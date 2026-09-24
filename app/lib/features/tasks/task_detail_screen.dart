import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/nav.dart';
import '../../core/tokens.dart';
import '../../services/ml_client/ml_models.dart';
import '../../services/ml_client/ml_providers.dart';

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

    // Live task-time ETA from the model backend. getEstimate never throws: it
    // returns an offline stub (model_version 'stub-0') when unreachable, so we
    // fall back to the seed value and flag whether the number is live.
    final estAsync = ref.watch(taskEstimateProvider(task.id));
    final est = estAsync.asData?.value;
    final live = est != null && est.modelVersion != 'stub-0';
    final loading = estAsync.isLoading;
    final etaMin = live ? est.estimatedMinutes.round() : task.eta;
    final baseMin = live && est.baselineMinutes != null ? est.baselineMinutes!.round() : task.est;

    final delta = etaMin == baseMin
        ? 'Same as the planner baseline.'
        : '${(etaMin - baseMin).abs()} min ${etaMin > baseMin ? 'longer' : 'shorter'} than the planner baseline, '
            'based on ${task.weather.toLowerCase()} weather, your skill level and machine age.';

    final String btnLabel = isDone
        ? 'Completed in ${app.done[task.id]} min.'
        : blocked
            ? 'Finish $activeId before starting another task.'
            : '▶  Start task';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        _backLink(acc, 'All tasks', () => ref.read(navProvider.notifier).backToList()),
        const SizedBox(height: 8),
        Text(task.id, style: mono(size: 13, color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(task.type.toUpperCase(),
            style: oswald(size: 30, weight: FontWeight.w700, spacing: 0.4, height: 38 / 30, color: AppColors.ink)),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.place_outlined, size: 18, color: AppColors.muted),
          const SizedBox(width: 4),
          Expanded(child: Text(task.location, style: inter(size: 15, color: AppColors.muted))),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: acc.tint, borderRadius: BorderRadius.circular(kRadiusCard)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('ESTIMATED TIME',
                      style: oswald(size: 13, weight: FontWeight.w500, spacing: 1.0, color: acc.ink)),
                  const Spacer(),
                  _estBadge(acc, loading: loading, live: live, model: est?.modelVersion),
                ],
              ),
              const SizedBox(height: 4),
              Text('$etaMin MIN',
                  style: oswald(size: 52, weight: FontWeight.w700, spacing: 0.4, height: 60 / 52, color: acc.ink)
                      .merge(kTabular)),
              const SizedBox(height: 8),
              Text(delta, style: inter(size: 14, height: 20 / 14, color: acc.ink)),
              if (live && est.factors.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final f in est.factors) _factorRow(acc, f),
              ],
            ],
          ),
        ),
        if (live && est.advisories.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final a in est.advisories) _advisory(a),
        ],
        if (live && est.bestStart != null && est.bestStart!.minutesSaved >= 5) ...[
          const SizedBox(height: 12),
          _bestStart(acc, est.bestStart!),
        ],
        const SizedBox(height: 12),
        _infoList([
          ('Weather', task.weather),
          ('Machine', '${user.machineId} · ${task.age} yrs'),
          ('Operator skill', user.skill),
          ('Planner baseline', '$baseMin min'),
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
                foregroundColor: AppColors.onAccent,
                disabledBackgroundColor: acc.base,
                disabledForegroundColor: AppColors.onAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusButton)),
                textStyle: oswald(size: 16, weight: FontWeight.w600, spacing: 1.0),
              ),
              child: Text(btnLabel.toUpperCase()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _estBadge(AccentPalette acc, {required bool loading, required bool live, String? model}) {
    final (String label, Color fg) = loading
        ? ('Estimating…', acc.ink)
        : live
            ? ('Live · ${model ?? 'model'}', acc.ink)
            : ('Offline estimate', AppColors.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(kRadiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(live ? Icons.bolt : Icons.wifi_off, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(label.toUpperCase(), style: oswald(size: 11, weight: FontWeight.w600, spacing: 0.8, color: fg)),
        ],
      ),
    );
  }

  Widget _factorRow(AccentPalette acc, EtaFactor f) {
    final sign = f.minutes >= 0 ? '+' : '−';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(f.detail.isNotEmpty ? f.detail : f.name,
                style: inter(size: 13, height: 18 / 13, color: acc.ink)),
          ),
          const SizedBox(width: 10),
          Text('$sign${f.minutes.abs().round()} MIN',
              style: oswald(size: 13, weight: FontWeight.w700, spacing: 0.4, color: acc.ink).merge(kTabular)),
        ],
      ),
    );
  }

  Widget _advisory(String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(kRadiusCard)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.errorText),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: inter(size: 14, height: 20 / 14, color: AppColors.errorText))),
          ],
        ),
      );

  Widget _bestStart(AccentPalette acc, BestStart b) {
    final t = DateTime.tryParse(b.startTime);
    final hhmm = t != null
        ? '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
        : b.startTime;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule, size: 20, color: acc.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Start at $hhmm to save ${b.minutesSaved.round()} min',
                    style: inter(size: 14, weight: FontWeight.w600, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(b.reason, style: inter(size: 13, height: 18 / 13, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _backLink(AccentPalette acc, String text, VoidCallback onTap) => Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chevron_left, size: 20, color: AppColors.ink2),
                const SizedBox(width: 2),
                Text(text.toUpperCase(),
                    style: oswald(size: 14, weight: FontWeight.w600, spacing: 0.8, color: AppColors.ink2)),
              ],
            ),
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
                    Text(rows[i].$1, style: inter(size: 15, color: AppColors.muted)),
                    Text(rows[i].$2, style: inter(size: 15, weight: FontWeight.w500, color: AppColors.ink)),
                  ],
                ),
              ),
          ],
        ),
      );
}
