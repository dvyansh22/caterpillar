/// AR Training Screen — calibration-free, real-time control lesson.
///
/// Each module knows its marker colour (gear = red, lever = blue), so there is
/// no calibration step: the tracker is armed with a target hue and auto-acquires
/// the marker. The camera fills the frame, a box + trail follow the marker,
/// floating text says which way to move it, and a live crane mirrors the motion.
/// A step completes when the prop travels a real distance in the asked direction
/// (a return-to-neutral gate prevents the return stroke from counting).
///
/// All processing is on-device (see `motion/frame_motion_tracker.dart`).
/// Owner: P3 (FR-LEARN).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../motion/frame_motion_tracker.dart';
import '../models/training_module.dart';
import '../providers/learning_hub_providers.dart';

/// One lesson step: a direction to move the marker + the machine effect.
class _Step {
  const _Step({required this.dir, required this.instruction, required this.effect});
  final MoveDir dir;
  final String instruction;
  final String effect;
}

/// How far (fraction of frame) the prop must travel in the requested direction
/// to complete a step — stops tiny twitches from counting.
const double _kMoveDist = 0.14;

class ArTrainingScreen extends ConsumerStatefulWidget {
  const ArTrainingScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<ArTrainingScreen> createState() => _ArTrainingScreenState();
}

