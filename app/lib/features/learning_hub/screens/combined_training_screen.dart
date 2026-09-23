/// Combined AR console lesson — landscape, both controllers at once.
///
/// Two colour trackers run simultaneously (red = gear, blue = lever). The
/// tutorial steps through the gear first, then the lever; only the active
/// marker's motion advances the current step. One crane shows two aspects of
/// the same machine: the gear drives cab slew + boom reach, the lever drives
/// boom lift. Calibration-free (auto-acquire by hue). Owner: P3 (FR-LEARN).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../motion/frame_motion_tracker.dart';
import '../providers/learning_hub_providers.dart';

const double _kMoveDist = 0.14;
const double _redHue = 2;
const double _blueHue = 225;
const double _greenHue = 95;
const Color _redBox = Color(0xFFFF5252);
const Color _blueBox = Color(0xFF448AFF);
const Color _greenBox = Color(0xFF69F0AE);

/// Frames (~66ms each) the green button must be held to toggle the engine (~1s).
const int _kHoldFrames = 15;

enum _Marker { gear, lever }

/// Lesson lifecycle: press the green button to start the engine, run the
/// steps, then press again to stop.
enum _Phase { prestart, running, poststop, done }

class _CStep {
  const _CStep({
    required this.marker,
    required this.dir,
    required this.instruction,
    required this.effect,
  });
  final _Marker marker;
  final MoveDir dir;
  final String instruction;
  final String effect;
}

const List<_CStep> _kSteps = [
  _CStep(marker: _Marker.gear, dir: MoveDir.forward, instruction: 'RED gear — push FORWARD', effect: 'Boom reaches out'),
  _CStep(marker: _Marker.gear, dir: MoveDir.back, instruction: 'RED gear — pull BACK', effect: 'Boom draws in'),
  _CStep(marker: _Marker.gear, dir: MoveDir.left, instruction: 'RED gear — swing LEFT', effect: 'Cab slews left'),
  _CStep(marker: _Marker.gear, dir: MoveDir.right, instruction: 'RED gear — swing RIGHT', effect: 'Cab slews right'),
  _CStep(marker: _Marker.lever, dir: MoveDir.forward, instruction: 'BLUE lever — slide UP', effect: 'Boom lifts'),
  _CStep(marker: _Marker.lever, dir: MoveDir.back, instruction: 'BLUE lever — slide DOWN', effect: 'Boom lowers'),
];

class CombinedTrainingScreen extends ConsumerStatefulWidget {
  const CombinedTrainingScreen({super.key});

  @override
  ConsumerState<CombinedTrainingScreen> createState() =>
      _CombinedTrainingScreenState();
}

