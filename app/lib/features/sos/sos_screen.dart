import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';

/// 09 SOS — BLE SOS with multi-hop relay (FR-SOS, DESIGN §17). Hold 2s to send.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  Timer? _holdTimer;
  Timer? _tick;
  double _hold = 0;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _startHold() {
    _holdTimer?.cancel();
    final start = DateTime.now().millisecondsSinceEpoch;
    _holdTimer = Timer.periodic(const Duration(milliseconds: 30), (t) {
      final h = math.min(1, (DateTime.now().millisecondsSinceEpoch - start) / 2000);
      if (h >= 1) {
        t.cancel();
        setState(() => _hold = 0);
        ref.read(appProvider.notifier).startSos();
        _ensureTick();
      } else {
        setState(() => _hold = h.toDouble());
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    if (_hold != 0) setState(() => _hold = 0);
  }

  void _ensureTick() {
    _tick ??= Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) return;
      if (ref.read(appProvider).sosStartedMs == null) {
        _tick?.cancel();
        _tick = null;
      }
      setState(() {});
    });
  }

  String _mmss(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final app = ref.watch(appProvider);
    final active = app.sosStartedMs != null;
    if (active) _ensureTick();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      children: active ? _active(user, app) : _idle(),
    );
  }

  List<Widget> _idle() {
    return [
      Text('Sends your location over Bluetooth to nearby phones, which pass it on. Works with no cell signal.',
          style: inter(size: 15, height: 22 / 15, color: AppColors.muted)),
      const SizedBox(height: 32),
      Center(
        child: GestureDetector(
          onTapDown: (_) => _startHold(),
          onTapUp: (_) => _cancelHold(),
          onTapCancel: _cancelHold,
          child: SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CustomPaint(painter: _HoldRingPainter(_hold)),
                ),
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hold > 0 ? AppColors.dangerPressed : AppColors.danger,
                    boxShadow: [BoxShadow(color: AppColors.danger.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 6))],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('SOS', style: oswald(size: 52, weight: FontWeight.w700, spacing: 1, color: Colors.white)),
                      Text(_hold > 0 ? 'Keep holding' : 'Hold', style: inter(size: 14, weight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),
      Center(child: Text('Press and hold for 2 seconds', style: inter(size: 14, color: AppColors.muted))),
    ];
  }

  List<Widget> _active(OperatorUser user, AppData app) {
    final sosT = (DateTime.now().millisecondsSinceEpoch - app.sosStartedMs!) / 1000;
    final logs = app.logs[app.activeTaskId] ?? const [];
    final attached = logs.isNotEmpty ? 'last voice log + sensor snapshot' : 'sensor snapshot';
    final steps = <(double, String, String)>[
      (0, 'Broadcasting over Bluetooth', 'Sending the SOS packet every 250 ms'),
      (1.5, 'Picked up by 2 nearby phones',
          user.vertical == Vertical.mining ? 'HT009 (60 m) and LV03 (110 m) are relaying' : 'OP1003 (38 m) and OP1011 (72 m) are relaying'),
      (3, 'Reached the cloud', user.vertical == Vertical.mining ? 'Relayed by LV03 from the crib hut' : 'Relayed by OP1011, which has signal'),
      (4.2, 'The ${user.supervisor} was notified', 'Push alert sent with your location'),
    ];

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(kRadiusCard)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('SOS active · ${_mmss(sosT.floor())}', style: mono(size: 14, color: Colors.white)),
            ]),
            const SizedBox(height: 8),
            Text('Help is being alerted'.toUpperCase(),
                style: oswald(size: 26, weight: FontWeight.w700, spacing: 0.4, height: 32 / 26, color: Colors.white)),
            const SizedBox(height: 4),
            Text('Stay where you are if it is safe.', style: inter(size: 15, color: const Color(0xFFFFDAD5))),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(kRadiusCard), border: Border.all(color: AppColors.divider)),
        child: Column(
          children: [
            for (var i = 0; i < steps.length; i++) _relayRow(steps[i], sosT, i == steps.length - 1),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(kRadiusSmall)),
        child: Text(
          '${user.opId} · ${user.machineId} · ${user.gps} · severity high · $attached',
          style: mono(size: 12, color: AppColors.ink2),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 56,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => ref.read(appProvider.notifier).cancelSos(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.ink,
            side: const BorderSide(color: AppColors.muted2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusButton)),
            textStyle: oswald(size: 16, weight: FontWeight.w600, spacing: 1),
          ),
          child: const Text('CANCEL SOS'),
        ),
      ),
    ];
  }

  Widget _relayRow((double, String, String) step, double sosT, bool last) {
    final (t, label, detail) = step;
    final on = sosT >= t;
    final done = sosT >= t + 1.2;
    final Color dot = done ? AppColors.successInk : on ? AppColors.danger : AppColors.inputBorder;
    return Opacity(
      opacity: on ? 1 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              child: done ? const Icon(Icons.check, size: 16, color: AppColors.onAccent) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: inter(size: 15, weight: FontWeight.w500, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(detail, style: inter(size: 13, height: 18 / 13, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoldRingPainter extends CustomPainter {
  _HoldRingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - 8) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = AppColors.errorBg;
    canvas.drawCircle(center, radius, track);
    if (progress > 0) {
      final prog = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = AppColors.danger;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * progress, false, prog);
    }
  }

  @override
  bool shouldRepaint(covariant _HoldRingPainter old) => old.progress != progress;
}