class _ArTrainingScreenState extends ConsumerState<ArTrainingScreen>
    with TickerProviderStateMixin {
  CameraController? _camera;
  final _tracker = FrameMotionTracker();
  bool _streaming = false;
  String? _cameraError;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);

  MotionResult _result = MotionResult.empty;
  final List<Offset> _trail = [];
  late List<_Step> _steps;
  int _stepIndex = 0;
  double _progress = 0;
  int _stepCorrect = 0;
  bool _lessonComplete = false;
  double _totalScore = 0;
  bool _flashComplete = false;

  double _boom = 0.35;
  double _swing = 0.0;

  // Directional completion + return-to-neutral gate.
  bool _awaitNeutral = false;
  int _neutralFrames = 0;
  Offset? _stepStart;
  double _stepMaxProj = 0;

  late final AnimationController _pulse;
  late final double _markerHue;
  late final String _markerColor;

  TrainingModule? get _module {
    for (final m in ref.read(trainingModulesProvider)) {
      if (m.id == widget.moduleId) return m;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _steps = _buildSteps(_module);
    _markerHue = _targetHue(widget.moduleId);
    _markerColor = _colorName(_markerHue);
    _tracker.setTarget(_markerHue);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  @override
  void dispose() {
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
      _camera = controller;
      await controller.startImageStream(_onFrame);
      setState(() => _streaming = true);
    } catch (e) {
      setState(() => _cameraError = 'Camera error: $e');
    }
  }

  void _onFrame(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastFrame).inMilliseconds < 60) return;
    _lastFrame = now;
    if (_lessonComplete) return;
    _advance(_tracker.process(image));
  }

  void _advance(MotionResult r) {
    final step = _steps[_stepIndex];

    if (r.center != null) {
      _trail.add(r.center!);
      if (_trail.length > 28) _trail.removeAt(0);
    }
    final dir = r.dominantDir;
    final s = r.speed;
    switch (dir) {
      case MoveDir.forward:
        _boom = (_boom + s * 3.5).clamp(0.0, 1.0);
      case MoveDir.back:
        _boom = (_boom - s * 3.5).clamp(0.0, 1.0);
      case MoveDir.left:
        _swing = (_swing - s * 3.5).clamp(-1.0, 1.0);
      case MoveDir.right:
        _swing = (_swing + s * 3.5).clamp(-1.0, 1.0);
      case MoveDir.none:
        break;
    }

    // Require SUSTAINED stillness (not the momentary dip at the top of a
    // stroke) before the next step can begin.
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
      if (mounted) setState(() => _result = r);
      return;
    }

    // Displacement-based completion in the requested direction.
    final c = r.center;
    if (c != null) {
      _stepStart ??= c;
      final u = _dirUnit(step.dir);
      final disp = c - _stepStart!;
      final proj = disp.dx * u.dx + disp.dy * u.dy;
      if (proj < -0.05) {
        _stepStart = c; // moved back past origin — rebaseline
        _stepMaxProj = 0;
      } else if (proj > _stepMaxProj) {
        _stepMaxProj = proj;
        _stepCorrect++;
      }
      _progress = (_stepMaxProj / _kMoveDist).clamp(0.0, 1.0);
      if (_progress >= 1.0) _completeStep();
    }

    if (mounted) setState(() => _result = r);
  }

  Offset _dirUnit(MoveDir d) => switch (d) {
        MoveDir.forward => const Offset(0, -1),
        MoveDir.back => const Offset(0, 1),
        MoveDir.left => const Offset(-1, 0),
        MoveDir.right => const Offset(1, 0),
        MoveDir.none => Offset.zero,
      };

  void _completeStep() {
    _totalScore += (85 + 15 * (_stepCorrect > 3 ? 1 : 0)).clamp(85, 100);
    final moduleSteps = _module?.steps.length ?? _steps.length;
    final isLast = _stepIndex >= _steps.length - 1;
    ref.read(trainingModulesProvider.notifier).completeStep(
        widget.moduleId, isLast ? moduleSteps - 1 : _stepIndex, 95);

    _stepCorrect = 0;
    _progress = 0;
    _trail.clear();
    _awaitNeutral = true;
    _neutralFrames = 0;
    _stepStart = null;
    _stepMaxProj = 0;

    if (isLast) {
      setState(() => _lessonComplete = true);
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
    _tracker.setTarget(_markerHue);
    setState(() => _result = MotionResult.empty);
  }

  // ------------------------------------------------------------------ //
  // Build
  // ------------------------------------------------------------------ //

  @override
  Widget build(BuildContext context) {
    final module = _module;
    if (module == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Module Not Found')),
        body: const Center(child: Text('Training module not found.')),
      );
    }
    if (_lessonComplete) {
      return _CompletionView(module: module, avgScore: _totalScore / _steps.length);
    }

    final step = _steps[_stepIndex];
    final matched = _result.dominantDir == step.dir;

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
                painter: _OverlayPainter(
                  result: _result,
                  trail: _trail,
                  arrowDir: step.dir,
                  pulse: _pulse.value,
                  matched: matched,
                  label: 'Move ${step.dir.arrow}',
                ),
              ),
            ),
          // Live crane
          Positioned(
            right: 14,
            top: MediaQuery.paddingOf(context).top + 60,
            child: _CraneCard(boom: _boom, swing: _swing),
          ),
          // Searching banner until the marker is acquired
          if (!_result.hasObject) _searchingBanner(),
          _bottomPanel(step, matched),
          _topBar(module),
          if (_flashComplete) Center(child: _CheckFlash(pulse: _pulse.value)),
        ],
      ),
    );
  }

  Widget _cameraLayer() {
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded,
                  size: 64, color: CatColors.textMuted),
              const SizedBox(height: 12),
              Text(_cameraError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CatColors.textSecondary)),
            ],
          ),
        ),
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

  Widget _searchingBanner() {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: CatColors.catYellow),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Point the camera at the $_markerColor marker…',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomPanel(_Step step, bool matched) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.78),
              Colors.black.withValues(alpha: 0.94),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: CatColors.catYellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Step ${_stepIndex + 1} of ${_steps.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CatColors.catYellow,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  _result.hasObject
                      ? Icons.gps_fixed_rounded
                      : Icons.gps_not_fixed_rounded,
                  size: 14,
                  color:
                      _result.hasObject ? CatColors.success : CatColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  'Detected ${_result.dominantDir.arrow}',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        matched ? CatColors.success : CatColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              step.instruction,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.precision_manufacturing_rounded,
                    size: 16, color: CatColors.catYellow),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    step.effect,
                    style: const TextStyle(
                      color: CatColors.catYellow,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(
                  matched ? CatColors.success : CatColors.catYellow,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              !_result.hasObject
                  ? 'Bring the $_markerColor marker into view…'
                  : _awaitNeutral
                      ? 'Return to the centre, then make the next move'
                      : 'Move in the arrow direction — a real move completes it',
              style:
                  const TextStyle(fontSize: 12, color: CatColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(TrainingModule module) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            _GlassButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                module.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
            ),
            _GlassButton(icon: Icons.refresh_rounded, onTap: _reacquire),
          ],
        ),
      ),
    );
  }

  // ---- config ----

  double _targetHue(String id) => switch (id) {
        'lever_control' => 225.0, // blue
        'throttle_control' => 140.0, // green
        'bucket_control' => 300.0, // magenta
        _ => 2.0, // red (gear / default)
      };

  String _colorName(double hue) {
    if (hue < 20 || hue > 340) return 'red';
    if (hue < 50) return 'orange';
    if (hue < 80) return 'yellow';
    if (hue < 165) return 'green';
    if (hue < 200) return 'cyan';
    if (hue < 260) return 'blue';
    return 'purple';
  }

  List<_Step> _buildSteps(TrainingModule? m) {
    switch (m?.id) {
      case 'lever_control':
        return const [
          _Step(dir: MoveDir.forward, instruction: 'Slide the lever UP', effect: 'Hydraulic boom rises'),
          _Step(dir: MoveDir.back, instruction: 'Slide it DOWN', effect: 'Boom lowers'),
          _Step(dir: MoveDir.forward, instruction: 'Push UP to full', effect: 'Boom fully raised'),
          _Step(dir: MoveDir.back, instruction: 'Ease DOWN to rest', effect: 'Boom settles to idle'),
        ];
      case 'throttle_control':
        return const [
          _Step(dir: MoveDir.forward, instruction: 'Raise it UP', effect: 'Throttle increases'),
          _Step(dir: MoveDir.back, instruction: 'Lower it DOWN', effect: 'Throttle decreases'),
          _Step(dir: MoveDir.forward, instruction: 'Push to FULL', effect: 'Max power'),
          _Step(dir: MoveDir.back, instruction: 'Ease to IDLE', effect: 'Engine idles'),
        ];
      case 'bucket_control':
        return const [
          _Step(dir: MoveDir.forward, instruction: 'Tilt it FORWARD', effect: 'Bucket scoops'),
          _Step(dir: MoveDir.back, instruction: 'Tilt it BACK', effect: 'Bucket dumps'),
          _Step(dir: MoveDir.left, instruction: 'Swing it LEFT', effect: 'Arm rotates left'),
          _Step(dir: MoveDir.right, instruction: 'Swing it RIGHT', effect: 'Arm rotates right'),
        ];
      default:
        return const [
          _Step(dir: MoveDir.forward, instruction: 'Move it FORWARD', effect: 'Crane boom rises'),
          _Step(dir: MoveDir.back, instruction: 'Move it BACK', effect: 'Crane boom lowers'),
          _Step(dir: MoveDir.left, instruction: 'Move it LEFT', effect: 'Cab swings left'),
          _Step(dir: MoveDir.right, instruction: 'Move it RIGHT', effect: 'Cab swings right'),
        ];
    }
  }
}

