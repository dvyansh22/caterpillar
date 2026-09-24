import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/mock_data.dart';
import '../data/models.dart';
import 'data_repository.dart';

/// Firestore-backed data. Reads `tasks` (filtered by vertical), writes `incidents`
/// and `training`. Collections + rules are defined in firebase/.
class FirebaseDataRepository implements DataRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<List<OperatorTask>> getTasks(Vertical vertical) async {
    final vs = vertical == Vertical.mining ? 'mining' : 'construction';
    final snap = await _db.collection('tasks').where('vertical', isEqualTo: vs).get();
    final tasks = snap.docs.map((d) {
      final m = d.data();
      return OperatorTask(
        id: (m['id'] ?? d.id) as String,
        type: (m['type'] ?? '') as String,
        location: (m['location'] ?? '') as String,
        weather: (m['weather'] ?? '') as String,
        age: (m['age'] as num?)?.toInt() ?? 0,
        est: (m['est'] as num?)?.toInt() ?? 0,
        eta: (m['eta'] as num?)?.toInt() ?? 0,
      );
    }).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    // Fall back to seed data if the collection hasn't been populated yet.
    return tasks.isEmpty ? kTasks[vertical]! : tasks;
  }

  @override
  Future<void> addIncident(OperatorUser user, String taskId, VoiceLog log) async {
    await _db.collection('incidents').add({
      'operatorId': user.opId,
      'machineId': user.machineId,
      'vertical': user.vertical == Vertical.mining ? 'mining' : 'construction',
      'taskId': taskId,
      'text': log.text,
      'timeIntoTask': log.time,
      'sync': log.sync,
      'ts': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> saveTrainingScore(OperatorUser user, String lessonId, String title, int score) async {
    await _db.collection('training').doc('${user.opId}_$lessonId').set({
      'operatorId': user.opId,
      'lessonId': lessonId,
      'title': title,
      'score': score,
      'vertical': user.vertical == Vertical.mining ? 'mining' : 'construction',
      'date': 'Today',
      'ts': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<IncidentRecord>> readIncidents(Vertical vertical) async {
    final vs = vertical == Vertical.mining ? 'mining' : 'construction';
    // Filter by vertical only (no orderBy, so no composite index needed); sort client-side.
    final snap = await _db.collection('incidents').where('vertical', isEqualTo: vs).get();
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final ta = a.data()['ts'], tb = b.data()['ts'];
        if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta); // newest first
        return 0;
      });
    return docs.take(25).map((d) {
      final m = d.data();
      final ts = m['ts'];
      final time = ts is Timestamp ? _hhmm(ts.toDate()) : (m['timeIntoTask'] ?? '') as String;
      final sev = (m['severity'] ?? 'observation') as String;
      final text = (m['text'] ?? '') as String;
      // Live voice logs are observations; transcript defaults to the log text.
      final kind = (m['kind'] as String?) ?? 'observation';
      return IncidentRecord(
        text: text,
        machineId: (m['machineId'] ?? '') as String,
        time: time,
        severity: sev,
        operatorId: (m['operatorId'] ?? '') as String,
        kind: kind,
        location: (m['location'] ?? '') as String,
        gps: (m['gps'] ?? '') as String,
        transcript: (m['transcript'] ?? text) as String,
      );
    }).toList();
  }

  @override
  Future<List<TrainingRecord>> readTraining(Vertical vertical) async {
    final snap = await _db.collection('training').get(); // not all records are vertical-tagged
    return snap.docs.map((d) {
      final m = d.data();
      return TrainingRecord(
        operatorId: (m['operatorId'] ?? '') as String,
        lessonId: (m['lessonId'] ?? d.id) as String,
        title: (m['title'] ?? '') as String,
        score: (m['score'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
