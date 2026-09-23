import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/vertical.dart';
import 'task_model.dart';

/// FR-TASK-1 — daily task dashboard. Cards show name, ML-ETA, location; tap to start.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final vertical = ref.watch(verticalProvider);
    final tasks = ref.watch(tasksProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hi, ${session.operatorName.isEmpty ? 'Operator' : session.operatorName}',
                          style: Theme.of(context).textTheme.headlineSmall),
                      Text('${session.machineId.isEmpty ? '—' : session.machineId} · ${vertical.label}',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(Icons.wb_sunny_outlined, size: 18, color: vertical.accent),
                  label: const Text('Sunny · 31°C'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Today’s tasks', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...tasks.map((t) => _TaskCard(task: t, accent: vertical.accent)),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.accent});
  final OperatorTask task;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/task/${task.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.construction, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 16),
                        const SizedBox(width: 4),
                        Expanded(child: Text(task.location, style: Theme.of(context).textTheme.bodySmall)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('~${task.etaMinutes} min'),
                  ),
                  const SizedBox(height: 4),
                  Text(task.status, style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
