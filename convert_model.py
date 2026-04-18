import tensorflow as tf

model = tf.keras.models.load_model("backend/models/cnn_curated.keras")
model.save("backend/models/cnn_curated.h5")
print("Saved backend/models/cnn_curated.h5")