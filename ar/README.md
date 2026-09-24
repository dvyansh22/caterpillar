# ar/ — Unity AR Project

**Owner:** P3

Unity **2022.3 LTS** project using **AR Foundation** (ARCore/ARKit), embedded into the Flutter app via
`flutter_unity_widget`. Handles:

- **AR Learning Hub (everyday-object training):** maps a computer mouse → steering and a water bottle
  → throttle using AR Foundation image/object tracking, with animated prompts and step tracking.
  (FR-LEARN)
- **AR Field Repair:** exploded 3D view of a machine, fault-highlighted component, animated repair
  steps. Same pipeline later loads real Cat-machine models. (FR-REPAIR)

## Scripts (`Assets/Scripts/`)
- **`ArBridge.cs`** — message hub. Parses Flutter commands, dispatches to the
  controllers, and emits typed JSON events. Singleton (`ArBridge.Instance`).
- **`ObjectTrainingController.cs`** — everyday-object lessons (FR-LEARN): AR
  object tracking, per-step motion scoring, progress events.
- **`FieldRepairController.cs`** — field repair (FR-REPAIR): load model,
  exploded view, highlight the faulted part.
- **`MouseTracker.cs`** — reusable prop visual (bounding box + billboard text)
  attached to detected objects; also defines the `Billboard` helper.

## Scene setup
1. Create an **AR Session** + **AR Session Origin** (XR Origin) with an
   **AR Camera**.
2. Add an empty GameObject named **`ArBridge`** with the `ArBridge` component.
3. Add `ObjectTrainingController` (needs an `ARTrackedObjectManager` + a
   reference-object library of the props) and `FieldRepairController`; wire both
   into `ArBridge`'s `training` / `repair` fields.
4. Assign a `trackedObjectVisualPrefab` (a prefab with `MouseTracker`) and a
   `highlightMaterial`. Put machine models under `Resources/Models/<modelId>`.

## Setup / build
1. Install Unity 2022.3 LTS + AR Foundation, ARCore XR Plugin, ARKit XR Plugin,
   TextMeshPro.
2. This folder holds only the C# scripts (`Assets/Scripts/`). `ProjectSettings/` is an empty
   placeholder and there are no scenes or packages yet. Create a new Unity 2022.3 AR Foundation
   project, copy `Assets/Scripts/` into it, and build the scene as described above.
3. Export as an Android/iOS library and integrate via `flutter_unity_widget`
   into `app/ios/UnityLibrary` + `app/android/unityLibrary`.
   - Add `flutter_unity_widget` to `app/pubspec.yaml`; it isn't listed there yet.
   - Swap `arBridgeProvider` to `UnityArBridgeService` (see `app/lib/services/ar_bridge`).

> Until the Unity export exists, the Flutter app runs AR training on the phone camera with its own
> frame-differencing motion tracker (`app/lib/features/learning_hub/motion/`). The bridge screens use
> `MockArBridgeService`, so the UX is fully testable without Unity.

## Protocol
The frozen Unity↔Flutter message contract lives in [`PROTOCOL.md`](PROTOCOL.md)
and mirrors `app/lib/services/ar_bridge/ar_message.dart`.

> Unity's own generated folders (Library/, Temp/, etc.) are git-ignored — see root `.gitignore`.
