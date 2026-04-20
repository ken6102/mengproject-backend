from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from openai import OpenAI
import os

router = APIRouter(prefix="/chat", tags=["chat"])

client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY"))


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    reply: str


SYSTEM_PROMPT = """
You are the homepage assistant for a GP-facing skin lesion screening prototype app.

Your role:
- Help users understand how to use the app.
- Explain the Scan, History, Settings, About, and explainability features.
- Explain the ABC criteria at a basic and clinically appropriate level.
- Explain confidence scores cautiously.
- Explain that this is a prototype clinical decision-support tool.

Rules:
- Do not provide a definitive diagnosis.
- Do not claim that a lesion is definitely benign or definitely malignant.
- Do not replace clinical judgement.
- Do not give unsafe medical advice.
- If the user asks a medical-risk question, answer cautiously and advise appropriate clinical review.
- Keep answers clear, professional, and useful.
- Prefer short to medium-length answers unless more detail is requested.
- If asked about app capabilities, only describe the prototype in a realistic way.

Useful app context:
- The app supports image upload and camera capture.
- The app sends lesion images to a Python backend for binary classification.
- The app displays confidence and explainability output.
- The current explainability output is based on asymmetry, border, and colour variation.
- Saved scans can be stored in History with patient details.
- The app includes PIN protection and theme settings.
""".strip()


@router.post("/", response_model=ChatResponse)
async def chat_endpoint(payload: ChatRequest) -> ChatResponse:
    message = payload.message.strip()

    if not message:
        raise HTTPException(status_code=400, detail="Message cannot be empty.")

    try:
        response = client.responses.create(
            model="gpt-5.4",
            instructions=SYSTEM_PROMPT,
            input=message,
        )

        reply = response.output_text.strip()
        if not reply:
            reply = (
                "I’m sorry, but I couldn’t generate a response just now. "
                "Please try rephrasing your question."
            )

        return ChatResponse(reply=reply)

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Chat request failed: {exc}",
        ) from exc