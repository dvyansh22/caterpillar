# Smart Operator Assistant for CAT Machinery

A **phone-first intelligent companion** for Caterpillar machine operators and technicians — working on
**both telematics-equipped and legacy non-telematics machines**, across **construction** and **mining**.

> *"Caterpillar digitized the machine. We digitize the operator — on every machine, new or old,
> for the price of a phone."*

Built for the Caterpillar hackathon problem statement *"Smart Operator Assistant for CAT machinery."*

---

## What it does
- **Daily task dashboard** with **ML-predicted** task times
- **Real-time safety** using the phone as the sensor: seatbelt + fatigue (camera), BLE proximity, incident logging, acoustic engine anomaly
- **SOS** over BLE mesh (works with no cellular)
- **AR Learning Hub** — AR training that maps everyday objects to machine controls
- **Unusual-behavior detection** (idling, unsafe patterns) → **closed-loop** auto-assigned training
- **Vertical-adaptive UI** — one app, two personalities (construction / mining)
- **Owner web dashboard** — fleet visibility including non-telematics machines

See [`docs/`](docs/) for the full **SRS**, **Execution Plan**, and **Design** documents.

---

## Repository layout & team ownership

| Path | Owner | Purpose |
|---|---|---|
| [`app/`](app/) | **P4** (UI/backend) + **P3** (AR bridge, ML wiring) | Flutter mobile app + web dashboard |
| [`ar/`](ar/) | **P3** | Unity AR Foundation project (training + field repair) |
| [`backend/`](backend/) | **P1 / P2** | FastAPI AI service (ML, RAG, sim, signaling) |
| [`ml/`](ml/) | **P1 / P2** | Datasets + model training + synthetic data generator |
| [`firebase/`](firebase/) | **P4** | Firestore/Storage rules, indexes, Cloud Functions |
| [`docs/`](docs/) | all | SRS, Execution Plan, Design |

Roles: **P1** data + task-time estimation · **P2** safety/behavior ML + on-device TFLite + RAG ·
**P3** AR + model integration · **P4** Flutter UI + backend + SOS/BLE. Full breakdown in
[`docs/EXECUTION_PLAN.md`](docs/EXECUTION_PLAN.md).

---

## Getting started (per module)
- **App:** `cd app && flutter pub get && flutter run`
- **Backend:** `cd backend && pip install -r requirements.txt && uvicorn app.main:app --reload`
- **ML:** `cd ml && pip install -r requirements.txt` (generators/, training/, notebooks/)
- **AR:** open `ar/` in Unity 2022.3 LTS with AR Foundation
- **Firebase:** configure a project, then `firebase deploy` (rules/functions)

## Interface contracts to freeze first (Phase 0)
Data schemas · FastAPI request/response JSON (with stub responses) · TFLite tensor specs ·
Unity↔Flutter message protocol · Firestore data model. See [`docs/EXECUTION_PLAN.md`](docs/EXECUTION_PLAN.md).

## Tech stack (summary)
Flutter · Unity (AR Foundation) · Firebase (Auth/Firestore/Storage/FCM) · FastAPI (Cloud Run) ·
XGBoost / scikit-learn · TFLite / MediaPipe · sherpa-onnx (offline voice) · flutter_blue_plus (BLE) ·
Qdrant/Chroma + Gemini (RAG). Full details in [`docs/DESIGN.md`](docs/DESIGN.md).
