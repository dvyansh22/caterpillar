import '../data/mock_data.dart';
import '../data/models.dart';
import 'auth_service.dart';

/// Default auth: validates against the demo accounts (arjun/bala). Any non-empty
/// password is accepted. Mirrors the design prototype's copy.
class MockAuthService implements AuthService {
  @override
  Future<OperatorUser> signIn(String username, String password) async {
    final u = username.trim().toLowerCase();
    if (!kUsers.containsKey(u)) {
      throw AuthException('Unknown username. Use arjun or bala.');
    }
    if (password.isEmpty) {
      throw AuthException('Enter your password.');
    }
    return kUsers[u]!;
  }

  @override
  Future<void> signOut() async {}
}
