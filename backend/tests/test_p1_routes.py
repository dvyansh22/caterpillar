import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # backend/ -> `import app`

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402
from ml.generators.schema import column_names  # noqa: E402  (importable once app.core.ml_repo ran)

client = TestClient(app)


def test_estimate_returns_contract_shape():
    r = client.post("/ml/estimate", json={
        "task_type": "Trenching", "weather": "Rainy", "operator_skill": "Beginner", "machine_age_yrs": 4})
    assert r.status_code == 200
    body = r.json()
    assert set(body) == {"estimated_minutes", "baseline_minutes", "model_version"}
    assert body["estimated_minutes"] > 0 and body["baseline_minutes"] > 0


def test_estimate_orders_expert_below_beginner():
    base = {"task_type": "Load-Haul-Dump", "vertical": "mining", "machine_age_yrs": 6, "haul_distance_m": 2500}
    expert = client.post("/ml/estimate", json={**base, "weather": "Clear", "operator_skill": "Expert"}).json()
    beginner = client.post("/ml/estimate", json={**base, "weather": "Rain", "operator_skill": "Beginner"}).json()
    if expert["model_version"] == "xgb-v1":
        assert expert["estimated_minutes"] < beginner["estimated_minutes"]
    else:
        assert expert["estimated_minutes"] <= beginner["estimated_minutes"]


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