class _CombinedTrainingScreenState extends ConsumerState<CombinedTrainingScreen>
    with TickerProviderStateMixin {
  CameraController? _camera;
  final _redTracker = FrameMotionTracker();
  final _blueTracker = FrameMotionTracker();
  final _greenTracker = FrameMotionTracker();
  bool _streaming = false;
  String? _cameraError;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);

  MotionResult _red = MotionResult.empty;
  MotionResult _blue = MotionResult.empty;
  MotionResult _green = MotionResult.empty;
  final List<Offset> _trail = [];

  _Phase _phase = _Phase.prestart;
  bool _engineOn = false;

  // Green start/stop button: press = finger occludes the green → area drops.
  double _greenMax = 0; // baseline (uncovered) green area
  int _pressFrames = 0;

  int _stepIndex = 0;
  double _progress = 0;
  bool _flashComplete = false;

  // Machine aspects.
  double _boom = 0.4; // lever: lift
  double _swing = 0.0; // gear: slew (-1..1)
  double _reach = 0.4; // gear: boom reach (0..1)

  // Directional completion + neutral gate (for the active marker).
  bool _awaitNeutral = false;
  int _neutralFrames = 0;
  Offset? _stepStart;
  double _stepMaxProj = 0;

  late final AnimationController _pulse;

  _CStep get _step => _kSteps[_stepIndex];
  MotionResult get _active => _step.marker == _Marker.gear ? _red : _blue;

  @override
  void initState() {
    super.initState();
    // Portrait, same frame as the single lessons — identity mapping, so
    // directions behave exactly like the gear/lever modules.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _redTracker.setTarget(_redHue);
    _blueTracker.setTarget(_blueHue);
    _greenTracker.setTarget(_greenHue);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _pulse.dispose();
    final cam = _camera;
    _camera = null;
    () async {
      try {
        if (cam != null) {
          if (_streaming) await cam.stopImageStream();
          await cam.dispose();
        }
      } catch (_) {}
    }();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No camera available on this device.');
        return;
      }
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      // Widest field of view (no digital zoom) so both props fit more easily.
      try {
        await controller.setZoomLevel(await controller.getMinZoomLevel());
      } catch (_) {}
      _camera = controller;
      await controller.startImageStream(_onFrame);
      setState(() => _streaming = true);
    } catch (e) {
      setState(() => _cameraError = 'Camera error: $e');
    }
  }

  void _onFrame(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastFrame).inMilliseconds < 66) return;
    _lastFrame = now;

    switch (_phase) {
      case _Phase.prestart:
      case _Phase.poststop:
        _green = _greenTracker.process(image);
        _detectHold();
      case _Phase.running:
        _red = _redTracker.process(image);
        _blue = _blueTracker.process(image);
        _advance();
      case _Phase.done:
        break;
    }
  }

  /// Detect a 2-second press-and-hold on the green button (finger occludes it,
  /// so the visible green area drops below its uncovered baseline).
  void _detectHold() {
    final count = _green.matchCount.toDouble();
    if (_green.hasObject && count > _greenMax) _greenMax = count;
    _greenMax *= 0.99; // slowly adapt the baseline

    final covered = _green.hasObject &&
        count >= 2 &&
        _greenMax > 6 &&
        count < 0.55 * _greenMax;
    if (covered) {
      _pressFrames++;
    } else {
      // Decay instead of hard-reset, so camera shake / a brief flicker in the
      // green read doesn't wipe out the whole hold.
      _pressFrames = math.max(0, _pressFrames - 2);
    }

    if (_pressFrames >= _kHoldFrames) {
      _pressFrames = 0;
      _greenMax = 0;
      _onEngineToggle();
    }
    if (mounted) setState(() {});
  }

  double get _holdProgress => (_pressFrames / _kHoldFrames).clamp(0.0, 1.0);

  void _onEngineToggle() {
    if (_phase == _Phase.prestart) {
      setState(() {
        _engineOn = true;
        _phase = _Phase.running;
      });
    } else if (_phase == _Phase.poststop) {
      // Mark the module complete so the Learning Hub card updates.
      ref
          .read(trainingModulesProvider.notifier)
          .completeStep('combined_control', _kSteps.length - 1, 100);
      setState(() {
        _engineOn = false;
        _phase = _Phase.done;
      });
    }
  }

  void _advance() {
    final r = _active;
    final step = _step;

    if (r.center != null) {
      _trail.add(r.center!);
      if (_trail.length > 26) _trail.removeAt(0);
    }
    final dir = r.dominantDir;
    final s = r.speed;

    // Drive the two machine aspects from the active marker.
    if (step.marker == _Marker.gear) {
      switch (dir) {
        case MoveDir.forward:
          _reach = (_reach + s * 3.5).clamp(0.0, 1.0);
        case MoveDir.back:
          _reach = (_reach - s * 3.5).clamp(0.0, 1.0);
        case MoveDir.left:
          _swing = (_swing - s * 3.5).clamp(-1.0, 1.0);
        case MoveDir.right:
          _swing = (_swing + s * 3.5).clamp(-1.0, 1.0);
        case MoveDir.none:
          break;
      }
    } else {
      switch (dir) {
        case MoveDir.forward:
          _boom = (_boom + s * 3.5).clamp(0.0, 1.0);
        case MoveDir.back:
          _boom = (_boom - s * 3.5).clamp(0.0, 1.0);
        default:
          break;
      }
    }

    if (_awaitNeutral) {
      if (s < 0.006) {
        _neutralFrames++;
      } else {
        _neutralFrames = 0;
      }
      if (_neutralFrames >= 6) {
        _awaitNeutral = false;
        _stepStart = r.center;
        _stepMaxProj = 0;
      }
      if (mounted) setState(() {});
      return;
    }

    final c = r.center;
    if (c != null) {
      _stepStart ??= c;
      final u = _dirUnit(step.dir);
      final disp = c - _stepStart!;
      final proj = disp.dx * u.dx + disp.dy * u.dy;
      if (proj < -0.05) {
        _stepStart = c;
        _stepMaxProj = 0;
      } else if (proj > _stepMaxProj) {
        _stepMaxProj = proj;
      }
      _progress = (_stepMaxProj / _kMoveDist).clamp(0.0, 1.0);
      if (_progress >= 1.0) _completeStep();
    }

    if (mounted) setState(() {});
  }

  Offset _dirUnit(MoveDir d) => switch (d) {
        MoveDir.forward => const Offset(0, -1),
        MoveDir.back => const Offset(0, 1),
        MoveDir.left => const Offset(-1, 0),
        MoveDir.right => const Offset(1, 0),
        MoveDir.none => Offset.zero,
      };

  void _completeStep() {
    _progress = 0;
    _trail.clear();
    _awaitNeutral = true;
    _neutralFrames = 0;
    _stepStart = null;
    _stepMaxProj = 0;

    if (_stepIndex >= _kSteps.length - 1) {
      // All steps done → go to the engine-stop gate.
      _greenMax = 0;
      _pressFrames = 0;
      _green = MotionResult.empty;
      setState(() => _phase = _Phase.poststop);
      return;
    }
    setState(() {
      _flashComplete = true;
      _stepIndex++;
    });
    Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _flashComplete = false);
    });
  }

  void _reacquire() {
    _trail.clear();
    _redTracker.setTarget(_redHue);
    _blueTracker.setTarget(_blueHue);
    setState(() {
      _red = MotionResult.empty;
      _blue = MotionResult.empty;
    });
  }

  // ------------------------------------------------------------------ //

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.done) return const _CombinedComplete();

    if (_phase == _Phase.prestart || _phase == _Phase.poststop) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _cameraLayer(),
            if (_camera != null && _camera!.value.isInitialized)
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _GreenGatePainter(
                    green: _green,
                    hold: _holdProgress,
                    pulse: _pulse.value,
                  ),
                ),
              ),
            _gatePanel(_phase == _Phase.prestart),
            _topBar(),
          ],
        ),
      );
    }

    final step = _step;
    final matched = _active.dominantDir == step.dir;
    final activeMarker = step.marker;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _cameraLayer(),
          if (_camera != null && _camera!.value.isInitialized)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _DualOverlayPainter(
                  red: _red,
                  blue: _blue,
                  activeMarker: activeMarker,
                  arrowDir: step.dir,
                  trail: _trail,
                  pulse: _pulse.value,
                  matched: matched,
                ),
              ),
            ),
          // Machine console (two aspects)
          Positioned(
            right: 14,
            top: MediaQuery.paddingOf(context).top + 8,
            child: _ConsoleCard(
              boom: _boom,
              swing: _swing,
              reach: _reach,
              activeMarker: activeMarker,
            ),
          ),
          _bottomBar(step, matched),
          _topBar(),
          if (_flashComplete) Center(child: _CheckFlash(pulse: _pulse.value)),
        ],
      ),
    );
  }

  Widget _gatePanel(bool isStart) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isStart ? Icons.power_settings_new_rounded : Icons.stop_circle_rounded,
              color: _greenBox,
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              isStart ? 'Start the engine' : 'Shut the engine down',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _green.hasObject
                  ? 'Hold your finger on the GREEN button for 2 seconds'
                  : 'Point the camera at the GREEN button',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: CatColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _holdProgress,
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(_greenBox),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraLayer() {
    if (_cameraError != null) {
      return Center(
        child: Text(_cameraError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CatColors.textSecondary)),
      );
    }
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final preview = cam.value.previewSize!;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: preview.height,
        height: preview.width,
        child: CameraPreview(cam),
      ),
    );
  }

  Widget _topBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            _GlassButton(
              icon: Icons.close_rounded,
              onTap: () => context.go('/learning-hub'),
            ),
            const Spacer(),
            // All status chips grouped on the right side.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: (_engineOn ? _greenBox : Colors.white24)),
              ),
              child: Icon(Icons.power_settings_new_rounded,
                  size: 14, color: _engineOn ? _greenBox : Colors.white38),
            ),
            const SizedBox(width: 8),
            _MarkerChip(color: _redBox, label: 'GEAR', on: _red.hasObject),
            const SizedBox(width: 8),
            _MarkerChip(color: _blueBox, label: 'LEVER', on: _blue.hasObject),
            const SizedBox(width: 8),
            _GlassButton(icon: Icons.refresh_rounded, onTap: _reacquire),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(_CStep step, bool matched) {
    final color = step.marker == _Marker.gear ? _redBox : _blueBox;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.85),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Step ${_stepIndex + 1} of ${_kSteps.length}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _active.hasObject
                        ? 'Detected ${_active.dominantDir.arrow}'
                        : 'Searching…',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          matched ? CatColors.success : CatColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                step.instruction,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(
                      matched ? CatColors.success : color),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                !_active.hasObject
                    ? 'Point at both controllers — the ${step.marker == _Marker.gear ? "red" : "blue"} one is active'
                    : _awaitNeutral
                        ? 'Return to centre, then make the next move'
                        : step.effect,
                style: const TextStyle(
                    fontSize: 12, color: CatColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================================== //
// Painters + widgets
// ===================================================================== //

class _DualOverlayPainter extends CustomPainter {
  _DualOverlayPainter({
    required this.red,
    required this.blue,
    required this.activeMarker,
    required this.arrowDir,
    required this.trail,
    required this.pulse,
    required this.matched,
  });

  final MotionResult red;
  final MotionResult blue;
  final _Marker activeMarker;
  final MoveDir arrowDir;
  final List<Offset> trail;
  final double pulse;
  final bool matched;

  @override
  void paint(Canvas canvas, Size size) {
    _box(canvas, size, red.box, _redBox, activeMarker == _Marker.gear);
    _box(canvas, size, blue.box, _blueBox, activeMarker == _Marker.lever);
    _trailAndArrow(canvas, size);
  }

  void _box(Canvas canvas, Size size, Rect? nb, Color color, bool active) {
    if (nb == null) return;
    final rect = Rect.fromLTRB(
      nb.left.clamp(0.0, 1.0) * size.width,
      nb.top.clamp(0.0, 1.0) * size.height,
      nb.right.clamp(0.0, 1.0) * size.width,
      nb.bottom.clamp(0.0, 1.0) * size.height,
    );
    final a = active ? 1.0 : 0.4;
    final c = (active && matched) ? CatColors.success : color;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = c.withValues(alpha: 0.9 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 3 : 1.5,
    );
    if (active) {
      final len = (rect.shortestSide * 0.25).clamp(12.0, 34.0);
      final p = Paint()
        ..color = c
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      void corner(Offset o, Offset hx, Offset vy) {
        canvas.drawLine(o, o + hx, p);
        canvas.drawLine(o, o + vy, p);
      }

      corner(rect.topLeft, Offset(len, 0), Offset(0, len));
      corner(rect.topRight, Offset(-len, 0), Offset(0, len));
      corner(rect.bottomLeft, Offset(len, 0), Offset(0, -len));
      corner(rect.bottomRight, Offset(-len, 0), Offset(0, -len));
    }
  }

  void _trailAndArrow(Canvas canvas, Size size) {
    if (trail.length >= 2) {
      final color = matched ? CatColors.success : CatColors.catYellow;
      for (var i = 1; i < trail.length; i++) {
        final a =
            Offset(trail[i - 1].dx * size.width, trail[i - 1].dy * size.height);
        final b = Offset(trail[i].dx * size.width, trail[i].dy * size.height);
        final t = i / trail.length;
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = color.withValues(alpha: 0.15 + 0.5 * t)
            ..strokeWidth = 2 + 4 * t
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    if (arrowDir == MoveDir.none) return;
    final center = Offset(size.width * 0.4, size.height * 0.32);
    final reach = 40.0 * (0.9 + pulse * 0.25);
    final color = (matched ? CatColors.success : Colors.white)
        .withValues(alpha: 0.2 + pulse * 0.16);
    final dir = switch (arrowDir) {
      MoveDir.forward => const Offset(0, -1),
      MoveDir.back => const Offset(0, 1),
      MoveDir.left => const Offset(-1, 0),
      MoveDir.right => const Offset(1, 0),
      MoveDir.none => Offset.zero,
    };
    final tip = center + dir * reach;
    final base = center - dir * reach * 0.3;
    canvas.drawLine(
        base,
        tip,
        Paint()
          ..color = color
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round);
    final perp = Offset(-dir.dy, dir.dx);
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((tip - dir * 20 + perp * 14).dx, (tip - dir * 20 + perp * 14).dy)
      ..lineTo((tip - dir * 20 - perp * 14).dx, (tip - dir * 20 - perp * 14).dy)
      ..close();
    canvas.drawPath(head, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DualOverlayPainter old) => true;
}

/// Green start/stop button: highlights the button and shows a hold ring.
class _GreenGatePainter extends CustomPainter {
  _GreenGatePainter(
      {required this.green, required this.hold, required this.pulse});
  final MotionResult green;
  final double hold;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final box = green.box;
    if (box == null) return;
    final center = Offset(
      box.center.dx.clamp(0.0, 1.0) * size.width,
      box.center.dy.clamp(0.0, 1.0) * size.height,
    );
    final radius = (box.longestSide * size.width * 0.6).clamp(34.0, 120.0);

    // Base ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _greenBox.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    // Hold-progress arc
    if (hold > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * hold,
        false,
        Paint()
          ..color = _greenBox
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
    } else {
      // Idle pulse hint
      canvas.drawCircle(
        center,
        radius + 6 + pulse * 6,
        Paint()
          ..color = _greenBox.withValues(alpha: 0.15 * (1 - pulse))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GreenGatePainter old) => true;
}

/// Crane showing two aspects: gear → slew + reach, lever → lift.
class _ConsolePainter extends CustomPainter {
  _ConsolePainter({
    required this.boom,
    required this.swing,
    required this.reach,
    required this.activeMarker,
  });
  final double boom;
  final double swing;
  final double reach;
  final _Marker activeMarker;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const yellow = CatColors.catYellow;
    const dark = Color(0xFF2A2A2A);
    final steel = Paint()
      ..color = yellow
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    // ---- Fixed crawler base + cab (these NEVER move) ----
    final baseY = h * 0.9;
    final cx = w * 0.42; // leave room for the boom to sweep right
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, baseY - 4), width: w * 0.5, height: h * 0.08),
        const Radius.circular(4),
      ),
      Paint()..color = dark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.1, baseY - h * 0.16, w * 0.2, h * 0.1),
        const Radius.circular(3),
      ),
      Paint()..color = yellow,
    );

    // ---- Fixed vertical mast ----
    final mastTop = Offset(cx, baseY - h * 0.42);
    canvas.drawLine(Offset(cx, baseY - h * 0.13), mastTop, steel);

    // ---- Boom pivots at the mast top only ----
    // gear L/R → horizontal sweep (slew); lever up/down → lift; gear F/B → reach.
    final ext = 0.55 + reach * 0.55;
    final hx = swing * w * 0.34 * ext;
    final vy = -(0.3 + boom * 0.6) * h * 0.5 * ext;
    final tip = mastTop + Offset(hx, vy);
    canvas.drawLine(
        mastTop,
        tip,
        Paint()
          ..color = yellow
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);
    // short counter-jib on the opposite side of the sweep
    canvas.drawLine(
        mastTop, mastTop + Offset(-hx * 0.22 - w * 0.05, h * 0.015), steel);

    // hoist rope + hook hang straight down from the tip
    final hook = Offset(tip.dx, tip.dy + h * 0.16);
    canvas.drawLine(tip, hook,
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 1.5);
    canvas.drawCircle(hook, 3, Paint()..color = Colors.white70);
  }

  @override
  bool shouldRepaint(covariant _ConsolePainter old) =>
      old.boom != boom || old.swing != swing || old.reach != reach;
}

