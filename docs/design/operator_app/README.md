# Handoff: Smart Operator Assistant — Operator App (MVP flow)

## Overview
The operator-facing mobile app for the Smart Operator Assistant (repo `dvyansh22/caterpillar`, Flutter app in `app/`). It covers the MVP flow in `docs/DESIGN.md` §16–18 and `docs/SRS.md` §3: login → pre-start safety gate → welcome → tabbed app (Task, Learning Hub, Profile), with a floating SOS button reachable from every tab. It supports two verticals (construction and mining): one codebase, and the vertical changes the accent color, task names and some copy.

## About the Design Files
The files in this bundle are **design references built in HTML**. They are prototypes that show the intended look and behavior, not production code to copy. Rebuild the design in the existing Flutter app (`app/lib/`) using its planned stack: Material 3, Riverpod for state, GoRouter for routes, and a `features/` folder layout as in `app/README.md`. Mock data and timers in the prototype stand in for Firebase, the `/ml/estimate` API, sherpa-onnx, BLE and Unity. Wire those up for real.

Open `Smart Operator Prototype.dc.html` in a browser to click through it (it needs `support.js` and `ios-frame.jsx` in the same folder). The logic class at the bottom of the file holds all state, mock data and copy.

## Fidelity
**High fidelity.** Colors, type sizes, spacing, radii and copy are final for the MVP. Recreate them closely using Flutter/Material widgets. The iPhone bezel is presentation only; the app targets Android and iOS alike (SRS §5, Portability).

---

## Global layout
- Canvas: 402 × 874 (iPhone). Safe area top 54px, bottom home-indicator area ~30px. In Flutter use `SafeArea`.
- App background `#FBF8F2`. Cards `#FFFFFF`. Secondary surface (nav bar, info rows) `#F3EFE6`.
- Font: system font (SF Pro on iOS, Roboto on Android — use the platform default `TextTheme`). Monospace for IDs (task IDs, operator IDs, timestamps, BLE packet).
- Tabular figures on all numbers (ETAs, timers, scores): `FontFeature.tabularFigures()`.
- Minimum touch target 44px; primary buttons are 56px tall (gloved, in-cab use, SRS §5 Usability).

### App bar (inside the tabbed app)
- Height 56, horizontal padding 16, bottom border 1px `rgba(29,27,22,0.10)`.
- Left: title, 20px regular (`Tasks` / `Learning Hub` / `Emergency SOS` / `Profile`). On SOS a 40×40 close (✕) button sits before the title.
- Right: vertical chip, 32px tall, radius 8, border 1px `#C9C4B8`, 13px/500 `#3D3A33`, with an 8px accent dot: `Construction` or `Mining`.

### Bottom nav bar (3 tabs)
- Background `#F3EFE6`, top border 1px `rgba(29,27,22,0.08)`, padding 8 top / 30 bottom (incl. safe area).
- Three equal columns: **Task** (clipboard-list icon), **Learning Hub** (graduation-cap), **Profile** (user). Icons are Lucide, 22px, stroke 1.8.
- Active item: a 64×32 pill (radius 16) behind the icon filled with the accent tint; label 12px/700. Inactive: no pill, label 12px/500. Text `#1D1B16`.
- Tapping Task returns to the active task if one is running, otherwise to the list.

### Floating SOS button (on every tab except SOS)
- 68×68 circle, fill `#B3261E`, 3px border `#FBF8F2`, shadow `0 6px 18px rgba(179,38,30,0.40), 0 2px 4px rgba(0,0,0,0.12)`.
- Position: 16px from the right, 100px above the bottom of the app area (just above the nav bar). Floats above content (a `Stack` or `floatingActionButton` with a custom location).
- Label `SOS`, 17px/700, letter-spacing 1px, white. Hover `#9C2019`, pressed `#8C1D18`.
- While an SOS is active: a second line `ACTIVE` (10px/600) appears, and a red halo pulses behind it (scale 1 → 1.55, opacity 0.5 → 0, 1.4s ease-out, infinite).
- Tap → opens the SOS screen and remembers the previous tab. ✕ on the SOS screen returns to that tab.
- Scroll content has 88px bottom padding so nothing is trapped under the button.

