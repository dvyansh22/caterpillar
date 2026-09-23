/// Typed messages for the Unity↔Flutter AR bridge protocol.
///
/// Contract: P3 ↔ P4 (AGENTS.md interface contract #4).
///
/// Flutter → Unity messages use [ArCommand].
/// Unity → Flutter messages use [ArEvent].
library;

import 'dart:convert';

// ---------------------------------------------------------------------------
// Flutter → Unity commands
// ---------------------------------------------------------------------------

/// Base class for commands sent from Flutter to Unity.
sealed class ArCommand {
  const ArCommand();

  String get type;
  Map<String, dynamic> toJson();

  /// Serialise for the Unity message channel.
  String encode() => jsonEncode({'type': type, ...toJson()});
}

/// Load a 3D model or AR scene in Unity.
class LoadModelCommand extends ArCommand {
  const LoadModelCommand({required this.modelId, this.faultCode});

  final String modelId;
  final String? faultCode;

  @override
  String get type => 'loadModel';

  @override
  Map<String, dynamic> toJson() => {
    'modelId': modelId,
    if (faultCode != null) 'faultCode': faultCode,
  };
}

/// Highlight a specific part in the AR view (for repair).
class HighlightPartCommand extends ArCommand {
  const HighlightPartCommand({required this.partId, required this.faultCode});

  final String partId;
  final String faultCode;

  @override
  String get type => 'highlightPart';

  @override
  Map<String, dynamic> toJson() => {
    'partId': partId,
    'faultCode': faultCode,
  };
}

/// Begin or resume an AR training lesson.
class StartLessonCommand extends ArCommand {
  const StartLessonCommand({required this.lessonId, this.step = 0});

  final String lessonId;
  final int step;

  @override
  String get type => 'startLesson';

  @override
  Map<String, dynamic> toJson() => {
    'lessonId': lessonId,
    'step': step,
  };
}

/// Configure which real-world objects AR should track.
class SetTrackedObjectsCommand extends ArCommand {
  const SetTrackedObjectsCommand({required this.objectIds});

  final List<String> objectIds;

  @override
  String get type => 'setTrackedObjects';

  @override
  Map<String, dynamic> toJson() => {'objectIds': objectIds};
}

// ---------------------------------------------------------------------------
// Unity → Flutter events
// ---------------------------------------------------------------------------

/// Base class for events received from Unity.
sealed class ArEvent {
  const ArEvent();

  factory ArEvent.fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String) {
      'ready' => const EngineReadyEvent(),
      'onModelLoaded' => ModelLoadedEvent(
        modelId: json['modelId'] as String,
        success: json['success'] as bool,
      ),
      'onPartSelected' => PartSelectedEvent(
        partId: json['partId'] as String,
        partName: json['partName'] as String?,
      ),
      'onLessonStepComplete' => LessonStepCompleteEvent(
        lessonId: json['lessonId'] as String,
        step: json['step'] as int,
        score: (json['score'] as num).toDouble(),
        totalSteps: json['totalSteps'] as int,
      ),
      'onTrackingStatus' => TrackingStatusEvent(
        objectId: json['objectId'] as String,
        tracked: json['tracked'] as bool,
      ),
      _ => UnknownArEvent(type: json['type'] as String, data: json),
    };
  }
}

/// The Unity AR engine has booted and is ready to receive commands.
class EngineReadyEvent extends ArEvent {
  const EngineReadyEvent();
}

/// A 3D model finished loading.
class ModelLoadedEvent extends ArEvent {
  const ModelLoadedEvent({required this.modelId, required this.success});

  final String modelId;
  final bool success;
}

/// User tapped a part in the AR view.
class PartSelectedEvent extends ArEvent {
  const PartSelectedEvent({required this.partId, this.partName});

  final String partId;
  final String? partName;
}

/// A training lesson step was completed.
class LessonStepCompleteEvent extends ArEvent {
  const LessonStepCompleteEvent({
    required this.lessonId,
    required this.step,
    required this.score,
    required this.totalSteps,
  });

  final String lessonId;
  final int step;
  final double score;
  final int totalSteps;
}

/// Object tracking gained or lost.
class TrackingStatusEvent extends ArEvent {
  const TrackingStatusEvent({required this.objectId, required this.tracked});

  final String objectId;
  final bool tracked;
}

/// Fallback for unknown event types.
class UnknownArEvent extends ArEvent {
  const UnknownArEvent({required this.type, required this.data});

  final String type;
  final Map<String, dynamic> data;
}
