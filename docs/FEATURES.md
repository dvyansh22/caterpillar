# Smart Operator Assistant, Feature Set

Phone first companion for CAT machine operators and technicians, plus an owner web
dashboard. The thesis: the operator's phone becomes the intelligence layer, so every
machine gets smart operator features, old non telematics units included.

This is the current feature set after the P1 (data and estimation), P2 (anomaly,
safety, maintenance, RAG), P3 (AR and model wiring) and P4 (app, Firebase, dashboard)
work. Items marked simulated or planned are not implemented end to end yet.

## 1. Operator app (Flutter, on device)

- Sign in and session. Loads the operator's role and vertical (construction or mining)
  and the matching app personality. Uses Firebase Auth when built with
  `--dart-define=USE_FIREBASE=true`; mock sign-in otherwise.
- Pre start safety gate. Seatbelt and operator facing camera checks before the app
  unlocks, with a hard block on failure. The checks are simulated with timers today;
  wiring them to the camera and telematics is planned.
- Task dashboard. Task cards with type, location and a live ML predicted time from
  /ml/estimate (weather and location aware), with seed ETAs as the offline fallback.
- Task detail. Shows the estimate, the per factor minutes (operator, heat, visibility,
  wet ground), safety advisories and a suggested best start time against the planner
  baseline.
- Active task and voice logging. Live elapsed timer plus tap to speak incident logging.
  On mobile, speech to text runs on device (sherpa-onnx Whisper tiny: English, Hindi
  and Tamil) and works offline after a one time model download. The web build uses
  browser speech recognition.
- Learning Hub. AR training that maps machine controls onto everyday objects
  (mouse to steering, bottle to throttle), running on the phone camera with a motion
  tracker, plus an AR field repair view. The Unity AR Foundation version lives in
  `ar/` and is not embedded yet.
- On device safety monitor. Camera based checks with a heuristic scorer today. P2's
  TFLite seatbelt and engine sound models (`ml/models/`) are ready to be wired in.
- Emergency SOS. Hold to send, with a multi hop relay shown step by step. The BLE
  transport is simulated in the UI today; BLE mesh is planned.
- Profile and skills passport. Operator identity, assigned machine, skill level and
  completed training with scores.
- Vertical adaptive UI. One code base switches task vocabulary, safety rules and theme
  between construction and mining.

## 2. Intelligence layer (Python backend and ML)

### 2.1 Task time estimation (P1)

- XGBoost model that predicts a task's real duration per operator, not a fleet mean.
  On held out operators it lowers error by about 80 percent versus the planner baseline
  (MAE roughly 5.5 minutes versus 28 minutes).
- Weather and location aware. Given a site or lat and lon plus a start time, it uses the
  live Open-Meteo forecast (free, no key, nothing stored) and falls back to typical site
  weather when offline.
- Conditions engine. Converts weather into work conditions: heat stress breaks (WBGT),
  visibility and wet ground. On tasks hit by heat, fog or rain the error is about
  7.8 minutes versus 23.0 minutes for a weather label only model.
- Explains itself. The response returns the estimate plus per factor minutes, safety
  advisories and an optional suggested best start time in the next 24 hours.
- Endpoint: POST /ml/estimate. The first fields are the original contract; all weather
  and location fields are optional.

### 2.2 Anomaly, safety and maintenance (P2)

- Unusual behavior and idling detection (POST /ml/anomaly): excessive idle, unsafe
  operation, fuel anomaly and overheat risk, with human readable reasons and a primary
  type for the closed training loop.
- Safety alert prediction (POST /ml/safety) and predictive maintenance (POST
  /ml/maintenance) over the same session payload.
- Shared machine catalog. Per machine speed limits and fuel norms come from one source
  that both the data generator and the detector use, so the rules agree with the
  generated labels 100 percent.

### 2.3 Synthetic data (P1)

- Generator for sites, machines, operators, task standards, telematics (Dataset A) and
  tasks (Dataset B), both verticals, seeded and validated against the frozen schemas
  before writing.
- On the default run: 20,000 tasks and 40,000 telematics rows with realistic prevalence
  (safety alerts about 7 percent, anomalies about 11 percent).
- Endpoint: POST /sim/generate generates rows in the schema and returns the row count
  plus a sample (up to 20 rows); the full CSVs come from `ml/generators/generate.py`.

### 2.4 Manual Q&A (P2)

- POST /rag/query and POST /voice/nlu answer from the machine manuals in
  `ml/data/manuals/` with citations (Gemini when a key is set, otherwise the best
  matching manual section).

## 3. Owner and fleet dashboard (Flutter web)

- Fleet status, safety incident feed, idle and anomaly trends and training compliance,
  including non telematics machines fed by operator phones.
- Fleet data comes from GET /ml/fleet (a stable snapshot aggregated from generated,
  labelled telematics: alerts, anomalies, maintenance due, phone fed machines);
  incidents and training come from Firestore, with seed data as the fallback. The web build opens straight into the
  dashboard (anonymous Firebase sign in).

## 4. How the app and intelligence layer connect

- The app ships a tolerant ML client (Dio) for /ml/estimate, /ml/fleet, /ml/anomaly and
  /rag/query with offline fallbacks, so a slow or missing backend never breaks a screen.
  The backend URL is set with `--dart-define=API_BASE_URL=...` (default
  http://localhost:8000).
- Offline. The task view falls back to seed ETAs and voice capture works on device.
  Incidents are written to Firestore when a connection is available; a persistent
  offline sync queue is planned.
- Current state. Task cards and task detail call /ml/estimate live and show the model's
  ETA, factors, advisories and best start. The backend deploys as one Docker image
  (root `Dockerfile`, which bakes the model) to Hugging Face Spaces or Render. /ml/anomaly
  is wired in the client but not yet called from a screen.

## 5. Verticals

- Construction: heterogeneous task list, pedestrian proximity, utility and clearance
  awareness, grade precision.
- Mining: cyclic tons and haul route focus, blind spot proximity, rollover and shift
  aware fatigue, haul road condition awareness.
