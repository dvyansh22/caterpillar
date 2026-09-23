/// On-device safety inference service (P3, AGENTS.md task #5).
///
/// Per `docs/DESIGN.md §2`, seatbelt / fatigue / acoustic detection runs
/// **on-device**, never in the cloud. This module owns that pipeline in the
/// app: it takes a per-frame [SafetyFeatures] vector extracted on-device and
/// returns a [SafetyReading].
///
/// Two backends implement the same interface:
///   * [HeuristicSafetyInferenceService] — ships today; a small deterministic
///     model over on-device frame features. Lets the safety UX be built and
///     demoed before P2's TFLite files exist.
///   * `TfliteSafetyInferenceService` — the production path (see TODO below).
///     Swap it in once P2 delivers the `.tflite` files documented in
///     `assets/models/README.md` and the `tflite_flutter` dependency is added.
///
/// Contract consumed: P2's TFLite tensor specs (AGENTS.md interface contract #3).
library;

import 'dart:math' as math;

import 'safety_models.dart';

/// Common interface for on-device safety inference.
abstract class SafetyInferenceService {
  /// Human-readable backend name shown in the UI ("Heuristic", "TFLite").
  String get backendLabel;

  /// Whether a real model file has been loaded for [model].
  bool isLoaded(SafetyModel model);

  /// Load / warm up models. Cheap for the heuristic backend.
  Future<void> warmUp();

  /// Run inference for a single frame's [features].
  SafetyReading infer(SafetyFeatures features);

  /// Release native resources (interpreters). No-op for the heuristic backend.
  void dispose();
}

/// Deterministic on-device model used until real TFLite files are available.
///
/// It is a genuine on-device computation (no network), driven by the frame
/// features extracted in the safety screen. The math is intentionally simple
/// and documented so the mapping to a real model is obvious:
///   * seatbelt  — a logistic over luma contrast in the torso region proxy.
///   * fatigue   — a slow PERCLOS-style integrator over low-motion periods.
///   * acoustic  — placeholder driven by motion spikes (real model uses mic).
class HeuristicSafetyInferenceService implements SafetyInferenceService {
  HeuristicSafetyInferenceService();

  double _fatigueIntegrator = 0.0;

  @override
  String get backendLabel => 'Heuristic (on-device)';

  @override
  bool isLoaded(SafetyModel model) => false;

  @override
  Future<void> warmUp() async {
    _fatigueIntegrator = 0.0;
  }

  @override
  SafetyReading infer(SafetyFeatures f) {
    // --- Seatbelt: bright, well-lit torso proxy → fastened. Very dark or
    // washed-out frames lower confidence, mimicking an occluded/absent belt.
    final beltLogit = 6.0 * (f.meanLuma - 0.18);
    final seatbelt = _sigmoid(beltLogit).clamp(0.05, 0.99);

    // --- Fatigue: low motion for sustained frames drifts the integrator up
    // (drowsy / static gaze); motion pulls it back down (alert / scanning).
    final drowsyPush = f.motion < 0.04 ? 0.015 : -0.05;
    _fatigueIntegrator = (_fatigueIntegrator + drowsyPush).clamp(0.0, 1.0);
    final fatigue = _fatigueIntegrator;

    // --- Acoustic placeholder: sharp motion spikes stand in for abnormal
    // engine transients until the mic-driven acoustic model lands.
    final acoustic = (f.motion * 1.6).clamp(0.0, 1.0);

    return SafetyReading(
      seatbeltFastened: seatbelt,
      fatigueScore: fatigue,
      acousticAnomaly: acoustic,
      timestamp: DateTime.now(),
    );
  }

  @override
  void dispose() {}

  static double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));
}

// ---------------------------------------------------------------------------
// Production path (enable when P2 delivers TFLite models)
// ---------------------------------------------------------------------------
//
// TODO(P3): implement TfliteSafetyInferenceService.
//
//   1. Add `tflite_flutter: ^0.11.0` to pubspec.yaml.
//   2. Drop P2's files into assets/models/{seatbelt,fatigue,acoustic}.tflite
//      (paths already declared in AppConstants + SafetyModelInfo.assetPath).
//   3. Load with Interpreter.fromAsset(model.assetPath) in warmUp().
//   4. In infer(), build the input tensor from the raw CameraImage (resize to
//      the input shape documented in assets/models/README.md, normalise), run
//      interpreter.run(input, output), and map the output tensor to a
//      SafetyReading. The interface above does not change — only the backend.
//   5. Swap the provider in on_device_providers.dart to construct this class.
