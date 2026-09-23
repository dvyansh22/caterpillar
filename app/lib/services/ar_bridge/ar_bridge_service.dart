/// Unity↔Flutter AR bridge service.
///
/// Abstract interface + mock implementation. When the Unity AR project
/// (`ar/`) is exported and `flutter_unity_widget` is enabled, swap in
/// [UnityArBridgeService].
///
/// Contract: P3 ↔ P4 (AGENTS.md interface contract #4).
library;

import 'dart:async';

import 'ar_message.dart';

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

/// Bridge between Flutter and the Unity AR engine.
abstract class ArBridgeService {
  /// Stream of events coming from Unity.
  Stream<ArEvent> get events;

  /// Send a command to Unity.
  Future<void> send(ArCommand command);

  /// Whether the Unity AR engine is currently loaded and ready.
  bool get isReady;

  /// Dispose resources.
  void dispose();
}

// ---------------------------------------------------------------------------
// Mock implementation (used until Unity export is available)
// ---------------------------------------------------------------------------

/// Mock bridge that simulates Unity responses with realistic delays.
/// Allows the Learning Hub and Repair screens to be fully functional
/// and testable without the Unity engine.
class MockArBridgeService implements ArBridgeService {
  MockArBridgeService();

  final _controller = StreamController<ArEvent>.broadcast();
  bool _ready = true;

  @override
  Stream<ArEvent> get events => _controller.stream;

  @override
  bool get isReady => _ready;

  @override
  Future<void> send(ArCommand command) async {
    // Simulate Unity processing delay.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    switch (command) {
      case LoadModelCommand(:final modelId):
        _controller.add(ModelLoadedEvent(modelId: modelId, success: true));

      case HighlightPartCommand(:final partId):
        // Simulate part being selected after highlight.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        _controller.add(PartSelectedEvent(partId: partId, partName: 'Mock Part'));

      case StartLessonCommand(:final lessonId, :final step):
        // Simulate step completion after a short delay.
        await Future<void>.delayed(const Duration(seconds: 2));
        _controller.add(LessonStepCompleteEvent(
          lessonId: lessonId,
          step: step,
          score: 85.0 + (step * 3.0),
          totalSteps: 5,
        ));

      case SetTrackedObjectsCommand(:final objectIds):
        // Simulate tracking detected for each object.
        for (final id in objectIds) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          _controller.add(TrackingStatusEvent(objectId: id, tracked: true));
        }
    }
  }

  @override
  void dispose() {
    _ready = false;
    _controller.close();
  }
}

// ---------------------------------------------------------------------------
// Real Unity implementation (stub — wired when flutter_unity_widget enabled)
// ---------------------------------------------------------------------------

// TODO(P3): Implement when Unity export is available.
// class UnityArBridgeService implements ArBridgeService {
//   // Uses flutter_unity_widget's UnityWidgetController to send/receive messages.
//   // Channel: AppConstants.unityMessageChannel
// }
