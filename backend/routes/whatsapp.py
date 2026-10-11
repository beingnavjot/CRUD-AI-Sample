import os
import json
import httpx
from fastapi import APIRouter, Request, Response, BackgroundTasks, HTTPException, Query
from firebase_admin import firestore
from services.ai_agent import process_ai_agent

router = APIRouter(tags=["whatsapp"])

# Environment variables for Meta WhatsApp Cloud API
WHATSAPP_VERIFY_TOKEN = os.environ.get("WHATSAPP_VERIFY_TOKEN", "my_secure_whatsapp_token_123")
WHATSAPP_ACCESS_TOKEN = os.environ.get("WHATSAPP_ACCESS_TOKEN", "")
WHATSAPP_PHONE_NUMBER_ID = os.environ.get("WHATSAPP_PHONE_NUMBER_ID", "")

def get_db():
    return firestore.client()

# ============================================================================
# 5. Outbound WhatsApp Message Service
# ============================================================================
def send_whatsapp_message(to_number: str, text: str):
    """
    Sends a text response back to the user via Meta WhatsApp Cloud API.
    Uses WHATSAPP_ACCESS_TOKEN and WHATSAPP_PHONE_NUMBER_ID.
    """
    access_token = os.environ.get("WHATSAPP_ACCESS_TOKEN", WHATSAPP_ACCESS_TOKEN)
    phone_number_id = os.environ.get("WHATSAPP_PHONE_NUMBER_ID", WHATSAPP_PHONE_NUMBER_ID)

    if not access_token or not phone_number_id:
        print("[WhatsApp Error] Missing WHATSAPP_ACCESS_TOKEN or WHATSAPP_PHONE_NUMBER_ID environment variables.")
        return

    url = f"https://graph.facebook.com/v19.0/{phone_number_id}/messages"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    payload = {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": to_number,
        "type": "text",
        "text": {
            "preview_url": False,
            "body": text
        }
    }

    print(f"[WhatsApp Outbound] Sending message to '{to_number}': {text[:100]}...")

    try:
        with httpx.Client(timeout=10.0) as client:
            res = client.post(url, headers=headers, json=payload)
            print(f"[WhatsApp Outbound Response] Status: {res.status_code}, Body: {res.text}")
            if res.status_code not in (200, 201):
                print(f"[WhatsApp Outbound Error] Failed to send message: {res.text}")
    except Exception as e:
        print(f"[WhatsApp Outbound Exception] Error sending message: {e}")

# Helper function to look up user by phone number
def find_user_by_phone(phone: str):
    """
    Queries Firestore 'users' collection for a matching phoneNumber.
    Checks with and without '+' prefix. Returns user_id string if found, else None.
    """
    db = get_db()
    phone_clean = phone.strip()
    with_plus = f"+{phone_clean}" if not phone_clean.startswith("+") else phone_clean
    without_plus = phone_clean.lstrip("+")

    candidates = [with_plus, without_plus, phone_clean]

    for cand in candidates:
        try:
            docs = db.collection("users").where(filter=firestore.FieldFilter("phoneNumber", "==", cand)).limit(1).get()
            if docs:
                found_id = docs[0].id
                print(f"[User Lookup] Found user_id '{found_id}' for phone '{cand}'")
                return found_id
        except Exception as e:
            print(f"[User Lookup Warning] Firestore query failed for candidate '{cand}': {e}")

    print(f"[User Lookup] No registered user found for phone '{phone}'")
    return None

