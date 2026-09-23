import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/nav.dart';
import '../../core/tokens.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';

/// 08 AR lesson. Camera area is a placeholder for the Unity AR view (P3, flutter_unity_widget).
class ArLessonScreen extends ConsumerStatefulWidget {
  const ArLessonScreen({super.key});

  @override
  ConsumerState<ArLessonScreen> createState() => _ArLessonScreenState();
}

class _ArLessonScreenState extends ConsumerState<ArLessonScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final acc = user.accent;
    final lessonId = ref.watch(navProvider.select((s) => s.lessonId));
    final lesson = kLessons.firstWhere((l) => l.id == lessonId, orElse: () => kLessons.first);
    final running = _step < lesson.steps.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => ref.read(navProvider.notifier).closeLesson(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Text('‹  Learning Hub', style: TextStyle(fontSize: 15, color: AppColors.ink2)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _cameraArea(lesson, acc, running),
        const SizedBox(height: 16),
        if (running) ..._running(lesson, acc) else ..._done(lesson, acc),
      ],
    );
  }

  Widget _cameraArea(Lesson lesson, AccentPalette acc, bool running) {
    return SizedBox(
      height: 320,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadiusCard),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _StripePainter())),
            const Positioned.fill(
              child: Center(
                child: Text('camera feed · AR overlay', style: TextStyle(fontSize: 13, color: Color(0xFF8A867C))),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: acc.base, borderRadius: BorderRadius.circular(kRadiusChip)),
                child: Text('${lesson.object} = ${lesson.control}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(kRadiusChip)),
                child: Text(
                  running ? 'Step ${_step + 1} of ${lesson.steps.length}' : 'Complete',
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _running(Lesson lesson, AccentPalette acc) {
    return [
      Row(
        children: [
          for (var i = 0; i < lesson.steps.length; i++)
            Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i == lesson.steps.length - 1 ? 0 : 6),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= _step ? acc.base : const Color(0xFFE3DED2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Text(lesson.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.muted)),
      const SizedBox(height: 6),
      Text(lesson.steps[_step], style: const TextStyle(fontSize: 24, height: 32 / 24, color: AppColors.ink)),
      const SizedBox(height: 20),
      SizedBox(
        height: 56,
        width: double.infinity,
        child: FilledButton(
          onPressed: () {
            final next = _step + 1;
            if (next >= lesson.steps.length) {
              ref.read(appProvider.notifier).completeLesson(lesson.id, lesson.score);
            }
            setState(() => _step = next);
          },
          style: FilledButton.styleFrom(
            backgroundColor: acc.base,
            foregroundColor: AppColors.ink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
          child: const Text('Step done'),
        ),
      ),
    ];
  }

  List<Widget> _done(Lesson lesson, AccentPalette acc) {
    return [
      Text('${lesson.title} complete', style: const TextStyle(fontSize: 24, height: 32 / 24, color: AppColors.ink)),
      const SizedBox(height: 8),
      Text('${lesson.score} / 100',
          style: TextStyle(fontSize: 56, height: 64 / 56, fontWeight: FontWeight.w500, color: acc.ink).merge(kTabular)),
      const SizedBox(height: 8),
      const Text('Saved to your skills passport.', style: TextStyle(fontSize: 15, color: AppColors.muted)),
      const SizedBox(height: 20),
      SizedBox(
        height: 56,
        width: double.infinity,
        child: FilledButton(
          onPressed: () => ref.read(navProvider.notifier).closeLesson(),
          style: FilledButton.styleFrom(
            backgroundColor: acc.base,
            foregroundColor: AppColors.ink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
          child: const Text('Done'),
        ),
      ),
    ];
  }
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2A2926));
    final stripe = Paint()..color = const Color(0xFF201F1C);
    const gap = 26.0;
    for (double x = -size.height; x < size.width; x += gap) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + size.height, size.height)
        ..lineTo(x + size.height + 12, size.height)
        ..lineTo(x + 12, 0)
        ..close();
      canvas.drawPath(path, stripe);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
