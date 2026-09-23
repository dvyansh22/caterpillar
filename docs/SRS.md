# Software Requirements Specification (SRS)
## Smart Operator Assistant for CAT Machinery

**Project:** Smart Operator Assistant — a phone-first intelligent companion for Caterpillar machine
operators and technicians (with an owner/supervisor web dashboard).
**Hackathon:** Caterpillar problem statement — *Smart Operator Assistant for CAT machinery*.
**Team size:** 4.
**Document status:** v1.0 (planning).

---

## 1. Introduction

### 1.1 Purpose
This document specifies the functional and non-functional requirements for the Smart Operator
Assistant: an end-to-end application that supports CAT machine operators throughout their workday —
improving **efficiency, safety, and training** — and works on **both telematics-equipped and legacy
non-telematics machines** across the **construction** and **mining** verticals.

### 1.2 Product Scope
- **Mobile app** (Android/iOS) for **operators** and **technicians**.
- **Web dashboard** for **fleet owners / supervisors** (mining = dispatcher).
- **Cloud AI backend** (FastAPI) for ML inference, RAG, and data synthesis.
- **On-device intelligence** (vision, voice, BLE) so safety works with no connectivity.
- **MVP focus:** the operator flow end-to-end for both verticals. Technician AR repair and the owner
  dashboard are secondary.

### 1.3 Core Innovation
Every Cat digital product (VisionLink, MineStar Detect, Cat Simulators) requires **Product Link
telematics hardware** or a VR rig, leaving old "dumb" machines invisible. This product makes the
**operator's phone the intelligence layer**, delivering smart-machine capability to *any* machine.
*"Caterpillar digitized the machine. We digitize the operator — on every machine, new or old."*

### 1.4 Actors / User Classes
| Actor | Description |
|---|---|
| Operator | Drives the machine; primary user; hands-busy, in-cab, noisy environment. |
| Technician | Diagnoses and repairs machines; uses AR repair + remote expert. |
| Fleet Owner / Supervisor | Oversees the fleet via web dashboard (mining variant: Dispatcher). |
| Admin | Manages users, machines, and assignments. |

### 1.5 Definitions
- **Telematics** — machine sensor log (see Data Requirements, Dataset A).
- **ETA** — ML-predicted task-completion time.
- **Vertical** — construction | mining (drives the whole app personality).
- **Gate** — the non-bypassable pre-start safety check screen.

---

## 2. Overall Description

### 2.1 Product Perspective
A new standalone system integrating **Firebase** (auth, database, storage, messaging) and a
**FastAPI** AI service, with **Unity AR** embedded in the Flutter app. No dependency on Caterpillar
hardware.

### 2.2 Operating Environment
- Phone in a cab mount; intermittent or **no connectivity**; outdoor, noisy, gloved use.
- Web dashboard on desktop browsers.

### 2.3 Constraints
- **Offline-first**; on-device inference must be lightweight.
- "Available or assumed data" permitted → synthetic datasets to the organizer schemas.
- No financial or credential actions; privacy-preserving.
- Buildable by a 4-person team.

### 2.4 Assumptions & Dependencies
- Operator has a phone + cab mount.
- Datasets are synthesized to the organizer-provided schemas.
- 3D models and machine manuals are sourced or simplified for the demo.

---

## 3. Functional Requirements
Priority: **M** = Must, **S** = Should, **C** = Could.

### 3.1 Authentication & User Management
- **FR-AUTH-1 (M):** Username/password login via Firebase Auth.
- **FR-AUTH-2 (M):** Resolve `role` + `vertical` from custom claims; route to the correct UI personality.
- **FR-AUTH-3 (M):** Role-based access (operator/technician/owner/admin) via Firestore Security Rules.
- **FR-AUTH-4 (S):** Admin manages users and the machine registry (`vertical`, `hasTelematics`, assignment).

### 3.2 Pre-Start Safety Gate
- **FR-GATE-1 (M):** Before app access, auto-verify **seatbelt** (from telematics data) and **operator-facing camera ON**.
- **FR-GATE-2 (M):** Any failed check hard-blocks entry with a clear reason; all-pass ⇒ proceed. *(Breathalyzer removed.)*

### 3.3 Task Dashboard & Time Estimation
- **FR-TASK-1 (M):** List task cards showing name/type, **ML-ETA**, and location for the operator's day.
- **FR-TASK-2 (M):** ETA is produced by the task-time ML model, not the naive baseline.
- **FR-TASK-3 (M):** Start Task → active-task view with elapsed time.
- **FR-TASK-4 (S):** Map view of task locations.

