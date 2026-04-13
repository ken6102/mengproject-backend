from pathlib import Path
import tensorflow as tf
from tensorflow.keras.layers import BatchNormalization, InputLayer

MODEL_PATH = Path("models/cnn_curated_clean.h5")
_model = None


class CompatibleBatchNormalization(BatchNormalization):
    def __init__(self, *args, renorm=None, renorm_clipping=None, renorm_momentum=None, **kwargs):
        super().__init__(*args, **kwargs)


class CompatibleInputLayer(InputLayer):
    def __init__(self, *args, batch_shape=None, optional=None, **kwargs):
        if batch_shape is not None and "input_shape" not in kwargs:
            kwargs["input_shape"] = tuple(batch_shape[1:])
        super().__init__(*args, **kwargs)


class CompatibleDTypePolicy:
    def __init__(self, name="float32", **kwargs):
        self.name = name

    def __str__(self):
        return self.name


def get_model():
    global _model
    if _model is None:
        print(f"Loading model from: {MODEL_PATH.resolve()}")
        _model = tf.keras.models.load_model(
            MODEL_PATH,
            custom_objects={
                "CompatibleBatchNormalization": CompatibleBatchNormalization,
                "CompatibleInputLayer": CompatibleInputLayer,
                "BatchNormalization": CompatibleBatchNormalization,
                "InputLayer": CompatibleInputLayer,
                "DTypePolicy": CompatibleDTypePolicy,
            },
            compile=False,
        )
        print("Model loaded successfully.")
    return _model