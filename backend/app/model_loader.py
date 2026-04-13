from pathlib import Path
import tensorflow as tf

MODEL_PATH = Path("models/cnn_curated.keras")

_model = None

def get_model():
    global _model
    if _model is None:
        _model = tf.keras.models.load_model(MODEL_PATH)
    return _model