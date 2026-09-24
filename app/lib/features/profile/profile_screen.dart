import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/nav.dart';
import '../../core/tokens.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';

/// 10 Profile — identity, machine info, and the skills passport.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final app = ref.watch(appProvider);
    final acc = user.accent;

    // Lessons finished today go at the top of the passport.
    final passport = <PassportEntry>[
      for (final e in app.completed.entries)
        PassportEntry(title: kLessons.firstWhere((l) => l.id == e.key).title, date: 'Today', score: e.value),
      ...user.passport,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: acc.tint, shape: BoxShape.circle),
              child: Text(user.initial, style: oswald(size: 26, weight: FontWeight.w500, spacing: 0, color: acc.ink)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name.toUpperCase(),
                      style: oswald(size: 24, weight: FontWeight.w700, spacing: 0.4, height: 30 / 24, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(user.opId, style: mono(size: 13, color: AppColors.muted)),
                    Text(' · Operator', style: inter(size: 13, color: AppColors.muted)),
                  ]),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _infoList([
          ('Machine', user.machine),
          ('Data source', user.source),
          ('Site', user.site),
          ('Skill level', user.skill),
        ]),
        const SizedBox(height: 20),
        Text('Skills passport'.toUpperCase(),
            style: oswald(size: 13, weight: FontWeight.w600, spacing: 1.2, color: AppColors.muted)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(kRadiusCard)),
          child: Column(
            children: [
              for (var i = 0; i < passport.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: i == passport.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.dividerRow)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(passport[i].title, style: inter(size: 15, weight: FontWeight.w500, color: AppColors.ink)),
                            const SizedBox(height: 2),
                            Text(passport[i].date, style: inter(size: 13, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      Text('${passport[i].score}',
                          style: oswald(size: 20, weight: FontWeight.w500, color: AppColors.ink)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              ref.read(authServiceProvider).signOut();
              ref.read(appProvider.notifier).logout();
              ref.read(navProvider.notifier).reset();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.muted2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusButton)),
              textStyle: oswald(size: 16, weight: FontWeight.w600, spacing: 1),
            ),
            child: const Text('SIGN OUT'),
          ),
        ),
      ],
    );
  }

  Widget _infoList(List<(String, String)> rows) => Container(
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(kRadiusCard)),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text(rows[i].$1, style: inter(size: 15, color: AppColors.muted))),
                    const SizedBox(width: 12),
                    Flexible(child: Text(rows[i].$2, textAlign: TextAlign.right, style: inter(size: 15, weight: FontWeight.w500, color: AppColors.ink))),
                  ],
                ),
              ),
          ],
        ),
      );
}
