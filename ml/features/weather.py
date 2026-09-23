"""Weather for task-time estimation (P1) — simulated for training, live for serving. Nothing is stored.

- `sample_task_weather`: realistic hourly weather drawn from each site's climate profile
  (`catalog.SITE_CLIMATE`), used by the generator instead of downloaded history.
- `forecast`: Open-Meteo hourly forecast (free, no API key), kept in memory for 30 min.
- `typical_hourly`: deterministic "typical weather for this site, month and hour" — the offline fallback.
- `LABEL_DEFAULTS`: conditions implied by a bare weather label ("Rainy"), for old-style requests.
"""

from __future__ import annotations

import json
import math
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta

import numpy as np

from ml.generators import catalog as C

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"
TIMEOUT_S = 3.0
CACHE_TTL_S = 30 * 60


@dataclass
class Weather:
    temperature_c: float
    humidity_pct: float
    wind_speed_kmh: float
    visibility_m: float
    precip_mm_h: float


LABEL_DEFAULTS: dict[str, Weather] = {
    "Sunny": Weather(26.0, 45.0, 10.0, 15000.0, 0.0),
    "Cloudy": Weather(24.0, 60.0, 12.0, 12000.0, 0.0),
    "Rainy": Weather(22.0, 85.0, 15.0, 4000.0, 3.0),
    "Windy": Weather(24.0, 50.0, 45.0, 10000.0, 0.0),
    "Dusty": Weather(30.0, 30.0, 30.0, 1500.0, 0.0),
}


def weather_label(temperature_c, humidity_pct, wind_speed_kmh, visibility_m, precip_mm_h, dusty=False):
    """Schema `Weather` label implied by conditions (Rainy > Dusty > Windy > Cloudy > Sunny)."""
    precip, wind, vis, rh = (np.asarray(x, float) for x in (precip_mm_h, wind_speed_kmh, visibility_m, humidity_pct))
    return np.select(
        [precip >= 0.5, np.asarray(dusty) | ((vis < 3000) & (rh < 50)), wind >= 30, (vis < 3000) | (rh >= 80)],
        ["Rainy", "Dusty", "Windy", "Cloudy"], default="Sunny")


def nearest_site(latitude: float, longitude: float) -> str:
    return min(C.SITES, key=lambda s: (s[3] - latitude) ** 2 + (s[4] - longitude) ** 2)[0]


def _profile_arrays(site_ids):
    keys = ("temp_mean", "season_amp", "peak_month", "diurnal", "rh_dry", "rh_wet",
            "rain_p_dry", "rain_p_wet", "fog_p", "dust_p")
    return {k: np.array([C.SITE_CLIMATE[s][k] for s in site_ids], float) for k in keys}


def _is_wet(site_ids, month):
    return np.array([m in C.SITE_CLIMATE[s]["wet_months"] for s, m in zip(site_ids, month)])


def _mean_temp_rh(p, wet, month, hour):
    temp = (p["temp_mean"] + p["season_amp"] * np.cos(2 * np.pi * (month - p["peak_month"]) / 12)
            + p["diurnal"] / 2 * np.cos(2 * np.pi * (hour - 15) / 24) - 3.0 * wet)
    rh = np.where(wet, p["rh_wet"], p["rh_dry"]) + 12 * np.cos(2 * np.pi * (hour - 5) / 24)
    return temp, rh


def sample_task_weather(rng: np.random.Generator, site_ids, month, hour) -> dict[str, np.ndarray]:
    """Weather for each task window, from its site's climate profile, month (1-12) and start hour."""
    site_ids, month, hour = np.asarray(site_ids), np.asarray(month), np.asarray(hour)
    n, p, wet = len(site_ids), _profile_arrays(site_ids), _is_wet(site_ids, month)
    temp, rh = _mean_temp_rh(p, wet, month, hour)
    temp = temp + rng.normal(0, 2.0, n)

    raining = rng.random(n) < np.where(wet, p["rain_p_wet"], p["rain_p_dry"])
    precip = np.where(raining, rng.exponential(np.where(wet, 6.0, 3.0), n), 0.0)
    rh = np.where(raining, np.maximum(rh, 85), rh) + rng.normal(0, 5, n)

    morning = (hour >= 4) & (hour <= 9)
    fog = rng.random(n) < p["fog_p"] * np.where(morning, 3.0, 0.3)
    dust = ~raining & (rng.random(n) < p["dust_p"] * np.where((hour >= 12) & (hour <= 18), 2.0, 0.5))
    windy = rng.random(n) < 0.06
    wind = np.where(windy | dust, rng.uniform(30, 60, n), rng.uniform(0, 25, n))

    vis = rng.uniform(8000, 20000, n)
    vis = np.where(precip > 8, rng.uniform(500, 3000, n), vis)
    vis = np.where(dust, rng.uniform(150, 2000, n), vis)
    vis = np.where(fog, rng.uniform(50, 800, n), vis)
    rh = np.where(fog, np.maximum(rh, 90), rh)

    temp, rh = np.clip(temp, -20, 55), np.clip(rh, 5, 100)
    return {
        "Temperature_C": temp, "Humidity_pct": rh, "WindSpeed_kmh": wind,
        "Visibility_m": np.clip(vis, 50, 20000), "Precip_mm_h": precip,
        "Weather": weather_label(temp, rh, wind, vis, precip, dusty=dust),
    }


