# app/ — Flutter Mobile App + Web Dashboard

**Owners:** P4 (UI + backend/Firebase) · P3 (AR bridge + ML wiring)

The single Flutter codebase for the operator app, technician app, and the owner **web** dashboard
(built via `flutter build web`). Vertical-adaptive (construction ↔ mining).

Built to the "Night Shift" **dark** design (`docs/design/handoff/`, earlier light version in
`docs/design/operator_app/`); two verticals (construction/mining) driven by the signed-in account.

## Structure
```
lib/
├── main.dart              # root: web → owner dashboard; mobile → phase switch (login/gate/welcome/app)
├── firebase_options.dart  # FlutterFire config (project smart-operator)
├── core/
│   ├── config.dart        # USE_FIREBASE / API_BASE_URL dart-defines + AppConstants
│   ├── tokens.dart        # colour tokens + per-vertical AccentPalette
│   ├── theme.dart         # Night Shift dark ThemeData (Oswald / Inter / JetBrains Mono)
│   ├── nav.dart           # NavController (phase/tab/subview state; no router package)
│   └── app_state.dart     # AppController (session, tasks, logs, lessons, sos) + providers
├── data/                  # models.dart + mock_data.dart (users/tasks/lessons, offline seed)
├── features/
│   ├── auth/              # login + demo accounts                                (FR-AUTH)
│   ├── safety_gate/       # pre-start seatbelt + camera gate (simulated checks)  (FR-GATE)
│   ├── welcome/           # post-gate welcome
│   ├── tasks/             # list + detail with live ML ETA, active task + voice log (FR-TASK/FR-VOICE)
│   ├── learning_hub/      # lessons, camera AR training (motion tracker), AR repair, operator console (FR-LEARN)
│   ├── sos/               # hold-to-send SOS + relay steps (relay simulated)     (FR-SOS)
│   ├── profile/           # profile + skills passport
│   ├── dashboard/         # owner/fleet web dashboard (fl_chart, /ml/fleet)      (FR-DASH)
│   └── shell/             # main_shell: app bar, 3-tab nav, floating SOS
└── services/
    ├── ml_client/         # Dio client for /ml/estimate, /ml/fleet, /ml/anomaly, /rag/query (+ offline fallbacks)
    ├── voice/             # sherpa-onnx Whisper (mobile, offline) / speech_to_text (web)
    ├── on_device/         # safety inference (heuristic today; TFLite models planned)
    ├── ar_bridge/         # Unity↔Flutter protocol (mock bridge until Unity is embedded)
    └── *_repository / *_auth_service.dart   # mock ↔ Firebase implementations
```
(`features/safety/`, `features/voice_log/` and `lib/models/` are empty placeholders.)

**Real:**
- the ML ETA from `/ml/estimate`;
- Firebase auth and data (with `USE_FIREBASE=true`);
- voice-to-text;
- the owner dashboard.

**Simulated:**
- the safety-gate checks (timers);
- the SOS BLE relay;
- on-device safety inference (heuristic);
- Unity (mock bridge).

## Navigation
Flow: **login → safety gate → welcome → app**. In-app: 3-tab bottom nav
**Task | Learning Hub | Profile** with a **floating SOS button** on every tab (opens a full SOS view).

## Run
```
flutter pub get
flutter run                                    # mobile, mock auth/data
flutter run --dart-define=USE_FIREBASE=true    # real Firebase (see docs/FIREBASE_SETUP.md)
flutter run --dart-define=API_BASE_URL=https://<your-backend>   # ML backend (default http://localhost:8000)
flutter build web                              # owner dashboard
```
On an Android phone or emulator, `localhost` is the device itself. Point `API_BASE_URL` at your
computer's IP or at the deployed backend.

## Key packages (see pubspec.yaml)
flutter_riverpod · dio · firebase_core / firebase_auth / cloud_firestore · camera · sherpa_onnx ·
speech_to_text · record · path_provider · google_fonts · fl_chart.
`go_router` is declared but not used.

Planned and **not yet added**:
- flutter_blue_plus / flutter_nearby_connections (SOS/proximity)
- sensors_plus
- flutter_unity_widget
- tflite
- google_maps_flutter
- isar
- firebase storage/messaging
