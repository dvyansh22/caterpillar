"""Train the on-device seatbelt classifier (P2, FR-SAFE-1) and export it to TFLite.

Transfer learning on MobileNetV3-Small: one camera frame from the cab-mounted phone -> P(belt on).
Pose models only find shoulders and hips, not the belt, so the belt itself needs a classifier.

Data (not committed — photos of people): data/seatbelt/{belt,no_belt}/*.jpg, taken from the
real phone mount position. ~150+ per class, varied people, clothing, light and belt colours.

Usage (from ml/):
    python training/seatbelt.py                       # train on data/seatbelt/, export TFLite
    python training/seatbelt.py --synthetic 400 --weights none   # pipeline smoke test, no photos
Outputs: models/seatbelt.tflite + models/seatbelt.json (spec for P3, see ondevice/README.md).
"""

from __future__ import annotations

import argparse
import json
from datetime import date
from pathlib import Path

import numpy as np
import tensorflow as tf

ML_DIR = Path(__file__).resolve().parents[1]
IMG = 224
CLASSES = ["no_belt", "belt"]  # label 1 = belt on


def load_folder(root: Path, seed: int) -> tuple[tf.data.Dataset, tf.data.Dataset]:
    kwargs = dict(labels="inferred", class_names=CLASSES, label_mode="binary", image_size=(IMG, IMG),
                  batch_size=32, validation_split=0.2, seed=seed)
    train = tf.keras.utils.image_dataset_from_directory(root, subset="training", **kwargs)
    val = tf.keras.utils.image_dataset_from_directory(root, subset="validation", **kwargs)
    return train, val


def synthetic(n: int, seed: int) -> tuple[tf.data.Dataset, tf.data.Dataset]:
    """Fake cab frames: a torso block, with a diagonal band across it when belted."""
    rng = np.random.default_rng(seed)
    x = rng.uniform(40, 200, (n, IMG, IMG, 3)).astype("float32")
    y = (rng.random(n) < 0.5).astype("float32")
    yy, xx = np.mgrid[0:IMG, 0:IMG]
    for i in range(n):
        x0, y0 = rng.integers(40, 80), rng.integers(50, 90)
        x[i, y0:y0 + 120, x0:x0 + 110] = rng.uniform(60, 180, 3)
        if y[i]:
            offset = rng.integers(-15, 15)
            band = np.abs((yy - y0) - (xx - x0) + offset) < 8
            torso = (yy >= y0) & (yy < y0 + 120) & (xx >= x0) & (xx < x0 + 110)
            x[i][band & torso] = rng.uniform(0, 40)
    split = int(n * 0.8)
    make = lambda a, b: tf.data.Dataset.from_tensor_slices((a, b[:, None])).batch(32)  # noqa: E731
    return make(x[:split], y[:split]), make(x[split:], y[split:])


def build(weights: str | None) -> tf.keras.Model:
    augment = tf.keras.Sequential([
        tf.keras.layers.RandomFlip("horizontal"),  # a mirrored belt is still a belt
        tf.keras.layers.RandomRotation(0.05),
        tf.keras.layers.RandomBrightness(0.2, value_range=(0, 255)),
        tf.keras.layers.RandomContrast(0.2),
    ], name="augment")
    base = tf.keras.applications.MobileNetV3Small(
        input_shape=(IMG, IMG, 3), include_top=False, weights=weights, pooling="avg",
        include_preprocessing=True)  # takes raw 0-255 RGB, so the app does no normalisation
    base.trainable = False

    inputs = tf.keras.Input((IMG, IMG, 3), name="image")
    x = base(augment(inputs), training=False)
    x = tf.keras.layers.Dropout(0.2)(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid", name="p_belt")(x)
    model = tf.keras.Model(inputs, outputs)
    model.compile(tf.keras.optimizers.Adam(1e-3), "binary_crossentropy",
                  metrics=["accuracy", tf.keras.metrics.AUC(name="auc")])
    return model


def export(model: tf.keras.Model, out: Path) -> None:
    @tf.function(input_signature=[tf.TensorSpec([1, IMG, IMG, 3], tf.float32, name="image")])
    def serve(image):
        return {"p_belt": model(image, training=False)}

    converter = tf.lite.TFLiteConverter.from_concrete_functions([serve.get_concrete_function()], model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]  # int8 weights, float I/O
    out.write_bytes(converter.convert())


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--data", default=str(ML_DIR / "data" / "seatbelt"))
    p.add_argument("--synthetic", type=int, default=0, help="use N fake images instead of --data")
    p.add_argument("--weights", default="imagenet", choices=["imagenet", "none"])
    p.add_argument("--epochs", type=int, default=12)
    p.add_argument("--out", default=str(ML_DIR / "models" / "seatbelt.tflite"))
    p.add_argument("--seed", type=int, default=42)
    args = p.parse_args()
    tf.keras.utils.set_random_seed(args.seed)

    train, val = synthetic(args.synthetic, args.seed) if args.synthetic else load_folder(Path(args.data), args.seed)
    model = build(None if args.weights == "none" else args.weights)
    if args.weights == "none":
        model.layers[2].trainable = True  # nothing pre-trained to protect in a smoke test
        model.compile(tf.keras.optimizers.Adam(1e-3), "binary_crossentropy",
                      metrics=["accuracy", tf.keras.metrics.AUC(name="auc")])
    model.fit(train, validation_data=val, epochs=args.epochs, verbose=2)
    loss, acc, auc = model.evaluate(val, verbose=0)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    export(model, out)
    interpreter = tf.lite.Interpreter(model_path=str(out))
    interpreter.allocate_tensors()
    batch = next(iter(val))[0][:1].numpy()
    interpreter.set_tensor(interpreter.get_input_details()[0]["index"], batch)
    interpreter.invoke()
    tflite_p = float(interpreter.get_tensor(interpreter.get_output_details()[0]["index"])[0, 0])
    keras_p = float(model(batch, training=False)[0, 0])

    spec = {
        "model": out.name, "version": f"seatbelt-mnv3s-{date.today():%Y%m%d}",
        "trained_on": "synthetic" if args.synthetic else str(args.data),
        "input": {"name": "image", "shape": [1, IMG, IMG, 3], "dtype": "float32",
                  "range": "0-255 RGB, no normalisation", "resize": "center-crop to square, resize 224"},
        "output": {"name": "p_belt", "shape": [1, 1], "dtype": "float32", "meaning": "P(seatbelt on)"},
        "threshold": 0.5,
        "val_accuracy": round(acc, 4), "val_auc": round(auc, 4),
        "size_kb": round(out.stat().st_size / 1024),
    }
    out.with_suffix(".json").write_text(json.dumps(spec, indent=2))
    print(json.dumps(spec, indent=2))
    print(f"TFLite vs Keras on one frame: {tflite_p:.4f} vs {keras_p:.4f}")


if __name__ == "__main__":
    main()
