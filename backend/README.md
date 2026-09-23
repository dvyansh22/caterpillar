# backend/ — FastAPI AI Service

**Owners:** P1 / P2

The cloud "AI brain." Stateless FastAPI service (deploy to Cloud Run) that serves ML inference, RAG,
voice NLU, synthetic-data generation, and WebRTC signaling. Verifies Firebase ID tokens on every
request and uses the Firebase Admin SDK for Firestore access.

## Endpoints (freeze the JSON contract in Phase 0 — ship stubs first)
| Route | Purpose | Owner |
|---|---|---|
| `POST /ml/estimate` | Task-time estimation (XGBoost) | P1 |
| `POST /ml/anomaly` | Unusual-behavior / anomaly scoring | P2 |
| `POST /rag/query` | Repair-manual Q&A (RAG + LLM) | P2 |
| `POST /voice/nlu` | Voice intent → response (LLM) | P2 |
| `POST /sim/generate` | Generate synthetic telematics/task rows | P1 |
| `WS  /signal` | WebRTC signaling for tele-mentoring | P3 |

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

## Run
```
pip install -r requirements.txt
uvicorn app.main:app --reload
```
Local settings (Gemini key, retriever choice) go in `backend/.env` — copy `.env.example`. Without a
key, `/rag/query` and `/voice/nlu` still answer by quoting the best manual section from
`ml/data/manuals/`. Tests: `pip install -r requirements-dev.txt && pytest -q`.

## Structure
```
app/
├── main.py            # FastAPI app + router registration
├── routers/           # ml.py, rag.py, voice.py, sim.py, signal.py
├── schemas/           # pydantic request/response models (the API contract)
└── core/              # config, firebase admin, auth dependency
```
