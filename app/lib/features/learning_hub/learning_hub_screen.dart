/// Learning Hub — module list screen.
///
/// Shows available AR training modules with progress, difficulty,
/// and everyday-object mapping info. P3 owns this feature.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'screens/ar_training_screen.dart';
import 'screens/combined_training_screen.dart';
import 'models/training_module.dart';
import 'providers/learning_hub_providers.dart';

class LearningHubScreen extends ConsumerWidget {
  const LearningHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(trainingModulesProvider);
    final overallProgress = ref.watch(trainingProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Hub'),
      ),
      body: CustomScrollView(
        slivers: [
          // Overall progress header
          SliverToBoxAdapter(
            child: _ProgressHeader(progress: overallProgress),
          ),

          // Section title
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'AR Training Modules',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: CatColors.textPrimary,
                ),
              ),
            ),
          ),

          // Module cards
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: modules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final module = modules[index];
                return _ModuleCard(
                  module: module,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => module.id == 'combined_control'
                          ? const CombinedTrainingScreen()
                          : ArTrainingScreen(moduleId: module.id),
                    ),
                  ),
                );
              },
            ),
          ),

          // Animated controls manual (mirrors the AR lessons).
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Text(
                'How the Controls Work',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: CatColors.textPrimary,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: _ControlsManual()),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated controls manual — a no-camera, looping demo of each control,
// matching the AR lessons: red gear (slew + reach), blue lever (lift),
// green button (press-and-hold engine start/stop).
// ---------------------------------------------------------------------------

class _ControlsManual extends StatefulWidget {
  const _ControlsManual();

  @override
  State<_ControlsManual> createState() => _ControlsManualState();
}

class _ControlsManualState extends State<_ControlsManual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _ManualRow(
            anim: _c,
            kind: _ManualKind.gear,
            accent: const Color(0xFFFF5252),
            title: 'Red Gear — Direction',
            body: 'Grip the red-capped gear. Move it forward/back to extend or '
                'retract the crane boom, and left/right to slew the cab.',
          ),
          const SizedBox(height: 12),
          _ManualRow(
            anim: _c,
            kind: _ManualKind.lever,
            accent: const Color(0xFF448AFF),
            title: 'Blue Lever — Lift',
            body: 'Slide the blue-knob lever up and down to raise and lower the '
                'boom. Hold it steady to keep the boom at a height.',
          ),
          const SizedBox(height: 12),
          _ManualRow(
            anim: _c,
            kind: _ManualKind.engine,
            accent: const Color(0xFF69F0AE),
            title: 'Green Button — Engine',
            body: 'Press and hold the green button for ~1 second to start the '
                'engine before the drill, and again to stop it at the end.',
          ),
        ],
      ),
    );
  }
}

enum _ManualKind { gear, lever, engine }

class _ManualRow extends StatelessWidget {
  const _ManualRow({
    required this.anim,
    required this.kind,
    required this.accent,
    required this.title,
    required this.body,
  });

