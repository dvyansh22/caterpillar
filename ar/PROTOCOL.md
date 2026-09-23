# Unity ↔ Flutter AR Protocol

**Owners:** P3 (Unity) ↔ P4 (Flutter shell). Interface contract #4 (AGENTS.md).
**Frozen.** Do not change one side without the other.

Transport: `flutter_unity_widget`.
- **Flutter → Unity:** `UnityWidgetController.postMessage("ArBridge", "ReceiveMessage", <json>)`
- **Unity → Flutter:** `UnityMessageManager.Instance.SendMessageToFlutter(<json>)`

Every message is a flat JSON object with a `type` discriminator.

Dart types: `app/lib/services/ar_bridge/ar_message.dart`.
Unity hub: `ar/Assets/Scripts/ArBridge.cs`.

## Flutter → Unity (commands)

| `type` | Fields | Handled by |
|---|---|---|
| `loadModel` | `modelId: string`, `faultCode?: string` | `FieldRepairController.LoadModel` |
| `highlightPart` | `partId: string`, `faultCode: string` | `FieldRepairController.HighlightPart` |
| `startLesson` | `lessonId: string`, `step: int` | `ObjectTrainingController.StartLesson` |
| `setTrackedObjects` | `objectIds: string[]` | `ObjectTrainingController.SetTrackedObjects` |

## Unity → Flutter (events)

| `type` | Fields | Meaning |
|---|---|---|
| `ready` | `success: bool` | AR engine booted; safe to send commands |
| `onModelLoaded` | `modelId: string`, `success: bool` | Model instantiated (or not found) |
| `onPartSelected` | `partId: string`, `partName?: string` | A part was highlighted/tapped |
| `onLessonStepComplete` | `lessonId: string`, `step: int`, `score: float`, `totalSteps: int` | A lesson step finished with a score |
| `onTrackingStatus` | `objectId: string`, `tracked: bool` | A tracked prop was gained/lost |

## Example exchange

```
Flutter → {"type":"setTrackedObjects","objectIds":["computer_mouse"]}
Unity   → {"type":"onTrackingStatus","objectId":"computer_mouse","tracked":true}
Flutter → {"type":"startLesson","lessonId":"steering_control","step":1}
Unity   → {"type":"onLessonStepComplete","lessonId":"steering_control","step":1,"score":88.0,"totalSteps":5}
```
