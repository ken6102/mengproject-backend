from PIL import Image
import numpy as np
from pathlib import Path

def preprocess_image(image_path: Path) -> np.ndarray:
    image = Image.open(image_path).convert("RGB")
    image = image.resize((128, 128))
    image_array = np.array(image, dtype=np.float32) / 255.0
    image_array = np.expand_dims(image_array, axis=0)  # shape: (1, 128, 128, 3)
    return image_array