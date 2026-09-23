/// AR Training Screen — real-time, hands-free everyday-object lesson.
///
/// The camera fills the frame. A bounding box tracks the moving prop (e.g. a
/// mouse), floating text tells the trainee which way to move it, and moving the
/// prop in that direction is detected **in real time** and auto-advances the
/// lesson — no taps. All processing is on-device (see
/// `motion/frame_motion_tracker.dart`).
///
/// Per DESIGN.md §18: maps everyday objects to machine controls
/// (mouse → crane/steering, bottle → throttle, book → bucket). Owner: P3.
library;

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../motion/frame_motion_tracker.dart';
import '../models/training_module.dart';
import '../providers/learning_hub_providers.dart';

/// One step of the real-time lesson: a direction to move + the machine effect.
class _MotionStep {
  const _MotionStep({
    required this.dir,
    required this.instruction,
    required this.effect,
  });
  final MoveDir dir;
  final String instruction;
  final String effect;
}

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
  late List<_MotionStep> _steps;
  int _stepIndex = 0;
  double _progress = 0;
  int _stepCorrect = 0;
  int _stepWrong = 0;
  bool _lessonComplete = false;
  double _totalScore = 0;
  bool _flashComplete = false;

  // Live "machine" state driven by the trainee's motion.
  double _boom = 0.2; // 0..1
  double _swing = 0.0; // -1..1

  late final AnimationController _pulse;

  TrainingModule? get _module {
    final modules = ref.read(trainingModulesProvider);
    for (final m in modules) {
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
      // Rear camera — pointed at the prop on the desk.
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
    if (now.difference(_lastFrame).inMilliseconds < 66) return;
    _lastFrame = now;
    if (_lessonComplete) return;

    final result = _tracker.process(image);
    _advance(result);
  }

  void _advance(MotionResult r) {
    final step = _steps[_stepIndex];
    final dir = r.dominantDir;

    // Drive the live machine HUD from the detected motion.
    final s = r.speed;
    switch (dir) {
      case MoveDir.forward:
        _boom = (_boom + s * 3).clamp(0.0, 1.0);
      case MoveDir.back:
        _boom = (_boom - s * 3).clamp(0.0, 1.0);
      case MoveDir.left:
        _swing = (_swing - s * 3).clamp(-1.0, 1.0);
      case MoveDir.right:
        _swing = (_swing + s * 3).clamp(-1.0, 1.0);
      case MoveDir.none:
        break;
    }

    // Update the auto-advance meter.
    if (step.dir == MoveDir.none) {
      // Acquisition step: fill while an object is being tracked/moved.
      _progress += (r.hasObject || r.energy > 0.015) ? 0.05 : -0.01;
    } else if (dir == step.dir) {
      _stepCorrect++;
      _progress += (0.05 + s * 4).clamp(0.02, 0.14);
    } else if (dir != MoveDir.none && dir.sameAxisAs(step.dir)) {
      _progress += 0.012; // right axis, wrong sign — gentle nudge
    } else if (dir != MoveDir.none) {
      _stepWrong++;
      _progress -= 0.02; // perpendicular motion
    } else {
      _progress -= 0.008; // idle decay
    }
    _progress = _progress.clamp(0.0, 1.0);

    if (_progress >= 1.0) {
      _completeStep();
    }
    if (mounted) setState(() => _result = r);
  }

  void _completeStep() {
    final accuracy = _stepCorrect / (_stepCorrect + _stepWrong + 1);
    final score = (80 + 20 * accuracy).clamp(80.0, 100.0);
    _totalScore += score;
    ref
        .read(trainingModulesProvider.notifier)
        .completeStep(widget.moduleId, _stepIndex, score);

    _stepCorrect = 0;
    _stepWrong = 0;
    _progress = 0;

    if (_stepIndex >= _steps.length - 1) {
      setState(() => _lessonComplete = true);
      return;
    }
    // Brief ✓ flash between steps.
    setState(() {
      _flashComplete = true;
      _stepIndex++;
    });
    Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _flashComplete = false);
    });
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
      return _CompletionView(
        module: module,
        avgScore: _totalScore / _steps.length,
      );
    }

    final step = _steps[_stepIndex];
    final objectShort = _objectShort(module);
    final matched = _result.dominantDir == step.dir && step.dir != MoveDir.none;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- Full-frame camera ---
          _cameraLayer(),

          // --- AR overlay (bounding box, brackets, floating label, arrow) ---
          if (_camera != null && _camera!.value.isInitialized)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _OverlayPainter(
                  result: _result,
                  step: step,
                  pulse: _pulse.value,
                  matched: matched,
                  label: step.dir == MoveDir.none
                      ? 'Move the $objectShort'
                      : 'Move $objectShort ${step.dir.arrow}',
                ),
              ),
            ),

          // --- Top bar ---
          _topBar(module, step),

          // --- Bottom instruction + auto-advance meter + machine HUD ---
          _bottomPanel(module, step, objectShort, matched),

          // --- Step-complete flash ---
          if (_flashComplete)
            Center(
              child: _CheckFlash(pulse: _pulse.value),
            ),
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
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    // Cover the whole screen with the (landscape) preview rotated to portrait.
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

  Widget _topBar(TrainingModule module, _MotionStep step) {
    final tracking = _result.hasObject;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            _GlassButton(
              icon: Icons.close_rounded,
              onTap: () => context.go('/learning-hub'),
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
            // Live tracking chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (tracking ? CatColors.success : CatColors.warning)
                    .withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tracking ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    tracking ? 'Tracking' : 'Searching…',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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

  Widget _bottomPanel(
    TrainingModule module,
    _MotionStep step,
    String objectShort,
    bool matched,
  ) {
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
              Colors.black.withValues(alpha: 0.75),
              Colors.black.withValues(alpha: 0.92),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step counter + live detected direction
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
                Text(
                  'Detected ${_result.dominantDir.arrow}',
                  style: TextStyle(
                    fontSize: 12,
                    color: matched ? CatColors.success : CatColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Instruction
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
            // Machine effect
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
            // Auto-advance meter
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
              step.dir == MoveDir.none
                  ? 'Hold the $objectShort in view and start moving it…'
                  : 'Keep moving — the step completes automatically',
              style: const TextStyle(
                  fontSize: 12, color: CatColors.textSecondary),
            ),
            const SizedBox(height: 14),
            // Live machine HUD
            _MachineHud(boom: _boom, swing: _swing),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ //
  // Step definitions
  // ------------------------------------------------------------------ //

  String _objectShort(TrainingModule m) {
    final o = m.everydayObject;
    if (o == null || o.isEmpty) return 'object';
    return o.split(' ').last.toLowerCase();
  }

  List<_MotionStep> _buildSteps(TrainingModule? m) {
    const acquire = _MotionStep(
      dir: MoveDir.none,
      instruction: 'Point the camera at the object',
      effect: 'Calibrating controls…',
    );
    switch (m?.id) {
      case 'throttle_control':
        return const [
          acquire,
          _MotionStep(
            dir: MoveDir.forward,
            instruction: 'Raise it UP',
            effect: 'Throttle increases — engine revs up',
          ),
          _MotionStep(
            dir: MoveDir.back,
            instruction: 'Lower it DOWN',
            effect: 'Throttle decreases — engine eases',
          ),
          _MotionStep(
            dir: MoveDir.forward,
            instruction: 'Push to FULL throttle',
            effect: 'Max power to the drivetrain',
          ),
          _MotionStep(
            dir: MoveDir.back,
            instruction: 'Ease back to IDLE',
            effect: 'Engine returns to idle',
          ),
        ];
      case 'bucket_control':
        return const [
          acquire,
          _MotionStep(
            dir: MoveDir.forward,
            instruction: 'Tilt it FORWARD',
            effect: 'Bucket curls in to scoop',
          ),
          _MotionStep(
            dir: MoveDir.back,
            instruction: 'Tilt it BACK',
            effect: 'Bucket dumps the load',
          ),
          _MotionStep(
            dir: MoveDir.left,
            instruction: 'Swing it LEFT',
            effect: 'Arm rotates left',
          ),
          _MotionStep(
            dir: MoveDir.right,
            instruction: 'Swing it RIGHT',
            effect: 'Arm rotates right',
          ),
        ];
      default:
        // Steering / crane control (mouse).
        return const [
          acquire,
          _MotionStep(
            dir: MoveDir.forward,
            instruction: 'Move it FORWARD',
            effect: 'Crane boom rises',
          ),
          _MotionStep(
            dir: MoveDir.back,
            instruction: 'Move it BACK',
            effect: 'Crane boom lowers',
          ),
          _MotionStep(
            dir: MoveDir.left,
            instruction: 'Move it LEFT',
            effect: 'Cab swings left',
          ),
          _MotionStep(
            dir: MoveDir.right,
            instruction: 'Move it RIGHT',
            effect: 'Cab swings right',
          ),
        ];
    }
  }
}

// ===================================================================== //
// Overlay painter — bounding box, corner brackets, floating label, arrow
// ===================================================================== //

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.result,
    required this.step,
    required this.pulse,
    required this.matched,
    required this.label,
  });

  final MotionResult result;
  final _MotionStep step;
  final double pulse;
  final bool matched;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    _paintExpectedArrow(canvas, size);
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
    canvas.drawRRect(
      rr,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    // Corner brackets.
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
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padH = 10.0, padV = 6.0;
    final bw = tp.width + padH * 2;
    final bh = tp.height + padV * 2;
    var lx = rect.center.dx - bw / 2;
    var ly = rect.top - bh - 8;
    lx = lx.clamp(6.0, size.width - bw - 6);
    if (ly < 6) ly = rect.bottom + 8;

    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(lx, ly, bw, bh),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      bg,
      Paint()
        ..color = (matched ? CatColors.success : CatColors.catBlack)
            .withValues(alpha: 0.85),
    );
    tp.paint(canvas, Offset(lx + padH, ly + padV));
  }

  void _paintExpectedArrow(Canvas canvas, Size size) {
    if (step.dir == MoveDir.none) return;
    final center = Offset(size.width / 2, size.height * 0.42);
    final scale = 0.9 + pulse * 0.25;
    final reach = 46.0 * scale;
    final color = (matched ? CatColors.success : Colors.white)
        .withValues(alpha: 0.22 + pulse * 0.18);

    final dir = switch (step.dir) {
      MoveDir.forward => const Offset(0, -1),
      MoveDir.back => const Offset(0, 1),
      MoveDir.left => const Offset(-1, 0),
      MoveDir.right => const Offset(1, 0),
      MoveDir.none => Offset.zero,
    };
    final tip = center + dir * reach;
    final base = center - dir * reach * 0.3;

    final shaft = Paint()
      ..color = color
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(base, tip, shaft);

    // Arrow head.
    final perp = Offset(-dir.dy, dir.dx);
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((tip - dir * 22 + perp * 16).dx, (tip - dir * 22 + perp * 16).dy)
      ..lineTo((tip - dir * 22 - perp * 16).dx, (tip - dir * 22 - perp * 16).dy)
      ..close();
    canvas.drawPath(head, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) => true;
}

// ===================================================================== //
// Small widgets
// ===================================================================== //

class _MachineHud extends StatelessWidget {
  const _MachineHud({required this.boom, required this.swing});
  final double boom; // 0..1
  final double swing; // -1..1

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.engineering_rounded,
              size: 16, color: CatColors.textSecondary),
          const SizedBox(width: 8),
          const Text('Machine',
              style: TextStyle(
                  color: CatColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(child: _hudBar('Boom', boom, CatColors.info)),
          const SizedBox(width: 10),
          Expanded(child: _hudBar('Swing', (swing + 1) / 2, CatColors.catYellow)),
        ],
      ),
    );
  }

  Widget _hudBar(String label, double v, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: CatColors.textMuted, fontSize: 10)),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: v.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
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
          onPressed: () => context.go('/learning-hub'),
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
                  style:
                      TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
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
