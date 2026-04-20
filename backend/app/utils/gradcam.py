import base64
import io
from pathlib import Path

import cv2
import numpy as np
import tensorflow as tf
from PIL import Image
from tensorflow import keras

from app.model_loader import get_model
from app.preprocessing import preprocess_image


MODEL_IMG_SIZE = (128, 128)


def _last_conv_index(model: keras.Model) -> int:
    idx = None
    for i, layer in enumerate(model.layers):
        if isinstance(layer, keras.layers.Conv2D):
            idx = i
    if idx is None:
        raise ValueError("No Conv2D layer found. Grad-CAM requires a convolutional layer.")
    return idx


def _forward_until(model: keras.Model, x: tf.Tensor, stop_idx: int) -> tf.Tensor:
    h = x
    feature_maps = None

    for i, layer in enumerate(model.layers):
        try:
            h = layer(h, training=False)
        except TypeError:
            h = layer(h)

        if i == stop_idx:
            feature_maps = h

    if feature_maps is None:
        raise RuntimeError("Could not extract feature maps for Grad-CAM.")

    return feature_maps


def _forward_from(model: keras.Model, h: tf.Tensor, start_idx: int) -> tf.Tensor:
    for i, layer in enumerate(model.layers):
        if i <= start_idx:
            continue
        try:
            h = layer(h, training=False)
        except TypeError:
            h = layer(h)
    return h


def _make_gradcam_heatmap(model: keras.Model, x_np: np.ndarray) -> tuple[np.ndarray, float, str]:
    x = tf.convert_to_tensor(x_np, dtype=tf.float32)
    conv_idx = _last_conv_index(model)
    conv_layer_name = model.layers[conv_idx].name

    with tf.GradientTape() as tape:
        feature_maps = _forward_until(model, x, conv_idx)
        tape.watch(feature_maps)

        preds = _forward_from(model, feature_maps, conv_idx)

        if preds.shape[-1] == 1:
            score = preds[:, 0]
            prob_malignant = float(preds.numpy()[0][0])
        else:
            score = preds[:, 1]
            prob_malignant = float(preds.numpy()[0][1])

    grads = tape.gradient(score, feature_maps)
    if grads is None:
        raise RuntimeError("Gradients are None. Grad-CAM could not be generated.")

    pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2))
    fmap = feature_maps[0]

    heatmap = tf.reduce_sum(fmap * pooled_grads, axis=-1)
    heatmap = tf.maximum(heatmap, 0)
    heatmap = heatmap / (tf.reduce_max(heatmap) + 1e-8)

    return heatmap.numpy(), prob_malignant, conv_layer_name


def _overlay_heatmap_on_original(
    pil_orig: Image.Image,
    heatmap: np.ndarray,
    alpha: float = 0.28,
) -> Image.Image:
    orig_rgb = np.array(pil_orig.convert("RGB"))
    h, w = orig_rgb.shape[:2]

    heatmap_uint8 = np.uint8(255 * heatmap)
    heatmap_resized = cv2.resize(heatmap_uint8, (w, h), interpolation=cv2.INTER_LINEAR)
    heatmap_colored = cv2.applyColorMap(heatmap_resized, cv2.COLORMAP_JET)
    heatmap_colored = cv2.cvtColor(heatmap_colored, cv2.COLOR_BGR2RGB)

    overlay = cv2.addWeighted(orig_rgb, 1.0, heatmap_colored, alpha, 0)
    return Image.fromarray(overlay)


def _image_to_base64_png(image: Image.Image) -> str:
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return base64.b64encode(buffer.getvalue()).decode("utf-8")


def generate_gradcam_overlay_base64(image_path: Path) -> dict:
    """
    Generates a Grad-CAM overlay for the uploaded image and returns it as base64 PNG.
    This should not replace the main prediction pathway; it supplements it.
    """
    model = get_model()

    pil_orig = Image.open(image_path).convert("RGB")
    x_model = preprocess_image(image_path)

    heatmap, prob_malignant, conv_layer_name = _make_gradcam_heatmap(model, x_model)
    overlay_image = _overlay_heatmap_on_original(pil_orig, heatmap, alpha=0.28)

    return {
        "success": True,
        "overlay_base64": _image_to_base64_png(overlay_image),
        "probability_malignant": prob_malignant,
        "conv_layer": conv_layer_name,
    }