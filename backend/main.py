import os
from dotenv import load_dotenv
from fastapi import FastAPI
import firebase_admin
from firebase_admin import credentials

# Load environment variables from .env file if present
load_dotenv()

try:
    if os.path.exists("serviceAccountKey.json"):
        cred = credentials.Certificate("serviceAccountKey.json")
        print("Initialized Firebase Admin with serviceAccountKey.json")
    else:
        cred = credentials.ApplicationDefault()
        print("Initialized Firebase Admin with Application Default Credentials")
    firebase_admin.initialize_app(cred)
except Exception as e:
    print(f"Warning: Could not initialize Firebase Admin. Using default/unauthenticated mode. Error: {e}")
    # Initialize a dummy app so imports don't fail immediately
    try:
        firebase_admin.initialize_app()
    except ValueError:
        pass # App already exists


from routes import articles, ai_chat, whatsapp

app = FastAPI(title="AI CRUD Backend")

app.include_router(articles.router)
app.include_router(ai_chat.router)
app.include_router(whatsapp.router)

@app.get("/")
def read_root():
    return {"message": "AI CRUD Backend is running"}
