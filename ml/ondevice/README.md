# On-device models — spec for the app (P2 → P3)

**Interface contract #3 (TFLite model spec).** Everything here runs on the phone, offline
(`docs/DESIGN.md §2`). Owner: P2. Consumer: P3 (`app/lib/services/ml_client` + on-device integration).
Change a tensor shape or threshold only together with P3.

| Model | Requirement | Source | File(s) |
|---|---|---|---|
| Fatigue | FR-SAFE-1 (M) | Pre-trained face model (no training) + scoring logic below | `ondevice/fatigue.py` (reference) |
| Seatbelt | FR-SAFE-1 (M) | Our MobileNetV3-Small classifier | `models/seatbelt.tflite`, `models/seatbelt.json` |
| Engine sound | FR-SAFE-3 (C) | Our autoencoder, whole audio pipeline inside the model | `models/acoustic_anomaly.tflite`, `models/acoustic_anomaly.json` |

The committed `.tflite` files are **placeholders trained on synthetic data**: the shapes, names and
behaviour are final, the accuracy is not. Retrain with real photos/audio (below) and replace the
files. The `.json` next to each model is the machine-readable spec and is rewritten on every training run.

---

## 1. Fatigue (drowsiness) → `FatigueScore`

**Model: pre-trained, nothing to train.** Use either:
- **Recommended:** ML Kit face detection (`google_mlkit_face_detection`) with
  `enableClassification: true` → `leftEyeOpenProbability`, `rightEyeOpenProbability` (0–1) and
  `headEulerAngleX` (pitch, degrees; negative = looking down). Front camera, ~10 fps is enough.
- Or the MediaPipe Face Landmarker. Use the `eyeBlinkLeft/Right` blendshapes as `1 - eye_open`.

**Scoring: port `ml/ondevice/fatigue.py` to Dart exactly.** `ml/tests/test_fatigue.py` holds the
behaviour to match. Per frame, call `update(FaceFrame(t, face_found, left_eye_open, right_eye_open,
head_pitch_deg))` and get back:

| Field | Meaning | App action |
|---|---|---|
| `score` | 0–1 drowsiness over the last 60 s | show gauge; `> 0.7` → alert |
| `perclos` | fraction of time eyes closed (60 s) | debug / dashboard |
| `microsleep` | eyes closed ≥ 1 s right now | **immediate** loud alert + vibration |
| `face_missing` | no face for ≥ 3 s | "camera blocked / operator not visible" (safety gate) |
| `alert` | `microsleep or score > 0.7` | alert |

Constants: eyes closed when mean open-probability `< 0.3`; microsleep `≥ 1.0 s`; nod = pitch
`≤ -15°` for `≥ 0.5 s`; score = `0.6·min(PERCLOS/0.3,1) + 0.25·min(microsleeps/3,1) + 0.15·min(nods/4,1)`.
Report the **session maximum** (`session_max`) as the session's `FatigueScore` (Dataset A column,
`/ml/anomaly` and `/ml/safety` field `fatigue_score`).

---

## 2. Seatbelt → `SeatbeltStatus`

A pose model only finds shoulders and hips; it cannot see the belt. So this is an image classifier.

| | |
|---|---|
| Input | `image` · `float32 [1, 224, 224, 3]` · RGB, **raw 0–255** (the model normalises internally) |
| Preprocess | take the camera frame, centre-crop to a square, resize to 224×224. Front camera, cab-mount position. |
| Output | `p_belt` · `float32 [1, 1]` · probability the seatbelt is on |
| Decision | belt on if `p_belt > threshold` (in `seatbelt.json`, default 0.5) |
| Rate | 1 frame per second is plenty |
| Size | ~1.1 MB (int8 weights, float I/O) |

**Smoothing:** decide on the majority of the last 5 predictions. For Dataset A, a session is
`Unfastened` if the belt was off for more than 10% of moving time (SRS §6.1). The **pre-start gate**
(FR-GATE-1) uses the telematics `SeatbeltStatus` when the machine has it, and otherwise this model:
require 3 consecutive "belt on" frames.

**Real training data needed (team task):** photos from the **actual phone mount position** into
`ml/data/seatbelt/belt/` and `ml/data/seatbelt/no_belt/` (git-ignored, contains people). Aim for 150+
per class: different people, clothes (incl. hi-vis), belt colours, day/night/cab lighting, and
"belt hanging but not fastened" as `no_belt`. Then: `python training/seatbelt.py`.

---

## 3. Engine-sound anomaly → maintenance hint

The full signal chain (framing, DFT, mel filterbank, log, normalisation, autoencoder) is inside the
model. The app only records audio.

| | |
|---|---|
| Input | `audio` · `float32 [1, 16000]` · mono, **16 kHz, 1 second**, `int16 / 32768` → [-1, 1] |
| Output | `score` · `float32 [1]` · reconstruction error (higher = more unusual) |
| Decision | anomalous if `score > threshold` (in `acoustic_anomaly.json`) in **3 of the last 5** clips |
| Rate | one clip every few seconds while the engine runs. Skip clips during voice-log recording. |
| Size | ~2.3 MB (float16 weights) |

On an anomaly: show "Unusual engine sound — ask a technician to check", attach it to an incident,
and send it with the session (a `behaviorFlags` entry of type `acoustic`). It is a hint, not a diagnosis.

**Current placeholder quality (synthetic sounds):** AUC 0.987. At the threshold it catches bearing
whine, knock and misfire 100% and belt squeal 68%, with 3.7% false alarms per clip before the
3-of-5 debounce. Real recordings: a MIMII/DCASE-style folder with `normal/` and `abnormal/` wavs,
then `python training/acoustic.py --data <folder>`. Only normal sounds are needed to train;
abnormal ones are for measuring.

---

## Retraining (from `ml/`, with the ml venv)
```
python training/seatbelt.py                          # needs data/seatbelt/{belt,no_belt}
python training/seatbelt.py --synthetic 400          # pipeline check without photos
python training/acoustic.py --synthetic              # or --data <folder>
python -m pytest tests                               # fatigue reference behaviour
```
Note: TensorFlow 2.19 (`ml/requirements.txt`). `tf.lite.Interpreter` is deprecated in favour of
LiteRT (`ai_edge_litert`); the `.tflite` files themselves are unaffected.
