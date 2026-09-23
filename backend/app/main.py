"""Smart Operator Assistant — FastAPI AI service (scaffold stub).

Owners: P1 / P2. Registers routers; real logic lands in Phase 1+.
Ship stub responses first so the app team (P3) can integrate before models are trained.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import load_env

load_env()  # before routers read their settings

from app.routers import ml, rag, voice, sim  # noqa: E402

app = FastAPI(
    title="Smart Operator Assistant — AI Service",
    version="0.1.0",
)

# The operator app (and the Flutter web dashboard) call this service from another
# origin. Allow all origins: it is a public, read-only ML API with no cookies/auth.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=False,
)


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


app.include_router(ml.router)
app.include_router(rag.router)
app.include_router(voice.router)
app.include_router(sim.router)
# TODO(P3): app.include_router(signal.router)  # WebRTC signaling (WebSocket)
