"""Reference fatigue scorer (P2, FR-SAFE-1) — the logic P3 ports to Dart, frame for frame.

Input per camera frame comes from a pre-trained on-device face model (no training needed):
ML Kit face detection with classification (eye-open probabilities + head Euler angles) or the
MediaPipe Face Landmarker. See ml/ondevice/README.md for the exact mapping.

Output is `FatigueScore` in [0, 1], the same quantity as Dataset A's `FatigueScore` column
(the session maximum). Above 0.7 counts toward a safety alert (SRS §6.1).

Signals, all over a sliding window:
- PERCLOS: fraction of time the eyes are closed. The standard drowsiness measure; 0.15+ is drowsy.
- Microsleep: eyes closed continuously for >= 1 s. Immediate alert on its own.
- Head nods: head pitched down past the nod angle for >= 0.5 s.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass

EYE_CLOSED_BELOW = 0.3  # eye-open probability (ML Kit) or normalised EAR (see README)
WINDOW_S = 60.0
MICROSLEEP_S = 1.0
NOD_PITCH_DEG = -15.0  # negative pitch = head tilted down
NOD_MIN_S = 0.5
FACE_MISSING_S = 3.0

# Score weights and the value at which each signal saturates.
W_PERCLOS, PERCLOS_FULL = 0.6, 0.30
W_MICROSLEEP, MICROSLEEPS_FULL = 0.25, 3  # per window
W_NODS, NODS_FULL = 0.15, 4  # per window
ALERT_SCORE = 0.7


@dataclass
class FaceFrame:
    t: float  # seconds, monotonic
    face_found: bool
    left_eye_open: float | None = None  # 0 = closed, 1 = open
    right_eye_open: float | None = None
    head_pitch_deg: float | None = None


@dataclass
class FatigueState:
    score: float
    perclos: float
    microsleep: bool  # eyes closed >= MICROSLEEP_S right now
    face_missing: bool  # no face for >= FACE_MISSING_S (camera blocked or operator away)
    alert: bool


class FatigueScorer:
    def __init__(self) -> None:
        self._frames: deque[tuple[float, bool]] = deque()  # (t, eyes_closed)
        self._events: deque[tuple[float, str]] = deque()  # (t, "microsleep" | "nod")
        self._closed_since: float | None = None
        self._nod_since: float | None = None
        self._microsleep_counted = False
        self._nod_counted = False
        self._last_face_t: float | None = None
        self.session_max = 0.0

    def update(self, f: FaceFrame) -> FatigueState:
        if f.face_found:
            self._last_face_t = f.t
        face_missing = self._last_face_t is None or f.t - self._last_face_t >= FACE_MISSING_S

        closed = self._eyes_closed(f)
        if closed is not None:
            self._frames.append((f.t, closed))
        self._track_closure(f.t, closed)
        self._track_nod(f.t, f.head_pitch_deg if f.face_found else None)
        self._expire(f.t)

        perclos = self._perclos()
        microsleeps = sum(1 for _, kind in self._events if kind == "microsleep")
        nods = sum(1 for _, kind in self._events if kind == "nod")
        score = (W_PERCLOS * min(perclos / PERCLOS_FULL, 1.0)
                 + W_MICROSLEEP * min(microsleeps / MICROSLEEPS_FULL, 1.0)
                 + W_NODS * min(nods / NODS_FULL, 1.0))
        score = round(min(score, 1.0), 3)
        self.session_max = max(self.session_max, score)

        microsleep = self._closed_since is not None and f.t - self._closed_since >= MICROSLEEP_S
        return FatigueState(score, round(perclos, 3), microsleep, face_missing,
                            alert=microsleep or score > ALERT_SCORE)

    @staticmethod
    def _eyes_closed(f: FaceFrame) -> bool | None:
        eyes = [e for e in (f.left_eye_open, f.right_eye_open) if e is not None]
        if not f.face_found or not eyes:
            return None  # unknown frames don't count toward PERCLOS
        return sum(eyes) / len(eyes) < EYE_CLOSED_BELOW

    def _track_closure(self, t: float, closed: bool | None) -> None:
        if closed:
            if self._closed_since is None:
                self._closed_since, self._microsleep_counted = t, False
            elif not self._microsleep_counted and t - self._closed_since >= MICROSLEEP_S:
                self._events.append((t, "microsleep"))
                self._microsleep_counted = True
        elif closed is False:
            self._closed_since = None

    def _track_nod(self, t: float, pitch: float | None) -> None:
        if pitch is not None and pitch <= NOD_PITCH_DEG:
            if self._nod_since is None:
                self._nod_since, self._nod_counted = t, False
            elif not self._nod_counted and t - self._nod_since >= NOD_MIN_S:
                self._events.append((t, "nod"))
                self._nod_counted = True
        else:
            self._nod_since = None

    def _expire(self, now: float) -> None:
        while self._frames and now - self._frames[0][0] > WINDOW_S:
            self._frames.popleft()
        while self._events and now - self._events[0][0] > WINDOW_S:
            self._events.popleft()

    def _perclos(self) -> float:
        if not self._frames:
            return 0.0
        return sum(closed for _, closed in self._frames) / len(self._frames)
