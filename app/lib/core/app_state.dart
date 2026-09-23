import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimal session state for the scaffold. Real auth (Firebase Auth + custom claims)
/// replaces this in P4 task 2 — keep the shape so screens don't change.
class SessionState {
  const SessionState({
    this.loggedIn = false,
    this.gatePassed = false,
    this.operatorName = '',
    this.operatorId = '',
    this.machineId = '',
    this.skillLevel = 'Intermediate',
  });

  final bool loggedIn;
  final bool gatePassed;
  final String operatorName;
  final String operatorId;
  final String machineId;
  final String skillLevel;

  SessionState copyWith({
    bool? loggedIn,
    bool? gatePassed,
    String? operatorName,
    String? operatorId,
    String? machineId,
    String? skillLevel,
  }) {
    return SessionState(
      loggedIn: loggedIn ?? this.loggedIn,
      gatePassed: gatePassed ?? this.gatePassed,
      operatorName: operatorName ?? this.operatorName,
      operatorId: operatorId ?? this.operatorId,
      machineId: machineId ?? this.machineId,
      skillLevel: skillLevel ?? this.skillLevel,
    );
  }
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  /// Mock login — TODO(P4): replace with Firebase Auth + custom claims.
  void login(String username) {
    state = state.copyWith(
      loggedIn: true,
      operatorName: username.isEmpty ? 'Operator' : username,
      operatorId: 'OP1001',
      machineId: 'EXC001',
    );
  }

  void passGate() => state = state.copyWith(gatePassed: true);

  void logout() => state = const SessionState();
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
