from fastapi import APIRouter, File, UploadFile, HTTPException
from pathlib import Path
import shutil
import uuid

router = APIRouter(prefix="/predict", tags=["predict"])

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)


@router.post("/")
async def predict_image(file: UploadFile = File(...)) -> dict:
    allowed_types = {"image/jpeg", "image/png", "image/jpg", "image/webp"}

    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail="Unsupported file type. Please upload a JPG, PNG, or WEBP image."
        )

    file_extension = Path(file.filename).suffix.lower()
    unique_name = f"{uuid.uuid4()}{file_extension}"
    save_path = UPLOAD_DIR / unique_name

    try:
        with save_path.open("wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to save uploaded image: {exc}"
        ) from exc
    finally:
        file.file.close()

    # Dummy response for now
    return {
        "filename": unique_name,
        "label": "malignant",
        "confidence": 0.91,
        "probability_malignant": 0.91,
        "threshold": 0.5,
        "message": "Dummy prediction returned successfully. Replace this with real model inference next."
    }