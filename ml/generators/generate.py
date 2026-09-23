"""Synthetic data generator (P1) — schema v1.0.

Generates the reference tables (sites, machines, operators, task_standards), Dataset A
(telematics) and Dataset B (tasks) for both verticals, in the frozen schemas
(`ml/data/schemas/`, `docs/SRS.md` §6). All tables share MachineID/OperatorID/SiteID, and the
ground-truth rules in SRS §6.1/§6.2 are encoded here, e.g. beginner + bad weather -> overrun,
unfastened + high idle + low load cycles -> safety alert.

Deterministic for a given --seed; each vertical draws from its own random stream, so generating
one vertical gives the same rows as that vertical's slice of `--vertical both` (IDs aside).

Usage (from the repo root or ml/):
    python ml/generators/generate.py                                  # everything, both verticals
    python ml/generators/generate.py --dataset tasks --vertical mining --rows 2000
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd
from faker import Faker

if __package__ in (None, ""):  # run as a script: make `ml` importable
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from ml.generators import catalog as C  # noqa: E402
from ml.generators.schema import column_names, validate  # noqa: E402

ML_DIR = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ML_DIR / "data" / "synthetic"
DEFAULT_ROWS = {"tasks": 10_000, "telematics": 20_000}  # per vertical

DATE_START = pd.Timestamp("2025-09-01")
DAYS = 365
OPERATORS_PER_SITE = 15
SKILL_WEIGHTS = (0.30, 0.45, 0.25)  # Beginner, Intermediate, Expert
SITE_MEAN_TEMP = {s[0]: s[5] for s in C.SITES}
EXP_HOURS = {"Beginner": (200, 2000), "Intermediate": (2000, 8000), "Expert": (8000, 20000)}

# Dataset B multipliers (SRS §6.2).
SKILL_FACTOR = {"Expert": (0.88, 0.97), "Intermediate": (1.00, 1.12), "Beginner": (1.15, 1.35)}
WEATHER_FACTOR = {"Sunny": (1.0, 1.0), "Cloudy": (1.0, 1.0), "Rainy": (1.10, 1.20), "Windy": (1.05, 1.10), "Dusty": (1.05, 1.05)}
WEATHER_P = {"construction": (0.45, 0.30, 0.13, 0.08, 0.04), "mining": (0.40, 0.20, 0.08, 0.12, 0.20)}
TIME_OF_DAY_P = {"construction": (0.45, 0.35, 0.12, 0.08), "mining": (0.35, 0.30, 0.15, 0.20)}
WEATHER_TEMP_ADJ = {"Sunny": 2.0, "Cloudy": -2.0, "Rainy": -4.0, "Windy": -1.0, "Dusty": 3.0}

# Dataset A behaviour by operator skill.
IDLE_MEAN = {"Beginner": 0.30, "Intermediate": 0.22, "Expert": 0.15}
PRODUCTIVITY = {"Beginner": 0.80, "Intermediate": 1.00, "Expert": 1.10}
UNFASTENED_P = {"Beginner": 0.30, "Intermediate": 0.15, "Expert": 0.07}
HARSH_PER_H = {"Beginner": 0.15, "Intermediate": 0.07, "Expert": 0.03}
UNSAFE_EPISODE_P = {"Beginner": 0.015, "Intermediate": 0.008, "Expert": 0.003}
OVERSPEED_P = {"Beginner": 0.015, "Intermediate": 0.008, "Expert": 0.003}
PROXIMITY_PER_H = {"construction": 0.03, "mining": 0.06}


@dataclass
class Fleet:
    """Reference tables plus hidden per-machine state used to derive engine/service hours."""

    sites: pd.DataFrame
    machines: pd.DataFrame
    operators: pd.DataFrame
    task_standards: pd.DataFrame
    machine_state: pd.DataFrame  # MachineID -> util_h_per_day, eh_start, service_cycle_h, service_offset_h

    def tables(self) -> dict[str, pd.DataFrame]:
        return {"sites": self.sites, "machines": self.machines, "operators": self.operators,
                "task_standards": self.task_standards}


def _rng(seed: int | None, *stream: int) -> np.random.Generator:
    return np.random.default_rng(None if seed is None else [seed, *stream])


def _verticals(vertical: str) -> list[str]:
    return list(C.VERTICALS) if vertical == "both" else [vertical]


def _engine_hours(state: pd.DataFrame, day: np.ndarray) -> np.ndarray:
    return state["eh_start"].to_numpy() + state["util_h_per_day"].to_numpy() * day


def _hours_since_service(state: pd.DataFrame, engine_hours: np.ndarray) -> np.ndarray:
    return np.mod(engine_hours + state["service_offset_h"].to_numpy(), state["service_cycle_h"].to_numpy())


def _seasonal_temp(site_mean: np.ndarray, lat: np.ndarray, day: np.ndarray) -> np.ndarray:
    doy = (DATE_START.dayofyear + day) % 365
    return site_mean + 8.0 * np.sign(lat) * np.sin(2 * np.pi * (doy - 105) / 365)


# ---- Reference tables -------------------------------------------------------------------
def generate_reference(seed: int | None = 42) -> Fleet:
    """Sites, machines (~40% without telematics), operators and task standards."""
    rng = _rng(seed, 0)
    fake = Faker(["en_IN", "en_US", "en_AU"])
    fake.seed_instance(seed)

    sites = pd.DataFrame([s[:5] for s in C.SITES], columns=column_names("reference", "sites"))

    machines, state, counters = [], [], {}
    for site_id, _, vertical, *_ in C.SITES:
        for (v, mtype), spec in C.MACHINE_SPECS.items():
            if v != vertical:
                continue
            for _ in range(spec["count_per_site"]):
                counters[spec["prefix"]] = counters.get(spec["prefix"], 0) + 1
                mid = f"{spec['prefix']}{counters[spec['prefix']]:03d}"
                age = round(float(min(0.5 + rng.gamma(2.0, 1.75), 15.0)), 1)  # mean ~4 yrs, long tail
                p_tel = 0.70 if age < 5 else 0.45 if age < 10 else 0.20  # older fleet = legacy machines
                util = rng.uniform(4, 9) if vertical == "construction" else rng.uniform(10, 18)
                cycle = C.SERVICE_INTERVAL_H[vertical] * rng.uniform(0.8, 1.5)  # >1 = services run late
                machines.append({
                    "MachineID": mid, "MachineType": mtype, "Model": str(rng.choice(spec["models"])),
                    "Vertical": vertical, "SiteID": site_id, "HasTelematics": bool(rng.random() < p_tel),
                    "MachineAge_yrs": age,
                })
                state.append({
                    "MachineID": mid, "util_h_per_day": util,
                    "eh_start": age * 365 * util * rng.uniform(0.5, 0.8),
                    "service_cycle_h": cycle, "service_offset_h": rng.uniform(0, cycle),
                })
    machines = pd.DataFrame(machines)
    state = pd.DataFrame(state).set_index("MachineID")

    end_eh = _engine_hours(state.loc[machines["MachineID"]], np.full(len(machines), DAYS))
    machines["EngineHours"] = end_eh.round(1)
    machines["LastServiceHrs"] = (end_eh - _hours_since_service(state.loc[machines["MachineID"]], end_eh)).round(1)
    machines = machines[column_names("reference", "machines")]

    operators, n = [], 1000
    for site_id, _, vertical, *_ in C.SITES:
        for _ in range(OPERATORS_PER_SITE):
            n += 1
            skill = str(rng.choice(C.SKILLS, p=SKILL_WEIGHTS))
            operators.append({
                "OperatorID": f"OP{n}", "Name": fake.name(), "Vertical": vertical, "SiteID": site_id,
                "OperatorSkill": skill, "OperatorExpHours": round(float(rng.uniform(*EXP_HOURS[skill]))),
            })
    operators = pd.DataFrame(operators, columns=column_names("reference", "operators"))

    task_standards = pd.DataFrame(
        [{"Vertical": v, "TaskType": t, "StdTime_min": float(s["std_time_min"]),
          "RefVolume_m3": float(s["ref_volume_m3"]), "RefHaulDistance_m": float(s["ref_haul_m"])}
         for (v, t), s in C.TASK_SPECS.items()],
        columns=column_names("reference", "task_standards"),
    )
    return Fleet(sites, machines, operators, task_standards, state)


def _pick_operators(rng: np.random.Generator, fleet: Fleet, site_ids: np.ndarray) -> pd.DataFrame:
    """One operator per row, drawn from the operators working at that row's site."""
    op_ids = np.empty(len(site_ids), dtype=object)
    for site in np.unique(site_ids):
        idx = site_ids == site
        op_ids[idx] = rng.choice(fleet.operators.loc[fleet.operators["SiteID"] == site, "OperatorID"], idx.sum())
    return fleet.operators.set_index("OperatorID").loc[op_ids].reset_index()


