"""Safety-alert and predictive-maintenance scoring (P2, FR-ML-3).

Two binary classifiers on Dataset A (targets `SafetyAlertTriggered`, `MaintenanceDue`), sharing the
feature builder in app.core.anomaly. Each has a rules-only fallback when its model file is missing,
and every answer carries human-readable `reasons` built from the SRS §6.1 rules.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any

import pandas as pd

from app.core.anomaly import as_float, build_features

MODELS_DIR = Path(__file__).resolve().parents[3] / "ml" / "models"
THRESHOLD = 0.5

# SRS §6.1 thresholds.
SAFETY_IDLE_RATIO = 0.4
SAFETY_HARSH_EVENTS = 3
SAFETY_FATIGUE = 0.7
SERVICE_LIMIT_H = {"construction": 500, "mining": 400}
MAINTENANCE_TEMP_C = 105


@dataclass
class RiskResult:
    flagged: bool
    probability: float
    reasons: list[str]
    model_version: str


@lru_cache(maxsize=None)
def load_bundle(name: str) -> dict[str, Any] | None:
    path = Path(os.environ.get(f"{name.upper()}_MODEL_PATH", MODELS_DIR / f"{name}.joblib"))
    if not path.exists():
        return None
    import joblib

    return joblib.load(path)


def safety_reasons(row: dict[str, Any]) -> tuple[list[str], float]:
    """Risk factors present in the session, and the rule-based alert probability."""
    reasons: list[str] = []
    unbelted = str(row.get("SeatbeltStatus")) == "Unfastened"
    if unbelted:
        reasons.append("Seatbelt unfastened")

    idle, duration = as_float(row.get("IdlingTime_min")), as_float(row.get("SessionDuration_min"))
    idle_high = bool(idle is not None and duration and idle / duration > SAFETY_IDLE_RATIO)
    if idle_high:
        reasons.append(f"Idle for {idle / duration:.0%} of the session")
    harsh = as_float(row.get("HarshEvents")) or 0
    if harsh >= SAFETY_HARSH_EVENTS:
        reasons.append(f"{harsh:.0f} harsh accel/brake/turn events")
    fatigue = as_float(row.get("FatigueScore"))
    if fatigue is not None and fatigue > SAFETY_FATIGUE:
        reasons.append(f"High fatigue score {fatigue:.2f}")

    # The organizer rule also needs "LoadCycles in the bottom quartile for the type", which is a
    # fleet statistic; the model learns it, the fallback approximates it with idle alone.
    if unbelted and idle_high:
        p = 0.9
    elif unbelted and (harsh >= SAFETY_HARSH_EVENTS or (fatigue or 0) > SAFETY_FATIGUE):
        p = 0.7
    else:
        p = 0.03
    return reasons, p


def maintenance_reasons(row: dict[str, Any]) -> list[str]:
    reasons: list[str] = []
    limit = SERVICE_LIMIT_H.get(str(row.get("Vertical")), SERVICE_LIMIT_H["construction"])
    since = as_float(row.get("HoursSinceService"))
    if since is not None and since > limit:
        reasons.append(f"{since:.0f} h since last service (interval {limit} h)")
    fault = row.get("FaultCode")
    if fault:
        reasons.append(f"Active fault code {fault}")
    temp = as_float(row.get("EngineTemp_C"))
    if temp is not None and temp > MAINTENANCE_TEMP_C:
        reasons.append(f"Engine temperature {temp:.0f}°C above {MAINTENANCE_TEMP_C}°C")
    return reasons


def score_safety(row: dict[str, Any]) -> RiskResult:
    reasons, rule_p = safety_reasons(row)
    return _score("safety", row, reasons, rule_p)


def score_maintenance(row: dict[str, Any]) -> RiskResult:
    reasons = maintenance_reasons(row)
    return _score("maintenance", row, reasons, 1.0 if reasons else 0.0)


def _score(name: str, row: dict[str, Any], reasons: list[str], rule_p: float) -> RiskResult:
    bundle = load_bundle(name)
    if bundle is None:
        flagged = rule_p > THRESHOLD
        return RiskResult(flagged, round(rule_p, 4), reasons if flagged else [], "rules-1")

    features = build_features(pd.DataFrame([row]))[bundle["features"]]
    p = float(bundle["model"].predict_proba(features)[0, 1])
    flagged = p > bundle.get("threshold", THRESHOLD)
    if flagged and not reasons:
        reasons = [f"Pattern similar to past {name} cases (model probability {p:.2f})"]
    return RiskResult(flagged, round(p, 4), reasons if flagged else [], bundle["version"])
