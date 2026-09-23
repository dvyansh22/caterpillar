"""Reference fatigue scorer — behaviour P3's Dart port must reproduce."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ondevice.fatigue import FaceFrame, FatigueScorer  # noqa: E402

FPS = 10


def run(scorer, seconds, start=0.0, **frame):
    state = None
    for i in range(int(seconds * FPS)):
        state = scorer.update(FaceFrame(t=start + i / FPS, **frame))
    return state


def alert_face(**kw):
    return {"face_found": True, "left_eye_open": 0.9, "right_eye_open": 0.9, "head_pitch_deg": 0, **kw}


def test_alert_operator_scores_zero():
    state = run(FatigueScorer(), 60, **alert_face())
    assert state.score == 0 and not state.alert and state.perclos == 0


def test_short_blinks_do_not_trigger():
    s = FatigueScorer()
    for sec in range(60):  # one 0.2 s blink every second -> PERCLOS 0.2, no microsleep
        run(s, 0.8, start=sec, **alert_face())
        state = run(s, 0.2, start=sec + 0.8, **alert_face(left_eye_open=0.05, right_eye_open=0.05))
    assert not state.microsleep
    assert 0.3 < state.score < 0.7  # drowsy-ish, not yet an alert


def test_microsleep_alerts_immediately():
    s = FatigueScorer()
    run(s, 10, **alert_face())
    state = run(s, 1.2, start=10, **alert_face(left_eye_open=0.0, right_eye_open=0.0))
    assert state.microsleep and state.alert


def test_repeated_microsleeps_and_nods_push_score_over_alert_threshold():
    s = FatigueScorer()
    t = 0.0
    for _ in range(4):
        run(s, 8, start=t, **alert_face())
        run(s, 1.5, start=t + 8, **alert_face(left_eye_open=0.0, right_eye_open=0.0,
                                               head_pitch_deg=-25))
        t += 9.5
    state = run(s, 1, start=t, **alert_face())
    assert state.score > 0.7 and state.alert
    assert s.session_max >= state.score


def test_missing_face_is_reported_and_not_counted_as_closed_eyes():
    s = FatigueScorer()
    run(s, 5, **alert_face())
    state = run(s, 4, start=5, face_found=False)
    assert state.face_missing
    assert state.perclos == 0


def test_old_events_expire_after_the_window():
    s = FatigueScorer()
    run(s, 1.5, **alert_face(left_eye_open=0.0, right_eye_open=0.0))
    state = run(s, 70, start=1.5, **alert_face())
    assert state.score == 0
