# AGENTS.md

Guidance for AI coding agents (Claude Code, Cursor, Copilot, etc.) working in this repository.
Humans: see [`README.md`](README.md). Full spec: [`docs/`](docs/).

## ▶ How to use this file
1. Ask the teammate **which role they are: P1, P2, P3, or P4** (or infer it from what they're doing).
2. Jump to that role's **playbook** below and work the tasks **top to bottom**.
3. Respect the **interface contracts** — they are what let 4 people build in parallel without
   breaking each other. Never change a shared contract unilaterally.
4. When a requirement isn't in [`docs/`](docs/), leave a `TODO(<Pn>)` instead of guessing on a shared contract.

Read before non-trivial work: [`docs/SRS.md`](docs/SRS.md) (requirements, `FR-*` IDs) ·
[`docs/EXECUTION_PLAN.md`](docs/EXECUTION_PLAN.md) (ownership) · [`docs/DESIGN.md`](docs/DESIGN.md) (architecture).

---

## What this project is
**Smart Operator Assistant for CAT machinery** — a phone-first companion for Caterpillar operators/
technicians (+ owner web dashboard). Core idea: make the **operator's phone the intelligence layer**
so smart features work even on **old non-telematics machines**. One app, two verticals
(**construction + mining**), swapped by a `vertical` config — never hardcode per-vertical behavior.

| Folder | Owner | Stack |
|---|---|---|
| `app/` | P4 (+P3) | Flutter/Dart |
| `ar/` | P3 | Unity 2022.3 LTS + AR Foundation |
| `backend/` | P1/P2 | FastAPI (Python 3.12) |
| `ml/` | P1/P2 | Python (XGBoost/sklearn/TFLite) |
| `firebase/` | P4 | Firebase config |

---

# Role Playbooks

## 🟦 P1 — Data & Task-Time Estimation
**Mission:** the data foundation + the task-time ML model.
**You work in:** `ml/` (data, generators, training, models) · `backend/app/routers/ml.py` (`/ml/estimate`) · `backend/app/routers/sim.py`.
**You produce (contracts):** the Dataset A/B **column schemas** (`ml/data/schemas/`, `docs/SRS.md §6`); the `/ml/estimate` + `/sim` JSON.
**Implements:** FR-ML-1, FR-ML-5, FR-TASK-2.
**Tasks (in order):**
1. Finalize expanded schemas for Dataset A (telematics) & B (tasks); write them to `ml/data/schemas/`.
2. Build the synthetic generator in `ml/generators/generate.py` for **both verticals**, encoding the
   relationships in the sample CSVs (beginner+bad weather → overrun; unfastened+high idle → alert).
3. Train + evaluate the **XGBoost** task-time regressor in `ml/training/`; export to `ml/models/`.
4. Wire `/ml/estimate` in `backend/` to load the model and return real predictions (keep the JSON shape).
5. Seed a demo dataset into Firestore/BigQuery.
**Done when:** generator emits realistic rows for both verticals; the model beats the naive
`EstimatedTime` baseline; `POST /ml/estimate` returns a real ETA. Never edit `ml/data/raw/` (ground truth).

## 🟩 P2 — Safety / Behavior ML + On-Device Models + RAG
**Mission:** every safety/behavior model + the repair-answer brain.
**You work in:** `ml/training/`, `ml/models/` · `backend/app/routers/ml.py` (`/ml/anomaly`), `rag.py`, `voice.py`.
**You produce (contracts):** `/ml/anomaly`, `/rag/query`, `/voice/nlu` JSON; **TFLite tensor specs** (hand to P3).
**Implements:** FR-ML-2, FR-ML-3, FR-ML-4, FR-SAFE-1, FR-SAFE-3.
**Tasks (in order):**
1. Anomaly / excessive-idling / unsafe-pattern model (IsolationForest/classifier) → serve `/ml/anomaly`.
2. Safety-alert prediction, predictive-maintenance, fuel-anomaly models (`docs/SRS.md §6`, `DESIGN.md §5.4`).
3. Train & export **TFLite** models for seatbelt, fatigue, acoustic; document input/output tensors for P3.
4. Build the RAG corpus (machine manuals) + `/rag/query` (embeddings → vector DB → LLM); back `/voice/nlu` with it.
**Done when:** `/ml/anomaly` returns real scores+reasons; TFLite files exist with documented tensor
specs; `/rag/query` returns grounded answers with sources.

## 🟨 P3 — AR + Model Integration
**Mission:** all AR, and wiring the models into the app.
**You work in:** `ar/` (Unity) · `app/lib/features/learning_hub/` · `app/lib/services/ar_bridge` ·
`app/lib/services/ml_client` (+ on-device TFLite integration).
**You produce (contracts):** the **Unity↔Flutter message protocol**. **You consume:** P2's TFLite specs, P1/P2's FastAPI JSON.
**Implements:** FR-LEARN, FR-REPAIR, plus all "models in the app" wiring.
**Tasks (in order):**
1. Unity AR project + AR Foundation image/object tracking; agree the Unity↔Flutter protocol with P4.
2. **Everyday-object training** module: mouse → steering, water bottle → throttle, with stepped prompts.
3. AR field-repair exploded/animated view (fault-highlighted part).
4. `flutter_unity_widget` bridge in `app/lib/services/ar_bridge`.
5. Integrate on-device **TFLite** (seatbelt/fatigue/acoustic) + **FastAPI clients** (`ml_client`) into the app.
6. *(Stretch)* WebRTC tele-mentoring.
**Done when:** the everyday-object AR lesson runs; the app calls the ML endpoints (stub or real) and
runs a TFLite model on-device. Respect the on-device-vs-cloud split in `docs/DESIGN.md §2`.

## 🟥 P4 — Flutter App + Backend Infra
**Mission:** the app shell, all non-AR screens, auth, Firebase, SOS/BLE, offline.
**You work in:** `app/lib/` (core, features except learning_hub/AR, services: firebase/ble/sync) · `firebase/`.
**You produce (contracts):** the **Firestore data model** (`firebase/firestore.rules`). **You consume:** the FastAPI JSON.
**Implements:** FR-AUTH, FR-GATE, FR-TASK, FR-VOICE, FR-SOS, FR-DASH.
**Tasks (in order):**
1. App scaffold: navigation (`Task | Learning Hub | SOS | Profile`), theming, `vertical` switch (Riverpod).
2. Firebase Auth + RBAC (custom claims) + machine registry; write `firestore.rules` + collections.
3. Pre-start safety gate (seatbelt from data + camera-on; hard block on fail).
4. Task dashboard: cards (name, ML-ETA via `ml_client`, location) → Start Task → active view.
5. Voice-log / incident capture with on-device ASR (sherpa-onnx).
6. **SOS BLE mesh** + proximity (`flutter_blue_plus` + `flutter_nearby_connections`).
7. Offline cache/sync (Isar) + owner web dashboard (`flutter build web`, `fl_chart`).
**Done when:** login→gate→task(with ETA)→voice-log works; SOS relays across phones; verticals switch;
safety path works offline.

---

## Interface contracts — do NOT break without updating both sides
1. **FastAPI JSON** (`backend/app/routers/*.py` ↔ `app/lib/services/ml_client`) — change pydantic + Dart together.
2. **Data schemas** (`docs/SRS.md §6`, `ml/data/schemas/`) — generator, models, dashboard depend on them.
3. **TFLite tensor specs** (P2 → P3).
4. **Unity↔Flutter protocol** (`ar/` ↔ `app/lib/services/ar_bridge`).
5. **Firestore model** (`firebase/firestore.rules`: `users, machines, tasks, incidents, telematics, training, behaviorFlags, sosEvents`).

The backend returns **stub responses** today so the app can integrate before models exist — keep stubs contract-accurate.

## Setup & verify
- App: `cd app && flutter pub get && flutter run` · check `flutter analyze`
- Backend: `cd backend && pip install -r requirements.txt && uvicorn app.main:app --reload` · `GET /health`
- ML: `cd ml && pip install -r requirements.txt` · `python generators/generate.py --help`
- AR: open `ar/` in Unity 2022.3 LTS · Firebase: `firebase deploy --only firestore:rules,storage,functions`

Before pushing: backend must `import app.main` cleanly; app must `flutter analyze` without new errors (CI checks both).

## Conventions
- Dart → `flutter_lints`, feature-first folders. Python → PEP 8 + type hints.
- Commits: imperative subject, optional `type: subject` (`feat: add SOS BLE relay`). Feature branch + PR for shared files.
- Offline-first for all safety features. Vertical behavior comes from config, never hardcoded.

## Guardrails — do NOT
- Commit secrets (`google-services.json`, `GoogleService-Info.plist`, `serviceAccount*.json`, `.env` — git-ignored).
- Edit organizer sample data in `ml/data/raw/`.
- Weaken `firestore.rules` to `allow read, write: if true`.
- Move on-device work to the cloud or vice-versa against `docs/DESIGN.md §2`.
- Change a shared contract unilaterally.
