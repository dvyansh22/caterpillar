"""Train + evaluate the task-time XGBoost model (P1, FR-ML-1).

Evaluates on held-out *operators* (GroupShuffleSplit by OperatorID) against the naive planner
baseline `EstimatedTime_min`, then refits on all rows and saves the bundle used by `/ml/estimate`.

Usage (from the repo root or ml/):
    python ml/generators/generate.py            # writes ml/data/synthetic/tasks.csv
    python ml/training/train_task_time.py
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.model_selection import GroupShuffleSplit

if __package__ in (None, ""):  # run as a script: make `ml` importable
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from ml.generators.schema import load_schema  # noqa: E402
from ml.serving.task_time import FEATURES, MODEL_PATH, MODEL_VERSION, build_pipeline, target, to_minutes  # noqa: E402

ML_DIR = Path(__file__).resolve().parents[1]
DEFAULT_DATA = ML_DIR / "data" / "synthetic" / "tasks.csv"


def _errors(actual: np.ndarray, predicted: np.ndarray) -> dict[str, float]:
    err = predicted - actual
    return {
        "mae_min": round(float(np.mean(np.abs(err))), 2),
        "rmse_min": round(float(np.sqrt(np.mean(err**2))), 2),
        "mape_pct": round(float(np.mean(np.abs(err) / actual) * 100), 2),
    }


def evaluate(test: pd.DataFrame, predicted: np.ndarray) -> dict:
    """Model vs baseline, overall and per vertical / operator skill."""
    def block(mask: np.ndarray) -> dict:
        actual = test["ActualTime_min"].to_numpy()[mask]
        model = _errors(actual, predicted[mask])
        baseline = _errors(actual, test["EstimatedTime_min"].to_numpy()[mask])
        return {"rows": int(mask.sum()), "model": model, "baseline": baseline,
                "mae_improvement_pct": round(100 * (1 - model["mae_min"] / baseline["mae_min"]), 1)}

    everything = np.ones(len(test), dtype=bool)
    return {
        "overall": block(everything),
        "by_vertical": {v: block(test["Vertical"].eq(v).to_numpy()) for v in sorted(test["Vertical"].unique())},
        "by_skill": {s: block(test["OperatorSkill"].eq(s).to_numpy()) for s in sorted(test["OperatorSkill"].unique())},
    }


def main() -> None:
    p = argparse.ArgumentParser(description="Train the task-time XGBoost model")
    p.add_argument("--data", default=str(DEFAULT_DATA), help="tasks.csv from the generator")
    p.add_argument("--out", default=str(MODEL_PATH), help="output .joblib bundle")
    p.add_argument("--test-size", type=float, default=0.2, help="share of operators held out")
    p.add_argument("--seed", type=int, default=42)
    args = p.parse_args()

    data = Path(args.data)
    if not data.exists():
        sys.exit(f"{data} not found; run `python ml/generators/generate.py` first.")
    df = pd.read_csv(data, keep_default_na=False, na_values=[""])

    split = GroupShuffleSplit(n_splits=1, test_size=args.test_size, random_state=args.seed)
    train_idx, test_idx = next(split.split(df, groups=df["OperatorID"]))
    train, test = df.iloc[train_idx], df.iloc[test_idx].reset_index(drop=True)

    pipeline = build_pipeline(args.seed).fit(train[FEATURES], target(train))
    metrics = evaluate(test, to_minutes(pipeline, test))

    final = build_pipeline(args.seed).fit(df[FEATURES], target(df))  # ship a model trained on everything
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    report = {
        "model_version": MODEL_VERSION,
        "schema_version": load_schema("tasks")["version"],
        "trained_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "data": {"file": data.name, "rows": len(df), "train_rows": len(train), "test_rows": len(test),
                 "split": f"GroupShuffleSplit by OperatorID, test_size={args.test_size}, seed={args.seed}"},
        "features": FEATURES,
        "target": "log(ActualTime_min / EstimatedTime_min); ETA = EstimatedTime_min * exp(prediction)",
        "holdout_metrics": metrics,
    }
    joblib.dump({"pipeline": final, "model_version": MODEL_VERSION, "features": FEATURES, "report": report}, out)
    out.with_suffix(".metrics.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    o = metrics["overall"]
    print(f"Held-out operators ({o['rows']} tasks): MAE {o['model']['mae_min']} min vs baseline "
          f"{o['baseline']['mae_min']} min ({o['mae_improvement_pct']}% better); "
          f"RMSE {o['model']['rmse_min']} vs {o['baseline']['rmse_min']}; "
          f"MAPE {o['model']['mape_pct']}% vs {o['baseline']['mape_pct']}%")
    for group in ("by_vertical", "by_skill"):
        for name, m in metrics[group].items():
            print(f"  {name:<13} MAE {m['model']['mae_min']:>6} vs {m['baseline']['mae_min']:>6}  "
                  f"({m['mae_improvement_pct']}% better)")
    print(f"Saved {out} and {out.with_suffix('.metrics.json').name}")


if __name__ == "__main__":
    main()
