# Smart Operator Assistant for CAT Machinery — Full Low-Level Design & Tech Stack

> Team: 4 people. Focus: most innovative solution, fully specified stack. This document is the
> **complete technical design** — every subsystem, the exact tech used, and what each piece does.
> Timeline/task-splitting is at the end; this is a design doc, not a schedule.

## As built vs. designed (status: September 2026)
This document is the original design. Where the implementation differs, this table is the
current truth. [`FEATURES.md`](FEATURES.md) lists what works today.

| Area | Designed | As built |
|---|---|---|
| Backend hosting | Cloud Run, Firebase ID-token auth, Admin SDK | One Docker image from the repo root (`Dockerfile`, bakes the ETA model) on Hugging Face Spaces / Render. Public API, CORS `*`, **no auth yet**. |
| Endpoints | `/ml/estimate`, `/ml/anomaly`, `/rag/query`, `/voice/nlu`, `/sim/generate`, `/signal` | Those minus `/signal` (planned), plus `/ml/safety`, `/ml/maintenance`, `/ml/fleet`, `/health` |
| Task-time model | XGBoost + OpenWeatherMap | XGBoost on log(actual/estimate) + **Open-Meteo** live weather → conditions engine (heat stress WBGT, visibility, wet ground), factors, advisories, best start (`ml/features/`) |
| Anomaly / idle / fuel | IsolationForest | XGBoost multi-class + rule reasons; safety + maintenance are binary XGBoost + rules; per-machine limits shared with the generator (`ml/generators/catalog.py`) |
| Seatbelt | BlazePose (pre-trained) | Trained MobileNetV3-Small classifier → `ml/models/seatbelt.tflite` (the app still runs a heuristic) |
| Fatigue | Face TFLite | Pre-trained face model (ML Kit / MediaPipe) + rule scorer (`ml/ondevice/fatigue.py`); no TFLite file |
| Acoustic | MFCC + INT8 CNN/AE | Log-mel autoencoder in the TFLite graph, float16 weights (`acoustic_anomaly.tflite`); synthetic training data |
| RAG | Qdrant/ChromaDB co-deployed, Gemini/Claude | In-memory Qdrant + multilingual sentence-transformers, TF-IDF fallback, Gemini only (`backend/app/core/rag.py`) |
| Synthetic data | → Firestore/BigQuery | CSVs in `ml/data/synthetic/` (git-ignored); `/sim/generate` returns a sample |
| App navigation / state | GoRouter, role-based routing | Riverpod `NavController` (phase/tab enums); no roles in the UI |
| Offline store | Isar + sync queue | Not implemented; Firestore writes are fire-and-forget, seed data as the fallback |
| Voice ASR | sherpa-onnx SenseVoice/Paraformer | sherpa-onnx **Whisper tiny** (en/hi/ta, one-time download) on mobile; browser speech on web |
| SOS / proximity (BLE) | flutter_blue_plus + Nearby Connections mesh | UI flow with a **simulated** relay; no BLE packages yet |
| Safety gate | seatbelt from data + camera | UI flow with **simulated** checks (timers) |
| AR | Unity via flutter_unity_widget | Camera + frame-differencing motion tracker in Flutter; Unity scripts in `ar/`, not embedded |
| Firebase | Auth/Firestore/Storage/FCM/Functions, custom-claim roles | Auth (email/password, anonymous on web) + Firestore + Storage rules; no FCM, no Functions, no claims set |

---

## 1. Context

Build an "intelligent companion" for CAT operators/technicians covering the required outcomes (task
dashboard, real-time safety, training hub, unusual-behavior detection, task-time estimation) **plus**
our differentiators (voice-first multilingual, AR training + AR field repair, vertical-adaptive UI,
owner dashboard, user management).

**Innovation thesis / the wedge:** Caterpillar's own products (VisionLink, MineStar Detect, Cat
Simulators) all require **Product Link telematics hardware** or expensive VR rigs, so the huge base
of **old non-telematics machines gets nothing**. Our system makes **the operator's phone the
intelligence layer**, delivering VisionLink/MineStar-class capability to *every* machine — old or
connected. Standout mechanic: a **closed loop** — detect unsafe/weak behavior → auto-assign AR
micro-training → re-measure (Cat keeps detection and training in separate silos).

---

## 2. System Architecture (layers)

```
┌───────────────────────────────────────────────────────────────────────────┐
│  CLIENTS                                                                     │
│  • Flutter mobile app (operator + technician)   • Flutter Web owner dashboard│
│  • Unity AR module (embedded in Flutter)                                     │
└───────────────┬───────────────────────────────────────────────┬────────────┘
                │ (Firebase SDK: Auth/Firestore/Storage/FCM)     │ (HTTPS/REST + WebSocket)
                ▼                                                 ▼
┌──────────────────────────────┐              ┌──────────────────────────────────┐
│  FIREBASE (BaaS)             │              │  PYTHON BACKEND (FastAPI on Cloud  │
│  • Auth + custom claims (RBAC)│◄────────────►│  Run) — the "AI brain"            │
│  • Firestore (app data)      │  Admin SDK   │  • /ml   task-time, anomaly, idle  │
│  • Cloud Storage (3D, media) │              │  • /rag  repair-manual Q&A         │
│  • Cloud Messaging (push)    │              │  • /voice NLU + LLM orchestration  │
│  • Cloud Functions (triggers)│              │  • /sim  synthetic telematics gen  │
│  • Security Rules            │              │  • /signal WebRTC signaling        │
└──────────────────────────────┘              └───────────────┬──────────────────┘
                                                               │
                          ┌────────────────────────────────────┼───────────────┐
                          ▼                    ▼                ▼               ▼
                    Vector DB           LLM API           ML models        External APIs
                    (Qdrant/Chroma)   (Gemini/Claude)   (XGBoost, TFLite)  (Weather, Maps)
```

**On-device (no network needed):** voice ASR (sherpa-onnx), seatbelt/fatigue vision (TFLite), IMU
safety, BLE proximity, acoustic anomaly (TFLite). **Cloud:** RAG repair Q&A, task-time/anomaly ML,
LLM companion reasoning, dashboard aggregation, tele-mentoring signaling.

---

## 3. Master Tech Stack — what each piece is used for

