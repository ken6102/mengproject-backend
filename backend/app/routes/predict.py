from fastapi import APIRouter, File, UploadFile, HTTPException
from pathlib import Path
from PIL import Image
import shutil
import uuid
import cv2
import numpy as np

from app.inference import run_binary_inference
from app.utils.xai_features import (
    analyse_abc_features,
    build_baseline_abc_explanation,
)
from app.utils.xai_text import rewrite_abc_explanation

router = APIRouter(prefix="/predict", tags=["predict"])

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def pil_to_bgr(image: Image.Image) -> np.ndarray:
    rgb = image.convert("RGB")
    rgb_np = np.array(rgb)
    return cv2.cvtColor(rgb_np, cv2.COLOR_RGB2BGR)


@router.post("/")
async def predict_image(file: UploadFile = File(...)) -> dict:
    file_extension = Path(file.filename).suffix.lower()

    if file_extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Unsupported file extension. Please upload a JPG, PNG, or WEBP image.",
        )

    unique_name = f"{uuid.uuid4()}{file_extension}"
    save_path = UPLOAD_DIR / unique_name

    try:
        with save_path.open("wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to save uploaded image: {exc}",
        ) from exc
    finally:
        file.file.close()

    try:
        with Image.open(save_path) as img:
            img.verify()
    except Exception as exc:
        if save_path.exists():
            save_path.unlink(missing_ok=True)
        raise HTTPException(
            status_code=400,
            detail=f"Image validation failed: {exc}",
        ) from exc

    try:
        # Binary model inference
        result = run_binary_inference(save_path)

        # Re-open image after verify() and run ABC/XAI checks
        with Image.open(save_path) as pil_image:
            pil_image = pil_image.convert("RGB")
            image_bgr = pil_to_bgr(pil_image)
            abc_result = analyse_abc_features(image_bgr)

        baseline_explanation = build_baseline_abc_explanation(abc_result)
        rewritten_explanation = rewrite_abc_explanation(
            baseline_text=baseline_explanation,
            keyword_bank=abc_result.get("keyword_bank", {}),
            label=result.get("label"),
            confidence=result.get("confidence"),
        )

        result["filename"] = unique_name

        result["abc_features"] = {
            "asymmetry": abc_result.get("asymmetry"),
            "border": abc_result.get("border"),
            "colour": abc_result.get("colour"),
        }

        result["keyword_bank"] = abc_result.get(
            "keyword_bank",
            {
                "asymmetry": ["asymmetry not assessable"],
                "border": ["border not assessable"],
                "colour": ["colour variation not assessable"],
                "pooled": [
                    "asymmetry not assessable",
                    "border not assessable",
                    "colour variation not assessable",
                ],
            },
        )

        result["abc_analysis_success"] = abc_result.get("success", False)

        if not abc_result.get("success", False):
            result["abc_message"] = abc_result.get(
                "message",
                "ABC feature analysis could not be completed.",
            )

        result["xai_explanation"] = {
            "baseline": baseline_explanation,
            "rewritten": rewritten_explanation,
        }

        return result

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Inference failed: {exc}",
        ) from exc