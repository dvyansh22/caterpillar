"""Train the safety-alert and predictive-maintenance classifiers (P2, FR-ML-3).

Binary XGBoost on Dataset A targets `SafetyAlertTriggered` and `MaintenanceDue`, served at
POST /ml/safety and POST /ml/maintenance. Features and the rule baseline come from
backend/app/core so training and serving can't drift. Split by MachineID, as for the anomaly model.

Usage (from ml/):
    python training/risk.py                                   # P1's data/synthetic/telematics.csv
    python training/risk.py --data data/synthetic/telematics_p2dev.csv
"""

from __future__ import annotations

import argparse
import sys
from datetime import date
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import average_precision_score, f1_score, roc_auc_score
from sklearn.model_selection import GroupShuffleSplit
from xgboost import XGBClassifier

ML_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ML_DIR.parent / "backend"))
from app.core.anomaly import build_features  # noqa: E402
from app.core.risk import maintenance_reasons, safety_reasons  # noqa: E402
from augment import with_missing_fields  # noqa: E402

TARGETS = {
    "safety": ("SafetyAlertTriggered", lambda row: safety_reasons(row)[1] > 0.5),
    "maintenance": ("MaintenanceDue", lambda row: bool(maintenance_reasons(row))),
}


def train(df: pd.DataFrame, name: str, seed: int = 42) -> tuple[dict, dict]:
    target, rule = TARGETS[name]
    label = lambda d: (d[target] == "Yes").astype(int)  # noqa: E731
    fit_on = lambda d: _model(seed).fit(build_features(d), label(d))  # noqa: E731

    groups = df["MachineID"]
    split = GroupShuffleSplit(n_splits=1, test_size=0.25, random_state=seed)
    train_idx, test_idx = next(split.split(df, groups=groups))
    train_df, test_df = df.iloc[train_idx], df.iloc[test_idx]

    # Pick the decision threshold on machines held out from training, never on the test set.
    fit_rel, val_rel = next(split.split(train_df, groups=groups.iloc[train_idx]))
    val_df = with_missing_fields(train_df.iloc[val_rel], copies=1, seed=seed + 2)
    probe = fit_on(with_missing_fields(train_df.iloc[fit_rel], seed=seed))
    val_proba = probe.predict_proba(build_features(val_df))[:, 1]
    threshold = max(np.arange(0.1, 0.9, 0.05), key=lambda t: f1_score(label(val_df), val_proba > t))

    model = fit_on(with_missing_fields(train_df, seed=seed))
    y_test = label(test_df).to_numpy()
    proba = model.predict_proba(build_features(test_df))[:, 1]
    rule_pred = np.array([rule(r) for r in test_df.replace({np.nan: None}).to_dict("records")])
    partial = with_missing_fields(test_df, copies=1, seed=seed + 1).iloc[len(test_df):]
    y_partial = label(partial).to_numpy()
    flagged_partial = model.predict_proba(build_features(partial))[:, 1] > threshold
    metrics = {
        "roc_auc": roc_auc_score(y_test, proba),
        "pr_auc": average_precision_score(y_test, proba),
        "f1": f1_score(y_test, proba > threshold),
        "threshold": round(float(threshold), 2),
        "rule_baseline_f1": f1_score(y_test, rule_pred),
        # Sessions with random optional fields missing, as the app may send them.
        "partial_false_alarm_rate": float((flagged_partial & (y_partial == 0)).sum() / (y_partial == 0).sum()),
        "positive_rate": float(label(df).mean()),
        "train_rows": len(train_idx), "test_rows": len(test_idx),
    }
    bundle = {
        "model": model,
        "features": list(build_features(test_df.head(1)).columns),
        "target": target,
        "threshold": metrics["threshold"],
        "version": f"{name}-xgb-{date.today():%Y%m%d}",
        "metrics": metrics,
    }
    return bundle, metrics


def _model(seed: int) -> XGBClassifier:
    return XGBClassifier(
        n_estimators=300, max_depth=4, learning_rate=0.05, subsample=0.9, colsample_bytree=0.9,
        random_state=seed, eval_metric="logloss",
    )


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--data", default=str(ML_DIR / "data" / "synthetic" / "telematics.csv"))
    p.add_argument("--models-dir", default=str(ML_DIR / "models"))
    p.add_argument("--only", choices=list(TARGETS), help="train just one model")
    p.add_argument("--seed", type=int, default=42)
    args = p.parse_args()

    # Only empty cells are missing (schema null_encoding); pandas would otherwise read "None" as NaN.
    df = pd.read_csv(args.data, keep_default_na=False, na_values=[""])
    for name in [args.only] if args.only else TARGETS:
        bundle, m = train(df, name, args.seed)
        out = Path(args.models_dir) / f"{name}.joblib"
        out.parent.mkdir(parents=True, exist_ok=True)
        joblib.dump(bundle, out)
        print(f"{name:<12} positives {m['positive_rate']:.1%} · ROC-AUC {m['roc_auc']:.3f} · "
              f"PR-AUC {m['pr_auc']:.3f} · F1 {m['f1']:.3f} @ {m['threshold']} (rules alone {m['rule_baseline_f1']:.3f}) "
              f"· partial-session false alarms {m['partial_false_alarm_rate']:.1%} "
              f"-> {out.name}")


if __name__ == "__main__":
    main()