### 3.4 Voice Log / Incident Logging
- **FR-VOICE-1 (M):** During a task, tap-to-speak → transcribe (on-device) → save observation.
- **FR-VOICE-2 (M):** Stored as incident/observation records for later review (safety).
- **FR-VOICE-3 (S):** Multilingual and offline capture.

### 3.5 Real-Time Safety
- **FR-SAFE-1 (M):** On-device seatbelt + fatigue detection (camera, TFLite) during operation.
- **FR-SAFE-2 (S):** BLE proximity alerts between phones (workers/machines).
- **FR-SAFE-3 (C):** Acoustic engine-anomaly detection (mic → TFLite).
- **FR-SAFE-4 (M):** Incident logging with sensor snapshot + location.

### 3.6 SOS (BLE-based)
- **FR-SOS-1 (M):** Long-press SOS → BLE-broadcast emergency packet (operator, machine, GPS, severity).
- **FR-SOS-2 (M):** Nearby phones alert + re-broadcast (multi-hop mesh); a connected node relays to the cloud + push.
- **FR-SOS-3 (S):** Direction/proximity to victim via RSSI; attach last sensor snapshot / voice log.

### 3.7 Learning Hub (AR Training)
- **FR-LEARN-1 (M):** AR module maps everyday objects to controls (mouse → steering, bottle → throttle).
- **FR-LEARN-2 (M):** Stepped prompts + progress/score saved.
- **FR-LEARN-3 (S):** Closed loop — a behavior flag auto-assigns the matching micro-lesson.

### 3.8 AR Field Repair (Technician)
- **FR-REPAIR-1 (S):** AR exploded view + fault-highlighted part + animated repair steps.
- **FR-REPAIR-2 (C):** WebRTC tele-mentoring with live annotation.

### 3.9 AI / ML (Backend)
- **FR-ML-1 (M):** Task-time estimation (XGBoost) at `/ml/estimate`.
- **FR-ML-2 (M):** Unusual-behavior / anomaly detection (idling, unsafe patterns) at `/ml/anomaly`.
- **FR-ML-3 (S):** Safety-alert prediction, predictive maintenance, fuel anomaly.
- **FR-ML-4 (S):** Repair Q&A via RAG at `/rag/query`.
- **FR-ML-5 (M):** Synthetic data generator producing both-vertical rows in the given schemas.

### 3.10 Owner Dashboard (Web)
- **FR-DASH-1 (S):** Fleet view including non-telematics machines; incident feed; idle/anomaly trends.
- **FR-DASH-2 (C):** Mining dispatcher view (cycle time, queue, haul-road heatmap).

---

## 4. External Interface Requirements

### 4.1 User Interfaces
- Flutter Material UI; bottom navbar: **Task | Learning Hub | SOS | Profile**; vertical-adaptive theme.

### 4.2 Hardware Interfaces
- Phone camera, microphone, GPS, IMU (accelerometer/gyroscope), Bluetooth LE; cab mount. **No Cat hardware required.**

### 4.3 Software Interfaces / APIs
- Firebase (Auth, Firestore, Cloud Storage, Cloud Messaging, Cloud Functions).
- FastAPI service: `/ml/estimate`, `/ml/anomaly`, `/rag/query`, `/voice/nlu`, `/sim/generate`, `/signal`.
- LLM API (Gemini/Claude); OpenWeatherMap; Google Maps; Unity via flutter_unity_widget.

### 4.4 Communication Interfaces
- HTTPS/REST + WebSocket (signaling).
- BLE advertise/scan + Nearby Connections (fully offline peer-to-peer).

---

## 5. Non-Functional Requirements
- **Offline (M):** Login cache, safety detection, voice capture, SOS, and task view work with no network; a sync queue flushes on reconnect.
- **Performance (M):** On-device vision ≤ ~100 ms/frame; ETA/anomaly API responses < 1 s.
- **Safety (M):** Gate is non-bypassable; SOS is reliable and confirmable; alerts are unmissable.
- **Security (M):** Firebase token auth on every backend call; role-scoped rules; no PII in URLs.
- **Usability (M):** Hands-busy voice control; large touch targets; sunlight-readable.
- **Reliability / Scalability (S):** Stateless FastAPI on Cloud Run; retries on sync.
- **Portability (S):** Single Flutter codebase → Android / iOS / Web.

---

## 6. Data Requirements

