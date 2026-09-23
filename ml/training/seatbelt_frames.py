"""Turn short phone videos into seatbelt training photos (P2).

Record a few 20-60 s clips per person from the real cab-mount position, sorted by label:
    data/seatbelt_videos/belt/<person>_<anything>.mp4
    data/seatbelt_videos/no_belt/<person>_<anything>.mp4   (incl. belt hanging, not buckled)
Start each file name with the person's name: training holds whole people out for validation, so
the score shows how it does on someone it has never seen.

This writes centre-cropped 224x224 JPEGs (the same crop the app uses, see ondevice/README.md) to
data/seatbelt/<label>/<video>_<n>.jpg, skipping blurry frames and near-duplicates.

Usage (from ml/):
    python training/seatbelt_frames.py                  # ~3 photos per second of video
    python training/seatbelt_frames.py --fps 5
"""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np

ML_DIR = Path(__file__).resolve().parents[1]
LABELS = ["belt", "no_belt"]
VIDEO_EXT = {".mp4", ".mov", ".m4v", ".avi", ".3gp", ".mkv", ".webm"}
SIZE = 224
BLUR_BELOW = 40.0  # variance of the Laplacian; lower = blurrier (motion blur, out of focus)
SAME_BELOW = 6.0  # mean absolute pixel difference to the last kept frame


def centre_square(frame: np.ndarray, size: int = SIZE) -> np.ndarray:
    h, w = frame.shape[:2]
    side = min(h, w)
    top, left = (h - side) // 2, (w - side) // 2
    return cv2.resize(frame[top:top + side, left:left + side], (size, size), interpolation=cv2.INTER_AREA)


def extract(video: Path, out_dir: Path, fps: float) -> tuple[int, int]:
    """Save sampled frames from one video. Returns (kept, skipped)."""
    cap = cv2.VideoCapture(str(video))
    if not cap.isOpened():
        raise ValueError(f"cannot open {video}")
    src_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    step = max(1, round(src_fps / fps))

    kept = skipped = index = 0
    last: np.ndarray | None = None
    out_dir.mkdir(parents=True, exist_ok=True)
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        index += 1
        if (index - 1) % step:
            continue
        img = centre_square(frame)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        blurry = cv2.Laplacian(gray, cv2.CV_64F).var() < BLUR_BELOW
        duplicate = last is not None and np.abs(gray.astype(int) - last).mean() < SAME_BELOW
        if blurry or duplicate:
            skipped += 1
            continue
        cv2.imwrite(str(out_dir / f"{video.stem}_{kept:04d}.jpg"), img, [cv2.IMWRITE_JPEG_QUALITY, 92])
        last = gray.astype(int)
        kept += 1
    cap.release()
    return kept, skipped


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--videos", default=str(ML_DIR / "data" / "seatbelt_videos"))
    p.add_argument("--out", default=str(ML_DIR / "data" / "seatbelt"))
    p.add_argument("--fps", type=float, default=3.0, help="photos to keep per second of video")
    args = p.parse_args()

    totals = {}
    for label in LABELS:
        videos = sorted(v for v in (Path(args.videos) / label).glob("*") if v.suffix.lower() in VIDEO_EXT)
        totals[label] = 0
        for video in videos:
            kept, skipped = extract(video, Path(args.out) / label, args.fps)
            totals[label] += kept
            print(f"{label:<8} {video.name}: kept {kept}, skipped {skipped} blurry/duplicate")
    print("photos:", totals)
    if min(totals.values(), default=0) < 150:
        print("tip: aim for 150+ photos per label from 4+ people before training")


if __name__ == "__main__":
    main()
