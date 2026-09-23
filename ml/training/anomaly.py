"""Train the unusual-behaviour model (P2, FR-ML-2) served at POST /ml/anomaly.

XGBoost multi-class on Dataset A's AnomalyType (None / ExcessiveIdle / UnsafeOperation /
FuelAnomaly / OverheatRisk). Features come from backend/app/core/anomaly.py so training and serving
can't drift. Split is by MachineID (ml/data/schemas/README.md) so no machine is in both sets.

Usage (from ml/):
    python training/anomaly.py                                   # P1's data/synthetic/telematics.csv
    python training/anomaly.py --data data/synthetic/telematics_p2dev.csv
"""

from __future__ import annotations

import argparse
import sys
from datetime import date
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import classification_report, f1_score
from sklearn.model_selection import GroupShuffleSplit
from xgboost import XGBClassifier

ML_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ML_DIR.parent / "backend"))
from app.core.anomaly import ANOMALY_TYPES, build_features  # noqa: E402
from augment import with_missing_fields  # noqa: E402


def train(df: pd.DataFrame, seed: int = 42) -> tuple[dict, dict]:
    classes = {t: i for i, t in enumerate(ANOMALY_TYPES)}
    unknown = set(df["AnomalyType"]) - set(classes)
    if unknown:
        raise ValueError(f"unknown AnomalyType values: {unknown}")

    split = GroupShuffleSplit(n_splits=1, test_size=0.25, random_state=seed)
    train_idx, test_idx = next(split.split(df, groups=df["MachineID"]))
    train_df = with_missing_fields(df.iloc[train_idx], seed=seed)
    test_df = df.iloc[test_idx]
    partial_test = with_missing_fields(test_df, copies=1, seed=seed + 1).iloc[len(test_df):]

    model = XGBClassifier(
        n_estimators=300, max_depth=5, learning_rate=0.1, subsample=0.9, colsample_bytree=0.9,
        objective="multi:softprob", num_class=len(ANOMALY_TYPES), random_state=seed,
        eval_metric="mlogloss",
    )
    # No class re-weighting: it would make partial sessions look anomalous (false alarms).
    model.fit(build_features(train_df), train_df["AnomalyType"].map(classes))

    y_test = test_df["AnomalyType"].map(classes).to_numpy()
    pred = model.predict(build_features(test_df))
    y_partial = partial_test["AnomalyType"].map(classes).to_numpy()
    pred_partial = model.predict(build_features(partial_test))
    labels = list(range(len(ANOMALY_TYPES)))
    phone = (test_df["DataSource"] == "Phone").to_numpy()
    metrics = {
        "macro_f1": f1_score(y_test, pred, labels=labels, average="macro", zero_division=0),
        "anomaly_f1": f1_score(y_test != 0, pred != 0),
        "anomaly_f1_phone_only": f1_score(y_test[phone] != 0, pred[phone] != 0),
        # Sessions with random optional fields missing, as the app may send them.
        "partial_false_alarm_rate": float(((pred_partial != 0) & (y_partial == 0)).sum() / (y_partial == 0).sum()),
        "partial_anomaly_recall": float(((pred_partial != 0) & (y_partial != 0)).sum() / max((y_partial != 0).sum(), 1)),
        "report": classification_report(y_test, pred, labels=labels, target_names=ANOMALY_TYPES,
                                        zero_division=0),
        "train_rows": len(train_df), "test_rows": len(test_df),
    }
    bundle = {
        "model": model,
        "features": list(build_features(test_df.head(1)).columns),
        "classes": ANOMALY_TYPES,
        "version": f"anomaly-xgb-{date.today():%Y%m%d}",
        "metrics": {k: v for k, v in metrics.items() if k != "report"},
    }
    return bundle, metrics


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--data", default=str(ML_DIR / "data" / "synthetic" / "telematics.csv"))
    p.add_argument("--out", default=str(ML_DIR / "models" / "anomaly.joblib"))
    p.add_argument("--seed", type=int, default=42)
    args = p.parse_args()

    # Only empty cells are missing (schema null_encoding); pandas would otherwise read "None" as NaN.
    df = pd.read_csv(args.data, keep_default_na=False, na_values=[""])
    bundle, metrics = train(df, args.seed)
    print(metrics["report"])
    print(f"macro F1 {metrics['macro_f1']:.3f} · anomaly-vs-normal F1 {metrics['anomaly_f1']:.3f} "
          f"· phone-only machines {metrics['anomaly_f1_phone_only']:.3f} "
          f"· partial sessions: false alarms {metrics['partial_false_alarm_rate']:.1%}, "
          f"anomalies caught {metrics['partial_anomaly_recall']:.1%} "
          f"· {metrics['train_rows']} train / {metrics['test_rows']} test rows")

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(bundle, args.out)
    print(f"saved {bundle['version']} -> {args.out}")


if __name__ == "__main__":
    np.set_printoptions(precision=3)
    main()