---

## Screens

### 01 Login
Purpose: username/password sign-in (FR-AUTH-1). The account decides role + vertical (FR-AUTH-2).
- Padding 40 top, 24 sides, 24 bottom; vertical gap 28.
- Logo tile 48×48, radius 12, accent fill, dark excavator glyph.
- Title `Smart Operator`, 32/40 regular, letter-spacing −0.2. Sub `Sign in to start your shift. Your role and site load from your account.` 15/22 `#5F5B52`.
- Fields: label 13/500 `#5F5B52` above; input 56px tall, radius 8, white fill, border 1px `#C9C4B8`, 17px text, 16px horizontal padding. `Username`, `Password` (obscured).
- Error line under the fields, 14px `#A1281C`: `Unknown username. Use arjun or bala.` / `Enter your password.`
- "Demo accounts": a 2-column grid of 64px-tall cards (radius 12, white). Selected card has a 2px `#1D1B16` border, others 1px `#C9C4B8`. `arjun · Construction · EXC004`, `bala · Mining · HT012`. Demo only; drop them in production.
- Primary button pinned to the bottom: `Sign in`, 56px tall, radius 28 (pill), accent fill, text `#1D1B16` 17/500. Hover: brightness 0.95.

### 02 Pre-start safety gate
Purpose: the check you can't skip (FR-GATE-1/2). Seatbelt comes from telematics `SeatbeltStatus`; the operator camera must be on.
- Kicker `PRE-START SAFETY GATE` 13/500, uppercase, letter-spacing 0.6, `#5F5B52`.
- Title changes with state: `Checking before you start` → `Ready to start` → `Machine locked`. 30/38.
- Sub: `These checks run automatically. You can’t skip them.` / on fail: `Fix the item below, then run the checks again.`
- Two check cards (white, radius 16, 16 padding, 1px border; on fail the border is `#E7A79F`). Left: a 44px status circle. Pending/busy: `#F3EFE6` with `···`. Pass: `#D7ECD6` with a `#1E5B24` check. Fail: `#FBE4E0` with a `#A1281C` ✕. Title 17/500, detail 14/20 `#5F5B52`.
  - Seatbelt — busy `Reading SeatbeltStatus for EXC004…`, pass `Fastened · session S000214`, fail `Unfastened. Fasten your seatbelt, then re-run the checks.`
  - Operator camera — pending `Waiting for seatbelt check`, busy `Starting the front camera…`, pass `On · face detected for fatigue monitoring`, fail `Front camera is off. Turn it on so fatigue monitoring can run.`
- Sequence: seatbelt runs for 1.2s, then the camera runs for 1.2s. If both pass, go to Welcome after 0.8s.
- Locked state (any fail): a banner (`#FBE4E0`, radius 12, lock icon, `#7A1D14` 14px) `App locked until every check passes.`, a primary button `Re-run checks`, and a text button `Sign out` (48px, `#5F5B52`).

### 03 Welcome
- Centered column, 24 padding. A 56px circle in the accent tint with a check in accent ink.
- `Good morning, {first}` 36/44. Sub 16/24 `#5F5B52`: `Safety checks passed on {machineId}. You have {n} tasks today at {site}.`
- Primary button `Go to tasks`. It also moves on by itself after 3s.

