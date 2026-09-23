# Data Schema v1.0 (frozen)

**Owner:** P1 · **Consumers:** P2 (Dataset A models), P4 (Firestore/dashboard), P1 (task-time model).
**The full column tables are in [`docs/SRS.md` §6](../../../docs/SRS.md#6-data-requirements).** They are
the canonical human-readable spec. The JSON files here hold the same schema in machine-readable form.
Changing a column requires sign-off from P2 and P4 and a major version bump.

## Files
| File | Describes | Output file (generated) |
|---|---|---|
| `telematics.schema.json` | Dataset A: one row per machine operating session | `data/synthetic/telematics.csv` |
| `tasks.schema.json` | Dataset B: one row per completed task | `data/synthetic/tasks.csv` |
| `reference.schema.json` | `sites`, `machines`, `operators`, `task_standards` | `data/synthetic/<table>.csv` |

Each column entry has `name, type, unit, range|allowed, nullable, role` (`key | feature | baseline | target`)
and a `description`. `generation_rules` lists the relationships the generator follows. These are
the patterns the models should learn.

## Conventions
- CSV, UTF-8, header row. A missing value is an **empty cell**. Timestamps are `YYYY-MM-DD HH:MM:SS`.
- Numeric columns carry a unit suffix (`_min`, `_L`, `_kmh`, `_C`, `_bar`, `_m3`, `_m`, `_t`, `_deg`, `_yrs`).
- Booleans/flags use the organizer style: `Yes|No`, `Fastened|Unfastened`.
- `MachineID`, `OperatorID` and `SiteID` join every table, so the datasets describe one consistent fleet.
- The organizer CSVs in `data/raw/` are valid rows of this schema; they just have the new columns blank.
- Generator default seed is `42`, so the same command always produces the same data.

## For P2 — what to know about Dataset A
- **Targets:** `SafetyAlertTriggered`, `AnomalyFlag`, `AnomalyType` (multi-class, primary type), `MaintenanceDue`.
- **Non-telematics machines:** about 40% of machines are `DataSource=Phone`. For those rows, `FuelUsed_L`, `EngineTemp_C`,
  `HydraulicPressure_bar`, `RPM` and `FaultCode` are **blank**. Models must handle missing values, because
  this is the "old machine" case the product is built around. Use XGBoost's native NaN handling, or impute
  and add a `DataSource` indicator.
- **Phone-derivable features** (always present): `IdlingTime_min`, `LoadCycles`, `SeatbeltStatus`,
  `HarshEvents`, `ProximityWarnings`, `FatigueScore`, `HoursSinceBreak`, speeds, `SessionDuration_min`.
- **Approximate class balance:** SafetyAlert about 12%, Anomaly about 8%, MaintenanceDue about 15%.
- **`/ml/anomaly` request fields map to columns:** `idling_time_min → IdlingTime_min`,
  `load_cycles → LoadCycles`, `seatbelt_status → SeatbeltStatus`, `harsh_events → HarshEvents`,
  `speed_kmh → MaxSpeed_kmh`.
- **Split by `MachineID`** or by time, not randomly. Otherwise sessions from the same machine leak between train and test.

```python
import pandas as pd
df = pd.read_csv("ml/data/synthetic/telematics.csv", parse_dates=["Timestamp"])
y = (df["SafetyAlertTriggered"] == "Yes").astype(int)
```

Until the generator lands, you can build against the 4 organizer rows in `data/raw/telematics_sample.csv`
and the column list above.
