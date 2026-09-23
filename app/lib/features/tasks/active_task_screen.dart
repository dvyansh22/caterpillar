import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'task_model.dart';

/// FR-TASK-3 + FR-VOICE-1 — active task view with elapsed time and a voice-log button.
/// Voice capture is a placeholder (adds a mock entry). Real ASR (sherpa-onnx) in P4 task 5.
class ActiveTaskScreen extends ConsumerStatefulWidget {
  const ActiveTaskScreen({super.key, required this.taskId});
  final String taskId;

  @override
  ConsumerState<ActiveTaskScreen> createState() => _ActiveTaskScreenState();
}

class _ActiveTaskScreenState extends ConsumerState<ActiveTaskScreen> {
  Timer? _timer;
  int _elapsedSec = 0;
  bool _recording = false;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSec++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleRecording() {
    setState(() => _recording = !_recording);
    if (!_recording) {
      final now = TimeOfDay.now().format(context);
      setState(() => _logs.insert(0, 'Voice note logged at $now (placeholder transcript)'));
    }
  }

  String _fmt(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final task = tasks.firstWhere(
      (t) => t.id == widget.taskId,
      orElse: () => const OperatorTask(id: '?', name: 'Task', etaMinutes: 0, location: '—'),
    );
    final progress = task.etaMinutes == 0 ? 0.0 : (_elapsedSec / (task.etaMinutes * 60)).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: Text(task.name), leading: BackButton(onPressed: () => context.go('/home/tasks'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('Elapsed', style: Theme.of(context).textTheme.bodyMedium),
                    Text(_fmt(_elapsedSec), style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: progress, minHeight: 8),
                    const SizedBox(height: 6),
                    Text('Estimated ${task.etaMinutes} min · ${task.location}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _recording ? SafetyColors.danger : Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: Icon(_recording ? Icons.stop : Icons.mic,
                      size: 52, color: _recording ? Colors.white : Theme.of(context).colorScheme.onPrimaryContainer),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text(_recording ? 'Recording… tap to stop' : 'Tap to add a voice log')),
            const SizedBox(height: 20),
            if (_logs.isNotEmpty) ...[
              Text('Voice logs', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._logs.map((l) => Card(
                    child: ListTile(leading: const Icon(Icons.graphic_eq), title: Text(l)),
                  )),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/home/tasks'),
                    icon: const Icon(Icons.report_outlined),
                    label: const Text('Report Incident'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.go('/home/tasks'),
                    icon: const Icon(Icons.check),
                    label: const Text('Complete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
