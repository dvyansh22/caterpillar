import numpy as np
import pytest

from ml.serving.task_time import (
    BASELINE_VERSION,
    FEATURES,
    TaskTimeEstimator,
    build_pipeline,
    complete_features,
    target,
    to_minutes,
)


@pytest.fixture(scope="module")
def estimator(frames):
    tasks = frames["tasks"]
    train = tasks[tasks.index % 5 != 0]
    pipeline = build_pipeline().fit(train[FEATURES], target(train))
    return TaskTimeEstimator({"pipeline": pipeline, "model_version": "test"})


def test_complete_features_fills_every_feature():
    row = complete_features("Trenching", "Sunny", "Expert", 3.0)
    assert set(FEATURES) <= set(row)
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
