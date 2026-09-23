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
- `POST /ml/anomaly` `/ml/safety` `/ml/maintenance` — session scoring
- `POST /sim/generate` — synthetic rows in the dataset schema

Interactive docs at `/docs`.