| Layer | Technology | Used for |
|---|---|---|
| Mobile/Web UI | **Flutter (Dart)** | Single codebase: operator app, technician app, owner web dashboard |
| State mgmt | **Riverpod** | App state, DI, feature toggles per vertical |
| Navigation | **GoRouter** | Role-based routing (operator/technician/owner) |
| Local DB / offline | **Isar** (or Drift/SQLite) + Firestore offline persistence | Offline-first cache, sync queue |
| Auth | **Firebase Auth** + custom claims | Login, roles (operator/technician/fleet_owner/admin) |
| App database | **Cloud Firestore** | Users, machines, tasks, incidents, training progress, telematics summaries |
| File storage | **Firebase Cloud Storage** | 3D models (glTF/FBX), training videos, incident photos/audio |
| Push | **Firebase Cloud Messaging (FCM)** | Safety alerts, task assignments, training nudges |
| Serverless glue | **Cloud Functions** | Firestore triggers (e.g. incident → notify owner) |
| AR engine | **Unity 2022.3 LTS + AR Foundation** (ARCore/ARKit) | AR field repair (exploded parts, animated fix), AR training scenarios |
| AR ↔ Flutter bridge | **flutter_unity_widget** (or flutter_embed_unity) | Embed Unity AR view + message passing (fault code → highlight part) |
| Offline voice ASR | **sherpa-onnx** (`sherpa_onnx`) w/ SenseVoice/Paraformer multilingual | Hands-free, offline, regional-language voice input |
| Offline TTS | **sherpa-onnx TTS** / `flutter_tts` | Spoken responses & safety warnings |
| Wake word | **Picovoice Porcupine** (`porcupine_flutter`) | "Hey CAT" hotword, hands-busy activation |
| Cloud STT (fallback) | **Google Cloud STT** / Whisper API | Higher-accuracy transcription when online |
| LLM companion | **Gemini 2.x** (or Claude) via FastAPI | Natural-language help, task Q&A, repair guidance |
| RAG | **FastAPI + Qdrant/ChromaDB + sentence-transformers** | Ground LLM answers in machine manuals/SOPs |
| On-device face/eye | **face_detection_tflite** (MediaPipe/LiteRT, 478 landmarks, eye-open prob) | Fatigue/drowsiness detection |
| On-device pose | **BlazePose** (`pose_detection`) | Seatbelt-across-chest & posture detection |
| Camera | **camera** plugin / Google ML Kit | Frame capture for vision models, AR |
| Motion sensors | **sensors_plus** | Harsh accel/braking, rollover/impact, idle detection |
| Proximity | **flutter_blue_plus** (BLE RSSI) + **flutter_nearby_connections** (P2P) | Hardware-free worker/machine proximity alerts |
| Acoustic anomaly | Phone mic → **MFCC + INT8 TFLite CNN/autoencoder** | Abnormal engine-sound → predictive maintenance |
| Predictive ML | **XGBoost / scikit-learn** (served via FastAPI) | Task-time estimation, idle/anomaly, unusual-behavior scoring |
| Synthetic data | **Python (NumPy + Faker)** generator | "Assumed" fleet telematics history for ML + dashboard |
| Tele-mentoring | **flutter_webrtc** + STUN/TURN + data channel | Remote expert annotates junior's live AR/video feed |
| Maps/geo | **google_maps_flutter** + geofencing | Site map, task locations, proximity zones |
| Weather | **Open-Meteo API** (free, no key; live forecast, nothing stored) | Work conditions for task-time estimation: heat stress (WBGT), visibility, rain |
| Backend runtime | **FastAPI (Python)** on **Cloud Run** | ML, RAG, LLM orchestration, sim, signaling |
| Analytics/health | **Firebase Analytics + Crashlytics** | Usage, crash reporting |

---

## 4. Feature-by-Feature Low-Level Design

### 4.1 Voice-First Multilingual Companion *(hero)*
- **Flow:** Porcupine wake word → sherpa-onnx on-device ASR (offline, regional language) → intent
  parse. Simple commands (log incident, next task, start checklist) resolve **on-device**; complex
  Q&A ("how do I set grade?") → FastAPI `/voice` → Gemini (+ RAG) → sherpa-onnx TTS reply.
- **Safety gate:** while `sensors_plus` shows the machine moving, responses are audio-only; no
  screen-reading prompts.
- **Multilingual:** SenseVoice/Paraformer for on-device languages; Google STT fallback online for
  languages/accuracy the local model misses.

### 4.2 AR Field Repair — "X-ray the machine" *(hero add-on)*
- **Flow:** Camera → identify machine/model (QR sticker or ML Kit image label) → Unity loads the
  glTF model from Cloud Storage → **exploded-parts view**, animated step-by-step fix, torque specs.
- **Fault-driven:** a fault code (from telematics or manual entry) is passed Flutter→Unity via
  `flutter_unity_widget` messaging → Unity highlights the affected component and plays the repair
  animation. Repair steps text comes from the RAG service over the manual corpus.
- **Tele-mentoring:** `flutter_webrtc` streams the junior's camera to a senior tech, who draws
  annotations sent back over a WebRTC **data channel** and rendered as an overlay.

### 4.3 AR + AI Training Hub *(hero)*
- **Formats:** (a) AR scenario modules in Unity (e.g. practice a load cycle), (b) micro-video
  lessons from Cloud Storage, (c) quizzes → **skills passport** stored in Firestore.
- **Closed-loop adaptive training:** the anomaly/behavior service flags a weakness (e.g. excessive
  idling) → Cloud Function assigns the matching micro-lesson → FCM nudge → re-measure next shift.
  This is the flagship novel mechanic.

### 4.4 Daily Task Dashboard + Task-Time Estimation *(required)*
- **Dashboard:** Firestore `tasks` collection filtered by operator + date; map view via
  google_maps_flutter.
- **Estimation model:** XGBoost regressor, features = {machine type, task type, operator skill,
  material/soil, live weather + site location (Open-Meteo -> heat stress, visibility, wet ground; `ml/features/conditions.py`), historical durations}. Trained on the synthetic dataset;
  served at FastAPI `/ml/estimate`. Returns per-task ETA adapted to *this* operator, not a fleet mean.

### 4.5 Phone-as-Sensor Safety Suite *(required: seatbelt, proximity, incidents)*
- **Seatbelt:** dash-mounted phone cam → BlazePose detects belt line across torso → on-device only.
- **Fatigue:** face_detection_tflite eye-open probability + blink rate + head pose → drowsiness score.
- **Rollover/impact/harsh op:** sensors_plus accelerometer/gyro thresholds + z-score.
- **Proximity:** each phone advertises a BLE beacon ID and scans peers; RSSI → near/far zones;
  flutter_nearby_connections for richer P2P. Fully offline, no site radio, no Cat hardware.
- **Incident logging:** voice or button → captures GPS + sensor snapshot + optional photo/audio →
  Firestore `incidents` → Cloud Function → FCM to owner.

### 4.6 Unusual-Behavior / Anomaly Detection *(required)*
- **Idle:** engine-on (telematics/assumed) + no IMU motion beyond threshold ⇒ idle event.
- **Unsafe patterns:** harsh accel/decel/overspeed from IMU+GPS, scored by IsolationForest on
  telematics features at FastAPI `/ml/anomaly`.
- **Acoustic (novel):** mic → MFCC → INT8 TFLite model → abnormal engine sound → predictive-maint
  alert surfaced in-cab.

### 4.7 Vertical-Adaptive UI *(differentiator)*
- One app; a `vertical` config (construction/mining/paving/forestry) in Firestore Remote Config
  drives theming, task types, safety rules, and training catalog. Riverpod provides it app-wide.

### 4.8 Owner / Fleet Dashboard *(differentiator, must NOT clone VisionLink)*
- Flutter Web (same codebase). Aggregates fleet status, safety incidents, idle/anomaly trends,
  training compliance — **including non-telematics machines fed by operator phones**, which is the
  visibility VisionLink cannot provide without hardware. Charts via `fl_chart`.

### 4.9 User Management / RBAC
- Firebase Auth + **custom claims** = {operator, technician, fleet_owner, admin}. Firestore Security
  Rules enforce per-role read/write. Machine & model registry in Firestore; operators assigned to
  machines by owners.

---

## 5. Data Layer

### 5.0 Organizer-supplied sample datasets (ground truth — build to these schemas)

