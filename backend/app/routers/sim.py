"""Synthetic-data generation endpoint (P1).

Thin API over ml/generators. Produces telematics/task rows in the frozen schemas for a vertical.
"""

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(prefix="/sim", tags=["sim"])


class SimRequest(BaseModel):
    dataset: str  # "telematics" | "tasks"
    vertical: str = "construction"
    rows: int = 100


class SimResponse(BaseModel):
    dataset: str
    vertical: str
    rows_generated: int
    sample: list[dict] = []


@router.post("/generate", response_model=SimResponse)
def generate(req: SimRequest) -> SimResponse:
    # TODO(P1): call ml/generators to synthesize rows encoding real sample relationships.
    return SimResponse(dataset=req.dataset, vertical=req.vertical, rows_generated=0, sample=[])
