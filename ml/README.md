# ml/ — Data & Model Training

**Owners:** P1 / P2

Datasets, the synthetic-data generator, and model training. Trained models are exported for serving
by `backend/` (cloud) or embedded on-device (TFLite) by the app.

## Structure
```
data/
├── raw/         # organizer-provided sample data (telematics_sample.csv, task_history_sample.csv)
├── synthetic/   # generated rows (git-ignored)
└── schemas/     # frozen column definitions (the data contract)
generators/      # synthetic data generator (P1)
training/        # task_time (P1); anomaly, safety, maintenance, acoustic (P2)
models/          # exported .pkl / .joblib / .tflite (git-ignored)
notebooks/       # exploration / evaluation
```

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
