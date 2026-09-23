"""ML endpoints — task-time estimation (P1) and anomaly/behavior (P2).

Stub responses establish the API contract (§20.2). Replace with real model inference in Phase 1+.
"""

from fastapi import APIRouter
from pydantic import BaseModel, ConfigDict

from app.core.anomaly import score_session

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
    """One operating session. Field → Dataset A column mapping is in ml/data/schemas/README.md.

    The first six fields are the original contract; the rest are optional additions so the model
    can use more of the session (send whatever the phone/telematics has; omit the rest).
    """

    machine_id: str
    idling_time_min: float
    load_cycles: int
    seatbelt_status: str
    harsh_events: int = 0
    speed_kmh: float | None = None  # max speed in the session
    # optional expanded features (schema v1.0)
    vertical: str | None = None
    machine_type: str | None = None
    data_source: str | None = None
    session_duration_min: float | None = None
    avg_speed_kmh: float | None = None
    fuel_used_l: float | None = None
    engine_temp_c: float | None = None
    hydraulic_pressure_bar: float | None = None
    rpm: float | None = None
    payload_t: float | None = None
    hours_since_service: float | None = None
    proximity_warnings: int | None = None
    hours_since_break: float | None = None
    fatigue_score: float | None = None
    ambient_temp_c: float | None = None

    def to_session(self) -> dict:
        return {
            "MachineID": self.machine_id,
            "IdlingTime_min": self.idling_time_min,
            "LoadCycles": self.load_cycles,
            "SeatbeltStatus": self.seatbelt_status,
            "HarshEvents": self.harsh_events,
            "MaxSpeed_kmh": self.speed_kmh,
            "Vertical": self.vertical,
            "MachineType": self.machine_type,
            "DataSource": self.data_source,
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
