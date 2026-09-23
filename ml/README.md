# ml/ — Data & Model Training

**Owners:** P1 / P2

Datasets, the synthetic-data generator, and model training. Trained models are exported for serving
by `backend/` (cloud) or embedded on-device (TFLite) by the app.

## Structure
```
data/
├── raw/         # organizer-provided sample data (telematics_sample.csv, task_history_sample.csv)
├── synthetic/   # generated rows (git-ignored)
└── schemas/     # frozen column definitions (the data contract) — start at data/schemas/README.md
generators/      # synthetic data generator (P1)
training/        # task_time (P1); anomaly, safety, maintenance, acoustic (P2)
models/          # exported .pkl / .joblib / .tflite (git-ignored)
notebooks/       # exploration / evaluation
```

## Data contract
**Schema v1.0 is frozen.** See [`data/schemas/README.md`](data/schemas/README.md) and
[`docs/SRS.md` §6](../docs/SRS.md#6-data-requirements) for every column, unit, enum and target.
The generator writes `telematics`, `tasks`, `sites`, `machines`, `operators`, `task_standards` CSVs to `data/synthetic/`.

## Given sample data (in data/raw/)
- **telematics_sample.csv** — Timestamp, MachineID, OperatorID, EngineHours, FuelUsed_L, LoadCycles,
  IdlingTime_min, SeatbeltStatus, SafetyAlertTriggered. Rule seen: *Unfastened + high idling + low
  load cycles → Safety Alert.*
- **task_history_sample.csv** — TaskID, TaskType, Weather, OperatorSkill, MachineAge_yrs,
  EstimatedTime_min, ActualTime_min. Target = ActualTime; the model must beat the naive estimate.

## Models (map to expected outcomes)
| Model | Owner | Type |
|---|---|---|
| Task-time estimation | P1 | XGBoost regressor |
| Anomaly / idling / unsafe | P2 | IsolationForest / classifier |
| Safety-alert prediction | P2 | Binary classifier |
| Predictive maintenance | P2 | Classifier / regressor |
| Seatbelt / fatigue / acoustic | P2 | TFLite (on-device) |

## Run (Python 3.12, from the repo root)
```
py -3.12 -m venv .venv && .venv\Scripts\activate      # macOS/Linux: python3.12 -m venv .venv && source .venv/bin/activate
pip install -r ml/requirements.txt
python ml/generators/generate.py                     # all tables, both verticals -> ml/data/synthetic/
python ml/generators/generate.py --dataset tasks --vertical mining --rows 2000 --seed 7
python ml/training/train_task_time.py                # -> ml/models/task_time_v1.joblib + .metrics.json
python -m pytest ml/tests backend/tests
```
- The generator validates every table against `data/schemas/*.schema.json` before writing.
- `generators/catalog.py` holds the domain constants (enums, machine specs, task standards, baseline formula).
- `serving/task_time.py` is shared by training and `/ml/estimate`, so features are built identically.
- The model predicts log(Actual / Estimated). Held-out-operator results are in `models/task_time_v1.metrics.json`.
- **Weather and conditions (no stored weather):**
  - `features/weather.py` simulates task weather from a few climate numbers per site (`catalog.SITE_CLIMATE`) and fetches live Open-Meteo forecasts at serving time.
  - `features/conditions.py` turns weather into work effects: heat-stress breaks (WBGT), visibility, wet ground.
  - The same code is used by the generator, training and `/ml/estimate`.

### Demo: weather-aware ETA
Start the backend (`cd backend && uvicorn app.main:app --reload`), open http://127.0.0.1:8000/docs → `POST /ml/estimate` → Try it out:
- **Live weather + best start:** `{"task_type": "Earth Excavation", "weather": "Sunny", "operator_skill": "Beginner", "machine_age_yrs": 9, "site_id": "SITE01", "suggest_start": true}`
- **Heat (repeatable):** add `"temperature_c": 37, "humidity_pct": 40` to show "heat breaks" and a hydration advisory.
  Use `"machine_age_yrs": 4` to show an AC cab softening it.
- **Fog on a mine haul:** `{"task_type": "Load-Haul-Dump", "vertical": "mining", "weather": "Sunny", "operator_skill": "Expert", "machine_age_yrs": 4, "site_id": "SITE06", "visibility_m": 150}`
- **No internet:** still works, and `weather_source` becomes `site-typical`.

### P2 — anomaly, safety-alert and maintenance models (`/ml/anomaly`, `/ml/safety`, `/ml/maintenance`)
Train on P1's `data/synthetic/telematics.csv`. `training/p2_dev_data.py` is an older stand-in Dataset A,
kept for quick experiments. Features and rule checks live in `backend/app/core/anomaly.py`, shared by
training and serving. The per-machine-type speed limits and fuel norms come from P1's
`generators/catalog.py` (`anomaly_limits`, `fuel_ratio`), the same numbers the generator labels with.
`backend/tests/test_shared_limits.py` fails if the two ever disagree.
```
python generators/generate.py                                # -> data/synthetic/telematics.csv (P1)
python training/anomaly.py                                   # -> models/anomaly.joblib
python training/risk.py                                      # -> models/{safety,maintenance}.joblib
python training/p2_dev_data.py --rows 20000                  # optional stand-in -> telematics_p2dev.csv
```
The backend loads `ml/models/{anomaly,safety,maintenance}.joblib` (override with
`ANOMALY_MODEL_PATH`, `SAFETY_MODEL_PATH`, `MAINTENANCE_MODEL_PATH`). If a file is missing, that
endpoint falls back to the schema rules alone (`model_version: rules-1`). All three endpoints take
the same session body. Fuel anomaly is the `FuelAnomaly` class of the anomaly model.

### P2 — on-device models (seatbelt, fatigue, engine sound)
Spec for the app, retraining steps and data needs: [`ondevice/README.md`](ondevice/README.md).
