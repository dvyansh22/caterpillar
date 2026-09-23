# Handoff: Smart Operator Assistant — Operator App (MVP flow) · Night Shift dark theme

## Overview
The operator-facing mobile app for the Smart Operator Assistant (repo `dvyansh22/caterpillar`, Flutter app in `app/`). It covers the MVP flow in `docs/DESIGN.md` §16–18 and `docs/SRS.md` §3: login → pre-start safety gate → welcome → tabbed app (Task, Learning Hub, Profile), with a floating SOS button reachable from every tab. It supports two verticals (construction and mining): one codebase, and the vertical changes the accent color, task names and some copy.

## About the Design Files
The files in this bundle are **design references built in HTML**. They are prototypes that show the intended look and behavior, not production code to copy. Rebuild the design in the existing Flutter app (`app/lib/`) using its planned stack: Material 3, Riverpod for state, GoRouter for routes, and a `features/` folder layout as in `app/README.md`. Mock data and timers in the prototype stand in for Firebase, the `/ml/estimate` API, sherpa-onnx, BLE and Unity. Wire those up for real.

Open `prototypes/Smart Operator Prototype.dc.html` in a browser to click through it (it needs `support.js` and `ios-frame.jsx` in the same folder). The logic class at the bottom of the file holds all state, mock data and copy.

## Theme: Night Shift (dark)
Both products use one dark theme for work sites. It is based on the "Night Shift" artifact: a near-black background, dark cards with thin borders, Caterpillar yellow as the one strong color, and condensed uppercase type for headings, numbers, labels and buttons.
- **Type:** **Oswald** (Google Fonts, weights 500/600/700), always uppercase, for page and screen titles, big numbers, kickers/labels, buttons, chips and tabs. Label letter-spacing is 0.8–1.4px; headlines use 0.4px with line-height about 0.9× the size. **Inter** 400/500/600 for body text, list items and values. **JetBrains Mono** 400/500 for IDs, times, GPS and packets.
- **Text on accent fills** (buttons, active chips, logo tile) is always `#141414`, never white.
- **Accent tints** are dark (`#2E2710` construction, `#33230F` mining) with the accent itself as the text color on them.
- **Success** is a bright green `#3DF58A` on `#0F3A22`, used only for passed checks, done/completed tags and finished SOS relay steps.
- **Danger** (SOS, safety alerts) stays red: `#E5484D`.
- Buttons are 10px-radius blocks, not pills. Chips/tags are 12px radius. Cards stay 16px radius with a 1px `#2E2D2A` border and no shadow.
- A small yellow hazard-stripe mark (26×7, 45° stripes, 4px on/4px off) sits before the date kicker on the task list.

## Fidelity
**High fidelity.** Colors, type sizes, spacing, radii and copy are final for the MVP. Recreate them closely using Flutter/Material widgets. The iPhone bezel is presentation only; the app targets Android and iOS alike (SRS §5, Portability).

---

## Global layout
- Canvas: 402 × 874 (iPhone). Safe area top 54px, bottom home-indicator area ~30px. In Flutter use `SafeArea`.
- App background `#141414`. Cards `#1D1C1A`. Secondary surface (nav bar, info rows) `#242321`.
- Fonts: Oswald (uppercase display: titles, numbers, labels, buttons, chips, tab labels), Inter (body), JetBrains Mono (task IDs, operator IDs, timestamps, BLE packet). Bundle them with `google_fonts` or as assets.
- Tabular figures on all numbers (ETAs, timers, scores): `FontFeature.tabularFigures()`.
- Minimum touch target 44px; primary buttons are 56px tall (gloved, in-cab use, SRS §5 Usability).

### App bar (inside the tabbed app)
- Height 56, horizontal padding 16, bottom border 1px `#2E2D2A`.
- Left: title, Oswald 20/700 uppercase (`Tasks` / `Learning Hub` / `Emergency SOS` / `Profile`). On SOS a 40×40 close (✕) button sits before the title.
- Right: vertical chip (Oswald 12/500 uppercase, letter-spacing 1), 32px tall, radius 16, border 1px `#3A3935`, 13px/500 `#CDCAC3`, with an 8px accent dot: `Construction` or `Mining`.

