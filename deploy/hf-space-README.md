---
title: Smart Operator ETA
emoji: 🚜
colorFrom: yellow
colorTo: gray
sdk: docker
app_port: 7860
pinned: false
---

# Smart Operator — Task-Time ETA Service

FastAPI service that serves the P1 XGBoost task-time model (weather-aware via the
live Open-Meteo forecast, with an offline fallback). It is built from the repo's
root `Dockerfile`, which bakes the model at build time (generate synthetic data,
then train), so there is no runtime training and no external data dependency.

Endpoints:
- `GET  /health`
- `POST /ml/estimate` — task-time ETA + factors, advisories, best-start
- `POST /ml/anomaly` `/ml/safety` `/ml/maintenance` — session scoring (rules-only unless P2's model files are added)
- `GET  /ml/fleet?vertical=` — fleet view for the owner dashboard
- `POST /rag/query`, `POST /voice/nlu` — manual Q&A (lightweight TF-IDF / extractive mode in this image)
- `POST /sim/generate` — synthetic rows in the dataset schema

Interactive docs at `/docs`.
