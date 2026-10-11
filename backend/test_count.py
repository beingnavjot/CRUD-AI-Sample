import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.ApplicationDefault()
firebase_admin.initialize_app(cred)

db = firestore.client()
try:
    snapshot = db.collection('articles').count().get()
    print("Snapshot:", snapshot)
    count = snapshot[0][0].value
    print("Count:", count)
except Exception as e:
    print("Error:", e)