### 04 Tasks (list)
Purpose: today's task cards with the ML-predicted ETA (FR-TASK-1/2).
- 16 padding, 12 gap. Header: date `Wednesday, 23 September` 14px `#5F5B52`; summary `5 tasks · 5 h 6 min` 26/32; note `Times predicted by the task-time model for {first} on {machineId}` 13px.
- Task card (the whole card is a button): white, radius 16, 16 padding, 1px border `rgba(29,27,22,0.10)`. The active task's border uses the accent. Done cards drop to 60% opacity.
  - Left column: mono ID 12px + status chip (22px tall, radius 6, 12/500). Scheduled `#F3EFE6`/`#5F5B52`, In progress accent/`#1D1B16`, Done `#D7ECD6`/`#1E5B24`. Task type 18/500. Location with a map-pin icon, 14px `#5F5B52`.
  - Right: ETA badge, min-width 76, radius 12, accent tint fill, accent ink text. Number 28/32 weight 500 tabular, `min` 12/500 under it.
- Tap: active task → Active task screen; any other → Task detail.

### 05 Task detail
- Back link `‹ All tasks` (44px, pill hover `rgba(29,27,22,0.06)`).
- Mono ID 13px; type 30/38; location with pin 15px.
- Estimate panel: accent tint fill, radius 16, 20 padding, accent ink. `Estimated time` 13/500; `{eta} min` 52/60; explanation 14/20, e.g. `6 min longer than the planner baseline, based on rainy weather, your skill level and machine age.`
- Info list (white, radius 16, rows 14×16 with 1px dividers): Weather, Machine (`EXC004 · 4 yrs`), Operator skill, Planner baseline (`45 min`).
- Primary `▶ Start task`. Disabled (40% opacity) while another task is running: `Finish {id} before starting another task.` If the task is done: `Completed in {n} min.`

### 06 Active task
Purpose: elapsed time + voice log (FR-TASK-3, FR-VOICE-1/2).
- Timer card: `#1D1B16` fill, radius 16, 20 padding, text `#FBF8F2`. Status line with an accent dot `In progress · T002`; type 22/28; elapsed `MM:SS` 60/64 weight 300 tabular; `of ~51 min` 14px `#C9C4B8`; 6px progress bar (track `rgba(251,248,242,0.18)`, fill accent, radius 3).
- Voice log card: 72px round mic button (accent fill, dark icon; while recording it inverts to dark fill with accent icon, plus a pulsing accent halo). Title `Voice log` / `Listening…` 18/500. Sub `Tap and say what you notice. Works offline.` / `Describe what you see. Transcribed on the phone.`
- Observations list: header `Observations · {n}`; empty `Nothing logged yet on this task.`; each entry a white card (radius 12) with the text 15/22 and a meta line: mono time into the task, then `Synced` (construction) or `Queued, no signal` (mining, offline sync queue — DESIGN §7).
- Secondary button `End task` (56px, pill, 1px `#7A766C` border, transparent). Marks the task done with its real minutes and returns to the list.
- The prototype fakes a transcription after 2.6s. Replace that with sherpa-onnx.

### 07 Learning Hub
Purpose: AR lessons mapping everyday objects to controls (FR-LEARN-1/2/3, DESIGN §18).
- Intro 15/22 `#5F5B52`: `Practice machine controls in AR using objects you have on hand.`
- Lesson card (white, radius 16, 16 padding, gap 12). The auto-assigned lesson has an accent border.
  - Chip: `Assigned to you` (accent) / `Optional` (`#F3EFE6`) / `Completed` (`#D7ECD6`/`#1E5B24`). Right meta `4 steps · 3 min` or `Score 92`.
  - Title 20/500; note 14/20. The assigned lesson explains why: `Auto-assigned after a harsh-throttle flag on EXC004, 22 Sep.` (mining: `…harsh loaded-turn flag on HT012…`). This is the closed loop.
  - Mapping row (`#F3EFE6`, radius 10): `Water bottle → Throttle`, `Computer mouse → Steering`.
  - Button: assigned + not done = accent fill; otherwise an outline. `Start lesson` / `Practice again`.

