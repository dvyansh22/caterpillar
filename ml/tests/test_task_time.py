from datetime import datetime, timedelta, timezone

import numpy as np
import pytest

from ml.features import weather as wx
from ml.serving.task_time import (
    BASELINE_VERSION,
    DERIVED,
    FEATURES,
    TaskTimeEstimator,
    add_condition_features,
    build_pipeline,
    complete_features,
    target,
    to_minutes,
)


@pytest.fixture(scope="module")
def estimator(frames):
    tasks = add_condition_features(frames["tasks"])
    train = tasks[tasks.index % 5 != 0]
    pipeline = build_pipeline().fit(train[FEATURES], target(train))
    return TaskTimeEstimator({"pipeline": pipeline, "model_version": "test", "features": FEATURES})


def _hot_afternoons(lat, lon):
    """Fake 48 h forecast in site-local time (UTC offset 0): 40 °C 11:00-17:00, 22 °C otherwise."""
    start = datetime.now(timezone.utc).replace(tzinfo=None, minute=0, second=0, microsecond=0) - timedelta(hours=1)
    rows = []
    for h in range(48):
        t = start + timedelta(hours=h)
        hot = 11 <= t.hour <= 17
        rows.append((t, wx.Weather(40.0 if hot else 22.0, 45.0 if hot else 60.0, 10.0, 15000.0, 0.0)))
    return rows, 0


def _offline(lat, lon):
    raise OSError("no network")


@pytest.fixture(autouse=True)
def no_network(monkeypatch):
    """Tests never call Open-Meteo; individual tests swap in a fake forecast."""
    monkeypatch.setattr(wx, "forecast", _offline)


def test_complete_features_fills_every_feature():
    row = complete_features("Trenching", "Sunny", "Expert", 3.0)
    assert set(FEATURES) - set(DERIVED) <= set(row)
    assert row["EstimatedTime_min"] > 0


def test_openweather_conditions_are_mapped():
    assert complete_features("Grading", "Rain", "Beginner", 2.0)["Weather"] == "Rainy"
    assert complete_features("Grading", "clear", "Beginner", 2.0)["Weather"] == "Sunny"


@pytest.mark.parametrize("kwargs", [
    {"task_type": "Haulage"},
    {"weather": "Hail?"},
    {"operator_skill": "Pro"},
    {"task_type": "Ore Loading"},  # mining task on the default construction vertical
])
def test_unknown_values_are_rejected(kwargs):
    request = {"task_type": "Trenching", "weather": "Sunny", "operator_skill": "Expert", "machine_age_yrs": 3.0}
    with pytest.raises(ValueError):
        complete_features(**{**request, **kwargs})


def test_without_model_file_falls_back_to_baseline(tmp_path):
    est = TaskTimeEstimator.load(tmp_path / "missing.joblib").estimate(
        task_type="Trenching", weather="Sunny", operator_skill="Expert", machine_age_yrs=3.0)
    assert est.model_version == BASELINE_VERSION
    assert est.estimated_minutes == est.baseline_minutes


def test_model_beats_baseline_on_holdout(frames, estimator):
    test = frames["tasks"][frames["tasks"].index % 5 == 0]
    actual = test["ActualTime_min"].to_numpy()
    model_mae = np.mean(np.abs(to_minutes(estimator.pipeline, test) - actual))
    baseline_mae = np.mean(np.abs(test["EstimatedTime_min"].to_numpy() - actual))
    assert model_mae < 0.6 * baseline_mae


def test_eta_reflects_skill_and_weather(estimator):
    common = {"task_type": "Earth Excavation", "machine_age_yrs": 4.0}
    expert = estimator.estimate(weather="Sunny", operator_skill="Expert", **common)
    beginner = estimator.estimate(weather="Rainy", operator_skill="Beginner", **common)
    assert expert.estimated_minutes < expert.baseline_minutes < beginner.estimated_minutes
    assert expert.weather_source == "label-only" and beginner.factors


def test_heat_adds_minutes_with_a_reason(estimator):
    common = {"task_type": "Earth Excavation", "weather": "Sunny", "operator_skill": "Intermediate",
              "machine_age_yrs": 12, "site_id": "SITE01", "humidity_pct": 45}
    mild = estimator.estimate(temperature_c=24, **common)
    hot = estimator.estimate(temperature_c=40, **common)
    assert hot.weather_source == "client"
    assert hot.estimated_minutes > mild.estimated_minutes  # small test model: direction, not size
    assert any(f["name"] == "heat breaks" for f in hot.factors)
    assert any("Heat" in a for a in hot.advisories)
    # factors explain the whole gap between the planner baseline and the ETA
    assert sum(f["minutes"] for f in hot.factors) == pytest.approx(hot.estimated_minutes - hot.baseline_minutes, abs=0.5)


def test_fog_stops_haulage(estimator):
    est = estimator.estimate(task_type="Load-Haul-Dump", vertical="mining", weather="Sunny", operator_skill="Expert",
                             machine_age_yrs=4, site_id="SITE06", visibility_m=150)
    assert any(f["name"] == "low visibility" for f in est.factors)
    assert est.estimated_minutes > est.baseline_minutes


def test_live_forecast_and_best_start(estimator, monkeypatch):
    monkeypatch.setattr(wx, "forecast", _hot_afternoons)
    tomorrow_2pm = (datetime.now(timezone.utc) + timedelta(days=1)).replace(tzinfo=None, hour=14, minute=0)
    est = estimator.estimate(task_type="Earth Excavation", weather="Sunny", operator_skill="Beginner",
                             machine_age_yrs=12, site_id="SITE01", start_time=tomorrow_2pm, suggest_start=True)
    assert est.weather_source == "open-meteo"
    assert est.conditions["temperature_c"] == pytest.approx(40, abs=1)
    best = est.best_start
    assert best is not None and best["minutes_saved"] > 0
    assert not 11 <= datetime.fromisoformat(best["start_time"]).hour <= 17  # moved out of the heat


def test_offline_falls_back_to_site_typical_weather(estimator):
    est = estimator.estimate(task_type="Trenching", weather="Sunny", operator_skill="Expert", machine_age_yrs=3,
                             site_id="SITE03", suggest_start=True)
    assert est.weather_source == "site-typical"
    assert est.estimated_minutes > 0 and est.conditions["start_time"]


def test_unknown_site_is_rejected(estimator):
    with pytest.raises(ValueError):
        estimator.estimate(task_type="Trenching", weather="Sunny", operator_skill="Expert", machine_age_yrs=3,
                           site_id="SITE99")
