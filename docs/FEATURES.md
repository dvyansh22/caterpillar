# Smart Operator Assistant, Feature Set

Phone first companion for CAT machine operators and technicians, plus an owner web
dashboard. The thesis: the operator's phone becomes the intelligence layer, so every
machine gets smart operator features, old non telematics units included.

This is the current, accurate feature set after the P1 (data and estimation), P2
(anomaly, safety, maintenance) and P3 (app and AR) work.

## 1. Operator app (Flutter, on device)

- Sign in and session. Firebase Auth resolves the operator's role and vertical
  (construction or mining) and loads the matching app personality.
- Pre start safety gate. Auto verifies seatbelt and operator facing camera before the
  app unlocks. Any failure hard blocks entry with a clear reason.
- Task dashboard. Task cards with type, location and a predicted time for the shift.
- Task detail. Shows the estimate and how it was reached (weather, skill, machine age)
  against the planner baseline.
- Active task and voice logging. Live elapsed timer plus tap to speak incident logging.
  Speech to text runs offline on device (sherpa-onnx Whisper, multilingual English,
  Hindi and Tamil), so it works with no signal.
- Learning Hub. AR training that maps machine controls onto everyday objects
  (mouse to steering, bottle to throttle) and an AR field repair view.
- On device safety monitor. Camera and sensor based checks, no extra hardware.
- Emergency SOS. BLE based beacon designed to work with no cellular signal.
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
  7.9 minutes versus 22.9 minutes for a weather label only model.
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
- Endpoint: POST /sim/generate returns fresh rows in the schema for demos and training.

## 3. Owner and fleet dashboard (Flutter web)

- Fleet status, safety incident feed, idle and anomaly trends and training compliance,
  including non telematics machines fed by operator phones.

## 4. How the app and intelligence layer connect

- The app ships a tolerant ML client (Dio) that targets /ml/estimate, /ml/anomaly and
  /rag/query with offline fallbacks, so a slow or missing backend never breaks a screen.
- Offline first. Safety detection, voice capture, SOS and the task view work with no
  network; work syncs when connectivity returns.
- Current state. The estimation model and its API are built and tested end to end (real
  XGBoost model, weather aware, verified against the backend). The Python backend is not
  yet hosted, so each task in the app shows a predicted time field from illustrative demo
  data today; the live /ml/estimate call is wired and ready to switch on once the backend
  is deployed with the ml package alongside it.

## 5. Verticals

- Construction: heterogeneous task list, pedestrian proximity, utility and clearance
  awareness, grade precision.
- Mining: cyclic tons and haul route focus, blind spot proximity, rollover and shift
  aware fatigue, haul road condition awareness.
