from fastapi import APIRouter, Depends, HTTPException
from typing import List
from models import ArticleCreate, ArticleUpdate, ArticleInDB
from middleware.auth import verify_token
from firebase_admin import firestore

router = APIRouter(prefix="/articles", tags=["articles"])
COLLECTION_NAME = 'articles'

def get_db():
    return firestore.client()

@router.get("/", response_model=List[ArticleInDB])
def get_articles(user: dict = Depends(verify_token)):
    db = get_db()
    docs = db.collection(COLLECTION_NAME).order_by("createdAt", direction=firestore.Query.DESCENDING).stream()
    articles = []
    for doc in docs:
        data = doc.to_dict()
        data['id'] = doc.id
        articles.append(ArticleInDB(**data))
    return articles

@router.get("/{article_id}", response_model=ArticleInDB)
def get_article(article_id: str, user: dict = Depends(verify_token)):
    db = get_db()
    doc = db.collection(COLLECTION_NAME).document(article_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Article not found")
    data = doc.to_dict()
    data['id'] = doc.id
    return ArticleInDB(**data)

@router.post("/", response_model=ArticleInDB)
def create_article(article: ArticleCreate, user: dict = Depends(verify_token)):
    db = get_db()
    new_article = ArticleInDB.create_new(article)
    db.collection(COLLECTION_NAME).document(new_article.id).set(new_article.model_dump())
    return new_article

@router.put("/{article_id}", response_model=ArticleInDB)
def update_article(article_id: str, article: ArticleUpdate, user: dict = Depends(verify_token)):
    db = get_db()
    doc_ref = db.collection(COLLECTION_NAME).document(article_id)
    if not doc_ref.get().exists:
        raise HTTPException(status_code=404, detail="Article not found")

    update_data = {k: v for k, v in article.model_dump().items() if v is not None}
    if update_data:
        doc_ref.update(update_data)

    updated_doc = doc_ref.get().to_dict()
    updated_doc['id'] = article_id
    return ArticleInDB(**updated_doc)

@router.delete("/{article_id}")
def delete_article(article_id: str, user: dict = Depends(verify_token)):
    db = get_db()
    doc_ref = db.collection(COLLECTION_NAME).document(article_id)
    if not doc_ref.get().exists:
        raise HTTPException(status_code=404, detail="Article not found")
    doc_ref.delete()
    return {"status": "success", "id": article_id}
