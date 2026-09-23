/// Learning Hub — module list screen.
///
/// Shows available AR training modules with progress, difficulty,
/// and everyday-object mapping info. P3 owns this feature.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'screens/ar_training_screen.dart';
import 'screens/combined_training_screen.dart';
import 'models/training_module.dart';
import 'providers/learning_hub_providers.dart';

class LearningHubScreen extends ConsumerWidget {
  const LearningHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(trainingModulesProvider);
    final overallProgress = ref.watch(trainingProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Hub'),
      ),
      body: CustomScrollView(
        slivers: [
          // Overall progress header
          SliverToBoxAdapter(
            child: _ProgressHeader(progress: overallProgress),
          ),

          // Section title
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'AR Training Modules',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: CatColors.textPrimary,
                ),
              ),
            ),
          ),

          // Module cards
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: modules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final module = modules[index];
                return _ModuleCard(
                  module: module,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => module.id == 'combined_control'
                          ? const CombinedTrainingScreen()
                          : ArTrainingScreen(moduleId: module.id),
                    ),
                  ),
                );
              },
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress header
// ---------------------------------------------------------------------------

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (progress * 100).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.15),
            theme.colorScheme.secondary.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skills Passport',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$percentage% complete',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CatColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Circular progress
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(
                        theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.12),
              valueColor:
                  AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Module card
// ---------------------------------------------------------------------------

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.onTap});

  final TrainingModule module;
  final VoidCallback onTap;

  IconData _iconForName(String name) => switch (name) {
    'sports_esports' => Icons.sports_esports_rounded,
    'speed' => Icons.speed_rounded,
    'construction' => Icons.construction_rounded,
    'build' => Icons.build_rounded,
    'tune' => Icons.tune_rounded,
    _ => Icons.school_rounded,
  };

  Color _difficultyColor(ModuleDifficulty d) => switch (d) {
    ModuleDifficulty.beginner => CatColors.success,
    ModuleDifficulty.intermediate => CatColors.warning,
    ModuleDifficulty.advanced => CatColors.danger,
  };

  String _difficultyLabel(ModuleDifficulty d) => switch (d) {
    ModuleDifficulty.beginner => 'Beginner',
    ModuleDifficulty.intermediate => 'Intermediate',
    ModuleDifficulty.advanced => 'Advanced',
  };

  String _statusLabel(ModuleStatus s) => switch (s) {
    ModuleStatus.locked => 'Locked',
    ModuleStatus.available => 'Start',
    ModuleStatus.inProgress => 'Continue',
    ModuleStatus.completed => 'Completed',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diffColor = _difficultyColor(module.difficulty);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: module.status == ModuleStatus.locked ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: icon + title + difficulty badge
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconForName(module.iconName),
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (module.everydayObject != null)
                          Text(
                            '${module.everydayObject} → ${module.machineControl}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: CatColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Difficulty chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: diffColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _difficultyLabel(module.difficulty),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: diffColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                module.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: CatColors.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 14),

              // Progress bar + action button
              Row(
                children: [
                  // Progress
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${module.completedSteps}/${module.steps.length} steps',
                          style: const TextStyle(
                            fontSize: 12,
                            color: CatColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: module.progressPercent,
                            minHeight: 4,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation(
                              module.status == ModuleStatus.completed
                                  ? CatColors.success
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Action button
                  FilledButton.tonal(
                    onPressed:
                        module.status == ModuleStatus.locked ? null : onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: module.status == ModuleStatus.completed
                          ? CatColors.success.withValues(alpha: 0.15)
                          : theme.colorScheme.primary.withValues(alpha: 0.15),
                      foregroundColor: module.status == ModuleStatus.completed
                          ? CatColors.success
                          : theme.colorScheme.primary,
                    ),
                    child: Text(_statusLabel(module.status)),
                  ),
                ],
              ),

              // Best score (if any)
              if (module.bestScore > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 16, color: CatColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      'Best: ${module.bestScore.round()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CatColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
