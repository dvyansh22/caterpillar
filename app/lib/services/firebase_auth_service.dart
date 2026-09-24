import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/models.dart';
import 'auth_service.dart';

/// Real auth: Firebase Auth (email/password) + a Firestore `users/{uid}` profile.
/// Activated when the app is built with --dart-define=USE_FIREBASE=true and a
/// Firebase project is configured (docs/FIREBASE_SETUP.md).
///
/// Demo accounts are created in Firebase with emails like `arjun@smartoperator.demo`;
/// a bare username is expanded to that domain.
class FirebaseAuthService implements AuthService {
  static const _demoDomain = 'smartoperator.demo';

  @override
  Future<OperatorUser> signIn(String username, String password) async {
    final email = username.contains('@') ? username.trim() : '${username.trim().toLowerCase()}@$_demoDomain';
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      final uid = cred.user!.uid;
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!snap.exists) {
        throw AuthException('No operator profile found for this account.');
      }
      return _userFromDoc(username.trim().toLowerCase(), snap.data()!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e.code));
    }
  }

  @override
  Future<OperatorUser?> currentUser() async {
    final u = FirebaseAuth.instance.currentUser;
    // Ignore anonymous sessions (used by the web dashboard) — they have no profile.
    if (u == null || u.isAnonymous) return null;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
      if (!snap.exists) return null;
      final username = (u.email ?? '').split('@').first;
      return _userFromDoc(username, snap.data()!);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> signOut() => FirebaseAuth.instance.signOut();

  String _mapError(String code) => switch (code) {
        'user-not-found' || 'invalid-email' => 'Unknown username. Use arjun or bala.',
        'wrong-password' || 'invalid-credential' => 'Wrong password. Try again.',
        'missing-password' => 'Enter your password.',
        _ => 'Sign-in failed. Check your connection and try again.',
      };

  OperatorUser _userFromDoc(String username, Map<String, dynamic> d) {
    final verticalStr = (d['vertical'] as String?)?.toLowerCase() ?? 'construction';
    final passport = (d['passport'] as List?)
            ?.map((e) => PassportEntry(
                  title: (e['title'] ?? '') as String,
                  date: (e['date'] ?? '') as String,
                  score: (e['score'] ?? 0) as int,
                ))
            .toList() ??
        const [];
    return OperatorUser(
      username: username,
      name: (d['name'] ?? '') as String,
      first: (d['first'] ?? '') as String,
      initial: (d['initial'] ?? (d['first'] ?? '?').toString().substring(0, 1)) as String,
      opId: (d['opId'] ?? '') as String,
      vertical: verticalStr == 'mining' ? Vertical.mining : Vertical.construction,
      machineId: (d['machineId'] ?? '') as String,
      machine: (d['machine'] ?? '') as String,
      site: (d['site'] ?? '') as String,
      siteShort: (d['siteShort'] ?? '') as String,
      source: (d['source'] ?? '') as String,
      skill: (d['skill'] ?? '') as String,
      gps: (d['gps'] ?? '') as String,
      session: (d['session'] ?? '') as String,
      supervisor: (d['supervisor'] ?? 'supervisor') as String,
      passport: passport,
      flag: (d['flag'] ?? '') as String,
      voice: (d['voice'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}
