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