def _skill_position(skill: np.ndarray, exp_hours: np.ndarray) -> np.ndarray:
    """0..1 position of an operator's experience within their skill band."""
    lo = np.array([EXP_HOURS[s][0] for s in skill])
    hi = np.array([EXP_HOURS[s][1] for s in skill])
    return np.clip((exp_hours - lo) / (hi - lo), 0, 1)


# ---- Dataset B: tasks -------------------------------------------------------------------
def _tasks_for(vertical: str, n: int, rng: np.random.Generator, fleet: Fleet) -> pd.DataFrame:
    types = np.array(C.TASK_TYPES[vertical])
    task_type = rng.choice(types, n)
    fleet_m = fleet.machines[fleet.machines["Vertical"] == vertical]

    machine_id = np.empty(n, dtype=object)
    material = np.empty(n, dtype=object)
    volume = np.empty(n)
    haul = np.zeros(n)
    for t in types:
        idx = task_type == t
        k = int(idx.sum())
        spec = C.TASK_SPECS[(vertical, t)]
        machine_id[idx] = rng.choice(fleet_m.loc[fleet_m["MachineType"].isin(spec["machine_types"]), "MachineID"], k)
        material[idx] = rng.choice(spec["materials"], k)
        lo, hi = spec["volume_m3"]
        volume[idx] = np.exp(rng.uniform(np.log(lo), np.log(hi), k))
        if spec["haul_m"][1] > 0:
            haul[idx] = rng.uniform(*spec["haul_m"], k)

    m = fleet_m.set_index("MachineID").loc[machine_id].reset_index()
    ops = _pick_operators(rng, fleet, m["SiteID"].to_numpy())
    site = fleet.sites.set_index("SiteID").loc[m["SiteID"]]
    site_mean = m["SiteID"].map(SITE_MEAN_TEMP).to_numpy()

    day = rng.integers(0, DAYS, n)
    weather = rng.choice(C.WEATHERS, n, p=WEATHER_P[vertical])
    tod = rng.choice(C.TIMES_OF_DAY, n, p=TIME_OF_DAY_P[vertical])
    night = tod == "Night"
    temp = (_seasonal_temp(site_mean, site["Latitude"].to_numpy(), day)
            + np.array([WEATHER_TEMP_ADJ[w] for w in weather]) - 5.0 * night + rng.normal(0, 2.5, n))
    wind = np.where(weather == "Windy", rng.uniform(30, 60, n), rng.uniform(0, 25, n))
    slope = rng.gamma(2.0, 1.5, n) if vertical == "construction" else 1.0 + rng.gamma(2.0, 2.0, n)

    skill = ops["OperatorSkill"].to_numpy()
    exp_hours = ops["OperatorExpHours"].to_numpy(dtype=float)
    age = m["MachineAge_yrs"].to_numpy()
    estimated = np.array([C.baseline_minutes(vertical, t, v, h) for t, v, h in zip(task_type, volume, haul)])

    # ActualTime = Estimated x skill x weather x beginner_bad_weather x age x slope x night x noise.
    lo = np.array([SKILL_FACTOR[s][0] for s in skill])
    hi = np.array([SKILL_FACTOR[s][1] for s in skill])
    skill_f = hi - (hi - lo) * _skill_position(skill, exp_hours)  # more experience -> lower factor
    weather_f = np.array([rng.uniform(*WEATHER_FACTOR[w]) for w in weather])
    bad_weather_f = np.where((skill == "Beginner") & np.isin(weather, ["Rainy", "Windy"]), 1.10, 1.0)
    age_f = 1 + 0.015 * np.maximum(0, age - 3)
    slope_f = 1 + 0.01 * np.maximum(0, np.clip(slope, 0, 25) - 5)
    night_f = np.where(night, 1.08, 1.0)
    noise = rng.lognormal(0, 0.05, n)
    actual = estimated * skill_f * weather_f * bad_weather_f * age_f * slope_f * night_f * noise

    df = pd.DataFrame({
        "TaskID": "",
        "Date": (DATE_START + pd.to_timedelta(day, unit="D")).strftime("%Y-%m-%d"),
        "Vertical": vertical,
        "SiteID": m["SiteID"],
        "MachineID": m["MachineID"],
        "OperatorID": ops["OperatorID"],
        "TaskType": task_type,
        "MachineType": m["MachineType"],
        "MachineAge_yrs": age,
        "MaterialType": material,
        "TerrainSlope_deg": np.clip(slope, 0, 25).round(1),
        "Weather": weather,
        "Temperature_C": np.clip(temp, -20, 55).round(1),
        "WindSpeed_kmh": wind.round(1),
        "OperatorSkill": skill,
        "OperatorExpHours": exp_hours,
        "LoadVolume_m3": volume.round(1),
        "HaulDistance_m": haul.round(0),
        "TimeOfDay": tod,
        "EstimatedTime_min": estimated,
        "ActualTime_min": np.clip(actual, 1, 1440).round(1),
    })
    return df


