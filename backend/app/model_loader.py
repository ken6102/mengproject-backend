from pathlib import Path
import tensorflow as tf

MODEL_PATH = Path("models/cnn_curated.keras")
_model = None

def get_model():
    global _model
    if _model is None:
        print(f"Loading model from: {MODEL_PATH.resolve()}")
        _model = tf.keras.models.load_model(MODEL_PATH)
        print("Model loaded successfully.")
    return _model