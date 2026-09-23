/// Build-time flag to switch from mock auth/data to Firebase.
/// Enable with: `flutter run --dart-define=USE_FIREBASE=true` (after docs/FIREBASE_SETUP.md).
const kUseFirebase = bool.fromEnvironment('USE_FIREBASE', defaultValue: false);

/// Shared constants — API URLs, asset paths, BLE UUIDs, AR channel.
/// (Merged from P3's integration; `Vertical` lives in `data/models.dart`.)
abstract final class AppConstants {
  /// FastAPI backend base URL (override for Cloud Run).
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');

  /// On-device TFLite model asset paths (tensor contract: ml/ondevice/README.md, PR #3).
  static const String seatbeltModelPath = 'assets/models/seatbelt.tflite';
  static const String acousticModelPath = 'assets/models/acoustic_anomaly.tflite';

  /// BLE SOS service UUID (shared across phones running the app).
  static const String sosBleServiceUuid = '0000FE01-0000-1000-8000-00805F9B34FB';

  /// Unity ↔ Flutter message channel name.
  static const String unityMessageChannel = 'SmartOperatorAR';
}
