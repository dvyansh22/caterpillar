/// Build-time flag to switch from mock auth/data to Firebase.
/// Enable with: `flutter run --dart-define=USE_FIREBASE=true` (after docs/FIREBASE_SETUP.md).
const kUseFirebase = bool.fromEnvironment('USE_FIREBASE', defaultValue: false);
