"""ML endpoints — task-time estimation (P1) and anomaly/behavior (P2).

Stub responses establish the API contract (§20.2). /ml/estimate serves the trained XGBoost model
(ml/models/task_time_v1.joblib); /ml/anomaly is still a stub.
"""

from functools import lru_cache

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.core.ml_repo import ensure_ml_importable

router = APIRouter(prefix="/ml", tags=["ml"])


@lru_cache(maxsize=1)
def get_task_time_estimator():
    """Load the task-time model once per process; None if the `ml` package isn't available."""
    if not ensure_ml_importable():
        return None
    from ml.serving.task_time import TaskTimeEstimator

    return TaskTimeEstimator.load()


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
    estimator = get_task_time_estimator()
    if estimator is None:  # ml/ not deployed alongside the backend: keep the contract-accurate stub
        return EstimateResponse(estimated_minutes=45.0, baseline_minutes=45.0)
    try:
        result = estimator.estimate(**req.model_dump())
    except ValueError as exc:  # unknown task_type / weather / skill / vertical
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return EstimateResponse(
        estimated_minutes=result.estimated_minutes,
        baseline_minutes=result.baseline_minutes,
        model_version=result.model_version,
    )


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
