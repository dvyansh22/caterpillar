"""Synthetic-data generation endpoint (P1).

Thin API over ml/generators. Produces telematics/task rows in the frozen schemas for a vertical.
"""

import json

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.core.ml_repo import ensure_ml_importable

router = APIRouter(prefix="/sim", tags=["sim"])

SAMPLE_ROWS = 20


class SimRequest(BaseModel):
    dataset: str  # "telematics" | "tasks"
    vertical: str = "construction"  # "construction" | "mining" | "both"
    rows: int = Field(100, ge=1, le=5000)  # per vertical


class SimResponse(BaseModel):
    dataset: str
    vertical: str
    rows_generated: int
    sample: list[dict] = []


@router.post("/generate", response_model=SimResponse)
def generate(req: SimRequest) -> SimResponse:
    if req.dataset not in ("telematics", "tasks"):
        raise HTTPException(status_code=422, detail="dataset must be 'telematics' or 'tasks'")
    if req.vertical not in ("construction", "mining", "both"):
        raise HTTPException(status_code=422, detail="vertical must be 'construction', 'mining' or 'both'")
    if not ensure_ml_importable():
        raise HTTPException(status_code=503, detail="ml/ generator package is not deployed with this service")

    from ml.generators.generate import generate_tasks, generate_telematics

    make = generate_tasks if req.dataset == "tasks" else generate_telematics
    df = make(req.vertical, req.rows, seed=None)  # fresh random fleet per call
    sample = json.loads(df.head(SAMPLE_ROWS).to_json(orient="records"))  # NaN -> null, native types
    return SimResponse(dataset=req.dataset, vertical=req.vertical, rows_generated=len(df), sample=sample)