### Bottom nav bar (3 tabs)
- Background `#242321`, top border 1px `#2A2927`, padding 8 top / 30 bottom (incl. safe area).
- Three equal columns: **Task** (clipboard-list icon), **Learning Hub** (graduation-cap), **Profile** (user). Icons are Lucide, 22px, stroke 1.8.
- Active item: a 64×32 pill (radius 16) behind the icon filled with the accent tint; icon and label in the accent. Inactive: no pill, icon and label `#85837D`. Labels are Oswald 12 uppercase.
- Tapping Task returns to the active task if one is running, otherwise to the list.

### Floating SOS button (on every tab except SOS)
- 68×68 circle, fill `#E5484D`, 3px border `#141414` (the app background), shadow `0 6px 18px rgba(229,72,77,0.40), 0 2px 4px rgba(0,0,0,0.12)`.
- Position: 16px from the right, 100px above the bottom of the app area (just above the nav bar). Floats above content (a `Stack` or `floatingActionButton` with a custom location).
- Label `SOS`, 17px/700, letter-spacing 1px, white. Hover `#D23E43`, pressed `#C4383D`.
- While an SOS is active: a second line `ACTIVE` (10px/600) appears, and a red halo pulses behind it (scale 1 → 1.55, opacity 0.5 → 0, 1.4s ease-out, infinite).
- Tap → opens the SOS screen and remembers the previous tab. ✕ on the SOS screen returns to that tab.
- Scroll content has 88px bottom padding so nothing is trapped under the button.

---

## Screens

### 01 Login
Purpose: username/password sign-in (FR-AUTH-1). The account decides role + vertical (FR-AUTH-2).
- Padding 40 top, 24 sides, 24 bottom; vertical gap 28.
- Logo tile 48×48, radius 12, accent fill, `#141414` excavator glyph.
- Title `Smart Operator`, Oswald 32/36 700 uppercase. Sub `Sign in to start your shift. Your role and site load from your account.` 15/22 `#A3A19B`.
- Fields: label 13/500 `#A3A19B` above; input 56px tall, radius 8, `#1D1C1A` fill, border 1px `#3A3935`, 17px text, 16px horizontal padding. `Username`, `Password` (obscured).
- Error line under the fields, 14px `#FF8589`: `Unknown username. Use arjun or bala.` / `Enter your password.`
- There are no demo-account cards and no link to the owner dashboard on this screen. (Test accounts: `arjun` = construction, `bala` = mining; any password.)
- Primary button pinned to the bottom: `Sign in`, 56px tall, radius 10, accent fill, text `#141414` Oswald 16/600 uppercase, letter-spacing 1. Hover: brightness 0.95.

### 02 Pre-start safety gate
Purpose: the check you can't skip (FR-GATE-1/2). Seatbelt comes from telematics `SeatbeltStatus`; the operator camera must be on.
- Kicker `PRE-START SAFETY GATE` Oswald 13/600 uppercase, letter-spacing 1.4, in the accent.
- Title changes with state: `Checking before you start` → `Ready to start` → `Machine locked`. 30/38.
- Sub: `These checks run automatically. You can’t skip them.` / on fail: `Fix the item below, then run the checks again.`
- Two check cards (`#1D1C1A`, radius 16, 16 padding, 1px border; on fail the border is `#6B2A2C`). Left: a 44px status circle. Pending/busy: `#242321` with `···`. Pass: `#0F3A22` with a `#3DF58A` check. Fail: `#3A1A1B` with a `#FF8589` ✕. Title 17/500, detail 14/20 `#A3A19B`.
  - Seatbelt — busy `Reading SeatbeltStatus for EXC004…`, pass `Fastened · session S000214`, fail `Unfastened. Fasten your seatbelt, then re-run the checks.`
  - Operator camera — pending `Waiting for seatbelt check`, busy `Starting the front camera…`, pass `On · face detected for fatigue monitoring`, fail `Front camera is off. Turn it on so fatigue monitoring can run.`
