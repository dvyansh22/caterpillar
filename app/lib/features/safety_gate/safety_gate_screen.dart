import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/nav.dart';
import '../../core/tokens.dart';

/// 02 Pre-start safety gate (FR-GATE-1/2). Auto-verifies seatbelt + camera; can't be skipped.
class SafetyGateScreen extends ConsumerStatefulWidget {
  const SafetyGateScreen({super.key});

  @override
  ConsumerState<SafetyGateScreen> createState() => _SafetyGateScreenState();
}

class _SafetyGateScreenState extends ConsumerState<SafetyGateScreen> {
  final _timers = <Timer>[];
  GateStatus _seat = GateStatus.pending;
  GateStatus _cam = GateStatus.pending;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _run() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    setState(() {
      _seat = GateStatus.busy;
      _cam = GateStatus.pending;
    });
    _timers.add(Timer(const Duration(milliseconds: 1200), () {
      setState(() {
        _seat = GateStatus.pass;
        _cam = GateStatus.busy;
      });
    }));
    _timers.add(Timer(const Duration(milliseconds: 2400), () {
      setState(() {
        _seat = GateStatus.pass;
        _cam = GateStatus.pass;
      });
    }));
    _timers.add(Timer(const Duration(milliseconds: 3200), () {
      if (mounted) ref.read(navProvider.notifier).toWelcome();
    }));
  }

  bool get _locked => _seat == GateStatus.fail || _cam == GateStatus.fail;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final acc = user.accent;
    final passed = _seat == GateStatus.pass && _cam == GateStatus.pass;
    final title = _locked ? 'Machine locked' : passed ? 'Ready to start' : 'Checking before you start';
    final sub = _locked
        ? 'Fix the item below, then run the checks again.'
        : 'These checks run automatically. You can’t skip them.';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
                children: [
                  Text('PRE-START SAFETY GATE',
                      style: oswald(size: 13, weight: FontWeight.w600, spacing: 1.4, color: acc.base)),
                  const SizedBox(height: 10),
                  Text(title.toUpperCase(),
                      style: oswald(size: 30, weight: FontWeight.w700, spacing: 0.4, height: 38 / 30, color: AppColors.ink)),
                  const SizedBox(height: 8),
                  Text(sub, style: inter(size: 15, height: 22 / 15, color: AppColors.muted)),
                  const SizedBox(height: 24),
                  _checkCard(
                    _seat,
                    'Seatbelt',
                    {
                      GateStatus.pending: 'Waiting',
                      GateStatus.busy: 'Reading SeatbeltStatus for ${user.machineId}…',
                      GateStatus.pass: 'Fastened · session ${user.session}',
                      GateStatus.fail: 'Unfastened. Fasten your seatbelt, then re-run the checks.',
                    },
                  ),
                  const SizedBox(height: 12),
                  _checkCard(
                    _cam,
                    'Operator camera',
                    {
                      GateStatus.pending: 'Waiting for seatbelt check',
                      GateStatus.busy: 'Starting the front camera…',
                      GateStatus.pass: 'On · face detected for fatigue monitoring',
                      GateStatus.fail: 'Front camera is off. Turn it on so fatigue monitoring can run.',
                    },
                  ),
                ],
              ),
            ),
            if (_locked)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(kRadiusChip)),
                      child: Row(children: [
                        const Icon(Icons.lock_outlined, size: 20, color: Color(0xFFFF9EA1)),
                        const SizedBox(width: 10),
                        Expanded(child: Text('App locked until every check passes.',
                            style: inter(size: 14, color: const Color(0xFFFF9EA1)))),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _run,
                        style: FilledButton.styleFrom(
                          backgroundColor: acc.base,
                          foregroundColor: AppColors.onAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusButton)),
                        ),
                        child: Text('RE-RUN CHECKS',
                            style: oswald(size: 16, weight: FontWeight.w600, spacing: 1, color: AppColors.onAccent)),
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: TextButton(
                        onPressed: () {
                          ref.read(authServiceProvider).signOut();
                          ref.read(appProvider.notifier).logout();
                          ref.read(navProvider.notifier).reset();
                        },
                        child: Text('SIGN OUT',
                            style: oswald(size: 14, weight: FontWeight.w600, spacing: 1, color: AppColors.muted)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _checkCard(GateStatus status, String title, Map<GateStatus, String> detail) {
    final (Color chipBg, Widget chipChild) = switch (status) {
      GateStatus.pass => (AppColors.successBg, const Icon(Icons.check, size: 22, color: AppColors.successInk)),
      GateStatus.fail => (AppColors.errorBg, const Icon(Icons.close, size: 22, color: AppColors.errorText)),
      _ => (AppColors.surface2, Text('···', style: oswald(weight: FontWeight.w700, color: AppColors.muted2))),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: status == GateStatus.fail ? AppColors.errorBorder : AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: chipBg, shape: BoxShape.circle),
            child: chipChild,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: inter(size: 17, weight: FontWeight.w500, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(detail[status] ?? '', style: inter(size: 14, height: 20 / 14, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