class _ConsoleCard extends StatelessWidget {
  const _ConsoleCard({
    required this.boom,
    required this.swing,
    required this.reach,
    required this.activeMarker,
  });
  final double boom;
  final double swing;
  final double reach;
  final _Marker activeMarker;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 168,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _tag('GEAR ▸ slew/reach', _redBox, activeMarker == _Marker.gear),
              const Spacer(),
            ],
          ),
          _tag('LEVER ▸ lift', _blueBox, activeMarker == _Marker.lever),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _ConsolePainter(
                  boom: boom,
                  swing: swing,
                  reach: reach,
                  activeMarker: activeMarker),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String t, Color c, bool on) => Text(
        t,
        style: TextStyle(
          color: on ? c : Colors.white.withValues(alpha: 0.4),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _MarkerChip extends StatelessWidget {
  const _MarkerChip({required this.color, required this.label, required this.on});
  final Color color;
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: on ? 0.9 : 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(on ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
              size: 12, color: on ? color : Colors.white38),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: on ? Colors.white : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _CheckFlash extends StatelessWidget {
  const _CheckFlash({required this.pulse});
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.8 + pulse * 0.3,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CatColors.success.withValues(alpha: 0.9),
        ),
        child: const Icon(Icons.check_rounded, size: 64, color: Colors.white),
      ),
    );
  }
}

class _CombinedComplete extends StatelessWidget {
  const _CombinedComplete();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CatColors.constructionSurface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CatColors.success.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.verified_rounded,
                    size: 60, color: CatColors.success),
              ),
              const SizedBox(height: 20),
              const Text('Console Mastered! 🎉',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('You drove both the gear and the lever.',
                  style: TextStyle(color: CatColors.textSecondary)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/learning-hub'),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to Learning Hub'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
