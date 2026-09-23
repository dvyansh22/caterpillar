"""Anomaly / unusual-behaviour scoring (P2) — shared by training and serving.

Single source of truth for:
- per-machine-type operating norms used by the Dataset A ground-truth rules (SRS §6.1),
- the feature builder (training in ml/training/ and inference in /ml/anomaly use the same code),
- the human-readable rule checks that produce `reasons`,
- loading the trained model bundle, with a rules-only fallback when no model file exists.
"""

from __future__ import annotations

import math
import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd


@dataclass(frozen=True)
class MachineNorm:
    speed_limit_kmh: float  # UnsafeOperation if MaxSpeed_kmh exceeds this
    fuel_l_per_h: float  # typical burn while working
    cycles_per_h: float  # typical LoadCycles per working hour

    @property
    def fuel_per_cycle(self) -> float:
        return self.fuel_l_per_h / self.cycles_per_h


# TODO(P1): the schema names "type speed limit" and "MachineType norm" but gives no values.
# These are P2's working assumptions; replace with P1's generator constants once published.
NORMS: dict[tuple[str, str], MachineNorm] = {
    ("construction", "Excavator"): MachineNorm(6, 18, 12),
    ("construction", "Wheel Loader"): MachineNorm(25, 15, 10),
    ("construction", "Dozer"): MachineNorm(11, 25, 6),
    ("construction", "Motor Grader"): MachineNorm(40, 14, 4),
    ("construction", "Backhoe Loader"): MachineNorm(40, 8, 10),
    ("mining", "Haul Truck"): MachineNorm(50, 90, 2.5),
    ("mining", "Hydraulic Shovel"): MachineNorm(3, 150, 14),
    ("mining", "Wheel Loader"): MachineNorm(30, 60, 8),
    ("mining", "Dozer"): MachineNorm(11, 45, 6),
    ("mining", "Drill"): MachineNorm(3, 30, 1),
}

# Ground-truth thresholds from SRS §6.1.
IDLE_RATIO_LIMIT = 0.5
HARSH_EVENTS_LIMIT = 4
PROXIMITY_LIMIT = 3
FUEL_RATIO_LIMIT = 1.5
OVERHEAT_TEMP_C = 110

ANOMALY_TYPES = ["None", "ExcessiveIdle", "UnsafeOperation", "FuelAnomaly", "OverheatRisk"]
# Most severe first (SRS §6.1: UnsafeOperation > OverheatRisk > FuelAnomaly > ExcessiveIdle).
SEVERITY = ["UnsafeOperation", "OverheatRisk", "FuelAnomaly", "ExcessiveIdle"]

NUMERIC_COLUMNS = [
    "SessionDuration_min", "HoursSinceService", "FuelUsed_L", "LoadCycles", "Payload_t",
    "IdlingTime_min", "AvgSpeed_kmh", "MaxSpeed_kmh", "EngineTemp_C", "HydraulicPressure_bar",
    "RPM", "HarshEvents", "ProximityWarnings", "HoursSinceBreak", "FatigueScore", "AmbientTemp_C",
]
CATEGORICAL_COLUMNS = {
    "Vertical": ["construction", "mining"],
    "MachineType": sorted({t for _, t in NORMS}),
    "DataSource": ["Telematics", "Phone"],
    "SeatbeltStatus": ["Fastened", "Unfastened"],
    "FaultCode": ["HYD_PRESSURE_LOW", "ENGINE_OVERHEAT", "AIR_FILTER_RESTRICTED", "FUEL_FILTER_CLOGGED",
                  "TRACK_TENSION", "BRAKE_WEAR", "TIRE_PRESSURE_LOW"],
}


def norm_for(vertical: Any, machine_type: Any) -> MachineNorm | None:
    return NORMS.get((str(vertical), str(machine_type)))


def build_features(df: pd.DataFrame) -> pd.DataFrame:
    """Dataset A rows (schema column names) -> model feature matrix. Missing values stay NaN."""
    out = pd.DataFrame(index=df.index)
    for col in NUMERIC_COLUMNS:
        out[col] = pd.to_numeric(df[col], errors="coerce") if col in df else np.nan

    for col, values in CATEGORICAL_COLUMNS.items():
        raw = df[col].astype(str) if col in df else pd.Series("", index=df.index)
        for value in values:
            out[f"{col}={value}"] = (raw == value).astype(float)

    norms = [
        norm_for(v, t)
        for v, t in zip(df.get("Vertical", [None] * len(df)), df.get("MachineType", [None] * len(df)))
    ]
    speed_limit = pd.Series([n.speed_limit_kmh if n else np.nan for n in norms], index=df.index)
    fuel_norm = pd.Series([n.fuel_per_cycle if n else np.nan for n in norms], index=df.index)

    out["idle_ratio"] = out["IdlingTime_min"] / out["SessionDuration_min"]
    out["speed_over_limit"] = out["MaxSpeed_kmh"] / speed_limit
    out["fuel_ratio"] = out["FuelUsed_L"] / out["LoadCycles"].clip(lower=1) / fuel_norm
    return out


