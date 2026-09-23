import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))  # repo root -> `import ml`

from ml.generators.generate import generate_all  # noqa: E402


@pytest.fixture(scope="session")
def frames():
    return generate_all(rows=1500, seed=7)
