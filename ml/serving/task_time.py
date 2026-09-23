"""Task-time estimation — feature building, model pipeline and inference (P1, FR-ML-1 / FR-TASK-2).

Shared by `ml/training/train_task_time.py` and the backend `/ml/estimate` route so training and
serving build features identically. The model predicts log(ActualTime / EstimatedTime), i.e. how
much this task will over/under-run the planner baseline, and the ETA is baseline x exp(prediction).
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd

from ml.generators import catalog as C

ML_DIR = Path(__file__).resolve().parents[1]
MODEL_PATH = ML_DIR / "models" / "task_time_v1.joblib"
MODEL_VERSION = "xgb-v1"
BASELINE_VERSION = "baseline-0"

CATEGORICAL = ["Vertical", "TaskType", "MachineType", "MaterialType", "Weather", "OperatorSkill", "TimeOfDay"]
NUMERIC = ["MachineAge_yrs", "TerrainSlope_deg", "Temperature_C", "WindSpeed_kmh", "OperatorExpHours",
           "LoadVolume_m3", "HaulDistance_m", "EstimatedTime_min"]
FEATURES = CATEGORICAL + NUMERIC

# OpenWeatherMap "main" conditions -> schema Weather enum (the app may pass either).
WEATHER_ALIASES = {
    "clear": "Sunny", "clouds": "Cloudy", "rain": "Rainy", "drizzle": "Rainy", "thunderstorm": "Rainy",
    "snow": "Rainy", "mist": "Cloudy", "fog": "Cloudy", "smoke": "Dusty", "haze": "Dusty", "dust": "Dusty",
    "sand": "Dusty", "ash": "Dusty", "squall": "Windy", "tornado": "Windy",
}


def _canonical(value: str, options: tuple[str, ...] | list[str], field: str) -> str:
    for option in options:
        if value.strip().lower() == option.lower():
            return option
    raise ValueError(f"unknown {field} {value!r}; expected one of {list(options)}")


def normalize_weather(value: str) -> str:
    alias = WEATHER_ALIASES.get(value.strip().lower())
    return alias or _canonical(value, C.WEATHERS, "weather")


def build_pipeline(seed: int = 42):
    """One-hot categoricals + XGBoost regressor on the log over/under-run ratio."""
    from sklearn.compose import ColumnTransformer
    from sklearn.pipeline import Pipeline
    from sklearn.preprocessing import OneHotEncoder
    from xgboost import XGBRegressor

    features = ColumnTransformer(
        [("cat", OneHotEncoder(handle_unknown="ignore"), CATEGORICAL), ("num", "passthrough", NUMERIC)]
    )
    model = XGBRegressor(n_estimators=500, max_depth=5, learning_rate=0.05, subsample=0.9,
                         colsample_bytree=0.9, min_child_weight=5, random_state=seed, n_jobs=-1)
    return Pipeline([("features", features), ("model", model)])


def target(df: pd.DataFrame) -> np.ndarray:
    return np.log(df["ActualTime_min"].to_numpy() / df["EstimatedTime_min"].to_numpy())


def to_minutes(pipeline, X: pd.DataFrame) -> np.ndarray:
    return X["EstimatedTime_min"].to_numpy() * np.exp(pipeline.predict(X[FEATURES]))


def complete_features(
    task_type: str,
    weather: str,
    operator_skill: str,
    machine_age_yrs: float,
    vertical: str = "construction",
    material_type: str | None = None,
    haul_distance_m: float | None = None,
    **optional: float | str | None,
) -> dict:
    """Validate a request and fill every feature the request doesn't carry with a typical value.

    `optional` may carry any other schema column (e.g. LoadVolume_m3, OperatorExpHours) to override
    a default. Raises ValueError on unknown enum values.
    """
    vertical = _canonical(vertical, C.VERTICALS, "vertical")
    task_type = _canonical(task_type, C.TASK_TYPES[vertical], f"task_type for {vertical}")
    skill = _canonical(operator_skill, C.SKILLS, "operator_skill")
    weather = normalize_weather(weather)
    spec = C.TASK_SPECS[(vertical, task_type)]
    if material_type is not None:
        material_type = _canonical(material_type, C.MATERIAL_TYPES[vertical], f"material_type for {vertical}")

    lo, hi = spec["volume_m3"]
    row = {
        "Vertical": vertical,
        "TaskType": task_type,
        "MachineType": spec["machine_types"][0],
        "MaterialType": material_type or spec["materials"][0],
        "Weather": weather,
        "OperatorSkill": skill,
        "TimeOfDay": "Morning",
        "MachineAge_yrs": float(machine_age_yrs),
        "TerrainSlope_deg": 3.0 if vertical == "construction" else 5.0,
        "Temperature_C": 22.0 if weather == "Rainy" else 26.0,
        "WindSpeed_kmh": 45.0 if weather == "Windy" else 12.0,
        "OperatorExpHours": {"Beginner": 1100.0, "Intermediate": 5000.0, "Expert": 14000.0}[skill],
        "LoadVolume_m3": float(np.sqrt(lo * hi)),  # geometric mid of the generated range
        "HaulDistance_m": float(haul_distance_m) if haul_distance_m is not None else float(np.mean(spec["haul_m"])),
    }
    row.update({k: v for k, v in optional.items() if k in FEATURES and v is not None})
    row["EstimatedTime_min"] = C.baseline_minutes(vertical, task_type, row["LoadVolume_m3"], row["HaulDistance_m"])
    return row


@dataclass
class Estimate:
    estimated_minutes: float
    baseline_minutes: float
    model_version: str


class TaskTimeEstimator:
    """Loads the trained bundle; falls back to the planner baseline when no model file exists."""

    def __init__(self, bundle: dict | None):
        self.bundle = bundle
        self.pipeline = bundle["pipeline"] if bundle else None
        self.model_version = bundle["model_version"] if bundle else BASELINE_VERSION

    @classmethod
    def load(cls, path: Path | str = MODEL_PATH) -> "TaskTimeEstimator":
        path = Path(path)
        if not path.exists():
            return cls(None)
        import joblib

        return cls(joblib.load(path))

    def estimate(self, **request) -> Estimate:
        row = complete_features(**request)
        baseline = row["EstimatedTime_min"]
        if self.pipeline is None:
            return Estimate(baseline, baseline, self.model_version)
        minutes = float(to_minutes(self.pipeline, pd.DataFrame([row]))[0])
        return Estimate(round(minutes, 1), baseline, self.model_version)
