"""Load and enforce the frozen data schemas in `ml/data/schemas/*.schema.json` (P1).

`validate(df, "telematics")` returns a list of human-readable violations (empty = valid).
Used by the generator after every run and by the tests.
"""

from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path

import pandas as pd

SCHEMA_DIR = Path(__file__).resolve().parents[1] / "data" / "schemas"
_MAX_EXAMPLES = 3


@lru_cache(maxsize=None)
def load_schema(name: str) -> dict:
    """Load `<name>.schema.json` (`telematics`, `tasks` or `reference`)."""
    return json.loads((SCHEMA_DIR / f"{name}.schema.json").read_text(encoding="utf-8"))


def _spec(name: str, table: str | None) -> dict:
    schema = load_schema(name)
    return schema["tables"][table] if table else schema


def column_names(name: str, table: str | None = None) -> list[str]:
    """Ordered column names of a dataset (or of a reference `table`)."""
    return [c["name"] for c in _spec(name, table)["columns"]]


def _resolve_allowed(col: dict, name: str) -> list[str] | dict[str, list[str]] | None:
    if "allowed" in col:
        return col["allowed"]
    ref = col.get("allowed_ref")
    if not ref:
        return None
    parts = ref.split(".")  # "enums.X" (same schema) or "<schema>.enums.X"
    schema = load_schema(name) if parts[0] == "enums" else load_schema(parts[0])
    return schema["enums"][parts[-1]]


def _examples(values: pd.Series) -> str:
    return ", ".join(repr(v) for v in values.unique()[:_MAX_EXAMPLES])


def validate(df: pd.DataFrame, name: str, table: str | None = None) -> list[str]:
    """Check `df` against the schema: columns/order, nulls, enums, patterns, ranges, keys, constraints."""
    spec = _spec(name, table)
    label = f"{name}.{table}" if table else name
    errors: list[str] = []

    expected = column_names(name, table)
    if list(df.columns) != expected:
        missing = [c for c in expected if c not in df.columns]
        extra = [c for c in df.columns if c not in expected]
        errors.append(f"{label}: columns differ from schema (missing={missing}, extra={extra}, or order)")
        return errors

    phone = df["DataSource"].eq("Phone") if "DataSource" in df.columns else None

    for col in spec["columns"]:
        cname, s = col["name"], df[col["name"]]
        present = s.notna()

        if not col.get("nullable", False) and not present.all():
            errors.append(f"{label}.{cname}: {int((~present).sum())} null values in non-nullable column")
        if col.get("null_when") == "DataSource = Phone" and phone is not None:
            if present[phone].any():
                errors.append(f"{label}.{cname}: must be null when DataSource=Phone")
            if (~present[~phone]).any():
                errors.append(f"{label}.{cname}: null on a Telematics row")

        values = s[present]
        if values.empty:
            continue

        allowed = _resolve_allowed(col, name)
        if isinstance(allowed, dict) and "Vertical" in df.columns:
            for vertical, options in allowed.items():
                bad = values[df.loc[present, "Vertical"].eq(vertical) & ~values.isin(options)]
                if not bad.empty:
                    errors.append(f"{label}.{cname}: not allowed for {vertical}: {_examples(bad)}")
        elif allowed is not None:
            options = sum(allowed.values(), []) if isinstance(allowed, dict) else allowed
            bad = values[~values.isin(options)]
            if not bad.empty:
                errors.append(f"{label}.{cname}: not in allowed values: {_examples(bad)}")

        if "pattern" in col:
            bad = values[~values.astype(str).str.fullmatch(col["pattern"])]
            if not bad.empty:
                errors.append(f"{label}.{cname}: does not match {col['pattern']}: {_examples(bad)}")

        ctype = col["type"]
        if ctype in ("int", "float"):
            nums = pd.to_numeric(values, errors="coerce")
            if nums.isna().any():
                errors.append(f"{label}.{cname}: non-numeric values: {_examples(values[nums.isna()])}")
                continue
            if ctype == "int" and not (nums % 1 == 0).all():
                errors.append(f"{label}.{cname}: non-integer values")
            if "range" in col:
                lo, hi = col["range"]
                bad = nums[(nums < lo) | (nums > hi)]
                if not bad.empty:
                    errors.append(f"{label}.{cname}: {len(bad)} values outside [{lo}, {hi}]: {_examples(bad)}")
        elif ctype in ("datetime", "date"):
            fmt = "%Y-%m-%d %H:%M:%S" if ctype == "datetime" else "%Y-%m-%d"
            parsed = pd.to_datetime(values.astype(str), format=fmt, errors="coerce")
            if parsed.isna().any():
                errors.append(f"{label}.{cname}: not in format {col['format']}: {_examples(values[parsed.isna()])}")
        elif ctype == "bool":
            if not values.isin([True, False]).all():
                errors.append(f"{label}.{cname}: non-boolean values")

        if "constraint" in col:
            m = re.fullmatch(r"(<=|>=)\s*(\w+)", col["constraint"])
            if m:
                op, other = m.groups()
                lhs, rhs = df.loc[present, cname], df.loc[present, other]
                bad = lhs > rhs if op == "<=" else lhs < rhs
                if bad.any():
                    errors.append(f"{label}.{cname}: {int(bad.sum())} rows violate '{col['constraint']}'")

    pk = spec.get("primary_key", [])
    if pk and df.duplicated(subset=pk).any():
        errors.append(f"{label}: duplicate primary key {pk}")
    return errors
