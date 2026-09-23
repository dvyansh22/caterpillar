import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../data/models.dart';
import 'tokens.dart';

enum GateStatus { pending, busy, pass, fail }

/// Central mutable app state, mirroring the design prototype's logic class.
/// TODO: back with Firebase (session/tasks/incidents/training) + /ml/estimate.
class AppData {
  const AppData({
    this.username = 'arjun',
    this.activeTaskId,
    this.activeStartMs,
    this.done = const {},
    this.logs = const {},
    this.completed = const {},
    this.sosStartedMs,
  });

  final String username;
  final String? activeTaskId;
  final int? activeStartMs;
  final Map<String, int> done; // taskId -> minutes
  final Map<String, List<VoiceLog>> logs; // taskId -> observations
  final Map<String, int> completed; // lessonId -> score
  final int? sosStartedMs;

  AppData copyWith({
    String? username,
    Object? activeTaskId = _sentinel,
    Object? activeStartMs = _sentinel,
    Map<String, int>? done,
    Map<String, List<VoiceLog>>? logs,
    Map<String, int>? completed,
    Object? sosStartedMs = _sentinel,
  }) {
    return AppData(
      username: username ?? this.username,
      activeTaskId: activeTaskId == _sentinel ? this.activeTaskId : activeTaskId as String?,
      activeStartMs: activeStartMs == _sentinel ? this.activeStartMs : activeStartMs as int?,
      done: done ?? this.done,
      logs: logs ?? this.logs,
      completed: completed ?? this.completed,
      sosStartedMs: sosStartedMs == _sentinel ? this.sosStartedMs : sosStartedMs as int?,
    );
  }

  static const _sentinel = Object();
}

class AppController extends Notifier<AppData> {
  @override
  AppData build() => const AppData();

  OperatorUser get user => kUsers[state.username] ?? kUsers['arjun']!;

  void setUsername(String username) => state = state.copyWith(username: username);

  void logout() => state = const AppData();

  void startTask(String id) =>
      state = state.copyWith(activeTaskId: id, activeStartMs: DateTime.now().millisecondsSinceEpoch);

  /// Marks the active task done with its real elapsed minutes.
  void endTask() {
    final id = state.activeTaskId;
    if (id == null) return;
    final startedMs = state.activeStartMs ?? DateTime.now().millisecondsSinceEpoch;
    final mins = ((DateTime.now().millisecondsSinceEpoch - startedMs) / 60000).round().clamp(1, 999);
    state = state.copyWith(
      done: {...state.done, id: mins},
      activeTaskId: null,
      activeStartMs: null,
    );
  }

  void addVoiceLog(String taskId, VoiceLog log) {
    final existing = state.logs[taskId] ?? const [];
    state = state.copyWith(logs: {...state.logs, taskId: [log, ...existing]});
  }

  void completeLesson(String lessonId, int score) =>
      state = state.copyWith(completed: {...state.completed, lessonId: score});

  void startSos() => state = state.copyWith(sosStartedMs: DateTime.now().millisecondsSinceEpoch);
  void cancelSos() => state = state.copyWith(sosStartedMs: null);
}

final appProvider = NotifierProvider<AppController, AppData>(AppController.new);

/// The signed-in user (derived from the demo username).
final currentUserProvider = Provider<OperatorUser>((ref) {
  final username = ref.watch(appProvider.select((s) => s.username));
  return kUsers[username] ?? kUsers['arjun']!;
});

/// Accent palette for the current vertical.
final accentProvider = Provider<AccentPalette>((ref) => ref.watch(currentUserProvider).accent);

/// Today's tasks for the current vertical.
final tasksProvider = Provider<List<OperatorTask>>((ref) {
  final vertical = ref.watch(currentUserProvider).vertical;
  return kTasks[vertical]!;
});
