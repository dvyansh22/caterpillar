"""ML endpoints — task-time estimation (P1) and anomaly/behavior (P2).

Stub responses established the API contract (§20.2). /ml/estimate serves the trained XGBoost model
(ml/models/task_time_v1.joblib); /ml/anomaly, /ml/safety and /ml/maintenance serve P2's models,
with a rules-only fallback when a model file is missing.
"""

from functools import lru_cache

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, ConfigDict, Field

from app.core.anomaly import canonical, score_session
from app.core.ml_repo import ensure_ml_importable
from app.core.risk import score_maintenance, score_safety

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
    model_config = ConfigDict(protected_namespaces=())

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
    """One operating session. Field → Dataset A column mapping is in ml/data/schemas/README.md.

    The first six fields are the original contract; the rest are optional additions so the model
    can use more of the session (send whatever the phone/telematics has; omit the rest).
    """

    machine_id: str
    idling_time_min: float = Field(ge=0)
    load_cycles: int = Field(ge=0)
    seatbelt_status: str
    harsh_events: int = Field(0, ge=0)
    speed_kmh: float | None = Field(None, ge=0)  # max speed in the session
    # optional expanded features (schema v1.0); ranges reject impossible values with a 422
    vertical: str | None = None
    machine_type: str | None = None
    data_source: str | None = None
    session_duration_min: float | None = Field(None, gt=0)
    avg_speed_kmh: float | None = Field(None, ge=0)
    fuel_used_l: float | None = Field(None, ge=0)
    engine_temp_c: float | None = None
    hydraulic_pressure_bar: float | None = Field(None, ge=0)
    rpm: float | None = Field(None, ge=0)
    payload_t: float | None = Field(None, ge=0)
    hours_since_service: float | None = Field(None, ge=0)
    proximity_warnings: int | None = Field(None, ge=0)
    hours_since_break: float | None = Field(None, ge=0)
    fatigue_score: float | None = Field(None, ge=0, le=1)
    ambient_temp_c: float | None = None
    fault_code: str | None = None

    def to_session(self) -> dict:
        return {
            "MachineID": self.machine_id,
            "IdlingTime_min": self.idling_time_min,
            "LoadCycles": self.load_cycles,
            "SeatbeltStatus": canonical("SeatbeltStatus", self.seatbelt_status),
            "HarshEvents": self.harsh_events,
            "MaxSpeed_kmh": self.speed_kmh,
            "Vertical": canonical("Vertical", self.vertical),
            "MachineType": canonical("MachineType", self.machine_type),
            "DataSource": canonical("DataSource", self.data_source),
            "SessionDuration_min": self.session_duration_min,
            "AvgSpeed_kmh": self.avg_speed_kmh,
            "FuelUsed_L": self.fuel_used_l,
            "EngineTemp_C": self.engine_temp_c,
            "HydraulicPressure_bar": self.hydraulic_pressure_bar,
            "RPM": self.rpm,
            "Payload_t": self.payload_t,
            "HoursSinceService": self.hours_since_service,
            "ProximityWarnings": self.proximity_warnings,
            "HoursSinceBreak": self.hours_since_break,
            "FatigueScore": self.fatigue_score,
            "AmbientTemp_C": self.ambient_temp_c,
            "FaultCode": canonical("FaultCode", self.fault_code),
        }


class AnomalyResponse(BaseModel):
    model_config = ConfigDict(protected_namespaces=())

    anomaly: bool
    score: float
    reasons: list[str] = []
    model_version: str = "stub-0"
    # added: primary type for the closed loop (None | ExcessiveIdle | UnsafeOperation | FuelAnomaly | OverheatRisk)
    anomaly_type: str = "None"


@router.post("/anomaly", response_model=AnomalyResponse)
def anomaly(req: AnomalyRequest) -> AnomalyResponse:
    result = score_session(req.to_session())
    return AnomalyResponse(
        anomaly=result.anomaly,
        score=result.score,
        reasons=result.reasons,
        model_version=result.model_version,
        anomaly_type=result.anomaly_type,
    )


# ---- /ml/safety and /ml/maintenance (P2, FR-ML-3) ----
# Same session body as /ml/anomaly, so the app can send one payload to all three.
SessionRequest = AnomalyRequest


class RiskResponse(BaseModel):
    model_config = ConfigDict(protected_namespaces=())

    flagged: bool
    probability: float
    reasons: list[str] = []
    model_version: str


@router.post("/safety", response_model=RiskResponse)
def safety(req: SessionRequest) -> RiskResponse:
    """Will this session raise a safety alert? (target SafetyAlertTriggered)"""
    return RiskResponse(**vars(score_safety(req.to_session())))


@router.post("/maintenance", response_model=RiskResponse)
def maintenance(req: SessionRequest) -> RiskResponse:
    """Does the machine need maintenance? (target MaintenanceDue)"""
    return RiskResponse(**vars(score_maintenance(req.to_session())))
