import os
from datetime import datetime, timezone
import google.generativeai as genai
from google.ai.generativelanguage_v1beta.types import FunctionResponse, Part, Content
from firebase_admin import firestore

# Configure Gemini API key from environment
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
genai.configure(api_key=GEMINI_API_KEY)

def get_db():
    return firestore.client()

def process_ai_agent(user_id: str, prompt: str) -> str:
    """
    Processes a prompt for a given user_id using Gemini Generative AI agent.
    Performs CRUD operations on Firestore subcollection: users/{user_id}/articles
    Returns a natural language response string.
    """
    print(f"[AI Agent] Processing prompt for user_id='{user_id}': {prompt}")

    db = get_db()
    articles_ref = db.collection("users").document(user_id).collection("articles")

    # Define tool functions scoped to this user_id
    def create_article(title: str, content: str, imageUrl: str = None) -> dict:
        """Creates a new article for the user with title, content, and optional image URL."""
        now = datetime.now(timezone.utc).isoformat()
        doc_ref = articles_ref.document()
        article_data = {
            "id": doc_ref.id,
            "title": title,
            "content": content,
            "imageUrl": imageUrl,
            "createdAt": now,
            "updatedAt": now,
            "userId": user_id
        }
        doc_ref.set(article_data)
        print(f"[AI Agent] Created article {doc_ref.id} for user {user_id}")
        return {"status": "success", "message": f"Article '{title}' created successfully.", "article_id": doc_ref.id}

    def list_articles() -> dict:
        """Lists all articles owned by the user."""
        docs = articles_ref.order_by("createdAt", direction=firestore.Query.DESCENDING).limit(10).stream()
        articles = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            articles.append({
                "id": data.get("id"),
                "title": data.get("title"),
                "content": data.get("content"),
                "imageUrl": data.get("imageUrl"),
                "createdAt": data.get("createdAt")
            })
        print(f"[AI Agent] Listed {len(articles)} articles for user {user_id}")
        return {"status": "success", "count": len(articles), "articles": articles}

    def update_article(article_id: str, title: str = None, content: str = None, imageUrl: str = None) -> dict:
        """Updates an existing article for the user by its article_id."""
        doc_ref = articles_ref.document(article_id)
        snapshot = doc_ref.get()
        if not snapshot.exists:
            return {"status": "error", "message": f"Article with ID '{article_id}' not found."}

        update_fields = {}
        if title is not None:
            update_fields["title"] = title
        if content is not None:
            update_fields["content"] = content
        if imageUrl is not None:
            update_fields["imageUrl"] = imageUrl

        if update_fields:
            update_fields["updatedAt"] = datetime.now(timezone.utc).isoformat()
            doc_ref.update(update_fields)
            print(f"[AI Agent] Updated article {article_id} for user {user_id}")
            return {"status": "success", "message": f"Article '{article_id}' updated successfully."}
        return {"status": "success", "message": "No fields were provided to update."}

    def delete_article(article_id: str) -> dict:
        """Deletes an article for the user by its article_id."""
        doc_ref = articles_ref.document(article_id)
        if not doc_ref.get().exists:
            return {"status": "error", "message": f"Article with ID '{article_id}' not found."}
        doc_ref.delete()
        print(f"[AI Agent] Deleted article {article_id} for user {user_id}")
        return {"status": "success", "message": f"Article '{article_id}' deleted successfully."}

    def get_article_count() -> dict:
        """Returns the total count of articles owned by the user."""
        snapshot = articles_ref.count().get()
        count = snapshot[0][0].value if snapshot else 0
        return {"status": "success", "count": count}

    tools_map = {
        "create_article": create_article,
        "list_articles": list_articles,
        "update_article": update_article,
        "delete_article": delete_article,
        "get_article_count": get_article_count
    }

    try:
        # Initialize Gemini Model with available tools
        model = genai.GenerativeModel(
            model_name="gemini-3-flash-preview",
            tools=[create_article, list_articles, update_article, delete_article, get_article_count]
        )

        chat = model.start_chat(history=[])
        response = chat.send_message(prompt)

        # Handle function call if triggered by Gemini
        tool_results = []
        if response.parts:
            for part in response.parts:
                if fn := part.function_call:
                    func_name = fn.name
                    fn_dict = type(fn).to_dict(fn)
                    args = fn_dict.get("args", {})

                    print(f"[AI Agent] Executing tool '{func_name}' with args: {args}")

                    if func_name in tools_map:
                        result = tools_map[func_name](**args)
                    else:
                        result = {"error": f"Unknown tool function: {func_name}"}

                    tool_results.append(
                        Part(function_response=FunctionResponse(name=func_name, response=result))
                    )

        if tool_results:
            final_response = chat.send_message(Content(parts=tool_results))
            return final_response.text

        return response.text or "Request processed successfully."

    except Exception as e:
        print(f"[AI Agent Error] Failed to process prompt: {e}")
        import traceback
        traceback.print_exc()
        return f"Sorry, I encountered an error while processing your request: {str(e)}"