// ===================================================================== //
// Painters + widgets
// ===================================================================== //

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.result,
    required this.trail,
    required this.arrowDir,
    required this.pulse,
    required this.matched,
    required this.label,
  });

  final MotionResult result;
  final List<Offset> trail;
  final MoveDir arrowDir;
  final double pulse;
  final bool matched;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    _paintExpectedArrow(canvas, size);
    _paintTrail(canvas, size);
    final box = result.box;
    if (box != null) {
      final rect = Rect.fromLTRB(
        box.left.clamp(0.0, 1.0) * size.width,
        box.top.clamp(0.0, 1.0) * size.height,
        box.right.clamp(0.0, 1.0) * size.width,
        box.bottom.clamp(0.0, 1.0) * size.height,
      );
      _paintBox(canvas, rect);
      _paintLabel(canvas, rect, size);
    }
  }

  void _paintTrail(Canvas canvas, Size size) {
    if (trail.length < 2) return;
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
          ..color = color.withValues(alpha: 0.15 + 0.55 * t)
          ..strokeWidth = 2 + 5 * t
          ..strokeCap = StrokeCap.round,
      );
    }
    final head = trail.last;
    canvas.drawCircle(
      Offset(head.dx * size.width, head.dy * size.height),
      6 + pulse * 3,
      Paint()..color = color.withValues(alpha: 0.9),
    );
  }

  void _paintBox(Canvas canvas, Rect rect) {
    final color = matched ? CatColors.success : CatColors.catYellow;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    canvas.drawRRect(rr, Paint()..color = color.withValues(alpha: 0.10));
    final len = (rect.shortestSide * 0.25).clamp(12.0, 34.0);
    final p = Paint()
      ..color = color
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

  void _paintLabel(Canvas canvas, Rect rect, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padH = 10.0, padV = 6.0;
    final bw = tp.width + padH * 2;
    final bh = tp.height + padV * 2;
    final lx = (rect.center.dx - bw / 2).clamp(6.0, size.width - bw - 6);
    var ly = rect.top - bh - 8;
    if (ly < 6) ly = rect.bottom + 8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(lx, ly, bw, bh), const Radius.circular(8)),
      Paint()
        ..color = (matched ? CatColors.success : CatColors.catBlack)
            .withValues(alpha: 0.85),
    );
    tp.paint(canvas, Offset(lx + padH, ly + padV));
  }

  void _paintExpectedArrow(Canvas canvas, Size size) {
    if (arrowDir == MoveDir.none) return;
    final center = Offset(size.width / 2, size.height * 0.30);
    final scale = 0.9 + pulse * 0.25;
    final reach = 42.0 * scale;
    final color = (matched ? CatColors.success : Colors.white)
        .withValues(alpha: 0.20 + pulse * 0.16);
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
        ..strokeCap = StrokeCap.round,
    );
    final perp = Offset(-dir.dy, dir.dx);
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((tip - dir * 20 + perp * 15).dx, (tip - dir * 20 + perp * 15).dy)
      ..lineTo((tip - dir * 20 - perp * 15).dx, (tip - dir * 20 - perp * 15).dy)
      ..close();
    canvas.drawPath(head, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) => true;
}

