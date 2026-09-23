"""Teach the models that the app often sends partial sessions.

/ml/anomaly, /ml/safety and /ml/maintenance only require idle time, load cycles and seatbelt;
everything else is optional, and old machines never have engine sensors. A model trained only on
complete rows treats a blank field as "unusual" and raises false alarms. So each training row is
also added in copies with random optional fields blanked out (labels unchanged).
"""

from __future__ import annotations

import numpy as np
import pandas as pd

# Always sent by the app (required request fields; harsh_events defaults to 0).
ALWAYS_PRESENT = {"IdlingTime_min", "LoadCycles", "SeatbeltStatus", "HarshEvents", "MachineID"}
OPTIONAL = [
    "SessionDuration_min", "HoursSinceService", "FuelUsed_L", "Payload_t", "AvgSpeed_kmh",
    "MaxSpeed_kmh", "EngineTemp_C", "HydraulicPressure_bar", "RPM", "FaultCode",
    "ProximityWarnings", "HoursSinceBreak", "FatigueScore", "AmbientTemp_C", "DataSource",
]
IDENTITY = ["Vertical", "MachineType"]  # dropped together, less often


def with_missing_fields(df: pd.DataFrame, copies: int = 2, p_drop: float = 0.5,
                        p_identity: float = 0.2, seed: int = 42) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    parts = [df]
    for _ in range(copies):
        masked = df.copy()
        for col in OPTIONAL:
            if col in masked:
                masked[col] = masked[col].astype(object).where(rng.random(len(df)) >= p_drop, None)
        drop_identity = rng.random(len(df)) < p_identity
        for col in IDENTITY:
            if col in masked:
                masked[col] = masked[col].astype(object).where(~drop_identity, None)
        parts.append(masked)
    return pd.concat(parts, ignore_index=True)