**Schema v1.0 — frozen (owner: P1).** This section is the data contract. Machine-readable files are
in [`ml/data/schemas/`](../ml/data/schemas/). Changing a column requires sign-off from P2 and P4.
- Organizer column names are kept, so the raw sample CSVs are valid rows of this schema (new columns blank).
- Numeric columns carry a unit suffix. A missing value is written as an empty cell.
- All datasets share the keys `MachineID`, `OperatorID` and `SiteID` (one consistent fleet).
- Non-telematics machines (`DataSource=Phone`) leave the engine-sensor columns blank.

### 6.1 Dataset A — Machine Telematics Log (`telematics.csv`)
**Grain:** one row = one operating session of one machine. **Key:** `SessionID`.

| Column | Type | Unit / allowed values | Null? | Role |
|---|---|---|---|---|
| SessionID | str | `S000001` | no | key |
| Timestamp | datetime | `YYYY-MM-DD HH:MM:SS`, session start, site local | no | key |
| MachineID | str | `EXC001`, `HT012` (type prefix) | no | key |
| MachineType | enum | per vertical (§6.6) | no | feature |
| Vertical | enum | construction \| mining | no | feature |
| OperatorID | str | `OP1001` | no | key |
| SiteID | str | `SITE01` | no | key |
| DataSource | enum | Telematics \| Phone | no | feature |
| Latitude, Longitude | float | deg, session centroid | no | feature |
| SessionDuration_min | float | 30–480 | no | feature |
| EngineHours | float | h, cumulative | no | feature |
| HoursSinceService | float | h, 0–1000 | no | feature |
| FuelUsed_L | float | L per session | blank if Phone | feature |
| LoadCycles | int | 0–120 | no | feature |
| Payload_t | float | t, avg per cycle | no | feature |
| IdlingTime_min | float | min, ≤ SessionDuration_min | no | feature |
| AvgSpeed_kmh, MaxSpeed_kmh | float | km/h | no | feature |
| EngineTemp_C | float | °C, max in session, 70–120 | blank if Phone | feature |
| HydraulicPressure_bar | float | bar, avg, 150–350 | blank if Phone | feature |
| RPM | float | avg, 700–2200 | blank if Phone | feature |
| FaultCode | enum | §6.6 | blank = no fault or Phone | feature |
| SeatbeltStatus | enum | Fastened \| Unfastened (Unfastened if >10% of moving time) | no | feature |
| HarshEvents | int | count (phone IMU) | no | feature |
| ProximityWarnings | int | count (BLE) | no | feature |
| HoursSinceBreak | float | h, at session end | no | feature |
| FatigueScore | float | 0–1, max in session | no | feature |
| AmbientTemp_C | float | °C | no | feature |
| SafetyAlertTriggered | enum | Yes \| No | no | **target** |
| AnomalyFlag | enum | Yes \| No (Yes iff AnomalyType ≠ None) | no | **target** |
| AnomalyType | enum | None \| ExcessiveIdle \| UnsafeOperation \| FuelAnomaly \| OverheatRisk (primary type) | no | **target** |
| MaintenanceDue | enum | Yes \| No | no | **target** |

**Ground-truth rules** (the generator follows these, so the models should learn them). `idle_ratio = IdlingTime_min / SessionDuration_min`.
- **SafetyAlertTriggered:** p≈0.9 if Unfastened and idle_ratio > 0.4 and LoadCycles are in the bottom
  quartile for the machine type (organizer rule). p≈0.7 if Unfastened and (HarshEvents ≥ 3 or
  FatigueScore > 0.7). Otherwise 3%. Overall about 7%.
- **AnomalyType:**
  - idle_ratio > 0.5 → ExcessiveIdle.
  - HarshEvents ≥ 4, MaxSpeed above the machine type's speed limit, or ProximityWarnings ≥ 3 → UnsafeOperation.
  - FuelUsed_L / LoadCycles > 1.5× the norm (median fuel per cycle for that vertical + machine type, over rows with LoadCycles > 0) → FuelAnomaly.
  - EngineTemp_C > 110 → OverheatRisk.
  - If several apply, keep the most severe (UnsafeOperation > OverheatRisk > FuelAnomaly > ExcessiveIdle). Overall about 11%.
- **MaintenanceDue:** Yes if HoursSinceService > 500 (construction) or > 400 (mining), a FaultCode is
  present, or EngineTemp_C > 105. Overall about 15%.
- **Fleet:** about 40% of machines have no telematics. Beginner operators idle more and have more harsh events.
- **Used for:** seatbelt compliance, idle/behavior detection, safety-alert prediction, predictive maintenance, fuel anomaly.