class _CranePainter extends CustomPainter {
  _CranePainter({required this.boom, required this.swing});
  final double boom;
  final double swing;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const yellow = CatColors.catYellow;
    const dark = Color(0xFF2A2A2A);

    canvas.save();
    canvas.translate(w / 2, h * 0.9);
    canvas.rotate(swing * 0.32);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(0, -h * 0.05), width: w * 0.5, height: h * 0.09),
        const Radius.circular(4),
      ),
      Paint()..color = dark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-w * 0.14, -h * 0.20, w * 0.22, h * 0.13),
        const Radius.circular(3),
      ),
      Paint()..color = yellow,
    );

    final mastBase = Offset(0, -h * 0.18);
    final mastTop = Offset(0, -h * 0.56);
    final steel = Paint()
      ..color = yellow
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(mastBase, mastTop, steel);

    final ang = 0.32 + boom * 0.85;
    final len = h * 0.5;
    final tip = mastTop + Offset(math.cos(ang) * len, -math.sin(ang) * len);
    canvas.drawLine(
        mastTop,
        tip,
        Paint()
          ..color = yellow
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);
    canvas.drawLine(mastTop, mastTop + Offset(-w * 0.16, -h * 0.015), steel);

    final hook = Offset(tip.dx, tip.dy + h * 0.2);
    canvas.drawLine(
        tip,
        hook,
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 1.5);
    canvas.drawCircle(hook, 3.5, Paint()..color = Colors.white70);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CranePainter old) =>
      old.boom != boom || old.swing != swing;
}

class _CraneCard extends StatelessWidget {
  const _CraneCard({required this.boom, required this.swing});
  final double boom;
  final double swing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 180,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.precision_manufacturing_rounded,
                  size: 13, color: CatColors.catYellow),
              const SizedBox(width: 4),
              const Text('CRANE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  )),
              const Spacer(),
              Text('${(boom * 100).round()}%',
                  style: const TextStyle(
                      color: CatColors.catYellow,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 2),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _CranePainter(boom: boom, swing: swing),
            ),
          ),
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
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CatColors.success.withValues(alpha: 0.9),
        ),
        child: const Icon(Icons.check_rounded, size: 72, color: Colors.white),
      ),
    );
  }
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({required this.module, required this.avgScore});
  final TrainingModule module;
  final double avgScore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(module.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CatColors.success.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.check_circle_rounded,
                    size: 64, color: CatColors.success),
              ),
              const SizedBox(height: 24),
              const Text('Module Complete! 🎉',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(module.title,
                  style: const TextStyle(
                      fontSize: 16, color: CatColors.textSecondary)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text('${avgScore.round()}%',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        )),
                    const SizedBox(height: 4),
                    const Text('Control Accuracy',
                        style: TextStyle(
                            fontSize: 12, color: CatColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
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
