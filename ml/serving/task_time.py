"""Task-time estimation — feature building, model pipeline and inference (P1, FR-ML-1 / FR-TASK-2).

Shared by `ml/training/train_task_time.py` and the backend `/ml/estimate` route so training and
serving build features identically. The model predicts log(ActualTime / EstimatedTime), i.e. how
much this task will over/under-run the planner baseline, and the ETA is baseline x exp(prediction).

Weather and location: a request can name a site (or lat/lon) and a start time. The estimator then
uses the live Open-Meteo forecast (or the site's typical weather when offline), turns it into work
conditions (heat breaks, visibility, wet ground), explains the ETA and can suggest a better start.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path

import numpy as np
import pandas as pd

from ml.features import conditions, weather as wx
from ml.generators import catalog as C

ML_DIR = Path(__file__).resolve().parents[1]
MODEL_PATH = ML_DIR / "models" / "task_time_v1.joblib"
MODEL_VERSION = "xgb-v2"
BASELINE_VERSION = "baseline-0"

CATEGORICAL = ["Vertical", "TaskType", "MachineType", "MaterialType", "Weather", "OperatorSkill", "TimeOfDay"]
NUMERIC = ["MachineAge_yrs", "TerrainSlope_deg", "Temperature_C", "WindSpeed_kmh", "OperatorExpHours",
           "LoadVolume_m3", "HaulDistance_m", "EstimatedTime_min"]
LEGACY_FEATURES = CATEGORICAL + NUMERIC  # v1 model: weather label + temperature/wind only (ablation)
WEATHER_NUMERIC = ["Humidity_pct", "Visibility_m", "Precip_mm_h", "StartHour"]
DERIVED = ["WBGT_C", "HeatMultiplier", "VisibilityMultiplier", "WetMultiplier"]  # from conditions.assess
FEATURES = LEGACY_FEATURES + WEATHER_NUMERIC + DERIVED

CONSTRUCTION_SHIFT_HOURS = range(5, 21)  # best-start candidates for construction (mining runs 24 h)

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


def add_condition_features(df: pd.DataFrame) -> pd.DataFrame:
    """Add the DERIVED work-condition columns (WBGT, heat/visibility/wet multipliers)."""
    haul = [C.is_haul_task(v, t) for v, t in zip(df["Vertical"], df["TaskType"])]
    effects = conditions.assess(df["Temperature_C"], df["Humidity_pct"], df["Visibility_m"], df["Precip_mm_h"],
                                df["MaterialType"].to_numpy(), df["MachineAge_yrs"], haul)
    out = df.copy()
    for name in DERIVED:
        out[name] = np.asarray(effects[name], float)
    return out


def build_pipeline(seed: int = 42, features: list[str] | None = None):
    """One-hot categoricals + XGBoost regressor on the log over/under-run ratio."""
    from sklearn.compose import ColumnTransformer
    from sklearn.pipeline import Pipeline
    from sklearn.preprocessing import OneHotEncoder
    from xgboost import XGBRegressor

    numeric = [f for f in (features or FEATURES) if f not in CATEGORICAL]
    columns = ColumnTransformer(
        [("cat", OneHotEncoder(handle_unknown="ignore"), CATEGORICAL), ("num", "passthrough", numeric)]
    )
    model = XGBRegressor(n_estimators=500, max_depth=5, learning_rate=0.05, subsample=0.9,
                         colsample_bytree=0.9, min_child_weight=5, random_state=seed, n_jobs=-1)
    return Pipeline([("features", columns), ("model", model)])


def target(df: pd.DataFrame) -> np.ndarray:
    return np.log(df["ActualTime_min"].to_numpy() / df["EstimatedTime_min"].to_numpy())


def to_minutes(pipeline, X: pd.DataFrame, features: list[str] | None = None) -> np.ndarray:
    features = features or FEATURES
    if any(f in DERIVED for f in features) and not set(DERIVED) <= set(X.columns):
        X = add_condition_features(X)
    return X["EstimatedTime_min"].to_numpy() * np.exp(pipeline.predict(X[features]))


def complete_features(
    task_type: str,
    weather: str,
    operator_skill: str,
    machine_age_yrs: float,
    vertical: str = "construction",
    material_type: str | None = None,
    haul_distance_m: float | None = None,
    conditions_: wx.Weather | None = None,
    start_hour: int = 8,
    **optional: float | str | None,
) -> dict:
    """Validate a request and fill every feature the request doesn't carry with a typical value.

    `conditions_` supplies the weather numbers; without it they come from the weather label.
    `optional` may carry any other schema column (e.g. LoadVolume_m3) to override a default.
    Raises ValueError on unknown enum values.
    """
    vertical = _canonical(vertical, C.VERTICALS, "vertical")
    task_type = _canonical(task_type, C.TASK_TYPES[vertical], f"task_type for {vertical}")
    skill = _canonical(operator_skill, C.SKILLS, "operator_skill")
    weather = normalize_weather(weather)
    spec = C.TASK_SPECS[(vertical, task_type)]
    if material_type is not None:
        material_type = _canonical(material_type, C.MATERIAL_TYPES[vertical], f"material_type for {vertical}")
    w = conditions_ or wx.LABEL_DEFAULTS[weather]

    lo, hi = spec["volume_m3"]
    row = {
        "Vertical": vertical,
        "TaskType": task_type,
        "MachineType": spec["machine_types"][0],
        "MaterialType": material_type or spec["materials"][0],
        "Weather": weather,
        "OperatorSkill": skill,
        "TimeOfDay": C.time_of_day(start_hour),
        "StartHour": int(start_hour),
        "MachineAge_yrs": float(machine_age_yrs),
        "TerrainSlope_deg": 3.0 if vertical == "construction" else 5.0,
        "Temperature_C": w.temperature_c,
        "WindSpeed_kmh": w.wind_speed_kmh,
        "Humidity_pct": w.humidity_pct,
        "Visibility_m": w.visibility_m,
        "Precip_mm_h": w.precip_mm_h,
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
    weather_source: str = "label-only"
    conditions: dict = field(default_factory=dict)
    factors: list[dict] = field(default_factory=list)
    advisories: list[str] = field(default_factory=list)
    best_start: dict | None = None


def _site_location(site_id: str | None, latitude: float | None, longitude: float | None):
    """(lat, lon, profile site) for the request, or None when no location was given."""
    if site_id:
        site = next((s for s in C.SITES if s[0].lower() == site_id.strip().lower()), None)
        if site is None:
            raise ValueError(f"unknown site_id {site_id!r}; expected one of {[s[0] for s in C.SITES]}")
        return site[3], site[4], site[0]
    if latitude is not None and longitude is not None:
        return latitude, longitude, wx.nearest_site(latitude, longitude)
    return None


def _local_naive(ts: datetime, utc_offset_s: int) -> datetime:
    if ts.tzinfo is None:
        return ts
    return (ts.astimezone(timezone.utc) + timedelta(seconds=utc_offset_s)).replace(tzinfo=None)


class TaskTimeEstimator:
    """Loads the trained bundle; falls back to the planner baseline when no model file exists."""

    def __init__(self, bundle: dict | None):
        self.bundle = bundle
        self.pipeline = bundle["pipeline"] if bundle else None
        self.features = bundle.get("features", FEATURES) if bundle else FEATURES
        self.model_version = bundle["model_version"] if bundle else BASELINE_VERSION

    @classmethod
    def load(cls, path: Path | str = MODEL_PATH) -> "TaskTimeEstimator":
        path = Path(path)
        if not path.exists():
            return cls(None)
        import joblib

        return cls(joblib.load(path))

    def _predict(self, rows: list[dict]) -> np.ndarray:
        frame = add_condition_features(pd.DataFrame(rows))
        if self.pipeline is None:
            return frame["EstimatedTime_min"].to_numpy(dtype=float)
        return to_minutes(self.pipeline, frame, self.features)

    def estimate(
        self,
        task_type: str,
        weather: str,
        operator_skill: str,
        machine_age_yrs: float,
        vertical: str = "construction",
        material_type: str | None = None,
        haul_distance_m: float | None = None,
        site_id: str | None = None,
        latitude: float | None = None,
        longitude: float | None = None,
        start_time: datetime | None = None,
        temperature_c: float | None = None,
        humidity_pct: float | None = None,
        wind_speed_kmh: float | None = None,
        visibility_m: float | None = None,
        precip_mm_h: float | None = None,
        suggest_start: bool = False,
        **optional,
    ) -> Estimate:
        base = dict(task_type=task_type, weather=weather, operator_skill=operator_skill,
                    machine_age_yrs=machine_age_yrs, vertical=vertical, material_type=material_type,
                    haul_distance_m=haul_distance_m, **optional)
        planned = complete_features(**base)  # validates enums before any network call
        location = _site_location(site_id, latitude, longitude)

        # 1) Weather over the task window: live forecast -> site-typical -> weather label.
        hourly, source, offset = None, "label-only", 0
        if location:
            lat, lon, profile_site = location
            try:
                hourly, offset = wx.forecast(lat, lon)
                source = "open-meteo"
            except Exception:  # offline, timeout, bad response: typical weather for the site
                offset = int(round(lon / 15)) * 3600
                now_local = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(seconds=offset)
                anchor = _local_naive(start_time, offset) if start_time else now_local
                hourly = wx.typical_hourly(profile_site, anchor.replace(minute=0, second=0, microsecond=0) - timedelta(hours=1), 50)
                source = "site-typical"
        now_local = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(seconds=offset)
        start = _local_naive(start_time, offset) if start_time else (now_local if location else None)

        w = wx.window(hourly, start, planned["EstimatedTime_min"]) if hourly else wx.LABEL_DEFAULTS[planned["Weather"]]
        overrides = dict(temperature_c=temperature_c, humidity_pct=humidity_pct, wind_speed_kmh=wind_speed_kmh,
                         visibility_m=visibility_m, precip_mm_h=precip_mm_h)
        if any(v is not None for v in overrides.values()):
            w = wx.Weather(**{k: (v if v is not None else getattr(w, k)) for k, v in overrides.items()})
            source = "client"
        label = planned["Weather"] if source == "label-only" else str(wx.weather_label(
            w.temperature_c, w.humidity_pct, w.wind_speed_kmh, w.visibility_m, w.precip_mm_h))
        hour = start.hour if start else 8

        # 2) Predict and explain.
        row = complete_features(**{**base, "weather": label}, conditions_=w, start_hour=hour)
        eta = float(self._predict([row])[0])
        baseline = row["EstimatedTime_min"]
        effects = conditions.assess(w.temperature_c, w.humidity_pct, w.visibility_m, w.precip_mm_h,
                                    row["MaterialType"], row["MachineAge_yrs"], C.is_haul_task(row["Vertical"], row["TaskType"]))
        factors, advisories = conditions.explain(eta, effects, row["MachineAge_yrs"], w.visibility_m, w.precip_mm_h)
        if self.pipeline is None:
            factors = []  # the planner baseline doesn't model conditions
        else:
            condition_minutes = sum(f["minutes"] for f in factors)
            factors.insert(0, {"name": "operator, machine & terrain",
                               "minutes": round(eta - condition_minutes - baseline, 1),
                               "detail": f"{row['OperatorSkill']} operator, {row['MachineAge_yrs']:.0f}-yr machine"})

        result = Estimate(
            estimated_minutes=round(eta, 1), baseline_minutes=baseline, model_version=self.model_version,
            weather_source=source,
            conditions={"start_time": start.isoformat(timespec="minutes") if start else None,
                        "temperature_c": w.temperature_c, "humidity_pct": w.humidity_pct,
                        "wind_speed_kmh": w.wind_speed_kmh, "visibility_m": w.visibility_m,
                        "precip_mm_h": w.precip_mm_h, "weather": label,
                        "wbgt_c": round(float(effects["WBGT_C"]), 1),
                        "work_fraction": round(float(effects["WorkFraction"]), 2)},
            factors=factors, advisories=advisories,
        )
        if suggest_start and hourly and source != "client":
            result.best_start = self._best_start(base, hourly, now_local, eta, start)
        return result

    def _best_start(self, base: dict, hourly, now_local: datetime, current_eta: float, start: datetime) -> dict | None:
        """Fastest safe start in the next 24 h of the forecast (construction: 05-20 h only)."""
        first = now_local.replace(minute=0, second=0, microsecond=0) + timedelta(hours=1)
        candidates, rows, windows = [], [], []
        for h in range(24):
            t = first + timedelta(hours=h)
            if base["vertical"].strip().lower() == "construction" and t.hour not in CONSTRUCTION_SHIFT_HOURS:
                continue
            probe = complete_features(**base)
            w = wx.window(hourly, t, probe["EstimatedTime_min"])
            if w.visibility_m < conditions.VIS_STOP_BELOW_M or w.precip_mm_h > conditions.HEAVY_RAIN_MM_H:
                continue  # unsafe window: fog stoppage or heavy rain
            label = str(wx.weather_label(w.temperature_c, w.humidity_pct, w.wind_speed_kmh, w.visibility_m, w.precip_mm_h))
            rows.append(complete_features(**{**base, "weather": label}, conditions_=w, start_hour=t.hour))
            candidates.append(t)
            windows.append(w)
        if not rows:
            return None
        etas = self._predict(rows)
        i = int(np.argmin(etas))
        saved = round(current_eta - float(etas[i]), 1)
        w = windows[i]
        wbgt = float(conditions.wbgt_c(w.temperature_c, w.humidity_pct))
        reason = f"WBGT {wbgt:.1f} °C, visibility {w.visibility_m:.0f} m, rain {w.precip_mm_h:.1f} mm/h"
        if saved < 1:
            return {"start_time": start.isoformat(timespec="minutes"), "estimated_minutes": round(current_eta, 1),
                    "minutes_saved": 0.0, "reason": "Planned start is already as good as any in the next 24 h"}
        return {"start_time": candidates[i].isoformat(timespec="minutes"), "estimated_minutes": round(float(etas[i]), 1),
                "minutes_saved": saved, "reason": reason}
