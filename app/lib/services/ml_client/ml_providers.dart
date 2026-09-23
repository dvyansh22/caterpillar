/// Riverpod providers for the ML client.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../data/models.dart';
import 'ml_client.dart';
import 'ml_models.dart';

/// The ML client singleton.
final mlClientProvider = Provider<MlClient>((ref) {
  final client = MlClient();
  ref.onDispose(client.dispose);
  return client;
});

/// Live task-time ETA from the model backend for one task.
///
/// Builds the request from the task and the signed-in operator and calls
/// `/ml/estimate`. `getEstimate` never throws (it returns an offline stub with
/// `model_version == 'stub-0'` when the backend is unreachable), so the UI can
/// tell a live prediction from the offline fallback by the model version.
final taskEstimateProvider =
    FutureProvider.autoDispose.family<EstimateResponse, String>((ref, taskId) async {
  final tasks = ref.watch(tasksProvider);
  final user = ref.watch(currentUserProvider);
  final task = tasks.firstWhere((t) => t.id == taskId, orElse: () => tasks.first);
  return ref.read(mlClientProvider).getEstimate(EstimateRequest(
        taskType: task.type,
        weather: task.weather,
        operatorSkill: user.skill,
        machineAgeYears: task.age.toDouble(),
        vertical: user.vertical == Vertical.mining ? 'mining' : 'construction',
      ));
});
