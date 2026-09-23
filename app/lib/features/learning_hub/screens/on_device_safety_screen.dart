/// On-Device Safety demo — live seatbelt / fatigue / acoustic inference.
///
/// Demonstrates P3's "models in the app" wiring (AGENTS.md task #5): frames
/// are captured, a feature vector is extracted **on-device**, and the
/// [SafetyInferenceService] returns live scores — no network round-trip.
/// Per `docs/DESIGN.md §2` this class of detection must stay on-device.
///
/// The heuristic backend ships today; swapping in the TFLite backend (once P2
/// delivers models) changes nothing in this screen.
library;

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../services/on_device/on_device_providers.dart';
import '../../../services/on_device/safety_models.dart';

class OnDeviceSafetyScreen extends ConsumerStatefulWidget {
  const OnDeviceSafetyScreen({super.key});

  @override
  ConsumerState<OnDeviceSafetyScreen> createState() =>
      _OnDeviceSafetyScreenState();
}

class _OnDeviceSafetyScreenState extends ConsumerState<OnDeviceSafetyScreen> {
  CameraController? _camera;
  bool _streaming = false;
  bool _cameraFailed = false;

  SafetyReading _reading = SafetyReading.initial();
  int _frameIndex = 0;
  double _prevLuma = 0.0;
  double _motionEma = 0.0;
  DateTime _lastInfer = DateTime.fromMillisecondsSinceEpoch(0);

  // Fallback ticker used when the camera or image stream is unavailable, so
  // the on-device pipeline is still demonstrably running.
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    await ref.read(safetyInferenceProvider).warmUp();
    await _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _startFallback();
        return;
      }
      // Prefer the operator-facing (front) camera for seatbelt/fatigue.
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        cam,
        ResolutionPreset.low,
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
      debugPrint('[OnDeviceSafety] camera init failed: $e — using fallback');
      _cameraFailed = true;
      _startFallback();
    }
  }

  /// Extract on-device features from a BGRA frame and run inference (throttled).
  void _onFrame(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastInfer).inMilliseconds < 150) return;
    _lastInfer = now;

    final luma = _meanLumaBgra(image);
    final delta = (luma - _prevLuma).abs();
    _prevLuma = luma;
    _motionEma = (_motionEma * 0.7) + (delta * 5.0 * 0.3);

    final reading = ref.read(safetyInferenceProvider).infer(
          SafetyFeatures(
            meanLuma: luma,
            motion: _motionEma.clamp(0.0, 1.0),
            frameIndex: _frameIndex++,
          ),
        );
    if (mounted) setState(() => _reading = reading);
  }

  /// Sample the luminance of a BGRA8888 frame cheaply (every ~40th pixel).
  double _meanLumaBgra(CameraImage image) {
    final bytes = image.planes.first.bytes;
    if (bytes.isEmpty) return _prevLuma;
    var sum = 0.0;
    var count = 0;
    // 4 bytes per pixel (B, G, R, A); step to keep this ~a few hundred samples.
    const step = 4 * 40;
    for (var i = 0; i + 2 < bytes.length; i += step) {
      final b = bytes[i];
      final g = bytes[i + 1];
      final r = bytes[i + 2];
      sum += (0.114 * b + 0.587 * g + 0.299 * r);
      count++;
    }
    if (count == 0) return _prevLuma;
    return (sum / count) / 255.0;
  }

  void _startFallback() {
    _fallbackTimer?.cancel();
    var t = 0;
    _fallbackTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      // Synthesise gentle motion so the pipeline produces a live signal.
      final motion = (0.05 + 0.05 * (t % 20 < 10 ? 1 : 0)).toDouble();
      final reading = ref.read(safetyInferenceProvider).infer(
            SafetyFeatures(
              meanLuma: 0.45,
              motion: motion,
              frameIndex: t++,
            ),
          );
      if (mounted) setState(() => _reading = reading);
    });
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backend = ref.read(safetyInferenceProvider).backendLabel;
    final r = _reading;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/learning-hub'),
        ),
        title: const Text('On-Device Safety'),
      ),
      body: Column(
        children: [
          // Camera / status viewport
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: r.hasWarning
                      ? CatColors.danger.withValues(alpha: 0.7)
                      : CatColors.success.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_camera != null && _camera!.value.isInitialized)
                    Positioned.fill(child: CameraPreview(_camera!))
                  else
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _cameraFailed
                                ? Icons.videocam_off_rounded
                                : Icons.memory_rounded,
                            size: 64,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _cameraFailed
                                ? 'Camera unavailable — running synthetic feed'
                                : 'Starting on-device inference…',
                            style: const TextStyle(
                                color: CatColors.textSecondary),
                          ),
                        ],
                      ),
                    ),

                  // Live/on-device badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _Badge(
                      color: theme.colorScheme.primary,
                      icon: Icons.bolt_rounded,
                      text: 'ON-DEVICE • $backend',
                    ),
                  ),

                  // Overall safety banner
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: _StatusBanner(reading: r),
                  ),
                ],
              ),
            ),
          ),

          // Live gauges
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live Safety Signals',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Inference runs locally on the phone — no network.',
                    style:
                        TextStyle(fontSize: 12, color: CatColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Gauge(
                        label: 'Seatbelt',
                        value: r.seatbeltFastened,
                        good: r.seatbeltFastened >= 0.5,
                        goodText: 'Fastened',
                        badText: 'Unfastened',
                      ),
                      _Gauge(
                        label: 'Alertness',
                        value: r.alertness,
                        good: r.fatigueScore <= 0.6,
                        goodText: 'Alert',
                        badText: 'Drowsy',
                      ),
                      _Gauge(
                        label: 'Acoustic',
                        value: 1.0 - r.acousticAnomaly,
                        good: r.acousticAnomaly <= 0.6,
                        goodText: 'Nominal',
                        badText: 'Anomaly',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.label,
    required this.value,
    required this.good,
    required this.goodText,
    required this.badText,
  });

  final String label;
  final double value; // 0..1, higher = better
  final bool good;
  final String goodText;
  final String badText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = good ? CatColors.success : CatColors.danger;
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 68,
                  height: 68,
                  child: CircularProgressIndicator(
                    value: value.clamp(0.0, 1.0),
                    strokeWidth: 6,
                    backgroundColor: theme.colorScheme.primary
                        .withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text(
                  '${(value * 100).round()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            good ? goodText : badText,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.reading});
  final SafetyReading reading;

  @override
  Widget build(BuildContext context) {
    final warn = reading.hasWarning;
    final color = warn ? CatColors.danger : CatColors.success;
    final msgs = <String>[];
    if (reading.seatbeltFastened < 0.5) msgs.add('Fasten seatbelt');
    if (reading.fatigueScore > 0.6) msgs.add('Fatigue detected — take a break');
    if (reading.acousticAnomaly > 0.6) msgs.add('Abnormal engine sound');
    final text = warn ? msgs.join(' • ') : 'All safety checks nominal';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(warn ? Icons.warning_amber_rounded : Icons.verified_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.black),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