- Sequence: seatbelt runs for 1.2s, then the camera runs for 1.2s. If both pass, go to Welcome after 0.8s.
- Locked state (any fail): a banner (`#3A1A1B`, radius 12, lock icon, `#FF9EA1` 14px) `App locked until every check passes.`, a primary button `Re-run checks`, and a text button `Sign out` (48px, `#A3A19B`).

### 03 Welcome
- Centered column, 24 padding. A 56px square (radius 10) in the accent tint with a check in the accent.
- `Good morning, {first}` 36/44. Sub 16/24 `#A3A19B`: `Safety checks passed on {machineId}. You have {n} tasks today at {site}.`
- Primary button `Go to tasks`. It also moves on by itself after 3s.

### 04 Tasks (list)
Purpose: today's task cards with the ML-predicted ETA (FR-TASK-1/2).
- 16 padding, 12 gap. Header: hazard-stripe mark + date `Wednesday, 23 September` (Oswald 12/600 uppercase, letter-spacing 1.4, accent); summary `5 tasks · 4 h 46 min` Oswald 26/29 700 uppercase; note `Times predicted by the task-time model for {first} on {machineId}` 13px.
- Task card (the whole card is a button): `#1D1C1A`, radius 16, 16 padding, 1px border `#2E2D2A`. The active task's border uses the accent. Done cards drop to 60% opacity.
  - Left column: mono ID 12px + status chip (22px tall, radius 12, Oswald 11/600 uppercase). Scheduled `#242321`/`#CDCAC3`, In progress accent/`#141414`, Done `#0F3A22`/`#3DF58A`. Task type 18/500. Location with a map-pin icon, 14px `#A3A19B`.
  - Right: ETA badge, min-width 76, radius 12, accent tint fill, accent ink text. Number Oswald 28/32 700 tabular, `min` 12/500 under it.
- Tap: active task → Active task screen; any other → Task detail.

### 05 Task detail
- Back link `‹ All tasks` (44px, pill hover `rgba(245,243,238,0.07)`).
- Mono ID 13px; type 30/38; location with pin 15px.
- Estimate panel: accent tint fill, radius 16, 20 padding, accent ink. `Estimated time` 13/500; `{eta} min` Oswald 52/60 700; explanation 14/20, e.g. `6 min longer than the planner baseline, based on rainy weather, your skill level and machine age.`
- Info list (`#1D1C1A`, radius 16, rows 14×16 with 1px dividers): Weather, Machine (`EXC004 · 4 yrs`), Operator skill, Planner baseline (`45 min`).
- Primary `▶ Start task`. Disabled (40% opacity) while another task is running: `Finish {id} before starting another task.` If the task is done: `Completed in {n} min.`

### 06 Active task
Purpose: elapsed time + voice log (FR-TASK-3, FR-VOICE-1/2).
- Timer card: `#1D1C1A` fill with a 1px accent border, radius 16, 20 padding, text `#F5F3EE`. Status line with an accent dot `In progress · T002`; type 22/28; elapsed `MM:SS` Oswald 60/64 700 tabular; `of ~51 min` 14px `#3A3935`; 6px progress bar (track `rgba(245,243,238,0.18)`, fill accent, radius 3).
- Voice log card: 72px round mic button (accent fill, `#141414` icon; while recording it switches to `#242321` fill with an accent icon, plus a pulsing accent halo). Title `Voice log` / `Listening…` 18/500. Sub `Tap and say what you notice. Works offline.` / `Describe what you see. Transcribed on the phone.`
- Observations list: header `Observations · {n}`; empty `Nothing logged yet on this task.`; each entry a `#1D1C1A` card (radius 12) with the text 15/22 and a meta line: mono time into the task, then `Synced` (construction) or `Queued, no signal` (mining, offline sync queue — DESIGN §7).
- Secondary button `End task` (56px, radius 10, 1px `#3A3935` border, transparent, Oswald 16/600 uppercase). Marks the task done with its real minutes and returns to the list.
- The prototype fakes a transcription after 2.6s. Replace that with sherpa-onnx.

