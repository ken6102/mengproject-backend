from fastapi import APIRouter, File, UploadFile, HTTPException
from pathlib import Path
from PIL import Image
import shutil
import uuid

router = APIRouter(prefix="/predict", tags=["predict"])

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


@router.post("/")
async def predict_image(file: UploadFile = File(...)) -> dict:
    file_extension = Path(file.filename).suffix.lower()

    if file_extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Unsupported file extension. Please upload a JPG, PNG, or WEBP image."
        )

    unique_name = f"{uuid.uuid4()}{file_extension}"
    save_path = UPLOAD_DIR / unique_name

    try:
        with save_path.open("wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # Validate that the file is actually a readable image
        with Image.open(save_path) as img:
            img.verify()

    except HTTPException:
        raise
    except Exception as exc:
        if save_path.exists():
            save_path.unlink(missing_ok=True)
        raise HTTPException(
            status_code=400,
            detail=f"Uploaded file is not a valid supported image: {exc}"
        ) from exc
    finally:
        file.file.close()

    return {
        "filename": unique_name,
        "label": "malignant",
        "confidence": 0.91,
        "probability_malignant": 0.91,
        "threshold": 0.5,
        "message": "Dummy prediction returned successfully. Replace this with real model inference next."
    }