### 08 AR lesson
- Back `‹ Learning Hub`.
- Camera area, 320px tall, radius 16, dark stripes (placeholder for the Unity AR view via flutter_unity_widget). Top-left label on an accent chip `Water bottle = Throttle`; bottom-right `Step 2 of 4` on `rgba(0,0,0,0.5)`.
- Running: a 4-segment progress bar (4px, radius 2, done = accent, rest `#E3DED2`); lesson title 14/500; prompt 24/32; primary `Step done`.
  - Throttle steps: `Hold the bottle upright where the camera can see it.` → `Tilt it forward slowly to raise the throttle.` → `Bring it back upright to return to idle.` → `Tilt forward, then ease back without a jerk.`
  - Steering steps: `Place the mouse flat where the camera can see it.` → `Turn it left to steer left.` → `Turn it right to steer right.` → `Center it and hold for two seconds.`
- Done: `{title} complete`, score `92 / 100` 56/64, `Saved to your skills passport.`, primary `Done`. The score is written to `training` and shows up in Profile.

### 09 SOS (opened from the floating button)
Purpose: BLE SOS with multi-hop relay (FR-SOS-1/2/3, DESIGN §17).
- Idle: intro `Sends your location over Bluetooth to nearby phones, which pass it on. Works with no cell signal.` A 240px hold-ring: track `#F1D9D4` 8px; progress stroke `#B3261E` 8px round cap, filling over **2 seconds of press-and-hold**, and resetting if released early. Inner 200px circle `#B3261E` (pressed `#8C1D18`), shadow `0 6px 20px rgba(179,38,30,0.35)`, `SOS` 52/700, sub `Hold` → `Keep holding`. Caption `Press and hold for 2 seconds`.
- Active:
  - Banner `#B3261E`, radius 16: `SOS active · MM:SS`, `Help is being alerted` 26/32, `Stay where you are if it is safe.` `#FFDAD5`.
  - Relay steps (white card; each row has a 28px status dot: grey `#C9C4B8` → red while in progress → `#1E5B24` with a check when done; future rows at 40% opacity), revealed at about 0s, 1.5s, 3s and 4.2s:
    1. `Broadcasting over Bluetooth` — `Sending the SOS packet every 250 ms`
    2. `Picked up by 2 nearby phones` — `OP1003 (38 m) and OP1011 (72 m) are relaying` (mining: `HT009 (60 m) and LV03 (110 m)…`)
    3. `Reached the cloud` — `Relayed by OP1011, which has signal`
    4. `The site manager was notified` (mining: `dispatcher`) — `Push alert sent with your location`
  - Packet preview (`#F3EFE6`, mono 12px): `OP1001 · EXC004 · 12.9698, 77.7500 · severity high · sensor snapshot` (adds the last voice log if there is one).
  - Secondary `Cancel SOS`.
- You can leave with ✕ while the SOS is active; the floating button then shows `ACTIVE`.

### 10 Profile
- Header: a 64px avatar circle (accent tint, initial 26/500 accent ink), name 24/30, `OP1001 · Operator` (ID in mono).
- Info list: Machine, Data source (`Phone sensors (no telematics)` / `Product Link telematics`), Site, Skill level.
- `Skills passport` list: title 15px, date 13px, score 20/500 tabular. Lessons finished today go at the top.
- Secondary `Sign out` (52px). Resets all state and returns to Login.

---

## Interactions & Behavior summary
- Routes: `/login` → `/gate` → `/welcome` → shell with tabs `/tasks`, `/tasks/:id`, `/tasks/:id/active`, `/learn`, `/learn/:lessonId`, `/profile`; `/sos` pushed as a full screen over the shell.
- Only one active task at a time.
- Timers tick every 500ms while a task or SOS is active (elapsed clock, SOS clock and relay steps).
- Offline: mining voice logs show `Queued, no signal`; SOS works with no network.
- Focus ring: 2px `#1D1B16`, offset 2. Disabled: 40% opacity.

