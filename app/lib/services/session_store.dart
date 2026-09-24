import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';

/// A restorable operator session (the parts of AppData worth surviving a restart).
class SavedSession {
  const SavedSession({
    required this.username,
    this.activeTaskId,
    this.activeStartMs,
    this.done = const {},
    this.logs = const {},
    this.completed = const {},
  });

  final String username;
  final String? activeTaskId;
  final int? activeStartMs;
  final Map<String, int> done;
  final Map<String, List<VoiceLog>> logs;
  final Map<String, int> completed;
}

/// Local persistence for the operator session so the app doesn't lose progress
/// (active task, done tasks, observations, lesson scores) when it's reopened.
/// Stored as one JSON blob in SharedPreferences.
class SessionStore {
  static const _key = 'operator_session_v1';
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _instance() async => _prefs ??= await SharedPreferences.getInstance();

  static Future<void> save(SavedSession s) async {
    final prefs = await _instance();
    final map = {
      'username': s.username,
      'activeTaskId': s.activeTaskId,
      'activeStartMs': s.activeStartMs,
      'done': s.done,
      'completed': s.completed,
      'logs': s.logs.map((taskId, list) =>
          MapEntry(taskId, list.map((l) => {'text': l.text, 'time': l.time, 'sync': l.sync}).toList())),
    };
    await prefs.setString(_key, jsonEncode(map));
  }

  static Future<SavedSession?> load() async {
    final prefs = await _instance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final username = m['username'] as String?;
      if (username == null || username.isEmpty) return null;
      final doneRaw = (m['done'] as Map?) ?? const {};
      final done = <String, int>{
        for (final e in doneRaw.entries) e.key as String: (e.value as num).toInt(),
      };
      final completedRaw = (m['completed'] as Map?) ?? const {};
      final completed = <String, int>{
        for (final e in completedRaw.entries) e.key as String: (e.value as num).toInt(),
      };
      final logsRaw = (m['logs'] as Map?) ?? const {};
      final logs = <String, List<VoiceLog>>{
        for (final e in logsRaw.entries)
          e.key as String: [
            for (final l in (e.value as List))
              VoiceLog(
                text: (l['text'] ?? '') as String,
                time: (l['time'] ?? '') as String,
                sync: (l['sync'] ?? '') as String,
              ),
          ],
      };
      return SavedSession(
        username: username,
        activeTaskId: m['activeTaskId'] as String?,
        activeStartMs: (m['activeStartMs'] as num?)?.toInt(),
        done: done,
        logs: logs,
        completed: completed,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await _instance();
    await prefs.remove(_key);
  }
}