The organizers provided two sample tables. These lock our data model and confirm which features are
data-driven. Their few rows aren't enough to train models, so the `/sim` generator produces **more
rows in exactly these formats.**

**Dataset A — Machine Telematics Log** (one row per operating session):
`Timestamp, MachineID, OperatorID, EngineHours, FuelUsed_L, LoadCycles, IdlingTime_min,
SeatbeltStatus(Fastened|Unfastened), SafetyAlertTriggered(Yes|No)`
- Observed rule in the sample: **Unfastened + high idling + low load cycles → SafetyAlert=Yes.**
- Powers: seatbelt compliance, idle detection, unusual-behavior (low productivity), safety alerting;
  EngineHours → maintenance, FuelUsed → efficiency.

**Dataset B — Task History** (supervised set for time estimation):
`TaskID, TaskType(Earth Excavation|Trenching|Material Loading|Grading|Demolition), Weather(Sunny|
Rainy|Cloudy|Windy), OperatorSkill(Beginner|Intermediate|Expert), MachineAge_yrs,
EstimatedTime_min, ActualTime_min`
- Features = {TaskType, Weather, OperatorSkill, MachineAge}; **target = ActualTime**.
- Observed pattern: experts finish under estimate; beginners + bad weather overrun. The naive
  `EstimatedTime` is the baseline our XGBoost model must beat — a clean demo talking point.

**What's absent (and why it matters):** no GPS, proximity, audio, or camera fields. The provided
data represents the *connected machine*; our **phone-as-sensor** layer supplies exactly what's
missing (proximity, AR, acoustic, fatigue) — this validates the core thesis. Mining data is
generated in the same schema with mining task types (haul, load-haul-dump) since the sample is
construction/excavator-flavored.

### 5.1 Firestore schema (top-level collections)
- `users` {uid, role, vertical, orgId, assignedMachineIds, skillLevel}
- `machines` {id, model, vertical, hasTelematics(bool), fault codes, lastServiceHrs}
- `tasks` {id, machineId, operatorId, type, location(geo), scheduledStart, estDuration, status}
- `incidents` {id, machineId, operatorId, type, sensorSnapshot, mediaUrls, geo, ts}
- `telematics` {machineId, ts, engineHrs, fuel, idlePct, faultCodes, source(real|phone|sim)}
- `training` {userId, moduleId, status, score, assignedBy(auto|owner)}
- `behaviorFlags` {userId, machineId, type(idle/harsh/acoustic), severity, ts, linkedTrainingId}

### 5.2 Synthetic telematics generator (`/sim`)
- Python NumPy+Faker script generating realistic per-machine time-series (engine hrs, fuel burn,
  idle %, location tracks, fault-code injections) seeded from real Cat spec ranges. Writes CSVs to
  `ml/data/synthetic/` to (a) train ML models and (b) feed the owner dashboard (`/ml/fleet`).
  **This is how we satisfy "assumed data" without needing any dataset from Caterpillar.**

### 5.3 ML models
| Model | Type | Serving | Trained on |
|---|---|---|---|
| Task-time estimation | XGBoost regressor + conditions engine | FastAPI `/ml/estimate` | Synthetic history + simulated site weather |
| Anomaly / unsafe pattern | XGBoost multi-class + rules | FastAPI `/ml/anomaly` | Synthetic telematics |
| Safety alert / maintenance | Binary XGBoost + rules | FastAPI `/ml/safety`, `/ml/maintenance` | Synthetic telematics |
| Seatbelt | MobileNetV3-Small → TFLite | On-device | Seatbelt photos (from short videos) |
| Fatigue | Pre-trained face model + rule scorer | On-device | No training needed |
| Acoustic engine fault | Log-mel autoencoder → TFLite | On-device | Synthetic engine sounds |
| Repair Q&A | RAG (embeddings + Gemini) | FastAPI `/rag` | Machine manuals corpus |

### 5.4 Dataset expansion & ML-per-outcome (organizer data is only a seed)

The two given tables have too few columns/rows to train real models, so `/sim` **expands both** with
more columns and thousands of rows that preserve realistic relationships. Every "expected outcome" in
the problem statement gets a dedicated ML treatment.