def generate_tasks(vertical: str = "both", rows: int = DEFAULT_ROWS["tasks"], seed: int | None = 42,
                   fleet: Fleet | None = None) -> pd.DataFrame:
    """Dataset B. `rows` is per vertical; `vertical` is construction | mining | both."""
    fleet = fleet or generate_reference(seed)
    frames = [_tasks_for(v, rows, _rng(seed, 1, C.VERTICALS.index(v)), fleet) for v in _verticals(vertical)]
    df = pd.concat(frames, ignore_index=True)
    df["TaskID"] = [f"T{i:06d}" for i in range(1, len(df) + 1)]
    return df[column_names("tasks")]


# ---- Dataset A: telematics --------------------------------------------------------------
def _telematics_for(vertical: str, n: int, rng: np.random.Generator, fleet: Fleet) -> pd.DataFrame:
    fleet_m = fleet.machines[fleet.machines["Vertical"] == vertical]
    m = fleet_m.set_index("MachineID").loc[rng.choice(fleet_m["MachineID"], n)].reset_index()
    ops = _pick_operators(rng, fleet, m["SiteID"].to_numpy())
    site = fleet.sites.set_index("SiteID").loc[m["SiteID"]]
    site_mean = m["SiteID"].map(SITE_MEAN_TEMP).to_numpy()
    specs = [C.MACHINE_SPECS[(vertical, t)] for t in m["MachineType"]]
    spec = lambda key: np.array([s[key] for s in specs])  # noqa: E731
    spec_range = lambda key: np.array([rng.uniform(*s[key]) for s in specs])  # noqa: E731

    # When
    day = rng.integers(0, DAYS, n)
    hour = rng.integers(6, 20, n) if vertical == "construction" else rng.integers(0, 24, n)
    minute = rng.choice([0, 15, 30, 45], n)
    ts = DATE_START + pd.to_timedelta(day, unit="D") + pd.to_timedelta(hour, unit="h") + pd.to_timedelta(minute, unit="m")
    night = (hour >= 20) | (hour < 5)
    duration = rng.triangular(30, 180, 480, n).round(1)
    dur_h = duration / 60

    # Operator behaviour
    skill = ops["OperatorSkill"].to_numpy()
    pick = lambda table: np.array([table[s] for s in skill])  # noqa: E731
    idle_mean = pick(IDLE_MEAN)
    idle_ratio = rng.beta(idle_mean * 20, (1 - idle_mean) * 20)
    idle_episode = rng.random(n) < 0.05  # waiting on trucks / blasting / breakdowns
    idle_ratio = np.clip(np.where(idle_episode, rng.uniform(0.4, 0.85, n), idle_ratio), 0, 0.95)
    idling = np.minimum((duration * idle_ratio).round(1), duration)
    work_h = (duration - idling) / 60
    idle_h = idling / 60

    cycles_per_h = spec_range("cycles_per_h")
    productivity = pick(PRODUCTIVITY)
    cycles = np.clip(rng.poisson(cycles_per_h * work_h * productivity), 0, 120)
    payload = spec_range("payload_t").round(1)

    limit = spec("speed_limit_kmh")
    avg_speed = limit * rng.uniform(0.2, 0.5, n)
    max_speed = np.where(rng.random(n) < pick(OVERSPEED_P), limit * rng.uniform(1.05, 1.3, n),
                         limit * rng.uniform(0.55, 0.95, n))
    max_speed = np.clip(np.maximum(max_speed, avg_speed), 0, 70)

    harsh = rng.poisson(pick(HARSH_PER_H) * dur_h)
    harsh = np.clip(harsh + np.where(rng.random(n) < pick(UNSAFE_EPISODE_P), rng.integers(4, 11, n), 0), 0, 50)
    proximity = rng.poisson(PROXIMITY_PER_H[vertical] * dur_h)
    proximity = np.clip(proximity + np.where(rng.random(n) < 0.015, rng.integers(3, 7, n), 0), 0, 50)

    since_break = np.minimum(12, rng.uniform(0, 2, n) + dur_h * rng.uniform(0.5, 1.0, n))
    fatigue = np.clip(0.05 + 0.08 * since_break + 0.20 * night + rng.normal(0, 0.10, n), 0, 1)
    unfastened = rng.random(n) < pick(UNFASTENED_P) + 0.5 * idle_episode  # people unbuckle while waiting
    ambient = _seasonal_temp(site_mean, site["Latitude"].to_numpy(), day) - 5.0 * night + rng.normal(0, 3, n)

    # Machine state
    state = fleet.machine_state.loc[m["MachineID"]]
    engine_hours = _engine_hours(state, day + (hour + minute / 60 + dur_h) / 24)
    since_service = _hours_since_service(state, engine_hours)
    interval = C.SERVICE_INTERVAL_H[vertical]
    telematics = m["HasTelematics"].to_numpy()

    fault_p = 0.01 + 0.08 * np.clip(since_service / interval - 0.8, 0, None)
    has_fault = telematics & (rng.random(n) < fault_p)
    tracked = spec("tracked")
    fault = np.full(n, None, dtype=object)
    tracked_codes = [c for c in C.FAULT_CODES if c not in ("TIRE_PRESSURE_LOW", "BRAKE_WEAR")]
    wheeled_codes = [c for c in C.FAULT_CODES if c != "TRACK_TENSION"]
    for mask, codes in ((has_fault & tracked, tracked_codes), (has_fault & ~tracked, wheeled_codes)):
        fault[mask] = rng.choice(codes, int(mask.sum()))

    # Working fuel scales with work done (beginners burn more per cycle); idle burn on top.
    nominal = np.array([np.mean(s["fuel_lph"]) / np.mean(s["cycles_per_h"]) for s in specs])
    fuel_per_cycle = nominal / np.sqrt(productivity)
    fuel = cycles * fuel_per_cycle * rng.uniform(0.9, 1.1, n) + idle_h * spec("fuel_idle_lph")
    fuel *= np.where(np.isin(fault, ["AIR_FILTER_RESTRICTED", "FUEL_FILTER_CLOGGED"]), 1.2, 1.0)
    fuel *= np.where(rng.random(n) < 0.03, rng.uniform(1.8, 2.5, n), 1.0)  # leaks / theft / bad tuning

    engine_temp = 84 + 0.15 * (ambient - 20) + rng.normal(0, 3, n) + 0.01 * np.maximum(0, since_service - interval)
    engine_temp = np.where(fault == "ENGINE_OVERHEAT", rng.uniform(106, 118, n), engine_temp)
    # Hot-running sessions span 103-118 °C so both the 105 °C (maintenance) and 110 °C (overheat)
    # thresholds have examples on each side; otherwise models can't learn where the lines are.
    engine_temp = np.where(rng.random(n) < 0.03, rng.uniform(103, 118, n), engine_temp)
    hydraulic = np.where(fault == "HYD_PRESSURE_LOW", rng.uniform(150, 185, n), rng.uniform(200, 320, n))
    rpm = idle_ratio * 750 + (1 - idle_ratio) * rng.uniform(1300, 1900, n) + rng.normal(0, 40, n)

    def phone_null(values: np.ndarray, decimals: int = 1) -> np.ndarray:
        return np.where(telematics, np.round(values.astype(float), decimals), np.nan)

    df = pd.DataFrame({
        "SessionID": "",
        "Timestamp": ts.strftime("%Y-%m-%d %H:%M:%S"),
        "MachineID": m["MachineID"],
        "MachineType": m["MachineType"],
        "Vertical": vertical,
        "OperatorID": ops["OperatorID"],
        "SiteID": m["SiteID"],
        "DataSource": np.where(telematics, "Telematics", "Phone"),
        "Latitude": (site["Latitude"].to_numpy() + rng.normal(0, 0.01, n)).round(5),
        "Longitude": (site["Longitude"].to_numpy() + rng.normal(0, 0.01, n)).round(5),
        "SessionDuration_min": duration,
        "EngineHours": engine_hours.round(1),
        "HoursSinceService": np.clip(since_service, 0, 1000).round(1),
        "FuelUsed_L": phone_null(np.clip(fuel, 0, 2000)),
        "LoadCycles": cycles.astype(int),
        "Payload_t": payload,
        "IdlingTime_min": idling,
        "AvgSpeed_kmh": avg_speed.round(1),
        "MaxSpeed_kmh": np.maximum(max_speed.round(1), avg_speed.round(1)),
        "EngineTemp_C": phone_null(np.clip(engine_temp, 70, 120)),
        "HydraulicPressure_bar": phone_null(hydraulic),
        "RPM": phone_null(np.clip(rpm, 700, 2200), 0),
        "FaultCode": fault,
        "SeatbeltStatus": np.where(unfastened, "Unfastened", "Fastened"),
        "HarshEvents": harsh.astype(int),
        "ProximityWarnings": proximity.astype(int),
        "HoursSinceBreak": since_break.round(2),
        "FatigueScore": fatigue.round(3),
        "AmbientTemp_C": np.clip(ambient, -20, 55).round(1),
    })
    return _label_telematics(df, rng)


