import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/nav.dart';
import '../../core/tokens.dart';

/// 05 Task detail — estimate panel + inputs + start.
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final tasks = ref.watch(tasksProvider);
    final app = ref.watch(appProvider);
    final acc = user.accent;
    final selId = ref.watch(navProvider.select((s) => s.selId));
    final task = tasks.firstWhere((t) => t.id == selId, orElse: () => tasks.first);

    final activeId = app.activeTaskId;
    final isDone = app.done.containsKey(task.id);
    final blocked = activeId != null && activeId != task.id;
    final cantStart = activeId != null || isDone;

    final delta = task.eta == task.est
        ? 'Same as the planner baseline.'
        : '${(task.eta - task.est).abs()} min ${task.eta > task.est ? 'longer' : 'shorter'} than the planner baseline, '
            'based on ${task.weather.toLowerCase()} weather, your skill level and machine age.';

    final String btnLabel = isDone
        ? 'Completed in ${app.done[task.id]} min.'
        : blocked
            ? 'Finish $activeId before starting another task.'
            : '▶  Start task';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        _backLink('‹  All tasks', () => ref.read(navProvider.notifier).backToList()),
        const SizedBox(height: 8),
        Text(task.id, style: const TextStyle(fontSize: 13, color: AppColors.muted).merge(kMono)),
        const SizedBox(height: 4),
        Text(task.type, style: const TextStyle(fontSize: 30, height: 38 / 30, color: AppColors.ink)),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.place_outlined, size: 18, color: AppColors.muted),
          const SizedBox(width: 4),
          Expanded(child: Text(task.location, style: const TextStyle(fontSize: 15, color: AppColors.muted))),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: acc.tint, borderRadius: BorderRadius.circular(kRadiusCard)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estimated time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: acc.ink)),
              const SizedBox(height: 4),
              Text('${task.eta} min',
                  style: TextStyle(fontSize: 52, height: 60 / 52, fontWeight: FontWeight.w500, color: acc.ink).merge(kTabular)),
              const SizedBox(height: 8),
              Text(delta, style: TextStyle(fontSize: 14, height: 20 / 14, color: acc.ink)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _infoList([
          ('Weather', task.weather),
          ('Machine', '${user.machineId} · ${task.age} yrs'),
          ('Operator skill', user.skill),
          ('Planner baseline', '${task.est} min'),
        ]),
        const SizedBox(height: 16),
        Opacity(
          opacity: cantStart ? 0.4 : 1,
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: FilledButton(
              onPressed: cantStart
                  ? null
                  : () {
                      ref.read(appProvider.notifier).startTask(task.id);
                      ref.read(navProvider.notifier).openActiveTask();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: acc.base,
                foregroundColor: AppColors.ink,
                disabledBackgroundColor: acc.base,
                disabledForegroundColor: AppColors.ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
              child: Text(btnLabel),
            ),
          ),
        ),
      ],
    );
  }

  Widget _backLink(String text, VoidCallback onTap) => Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Text(text, style: const TextStyle(fontSize: 15, color: AppColors.ink2)),
          ),
        ),
      );

  Widget _infoList(List<(String, String)> rows) => Container(
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(kRadiusCard)),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: i == rows.length - 1
                      ? null
                      : const Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(rows[i].$1, style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                    Text(rows[i].$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink)),
                  ],
                ),
              ),
          ],
        ),
      );
}
