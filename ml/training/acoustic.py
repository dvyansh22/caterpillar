"""Train the on-device engine-sound anomaly model (P2, FR-SAFE-3) and export it to TFLite.

Unsupervised, like the DCASE machine-condition baseline: an autoencoder learns what a *normal*
engine sounds like from log-mel spectrograms; a clip it reconstructs badly is anomalous.

The whole pipeline is inside the TFLite graph (framing + DFT as a fixed conv, mel filterbank,
log, normalisation, autoencoder, error), so the app only feeds 1 s of raw mic audio and reads a
score. No audio maths to re-implement in Dart.

Data:
- real: a MIMII / DCASE-style folder (--data DIR with normal/*.wav and abnormal/*.wav, 16 kHz);
- dev: --synthetic generates engine-like hum (normal) and bearing whine, knock, belt squeal and
  misfire (abnormal) so the pipeline can be built before real recordings exist.

Usage (from ml/):
    python training/acoustic.py --synthetic
    python training/acoustic.py --data data/audio/pump_id00
Outputs: models/acoustic_anomaly.tflite + models/acoustic_anomaly.json (spec for P3).
"""

from __future__ import annotations

import argparse
import json
from datetime import date
from pathlib import Path

import librosa
import numpy as np
import tensorflow as tf
from sklearn.metrics import roc_auc_score

ML_DIR = Path(__file__).resolve().parents[1]
SR = 16000
CLIP = SR  # 1 s per inference
N_FFT, HOP, N_MELS = 1024, 512, 64
FRAMES = (CLIP - N_FFT) // HOP + 1  # 30
CONTEXT = 5  # frames per autoencoder input (DCASE baseline style)
GROUPS = FRAMES // CONTEXT  # 6


# ---- front end: waveform -> normalised log-mel, as fixed TF ops ----

