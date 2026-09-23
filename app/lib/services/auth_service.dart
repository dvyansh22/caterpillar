import '../data/models.dart';

/// Auth abstraction so the UI is identical for mock and Firebase.
/// [MockAuthService] is the default; [FirebaseAuthService] activates once a Firebase
/// project is configured (see docs/FIREBASE_SETUP.md). FR-AUTH-1/2.
abstract class AuthService {
  /// Signs in and returns the operator's profile, or throws [AuthException].
  Future<OperatorUser> signIn(String username, String password);

  Future<void> signOut();
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
