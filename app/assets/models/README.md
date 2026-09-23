# On-device TFLite models

**Owner of the wiring:** P3 · **Owner of the model files:** P2
**Contract:** TFLite tensor specs (AGENTS.md interface contract #3).

Drop P2's exported `.tflite` files here:

| File | Purpose | Runs |
|---|---|---|
| `seatbelt.tflite` | Seatbelt fastened / unfastened | On-device |
| `fatigue.tflite`  | Drowsiness (PERCLOS-style) | On-device |
| `acoustic.tflite` | Abnormal engine-sound detection | On-device |

Paths are already referenced by `AppConstants` (`lib/core/config.dart`) and
`SafetyModelInfo.assetPath` (`lib/services/on_device/safety_models.dart`).

## Expected tensor spec (fill in with P2's real values)

P2 must document, per model:

```
seatbelt:
  input:  [1, H, W, 3] float32, RGB, normalised 0–1   # e.g. 224x224
  output: [1, 2] float32 softmax → [unfastened, fastened]
fatigue:
  input:  [1, H, W, 1] float32 grayscale eye-crop
  output: [1, 1] float32 → drowsiness 0–1
acoustic:
  input:  [1, N] float32 log-mel frames
  output: [1, 1] float32 → anomaly 0–1
```

## Enabling the real backend
Until these files land, the app uses `HeuristicSafetyInferenceService`
(a genuine on-device pipeline over frame features). To switch to real
inference, follow the TODO in
`lib/services/on_device/safety_inference_service.dart`:
add `tflite_flutter`, load the interpreters in `warmUp()`, and construct
`TfliteSafetyInferenceService` in `on_device_providers.dart`. No screen or
provider consumer changes are required — the interface is stable.
