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

### 6.1 Dataset A — Machine Telematics Log (expanded from the organizer sample)
`Timestamp, MachineID, MachineType, Vertical, OperatorID, EngineHours, FuelUsed_L, LoadCycles,
IdlingTime_min, Speed_kmh, EngineTemp_C, HydraulicPressure, RPM, HarshEvents, ProximityWarnings,
HoursSinceBreak, AmbientTemp_C, SeatbeltStatus, FatigueScore, SafetyAlertTriggered, AnomalyFlag,
MaintenanceDue`
- Observed sample rule: **Unfastened seatbelt + high idling + low load cycles → Safety Alert.**
- Powers seatbelt compliance, idle/behavior detection, safety-alert prediction, predictive maintenance, fuel anomaly.

### 6.2 Dataset B — Task History (expanded from the organizer sample)
`TaskID, Vertical, TaskType, MachineType, MachineAge_yrs, MaterialType, TerrainSlope, Weather,
Temperature_C, WindSpeed, OperatorSkill, OperatorExpHours, LoadVolume, HaulDistance_m, TimeOfDay,
EstimatedTime_baseline, ActualTime`
- Features = {TaskType, Weather, OperatorSkill, MachineAge, …}; **target = ActualTime**.
- Observed pattern: experts finish under estimate; beginners + bad weather overrun. The model must beat the naive baseline.

### 6.3 Firestore Collections
`users, machines, tasks, incidents, telematics, training, behaviorFlags, sosEvents` — role-scoped by Security Rules.

### 6.4 Synthetic Data
A Python (NumPy + Faker) generator encodes the real relationships seen in the samples and emits
thousands of rows for **both verticals** in the exact schemas above — used to train models and to
populate the demo dashboard.
