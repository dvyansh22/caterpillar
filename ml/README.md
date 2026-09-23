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
