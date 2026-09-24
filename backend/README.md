# backend/ — FastAPI AI Service

**Owners:** P1 / P2

The cloud "AI brain." A stateless FastAPI service that serves ML inference, RAG, voice NLU and
synthetic data. It is deployed as one Docker image built from the repo root (`../Dockerfile`, which
also copies `ml/` and bakes the task-time model) on Hugging Face Spaces or Render.

It is a public API: CORS is open (`*`) and there is no auth yet. Firebase ID-token verification and
WebRTC signaling (`/signal`) are planned.

## Endpoints
| Route | Purpose | Owner |
|---|---|---|
| `GET  /health` | Liveness check | — |
| `POST /ml/estimate` | Task-time estimation (XGBoost; weather + location aware) | P1 |
| `POST /ml/anomaly` | Unusual-behavior scoring (XGBoost multi-class + rule reasons) | P2 |
| `POST /ml/safety` | Safety-alert prediction (XGBoost + rules), same session body as `/ml/anomaly` | P2 |
| `POST /ml/maintenance` | Predictive maintenance (XGBoost + rules), same session body | P2 |
| `GET  /ml/fleet?vertical=` | Fleet snapshot for the owner dashboard, aggregated from generated (labelled) telematics | P4 |
| `POST /rag/query` | Repair-manual Q&A (retrieval + Gemini, or extractive without a key) | P2 |
| `POST /voice/nlu` | Voice transcript → intent (regex commands) or RAG answer | P2 |
| `POST /sim/generate` | Synthetic telematics/task rows (count + 20-row sample) | P1 |
| `WS  /signal` | WebRTC signaling for tele-mentoring — **planned, not implemented** | P3 |

Model files (`ml/models/*.joblib`) are git-ignored. Without them, each endpoint falls back:
- `/ml/estimate` returns the planner baseline (`baseline-0`), or `stub-0` if `ml/` isn't deployed;
- `/ml/anomaly`, `/ml/safety` and `/ml/maintenance` use rules only (`rules-1`).

### `/ml/estimate` v1.1: weather + location (for P3's `ml_client`; all additions optional)
Old requests work unchanged and still get `estimated_minutes`, `baseline_minutes` and `model_version`.
- **New optional request fields:**
  - where: `site_id` (SITE01–07) or `latitude` + `longitude`;
  - when: `start_time` (ISO; no timezone = site local, default now);
  - the app's own weather: `temperature_c`, `humidity_pct`, `wind_speed_kmh`, `visibility_m`, `precip_mm_h`;
  - `suggest_start` (bool).
- **New optional response fields:**
  - `weather_source`: `open-meteo` | `site-typical` (offline) | `client` | `label-only`;
  - `conditions`: incl. `wbgt_c` and `work_fraction`;
  - `factors`: `[{name, minutes, detail}]`, which sum to `estimated_minutes - baseline_minutes`;
  - `advisories` (safety tips);
  - `best_start`: `{start_time, estimated_minutes, minutes_saved, reason}`.

With a location, the backend fetches the Open-Meteo forecast (free, no key, 3 s timeout, kept 30 min
in memory). If it can't reach the API, it uses typical weather for the site; the request never fails
because of weather. Examples are on `/docs`.

## Run (from `backend/`, Python 3.12)
```
pip install -r requirements.txt          # full: + RAG (qdrant, sentence-transformers), Gemini, firebase-admin
uvicorn app.main:app --reload            # http://127.0.0.1:8000/docs
```
- **Lean install:** `requirements-deploy.txt` is what the Docker image uses. RAG then runs in
  TF-IDF / extractive mode.
- **Train the models first** (from the repo root):
  - `python ml/generators/generate.py && python ml/training/train_task_time.py`
  - P2's models: `cd ml && python training/anomaly.py && python training/risk.py`
- **Local settings** (Gemini key, retriever choice) go in `backend/.env`; copy `.env.example`.
  Without a key, `/rag/query` and `/voice/nlu` still answer by quoting the best manual section from
  `ml/data/manuals/`.
- **Tests:** `pip install -r requirements-dev.txt && pytest -q`.

`backend/Dockerfile` copies only `app/`, so an image built from it serves stubs. Use the root
`Dockerfile` instead.

## Structure
```
app/
├── main.py            # FastAPI app, CORS, router registration (+ .env loading)
├── routers/           # ml.py (estimate/anomaly/safety/maintenance/fleet), rag.py, voice.py, sim.py
│                      #   (pydantic request/response models live in each router = the API contract)
├── schemas/           # empty placeholder
└── core/              # config.py (.env loader), ml_repo.py (makes ml/ importable),
                       # anomaly.py + risk.py (P2 rules, features, model loading), rag.py (retriever + Gemini)
```
