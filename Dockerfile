# Task-time ETA service for a free host (Render / Hugging Face Spaces / Fly).
# Build context = repo ROOT (needs both backend/ and ml/), unlike backend/Dockerfile
# which is the Cloud Run image that copies backend/ only.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    ML_REPO_ROOT=/app \
    PORT=8080

WORKDIR /app

# Lean deps (RAG/LLM/firebase are lazy-imported; not needed to serve the ETA).
COPY backend/requirements-deploy.txt .
RUN pip install --no-cache-dir -r requirements-deploy.txt

# App code + the ml package (generators, serving, trained model).
COPY backend/app ./app
COPY ml ./ml

# Bake the model into the image: generate synthetic data, then train the XGBoost
# task-time model to ml/models/task_time_v1.joblib so /ml/estimate serves the real
# model (not the baseline stub) with no runtime training and no external data.
RUN python ml/generators/generate.py && python ml/training/train_task_time.py

# $PORT is provided by the host (Render/HF/Fly set it); default 8080 locally.
CMD exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT}
