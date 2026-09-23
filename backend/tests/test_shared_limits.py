"""P2's anomaly/maintenance rules must judge a session exactly as P1's generator labels it."""

from fastapi.testclient import TestClient

from app.core import anomaly, risk
from app.core.anomaly import catalog, label_anomaly
from app.main import app

client = TestClient(app)


def test_thresholds_match_catalog():
    assert catalog is not None, "ml/ package not importable"
    assert anomaly.FUEL_RATIO_LIMIT == catalog.FUEL_RATIO_LIMIT
    assert anomaly.OVERHEAT_TEMP_C == catalog.OVERHEAT_TEMP_C
    assert risk.MAINTENANCE_TEMP_C == catalog.MAINTENANCE_TEMP_C
    assert risk.SERVICE_LIMIT_H == catalog.SERVICE_INTERVAL_H


def test_rules_reproduce_generator_labels():
    from ml.generators.generate import generate_telematics

    sessions = generate_telematics("both", 1500, seed=11)
    assert (label_anomaly(sessions) == sessions["AnomalyType"]).all()


def test_idle_session_with_no_cycles_is_not_a_fuel_anomaly():
    body = client.post("/ml/anomaly", json={
        "machine_id": "EXC001", "vertical": "construction", "machine_type": "Excavator",
        "data_source": "Telematics", "session_duration_min": 240, "idling_time_min": 200,
        "load_cycles": 0, "seatbelt_status": "Fastened", "fuel_used_l": 12,
    }).json()
    assert body["anomaly_type"] == "ExcessiveIdle"