def _label_telematics(df: pd.DataFrame, rng: np.random.Generator) -> pd.DataFrame:
    """Apply the SRS §6.1 ground-truth rules.

    Per-type limits come from `catalog.anomaly_limits` / `catalog.fuel_ratio`, the same functions
    /ml/anomaly uses, so a single session is judged identically at training and serving time. Only
    the safety-alert "bottom quartile of LoadCycles" is a fleet statistic (per Vertical + MachineType).
    """
    groups = [df["Vertical"], df["MachineType"]]
    keys = list(zip(df["Vertical"], df["MachineType"]))
    speed_limit = np.array([C.anomaly_limits(*k).speed_limit_kmh for k in keys])
    fuel_norm = np.array([C.anomaly_limits(*k).fuel_norm_l_per_cycle for k in keys])
    idle_ratio = df["IdlingTime_min"] / df["SessionDuration_min"]
    unfastened = df["SeatbeltStatus"].eq("Unfastened")

    low_cycles = df["LoadCycles"] <= df.groupby(groups)["LoadCycles"].transform(lambda s: s.quantile(0.25))
    p_alert = np.select(
        [unfastened & (idle_ratio > 0.4) & low_cycles,
         unfastened & ((df["HarshEvents"] >= 3) | (df["FatigueScore"] > 0.7))],
        [0.9, 0.7], default=0.03)
    df["SafetyAlertTriggered"] = np.where(rng.random(len(df)) < p_alert, "Yes", "No")

    # Vectorised catalog.fuel_ratio: undefined (never an anomaly) without fuel data or with 0 cycles.
    fuel_ratio = (df["FuelUsed_L"] / df["LoadCycles"]).where(df["LoadCycles"] > 0) / fuel_norm
    anomaly = np.select(  # most severe first
        [(df["HarshEvents"] >= 4) | (df["MaxSpeed_kmh"] > speed_limit) | (df["ProximityWarnings"] >= 3),
         df["EngineTemp_C"] > C.OVERHEAT_TEMP_C,
         fuel_ratio > C.FUEL_RATIO_LIMIT,
         idle_ratio > 0.5],
        ["UnsafeOperation", "OverheatRisk", "FuelAnomaly", "ExcessiveIdle"], default="None")
    df["AnomalyFlag"] = np.where(anomaly != "None", "Yes", "No")
    df["AnomalyType"] = anomaly

    interval = df["Vertical"].map(C.SERVICE_INTERVAL_H)
    due = (df["HoursSinceService"] > interval) | df["FaultCode"].notna() | (df["EngineTemp_C"] > C.MAINTENANCE_TEMP_C)
    df["MaintenanceDue"] = np.where(due, "Yes", "No")
    return df


