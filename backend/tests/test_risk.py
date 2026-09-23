"""POST /ml/safety and /ml/maintenance — with and without trained model files."""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.core import risk
from app.main import app

client = TestClient(app)

SESSION = {
    "machine_id": "EXC001", "vertical": "construction", "machine_type": "Excavator",
    "data_source": "Telematics", "session_duration_min": 240, "idling_time_min": 30,
    "load_cycles": 40, "seatbelt_status": "Fastened", "harsh_events": 0, "speed_kmh": 4,
    "fuel_used_l": 60, "engine_temp_c": 90, "proximity_warnings": 0, "fatigue_score": 0.2,
    "hours_since_break": 1, "hours_since_service": 100,
}


@pytest.fixture(params=["rules", "model"])
def mode(request, monkeypatch):
    for name in ("safety", "maintenance"):
        path = risk.MODELS_DIR / f"{name}.joblib"
        if request.param == "model" and not path.exists():
            pytest.skip("no trained models; run ml/training/risk.py")
        monkeypatch.setenv(f"{name.upper()}_MODEL_PATH",
                           str(path if request.param == "model" else Path("missing.joblib")))
    risk.load_bundle.cache_clear()
    yield request.param
    risk.load_bundle.cache_clear()


def post(endpoint, **overrides):
    res = client.post(f"/ml/{endpoint}", json={**SESSION, **overrides})
    assert res.status_code == 200
    return res.json()


def test_safe_session_has_no_alert(mode):
    body = post("safety")
    assert body["flagged"] is False
    assert body["reasons"] == []


@pytest.mark.parametrize(
    ("overrides", "reason_word"),
    [
        ({"seatbelt_status": "Unfastened", "idling_time_min": 150, "load_cycles": 5}, "Idle"),
        ({"seatbelt_status": "Unfastened", "fatigue_score": 0.85, "hours_since_break": 9}, "fatigue"),
        ({"seatbelt_status": "Unfastened", "harsh_events": 5}, "harsh"),
    ],
)
def test_unbelted_risky_session_raises_alert(mode, overrides, reason_word):
    body = post("safety", **overrides)
    assert body["flagged"] is True
    assert "Seatbelt unfastened" in body["reasons"]
    assert any(reason_word in r for r in body["reasons"])


def test_healthy_machine_needs_no_maintenance(mode):
    body = post("maintenance")
    assert body["flagged"] is False


@pytest.mark.parametrize(
    ("overrides", "reason_word"),
    [
        ({"hours_since_service": 620}, "since last service"),
        ({"vertical": "mining", "machine_type": "Haul Truck", "hours_since_service": 450}, "interval 400"),
        ({"fault_code": "BRAKE_WEAR"}, "BRAKE_WEAR"),
        ({"engine_temp_c": 108}, "temperature"),
    ],
)
def test_maintenance_due(mode, overrides, reason_word):
    body = post("maintenance", **overrides)
    assert body["flagged"] is True
    assert any(reason_word in r for r in body["reasons"])


def test_phone_machine_uses_service_hours_only(mode):
    body = post("maintenance", data_source="Phone", fuel_used_l=None, engine_temp_c=None,
                hours_since_service=640)
    assert body["flagged"] is True


def test_model_version_reports_source(mode):
    version = post("safety")["model_version"]
    assert version.startswith("rules-" if mode == "rules" else "safety-xgb-")


def test_lowercase_seatbelt_status_is_understood(mode):
    body = post("safety", seatbelt_status="unfastened", fatigue_score=0.9, hours_since_break=9)
    assert "Seatbelt unfastened" in body["reasons"]
