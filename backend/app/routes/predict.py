from fastapi import APIRouter, File, UploadFile, HTTPException
from pathlib import Path
from PIL import Image
import shutil
import uuid

from app.inference import run_binary_inference

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

        with Image.open(save_path) as img:
            img.verify()

        result = run_binary_inference(save_path)
        result["filename"] = unique_name
        return result

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