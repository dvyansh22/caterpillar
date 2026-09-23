# Task-time ETA service. Runs on Hugging Face Spaces (Docker) and other Docker
# hosts (Render/Fly). Build context = repo ROOT (needs both backend/ and ml/).
#
# HF Spaces run the container as UID 1000, so we create that user and own all
# files with it; this is also fine on hosts that run as root.
FROM python:3.12-slim

RUN useradd -m -u 1000 user

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH \
    ML_REPO_ROOT=/home/user/app \
    PORT=7860

USER user
WORKDIR /home/user/app

# Lean deps (RAG/LLM/firebase are lazy-imported; not needed to serve the ETA).
COPY --chown=user backend/requirements-deploy.txt .
RUN pip install --no-cache-dir --user -r requirements-deploy.txt

# App code + the ml package (generators, serving), owned by the runtime user.
COPY --chown=user backend/app ./app
COPY --chown=user ml ./ml

# Bake the model into the image: generate synthetic data + train the XGBoost model
# so /ml/estimate serves the real model with no runtime training or external data.
RUN python ml/generators/generate.py && python ml/training/train_task_time.py

# HF routes external traffic to app_port (7860, set in the Space README); other
# hosts inject $PORT and we bind whatever they give us.
CMD ["sh", "-c", "python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
