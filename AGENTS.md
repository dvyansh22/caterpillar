# AGENTS.md

Guidance for AI coding agents (Claude Code, Cursor, Copilot, etc.) working in this repository.
Humans: see [`README.md`](README.md). Full spec: [`docs/`](docs/).

---

## What this project is
**Smart Operator Assistant for CAT machinery** — a phone-first intelligent companion for Caterpillar
machine operators and technicians, plus an owner web dashboard. Core idea: make the **operator's
phone the intelligence layer** so smart-machine features work even on **old non-telematics machines**.
Two verticals, one app: **construction + mining** (config-swapped personality).

Read these before making non-trivial changes:
- [`docs/SRS.md`](docs/SRS.md) — requirements (functional reqs are IDed `FR-*`).
- [`docs/EXECUTION_PLAN.md`](docs/EXECUTION_PLAN.md) — who owns what + interface contracts.
- [`docs/DESIGN.md`](docs/DESIGN.md) — architecture, tech stack, data schemas.

---

## Repository map & ownership
| Folder | Owner | Stack | Purpose |
|---|---|---|---|
| `app/` | P4 (+P3) | Flutter/Dart | Mobile app + web dashboard |
| `ar/` | P3 | Unity 2022.3 LTS + AR Foundation | AR training + field repair |
| `backend/` | P1/P2 | FastAPI (Python 3.12) | ML/RAG/sim/signaling API |
| `ml/` | P1/P2 | Python (XGBoost/sklearn/TFLite) | Data + model training |
| `firebase/` | P4 | Firebase | Auth/Firestore/Storage/FCM config |
| `docs/` | all | Markdown | SRS, plan, design |

**Stay in your module.** If a change spans modules, it must respect the interface contracts below —
do not silently change a shared contract.

---

## Interface contracts — DO NOT break without updating both sides
1. **FastAPI JSON contract** — request/response shapes in `backend/app/routers/*.py`. The app calls
   these; changing a field breaks `app/lib/services/ml_client`. Update the pydantic schema AND the
   Dart client together.
2. **Data schemas** — column lists in `docs/SRS.md §6` and `ml/data/schemas/`. The generator, models,
   and dashboard all depend on these. The organizer sample CSVs in `ml/data/raw/` are ground truth —
   never edit them.
3. **TFLite model spec** — input/output tensor shapes agreed between `ml/` (producer) and
   `app/lib/services` (consumer).
4. **Unity↔Flutter protocol** — message names/payloads between `ar/` and `app/lib/services/ar_bridge`.
5. **Firestore data model** — collections in `firebase/firestore.rules`
   (`users, machines, tasks, incidents, telematics, training, behaviorFlags, sosEvents`).

The backend currently returns **stub responses** so the app can integrate before models are trained.
Keep stubs contract-accurate when you add real logic.

---

## Setup & commands
- **App:** `cd app && flutter pub get && flutter run` · web: `flutter build web` · check: `flutter analyze`
- **Backend:** `cd backend && pip install -r requirements.txt && uvicorn app.main:app --reload` ·
  health: `GET /health`
- **ML:** `cd ml && pip install -r requirements.txt` · generator: `python generators/generate.py --help`
- **AR:** open `ar/` in Unity 2022.3 LTS (AR Foundation + ARCore/ARKit plugins)
- **Firebase:** `firebase deploy --only firestore:rules,storage,functions`

Verify before pushing: backend must `import app.main` cleanly; app must `flutter analyze` without new
errors. CI (`.github/workflows/ci.yml`) runs these on push/PR.

---

## Conventions
- **Language/style:** Dart → `flutter_lints`; Python → PEP 8, type hints, `ruff`/`black` friendly.
- **State/nav (app):** Riverpod + GoRouter. Feature-first folders under `app/lib/features/<feature>/`.
- **Commits:** short imperative subject, optionally `type: subject` (e.g. `feat: add SOS BLE relay`).
- **Branches/PRs:** prefer a feature branch + PR for anything non-trivial on a shared file.
- **Vertical-adaptive:** never hardcode construction-vs-mining behavior; drive it from the `vertical`
  config/Remote Config.
- **Offline-first:** safety features (gate, seatbelt/fatigue, SOS, voice log) must work with NO network.

## Guardrails — do NOT
- Commit secrets: `google-services.json`, `GoogleService-Info.plist`, `serviceAccount*.json`, `.env`
  (already git-ignored — keep it that way).
- Edit the organizer sample data in `ml/data/raw/`.
- Weaken `firebase/firestore.rules` to `allow read, write: if true`.
- Add heavy real ML inference on-device where a `backend/` call belongs (and vice-versa) — respect the
  on-device vs cloud split in `docs/DESIGN.md §2`.
- Change a shared interface contract unilaterally — coordinate both sides.

## When unsure
Check `docs/` first; if the requirement isn't there, leave a `TODO(<owner>)` and note the open
question rather than guessing on a shared contract.
