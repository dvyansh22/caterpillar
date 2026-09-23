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
      'date': 'Today',
      'ts': FieldValue.serverTimestamp(),
    });
  }
}
