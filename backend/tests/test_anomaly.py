"""POST /ml/anomaly — contract + behaviour, with and without a trained model file."""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.core import anomaly as core
from app.main import app

client = TestClient(app)
MODEL = core.DEFAULT_MODEL_PATH

NORMAL = {
    "machine_id": "EXC001", "vertical": "construction", "machine_type": "Excavator",
    "data_source": "Telematics", "session_duration_min": 240, "idling_time_min": 30,
    "load_cycles": 40, "seatbelt_status": "Fastened", "harsh_events": 0, "speed_kmh": 4,
    "fuel_used_l": 60, "engine_temp_c": 90, "proximity_warnings": 0,
}


@pytest.fixture(params=["rules", "model"])
def mode(request, monkeypatch):
    if request.param == "model":
        if not MODEL.exists():
            pytest.skip("no trained model; run ml/training/anomaly.py")
        monkeypatch.setenv("ANOMALY_MODEL_PATH", str(MODEL))
    else:
        monkeypatch.setenv("ANOMALY_MODEL_PATH", str(Path("does-not-exist.joblib")))
    core.load_bundle.cache_clear()
    yield request.param
    core.load_bundle.cache_clear()


def post(**overrides):
    res = client.post("/ml/anomaly", json={**NORMAL, **overrides})
    assert res.status_code == 200
    return res.json()


def test_normal_session_is_not_anomalous(mode):
    body = post()
    assert body["anomaly"] is False
    assert body["anomaly_type"] == "None"
    assert body["reasons"] == []


@pytest.mark.parametrize(
    ("overrides", "expected", "reason_word"),
    [
        ({"idling_time_min": 150}, "ExcessiveIdle", "Idle"),
        ({"harsh_events": 6}, "UnsafeOperation", "harsh"),
        ({"speed_kmh": 9}, "UnsafeOperation", "speed"),
        ({"proximity_warnings": 4}, "UnsafeOperation", "proximity"),
        ({"fuel_used_l": 160}, "FuelAnomaly", "Fuel"),
        ({"engine_temp_c": 115}, "OverheatRisk", "temperature"),
    ],
)
def test_each_rule_is_flagged_with_a_reason(mode, overrides, expected, reason_word):
    body = post(**overrides)
    assert body["anomaly"] is True
    assert body["anomaly_type"] == expected
    assert body["score"] > 0.5
    assert any(reason_word in r for r in body["reasons"])


def test_most_severe_type_wins(mode):
    body = post(idling_time_min=150, harsh_events=6)
    assert body["anomaly_type"] == "UnsafeOperation"
    assert len(body["reasons"]) == 2


def test_phone_machine_without_engine_sensors(mode):
    body = post(data_source="Phone", fuel_used_l=None, engine_temp_c=None, idling_time_min=150)
    assert body["anomaly_type"] == "ExcessiveIdle"


def test_original_minimal_contract_still_accepted(mode):
    res = client.post("/ml/anomaly", json={
        "machine_id": "EXC001", "idling_time_min": 55, "load_cycles": 2,
        "seatbelt_status": "Unfastened",
    })
    assert res.status_code == 200
    assert set(res.json()) >= {"anomaly", "score", "reasons", "model_version"}


def test_model_version_reports_source(mode):
    version = post()["model_version"]
    assert version.startswith("rules-" if mode == "rules" else "anomaly-xgb-")
