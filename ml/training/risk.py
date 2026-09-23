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

TARGETS = {
    "safety": ("SafetyAlertTriggered", lambda row: safety_reasons(row)[1] > 0.5),
    "maintenance": ("MaintenanceDue", lambda row: bool(maintenance_reasons(row))),
}


def train(df: pd.DataFrame, name: str, seed: int = 42) -> tuple[dict, dict]:
    target, rule = TARGETS[name]
    X = build_features(df)
    y = (df[target] == "Yes").astype(int)

    groups = df["MachineID"]
    split = GroupShuffleSplit(n_splits=1, test_size=0.25, random_state=seed)
    train_idx, test_idx = next(split.split(X, y, groups=groups))

    # Pick the decision threshold on machines held out from training, never on the test set.
    fit_rel, val_rel = next(split.split(X.iloc[train_idx], groups=groups.iloc[train_idx]))
    fit_idx, val_idx = train_idx[fit_rel], train_idx[val_rel]
    probe = _model(seed).fit(X.iloc[fit_idx], y.iloc[fit_idx])
    val_proba = probe.predict_proba(X.iloc[val_idx])[:, 1]
    threshold = max(np.arange(0.1, 0.9, 0.05), key=lambda t: f1_score(y.iloc[val_idx], val_proba > t))

    model = _model(seed).fit(X.iloc[train_idx], y.iloc[train_idx])
    y_test = y.iloc[test_idx].to_numpy()
    proba = model.predict_proba(X.iloc[test_idx])[:, 1]
    test_rows = df.iloc[test_idx].replace({np.nan: None}).to_dict("records")
    rule_pred = np.array([rule(r) for r in test_rows])
    metrics = {
        "roc_auc": roc_auc_score(y_test, proba),
        "pr_auc": average_precision_score(y_test, proba),
        "f1": f1_score(y_test, proba > threshold),
        "threshold": round(float(threshold), 2),
        "rule_baseline_f1": f1_score(y_test, rule_pred),
        "positive_rate": float(y.mean()),
        "train_rows": len(train_idx), "test_rows": len(test_idx),
    }
    bundle = {
        "model": model,
        "features": list(X.columns),
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
              f"-> {out.name}")


if __name__ == "__main__":
    main()
