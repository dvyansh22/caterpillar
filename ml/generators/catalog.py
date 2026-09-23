"""Static domain catalog for schema v1.0 (P1).

Pure-Python constants shared by the generator, training and the backend (`/ml/estimate` baseline).
No third-party imports, so the backend can import it cheaply. Enum values must match
`ml/data/schemas/*.schema.json` and `docs/SRS.md` §6.6.
"""

from __future__ import annotations

VERTICALS: tuple[str, ...] = ("construction", "mining")

SKILLS: tuple[str, ...] = ("Beginner", "Intermediate", "Expert")
WEATHERS: tuple[str, ...] = ("Sunny", "Cloudy", "Rainy", "Windy", "Dusty")
TIMES_OF_DAY: tuple[str, ...] = ("Morning", "Afternoon", "Evening", "Night")

FAULT_CODES: tuple[str, ...] = (
    "HYD_PRESSURE_LOW",
    "ENGINE_OVERHEAT",
    "AIR_FILTER_RESTRICTED",
    "FUEL_FILTER_CLOGGED",
    "TRACK_TENSION",
    "BRAKE_WEAR",
    "TIRE_PRESSURE_LOW",
)

MATERIAL_TYPES: dict[str, tuple[str, ...]] = {
    "construction": ("Soil", "Clay", "Sand", "Gravel", "Rock", "Debris"),
    "mining": ("Overburden", "Ore", "Coal", "Blasted Rock"),
}

# Hours between scheduled services; MaintenanceDue rule threshold.
SERVICE_INTERVAL_H: dict[str, float] = {"construction": 500.0, "mining": 400.0}

# ---- Sites ------------------------------------------------------------------------------
# (SiteID, SiteName, Vertical, Latitude, Longitude, mean ambient °C)
SITES: tuple[tuple[str, str, str, float, float, float], ...] = (
    ("SITE01", "Pune Metro Extension", "construction", 18.5204, 73.8567, 27.0),
    ("SITE02", "Bengaluru Ring Road", "construction", 12.9716, 77.5946, 25.0),
    ("SITE03", "Houston Logistics Park", "construction", 29.7604, -95.3698, 22.0),
    ("SITE04", "Peoria Riverfront", "construction", 40.6936, -89.5890, 12.0),
    ("SITE05", "Pilbara Iron Ore Pit", "mining", -22.5900, 117.1800, 29.0),
    ("SITE06", "Jharia Coalfield", "mining", 23.7500, 86.4200, 26.0),
    ("SITE07", "Nevada Gold Mine", "mining", 40.8000, -116.0000, 11.0),
)

# ---- Machine specs ----------------------------------------------------------------------
# Per (vertical, machine type). Ranges are (low, high).
#   prefix           MachineID prefix
#   models           model names
#   count_per_site   machines of this type at each site of the vertical
#   cycles_per_h     load/dig/dump cycles per working hour
#   payload_t        average payload per cycle
#   fuel_lph         fuel burn per working hour; idle burn is fuel_idle_lph
#   speed_limit_kmh  site speed limit for the type (MaxSpeed above it = unsafe)
#   tracked          tracked undercarriage (TRACK_TENSION) vs wheeled (TIRE/BRAKE faults)
MACHINE_SPECS: dict[tuple[str, str], dict] = {
    ("construction", "Excavator"): dict(
        prefix="EXC", models=("320", "336", "352"), count_per_site=4, cycles_per_h=(8, 14),
        payload_t=(10, 25), fuel_lph=(15, 25), fuel_idle_lph=3.0, speed_limit_kmh=5.5, tracked=True),
    ("construction", "Wheel Loader"): dict(
        prefix="WHL", models=("950", "966", "980"), count_per_site=3, cycles_per_h=(10, 15),
        payload_t=(8, 20), fuel_lph=(12, 20), fuel_idle_lph=2.5, speed_limit_kmh=30.0, tracked=False),
    ("construction", "Dozer"): dict(
        prefix="DOZ", models=("D6", "D8"), count_per_site=2, cycles_per_h=(6, 10),
        payload_t=(5, 15), fuel_lph=(20, 35), fuel_idle_lph=3.5, speed_limit_kmh=10.0, tracked=True),
    ("construction", "Motor Grader"): dict(
        prefix="GRD", models=("140", "160"), count_per_site=2, cycles_per_h=(4, 8),
        payload_t=(0, 0), fuel_lph=(10, 18), fuel_idle_lph=2.5, speed_limit_kmh=35.0, tracked=False),
    ("construction", "Backhoe Loader"): dict(
        prefix="BHL", models=("420", "432"), count_per_site=2, cycles_per_h=(6, 10),
        payload_t=(3, 8), fuel_lph=(6, 10), fuel_idle_lph=1.5, speed_limit_kmh=30.0, tracked=False),
    ("mining", "Haul Truck"): dict(
        prefix="HT", models=("777", "785", "793"), count_per_site=6, cycles_per_h=(2, 5),
        payload_t=(90, 230), fuel_lph=(80, 150), fuel_idle_lph=12.0, speed_limit_kmh=50.0, tracked=False),
    ("mining", "Hydraulic Shovel"): dict(
        prefix="SHV", models=("6015", "6030"), count_per_site=2, cycles_per_h=(10, 15),
        payload_t=(150, 240), fuel_lph=(100, 200), fuel_idle_lph=15.0, speed_limit_kmh=2.5, tracked=True),
    ("mining", "Wheel Loader"): dict(
        prefix="MWL", models=("992", "994"), count_per_site=2, cycles_per_h=(8, 14),
        payload_t=(30, 60), fuel_lph=(40, 70), fuel_idle_lph=8.0, speed_limit_kmh=25.0, tracked=False),
    ("mining", "Dozer"): dict(
        prefix="MDZ", models=("D10", "D11"), count_per_site=2, cycles_per_h=(6, 10),
        payload_t=(20, 60), fuel_lph=(40, 60), fuel_idle_lph=6.0, speed_limit_kmh=11.0, tracked=True),
    ("mining", "Drill"): dict(
        prefix="DRL", models=("MD6250", "MD6310"), count_per_site=2, cycles_per_h=(1, 3),
        payload_t=(0, 0), fuel_lph=(30, 50), fuel_idle_lph=5.0, speed_limit_kmh=3.5, tracked=True),
}