### 6.2 Dataset B — Task History (`tasks.csv`)
**Grain:** one row = one completed task. **Key:** `TaskID`.

| Column | Type | Unit / allowed values | Null? | Role |
|---|---|---|---|---|
| TaskID | str | `T000001` | no | key |
| Date | date | `YYYY-MM-DD` | no | key |
| Vertical | enum | construction \| mining | no | feature |
| SiteID, MachineID, OperatorID | str | join keys | no | key |
| TaskType | enum | per vertical (§6.6) | no | feature |
| MachineType | enum | per vertical (§6.6) | no | feature |
| MachineAge_yrs | float | 0–20 | no | feature |
| MaterialType | enum | per vertical (§6.6) | no | feature |
| TerrainSlope_deg | float | 0–25 | no | feature |
| Weather | enum | Sunny \| Cloudy \| Rainy \| Windy \| Dusty | no | feature |
| Temperature_C | float | °C | no | feature |
| WindSpeed_kmh | float | 0–60 | no | feature |
| OperatorSkill | enum | Beginner \| Intermediate \| Expert | no | feature |
| OperatorExpHours | float | 0–20000 | no | feature |
| LoadVolume_m3 | float | m³ | no | feature |
| HaulDistance_m | float | m, 0 for non-haul tasks | no | feature |
| TimeOfDay | enum | Morning \| Afternoon \| Evening \| Night | no | feature |
| EstimatedTime_min | float | min, planner baseline from `task_standards` | no | baseline |
| ActualTime_min | float | min | no | **target** |

- **Ground-truth rule:** `ActualTime_min = EstimatedTime_min × skill × weather × beginner-in-bad-weather × age × slope × night × noise`.
  - skill: Expert 0.88–0.97, Intermediate 1.00–1.12, Beginner 1.15–1.35
  - weather: Rainy +10–20%, Windy +5–10%, Dusty +5%
  - beginner in bad weather: an extra +10% if Beginner and (Rainy or Windy)
  - age: +1.5% per year over 3
  - slope: +1% per degree over 5°
  - night: +8%
  - noise: lognormal, σ≈0.05
- The task-time model predicts `ActualTime_min` and must beat the naive `EstimatedTime_min` baseline (FR-TASK-2).

### 6.3 Firestore Collections
`users, machines, tasks, incidents, telematics, training, behaviorFlags, sosEvents` — role-scoped by Security Rules.

### 6.4 Synthetic Data
A Python (NumPy + Faker) generator (`ml/generators/generate.py`) encodes the real relationships seen in the samples and emits
thousands of rows for **both verticals** in the exact schemas above. The data is used to train models and to
populate the demo dashboard.
- **Output:** CSV, UTF-8, with a header row, written to `ml/data/synthetic/`. The default random seed is `42`.
- **Default volume:** about 20k telematics rows and about 10k task rows per vertical.

### 6.5 Reference Tables (shared keys)
The Firestore shapes for `machines` and `users` are **proposed to P4**, who owns the Firestore model.
- `sites.csv`: SiteID, SiteName, Vertical, Latitude, Longitude
- `machines.csv`: MachineID, MachineType, Model, Vertical, SiteID, HasTelematics (bool),
  MachineAge_yrs, EngineHours, LastServiceHrs
- `operators.csv`: OperatorID, Name, Vertical, SiteID, OperatorSkill, OperatorExpHours
- `task_standards.csv`: Vertical, TaskType, StdTime_min, RefVolume_m3, RefHaulDistance_m. This
  table is the source of `EstimatedTime_min`, and of `baseline_minutes` in `/ml/estimate`.

### 6.6 Enumerations
| Enum | construction | mining |
|---|---|---|
| MachineType | Excavator, Wheel Loader, Dozer, Motor Grader, Backhoe Loader | Haul Truck, Hydraulic Shovel, Wheel Loader, Dozer, Drill |
| TaskType | Earth Excavation, Trenching, Material Loading, Grading, Demolition | Overburden Removal, Ore Loading, Load-Haul-Dump, Haul Road Maintenance, Bench Drilling |
| MaterialType | Soil, Clay, Sand, Gravel, Rock, Debris | Overburden, Ore, Coal, Blasted Rock |

`FaultCode` (both verticals): HYD_PRESSURE_LOW, ENGINE_OVERHEAT, AIR_FILTER_RESTRICTED,
FUEL_FILTER_CLOGGED, TRACK_TENSION, BRAKE_WEAR, TIRE_PRESSURE_LOW. FaultCode is also the key that
maps a fault to the part to highlight in AR repair (P3).
