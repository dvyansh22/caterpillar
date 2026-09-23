import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/nav.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../services/ml_client/ml_providers.dart';

/// 04 Tasks list (FR-TASK-1/2). Cards show the ML-predicted ETA.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final tasks = ref.watch(tasksProvider);
    final app = ref.watch(appProvider);
    final acc = user.accent;
    final total = tasks.fold<int>(0, (a, t) => a + t.eta);
    final summary = '${tasks.length} tasks · ${total ~/ 60} h ${total % 60} min';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        Text(_todayString(), style: const TextStyle(fontSize: 14, color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(summary, style: const TextStyle(fontSize: 26, height: 32 / 26, color: AppColors.ink).merge(kTabular)),
        const SizedBox(height: 4),
        Text('Times predicted by the task-time model for ${user.first} on ${user.machineId}',
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 12),
        ...tasks.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TaskCard(task: t, acc: acc, app: app),
            )),
      ],
    );
  }

  static String _todayString() {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final n = DateTime.now();
    return '${days[n.weekday - 1]}, ${n.day} ${months[n.month - 1]}';
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task, required this.acc, required this.app});
  final OperatorTask task;
  final AccentPalette acc;
  final AppData app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live ML ETA (falls back to the seed value while loading / offline).
    final est = ref.watch(taskEstimateProvider(task.id)).asData?.value;
    final etaMin = (est != null && est.modelVersion != 'stub-0') ? est.estimatedMinutes.round() : task.eta;
    final isActive = app.activeTaskId == task.id;
    final isDone = app.done.containsKey(task.id);
    final status = isActive ? 'In progress' : isDone ? 'Done' : 'Scheduled';
    final (Color chipBg, Color chipInk) = isActive
        ? (acc.base, AppColors.ink)
        : isDone
            ? (AppColors.successBg, AppColors.successInk)
            : (AppColors.surface2, AppColors.muted);

    return Opacity(
      opacity: isDone ? 0.6 : 1,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kRadiusCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusCard),
          onTap: () {
            final n = ref.read(navProvider.notifier);
            if (isActive) {
              n.openActiveTask();
            } else {
              n.openTaskDetail(task.id);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadiusCard),
              border: Border.all(color: isActive ? acc.base : AppColors.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(task.id, style: const TextStyle(fontSize: 12, color: AppColors.muted).merge(kMono)),
                          const SizedBox(width: 8),
                          Container(
                            height: 22,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(kRadiusChip)),
                            child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: chipInk)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(task.type, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.ink)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.place_outlined, size: 16, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Expanded(child: Text(task.location, style: const TextStyle(fontSize: 14, color: AppColors.muted))),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  constraints: const BoxConstraints(minWidth: 76),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(color: acc.tint, borderRadius: BorderRadius.circular(kRadiusSmall)),
                  child: Column(
                    children: [
                      Text('$etaMin',
                          style: TextStyle(fontSize: 28, height: 32 / 28, fontWeight: FontWeight.w500, color: acc.ink).merge(kTabular)),
                      Text('min', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: acc.ink)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