## State (Riverpod providers)
- `session`: user {name, opId, vertical, machineId, machine, site, source, skill, gps, supervisorLabel}.
- `gate`: seatbelt / camera ∈ {pending, busy, pass, fail}.
- `tasks`: list from Firestore `tasks` + ETA from `/ml/estimate`; `activeTask {id, startedAt}`; `done {id: minutes}`.
- `voiceLogs {taskId: [ {text, offset, synced} ]}` → Firestore `incidents` via the sync queue.
- `lessons`: progress + scores → `training`; auto-assigned from `behaviorFlags`.
- `sos`: `startedAt`, relay status from BLE; `prevTab` for closing.
- Demo toggles in the prototype (`forceSeatbeltFail`, `forceCameraFail`, `skipLogin`) are for testing only.

## Design tokens
| Token | Value |
|---|---|
| bg | `#FBF8F2` |
| surface-2 (nav, info rows) | `#F3EFE6` |
| card | `#FFFFFF` |
| ink | `#1D1B16` |
| ink-2 | `#3D3A33` |
| muted | `#5F5B52` |
| muted-2 / outline button | `#7A766C` |
| input border | `#C9C4B8` |
| divider | `rgba(29,27,22,0.10)` / rows `0.08` |
| **Construction accent** / tint / ink | `#F2B21B` / `#FDEFC8` / `#5C4300` |
| **Mining accent** / tint / ink | `#EF8A3C` / `#FDE3CF` / `#6B2F00` |
| success bg / ink | `#D7ECD6` / `#1E5B24` |
| danger | `#B3261E` (pressed `#8C1D18`), error text `#A1281C`, error bg `#FBE4E0`, error border `#E7A79F` |
| radius | 6 (chips) · 8 (inputs, vertical chip) · 10–12 (small cards) · 16 (cards) · pill for buttons |
| spacing | 4 · 8 · 12 · 16 · 20 · 24 · 28 · 40 |
| type | 12 · 13 · 14 · 15 · 17 · 18 · 20 · 22 · 24 · 26 · 30 · 36 · 52 · 60 (weights 300/400/500/700) |

In Flutter: build a `ThemeExtension` with the neutral tokens, plus one `VerticalTheme` per vertical (accent/tint/ink), provided by Riverpod from the user's `vertical` claim (DESIGN §4.7).

## Assets
- Icons: Lucide (clipboard-list, graduation-cap, user, map-pin, mic, lock, check, x, chevron-left, play, arrow-right). Use `lucide_icons` for Flutter, or matching Material Symbols.
- No images. The AR camera view is a placeholder for the Unity view.

## Mock data (from `ml/data/raw/task_history_sample.csv` + SRS §6.6)
Construction (arjun, EXC004): T001 Earth Excavation 60→57 · T002 Trenching 45→51 · T003 Material Loading 30→41 · T004 Grading 35→33 · T005 Demolition 90→104 (planner → ML min).
Mining (bala, HT012): M001 Overburden Removal 120→127 · M002 Ore Loading 60→56 · M003 Load-Haul-Dump 45→43 · M004 Haul Road Maintenance 50→53 · M005 Bench Drilling 75→79.

## Screenshots
Captured from the prototype (construction account `arjun`), in `screenshots/`:
01-login · 02-safety-gate (all checks passed) · 03-welcome · 04-tasks · 05-task-detail · 06-active-task (with one voice observation) · 07-learning-hub · 08-ar-lesson (step 2 of 4) · 09-sos (idle, hold to send) · 10-sos-active (all relay steps done) · 11-profile.
The locked gate state and the mining account aren't captured. To see them, open the prototype and turn on `forceSeatbeltFail` / `forceCameraFail` in Tweaks, or sign in as `bala`. Some small text in the screenshots may render slightly differently from a real device; the README values are authoritative.

## Files
- `screenshots/` — one PNG per screen (see above).
- `Smart Operator Prototype.dc.html` — the full prototype (markup + logic class with state, mock data and copy).
- `support.js` — runtime needed to open the prototype in a browser.
- `ios-frame.jsx` — the iPhone bezel used for presentation only.
