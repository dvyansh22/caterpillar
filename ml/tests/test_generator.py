from pathlib import Path

import pandas as pd
import pytest

from ml.generators import catalog as C
from ml.generators.generate import generate_tasks, validate_all
from ml.generators.schema import column_names, load_schema

RAW = Path(__file__).resolve().parents[1] / "data" / "raw"


def test_every_table_matches_the_frozen_schema(frames):
    assert validate_all(frames) == []


def test_catalog_enums_match_schema_files():
    tel, tasks = load_schema("telematics"), load_schema("tasks")
    assert tel["enums"]["FaultCode"] == list(C.FAULT_CODES)
    for v in C.VERTICALS:
        assert tel["enums"]["MachineType"][v] == list(C.MACHINE_TYPES[v])
        assert tasks["enums"]["TaskType"][v] == list(C.TASK_TYPES[v])
        assert tasks["enums"]["MaterialType"][v] == list(C.MATERIAL_TYPES[v])


@pytest.mark.parametrize("raw, dataset", [("telematics_sample.csv", "telematics"), ("task_history_sample.csv", "tasks")])
def test_organizer_columns_are_in_schema(raw, dataset):
    header = pd.read_csv(RAW / raw, nrows=0).columns
    assert set(header) <= set(column_names(dataset))


def test_deterministic_for_a_seed():
    pd.testing.assert_frame_equal(generate_tasks("mining", 300, seed=3), generate_tasks("mining", 300, seed=3))


def test_single_vertical_equals_its_slice_of_both():
    both = generate_tasks("both", 300, seed=3)
    alone = generate_tasks("construction", 300, seed=3)
    cols = [c for c in both.columns if c != "TaskID"]
    pd.testing.assert_frame_equal(both[both["Vertical"] == "construction"][cols].reset_index(drop=True), alone[cols])


def test_keys_join_across_tables(frames):
    for name in ("tasks", "telematics"):
        df = frames[name]
        assert df["MachineID"].isin(frames["machines"]["MachineID"]).all()
        assert df["OperatorID"].isin(frames["operators"]["OperatorID"]).all()
        assert df["SiteID"].isin(frames["sites"]["SiteID"]).all()


def test_baseline_reproduces_organizer_estimates():
    # Organizer sample: Trenching 45 min, Material Loading 30 min, Demolition 90 min at standard volume.
    assert C.baseline_minutes("construction", "Trenching", 40) == 45
    assert C.baseline_minutes("construction", "Material Loading", 150, 50) == 30
    assert C.baseline_minutes("construction", "Demolition", 200) == 90


def test_task_overrun_relationships(frames):
    t = frames["tasks"]
    ratio = t["ActualTime_min"] / t["EstimatedTime_min"]
    expert_sunny = ratio[(t["OperatorSkill"] == "Expert") & (t["Weather"] == "Sunny")].mean()
    beginner_rain = ratio[(t["OperatorSkill"] == "Beginner") & (t["Weather"] == "Rainy")].mean()
    assert expert_sunny < 1.0  # experts finish under estimate
    assert beginner_rain > 1.3  # beginners + bad weather overrun


def test_organizer_safety_rule(frames):
    d = frames["telematics"]
    idle = d["IdlingTime_min"] / d["SessionDuration_min"]
    low = d["LoadCycles"] <= d.groupby(["Vertical", "MachineType"])["LoadCycles"].transform(lambda s: s.quantile(0.25))
    rule = d["SeatbeltStatus"].eq("Unfastened") & (idle > 0.4) & low
    assert rule.sum() > 20
    assert d.loc[rule, "SafetyAlertTriggered"].eq("Yes").mean() > 0.75
    assert d.loc[~rule & d["SeatbeltStatus"].eq("Fastened"), "SafetyAlertTriggered"].eq("Yes").mean() < 0.06


def test_phone_rows_have_no_engine_sensors(frames):
    phone = frames["telematics"][frames["telematics"]["DataSource"] == "Phone"]
    assert len(phone) > 0
    assert phone[["FuelUsed_L", "EngineTemp_C", "HydraulicPressure_bar", "RPM", "FaultCode"]].isna().all().all()


def _serving_rules(r) -> str:
    """Per-session AnomalyType using only catalog helpers, as /ml/anomaly must."""
    lim = C.anomaly_limits(r.Vertical, r.MachineType)
    if r.HarshEvents >= 4 or r.MaxSpeed_kmh > lim.speed_limit_kmh or r.ProximityWarnings >= 3:
        return "UnsafeOperation"
    if pd.notna(r.EngineTemp_C) and r.EngineTemp_C > C.OVERHEAT_TEMP_C:
        return "OverheatRisk"
    fuel = None if pd.isna(r.FuelUsed_L) else r.FuelUsed_L
    ratio = C.fuel_ratio(fuel, r.LoadCycles, r.Vertical, r.MachineType)
    if ratio is not None and ratio > C.FUEL_RATIO_LIMIT:
        return "FuelAnomaly"
    return "ExcessiveIdle" if r.IdlingTime_min / r.SessionDuration_min > 0.5 else "None"


def test_labels_reproducible_per_session_from_catalog(frames):
    t = frames["telematics"]
    assert all(_serving_rules(r) == r.AnomalyType for r in t.itertuples())


def test_every_machine_type_has_limits():
    for vertical, types in C.MACHINE_TYPES.items():
        for mtype in types:
            assert C.anomaly_limits(vertical, mtype) is not None
    assert C.anomaly_limits("mining", "Excavator") is None


def test_zero_load_cycles_is_never_a_fuel_anomaly():
    assert C.fuel_ratio(50.0, 0, "construction", "Excavator") is None
    assert C.fuel_ratio(None, 10, "construction", "Excavator") is None
    assert C.fuel_ratio(19.9, 10, "construction", "Excavator") == pytest.approx(1.0)


def test_both_temperature_thresholds_have_examples(frames):
    t = frames["telematics"]
    no_fault = t["FaultCode"].isna()
    between = no_fault & t["EngineTemp_C"].between(C.MAINTENANCE_TEMP_C, C.OVERHEAT_TEMP_C, inclusive="right")
    assert between.sum() > 5  # models must see 105-110 °C sessions to learn the 105 °C line
    assert (no_fault & (t["EngineTemp_C"] > C.OVERHEAT_TEMP_C)).sum() > 5


def test_anomaly_flag_matches_type(frames):
    d = frames["telematics"]
    assert (d["AnomalyFlag"].eq("Yes") == d["AnomalyType"].ne("None")).all()
