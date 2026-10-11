from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
import uuid

class ArticleBase(BaseModel):
    title: str
    content: str
    imageUrl: Optional[str] = None

class ArticleCreate(ArticleBase):
    pass

class ArticleUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    imageUrl: Optional[str] = None

class ArticleInDB(ArticleBase):
    id: str
    createdAt: str

    @classmethod
    def create_new(cls, data: ArticleCreate) -> "ArticleInDB":
        return cls(
            id=str(uuid.uuid4()),
            title=data.title,
            content=data.content,
            imageUrl=data.imageUrl,
            createdAt=datetime.utcnow().isoformat() + "Z"
        )
