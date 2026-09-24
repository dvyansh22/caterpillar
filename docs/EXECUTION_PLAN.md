# Execution Plan — 4-Person Team
## Smart Operator Assistant for CAT Machinery

**Team size:** 4 · **Repo:** github.com/dvyansh22/caterpillar · **Status:** v1.0 plan, now in build.
What is actually implemented (and what is simulated) is tracked in [`FEATURES.md`](FEATURES.md).

This plan divides the build across 4 people so they work **in parallel** against frozen interface
contracts. Dates are intentionally omitted (milestones are phase-based); sequence and dependencies
are what matter.

---

## 1. Roles & Ownership

| Person | Role | Owns |
|---|---|---|
| **P1** | Data & ML — Estimation | Synthetic **data generator** + schemas; **task-time estimation** (XGBoost); model eval; serves FastAPI `/ml/estimate` + `/sim`. |
| **P2** | Data & ML — Safety/Behavior | **Anomaly/idling/unsafe** (`/ml/anomaly`), **safety-alert**, **predictive maintenance**, **fuel anomaly**; prepares **on-device TFLite** models (seatbelt/fatigue/acoustic); RAG corpus + `/rag`. |
| **P3** | AR + Model Integration | **Unity AR** (everyday-object training, field repair); **flutter_unity bridge**; integrates **on-device TFLite** + **FastAPI clients** into the app (the "models in the app"). |
| **P4** | Flutter App + Backend | App shell, all **screens/navbar**, **auth/user management**, **Firebase** (Firestore/Storage/FCM/rules), **safety gate**, **task dashboard**, **voice-log UI + on-device ASR**, **SOS/BLE + proximity**, offline sync, owner web dashboard. |

**Pairing:** P1 ↔ P2 share the dataset; P3 ↔ P4 share the app (P3 = AR + ML wiring, P4 = UI + backend).

---

## 2. Interface Contracts — freeze these FIRST (Phase 0)
These are what let 4 people work without blocking each other.

1. **Data schemas** (P1/P2 → all): frozen column lists for Dataset A / Dataset B.
2. **FastAPI contract** (P1/P2 → P3): endpoint paths + request/response JSON for `/ml/estimate`,
   `/ml/anomaly`, `/rag/query`. **Ship stub responses immediately** so P3 integrates before the real
   models exist.
3. **TFLite model spec** (P2 → P3): file + input/output tensor shapes for seatbelt/fatigue/acoustic.
4. **Unity ↔ Flutter protocol** (P3 ↔ P4): message names/payloads (load model, highlight part,
   lesson step, progress).
5. **Firestore data model** (P4 → all): shapes for `users / machines / tasks / incidents /
   telematics / training / behaviorFlags / sosEvents`.

---

## 3. Work Breakdown (effort: S / M / L)

### P1 — Data & Estimation
- Design expanded dataset schemas (M)
- Build `/sim` synthetic generator for both verticals (L)
- Train + evaluate task-time XGBoost model (M)
- Serve `/ml/estimate` (S)
- Seed the demo dataset (S)

### P2 — Safety / Behavior ML
- Anomaly / idling / unsafe-pattern models (L)
- Safety-alert + predictive-maintenance + fuel-anomaly models (M)
- Train & export **TFLite** seatbelt / fatigue / acoustic models (L)
- RAG corpus + `/rag` endpoint (M)
- Serve `/ml/anomaly` (S)

### P3 — AR + Integration
- Unity AR project + AR Foundation image/object tracking (L)
- Everyday-object training module (mouse→steering, bottle→throttle) (L)
- AR field-repair exploded / animated view (M)
- flutter_unity bridge (M)
- Integrate TFLite + FastAPI clients into the app (L)
- *(Stretch)* WebRTC tele-mentoring (C)

### P4 — Flutter + Backend
- App scaffold + navigation + theming / vertical switch (M)
- Firebase Auth + RBAC + machine registry (M)
- Pre-start safety gate (S)
- Task dashboard + cards + start/active view (M)
- Voice-log + on-device ASR (M)
- **SOS BLE mesh + proximity** (L)
- Offline cache / sync (M)
- Owner web dashboard (M)

---

## 4. Milestones (phase-based)

- **Phase 0 — Foundations:** repo + Firebase project + Flutter scaffold + Unity skeleton; **freeze the
  5 interface contracts**; stub FastAPI endpoints.
- **Phase 1 — Vertical slice:** login → gate → task list → start → voice log (P4); `/sim` v1 +
  task-time v1 (P1); anomaly v1 + one TFLite model (P2); AR object-tracking "hello world" (P3).
- **Phase 2 — Feature build-out:** SOS/BLE + proximity + on-device seatbelt/fatigue (P3/P4); all ML
  models trained/served (P1/P2); AR training + field repair (P3); owner dashboard (P4).
- **Phase 3 — Integration:** wire models into the app end-to-end; both verticals; offline sync; the
  closed loop (detect → assign training).
- **Phase 4 — Demo polish:** seed demo data, rehearse the storyboard, prepare fallback mocks.

---

## 5. Risks & Mitigations
| Risk | Mitigation |
|---|---|
| Unity ↔ Flutter integration friction | Start P3's bridge in Phase 0; keep a WebAR fallback. |
| On-device ML performance | Quantize to INT8; test on real devices early. |
| BLE differences across iOS/Android | Prototype SOS/proximity in Phase 1; Android-only fallback for the demo. |
| Model accuracy from synthetic data | Encode the real sample relationships; present model-vs-baseline. |
| Scope for 4 people | MVP = operator flow + estimation + safety + SOS + AR training; repair/dashboard are stretch. |

---

## 6. Definition of Done (Demo Checklist)
- [ ] Login → safety gate → task with a real ML ETA
- [ ] Voice incident log captured and stored
- [ ] Live seatbelt / fatigue detection
- [ ] BLE SOS relays across 3 phones
- [ ] AR everyday-object lesson completes
- [ ] Both verticals switchable (construction ↔ mining)
- [ ] Owner dashboard shows a non-telematics machine
- [ ] Safety path runs fully offline
