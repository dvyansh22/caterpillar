/// Core configuration — vertical enum and app-wide settings.
library;

/// The two operational verticals. Drives theming, task types, safety rules,
/// and training catalog per DESIGN.md §4.7.
enum Vertical {
  construction,
  mining;

  String get displayName => switch (this) {
    Vertical.construction => 'Construction',
    Vertical.mining => 'Mining',
  };

  String get tagline => switch (this) {
    Vertical.construction => 'Build Smarter',
    Vertical.mining => 'Mine Safer',
  };
}

/// Shared constants — API URLs, asset paths, BLE UUIDs.
abstract final class AppConstants {
  /// FastAPI backend base URL (change for prod / Cloud Run).
  static const String apiBaseUrl = 'http://localhost:8000';

  /// TFLite model asset paths (loaded when P2 delivers models).
  static const String seatbeltModelPath = 'assets/models/seatbelt.tflite';
  static const String fatigueModelPath = 'assets/models/fatigue.tflite';
  static const String acousticModelPath = 'assets/models/acoustic.tflite';

  /// BLE SOS service UUID (shared with all phones running the app).
  static const String sosBleServiceUuid = '0000FE01-0000-1000-8000-00805F9B34FB';

  /// Unity↔Flutter message channel name.
  static const String unityMessageChannel = 'SmartOperatorAR';
}