# ============================================================================
# Background Task Processing for Inbound Webhook
# ============================================================================
def process_whatsapp_webhook_payload(payload: dict):
    """
    Extracts sender phone number and message body from Meta webhook payload.
    Authenticates user against Firestore 'users' collection.
    Invokes AI Agent or requests user registration.
    """
    print("\n--- [WhatsApp Webhook Payload Processing Started] ---")
    try:
        entries = payload.get("entry", [])
        for entry in entries:
            for change in entry.get("changes", []):
                value = change.get("value", {})
                messages = value.get("messages", [])

                for msg in messages:
                    sender_number = msg.get("from") # e.g., "15550199999" or "919876543210"
                    msg_type = msg.get("type")

                    if msg_type != "text":
                        print(f"[WhatsApp Processing] Ignored non-text message type '{msg_type}' from {sender_number}")
                        continue

                    text_body = msg.get("text", {}).get("body", "").strip()
                    print(f"[WhatsApp Inbound] Sender: {sender_number}, Text: '{text_body}'")

                    if not sender_number or not text_body:
                        continue

                    # 3. User Authentication via Phone Number
                    user_id = find_user_by_phone(sender_number)

                    if not user_id:
                        # User not found -> Ask to register via mobile app
                        registration_prompt = (
                            "Welcome! We couldn't find an account linked to this phone number. "
                            "Please register using our mobile app first to access your AI article manager."
                        )
                        send_whatsapp_message(sender_number, registration_prompt)
                    else:
                        # 4. AI Agent Invocation
                        ai_reply = process_ai_agent(user_id=user_id, prompt=text_body)

                        # 5. Outbound WhatsApp Message Service
                        send_whatsapp_message(sender_number, ai_reply)

    except Exception as e:
        print(f"[WhatsApp Webhook Background Error] Exception: {e}")
        import traceback
        traceback.print_exc()

# ============================================================================
# 1. Webhook Verification (GET /webhook/whatsapp)
# ============================================================================
@router.get("/webhook/whatsapp")
def verify_whatsapp_webhook(
    hub_mode: str = Query(None, alias="hub.mode"),
    hub_verify_token: str = Query(None, alias="hub.verify_token"),
    hub_challenge: str = Query(None, alias="hub.challenge")
):
    """
    Meta Webhook Verification Endpoint.
    Validates hub.verify_token against WHATSAPP_VERIFY_TOKEN env var.
    Returns hub.challenge string on match.
    """
    expected_token = os.environ.get("WHATSAPP_VERIFY_TOKEN", WHATSAPP_VERIFY_TOKEN)
    print(f"[WhatsApp GET Verification] Received mode='{hub_mode}', token='{hub_verify_token}', challenge='{hub_challenge}'")

    if hub_mode == "subscribe" and hub_verify_token == expected_token:
        print("[WhatsApp GET Verification] Token verified successfully!")
        return Response(content=hub_challenge, media_type="text/plain")

    print("[WhatsApp GET Verification] Token mismatch or invalid mode!")
    raise HTTPException(status_code=403, detail="Verification token mismatch")

# Also alias /whatsapp/webhook for convenience
@router.get("/whatsapp/webhook")
def verify_whatsapp_webhook_alias(
    hub_mode: str = Query(None, alias="hub.mode"),
    hub_verify_token: str = Query(None, alias="hub.verify_token"),
    hub_challenge: str = Query(None, alias="hub.challenge")
):
    return verify_whatsapp_webhook(hub_mode, hub_verify_token, hub_challenge)

# ============================================================================
# 2. Inbound Message Handling (POST /webhook/whatsapp) & Async Processing
# ============================================================================
@router.post("/webhook/whatsapp")
async def handle_whatsapp_webhook(
    request: Request,
    background_tasks: BackgroundTasks
):
    """
    Receives Meta WhatsApp webhook POST payloads.
    Immediately returns 200 OK within 3 seconds and processes payload in background.
    """
    try:
        body = await request.json()
        print(f"\n[WhatsApp POST Webhook Payload Debug]\n{json.dumps(body, indent=2)}")

        # Pass payload to FastAPI background task
        background_tasks.add_task(process_whatsapp_webhook_payload, body)

        return {"status": "success"}
    except Exception as e:
        print(f"[WhatsApp POST Webhook Error] {e}")
        # Always return 200 to prevent Meta from retrying indefinitely on bad JSON
        return {"status": "success"}

@router.post("/whatsapp/webhook")
async def handle_whatsapp_webhook_alias(
    request: Request,
    background_tasks: BackgroundTasks
):
    return await handle_whatsapp_webhook(request, background_tasks)
