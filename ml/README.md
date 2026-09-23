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

## Run
```
pip install -r requirements.txt
python generators/generate.py --dataset tasks --vertical construction --rows 2000
```

### P2 — anomaly, safety-alert and maintenance models (`/ml/anomaly`, `/ml/safety`, `/ml/maintenance`)
Until P1's generator lands, `training/p2_dev_data.py` writes a stand-in Dataset A that follows the
schema v1.0 rules. Features, thresholds and per-machine-type norms live in
`backend/app/core/anomaly.py`, shared by training and serving. The per-type speed limits and fuel norms
there are P2 assumptions, marked `TODO(P1)`.
```
python training/p2_dev_data.py --rows 20000                  # -> data/synthetic/telematics_p2dev.csv
python training/anomaly.py --data data/synthetic/telematics_p2dev.csv   # -> models/anomaly.joblib
python training/risk.py --data data/synthetic/telematics_p2dev.csv      # -> models/{safety,maintenance}.joblib
python training/anomaly.py && python training/risk.py        # once P1's telematics.csv exists
```
The backend loads `ml/models/{anomaly,safety,maintenance}.joblib` (override with
`ANOMALY_MODEL_PATH`, `SAFETY_MODEL_PATH`, `MAINTENANCE_MODEL_PATH`). If a file is missing, that
endpoint falls back to the schema rules alone (`model_version: rules-1`). All three endpoints take
the same session body. Fuel anomaly is the `FuelAnomaly` class of the anomaly model.
