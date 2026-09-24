"""Make the repo's `ml/` package (generators, catalog, model serving) importable from the backend.

Locally the backend runs from the monorepo, so `ml/` sits next to `backend/`. Override with
ML_REPO_ROOT if the layout differs; the root `Dockerfile` copies `ml/` next to the app and sets it.
`backend/Dockerfile` copies only `app/`, so an image built from it serves the /ml/estimate stub and
/sim returns 503. Deploy with the root `Dockerfile` instead.
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
