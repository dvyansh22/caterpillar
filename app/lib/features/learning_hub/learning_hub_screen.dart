import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/nav.dart';
import '../../core/tokens.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';

/// 07 Learning Hub — AR lessons mapping everyday objects to controls (FR-LEARN, closed loop).
class LearningHubScreen extends ConsumerWidget {
  const LearningHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final app = ref.watch(appProvider);
    final acc = user.accent;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        Text('Practice machine controls in AR using objects you have on hand.',
            style: const TextStyle(fontSize: 15, height: 22 / 15, color: AppColors.muted)),
        const SizedBox(height: 16),
        ...kLessons.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LessonCard(lesson: l, user: user, acc: acc, score: app.completed[l.id]),
            )),
      ],
    );
  }
}

class _LessonCard extends ConsumerWidget {
  const _LessonCard({required this.lesson, required this.user, required this.acc, required this.score});
  final Lesson lesson;
  final OperatorUser user;
  final AccentPalette acc;
  final int? score;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = score != null;
    final assigned = lesson.auto && !done;
    final tag = done ? 'Completed' : lesson.auto ? 'Assigned to you' : 'Optional';
    final (Color chipBg, Color chipInk) =
        done ? (AppColors.successBg, AppColors.successInk) : lesson.auto ? (acc.base, AppColors.ink) : (AppColors.surface2, AppColors.ink);
    final meta = done ? 'Score $score' : '${lesson.steps.length} steps · 3 min';
    final note = lesson.auto ? user.flag : 'Learn the steering control using a mouse on the table.';
    final cta = done ? 'Practice again' : 'Start lesson';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: assigned ? acc.base : AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(kRadiusChip)),
                child: Text(tag, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: chipInk)),
              ),
              Text(meta, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 12),
          Text(lesson.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.ink)),
          const SizedBox(height: 4),
          Text(note, style: const TextStyle(fontSize: 14, height: 20 / 14, color: AppColors.muted)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Text(lesson.object, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, size: 16, color: AppColors.muted)),
              Text(lesson.control, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink)),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: assigned
                ? FilledButton(
                    onPressed: () => ref.read(navProvider.notifier).openLesson(lesson.id),
                    style: FilledButton.styleFrom(
                      backgroundColor: acc.base,
                      foregroundColor: AppColors.ink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    child: Text(cta),
                  )
                : OutlinedButton(
                    onPressed: () => ref.read(navProvider.notifier).openLesson(lesson.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.muted2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    child: Text(cta),
                  ),
          ),
        ],
      ),
    );
  }
}
