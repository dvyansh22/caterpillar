import '../data/mock_data.dart';
import '../data/models.dart';
import 'data_repository.dart';

/// Default data source: static mock data; writes are no-ops (kept in memory by AppController).
class MockDataRepository implements DataRepository {
  @override
  Future<List<OperatorTask>> getTasks(Vertical vertical) async => kTasks[vertical]!;

  @override
  Future<void> addIncident(OperatorUser user, String taskId, VoiceLog log) async {}

  @override
  Future<void> saveTrainingScore(OperatorUser user, String lessonId, String title, int score) async {}

  @override
  Future<List<IncidentRecord>> readIncidents(Vertical vertical) async => const [];

  @override
  Future<List<TrainingRecord>> readTraining(Vertical vertical) async => const [];
}
