"""Make the repo's `ml/` package (generators, catalog, model serving) importable from the backend.

Locally the backend runs from the monorepo, so `ml/` sits next to `backend/`. Override with
ML_REPO_ROOT if the layout differs.
TODO(P1): the Dockerfile builds from backend/ only; copy ml/ (code + models/) into the image
before deploying to Cloud Run, otherwise /ml/estimate serves the stub and /sim returns 503.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

REPO_ROOT = Path(os.environ.get("ML_REPO_ROOT", Path(__file__).resolve().parents[3]))


def ensure_ml_importable() -> bool:
    """Put the repo root on sys.path if it contains the `ml` package. Returns availability."""
    if not (REPO_ROOT / "ml" / "__init__.py").exists():
        return False
    if str(REPO_ROOT) not in sys.path:
        sys.path.insert(0, str(REPO_ROOT))
    return True
