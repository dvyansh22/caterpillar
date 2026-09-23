"""ML endpoints — task-time estimation (P1) and anomaly/behavior (P2).

Stub responses establish the API contract (§20.2). Replace with real model inference in Phase 1+.
"""

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(prefix="/ml", tags=["ml"])


# ---- /ml/estimate (P1) ----
class EstimateRequest(BaseModel):
    task_type: str
    weather: str
    operator_skill: str
    machine_age_yrs: float
    vertical: str = "construction"
    # optional expanded features
    material_type: str | None = None
    haul_distance_m: float | None = None


class EstimateResponse(BaseModel):
    estimated_minutes: float
    baseline_minutes: float | None = None
    model_version: str = "stub-0"


@router.post("/estimate", response_model=EstimateResponse)
def estimate(req: EstimateRequest) -> EstimateResponse:
    # TODO(P1): load XGBoost model and predict ActualTime.
    return EstimateResponse(estimated_minutes=45.0, baseline_minutes=45.0)


# ---- /ml/anomaly (P2) ----
class AnomalyRequest(BaseModel):
    machine_id: str
    idling_time_min: float
    load_cycles: int
    seatbelt_status: str
    harsh_events: int = 0
    speed_kmh: float | None = None


class AnomalyResponse(BaseModel):
    anomaly: bool
    score: float
    reasons: list[str] = []
    model_version: str = "stub-0"


@router.post("/anomaly", response_model=AnomalyResponse)
def anomaly(req: AnomalyRequest) -> AnomalyResponse:
    # TODO(P2): IsolationForest / classifier over telematics features.
    return AnomalyResponse(anomaly=False, score=0.0, reasons=[])
