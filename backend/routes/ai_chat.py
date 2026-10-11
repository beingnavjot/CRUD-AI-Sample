from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import google.generativeai as genai
import os
import uuid
from datetime import datetime
from firebase_admin import firestore
from middleware.auth import verify_token
from models import ArticleCreate, ArticleInDB

router = APIRouter(prefix="/ai", tags=["ai"])
COLLECTION_NAME = 'articles'
AUDIT_COLLECTION = 'ai_audit_logs'

def get_db():
    return firestore.client()

# Load Gemini API Key from environment variable
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
genai.configure(api_key=GEMINI_API_KEY)

class ChatMessage(BaseModel):
    role: str # 'user' or 'model'
    parts: List[str]

class ChatRequest(BaseModel):
    message: str
    history: Optional[List[ChatMessage]] = []

def log_audit(user_id: str, intent: str, params: dict, status: str):
    log_entry = {
        "userId": user_id,
        "intent": intent,
        "params": params,
        "status": status,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }
    get_db().collection(AUDIT_COLLECTION).add(log_entry)

# Define the tools for Gemini
def create_article(title: str, content: str, imageUrl: str = None) -> dict:
    """Creates a new article with a title and content."""
    # In a real scenario, this would be executed via the REST endpoint or service layer
    # But for the AI chat endpoint, we handle the execution here.
    return {"action": "create", "status": "pending_confirmation", "params": {"title": title, "content": content, "imageUrl": imageUrl}}

def list_articles() -> dict:
    """Lists all available articles."""
    docs = get_db().collection(COLLECTION_NAME).order_by("createdAt", direction=firestore.Query.DESCENDING).stream()
    articles = []
    for doc in docs:
        data = doc.to_dict()
        data['id'] = doc.id
        articles.append(data)
    return {"action": "list", "status": "success", "articles": articles}

def update_article(id: str, title: str = None, content: str = None, imageUrl: str = None) -> dict:
    """Updates an existing article by its ID."""
    return {"action": "update", "status": "pending_confirmation", "params": {"id": id, "title": title, "content": content, "imageUrl": imageUrl}}

def delete_article(id: str) -> dict:
    """Deletes an article by its ID."""
    return {"action": "delete", "status": "pending_confirmation", "params": {"id": id}}

def get_article_count() -> dict:
    """Retrieves the total number of articles in the database."""
    snapshot = get_db().collection(COLLECTION_NAME).count().get()
    # Correctly access the count from the AggregationQuery snapshot in python
    count = snapshot[0][0].value if snapshot else 0
    return {"action": "count", "status": "success", "count": count}

# Define the model with tools
model = genai.GenerativeModel(
    model_name='gemini-3-flash-preview', # Using a stable model for the backend
    tools=[create_article, list_articles, update_article, delete_article, get_article_count]
)

from google.ai.generativelanguage_v1beta.types import FunctionResponse, Part, Content

@router.post("/chat")
async def ai_chat(request: ChatRequest, user: dict = Depends(verify_token)):
    # Reconstruct history for Gemini
    formatted_history = []
    if request.history:
        for msg in request.history:
            formatted_history.append({"role": msg.role, "parts": msg.parts})

    chat = model.start_chat(history=formatted_history)

    try:
        response = chat.send_message(request.message)

        # Check if the model decided to call a function
        pending_action = None
        tool_results = []

        if response.parts:
            for part in response.parts:
                if fn := part.function_call:
                    func_name = fn.name
                    # Safely convert protobuf MapComposite to Python dict
                    fn_dict = type(fn).to_dict(fn)
                    args = fn_dict.get('args', {})

                    # Execute the tool function locally
                    if func_name == "create_article":
                        result = create_article(**args)
                    elif func_name == "list_articles":
                        result = list_articles()
                    elif func_name == "update_article":
                        result = update_article(**args)
                    elif func_name == "delete_article":
                        result = delete_article(**args)
                    elif func_name == "get_article_count":
                        result = get_article_count()
                    else:
                        result = {"error": "Unknown function"}

                    # Log the intent
                    log_audit(user.get('uid', 'unknown'), func_name, args, result.get('status', 'unknown'))

                    # If it requires confirmation, we stop here and return the pending state to the frontend
                    if result.get("status") == "pending_confirmation":
                        pending_action = result
                        break # Only handle one pending action at a time
                    else:
                        # For read-only operations, we feed the result back to Gemini
                        tool_results.append(
                            Part(function_response=FunctionResponse(name=func_name, response=result))
                        )

        if pending_action:
            return {
                "reply": "I need your confirmation before proceeding.",
                "pending_action": pending_action
            }

        if tool_results:
            # Send the tool execution results back to Gemini to get a natural language response
            final_response = chat.send_message(Content(parts=tool_results))
            return {"reply": final_response.text}

        return {"reply": response.text}

    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/confirm_action")
def confirm_action(action_data: dict, user: dict = Depends(verify_token)):
    # This endpoint is called when the user clicks 'Confirm' in the Flutter UI
    action = action_data.get("action")
    params = action_data.get("params", {})
    user_id = user.get('uid', 'unknown')

    try:
        if action == "create":
            new_article = ArticleInDB.create_new(ArticleCreate(**params))
            get_db().collection(COLLECTION_NAME).document(new_article.id).set(new_article.model_dump())
            log_audit(user_id, "create_article", params, "executed")
            return {"status": "success", "message": "Article created successfully", "article": new_article.model_dump()}

        elif action == "update":
            article_id = params.pop("id", None)
            if not article_id:
                raise HTTPException(status_code=400, detail="Missing article ID")

            doc_ref = get_db().collection(COLLECTION_NAME).document(article_id)
            if not doc_ref.get().exists:
                raise HTTPException(status_code=404, detail="Article not found")

            # Basic validation: ensure the user owns the article (assuming we add a userId field later,
            # for now we just update)
            update_data = {k: v for k, v in params.items() if v is not None}
            if update_data:
                doc_ref.update(update_data)
            log_audit(user_id, "update_article", params, "executed")
            return {"status": "success", "message": "Article updated successfully"}

        elif action == "delete":
            article_id = params.get("id")
            if not article_id:
                raise HTTPException(status_code=400, detail="Missing article ID")

            doc_ref = get_db().collection(COLLECTION_NAME).document(article_id)
            if not doc_ref.get().exists:
                raise HTTPException(status_code=404, detail="Article not found")

            doc_ref.delete()
            log_audit(user_id, "delete_article", params, "executed")
            return {"status": "success", "message": "Article deleted successfully"}

        else:
            raise HTTPException(status_code=400, detail="Unknown action")

    except Exception as e:
        log_audit(user_id, f"{action}_article", params, f"failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
