# app/ — Flutter Mobile App + Web Dashboard

**Owners:** P4 (UI + backend/Firebase) · P3 (AR bridge + ML wiring)

The single Flutter codebase for the operator app, technician app, and the owner **web** dashboard
(built via `flutter build web`). Vertical-adaptive (construction ↔ mining).

## Structure
```
lib/
├── main.dart
├── core/          # theme, router (GoRouter), config, vertical switch (Riverpod)
├── features/
│   ├── auth/          # login, RBAC, vertical routing            (FR-AUTH)
│   ├── safety_gate/   # pre-start seatbelt + camera gate          (FR-GATE)
│   ├── tasks/         # dashboard, cards, start/active, ML ETA     (FR-TASK)
│   ├── voice_log/     # tap-to-speak incident log (sherpa-onnx)    (FR-VOICE)
│   ├── learning_hub/  # AR training entry (everyday objects)       (FR-LEARN)
│   ├── sos/           # BLE SOS mesh                               (FR-SOS)
│   ├── safety/        # on-device seatbelt/fatigue, proximity      (FR-SAFE)
│   └── profile/       # operator profile, skills passport
├── services/      # firebase, ble, ml_client, ar_bridge, sync
└── models/        # data models mirroring Firestore schema
```

## Bottom navbar
`Task | Learning Hub | SOS | Profile`

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