def label_anomaly(df: pd.DataFrame) -> pd.Series:
    """Apply the SRS §6.1 AnomalyType rules. Used by the dev data generator and by tests."""
    return pd.Series([primary_type(check_rules(row)) for row in _records(df)], index=df.index)


def check_rules(row: dict[str, Any]) -> dict[str, list[str]]:
    """Return {anomaly_type: [human-readable reasons]} for every rule the row breaks."""
    hits: dict[str, list[str]] = {}

    def add(kind: str, reason: str) -> None:
        hits.setdefault(kind, []).append(reason)

    norm = norm_for(row.get("Vertical"), row.get("MachineType"))
    idle, duration = as_float(row.get("IdlingTime_min")), as_float(row.get("SessionDuration_min"))
    if idle is not None and duration:
        ratio = idle / duration
        if ratio > IDLE_RATIO_LIMIT:
            add("ExcessiveIdle", f"Idle for {ratio:.0%} of the session (limit {IDLE_RATIO_LIMIT:.0%})")

    harsh = as_float(row.get("HarshEvents"))
    if harsh is not None and harsh >= HARSH_EVENTS_LIMIT:
        add("UnsafeOperation", f"{harsh:.0f} harsh accel/brake/turn events (limit {HARSH_EVENTS_LIMIT - 1})")
    speed = as_float(row.get("MaxSpeed_kmh"))
    if speed is not None and norm and speed > norm.speed_limit_kmh:
        add("UnsafeOperation", f"Max speed {speed:.0f} km/h over the {norm.speed_limit_kmh:.0f} km/h limit")
    prox = as_float(row.get("ProximityWarnings"))
    if prox is not None and prox >= PROXIMITY_LIMIT:
        add("UnsafeOperation", f"{prox:.0f} proximity warnings (worker/machine too close)")

    fuel, cycles = as_float(row.get("FuelUsed_L")), as_float(row.get("LoadCycles"))
    if fuel is not None and cycles is not None and norm:
        ratio = fuel / max(cycles, 1) / norm.fuel_per_cycle
        if ratio > FUEL_RATIO_LIMIT:
            add("FuelAnomaly", f"Fuel per load cycle is {ratio:.1f}x the normal rate")

    temp = as_float(row.get("EngineTemp_C"))
    if temp is not None and temp > OVERHEAT_TEMP_C:
        add("OverheatRisk", f"Engine temperature {temp:.0f}°C above {OVERHEAT_TEMP_C}°C")
    return hits


def primary_type(hits: dict[str, list[str]]) -> str:
    return next((kind for kind in SEVERITY if kind in hits), "None")


# ---- Serving ----

DEFAULT_MODEL_PATH = Path(__file__).resolve().parents[3] / "ml" / "models" / "anomaly.joblib"


@dataclass
class AnomalyResult:
    anomaly: bool
    score: float
    anomaly_type: str
    reasons: list[str]
    model_version: str


@lru_cache(maxsize=1)
def load_bundle() -> dict[str, Any] | None:
    path = Path(os.environ.get("ANOMALY_MODEL_PATH", DEFAULT_MODEL_PATH))
    if not path.exists():
        return None
    import joblib

    return joblib.load(path)


def score_session(row: dict[str, Any]) -> AnomalyResult:
    """Score one session. Uses the trained model if present, else the rules alone."""
    hits = check_rules(row)
    rule_type = primary_type(hits)
    reasons = [r for kind in SEVERITY for r in hits.get(kind, [])]

    bundle = load_bundle()
    if bundle is None:
        return AnomalyResult(
            anomaly=rule_type != "None",
            score=1.0 if rule_type != "None" else 0.0,
            anomaly_type=rule_type,
            reasons=reasons,
            model_version="rules-1",
        )

    features = build_features(pd.DataFrame([row]))[bundle["features"]]
    proba = bundle["model"].predict_proba(features)[0]
    classes: list[str] = bundle["classes"]
    score = 1.0 - float(proba[classes.index("None")])
    model_type = classes[int(np.argmax(proba))]

    anomaly = model_type != "None" or rule_type != "None"
    anomaly_type = rule_type if rule_type != "None" else model_type
    if anomaly and not reasons:
        reasons = [f"Unusual combination of readings (model score {score:.2f})"]
    return AnomalyResult(
        anomaly=anomaly,
        score=round(max(score, 1.0 if rule_type != "None" else 0.0), 4),
        anomaly_type=anomaly_type,
        reasons=reasons,
        model_version=bundle["version"],
    )


def as_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        f = float(value)
    except (TypeError, ValueError):
        return None
    return None if math.isnan(f) else f


def _records(df: pd.DataFrame) -> list[dict[str, Any]]:
    return df.replace({np.nan: None}).to_dict("records")
