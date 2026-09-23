"""Video -> training photos: crop size, blur and duplicate filtering."""

import sys
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "training"))
from seatbelt_frames import SIZE, extract  # noqa: E402


def write_video(path: Path, frames: list[np.ndarray], fps: int = 30) -> None:
    h, w = frames[0].shape[:2]
    vw = cv2.VideoWriter(str(path), cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
    for f in frames:
        vw.write(f)
    vw.release()


def test_static_video_keeps_one_frame_and_crops_square(tmp_path):
    frame = np.random.default_rng(0).integers(0, 255, (480, 640, 3), dtype=np.uint8)
    write_video(tmp_path / "asha_static.mp4", [frame] * 90)
    kept, skipped = extract(tmp_path / "asha_static.mp4", tmp_path / "out", fps=3)
    assert kept == 1 and skipped >= 5
    img = cv2.imread(str(next((tmp_path / "out").glob("*.jpg"))))
    assert img.shape == (SIZE, SIZE, 3)


def test_blurry_frames_are_skipped(tmp_path):
    flat = [np.full((480, 640, 3), 120 + i % 3, np.uint8) for i in range(60)]
    write_video(tmp_path / "bala_blur.mp4", flat)
    kept, skipped = extract(tmp_path / "bala_blur.mp4", tmp_path / "out", fps=3)
    assert kept == 0 and skipped > 0


def test_moving_video_is_sampled_at_the_requested_rate(tmp_path):
    rng = np.random.default_rng(1)
    frames = [rng.integers(0, 255, (480, 640, 3), dtype=np.uint8) for _ in range(90)]  # 3 s
    write_video(tmp_path / "chen_move.mp4", frames)
    kept, _ = extract(tmp_path / "chen_move.mp4", tmp_path / "out", fps=3)
    assert kept == 9
