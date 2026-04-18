import tensorflow as tf
from tensorflow.keras.layers import BatchNormalization, InputLayer

class CompatibleBatchNormalization(BatchNormalization):
    def __init__(self, *args, renorm=None, renorm_clipping=None, renorm_momentum=None, **kwargs):
        super().__init__(*args, **kwargs)

class CompatibleInputLayer(InputLayer):
    def __init__(self, *args, batch_shape=None, optional=None, **kwargs):
        if batch_shape is not None and "input_shape" not in kwargs:
            kwargs["input_shape"] = tuple(batch_shape[1:])
        super().__init__(*args, **kwargs)

model = tf.keras.models.load_model(
    "backend/models/cnn_curated.h5",
    custom_objects={
        "BatchNormalization": CompatibleBatchNormalization,
        "InputLayer": CompatibleInputLayer,
    },
    compile=False,
)

model.save("backend/models/cnn_curated_clean.h5")
print("Saved cleaned model to backend/models/cnn_curated_clean.h5")