  final Animation<double> anim;
  final _ManualKind kind;
  final Color accent;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CatColors.constructionSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: AnimatedBuilder(
              animation: anim,
              builder: (context, _) => CustomPaint(
                painter: _ManualPainter(
                    t: anim.value, kind: kind, accent: accent),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: CatColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualPainter extends CustomPainter {
  _ManualPainter({required this.t, required this.kind, required this.accent});
  final double t; // 0..1 loop
  final _ManualKind kind;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case _ManualKind.gear:
        // Boom slews left↔right and extends in↔out.
        _crane(canvas, size, lift: 0.55, swing: math.sin(t * 2 * math.pi),
            reach: 0.5 + 0.45 * math.sin(t * 2 * math.pi));
      case _ManualKind.lever:
        // Boom lifts up↔down.
        _crane(canvas, size,
            lift: 0.5 + 0.45 * math.sin(t * 2 * math.pi), swing: 0, reach: 0.6);
      case _ManualKind.engine:
        _engine(canvas, size);
    }
  }

  void _crane(Canvas canvas, Size size,
      {required double lift, required double swing, required double reach}) {
    final w = size.width, h = size.height;
    const yellow = CatColors.catYellow;
    final steel = Paint()
      ..color = yellow
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final baseY = h * 0.86;
    final cx = w * 0.42;
    // fixed base + cab
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, baseY - 3), width: w * 0.5, height: h * 0.09),
          const Radius.circular(3)),
      Paint()..color = const Color(0xFF2A2A2A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - w * 0.1, baseY - h * 0.16, w * 0.2, h * 0.11),
          const Radius.circular(3)),
      Paint()..color = yellow,
    );
    final mastTop = Offset(cx, baseY - h * 0.4);
    canvas.drawLine(Offset(cx, baseY - h * 0.13), mastTop, steel);
    final ext = 0.55 + reach * 0.5;
    final hx = swing * w * 0.34 * ext;
    final vy = -(0.3 + lift * 0.6) * h * 0.5 * ext;
    final tip = mastTop + Offset(hx, vy);
    canvas.drawLine(mastTop, tip,
        Paint()
          ..color = yellow
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);
    final hook = Offset(tip.dx, tip.dy + h * 0.14);
    canvas.drawLine(
        tip, hook, Paint()..color = Colors.white70..strokeWidth = 1.5);
    canvas.drawCircle(hook, 2.5, Paint()..color = Colors.white70);
    // accent dot marks the moving tip (which control is driving it).
    canvas.drawCircle(tip, 3.5, Paint()..color = accent);
  }

  void _engine(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final center = Offset(w / 2, h / 2);
    final r = w * 0.26;
    // hold cycles 0→1 then resets, like a press-and-hold.
    final hold = (t * 2) % 1.0;
    // button disc
    canvas.drawCircle(center, r, Paint()..color = accent.withValues(alpha: 0.85));
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // power glyph
    final glyph = Paint()
      ..color = const Color(0xFF141414)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.5),
        -math.pi / 2 + 0.7, 2 * math.pi - 1.4, false, glyph);
    canvas.drawLine(center + Offset(0, -r * 0.55), center + Offset(0, -r * 0.1),
        glyph);
    // hold progress ring
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r + 7),
      -math.pi / 2,
      2 * math.pi * hold,
      false,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ManualPainter old) =>
      old.t != t || old.kind != kind;
}

// ---------------------------------------------------------------------------
// Progress header
// ---------------------------------------------------------------------------

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (progress * 100).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.15),
            theme.colorScheme.secondary.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skills Passport',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$percentage% complete',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CatColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Circular progress
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(
                        theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.12),
              valueColor:
                  AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Module card
// ---------------------------------------------------------------------------

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.onTap});

  final TrainingModule module;
  final VoidCallback onTap;

  IconData _iconForName(String name) => switch (name) {
    'sports_esports' => Icons.sports_esports_rounded,
    'speed' => Icons.speed_rounded,
    'construction' => Icons.construction_rounded,
    'build' => Icons.build_rounded,
    'tune' => Icons.tune_rounded,
    _ => Icons.school_rounded,
  };

  Color _difficultyColor(ModuleDifficulty d) => switch (d) {
    ModuleDifficulty.beginner => CatColors.success,
    ModuleDifficulty.intermediate => CatColors.warning,
    ModuleDifficulty.advanced => CatColors.danger,
  };

  String _difficultyLabel(ModuleDifficulty d) => switch (d) {
    ModuleDifficulty.beginner => 'Beginner',
    ModuleDifficulty.intermediate => 'Intermediate',
    ModuleDifficulty.advanced => 'Advanced',
  };

  String _statusLabel(ModuleStatus s) => switch (s) {
    ModuleStatus.locked => 'Locked',
    ModuleStatus.available => 'Start',
    ModuleStatus.inProgress => 'Continue',
    ModuleStatus.completed => 'Completed',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diffColor = _difficultyColor(module.difficulty);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: module.status == ModuleStatus.locked ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: icon + title + difficulty badge
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconForName(module.iconName),
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (module.everydayObject != null)
                          Text(
                            '${module.everydayObject} → ${module.machineControl}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: CatColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Difficulty chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: diffColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _difficultyLabel(module.difficulty),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: diffColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                module.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: CatColors.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 14),

              // Progress bar + action button
              Row(
                children: [
                  // Progress
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${module.completedSteps}/${module.steps.length} steps',
                          style: const TextStyle(
                            fontSize: 12,
                            color: CatColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: module.progressPercent,
                            minHeight: 4,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation(
                              module.status == ModuleStatus.completed
                                  ? CatColors.success
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Action button
                  FilledButton.tonal(
                    onPressed:
                        module.status == ModuleStatus.locked ? null : onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: module.status == ModuleStatus.completed
                          ? CatColors.success.withValues(alpha: 0.15)
                          : theme.colorScheme.primary.withValues(alpha: 0.15),
                      foregroundColor: module.status == ModuleStatus.completed
                          ? CatColors.success
                          : theme.colorScheme.primary,
                    ),
                    child: Text(_statusLabel(module.status)),
                  ),
                ],
              ),

              // Best score (if any)
              if (module.bestScore > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 16, color: CatColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      'Best: ${module.bestScore.round()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CatColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
