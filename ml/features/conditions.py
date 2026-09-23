"""Work-condition engine (P1): weather -> what actually slows a task down.

Pure numpy functions, so the same code handles one live request or a whole generated dataset.
Used by the generator (to cause delays), training (derived features) and /ml/estimate (factors,
advisories). Heat numbers follow published heat-stress practice; the visibility and wet-ground
magnitudes are engineering assumptions, kept here as named constants so they're easy to tune.
"""

from __future__ import annotations

import numpy as np

# ---- Heat stress --------------------------------------------------------------------------
# ACGIH TLV-style work/rest schedule for acclimatised workers doing moderate work:
# WBGT up to 28 °C -> continuous work; then 75 / 50 / 25 % work per hour.
WBGT_STEPS_C = (28.0, 29.0, 30.0)
WORK_FRACTIONS = (1.0, 0.75, 0.50, 0.25)
AC_CAB_MAX_AGE_YRS = 8.0  # assumption: newer machines have air-conditioned cabs
AC_CAB_EXPOSURE = 0.3  # share of the heat-break burden that still applies (walk-arounds, loading)

# ---- Visibility (fog, dust, heavy rain) ----------------------------------------------------
VIS_SLOW_BELOW_M = 1000.0  # travel slows below this
VIS_STOP_BELOW_M = 200.0  # haulage stops (waits) below this
HAUL_SHARE = 0.7  # share of a haul task that is driving
OTHER_SHARE = 0.2  # share of other tasks that is moving around

# ---- Wet ground -----------------------------------------------------------------------------
MATERIAL_WET_SENSITIVITY = {
    "Clay": 1.0, "Soil": 0.8, "Overburden": 0.6, "Debris": 0.5, "Coal": 0.5, "Sand": 0.4,
    "Ore": 0.4, "Gravel": 0.3, "Blasted Rock": 0.2, "Rock": 0.15,
}
WET_MAX_SLOWDOWN = 0.35  # clay in heavy rain: up to +35 %
HEAVY_RAIN_MM_H = 7.6  # above this, work pauses for safety (e.g. trench walls)
HEAVY_RAIN_PAUSE = 0.15


def wet_bulb_c(temp_c, rh_pct):
    """Stull (2011) wet-bulb temperature from air temperature and relative humidity."""
    t, rh = np.asarray(temp_c, float), np.clip(np.asarray(rh_pct, float), 5, 99)
    return (t * np.arctan(0.151977 * np.sqrt(rh + 8.313659)) + np.arctan(t + rh)
            - np.arctan(rh - 1.676331) + 0.00391838 * rh**1.5 * np.arctan(0.023101 * rh) - 4.686035)


def wbgt_c(temp_c, rh_pct):
    """Shade WBGT (no solar term): 0.7 x wet bulb + 0.3 x dry bulb."""
    return 0.7 * wet_bulb_c(temp_c, rh_pct) + 0.3 * np.asarray(temp_c, float)


def work_fraction(wbgt, machine_age_yrs):
    """Share of each hour that can be worked, after heat breaks and cab protection."""
    wbgt = np.asarray(wbgt, float)
    raw = np.select([wbgt <= s for s in WBGT_STEPS_C], WORK_FRACTIONS[:3], default=WORK_FRACTIONS[3])
    ac_cab = np.asarray(machine_age_yrs, float) < AC_CAB_MAX_AGE_YRS
    return np.where(ac_cab, 1 - AC_CAB_EXPOSURE * (1 - raw), raw)


def visibility_multiplier(visibility_m, is_haul_task):
    """Time multiplier from slower (or stopped) travel in fog / dust / heavy rain."""
    vis = np.asarray(visibility_m, float)
    share = np.where(is_haul_task, HAUL_SHARE, OTHER_SHARE)
    speed = np.clip(0.5 + 0.5 * (vis - VIS_STOP_BELOW_M) / (VIS_SLOW_BELOW_M - VIS_STOP_BELOW_M), 0.5, 1.0)
    slowed = 1 + share * (1 / speed - 1)
    return np.where(vis < VIS_STOP_BELOW_M, 1 + share * 1.5, slowed)  # below 200 m: waiting it out


def wet_ground_multiplier(precip_mm_h, material):
    """Time multiplier from rain on the working surface, by material."""
    rate = np.clip(np.asarray(precip_mm_h, float), 0, None)
    sens = np.vectorize(lambda m: MATERIAL_WET_SENSITIVITY.get(m, 0.5), otypes=[float])(material)
    return 1 + sens * np.minimum(rate, 10) / 10 * WET_MAX_SLOWDOWN + np.where(rate > HEAVY_RAIN_MM_H, HEAVY_RAIN_PAUSE, 0)


def assess(temperature_c, humidity_pct, visibility_m, precip_mm_h, material, machine_age_yrs, is_haul_task):
    """All condition effects as arrays (or scalars): the multipliers the generator and model use."""
    wbgt = wbgt_c(temperature_c, humidity_pct)
    wf = work_fraction(wbgt, machine_age_yrs)
    return {
        "WBGT_C": wbgt,
        "WorkFraction": wf,
        "HeatMultiplier": 1 / wf,
        "VisibilityMultiplier": visibility_multiplier(visibility_m, is_haul_task),
        "WetMultiplier": wet_ground_multiplier(precip_mm_h, material),
    }


def explain(eta_minutes: float, effects: dict, machine_age_yrs: float, visibility_m: float,
            precip_mm_h: float) -> tuple[list[dict], list[str]]:
    """Split an ETA into minutes per condition (they sum to the condition delay) + advisories."""
    heat, vis, wet = (float(effects[k]) for k in ("HeatMultiplier", "VisibilityMultiplier", "WetMultiplier"))
    wbgt, wf = float(effects["WBGT_C"]), float(effects["WorkFraction"])
    base = eta_minutes / (heat * vis * wet)
    factors: list[dict] = []
    if heat > 1.001:
        cab = "AC cab" if machine_age_yrs < AC_CAB_MAX_AGE_YRS else "open cab"
        factors.append({"name": "heat breaks", "minutes": round(base * (heat - 1), 1),
                        "detail": f"WBGT {wbgt:.1f} °C -> {wf:.0%} of each hour workable ({cab})"})
    if vis > 1.001:
        what = "haulage waits for fog/dust to clear" if visibility_m < VIS_STOP_BELOW_M else "slower travel"
        factors.append({"name": "low visibility", "minutes": round(base * heat * (vis - 1), 1),
                        "detail": f"visibility {visibility_m:.0f} m -> {what}"})
    if wet > 1.001:
        factors.append({"name": "wet ground", "minutes": round(base * heat * vis * (wet - 1), 1),
                        "detail": f"rain {precip_mm_h:.1f} mm/h"})

    advisories: list[str] = []
    if wbgt > WBGT_STEPS_C[0]:
        advisories.append("Heat stress: drink water every 15-20 min and take shaded rest breaks")
    if wbgt > WBGT_STEPS_C[-1]:
        advisories.append("Extreme heat: avoid outdoor work outside the cab in the afternoon")
    if visibility_m < VIS_STOP_BELOW_M:
        advisories.append("Visibility under 200 m: stop haulage, use lights and radio check-ins")
    elif visibility_m < VIS_SLOW_BELOW_M:
        advisories.append("Low visibility: reduce speed and keep headlights on")
    if precip_mm_h > HEAVY_RAIN_MM_H:
        advisories.append("Heavy rain: check trench walls and haul-road traction before resuming")
    return factors, advisories
