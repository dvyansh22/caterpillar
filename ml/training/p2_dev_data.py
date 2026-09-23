"""P2 stand-in for Dataset A (telematics) until P1's generator lands.

Emits rows in the frozen schema v1.0 (ml/data/schemas/telematics.schema.json) and labels them with
the SRS §6.1 ground-truth rules, so the P2 models can be built now and simply retrained on
P1's `telematics.csv` later. Writes to data/synthetic/telematics_p2dev.csv (git-ignored).

Usage (from ml/):
    python training/p2_dev_data.py --rows 20000
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ML_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ML_DIR.parent / "backend"))
from app.core.anomaly import catalog, label_anomaly  # noqa: E402  (catalog = P1's ml/generators/catalog.py)

SITES = {
    "construction": [("SITE01", 12.97, 77.59), ("SITE02", 19.08, 72.88), ("SITE03", 28.61, 77.21)],
    "mining": [("SITE04", 23.80, 86.43), ("SITE05", 22.25, 84.88), ("SITE06", 15.30, 74.12)],
}
PREFIX = {
    "Excavator": "EXC", "Wheel Loader": "WL", "Dozer": "DZ", "Motor Grader": "MG",
    "Backhoe Loader": "BHL", "Haul Truck": "HT", "Hydraulic Shovel": "HS", "Drill": "DR",
}
FAULTS = ["HYD_PRESSURE_LOW", "ENGINE_OVERHEAT", "AIR_FILTER_RESTRICTED", "FUEL_FILTER_CLOGGED",
          "TRACK_TENSION", "BRAKE_WEAR", "TIRE_PRESSURE_LOW"]
SKILLS = ["Beginner", "Intermediate", "Expert"]
IDLE_BETA = {"Beginner": (2.3, 6.0), "Intermediate": (2.0, 7.0), "Expert": (2.0, 8.5)}
HARSH_RATE = {"Beginner": 1.0, "Intermediate": 0.5, "Expert": 0.25}  # per 4 h
UNBELTED = {"Beginner": 0.40, "Intermediate": 0.28, "Expert": 0.15}


def make_fleet(rng: np.random.Generator, per_vertical: int = 30) -> tuple[pd.DataFrame, pd.DataFrame]:
    machines, operators, counter = [], [], {}
    for vertical, sites in SITES.items():
        types = list(catalog.MACHINE_TYPES[vertical])
        for _ in range(per_vertical):
            mtype = rng.choice(types)
            prefix = PREFIX[mtype]
            counter[prefix] = counter.get(prefix, 0) + 1
            machines.append({
                "MachineID": f"{prefix}{counter[prefix]:03d}", "MachineType": mtype,
                "Vertical": vertical, "SiteID": sites[rng.integers(len(sites))][0],
                "HasTelematics": rng.random() > 0.4, "EngineHours": rng.uniform(500, 30000),
            })
        for _ in range(per_vertical + 10):
            operators.append({
                "OperatorID": f"OP{1001 + len(operators)}", "Vertical": vertical,
                "OperatorSkill": rng.choice(SKILLS, p=[0.3, 0.45, 0.25]),
            })
    return pd.DataFrame(machines), pd.DataFrame(operators)


def generate(rows: int, seed: int = 42) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    machines, operators = make_fleet(rng)
    site_coords = {s: (lat, lon) for sites in SITES.values() for s, lat, lon in sites}
    ops_by_vertical = {v: g.reset_index(drop=True) for v, g in operators.groupby("Vertical")}

    m = machines.iloc[rng.integers(len(machines), size=rows)].reset_index(drop=True)
    ops = pd.concat(
        [ops_by_vertical[v].iloc[[rng.integers(len(ops_by_vertical[v]))]] for v in m["Vertical"]],
        ignore_index=True,
    )
    skill = ops["OperatorSkill"].to_numpy()
    spec = [catalog.MACHINE_SPECS[(v, t)] for v, t in zip(m["Vertical"], m["MachineType"])]
    speed_limit = np.array([s["speed_limit_kmh"] for s in spec])
    fuel_rate = np.array([np.mean(s["fuel_lph"]) for s in spec])
    cycle_rate = np.array([np.mean(s["cycles_per_h"]) for s in spec])
    mining = (m["Vertical"] == "mining").to_numpy()
    phone = ~m["HasTelematics"].to_numpy()

    duration = rng.uniform(60, 480, rows).round(0)
    idle_ratio = np.array([rng.beta(*IDLE_BETA[s]) for s in skill])
    idle = (duration * idle_ratio).round(1)
    work_h = (duration - idle) / 60
    cycles = np.clip(np.round(cycle_rate * work_h * rng.lognormal(0, 0.15, rows)), 0, 120)

    # Burn tracks work done, plus ~30% of the working rate while idling.
    idle_burn = 1 + 0.3 * (idle / 60) / np.maximum(work_h, 0.1)
    fuel = fuel_rate / cycle_rate * np.maximum(cycles, 1) * idle_burn * rng.lognormal(0, 0.1, rows)
    fuel = np.where(rng.random(rows) < 0.02, fuel * rng.uniform(1.8, 2.5, rows), fuel)  # leak / waste

    avg_speed = np.clip(speed_limit * 0.5 * rng.uniform(0.4, 1.0, rows), 0, 70)
    max_speed = np.minimum(avg_speed * rng.uniform(1.2, 1.6, rows), speed_limit * 0.98)
    speeding = rng.random(rows) < 0.015
    max_speed = np.clip(np.where(speeding, speed_limit * rng.uniform(1.05, 1.3, rows), max_speed), 0, 70)

    harsh = rng.poisson([HARSH_RATE[s] for s in skill] * duration / 240)
    proximity = rng.poisson(np.where(mining, 0.2, 0.4))
    ambient = np.where(mining, rng.normal(28, 10, rows), rng.normal(30, 6, rows)).clip(-20, 55)
    temp = (85 + 0.3 * (ambient - 25) + rng.normal(0, 5, rows)).clip(70, 104)
    temp = np.where(rng.random(rows) < 0.02, rng.uniform(106, 119, rows), temp)
    fault = np.where(rng.random(rows) < 0.04, rng.choice(FAULTS, rows), None)
    fault = np.where(temp > 110, "ENGINE_OVERHEAT", fault)
    hydraulic = rng.normal(260, 25, rows).clip(150, 350)
    hydraulic = np.where(fault == "HYD_PRESSURE_LOW", rng.uniform(150, 180, rows), hydraulic)

    hours_since_break = rng.uniform(0, np.where(mining, 10, 6))
    fatigue = (0.15 + 0.08 * hours_since_break + rng.normal(0, 0.1, rows)).clip(0, 1)
    seatbelt = np.where(rng.random(rows) < [UNBELTED[s] for s in skill], "Unfastened", "Fastened")
    since_service = rng.uniform(0, np.where(mining, 450, 550))

    start = pd.Timestamp("2025-05-01 06:00:00")
    df = pd.DataFrame({
        "SessionID": [f"S{i + 1:06d}" for i in range(rows)],
        "Timestamp": (start + pd.to_timedelta(np.sort(rng.uniform(0, 150 * 24 * 60, rows)), unit="min"))
        .floor("min").strftime("%Y-%m-%d %H:%M:%S"),
        "MachineID": m["MachineID"], "MachineType": m["MachineType"], "Vertical": m["Vertical"],
        "OperatorID": ops["OperatorID"], "SiteID": m["SiteID"],
        "DataSource": np.where(phone, "Phone", "Telematics"),
        "Latitude": [site_coords[s][0] + rng.normal(0, 0.01) for s in m["SiteID"]],
        "Longitude": [site_coords[s][1] + rng.normal(0, 0.01) for s in m["SiteID"]],
        "SessionDuration_min": duration,
        "EngineHours": (m["EngineHours"] + duration / 60).round(1),
        "HoursSinceService": since_service.round(1),
        "FuelUsed_L": fuel.round(1), "LoadCycles": cycles.astype(int),
        "Payload_t": [round(rng.uniform(0.5, 1.2) * p, 1) for p in _payload(m["MachineType"])],
        "IdlingTime_min": idle,
        "AvgSpeed_kmh": avg_speed.round(1), "MaxSpeed_kmh": max_speed.round(1),
        "EngineTemp_C": temp.round(1), "HydraulicPressure_bar": hydraulic.round(0),
        "RPM": rng.normal(1500, 200, rows).clip(700, 2200).round(0), "FaultCode": fault,
        "SeatbeltStatus": seatbelt, "HarshEvents": harsh.clip(0, 50),
        "ProximityWarnings": proximity.clip(0, 50),
        "HoursSinceBreak": hours_since_break.round(2), "FatigueScore": fatigue.round(3),
        "AmbientTemp_C": ambient.round(1),
    })
    for col in ["FuelUsed_L", "EngineTemp_C", "HydraulicPressure_bar", "RPM", "FaultCode"]:
        df[col] = df[col].astype(object).where(~phone, None)

    df["AnomalyType"] = label_anomaly(df)
    df["AnomalyFlag"] = np.where(df["AnomalyType"] != "None", "Yes", "No")
    df["SafetyAlertTriggered"] = _safety_alert(df, rng)
    df["MaintenanceDue"] = _maintenance(df)
    return df[_schema_columns()]


def _payload(types: pd.Series) -> list[float]:
    base = {"Haul Truck": 150, "Hydraulic Shovel": 40, "Wheel Loader": 8, "Excavator": 1.5,
            "Backhoe Loader": 1, "Dozer": 0, "Motor Grader": 0, "Drill": 0}
    return [base[t] for t in types]


def _safety_alert(df: pd.DataFrame, rng: np.random.Generator) -> np.ndarray:
    idle_ratio = df["IdlingTime_min"] / df["SessionDuration_min"]
    q1 = df.groupby("MachineType")["LoadCycles"].transform(lambda s: s.quantile(0.25))
    unbelted = df["SeatbeltStatus"] == "Unfastened"
    p = np.select(
        [unbelted & (idle_ratio > 0.4) & (df["LoadCycles"] <= q1),
         unbelted & ((df["HarshEvents"] >= 3) | (df["FatigueScore"] > 0.7))],
        [0.9, 0.7], default=0.03,
    )
    return np.where(rng.random(len(df)) < p, "Yes", "No")


def _maintenance(df: pd.DataFrame) -> np.ndarray:
    limit = np.where(df["Vertical"] == "mining", 400, 500)
    temp = pd.to_numeric(df["EngineTemp_C"], errors="coerce")
    due = (df["HoursSinceService"] > limit) | df["FaultCode"].notna() | (temp > 105)
    return np.where(due, "Yes", "No")


def _schema_columns() -> list[str]:
    import json

    schema = json.loads((ML_DIR / "data" / "schemas" / "telematics.schema.json").read_text(encoding="utf-8"))
    return [c["name"] for c in schema["columns"]]


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--rows", type=int, default=20000)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", default=str(ML_DIR / "data" / "synthetic" / "telematics_p2dev.csv"))
    args = p.parse_args()

    df = generate(args.rows, args.seed)
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(args.out, index=False)
    print(f"wrote {len(df)} rows -> {args.out}")
    for target in ["SafetyAlertTriggered", "AnomalyFlag", "MaintenanceDue"]:
        print(f"  {target}: {(df[target] == 'Yes').mean():.1%} Yes")
    print("  AnomalyType:", df["AnomalyType"].value_counts(normalize=True).round(3).to_dict())


if __name__ == "__main__":
    main()
