# Smart Operator Assistant for CAT Machinery

A **phone-first intelligent companion** for Caterpillar machine operators and technicians — working on
**both telematics-equipped and legacy non-telematics machines**, across **construction** and **mining**.

> *"Caterpillar digitized the machine. We digitize the operator — on every machine, new or old,
> for the price of a phone."*

Built for the Caterpillar hackathon problem statement *"Smart Operator Assistant for CAT machinery."*

---

## What it does
Working today:
- **Daily task dashboard with ML-predicted times.** The ETAs are weather- and location-aware (live
  Open-Meteo forecast), explain themselves, and suggest a best start time (`POST /ml/estimate`).
- **Voice incident logging.** Offline speech-to-text on the phone (sherpa-onnx Whisper, after a
  one-time model download); browser speech on web.
- **Unusual-behavior, safety-alert and maintenance scoring** (`/ml/anomaly`, `/ml/safety`,
  `/ml/maintenance`), with plain-English reasons.
- **Manual Q&A (RAG)** with citations (`/rag/query`, `/voice/nlu`).
- **AR Learning Hub.** Everyday objects mapped to machine controls, running on the phone camera
  with a motion tracker. The Unity AR Foundation scripts are in `ar/`, but not yet embedded in the app.
- **Vertical-adaptive UI** (construction / mining), dark "Night Shift" theme.
- **Owner web dashboard.** Fleet view including non-telematics machines (`GET /ml/fleet`).

Simulated in the UI for now (the real transport or sensors are planned):
- Pre-start safety gate
- SOS BLE mesh relay
- BLE proximity
- On-device seatbelt / fatigue / engine-sound inference. The TFLite models are in `ml/models/`;
  the app still uses a heuristic.

[`docs/FEATURES.md`](docs/FEATURES.md) is the current feature list. [`docs/`](docs/) holds the
**SRS**, **Execution Plan** and **Design** (the original spec).

---

## Repository layout & team ownership

| Path | Owner | Purpose |
|---|---|---|
| [`app/`](app/) | **P4** (UI/backend) + **P3** (AR bridge, ML wiring) | Flutter mobile app + web dashboard |
| [`ar/`](ar/) | **P3** | Unity AR Foundation scripts + Unity↔Flutter protocol (training + field repair) |
| [`backend/`](backend/) | **P1 / P2** | FastAPI AI service (ML, RAG, voice NLU, sim; WebRTC signaling planned) |
| [`ml/`](ml/) | **P1 / P2** | Datasets, synthetic data generator, model training, conditions engine, on-device models |
| [`firebase/`](firebase/) | **P4** | Firestore/Storage rules, indexes, demo-user seeder (no Cloud Functions yet) |
| [`deploy/`](deploy/), `Dockerfile`, `render.yaml` | P1 | Backend image (Hugging Face Spaces / Render) |
| [`docs/`](docs/) | all | Features, SRS, Execution Plan, Design |

Roles: **P1** data + task-time estimation · **P2** safety/behavior ML + on-device TFLite + RAG ·
**P3** AR + model integration · **P4** Flutter UI + backend + SOS/BLE. Full breakdown in
[`docs/EXECUTION_PLAN.md`](docs/EXECUTION_PLAN.md).

---

## Getting started (per module)
- **App:** `cd app && flutter pub get && flutter run`
  - The app uses mock auth/data unless you pass `--dart-define=USE_FIREBASE=true`.
  - It calls the backend at `--dart-define=API_BASE_URL=...` (default `http://localhost:8000`; on an
    Android device or emulator, use your machine's IP or the deployed URL).
- **ML + backend (Python 3.12, from the repo root):**
  ```
  py -3.12 -m venv .venv && .venv\Scripts\activate
  pip install -r ml/requirements.txt -r backend/requirements-dev.txt
  python ml/generators/generate.py && python ml/training/train_task_time.py   # data + ETA model (git-ignored)
  cd backend && uvicorn app.main:app --reload                                   # http://127.0.0.1:8000/docs
  ```
- **Deploy the backend:** root `Dockerfile` (bakes the model) on Hugging Face Spaces
  (`deploy/hf-deploy.sh`) or Render (`render.yaml`).
- **AR:** create a Unity 2022.3 LTS AR Foundation project and add `ar/Assets/Scripts` (see [`ar/README.md`](ar/README.md)).
- **Firebase:** see [`docs/FIREBASE_SETUP.md`](docs/FIREBASE_SETUP.md); `firebase deploy --only firestore:rules,storage`.

## Interface contracts
- Data schemas: [`ml/data/schemas/`](ml/data/schemas/)
- FastAPI request/response JSON: `backend/app/routers/*.py`, live at `/docs`
- On-device model specs: [`ml/ondevice/README.md`](ml/ondevice/README.md)
- Unity↔Flutter protocol: [`ar/PROTOCOL.md`](ar/PROTOCOL.md)
- Firestore data model: `firebase/firestore.rules`

## Tech stack (summary)
- **App:** Flutter · Riverpod · Dio · Firebase (Auth/Firestore) · sherpa-onnx (offline voice) · camera · fl_chart
- **Backend:** FastAPI (Docker: Hugging Face Spaces / Render)
- **ML:** XGBoost / scikit-learn · TensorFlow Lite models for seatbelt and engine sound
- **RAG:** in-memory Qdrant + sentence-transformers (TF-IDF fallback) + Gemini
- **Weather:** Open-Meteo
- **AR:** Unity AR Foundation scripts

Details in [`docs/DESIGN.md`](docs/DESIGN.md).
