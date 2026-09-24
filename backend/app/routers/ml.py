"""ML endpoints — task-time estimation (P1) and anomaly/behavior (P2).

Stub responses established the API contract (§20.2). /ml/estimate serves the trained XGBoost model
(ml/models/task_time_v1.joblib); /ml/anomaly, /ml/safety and /ml/maintenance serve P2's models,
with a rules-only fallback when a model file is missing.
"""

from datetime import datetime
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
    """The first seven fields are the original contract. Everything after is optional (v1.1):
    give a site (or lat/lon) and start time to use live weather, or send weather numbers yourself."""

    model_config = ConfigDict(json_schema_extra={"examples": [
        {"task_type": "Earth Excavation", "weather": "Sunny", "operator_skill": "Beginner",
         "machine_age_yrs": 9, "vertical": "construction", "site_id": "SITE01", "suggest_start": True},
        {"task_type": "Earth Excavation", "weather": "Sunny", "operator_skill": "Beginner",
         "machine_age_yrs": 9, "site_id": "SITE01", "start_time": "2026-05-14T14:00",
         "temperature_c": 37, "humidity_pct": 40},
        {"task_type": "Load-Haul-Dump", "weather": "Sunny", "operator_skill": "Expert",
         "machine_age_yrs": 4, "vertical": "mining", "site_id": "SITE06", "visibility_m": 150},
    ]})

    task_type: str
    weather: str
    operator_skill: str
    machine_age_yrs: float
    vertical: str = "construction"
    # optional expanded features
    material_type: str | None = None
    haul_distance_m: float | None = None
    # optional: where and when (live Open-Meteo forecast; site-typical weather when offline)
    site_id: str | None = Field(None, description="SITE01-SITE07 (see ml/data/synthetic/sites.csv)")
    latitude: float | None = Field(None, ge=-90, le=90)
    longitude: float | None = Field(None, ge=-180, le=180)
    start_time: datetime | None = Field(None, description="ISO time; no timezone = site local time. Default: now")
    # optional: weather the app already has (overrides the forecast)
    temperature_c: float | None = Field(None, ge=-40, le=60)
    humidity_pct: float | None = Field(None, ge=0, le=100)
    wind_speed_kmh: float | None = Field(None, ge=0, le=200)
    visibility_m: float | None = Field(None, ge=0, le=50000)
    precip_mm_h: float | None = Field(None, ge=0, le=200)
    suggest_start: bool = Field(False, description="Also return the best start time in the next 24 h")


class EtaFactor(BaseModel):
    name: str
    minutes: float
    detail: str


class WorkConditions(BaseModel):
    start_time: str | None = None
    temperature_c: float
    humidity_pct: float
    wind_speed_kmh: float
    visibility_m: float
    precip_mm_h: float
    weather: str
    wbgt_c: float
    work_fraction: float


class BestStart(BaseModel):
    start_time: str
    estimated_minutes: float
    minutes_saved: float
    reason: str


class EstimateResponse(BaseModel):
    model_config = ConfigDict(protected_namespaces=(), json_schema_extra={"examples": [{
        # real output for the second request example (Pune, 37 °C / 40 % RH at 14:00)
        "estimated_minutes": 177.5, "baseline_minutes": 55.0, "model_version": "xgb-v2",
        "weather_source": "client",
        "conditions": {"start_time": "2026-05-14T14:00", "temperature_c": 37.0, "humidity_pct": 40.0,
                       "wind_speed_kmh": 12.0, "visibility_m": 15000.0, "precip_mm_h": 0.0, "weather": "Sunny",
                       "wbgt_c": 29.4, "work_fraction": 0.5},
        "factors": [{"name": "operator, machine & terrain", "minutes": 33.7, "detail": "Beginner operator, 9-yr machine"},
                    {"name": "heat breaks", "minutes": 88.8, "detail": "WBGT 29.4 °C -> 50% of each hour workable (open cab)"}],
        "advisories": ["Heat stress: drink water every 15-20 min and take shaded rest breaks"],
        "best_start": None,
    }]})

    estimated_minutes: float
    baseline_minutes: float | None = None
    model_version: str = "stub-0"
    # optional additions (v1.1); older clients can ignore them
    weather_source: str | None = None  # open-meteo | site-typical | client | label-only
    conditions: WorkConditions | None = None
    factors: list[EtaFactor] = []  # minutes added/removed vs baseline_minutes; they sum to the difference
    advisories: list[str] = []
    best_start: BestStart | None = None


