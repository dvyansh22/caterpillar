import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # backend/ -> `import app`

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.core.ml_repo import ensure_ml_importable  # noqa: E402
from app.main import app  # noqa: E402

assert ensure_ml_importable(), "ml/ package not found next to backend/"
from ml.features import weather as wx  # noqa: E402
from ml.generators.schema import column_names  # noqa: E402

client = TestClient(app)
ORIGINAL_FIELDS = {"estimated_minutes", "baseline_minutes", "model_version"}


@pytest.fixture(autouse=True)
def no_network(monkeypatch):
    """Never call Open-Meteo from tests: behave as if offline."""
    def offline(lat, lon):
        raise OSError("no network in tests")
    monkeypatch.setattr(wx, "forecast", offline)


def test_estimate_returns_contract_shape():
    r = client.post("/ml/estimate", json={
        "task_type": "Trenching", "weather": "Rainy", "operator_skill": "Beginner", "machine_age_yrs": 4})
    assert r.status_code == 200
    body = r.json()
    assert ORIGINAL_FIELDS <= set(body)  # original contract intact; v1.1 fields are additions
    assert body["estimated_minutes"] > 0 and body["baseline_minutes"] > 0


def test_estimate_orders_expert_below_beginner():
    base = {"task_type": "Load-Haul-Dump", "vertical": "mining", "machine_age_yrs": 6, "haul_distance_m": 2500}
    expert = client.post("/ml/estimate", json={**base, "weather": "Clear", "operator_skill": "Expert"}).json()
    beginner = client.post("/ml/estimate", json={**base, "weather": "Rain", "operator_skill": "Beginner"}).json()
    if expert["model_version"].startswith("xgb"):
        assert expert["estimated_minutes"] < beginner["estimated_minutes"]
    else:
        assert expert["estimated_minutes"] <= beginner["estimated_minutes"]


def test_estimate_with_site_works_offline():
    r = client.post("/ml/estimate", json={
        "task_type": "Earth Excavation", "weather": "Sunny", "operator_skill": "Beginner", "machine_age_yrs": 9,
        "site_id": "SITE01", "suggest_start": True})
    assert r.status_code == 200
    body = r.json()
    if body["model_version"] == "stub-0":
        pytest.skip("ml/ not available")
    assert body["weather_source"] == "site-typical"
    assert body["conditions"]["start_time"]


def test_estimate_with_forced_heat_explains_it():
    r = client.post("/ml/estimate", json={
        "task_type": "Earth Excavation", "weather": "Sunny", "operator_skill": "Intermediate", "machine_age_yrs": 12,
        "site_id": "SITE05", "temperature_c": 42, "humidity_pct": 25})
    body = r.json()
    assert body["weather_source"] == "client"
    assert body["conditions"]["wbgt_c"] > 30
    assert any("Heat" in a for a in body["advisories"])
    if body["model_version"].startswith("xgb"):
        assert any(f["name"] == "heat breaks" for f in body["factors"])


@pytest.mark.parametrize("bad", [{"site_id": "SITE99"}, {"humidity_pct": 150}, {"latitude": 200, "longitude": 0}])
def test_estimate_rejects_bad_location_or_weather(bad):
    r = client.post("/ml/estimate", json={
        "task_type": "Trenching", "weather": "Sunny", "operator_skill": "Expert", "machine_age_yrs": 1, **bad})
    assert r.status_code == 422


def test_estimate_rejects_unknown_task_type():
    r = client.post("/ml/estimate", json={
        "task_type": "Juggling", "weather": "Sunny", "operator_skill": "Expert", "machine_age_yrs": 1})
    assert r.status_code == 422


def test_sim_generate_returns_schema_rows():
    r = client.post("/sim/generate", json={"dataset": "telematics", "vertical": "mining", "rows": 30})
    assert r.status_code == 200
    body = r.json()
    assert body["rows_generated"] == 30
    assert len(body["sample"]) == 20
    assert list(body["sample"][0]) == column_names("telematics")


def test_sim_rejects_unknown_dataset():
    assert client.post("/sim/generate", json={"dataset": "weather"}).status_code == 422