### 07 Learning Hub
Purpose: AR lessons mapping everyday objects to controls (FR-LEARN-1/2/3, DESIGN §18).
- Intro 15/22 `#A3A19B`: `Practice machine controls in AR using objects you have on hand.`
- Lesson card (`#1D1C1A`, radius 16, 16 padding, gap 12). The auto-assigned lesson has an accent border.
  - Chip: `Assigned to you` (accent) / `Optional` (`#242321`) / `Completed` (`#0F3A22`/`#3DF58A`). Right meta `4 steps · 3 min` or `Score 92`.
  - Title 20/500; note 14/20. The assigned lesson explains why: `Auto-assigned after a harsh-throttle flag on EXC004, 22 Sep.` (mining: `…harsh loaded-turn flag on HT012…`). This is the closed loop.
  - Mapping row (`#242321`, radius 10): `Water bottle → Throttle`, `Computer mouse → Steering`.
  - Button: assigned + not done = accent fill with `#141414` text; otherwise an outline (`#3A3935` border, `#F5F3EE` text). `Start lesson` / `Practice again`.

### 08 AR lesson
- Back `‹ Learning Hub`.
- Camera area, 320px tall, radius 16, dark stripes (placeholder for the Unity AR view via flutter_unity_widget). Top-left label on an accent chip `Water bottle = Throttle`; bottom-right `Step 2 of 4` in `#F5F3EE` on `rgba(0,0,0,0.6)`. Both labels are single-line (no wrap).
- Running: a 4-segment progress bar (4px, radius 2, done = accent, rest `#2E2D2A`); lesson title 14/500; prompt 24/32; primary `Step done`.
  - Throttle steps: `Hold the bottle upright where the camera can see it.` → `Tilt it forward slowly to raise the throttle.` → `Bring it back upright to return to idle.` → `Tilt forward, then ease back without a jerk.`
  - Steering steps: `Place the mouse flat where the camera can see it.` → `Turn it left to steer left.` → `Turn it right to steer right.` → `Center it and hold for two seconds.`
- Done: `{title} complete`, score `92 / 100` 56/64, `Saved to your skills passport.`, primary `Done`. The score is written to `training` and shows up in Profile.

