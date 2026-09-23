/// Riverpod providers for the Learning Hub feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/training_module.dart';

/// All available training modules.
final trainingModulesProvider = StateNotifierProvider<TrainingModulesNotifier, List<TrainingModule>>(
  (ref) => TrainingModulesNotifier(),
);

class TrainingModulesNotifier extends StateNotifier<List<TrainingModule>> {
  TrainingModulesNotifier() : super(DefaultModules.all);

  /// Mark a step as completed in a module.
  void completeStep(String moduleId, int stepIndex, double score) {
    state = [
      for (final module in state)
        if (module.id == moduleId)
          module.copyWith(
            status: stepIndex >= module.steps.length - 1
                ? ModuleStatus.completed
                : ModuleStatus.inProgress,
            completedSteps: stepIndex + 1,
            bestScore: score > module.bestScore ? score : module.bestScore,
          )
        else
          module,
    ];
  }

  /// Reset progress for a module.
  void resetModule(String moduleId) {
    state = [
      for (final module in state)
        if (module.id == moduleId)
          module.copyWith(
            status: ModuleStatus.available,
            completedSteps: 0,
            bestScore: 0,
          )
        else
          module,
    ];
  }
}

/// The currently active lesson (module ID + current step).
final activeLessonProvider = StateProvider<({String moduleId, int step})?>((ref) => null);

/// Overall training progress (0.0 – 1.0).
final trainingProgressProvider = Provider<double>((ref) {
  final modules = ref.watch(trainingModulesProvider);
  if (modules.isEmpty) return 0;
  final totalSteps = modules.fold<int>(0, (sum, m) => sum + m.steps.length);
  final completedSteps = modules.fold<int>(0, (sum, m) => sum + m.completedSteps);
  return totalSteps == 0 ? 0 : completedSteps / totalSteps;
});
