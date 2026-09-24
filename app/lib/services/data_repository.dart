import '../data/models.dart';

/// Data abstraction for tasks / incidents / training — mock or Firestore.
/// Same swappable pattern as [AuthService]; selected by USE_FIREBASE.
abstract class DataRepository {
  /// Today's tasks for a vertical (ETA is the ML prediction; mocked for now).
  Future<List<OperatorTask>> getTasks(Vertical vertical);

  /// Persist a voice observation as an incident (FR-VOICE-2).
  Future<void> addIncident(OperatorUser user, String taskId, VoiceLog log);

  /// Persist a completed lesson's score to the training record.
  Future<void> saveTrainingScore(OperatorUser user, String lessonId, String title, int score);

  /// Recent incidents/observations for a vertical (owner dashboard feed, FR-DASH-1).
  Future<List<IncidentRecord>> readIncidents(Vertical vertical);

  /// Completed-lesson records for a vertical (owner dashboard training compliance).
  Future<List<TrainingRecord>> readTraining(Vertical vertical);
}
