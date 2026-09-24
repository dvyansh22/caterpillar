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
        Row(
          children: [
            SizedBox(
              width: 26,
              height: 7,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: CustomPaint(painter: _HazardStripePainter(acc.base)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_todayString().toUpperCase(),
                  style: oswald(size: 12, weight: FontWeight.w600, spacing: 1.4, color: acc.base)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(summary.toUpperCase(),
            style: oswald(size: 26, weight: FontWeight.w700, spacing: 0.4, height: 29 / 26, color: AppColors.ink)),
        const SizedBox(height: 6),
        Text('Times predicted by the task-time model for ${user.first} on ${user.machineId}',
            style: inter(size: 13, color: AppColors.muted, height: 18 / 13)),
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

/// Yellow hazard-stripe mark: 45° accent stripes, ~4px on / 4px off.
class _HazardStripePainter extends CustomPainter {
  _HazardStripePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const stripe = 4.0;
    const period = stripe * 2;
    for (double x = -size.height; x < size.width + size.height; x += period) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + stripe, 0)
        ..lineTo(x + stripe + size.height, size.height)
        ..lineTo(x + size.height, size.height)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _HazardStripePainter old) => old.color != color;
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
        ? (acc.base, AppColors.onAccent)
        : isDone
            ? (AppColors.successBg, AppColors.successInk)
            : (AppColors.surface2, AppColors.ink2);

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
                          Text(task.id, style: mono(size: 12, color: AppColors.muted)),
                          const SizedBox(width: 8),
                          Container(
                            height: 22,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(kRadiusChip)),
                            child: Text(status.toUpperCase(),
                                style: oswald(size: 11, weight: FontWeight.w600, spacing: 0.8, color: chipInk)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(task.type, style: inter(size: 18, weight: FontWeight.w600, color: AppColors.ink)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.place_outlined, size: 16, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Expanded(child: Text(task.location, style: inter(size: 14, color: AppColors.muted))),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  constraints: const BoxConstraints(minWidth: 76),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(color: acc.tint, borderRadius: BorderRadius.circular(kRadiusChip)),
                  child: Column(
                    children: [
                      Text('$etaMin',
                          style: oswald(size: 28, weight: FontWeight.w700, spacing: 0, height: 32 / 28, color: acc.ink)
                              .merge(kTabular)),
                      Text('MIN', style: oswald(size: 12, weight: FontWeight.w500, spacing: 0.8, color: acc.ink)),
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
