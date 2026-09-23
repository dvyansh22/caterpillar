import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/nav.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';

/// 06 Active task — elapsed time + voice log (FR-TASK-3, FR-VOICE-1/2).
class ActiveTaskScreen extends ConsumerStatefulWidget {
  const ActiveTaskScreen({super.key});

  @override
  ConsumerState<ActiveTaskScreen> createState() => _ActiveTaskScreenState();
}

class _ActiveTaskScreenState extends ConsumerState<ActiveTaskScreen> with SingleTickerProviderStateMixin {
  Timer? _tick;
  Timer? _recTimer;
  bool _recording = false;
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _recTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String _mmss(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  void _toggleVoice(OperatorUser user, String taskId, int elapsedSec) {
    if (_recording) return;
    setState(() => _recording = true);
    _recTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      final list = ref.read(appProvider).logs[taskId] ?? const [];
      final text = user.voice[list.length % user.voice.length];
      final sync = user.vertical == Vertical.mining ? 'Queued, no signal' : 'Synced';
      ref.read(appProvider.notifier).addVoiceLog(taskId, VoiceLog(text: text, time: _mmss(elapsedSec), sync: sync));
      setState(() => _recording = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final tasks = ref.watch(tasksProvider);
    final app = ref.watch(appProvider);
    final acc = user.accent;
    final activeId = app.activeTaskId;
    final task = tasks.firstWhere((t) => t.id == activeId, orElse: () => tasks.first);
    final elapsedSec = app.activeStartMs == null
        ? 0
        : ((DateTime.now().millisecondsSinceEpoch - app.activeStartMs!) / 1000).floor().clamp(0, 999999);
    final progress = (elapsedSec / (task.eta * 60)).clamp(0.0, 1.0);
    final logs = app.logs[activeId] ?? const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      children: [
        // Timer card (dark)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(kRadiusCard)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: acc.base, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('In progress · ${task.id}', style: const TextStyle(fontSize: 14, color: Color(0xFFC9C4B8)).merge(kMono)),
              ]),
              const SizedBox(height: 6),
              Text(task.type, style: const TextStyle(fontSize: 22, height: 28 / 22, color: AppColors.bg, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(_mmss(elapsedSec),
                      style: const TextStyle(fontSize: 60, height: 64 / 60, fontWeight: FontWeight.w300, color: AppColors.bg).merge(kTabular)),
                  const SizedBox(width: 10),
                  Text('of ~${task.eta} min', style: const TextStyle(fontSize: 14, color: Color(0xFFC9C4B8))),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: const Color(0x2EFBF8F2),
                  valueColor: AlwaysStoppedAnimation(acc.base),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Voice log card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(kRadiusCard), border: Border.all(color: AppColors.divider)),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _toggleVoice(user, task.id, elapsedSec),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_recording)
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, _) => Container(
                            width: 72 * (1 + 0.4 * _pulse.value),
                            height: 72 * (1 + 0.4 * _pulse.value),
                            decoration: BoxDecoration(shape: BoxShape.circle, color: acc.base.withValues(alpha: 0.4 * (1 - _pulse.value))),
                          ),
                        ),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: _recording ? AppColors.ink : acc.base),
                        child: Icon(Icons.mic, size: 30, color: _recording ? acc.base : AppColors.ink),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_recording ? 'Listening…' : 'Voice log',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.ink)),
                    const SizedBox(height: 4),
                    Text(_recording ? 'Describe what you see. Transcribed on the phone.' : 'Tap and say what you notice. Works offline.',
                        style: const TextStyle(fontSize: 14, height: 20 / 14, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Observations · ${logs.length}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 8),
        if (logs.isEmpty)
          const Text('Nothing logged yet on this task.', style: TextStyle(fontSize: 15, color: AppColors.muted))
        else
          ...logs.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(kRadiusSmall), border: Border.all(color: AppColors.divider)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.text, style: const TextStyle(fontSize: 15, height: 22 / 15, color: AppColors.ink)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text(l.time, style: const TextStyle(fontSize: 12, color: AppColors.muted).merge(kMono)),
                        const SizedBox(width: 8),
                        Text(l.sync, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ]),
                    ],
                  ),
                ),
              )),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              ref.read(appProvider.notifier).endTask();
              ref.read(navProvider.notifier).backToList();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.muted2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            child: const Text('End task'),
          ),
        ),
      ],
    );
  }
}