### 09 SOS (opened from the floating button)
Purpose: BLE SOS with multi-hop relay (FR-SOS-1/2/3, DESIGN §17).
- Idle: intro `Sends your location over Bluetooth to nearby phones, which pass it on. Works with no cell signal.` A 240px hold-ring: track `#3A1A1B` 8px; progress stroke `#E5484D` 8px round cap, filling over **2 seconds of press-and-hold**, and resetting if released early. Inner 200px circle `#E5484D` (pressed `#C4383D`), shadow `0 6px 20px rgba(229,72,77,0.35)`, `SOS` 52/700, sub `Hold` → `Keep holding`. Caption `Press and hold for 2 seconds`.
- Active:
  - Banner `#E5484D`, radius 16: `SOS active · MM:SS`, `Help is being alerted` 26/32, `Stay where you are if it is safe.` `#FFD6D7`.
  - Relay steps (`#1D1C1A` card; each row has a 28px status dot: grey `#3A3935` → red while in progress → bright green `#3DF58A` with a `#141414` check when done; future rows at 40% opacity), revealed at about 0s, 1.5s, 3s and 4.2s:
    1. `Broadcasting over Bluetooth` — `Sending the SOS packet every 250 ms`
    2. `Picked up by 2 nearby phones` — `OP1003 (38 m) and OP1011 (72 m) are relaying` (mining: `HT009 (60 m) and LV03 (110 m)…`)
    3. `Reached the cloud` — `Relayed by OP1011, which has signal`
    4. `The site manager was notified` (mining: `dispatcher`) — `Push alert sent with your location`
  - Packet preview (`#242321`, mono 12px): `OP1001 · EXC004 · 12.9698, 77.7500 · severity high · sensor snapshot` (adds the last voice log if there is one).
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
- Focus ring: 2px accent, offset 2. Disabled: 40% opacity.

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
| bg | `#141414` |
| surface-2 (nav, info rows) | `#242321` |
| card | `#1D1C1A` (hover `#22211F`) |
| device frame / status bar | `#0B0B0B` / `#141414` |
| ink | `#F5F3EE` |
| ink-2 | `#CDCAC3` |
| muted | `#A3A19B` |
| muted-2 / outline button | `#85837D` |
| input border | `#3A3935` |
| divider | `#2E2D2A` / rows `0.08` |
| **Construction accent** / tint / ink | `#F6C611` / `#2E2710` / `#F6C611` |
| **Mining accent** / tint / ink | `#F28C28` / `#33230F` / `#F28C28` |
| success bg / ink | `#0F3A22` / `#3DF58A` |
| danger | `#E5484D` (pressed `#C4383D`), error text `#FF8589`, error bg `#3A1A1B`, error border `#6B2A2C` |
| radius | 8 (inputs) · 10 (buttons, small tiles) · 12 (chips, small cards) · 16 (cards, vertical chip) |
| spacing | 4 · 8 · 12 · 16 · 20 · 24 · 28 · 40 |
| type | 11 · 12 · 13 · 14 · 15 · 16 · 17 · 18 · 20 · 22 · 24 · 26 · 30 · 32 · 36 · 52 · 60 |
| fonts | Oswald 500/600/700 uppercase (display, labels, buttons, chips) · Inter 400/500/600 (body) · JetBrains Mono 400/500 (IDs, times) |
| on-accent text | `#141414` |
| accent-tint border (active task) / strong border | accent / `#3A3935` |

In Flutter: build a `ThemeExtension` with the neutral tokens, plus one `VerticalTheme` per vertical (accent/tint/ink), provided by Riverpod from the user's `vertical` claim (DESIGN §4.7).

## Assets
- Icons: Lucide (clipboard-list, graduation-cap, user, map-pin, mic, lock, check, x, chevron-left, play, arrow-right). Use `lucide_icons` for Flutter, or matching Material Symbols.
- No images. The AR camera view is a placeholder for the Unity view.

## Mock data (from `ml/data/raw/task_history_sample.csv` + SRS §6.6)
Construction (arjun, EXC004): T001 Earth Excavation 60→57 · T002 Trenching 45→51 · T003 Material Loading 30→41 · T004 Grading 35→33 · T005 Demolition 90→104 (planner → ML min).
Mining (bala, HT012): M001 Overburden Removal 120→127 · M002 Ore Loading 60→56 · M003 Load-Haul-Dump 45→43 · M004 Haul Road Maintenance 50→53 · M005 Bench Drilling 75→79.

## Screenshots
Captured from the prototype (construction account `arjun`), in `screenshots/operator/`:
01-login · 02-safety-gate (all checks passed) · 03-welcome · 04-tasks · 05-task-detail · 06-active-task (with one voice observation) · 07-learning-hub · 08-ar-lesson (step 2 of 4) · 09-sos (idle, hold to send) · 10-sos-active (all relay steps done) · 11-profile.
The locked gate state and the mining account aren't captured. To see them, open the prototype and turn on `forceSeatbeltFail` / `forceCameraFail` in Tweaks, or sign in as `bala`. Some small text in the screenshots may render slightly differently from a real device; the README values are authoritative.

## Files
- `screenshots/operator/` — one PNG per screen (see above).
- `prototypes/Smart Operator Prototype.dc.html` — the full prototype (markup + logic class with state, mock data and copy).
- `prototypes/support.js` — runtime needed to open the prototype in a browser.
- `prototypes/ios-frame.jsx` — the iPhone bezel used for presentation only.
