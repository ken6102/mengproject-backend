from pathlib import Path
from app.model_loader import get_model
from app.preprocessing import preprocess_image

def run_binary_inference(image_path: Path) -> dict:
    model = get_model()
    input_tensor = preprocess_image(image_path)

    prediction = model.predict(input_tensor, verbose=0)
    score = float(prediction[0][0])  # sigmoid output

    is_malignant = score > 0.5
    confidence = score if is_malignant else (1.0 - score)

    return {
        "label": "malignant" if is_malignant else "benign",
        "confidence": confidence,
        "probability_malignant": score,
        "threshold": 0.5,
        "message": (
            "Prediction returned successfully."
            if is_malignant or not is_malignant
            else "Prediction complete."
        ),
    }