def dft_kernel() -> np.ndarray:
    """[N_FFT, 1, 2 * bins] Hann-windowed cos/sin filters: a strided conv1d == framed real DFT."""
    n = np.arange(N_FFT)[:, None]
    k = np.arange(N_FFT // 2 + 1)[None, :]
    window = np.hanning(N_FFT)[:, None]
    angle = 2 * np.pi * n * k / N_FFT
    return np.concatenate([window * np.cos(angle), -window * np.sin(angle)], axis=1)[:, None, :].astype("float32")


class FrontEnd(tf.Module):
    def __init__(self, mean: np.ndarray | None = None, std: np.ndarray | None = None) -> None:
        self.kernel = tf.constant(dft_kernel())
        mel = librosa.filters.mel(sr=SR, n_fft=N_FFT, n_mels=N_MELS, fmin=20, fmax=SR // 2)
        self.mel = tf.constant(mel.T.astype("float32"))
        self.mean = tf.constant(np.zeros(N_MELS, "float32") if mean is None else mean.astype("float32"))
        self.std = tf.constant(np.ones(N_MELS, "float32") if std is None else std.astype("float32"))

    def log_mel(self, wave: tf.Tensor) -> tf.Tensor:
        """[B, CLIP] float waveform in [-1, 1] -> [B, FRAMES, N_MELS] log-mel."""
        spec = tf.nn.conv1d(wave[:, :, None], self.kernel, stride=HOP, padding="VALID")
        bins = N_FFT // 2 + 1
        power = tf.square(spec[..., :bins]) + tf.square(spec[..., bins:])
        return tf.math.log(tf.matmul(power, self.mel) + 1e-6)

    def features(self, wave: tf.Tensor) -> tf.Tensor:
        """-> [B, GROUPS, CONTEXT * N_MELS] normalised autoencoder inputs."""
        x = (self.log_mel(wave) - self.mean) / self.std
        return tf.reshape(x[:, : GROUPS * CONTEXT], [-1, GROUPS, CONTEXT * N_MELS])


def autoencoder() -> tf.keras.Model:
    dim = CONTEXT * N_MELS
    inputs = tf.keras.Input((GROUPS, dim))
    x = inputs
    for units in (128, 64, 8, 64, 128):
        x = tf.keras.layers.Dense(units, activation="relu")(x)
    outputs = tf.keras.layers.Dense(dim)(x)
    model = tf.keras.Model(inputs, outputs)
    model.compile(tf.keras.optimizers.Adam(1e-3), "mse")
    return model


class Detector(tf.Module):
    """Front end + trained autoencoder with weights frozen as constants (TFLite has no variables)."""

    def __init__(self, front: FrontEnd, ae: tf.keras.Model) -> None:
        self.front = front
        weights = ae.get_weights()
        self.layers = [(tf.constant(w), tf.constant(b)) for w, b in zip(weights[::2], weights[1::2])]

    @tf.function(input_signature=[tf.TensorSpec([1, CLIP], tf.float32, name="audio")])
    def __call__(self, audio: tf.Tensor) -> dict[str, tf.Tensor]:
        x = self.front.features(audio)
        h = x
        for i, (w, b) in enumerate(self.layers):
            h = tf.matmul(h, w) + b
            if i < len(self.layers) - 1:
                h = tf.nn.relu(h)
        return {"score": tf.reduce_mean(tf.square(h - x), axis=[1, 2])}


# ---- data ----

def synth_clips(n: int, kind: str, rng: np.random.Generator) -> np.ndarray:
    t = np.arange(CLIP) / SR
    clips = np.empty((n, CLIP), "float32")
    for i in range(n):
        f0 = rng.uniform(25, 45) * (1 + 0.01 * np.sin(2 * np.pi * rng.uniform(0.2, 1) * t))
        phase = 2 * np.pi * np.cumsum(f0) / SR
        x = sum(rng.uniform(0.6, 1.0) / k ** 0.8 * np.sin(k * phase + rng.uniform(0, 6.3))
                for k in range(1, 41))
        x = x / np.abs(x).max()
        noise = np.cumsum(rng.normal(0, 1, CLIP))
        noise = (noise - noise.mean()) / (np.abs(noise).max() + 1e-9)
        x = x + rng.uniform(0.05, 0.3) * noise + rng.normal(0, rng.uniform(0.005, 0.03), CLIP)

        if kind == "bearing":  # high-frequency whine, modulated by shaft speed
            x += rng.uniform(0.06, 0.15) * np.sin(2 * np.pi * rng.uniform(2500, 5000) * t) * (1 + 0.5 * np.sin(phase))
        elif kind == "knock":  # decaying resonant impulses every other revolution
            period = int(SR / (f0.mean() / 2))
            ring = np.exp(-np.arange(400) / 60) * np.sin(2 * np.pi * rng.uniform(1000, 3000) * np.arange(400) / SR)
            for start in range(rng.integers(0, period), CLIP - 400, period):
                x[start:start + 400] += rng.uniform(0.4, 0.8) * ring
        elif kind == "squeal":  # slipping belt: wavering tone around 1-2 kHz
            fc = rng.uniform(1000, 2000)
            x += rng.uniform(0.08, 0.2) * np.sin(2 * np.pi * np.cumsum(fc + 80 * np.sin(2 * np.pi * 3 * t)) / SR)
        elif kind == "misfire":  # one cylinder in four dropping out
            x *= 1 - rng.uniform(0.5, 0.8) * (np.sin(phase / 4) > 0.7)
        clips[i] = (x / np.abs(x).max() * rng.uniform(0.1, 0.8)).astype("float32")
    return clips


def load_wavs(folder: Path) -> np.ndarray:
    """Cut every wav in the folder into 1 s clips."""
    clips = []
    for path in sorted(folder.glob("*.wav")):
        audio, _ = librosa.load(path, sr=SR, mono=True)
        clips += [audio[i:i + CLIP] for i in range(0, len(audio) - CLIP + 1, CLIP)]
    return np.stack(clips).astype("float32")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--data", help="folder with normal/ and abnormal/ wav files (16 kHz)")
    p.add_argument("--synthetic", action="store_true")
    p.add_argument("--epochs", type=int, default=40)
    p.add_argument("--out", default=str(ML_DIR / "models" / "acoustic_anomaly.tflite"))
    p.add_argument("--seed", type=int, default=42)
    args = p.parse_args()
    tf.keras.utils.set_random_seed(args.seed)
    rng = np.random.default_rng(args.seed)

    if args.synthetic:
        normal = synth_clips(1500, "normal", rng)
        abnormal = {k: synth_clips(75, k, rng) for k in ("bearing", "knock", "squeal", "misfire")}
    elif args.data:
        normal = load_wavs(Path(args.data) / "normal")
        abnormal = {"abnormal": load_wavs(Path(args.data) / "abnormal")}
    else:
        p.error("pass --synthetic or --data")

    rng.shuffle(normal)
    n_test = min(300, len(normal) // 5)
    train, val, test_normal = normal[2 * n_test:], normal[n_test:2 * n_test], normal[:n_test]

    raw = FrontEnd().log_mel(train).numpy()
    front = FrontEnd(raw.mean(axis=(0, 1)), raw.std(axis=(0, 1)) + 1e-6)
    ae = autoencoder()
    x_train = front.features(train).numpy()
    ae.fit(x_train, x_train, validation_data=(front.features(val).numpy(),) * 2,
           epochs=args.epochs, batch_size=64, verbose=0,
           callbacks=[tf.keras.callbacks.EarlyStopping(patience=5, restore_best_weights=True)])

    detector = Detector(front, ae)
    score = lambda clips: np.concatenate([detector(c[None])["score"].numpy() for c in clips])  # noqa: E731
    threshold = float(np.percentile(score(val), 99))  # ~1% false alarms on normal engines

    normal_scores = score(test_normal)
    all_abnormal = np.concatenate(list(abnormal.values()))
    auc = roc_auc_score(np.r_[np.zeros(len(normal_scores)), np.ones(len(all_abnormal))],
                        np.r_[normal_scores, score(all_abnormal)])
    detection = {k: round(float((score(v) > threshold).mean()), 3) for k, v in abnormal.items()}
    false_alarms = round(float((normal_scores > threshold).mean()), 3)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    converter = tf.lite.TFLiteConverter.from_concrete_functions(
        [detector.__call__.get_concrete_function()], detector)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]  # half size; int8 would blur the DFT
    out.write_bytes(converter.convert())

    interpreter = tf.lite.Interpreter(model_path=str(out))
    run = interpreter.get_signature_runner()
    tflite_scores = np.array([run(audio=c[None])["score"][0] for c in test_normal[:50]])
    max_rel_diff = float(np.max(np.abs(tflite_scores - normal_scores[:50]) / normal_scores[:50]))

    spec = {
        "model": out.name, "version": f"acoustic-ae-{date.today():%Y%m%d}",
        "trained_on": "synthetic" if args.synthetic else str(args.data),
        "input": {"name": "audio", "shape": [1, CLIP], "dtype": "float32",
                  "format": f"mono PCM at {SR} Hz, 1 s, scaled to [-1, 1] (int16 / 32768)"},
        "output": {"name": "score", "shape": [1], "dtype": "float32",
                   "meaning": "reconstruction error; higher = more unusual sound"},
        "threshold": round(threshold, 5),
        "decision": "anomalous if score > threshold in 3 of the last 5 clips (debounce)",
        "test_auc": round(auc, 4), "detection_rate_at_threshold": detection,
        "false_alarm_rate_at_threshold": false_alarms,
        "tflite_vs_tf_max_relative_diff": round(max_rel_diff, 4),
        "size_kb": round(out.stat().st_size / 1024),
    }
    out.with_suffix(".json").write_text(json.dumps(spec, indent=2))
    print(json.dumps(spec, indent=2))


if __name__ == "__main__":
    main()