MACHINE_TYPES: dict[str, tuple[str, ...]] = {
    v: tuple(t for (vv, t) in MACHINE_SPECS if vv == v) for v in VERTICALS
}

# ---- Task standards ---------------------------------------------------------------------
# Per (vertical, task type):
#   std_time_min / ref_volume_m3 / ref_haul_m   planner standard (task_standards.csv)
#   machine_types                                machines that perform the task
#   materials                                    plausible materials
#   volume_m3 / haul_m                           sampling ranges for generated tasks
TASK_SPECS: dict[tuple[str, str], dict] = {
    ("construction", "Earth Excavation"): dict(
        std_time_min=60, ref_volume_m3=120, ref_haul_m=0, machine_types=("Excavator", "Backhoe Loader"),
        materials=("Soil", "Clay", "Sand", "Gravel", "Rock"), volume_m3=(40, 300), haul_m=(0, 0)),
    ("construction", "Trenching"): dict(
        std_time_min=45, ref_volume_m3=40, ref_haul_m=0, machine_types=("Excavator", "Backhoe Loader"),
        materials=("Soil", "Clay", "Gravel", "Rock"), volume_m3=(10, 120), haul_m=(0, 0)),
    ("construction", "Material Loading"): dict(
        std_time_min=30, ref_volume_m3=150, ref_haul_m=50, machine_types=("Wheel Loader", "Excavator"),
        materials=("Sand", "Gravel", "Soil", "Debris"), volume_m3=(50, 400), haul_m=(20, 150)),
    ("construction", "Grading"): dict(
        std_time_min=35, ref_volume_m3=60, ref_haul_m=0, machine_types=("Motor Grader", "Dozer"),
        materials=("Soil", "Gravel", "Sand"), volume_m3=(20, 200), haul_m=(0, 0)),
    ("construction", "Demolition"): dict(
        std_time_min=90, ref_volume_m3=200, ref_haul_m=0, machine_types=("Excavator",),
        materials=("Debris",), volume_m3=(60, 500), haul_m=(0, 0)),
    ("mining", "Overburden Removal"): dict(
        std_time_min=120, ref_volume_m3=3000, ref_haul_m=0, machine_types=("Hydraulic Shovel", "Dozer"),
        materials=("Overburden", "Blasted Rock"), volume_m3=(1000, 8000), haul_m=(0, 0)),
    ("mining", "Ore Loading"): dict(
        std_time_min=90, ref_volume_m3=2000, ref_haul_m=0, machine_types=("Hydraulic Shovel", "Wheel Loader"),
        materials=("Ore", "Coal"), volume_m3=(600, 5000), haul_m=(0, 0)),
    ("mining", "Load-Haul-Dump"): dict(
        std_time_min=150, ref_volume_m3=1500, ref_haul_m=2000, machine_types=("Haul Truck",),
        materials=("Ore", "Coal", "Overburden", "Blasted Rock"), volume_m3=(500, 3000), haul_m=(800, 5000)),
    ("mining", "Haul Road Maintenance"): dict(
        std_time_min=60, ref_volume_m3=300, ref_haul_m=0, machine_types=("Dozer", "Wheel Loader"),
        materials=("Blasted Rock", "Overburden"), volume_m3=(100, 1000), haul_m=(0, 0)),
    ("mining", "Bench Drilling"): dict(
        std_time_min=180, ref_volume_m3=400, ref_haul_m=0, machine_types=("Drill",),
        materials=("Ore", "Overburden"), volume_m3=(200, 1000), haul_m=(0, 0)),
}

TASK_TYPES: dict[str, tuple[str, ...]] = {
    v: tuple(t for (vv, t) in TASK_SPECS if vv == v) for v in VERTICALS
}

# Volume elasticity of planner time (economies of scale on bigger jobs).
BASELINE_VOLUME_EXPONENT = 0.9


def baseline_minutes(vertical: str, task_type: str, load_volume_m3: float, haul_distance_m: float = 0.0) -> float:
    """Naive planner estimate (`EstimatedTime_min`) from the task standards.

    StdTime scaled by volume^0.9 and, for haul tasks, by relative haul distance; rounded to 5 min
    like a human planner would (the organizer sample estimates are multiples of 5).
    """
    spec = TASK_SPECS[(vertical, task_type)]
    t = spec["std_time_min"] * (max(load_volume_m3, 1.0) / spec["ref_volume_m3"]) ** BASELINE_VOLUME_EXPONENT
    if spec["ref_haul_m"] > 0:
        t *= 0.5 + 0.5 * max(haul_distance_m, 0.0) / spec["ref_haul_m"]
    return float(min(max(5.0 * round(t / 5.0), 5.0), 1440.0))