> **Schemas: Dataset A v1.0, Dataset B v1.1** — units, enums, nullability, keys and ground-truth rules are defined in
> [`SRS.md` §6](SRS.md#6-data-requirements) and [`ml/data/schemas/`](../ml/data/schemas/). The lists
> below are the column names only.

**Dataset A — Telematics (one row per operating session):**
`SessionID, Timestamp, MachineID, MachineType, Vertical, OperatorID, SiteID, DataSource, Latitude,
Longitude, SessionDuration_min, EngineHours, HoursSinceService, FuelUsed_L, LoadCycles, Payload_t,
IdlingTime_min, AvgSpeed_kmh, MaxSpeed_kmh, EngineTemp_C, HydraulicPressure_bar, RPM, FaultCode,
SeatbeltStatus, HarshEvents, ProximityWarnings, HoursSinceBreak, FatigueScore, AmbientTemp_C,
SafetyAlertTriggered, AnomalyFlag, AnomalyType, MaintenanceDue` (last four = ML targets).
Rows with `DataSource=Phone` (non-telematics machines) leave the engine-sensor columns blank.

| Expected outcome | ML approach | Key features |
|---|---|---|
| Seatbelt compliance | Rule + trend classifier | SeatbeltStatus over time |
| Excessive idling | Rules + XGBoost (anomaly model) | IdlingTime, LoadCycles |
| Unsafe operation patterns | Classifier (Random Forest/XGBoost) | HarshEvents, MaxSpeed_kmh, ProximityWarnings |
| Safety-alert prediction | Binary classifier (target: SafetyAlertTriggered) | Seatbelt + Idling + Harsh |
| Predictive maintenance | Classifier/regressor (target: MaintenanceDue) | HoursSinceService, EngineTemp_C, RPM, HydraulicPressure_bar, FaultCode |
| Fuel-efficiency anomaly | Rules + XGBoost (`FuelAnomaly` class) | FuelUsed vs LoadCycles (shared per-type norms) |
| Fatigue | On-device vision → FatigueScore label + HoursSinceBreak | camera + shift length |

**Dataset B — Task history (one row per completed task):**
`TaskID, Date, Vertical, SiteID, MachineID, OperatorID, TaskType, MachineType, MachineAge_yrs,
MaterialType, TerrainSlope_deg, Weather, Temperature_C, WindSpeed_kmh, OperatorSkill,
OperatorExpHours, LoadVolume_m3, HaulDistance_m, TimeOfDay, EstimatedTime_min, ActualTime_min`
(target = **ActualTime_min**).
- **Task-time model = XGBoost regressor** predicting ActualTime_min. The app's task-card ETA (§16) is
  **this prediction**, not the naive baseline column. Demo point: our model beats `EstimatedTime_min`.

**Reference tables** (`sites`, `machines`, `operators`, `task_standards`) share the keys
`SiteID/MachineID/OperatorID`, so both datasets describe one consistent fleet. See SRS §6.5.

**Synthetic generation:** Python (NumPy + Faker) encodes the real relationships seen in the samples
(e.g. beginners ×1.15–1.35, plus extra time in rain / low visibility / heat; unfastened + high idle
→ alert) plus noise, generating both construction and mining rows in these exact schemas. Task
weather is simulated from per-site climate profiles. Output → CSVs in `ml/data/synthetic/` for
training and the dashboard.

---

## 6. Backend (FastAPI)
- Endpoints (as built):
  - `/health`, `/ml/estimate`, `/ml/anomaly`, `/ml/safety`, `/ml/maintenance`, `/ml/fleet`;
  - `/rag/query`, `/voice/nlu`, `/sim/generate`;
  - `/signal` (WebRTC signaling over WebSocket) is planned.
- Deployed as one Docker image from the repo root (Hugging Face Spaces / Render).
- *Designed, not yet built:* the **Firebase Admin SDK** and Firebase ID-token verification on every
  request. The API is public for now.
- RAG uses an in-memory Qdrant (TF-IDF fallback) and Gemini.

---

## 7. Offline-First & Sync
- *Designed:* Firestore offline persistence + Isar local cache; a **sync queue** flushes incidents,
  behavior flags, and task updates when connectivity returns. *As built:* no Isar or queue yet. The
  app falls back to seed data and voice capture works on device (job sites have poor coverage — big credibility
  point). All safety detection (vision/IMU/BLE/acoustic) runs fully on-device, so safety never
  depends on the network.

## 8. Security
- Firebase ID-token auth on all backend calls; Firestore Security Rules per role; Storage rules
  scope media to the owning org; TURN credentials short-lived; no PII in URLs.

## 9. Infra / DevOps
- Firebase project (Auth/Firestore/Storage/FCM/Functions). FastAPI containerized → **Cloud Run**.
  Qdrant on Cloud Run or managed. CI: GitHub Actions (build Flutter, deploy Cloud Run/Functions).
  Unity AR module built as an Android/iOS library embedded via flutter_unity_widget.

---

## 10. Team Split (4 people)
Superseded by [`EXECUTION_PLAN.md`](EXECUTION_PLAN.md) §1, which is authoritative:
- **P1 — Data & ML (Estimation):** data schemas, synthetic generator (`/sim`), task-time XGBoost (`/ml/estimate`).
- **P2 — Data & ML (Safety/Behavior):** anomaly/safety/maintenance/fuel models (`/ml/anomaly`), on-device TFLite, RAG (`/rag`).
- **P3 — AR + Model Integration:** Unity AR, flutter_unity bridge, TFLite + FastAPI clients in the app.
- **P4 — Flutter App + Backend Infra:** app shell/screens, auth, Firebase + Firestore model, SOS/BLE, offline sync, owner dashboard.

---

## 10.5 Vertical Use-Case Differentiation (Construction vs Mining)

Caterpillar itself splits these into two business segments — **Construction Industries** (infra,
building, forestry, quarry) and **Resource Industries** (mining, quarry, waste, material handling) —
because the operator's world differs fundamentally. This drives our vertical-adaptive UI (§4.7).

| Dimension | Construction | Mining |
|---|---|---|
| Site | Dense, dynamic, changes daily, pedestrians/trades on foot | Vast, remote, fixed haul roads, few on foot, harsh, 24/7 |
| Machines | Many small–mid types (excavator, dozer, backhoe, loader, grader, compactor, paver) | Few massive types (off-highway haul trucks, shovels, draglines, large loaders) |
| Operator work | Varied precision tasks (dig/grade/lift/compact/pave) | Repetitive load–haul–dump cycles, endurance |
| Top hazards | Struck-by (pedestrians), falls, overhead power lines, buried utilities | Haul-truck blind spots, rollover on grade, haul-road traffic, fatigue, rockfall |
| Connectivity | Usually near cellular | Often no signal → offline-first mandatory |
| KPIs | Task completion, grade accuracy | Cycle time, tons moved, fuel/ton, haul-road efficiency |
| Regulator | OSHA | MSHA (stricter powered-haulage) |

**Feature adaptation per vertical:**
- **Task dashboard:** Construction = heterogeneous task list across a shifting site; Mining = cyclic tons quota + haul-route + queue position.
- **Safety:** Construction = pedestrian BLE proximity, overhead/buried-utility warnings, edge/fall; Mining = machine blind-spot proximity, rollover (IMU+slope), fatigue (shift-aware), pre-shift brake/tire checklist.
- **Task-time estimation:** Construction = per-task w/ soil+weather; Mining = cycle time / tons-per-hour w/ haul distance + road condition.
- **Unusual behavior:** Construction = idle in traffic, unsafe swing near people; Mining = haul-road overspeed, harsh loaded turns, queue idle.
- **Training:** Construction = machine versatility + grade precision; Mining = haul-road procedures, fatigue, MSHA, tire/brake.

**Vertical-unique "wow" use cases:**
- Construction: utility-strike prevention (AR buried-line overlay + overhead-clearance alert), AR grade-assist, multi-trade coordination.
- Mining: crowdsourced **haul-road condition map** (phones' IMU map rough patches → warn next truck), shift-length fatigue management, blast-zone geofencing, dispatch/queue optimization.
- Optional bridge vertical: **Quarry/Aggregates** (load-weighing, crusher-feed coordination, dust) — Cat lists it under *both* segments, so it's a natural expansion.

**Config-driven implementation (§4.7):** a `vertical` value in Firestore Remote Config swaps task
vocabulary, KPI set, safety rule pack, checklist templates, training catalog, and machine registry —
one codebase, distinct personalities.

## 11. Verification (end-to-end demo path)
1. Log in as operator → vertical-adaptive dashboard shows today's tasks with **ML ETAs**.
2. Dash-mount phone → live **seatbelt + fatigue** detection; trigger a **BLE proximity** alert with a second phone.
3. Say a command in a regional language → **offline voice** logs an incident; ask a repair question → **RAG** answer spoken back.
4. Point at a machine → **Unity AR** exploded view + animated fix; start **WebRTC tele-mentoring**, remote annotation appears.
5. Force an **idle/harsh** event → **behavior flag** auto-assigns an **AR micro-lesson** (closed loop) → FCM nudge.
6. Log in as owner (Flutter Web) → fleet view aggregates the above **including the non-telematics machine**.
- Tests: unit tests for ML endpoints (pytest), Flutter widget tests, and a scripted demo dataset from `/sim`.

---

## 12. User Personas & Day-in-the-Life Journeys

Five personas across the two locked verticals (Construction + Mining). Each shows where the app
touches their day — these anchor screen design and feature priority.

### P-A — Construction Operator ("Arjun", excavator/backhoe, urban site)
- **Context:** Runs 2–3 machine types across a changing site; works near other trades on foot;
  precision matters (digging to grade near buried utilities).
- **Goals:** Finish assigned tasks accurately, avoid hitting people/utilities, log issues fast.
- **Pains:** No idea of buried lines; struck-by risk with ground crew; unclear task sequence; older
  machine with no screen/telematics.
- **Journey:** Clock in → app shows **today's task list** on a site map with ETAs → mounts phone,
  runs **pre-op checklist by voice** → **seatbelt + fatigue** monitoring on → starts digging; app
  **AR-overlays buried utility lines** and warns on **overhead clearance** → a laborer walks close,
  **BLE proximity alert** buzzes → hits an unknown fault, asks by voice → **RAG repair answer**, or
  escalates to **AR field repair / tele-mentor** → logs a near-miss **incident by voice** → end of
  shift, **coach replay** flags an unsafe swing → **AR micro-lesson** auto-assigned.

### P-B — Mining Haul-Truck Operator ("Bala", off-highway truck, remote pit)
- **Context:** Repetitive load–haul–dump cycles, 10–12h shifts, no cellular, huge blind spots.
- **Goals:** Hit tons quota safely, stay alert, avoid haul-road hazards and light-vehicle collisions.
- **Pains:** Fatigue; blind spots crushing pickups; rough haul roads causing rollovers; idle time in
  loading queue killing fuel/ton.
- **Journey:** Shift start → **cyclic dashboard**: tons target, assigned haul route, queue position →
  **brake/tire pre-shift checklist** → drives; **fatigue detection** escalates warnings by shift
  length → **machine-to-machine blind-spot proximity** alerts → app **maps haul-road roughness** from
  IMU and warns of a bad patch reported by an earlier truck → **overspeed / harsh loaded-turn**
  flagged → all captured **offline**, syncs at the crib hut → supervisor sees cycle-time + safety.

### P-C — Field Technician ("Chandran", serves both verticals)
- **Context:** Travels between machines/sites to diagnose and repair; mix of old and connected units.
- **Goals:** Diagnose fast, fix right the first time, avoid a second trip.
- **Pains:** Unfamiliar model/part; manuals scattered; no senior on site.
- **Journey:** Gets an **FCM alert** (fault code or acoustic anomaly flagged) → opens **AR field
  repair**: point at machine → exploded parts + fault-highlighted component + torque specs →
  step-by-step animation → stuck, starts **WebRTC tele-mentoring**, senior annotates live view →
  marks repair done, updates machine record.

### P-D — Construction Fleet Owner / Site Manager ("Deepa")
- **Context:** Runs a mixed fleet incl. non-telematics machines; accountable for safety + productivity.
- **Goals:** See everything, prove safety compliance, cut idle/rework.
- **Pains:** Old machines are invisible to VisionLink; safety incidents surface late.
- **Journey:** **Web dashboard**: fleet map incl. **non-telematics machines fed by operator phones**
  → safety-incident feed, idle/anomaly trends, **training-compliance** view → assigns tasks/operators
  → gets pushed the day's near-misses.

### P-E — Mine Supervisor / Dispatcher ("Eswar")
- **Context:** Coordinates trucks/shovels for throughput; safety-critical, MSHA-regulated.
- **Goals:** Maximize tons/hour, minimize queue idle, zero collisions.
- **Pains:** Queue congestion, haul-road degradation, fatigue events mid-shift.
- **Journey:** **Dispatcher view**: live cycle times, queue lengths, **haul-road condition heatmap**,
  fatigue-risk roster → rebalances routes → reviews shift safety + throughput report.

---

## 13. Deep Per-Vertical Feature List

For each feature: **[C]** = construction behavior, **[M]** = mining behavior, with concrete
screens/data. Shared plumbing is in §3–§9.

### 13.1 Task Dashboard
- **[C]** Heterogeneous task cards (dig-to-grade, load truck, compact, lift) pinned on a **site map**;
  each with ETA (§4.4), machine assignment, priority. Data: `tasks{type, geo, estDuration}`.
- **[M]** Cycle-oriented: **tons-target gauge**, assigned **haul route** polyline, **queue position**
  at loader, cycles completed vs target. Data: `tasks{tonsTarget, routeId, cycleCount}`.

### 13.2 Task-Time Estimation
- **[C]** Per-task duration from {machine, task type, soil/material, weather, operator skill}.
- **[M]** **Cycle time & tons/hour** from {haul distance, road condition, grade, payload, weather};
  predicts shift throughput and flags when quota is at risk.

### 13.3 Safety Suite
- **[C]** Pedestrian **BLE proximity** (workers carry the app/beacon); **AR buried-utility overlay**
  + **overhead power-line clearance** alert; edge/fall-zone geofence; seatbelt + fatigue.
- **[M]** **Machine-to-machine & light-vehicle blind-spot proximity**; **rollover risk** (IMU tilt +
  slope + load state); **shift-aware fatigue** escalation; pre-shift **brake/tire checklist**;
  blast-zone geofence.

### 13.4 Unusual-Behavior Detection
- **[C]** Idle-in-traffic, unsafe swing near people, harsh bucket ops.
- **[M]** **Haul-road overspeed**, **harsh loaded turns** (rollover precursor), **queue idle** burning
  fuel; feeds the crowdsourced road map.

### 13.5 Acoustic Anomaly (novel, both)
- Mic → MFCC → TFLite → abnormal engine/hydraulic sound → predictive-maintenance flag. **[M]** also
  listens for tire/brake distress on haul roads.

### 13.6 Training Hub (closed-loop)
- **[C]** Machine-versatility modules + **AR grade-assist** practice + precision scoring.
- **[M]** **Haul-road procedure** sims, **fatigue-management** & MSHA modules, tire/brake inspection.
- Both: behavior flag (§13.4) → auto-assigned **AR micro-lesson** → re-measure.

### 13.7 AR Field Repair (technician, both)
- Exploded parts, fault-highlighted component, animated steps, tele-mentoring. Model library scoped
  by vertical (mid machines vs mega machines).

### 13.8 Voice Companion (both)
- Multilingual, offline, safety-gated. **[C]** varied task/checklist commands; **[M]** cycle logging,
  fatigue check-ins, hazard call-outs — critical where there's no cellular.

### 13.9 Vertical-Unique Signature Features
- **[C]** Utility-strike prevention (AR buried-line + overhead clearance) — the construction hero.
- **[M]** **Crowdsourced haul-road condition heatmap** (every phone's IMU maps rough/dangerous
  patches → warns the next truck + feeds dispatcher) — the mining hero.

### 13.10 Owner / Supervisor View
- **[C]** Site manager: fleet map (incl. non-telematics), incident feed, idle/rework, training
  compliance.
- **[M]** Dispatcher: live cycle times, queue lengths, **haul-road heatmap**, fatigue roster,
  throughput vs quota.

### 13.11 Shared: User Management
- Roles operator/technician/owner(+dispatcher)/admin via Firebase custom claims; machine registry
  tags each machine with its `vertical` so the app auto-loads the right personality (§4.7).

---

## 14. Novelty / Competitive Map (vs Caterpillar's own products)

The umbrella novelty: **every Cat digital safety/telematics product requires Product Link hardware or
a VR rig; ours needs only the operator's phone — so it works on the huge base of old non-telematics
machines Cat's tools can't reach.** Feature-by-feature:

| Our feature | Closest Cat product | What Cat does today | What's new in ours |
|---|---|---|---|
| Owner/fleet dashboard | **VisionLink** | Full fleet view, but only for telematics-equipped machines | Aggregates **non-telematics machines via operator phones** — visibility Cat literally can't give without hardware |
| Idle / behavior detection | VisionLink (idle segmentation, Operator Coaching) | Post-hoc, cloud, telematics-based | **On-device, real-time, in-cab**, hardware-free; adds acoustic |
| Proximity / collision | **MineStar Detect** (Proximity Awareness) | Powerful, but needs on-machine hardware + mining-only | **Phone-to-phone BLE P2P**, no site radio/hardware; also covers **construction pedestrians** |
| Seatbelt / fatigue | MineStar **Driver Safety System** | In-cab camera **hardware** | Uses the **operator's own phone camera** (TFLite) — zero install cost |
| Incident capture | MineStar (capture/playback) | Telematics-equipped machines | **Voice + auto sensor snapshot** on *any* machine, offline |
| Operator training | **Cat Simulators (Simformotion)** | VR headset / motion rig, off-site, costly | **Phone AR in the field**, cheap/scalable, **+ closed-loop adaptive assignment** |
| AR field repair | — (Cat has VR *training*) | No AR field-repair product | **Fully new**: exploded parts, fault-highlighted, animated fix on a phone |
| Remote assistance | Dealer remote troubleshooting | Expert-to-machine data, not visual | **AR tele-mentoring**: senior annotates junior's live view |
| Voice companion | — | Screen/dashboard-first tools | **Voice-native, offline, multilingual**, safety-gated |
| Task-time estimation | VisionLink productivity | Fleet-level analytics | **Per-operator, environment-adjusted, task/cycle-level prediction** |
| Haul-road condition map | — | Not crowdsourced from phones | **New**: phones' IMU crowdsource a live roughness/hazard heatmap |
| Utility-strike prevention | — | Not in operator tools | **New**: AR buried-line overlay + overhead-clearance alert |
| Detect → train → re-measure | Detection & training are **separate** Cat products | Two silos | **New closed loop** connecting them |

Positioning line: *"Caterpillar digitized the machine. We digitize the operator — on every machine,
new or old, for the price of a phone."*

---

## 15. Demo Storyboard (judge-facing narrative, both verticals in one story)

**Scene 0 — The hook (15s):** "Most machines on a real site are old and 'dumb' — invisible to
VisionLink and MineStar because they have no Cat hardware. Watch us bring the full smart-operator
experience to them with nothing but a phone."

**Scene 1 — Construction operator logs in:** app detects the machine's `vertical=construction` and
loads that personality → **task dashboard** on a site map with **ML ETAs**.

**Scene 2 — Live safety (the wow burst):** phone on dash → **seatbelt + fatigue** detection on screen
→ a teammate with the app walks up → **BLE proximity alert** fires → operator starts digging → **AR
buried-utility line** appears in the camera view with an overhead-clearance warning.

**Scene 3 — Voice + repair:** operator asks a question **in a regional language, offline** → spoken
**RAG** answer → a fault code appears → **AR field repair** exploded view highlights the part and
animates the fix → operator taps **tele-mentor**, a "senior" annotates the live view.

**Scene 4 — Same app, mining mode:** switch to a haul-truck operator → UI flips to **tons quota + haul
route + queue** → **blind-spot proximity** alert → **shift-aware fatigue** warning → the **crowdsourced
haul-road heatmap** warns of a rough patch an earlier truck reported. (All working **offline**.)

**Scene 5 — The closed loop:** a **harsh loaded-turn** gets flagged → the system **auto-assigns an AR
micro-lesson** and pushes a nudge. "Detection and training, finally connected."

**Scene 6 — The owner/dispatcher payoff:** open the **web dashboard** → fleet map shows every machine
**including the non-telematics one**, safety feed, idle/throughput, training compliance, haul-road
heatmap. The "aha": *this data didn't exist before, because these machines had no hardware.*

**Scene 7 — Close:** *"One phone. Every machine. Every vertical. That's the Smart Operator Assistant."*

---

## 16. Implementation User Flow (operator app — as dictated by the team)

This is the concrete screen-by-screen build spec for the MVP.

1. **Login screen** — username + password (Firebase Auth). Auth resolves the operator's `role` and
   `vertical` (mining/construction) via custom claims → routes to the matching UI personality (§4.7).

2. **Pre-start safety gate** (hard block — cannot proceed until all pass):
   - ✅ **Seatbelt** — verified from the telematics dataset `SeatbeltStatus` (§5.0).
   - ✅ **Operator-facing camera ON** — permission + liveness check (front camera active for fatigue).
   - *(Breathalyzer removed.)*
   - Checks are **auto-verified by the software** against the data/sensors; any fail ⇒ operator is
     locked out of the app with a clear reason. Passing all ⇒ continue.

3. **Landing page** — brief welcome, then defaults to **Tasks**. Persistent **bottom navbar:**
   **Task | Learning Hub | SOS | Profile**.

4. **Task tab** — list of **task cards**, each showing: task name/type, **ML-estimated time** (§5.4
   prediction, not the naive baseline), and **location**. Tap a card → **Start Task**.
   - During an active task: **Voice Log** button → operator taps and speaks what they notice →
     transcribed (sherpa-onnx) and saved as an **incident/observation log** for later use (safety).

5. **Learning Hub tab** — **AR-based training** modules (§18).

6. **SOS tab/button** — BLE emergency beacon (§17).

7. **Profile tab** — operator identity, assigned machine, skill level, training/skills passport.

---

## 17. SOS Button — BLE-based Design (works with no cellular)

**Problem:** remote sites often have no signal, so SOS can't rely on the internet. Solution: a
**hardware-free, offline-first emergency beacon with multi-hop relay.**

**How it works:**
1. Operator taps **SOS** (or long-press to avoid accidental triggers).
2. The phone starts **BLE advertising** an SOS packet: `{operatorId, machineId, timestamp,
   lastKnownGPS, severity}` (via `flutter_blue_plus` advertising + `flutter_nearby_connections`).
3. **Nearby phones** (other operators/supervisors in BLE range ~10–100 m) receive it, immediately
   **show a full-screen alert + direction/RSSI proximity** to guide responders, and **re-broadcast**
   it (store-and-forward mesh) so it hops beyond the origin's range.
4. **Any node with connectivity** forwards the SOS to the cloud → Firebase writes an `sosEvents`
   record → **FCM** pushes to the supervisor/dispatcher dashboard.
5. **Fallback:** if the originating phone itself has signal, it also sends directly to the cloud in
   parallel. Auto-attach the latest sensor snapshot + last voice log.

**Why it's strong:** it reuses the same BLE stack as proximity safety (§4.5), needs no site radio or
Cat hardware, and works in the exact dead-zone conditions where SOS matters most. Demo: 3 phones —
one triggers SOS, the other two light up and relay; a connected one posts it to the dashboard.

---

## 18. AR Training Demo — Everyday-Object Mapping (Learning Hub)

**Goal:** demo AR operator training **without a real cab or machine controls** by mapping machine
controls onto **everyday objects** the judges can see.

**Mapping for the demo:**
- **Steering / directional control → a computer mouse.**
- **Throttle / thrust control → a water bottle.**
- (Extendable: pedal → book, lever → pen, etc.)

**How it works (Unity AR Foundation + image/object tracking):**
1. Unity is pre-trained with reference images of the mouse and bottle (AR Foundation tracked images /
   object references).
2. When the camera detects the object, Unity anchors a **3D label + animated arrow overlay** naming
   it as the machine control ("Steering — turn left/right", "Throttle — raise to accelerate").
3. The lesson **steps through prompts** ("increase throttle"): the trainee performs the gesture with
   the everyday object; step completes on a simple detection (object moved/rotated/lifted) or a
   confirm tap. Progress + score saved to the `training` collection.
4. Ties into the **closed loop** (§4.3): a behavior flag (e.g. harsh throttle) can auto-assign the
   matching everyday-object micro-lesson.

**Why it's clever:** zero equipment, fully relatable, and it *proves the AR pipeline works* — the same
tech later loads real Cat-machine 3D models instead of a mouse/bottle. It's a demoable slice of the
full AR training vision.

---

# 19. Software Requirements Specification (SRS)

## 19.1 Introduction
- **Purpose:** specify requirements for the Smart Operator Assistant — a phone-first intelligent
  companion for CAT machine operators/technicians (+ owner web dashboard), working on both
  telematics and non-telematics machines across construction and mining.
- **Scope:** mobile app (operator + technician), web dashboard (owner/supervisor), a cloud AI
  backend, and on-device intelligence. MVP targets the operator flow (§16) end-to-end for both
  verticals; technician AR repair and owner dashboard are secondary.
- **Actors:** Operator, Technician, Fleet Owner/Supervisor (mining = Dispatcher), Admin.
- **Definitions:** *Telematics* = machine sensor log (§5.0 Dataset A); *ETA* = ML task-time
  prediction; *Vertical* = construction | mining; *Gate* = pre-start safety block (§16).

## 19.2 Overall Description
- **Product perspective:** new standalone system; integrates Firebase (BaaS) + a FastAPI AI service;
  Unity AR embedded in Flutter. No dependency on Cat hardware.
- **User classes:** Operators (primary, in-cab, hands-busy); Technicians (repair); Owners/Dispatchers
  (web, oversight); Admin (user/machine registry).
- **Operating environment:** Android/iOS phone in a cab mount; intermittent/no connectivity; noisy,
  outdoor, gloved use. Web dashboard on desktop.
- **Constraints:** offline-first; on-device inference must be lightweight; "assumed data" allowed;
  no financial/credential actions; hackathon-buildable by 4 people.
- **Assumptions & dependencies:** operator has a phone + mount; datasets are synthesized to the
  organizer schemas (§5.0/§5.4); 3D models & manuals are sourced/simplified.

## 19.3 Functional Requirements (ID · priority: M=must, S=should, C=could)

**Auth & User Management**
- FR-AUTH-1 (M): username/password login via Firebase Auth.
- FR-AUTH-2 (M): resolve `role` + `vertical` from custom claims; route to the correct UI personality.
- FR-AUTH-3 (M): RBAC — operator/technician/owner/admin scoped by Firestore Security Rules.
- FR-AUTH-4 (S): admin manages users, machines (with `vertical`, `hasTelematics`), assignments.

**Safety Gate**
- FR-GATE-1 (M): before app access, auto-verify **seatbelt** (Dataset A) + **operator-camera ON**.
- FR-GATE-2 (M): any failed check hard-blocks entry with a clear reason; all-pass ⇒ proceed.

**Task Dashboard & Estimation**
- FR-TASK-1 (M): list task cards {name/type, ML-ETA, location} for the operator/day.
- FR-TASK-2 (M): ETA comes from the task-time ML model (§5.4), not the naive baseline.
- FR-TASK-3 (M): Start Task → active-task view with elapsed time.
- FR-TASK-4 (S): map view of task locations (google_maps_flutter).

**Voice Log / Incident**
- FR-VOICE-1 (M): during a task, tap-to-speak → transcribe (sherpa-onnx) → save observation.
- FR-VOICE-2 (M): logs stored as incident/observation records for later review.
- FR-VOICE-3 (S): multilingual + offline capture.

**Real-time Safety**
- FR-SAFE-1 (M): on-device seatbelt + fatigue detection (camera, TFLite) during operation.
- FR-SAFE-2 (S): BLE proximity alerts between phones (workers/machines).
- FR-SAFE-3 (C): acoustic engine-anomaly detection (mic → TFLite).
- FR-SAFE-4 (M): incident logging with sensor snapshot + location.

**SOS (BLE)**
- FR-SOS-1 (M): long-press SOS → BLE-broadcast emergency packet (§17).
- FR-SOS-2 (M): nearby phones alert + re-broadcast (multi-hop); connected node relays to cloud + push.
- FR-SOS-3 (S): direction/proximity to victim via RSSI; attach last sensor snapshot/voice log.

**Learning Hub (AR training)**
- FR-LEARN-1 (M): AR module maps everyday objects to controls (mouse→steering, bottle→throttle) (§18).
- FR-LEARN-2 (M): stepped prompts + progress/score saved to `training`.
- FR-LEARN-3 (S): closed loop — behavior flag auto-assigns the matching micro-lesson.

**AR Field Repair (technician)**
- FR-REPAIR-1 (S): AR exploded view + fault-highlighted part + animated steps.
- FR-REPAIR-2 (C): WebRTC tele-mentoring with live annotation.

**AI/ML (backend)**
- FR-ML-1 (M): task-time estimation (XGBoost) served at `/ml/estimate`.
- FR-ML-2 (M): unusual-behavior/anomaly (idling, unsafe patterns) at `/ml/anomaly`.
- FR-ML-3 (S): safety-alert prediction, predictive maintenance, fuel anomaly (§5.4).
- FR-ML-4 (S): repair Q&A via RAG at `/rag/query`.
- FR-ML-5 (M): synthetic data generator producing both-vertical rows in the given schemas.

**Owner Dashboard (web)**
- FR-DASH-1 (S): fleet view incl. non-telematics machines; incident feed; idle/anomaly trends.
- FR-DASH-2 (C): mining dispatcher view (cycle time, queue, haul-road heatmap).

## 19.4 External Interface Requirements
- **UI:** Flutter Material; bottom navbar Task | Learning Hub | SOS | Profile; vertical-adaptive theme.
- **Hardware:** phone camera, mic, GPS, IMU, BLE; cab mount. No Cat hardware required.
- **Software/APIs:** Firebase (Auth/Firestore/Storage/FCM/Functions); FastAPI (`/ml/*`, `/rag`,
  `/voice`, `/sim`, `/signal`); LLM (Gemini/Claude); Open-Meteo; Google Maps; Unity via
  flutter_unity_widget.
- **Comms:** HTTPS/REST + WebSocket (signaling); BLE advertise/scan + Nearby Connections (offline).

## 19.5 Non-Functional Requirements
- **Offline (M):** login cache, safety detection, voice capture, SOS, and task view work with no
  network; sync queue flushes on reconnect.
- **Performance (M):** on-device vision ≤ ~100 ms/frame; ETA/anomaly API < 1 s.
- **Safety (M):** gate is non-bypassable; SOS is reliable and confirmable; alerts are unmissable.
- **Security (M):** Firebase token auth on every backend call; role-scoped rules; no PII in URLs.
- **Usability (M):** hands-busy voice control; large touch targets; readable in sunlight.
- **Reliability/Scalability (S):** stateless FastAPI on Cloud Run; retries on sync.
- **Portability (S):** single Flutter codebase → Android/iOS/Web.

## 19.6 Data Requirements
Per §5.0 (given schemas), §5.4 (expanded columns + ML-per-outcome), §5.1 (Firestore collections).

---

# 20. Four-Person Execution Plan

## 20.1 Roles & Ownership

| Person | Role | Owns |
|---|---|---|
| **P1** | Data & ML — Estimation | Synthetic **data generator** + schemas (§5.4); **task-time estimation** (XGBoost); eval; owns FastAPI `/ml/estimate` + `/sim`. |
| **P2** | Data & ML — Safety/Behavior | **Anomaly/idling/unsafe** (`/ml/anomaly`), **safety-alert**, **predictive maintenance**, **fuel anomaly**; prepares **on-device TFLite** models (seatbelt/fatigue/acoustic); RAG corpus + `/rag`. |
| **P3** | AR + Model Integration | **Unity AR** (everyday-object training §18, field repair); **flutter_unity bridge**; integrates **on-device TFLite** + **FastAPI clients** into the app (the "models in the app"). |
| **P4** | Flutter App + Backend | App shell, all **screens/navbar**, **auth/user mgmt**, **Firebase** (Firestore/Storage/FCM/rules), **safety gate**, **task dashboard**, **voice-log UI + sherpa-onnx**, **SOS/BLE + proximity**, offline sync. |

Pairing: P1↔P2 share the dataset; P3↔P4 share the app (P3 = AR + ML wiring, P4 = UI + backend).

## 20.2 Interface Contracts (agree in Phase 0 — this is what lets 4 people work in parallel)
1. **Data schemas** (P1/P2 → all): frozen column lists for Dataset A/B (§5.4).
2. **FastAPI contract** (P1/P2 → P3): endpoint paths + request/response JSON for `/ml/estimate`,
   `/ml/anomaly`, `/rag/query`. Stub responses first so P3 can integrate before models are ready.
3. **TFLite model spec** (P2 → P3): file + input/output tensor shapes for seatbelt/fatigue/acoustic.
4. **Unity↔Flutter protocol** (P3 ↔ P4): message names/payloads (load model, highlight part, lesson
   step, progress).
5. **Firestore data model** (P4 → all): collection shapes for `users/machines/tasks/incidents/
   telematics/training/sosEvents` (§5.1).

## 20.3 Work Breakdown (effort: S/M/L)

**P1 — Data & Estimation:** design expanded schemas (M) · build `/sim` generator, both verticals (L) ·
train + evaluate task-time XGBoost (M) · serve `/ml/estimate` (S) · seed demo dataset (S).

**P2 — Safety/Behavior ML:** anomaly/idling/unsafe models (L) · safety-alert + maintenance + fuel
models (M) · train/export **TFLite** seatbelt/fatigue/acoustic (L) · RAG corpus + `/rag` (M) ·
serve `/ml/anomaly` (S).

**P3 — AR + Integration:** Unity AR project + AR Foundation image/object tracking (L) · everyday-object
training module (L) · AR field-repair exploded/animated view (M) · flutter_unity bridge (M) ·
integrate TFLite + FastAPI clients into app (L) · (stretch) WebRTC tele-mentoring (C).

**P4 — Flutter + Backend:** app scaffold + nav + theming/vertical switch (M) · Firebase Auth + RBAC +
registry (M) · safety gate (S) · task dashboard + cards + start/active view (M) · voice-log +
sherpa-onnx (M) · **SOS BLE mesh + proximity** (L) · offline cache/sync (M) · owner web dashboard (M).

## 20.4 Milestones (phase-based; dates flexible)
- **Phase 0 — Foundations:** repo + Firebase project + Flutter scaffold + Unity skeleton; **freeze
  the 5 interface contracts (§20.2)**; stub FastAPI endpoints.
- **Phase 1 — Vertical slice:** login → gate → task list → start → voice log (P4); `/sim` v1 +
  task-time v1 (P1); anomaly v1 + one TFLite model (P2); AR object-tracking "hello world" (P3).
- **Phase 2 — Feature build-out:** SOS/BLE + proximity + on-device seatbelt/fatigue (P3/P4); all ML
  models trained/served (P1/P2); AR training + field repair (P3); owner dashboard (P4).
- **Phase 3 — Integration:** wire models into app end-to-end; both verticals; offline sync; closed loop.
- **Phase 4 — Demo polish:** seed demo data, rehearse storyboard (§15), prepare fallback mocks.

## 20.5 Risks & Mitigations
- **Unity↔Flutter friction (high):** start P3's bridge in Phase 0; keep a WebAR fallback.
- **On-device ML perf:** quantize (INT8); test on real devices early.
- **BLE across iOS/Android:** prototype SOS/proximity in Phase 1; Android-only fallback for demo.
- **Model accuracy from synthetic data:** encode real sample relationships; show model-vs-baseline.
- **Scope for 4 people:** MVP = operator flow + estimation + safety + SOS + AR training; repair/dash
  are stretch.

## 20.6 Definition of Done (demo checklist)
Login→gate→task with real ML ETA · voice incident log · live seatbelt/fatigue · BLE SOS relay across
3 phones · AR everyday-object lesson · both verticals switchable · owner dashboard shows a
non-telematics machine · runs offline for the safety path.

---

# 21. Repository Structure (monorepo — github.com/dvyansh22/caterpillar)

Owner-tagged folders so each of the 4 people has a clear home. Owner web dashboard is the Flutter
**web** build of `app/` (no separate frontend).

```
caterpillar/
├── README.md                  # overview, setup, team ownership map
├── .gitignore
├── docs/                      # SRS, architecture, plan (this document)
├── app/                       # P4 (UI/backend) + P3 (AR bridge, ML wiring) — Flutter
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/              # theme, nav (NavController), config, app_state
│   │   ├── features/          # auth, safety_gate, welcome, tasks, learning_hub, sos, profile,
│   │   │                      #   dashboard, shell (voice_log/, safety/ are empty placeholders)
│   │   ├── services/          # ml_client, voice, on_device, ar_bridge, auth + data repositories
│   │   └── data/              # models + mock/seed data
│   ├── assets/  ├── test/  └── pubspec.yaml
├── ar/                        # P3 — Unity AR Foundation scripts + PROTOCOL.md
├── backend/                   # P1/P2 — FastAPI AI service
│   ├── app/ (main.py, routers/{ml,rag,voice,sim}, core/{anomaly,risk,rag,ml_repo,config}, schemas/ empty)
│   ├── requirements.txt / -dev.txt / -deploy.txt └── Dockerfile (backend-only; use the root Dockerfile)
├── ml/                        # P1/P2 — data, models, shared ML code
│   ├── data/{raw,synthetic,schemas,manuals}
│   ├── generators/            # synthetic data generator, catalog, schema validator
│   ├── features/              # conditions engine + weather (Open-Meteo)
│   ├── serving/               # task-time estimator shared with the backend
│   ├── training/              # train_task_time, anomaly, risk, acoustic, seatbelt(_frames), augment, p2_dev_data
│   ├── ondevice/              # fatigue scorer + on-device model spec
│   ├── models/                # .joblib (git-ignored), .tflite + .json specs
│   ├── tests/  ├── notebooks/  └── requirements.txt
├── firebase/                  # P4 — rules, indexes, seed.js, firebase.json (functions/ placeholder)
├── deploy/, Dockerfile, render.yaml   # backend image for HF Spaces / Render
└── .github/workflows/         # CI
```

Scaffold = folders + per-module README (with owner + purpose) + minimal stub files
(`pubspec.yaml`, `requirements.txt`, `main.py`, `firestore.rules`, `.gitignore`, CI) so all four can
start immediately against the frozen contracts (§20.2).
