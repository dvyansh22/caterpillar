"""Synthetic data generator (P1) — scaffold stub.

Generates telematics/task rows in the frozen schemas (see ml/data/schemas & docs/SRS.md §6),
encoding the relationships observed in the organizer samples (e.g. beginner + bad weather -> overrun;
unfastened + high idle -> safety alert). Fill in during Phase 1.

Usage:
    python generators/generate.py --dataset tasks --vertical construction --rows 2000
"""

import argparse


def generate_tasks(vertical: str, rows: int):
    # TODO(P1): synthesize rows with realistic relationships + noise; return DataFrame.
    raise NotImplementedError("Implement task-history generator in Phase 1.")


def generate_telematics(vertical: str, rows: int):
    # TODO(P1): synthesize telematics sessions; inject anomalies/alerts per observed rules.
    raise NotImplementedError("Implement telematics generator in Phase 1.")


def main() -> None:
    p = argparse.ArgumentParser(description="Synthetic data generator")
    p.add_argument("--dataset", choices=["tasks", "telematics"], required=True)
    p.add_argument("--vertical", choices=["construction", "mining"], default="construction")
    p.add_argument("--rows", type=int, default=1000)
    p.add_argument("--out", default="data/synthetic")
    args = p.parse_args()
    print(f"[stub] would generate {args.rows} {args.dataset} rows for {args.vertical} -> {args.out}")


if __name__ == "__main__":
    main()
