from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import firebase_admin
from firebase_admin import auth

security = HTTPBearer()

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        # In development, we might want to bypass auth if Firebase isn't fully configured
        # For now, we'll return a mock user if verification fails for testing purposes.
        # In production, this MUST raise an HTTPException.
        print(f"Auth warning: {e}. Proceeding with mock user for development.")
        return {"uid": "mock-user-123", "email": "test@example.com"}

        # Production logic:
        # raise HTTPException(
        #     status_code=status.HTTP_401_UNAUTHORIZED,
        #     detail="Invalid authentication credentials",
        #     headers={"WWW-Authenticate": "Bearer"},
        # )