def generate_telematics(vertical: str = "both", rows: int = DEFAULT_ROWS["telematics"], seed: int | None = 42,
                        fleet: Fleet | None = None) -> pd.DataFrame:
    """Dataset A. `rows` is per vertical; `vertical` is construction | mining | both."""
    fleet = fleet or generate_reference(seed)
    frames = [_telematics_for(v, rows, _rng(seed, 2, C.VERTICALS.index(v)), fleet) for v in _verticals(vertical)]
    df = pd.concat(frames, ignore_index=True).sort_values(["Timestamp", "MachineID"], ignore_index=True)
    df["SessionID"] = [f"S{i:06d}" for i in range(1, len(df) + 1)]
    return df[column_names("telematics")]


# ---- Orchestration ----------------------------------------------------------------------
def generate_all(dataset: str = "all", vertical: str = "both", rows: int | None = None,
                 seed: int | None = 42) -> dict[str, pd.DataFrame]:
    """Reference tables (always) plus the requested dataset(s)."""
    fleet = generate_reference(seed)
    out = dict(fleet.tables())
    if dataset in ("all", "tasks"):
        out["tasks"] = generate_tasks(vertical, rows or DEFAULT_ROWS["tasks"], seed, fleet)
    if dataset in ("all", "telematics"):
        out["telematics"] = generate_telematics(vertical, rows or DEFAULT_ROWS["telematics"], seed, fleet)
    return out


