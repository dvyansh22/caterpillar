# app/ — Flutter Mobile App + Web Dashboard

**Owners:** P4 (UI + backend/Firebase) · P3 (AR bridge + ML wiring)

The single Flutter codebase for the operator app, technician app, and the owner **web** dashboard
(built via `flutter build web`). Vertical-adaptive (construction ↔ mining).

Built to the design handoff in [`docs/design/operator_app`](../docs/design/operator_app) — a warm
**light** theme, two verticals (construction/mining) driven by the signed-in account.

## Structure
```
lib/
├── main.dart          # root: phase switch (login/gate/welcome/app), phone-width cap
├── core/
│   ├── tokens.dart    # neutral color tokens + per-vertical AccentPalette
│   ├── theme.dart     # light ThemeData
│   ├── nav.dart       # NavController (phase/tab/subview state)
│   └── app_state.dart # AppController (session, tasks, logs, lessons, sos) + providers
├── data/              # models.dart + mock_data.dart (users/tasks/lessons)
├── features/
│   ├── auth/          # login + demo accounts (arjun/bala)          (FR-AUTH)
│   ├── safety_gate/   # pre-start seatbelt + camera gate            (FR-GATE)
│   ├── welcome/       # post-gate welcome
│   ├── tasks/         # list, detail, active (voice log)      (FR-TASK/FR-VOICE)
│   ├── learning_hub/  # lessons + AR lesson (everyday objects)      (FR-LEARN)
│   ├── sos/           # hold-to-send BLE SOS + relay steps          (FR-SOS)
│   ├── profile/       # profile + skills passport
│   └── shell/         # main_shell: app bar, 3-tab nav, floating SOS
```
Mock data/timers stand in for Firebase, `/ml/estimate`, sherpa-onnx, BLE and Unity — wire those up.

## Navigation
Flow: **login → safety gate → welcome → app**. In-app: 3-tab bottom nav
**Task | Learning Hub | Profile** with a **floating SOS button** on every tab (opens a full SOS view).

## Run
```
flutter pub get
flutter run              # mobile
flutter build web        # owner dashboard
```

## Key packages (see pubspec.yaml)
flutter_riverpod · go_router · firebase_core/auth/firestore/storage/messaging · camera ·
sensors_plus · flutter_blue_plus · flutter_nearby_connections · sherpa_onnx · flutter_unity_widget ·
google_maps_flutter · fl_chart · isar.
