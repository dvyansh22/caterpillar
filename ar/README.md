# ar/ — Unity AR Project

**Owner:** P3

Unity **2022.3 LTS** project using **AR Foundation** (ARCore/ARKit), embedded into the Flutter app via
`flutter_unity_widget`. Handles:

- **AR Learning Hub (everyday-object training):** maps a computer mouse → steering and a water bottle
  → throttle using AR Foundation image/object tracking, with animated prompts and step tracking.
  (FR-LEARN)
- **AR Field Repair:** exploded 3D view of a machine, fault-highlighted component, animated repair
  steps. Same pipeline later loads real Cat-machine models. (FR-REPAIR)

## Setup
1. Install Unity 2022.3 LTS + AR Foundation, ARCore XR Plugin, ARKit XR Plugin.
2. Open this folder as a Unity project.
3. Export as an Android/iOS library and integrate via `flutter_unity_widget` (see app/lib/services/ar_bridge).

## Unity ↔ Flutter message protocol (freeze in Phase 0 with P4)
Messages such as: `loadModel(modelId)`, `highlightPart(faultCode)`, `startLesson(lessonId)`,
`lessonStep(index)`, `progress(score)`. Define exact payloads jointly with P4.

> Unity's own generated folders (Library/, Temp/, etc.) are git-ignored — see root `.gitignore`.
