# On-device TFLite models

**Owner of the wiring:** P3 · **Owner of the model files:** P2
**Contract:** TFLite tensor specs (AGENTS.md interface contract #3). The source of truth is
[`ml/ondevice/README.md`](../../../ml/ondevice/README.md) + `ml/models/*.json`.

P2's exported models live in `ml/models/` (committed). Copy them here to bundle them with the app:

| File (in `ml/models/`) | Purpose | Input → output |
|---|---|---|
| `seatbelt.tflite` | Seatbelt on / off | `image` [1,224,224,3] float32 RGB 0–255 → `p_belt` [1,1] P(seatbelt on), threshold 0.5 |
| `acoustic_anomaly.tflite` | Abnormal engine sound | `audio` [1,16000] float32 (1 s mono 16 kHz, −1..1) → `score` [1] reconstruction error, threshold 0.0906 |

**Fatigue has no TFLite file.** It uses a pre-trained face model (ML Kit / MediaPipe eye-open
probability and head pose) plus the scorer in `ml/ondevice/fatigue.py`, which is to be ported to Dart.

## Before wiring these in (known gaps)
- **Acoustic file name.** `AppConstants.acousticModelPath` (`lib/core/config.dart`) uses
  `acoustic_anomaly.tflite`, but `SafetyModelInfo.assetPath` (`lib/services/on_device/safety_models.dart`)
  expects `acoustic.tflite`. Pick one; P2's file is `acoustic_anomaly.tflite`.
- **Not bundled yet.** `pubspec.yaml` has no `flutter: assets:` entry for `assets/models/`, so files
  dropped here are not packaged until you add it.

## Enabling real inference
Today the app uses `HeuristicSafetyInferenceService` (a heuristic over camera frame features).
To switch, follow the TODO in `lib/services/on_device/safety_inference_service.dart`:
1. Add `tflite_flutter`.
2. Load the interpreters in `warmUp()`.
3. Construct `TfliteSafetyInferenceService` in `on_device_providers.dart`.

No screen or provider consumer changes are needed; the interface is stable.