@router.post("/estimate", response_model=EstimateResponse)
def estimate(req: EstimateRequest) -> EstimateResponse:
    estimator = get_task_time_estimator()
    if estimator is None:  # ml/ not deployed alongside the backend: keep the contract-accurate stub
        return EstimateResponse(estimated_minutes=45.0, baseline_minutes=45.0)
    try:
        result = estimator.estimate(**req.model_dump())
    except ValueError as exc:  # unknown task_type / weather / skill / vertical / site
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return EstimateResponse(
        estimated_minutes=result.estimated_minutes,
        baseline_minutes=result.baseline_minutes,
        model_version=result.model_version,
        weather_source=result.weather_source,
        conditions=result.conditions or None,
        factors=result.factors,
        advisories=result.advisories,
        best_start=result.best_start,
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


# ---- /ml/fleet (owner dashboard: model-labeled fleet snapshot) ----
class FleetMachine(BaseModel):
    id: str
    type: str
    operator: str
    status: str  # in_use | idle | offline
    phone_fed: bool  # phone sensors (no telematics hardware)
    alerts: int


class FleetResponse(BaseModel):
    model_config = ConfigDict(protected_namespaces=())
    vertical: str
    machines: list[FleetMachine]
    idle_week: list[int]  # avg idle % by weekday (Mon..Sun)
    active: int
    safety_alerts: int
    anomalies: int
    maintenance_due: int
    phone_fed: int


@router.get("/fleet", response_model=FleetResponse)
def fleet(vertical: str = "construction") -> FleetResponse:
    """A fleet snapshot for the owner dashboard, aggregated from the generated,
    model-labeled telematics (SafetyAlert/Anomaly/MaintenanceDue, idling, phone vs
    telematics source). Seeded so the snapshot is stable across refreshes."""
    if vertical not in ("construction", "mining"):
        raise HTTPException(status_code=422, detail="vertical must be 'construction' or 'mining'")
    if not ensure_ml_importable():
        raise HTTPException(status_code=503, detail="ml/ generator package is not deployed")
    import pandas as pd
    from ml.generators.generate import generate_telematics

    df = generate_telematics(vertical, 300, seed=7)  # stable one-shift fleet snapshot
    yes = lambda s: s.astype(str).str.lower().eq("yes")
    df = df.assign(_idle=(df["IdlingTime_min"] / df["SessionDuration_min"]).clip(lower=0, upper=1))

    rows = []
    for mid, g in df.groupby("MachineID"):
        rows.append({
            "id": str(mid),
            "type": str(g["MachineType"].iat[0]),
            "operator": str(g["OperatorID"].mode().iat[0]) if not g["OperatorID"].isna().all() else "",
            "idle": float(g["_idle"].mean()),
            "sessions": int(len(g)),
            "phone_fed": bool(g["DataSource"].astype(str).str.lower().eq("phone").mean() >= 0.5),
            "alerts": int(yes(g["SafetyAlertTriggered"]).sum() + yes(g["AnomalyFlag"]).sum()),
        })
    rows.sort(key=lambda m: (-m["alerts"], -m["sessions"]))
    rows = rows[:9]  # a readable fleet for the table

    # Simulated "live" variation: stable machine identities, but each machine's
    # status/idle/alerts drift over time so the dashboard animates as it polls.
    import math
    import time
    import zlib

    tick = int(time.time() // 6)  # advances every 6 seconds
    for m in rows:
        phase = zlib.crc32(m["id"].encode()) % 7
        m["idle"] = max(0.05, min(0.45, 0.25 + 0.17 * math.sin((tick + phase) / 3.0)))
        r = (tick + phase) % 11
        if r == 0:
            m["status"] = "offline"
        elif m["idle"] > 0.38 or r in (1, 2):
            m["status"] = "idle"
        else:
            m["status"] = "in_use"
        m["alerts"] = max(0, m["alerts"] - 1 + ((tick + phase) % 3))

    dow = pd.to_datetime(df["Timestamp"]).dt.dayofweek
    idle_by_dow = df["_idle"].groupby(dow).mean().reindex(range(7)).fillna(0.0)
    idle_week = [int(round(v * 100)) for v in idle_by_dow.tolist()]
    idle_week[-1] = int(max(5, min(45, round(22 + 12 * math.sin(tick / 2.0)))))  # TODAY drifts live

    return FleetResponse(
        vertical=vertical,
        machines=[FleetMachine(id=m["id"], type=m["type"], operator=m["operator"],
                               status=m["status"], phone_fed=m["phone_fed"], alerts=m["alerts"]) for m in rows],
        idle_week=idle_week,
        active=sum(1 for m in rows if m["status"] != "offline"),
        safety_alerts=sum(m["alerts"] for m in rows),
        anomalies=int(yes(df["AnomalyFlag"]).sum()),
        maintenance_due=int(yes(df["MaintenanceDue"]).sum()),
        phone_fed=sum(1 for m in rows if m["phone_fed"]),
    )
