/// Data models for on-device safety inference (seatbelt / fatigue / acoustic).
///
/// These are the app-side result types produced by the on-device inference
/// pipeline (P3, AGENTS.md task #5). They are independent of the concrete
/// backend (heuristic today, TFLite once P2 delivers models).
library;

/// Which on-device safety model produced (or would produce) a signal.
enum SafetyModel { seatbelt, fatigue, acoustic }

extension SafetyModelInfo on SafetyModel {
  String get label => switch (this) {
        SafetyModel.seatbelt => 'Seatbelt',
        SafetyModel.fatigue => 'Fatigue',
        SafetyModel.acoustic => 'Acoustic',
      };

  /// Asset path of the `.tflite` file this model loads once available (P2).
  /// Kept in sync with [AppConstants] in `core/config.dart`.
  String get assetPath => switch (this) {
        SafetyModel.seatbelt => 'assets/models/seatbelt.tflite',
        SafetyModel.fatigue => 'assets/models/fatigue.tflite',
        SafetyModel.acoustic => 'assets/models/acoustic.tflite',
      };
}

/// A lightweight, model-agnostic feature vector extracted on-device from a
/// single camera frame. A real TFLite model would consume the raw tensor
/// instead; this keeps the demo pipeline cheap and format-independent.
class SafetyFeatures {
  const SafetyFeatures({
    required this.meanLuma,
    required this.motion,
    required this.frameIndex,
  });

  /// Mean luminance of the frame, normalised 0–1.
  final double meanLuma;

  /// Inter-frame motion estimate (EMA of |Δluma|), normalised 0–1.
  final double motion;

  /// Monotonic frame counter — lets models model temporal state (e.g. PERCLOS).
  final int frameIndex;
}

/// A single inference result across the safety models.
class SafetyReading {
  const SafetyReading({
    required this.seatbeltFastened,
    required this.fatigueScore,
    required this.acousticAnomaly,
    required this.timestamp,
  });

  /// P(seatbelt fastened) — 0 (unfastened) … 1 (fastened).
  final double seatbeltFastened;

  /// Drowsiness score — 0 (alert) … 1 (drowsy). Proxy for PERCLOS.
  final double fatigueScore;

  /// Acoustic anomaly score — 0 (nominal) … 1 (anomalous engine sound).
  final double acousticAnomaly;

  final DateTime timestamp;

  /// Alertness is the inverse of the fatigue score.
  double get alertness => 1.0 - fatigueScore;

  /// True when any safety signal crosses its warning threshold.
  bool get hasWarning =>
      seatbeltFastened < 0.5 || fatigueScore > 0.6 || acousticAnomaly > 0.6;

  static SafetyReading initial() => SafetyReading(
        seatbeltFastened: 1.0,
        fatigueScore: 0.0,
        acousticAnomaly: 0.0,
        timestamp: DateTime.now(),
      );
}