def typical_hourly(site_id: str, start: datetime, hours: int = 24) -> list[tuple[datetime, Weather]]:
    """Deterministic typical weather for the site from `start` onward (offline fallback)."""
    out = []
    for h in range(hours):
        t = start + timedelta(hours=h)
        p = _profile_arrays([site_id])
        wet = _is_wet([site_id], [t.month])
        temp, rh = _mean_temp_rh(p, wet, np.array([t.month]), np.array([t.hour]))
        out.append((t, Weather(round(float(temp[0]), 1), round(float(np.clip(rh[0], 5, 100)), 1), 12.0, 15000.0, 0.0)))
    return out


_cache: dict[tuple[float, float], tuple[float, list[tuple[datetime, Weather]], int]] = {}


def forecast(latitude: float, longitude: float) -> tuple[list[tuple[datetime, Weather]], int]:
    """Hourly Open-Meteo forecast (site-local times) and the site's UTC offset in seconds.

    Kept in memory for 30 min, never written to disk. Raises on network or format errors so the
    caller can fall back to `typical_hourly`.
    """
    key = (round(latitude, 2), round(longitude, 2))
    hit = _cache.get(key)
    if hit and time.time() - hit[0] < CACHE_TTL_S:
        return hit[1], hit[2]
    query = urllib.parse.urlencode({
        "latitude": latitude, "longitude": longitude, "forecast_days": 2, "timezone": "auto",
        "hourly": "temperature_2m,relative_humidity_2m,wind_speed_10m,visibility,precipitation",
    })
    with urllib.request.urlopen(f"{OPEN_METEO_URL}?{query}", timeout=TIMEOUT_S) as res:
        data = json.load(res)
    h = data["hourly"]
    rows = []
    for i, ts in enumerate(h["time"]):
        values = [h[k][i] for k in ("temperature_2m", "relative_humidity_2m", "wind_speed_10m", "visibility", "precipitation")]
        if any(v is None or (isinstance(v, float) and math.isnan(v)) for v in values):
            continue
        temp, rh, wind, vis, precip = (float(v) for v in values)
        vis = min(max(vis, 50.0), 20000.0)  # the model was trained on 50 m - 20 km
        rows.append((datetime.fromisoformat(ts), Weather(temp, rh, wind, vis, precip)))
    if not rows:
        raise ValueError("empty forecast")
    offset = int(data.get("utc_offset_seconds", 0))
    _cache[key] = (time.time(), rows, offset)
    return rows, offset


def window(hourly: list[tuple[datetime, Weather]], start: datetime, minutes: float) -> Weather:
    """Aggregate hourly weather over a task window: mean temp/RH/wind/rain, worst visibility."""
    end = start + timedelta(minutes=max(minutes, 60))
    rows = [w for t, w in hourly if start - timedelta(minutes=59) <= t < end] or [
        min(hourly, key=lambda tw: abs((tw[0] - start).total_seconds()))[1]]
    return Weather(
        temperature_c=round(float(np.mean([w.temperature_c for w in rows])), 1),
        humidity_pct=round(float(np.mean([w.humidity_pct for w in rows])), 1),
        wind_speed_kmh=round(float(np.mean([w.wind_speed_kmh for w in rows])), 1),
        visibility_m=round(float(min(w.visibility_m for w in rows)), 0),
        precip_mm_h=round(float(np.mean([w.precip_mm_h for w in rows])), 2),
    )