def validate_all(frames: dict[str, pd.DataFrame]) -> list[str]:
    errors: list[str] = []
    for name, df in frames.items():
        errors += validate(df, name) if name in ("tasks", "telematics") else validate(df, "reference", name)
    return errors


def summarize(frames: dict[str, pd.DataFrame]) -> str:
    lines = [f"  {name:<15} {len(df):>7,} rows" for name, df in frames.items()]
    if "telematics" in frames:
        t = frames["telematics"]
        lines.append("  telematics prevalence: "
                     f"SafetyAlert {t['SafetyAlertTriggered'].eq('Yes').mean():.1%}, "
                     f"Anomaly {t['AnomalyFlag'].eq('Yes').mean():.1%}, "
                     f"MaintenanceDue {t['MaintenanceDue'].eq('Yes').mean():.1%}, "
                     f"Phone rows {t['DataSource'].eq('Phone').mean():.1%}")
    if "tasks" in frames:
        k = frames["tasks"]
        ratio = (k["ActualTime_min"] / k["EstimatedTime_min"]).groupby(k["OperatorSkill"]).mean()
        lines.append("  tasks Actual/Estimated by skill: " + ", ".join(f"{s} {r:.2f}" for s, r in ratio.items()))
    return "\n".join(lines)


def main() -> None:
    p = argparse.ArgumentParser(description="Synthetic data generator (schema v1.0)")
    p.add_argument("--dataset", choices=["all", "tasks", "telematics", "reference"], default="all")
    p.add_argument("--vertical", choices=["both", "construction", "mining"], default="both")
    p.add_argument("--rows", type=int, default=None,
                   help=f"rows per vertical (default: tasks {DEFAULT_ROWS['tasks']}, telematics {DEFAULT_ROWS['telematics']})")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", default=str(DEFAULT_OUT), help="output directory for the CSVs")
    p.add_argument("--no-validate", action="store_true", help="skip schema validation")
    args = p.parse_args()

    frames = generate_all(args.dataset, args.vertical, args.rows, args.seed)
    if not args.no_validate:
        errors = validate_all(frames)
        if errors:
            sys.exit("Schema validation failed:\n  " + "\n  ".join(errors))

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for name, df in frames.items():
        df.to_csv(out / f"{name}.csv", index=False)
    print(f"Wrote to {out} (seed={args.seed}, vertical={args.vertical}):\n{summarize(frames)}")


if __name__ == "__main__":
    main()
