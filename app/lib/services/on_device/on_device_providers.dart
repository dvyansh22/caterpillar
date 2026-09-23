/// Riverpod providers for on-device inference (P3).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'safety_inference_service.dart';

/// The on-device safety inference service.
///
/// Today this is the heuristic backend. To ship real models, swap the
/// constructor for `TfliteSafetyInferenceService()` (see
/// safety_inference_service.dart) — nothing else in the app changes.
final safetyInferenceProvider = Provider<SafetyInferenceService>((ref) {
  final service = HeuristicSafetyInferenceService();
  ref.onDispose(service.dispose);
  return service;
});
