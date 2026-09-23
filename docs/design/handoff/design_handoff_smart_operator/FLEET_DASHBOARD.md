# Handoff: Smart Operator Assistant — Owner / Fleet Dashboard (web) · Night Shift theme

## Overview
The supervisor/owner web dashboard that pairs with the operator phone app. It's the "Owner Dashboard" in `docs/SRS.md` §3.10 (FR-DASH-1) and `docs/DESIGN.md` §4.8 / §13.10. The main point it makes: machines **without telematics** (fed by the operator's phone) sit right next to connected ones, each marked with a data-source tag.

Four tabs: **Overview** (the main screen), **Fleet**, **Incidents**, **Training**. A Construction/Mining toggle swaps the site data and the accent color (yellow ↔ amber).

## About the Design Files
`prototypes/Fleet Dashboard.dc.html` is a **design reference built in HTML**, not production code. Rebuild it as the Flutter **web** build of `app/` (`flutter build web`), using Riverpod, GoRouter and `fl_chart` for the one chart. Replace the mock data with Firestore (`machines`, `incidents`, `training`, `behaviorFlags`, `users`).

Open the HTML file in a browser to click through it (it needs `support.js` in the same folder). All mock data, copy and state logic are in the logic class at the bottom of the file (`SITES`).

## Fidelity
**High fidelity.** Tokens, sizes and copy are final. Designed at 1360px wide, usable down to 768px. Keep it minimal: don't add widgets, charts or columns.

---

## Theme rules (Night Shift)
- Near-black page `#141414`, cards `#1D1C1A` with a 1px `#2E2D2A` border, radius 16, no shadow. Raised surfaces (table header, transcript box, owner pill) `#242321`.
- **Oswald**, always uppercase, for titles, card titles, KPI numbers, labels, table headers, tabs, tags, buttons and links. **Inter** for body text and table cells. **JetBrains Mono** for machine IDs, operator IDs, times and GPS.
- The accent is used for small marks, icons, key numbers, tags and underlines, not for big filled areas. Text on an accent fill is always `#141414`.
- Icons are Lucide line icons, 16px, stroke 1.8, inside **32px outline rings** (1.5px accent border, accent icon).
- Every page title has a **hazard-stripe kicker** above it: a 32×8 block of 45° accent stripes (5px on / 4px off) followed by Oswald 13/600 uppercase, letter-spacing 1.6, in the accent, e.g. `SITE01 · METRO DEPOT · WED 23 SEP`.
- Red `#E5484D` is only for safety alerts.

## Global layout
- Content `max-width: 1280px`, centered, padding 40 32 56, 24px gap between blocks.
- **Top bar** (sticky, min-height 64, bottom border 1px `#2E2D2A`, wraps on narrow screens):
  - Logo tile 28×28, radius 6, accent fill, `#141414` excavator glyph; `SMART OPERATOR` Oswald 16/600, letter-spacing 1, + ` · FLEET` in `#97958F`.
  - Tabs (28px gap, 64px tall): Oswald 14/500 uppercase, letter-spacing 1.4. Active: `#F5F3EE` + 3px accent underline. Inactive `#97958F`, hover `#F5F3EE`.
  - Right: vertical toggle = 34px outline track (1px `#2E2D2A`, radius 17, 3px padding) with two 26px pills (Oswald 12/500 uppercase, 7px color dot). Selected pill: `#F5F3EE` fill, `#141414` text. Unselected: transparent, `#97958F`.
  - Owner pill: 34px, radius 17, `#242321`, 24px accent circle with the initial (Oswald 12/700, `#141414`) + name 13px `#CDCAC3` (`Deepa Menon` / `Eswar Prasad`).
- **Page header**: kicker (above) + H1 Oswald 48/48 700 uppercase, letter-spacing 0.4. Fleet, Incidents and Training add a 15px `#CDCAC3` subline.

## Shared components
- **Status tag** (22px, radius 11, 1px border, Oswald 11/600 uppercase, letter-spacing 0.9, no wrap): `In use` = accent fill + border, `#141414` text · `Idle` = `#242321` fill, `#CDCAC3` text · `Offline` = transparent, `#3A3935` border, `#97958F` text.
- **Data-source tag** (22px, radius 11, transparent, Oswald 11/500 uppercase, 12px icon): `Phone sensors` = accent border + accent text, smartphone icon · `Telematics` = `#3A3935` border + `#CDCAC3` text, radio icon.
- **Alerts cell**: 8px red dot + count in Oswald 16/600 `#FF8589`, or `—` in `#6F6D68`. Counts today's safety alerts + unusual-behavior flags.
- **Incident dot**: 8px. Red `#E5484D` = safety alert/SOS · amber `#E0A21A` = unusual behavior · grey `#8A8882` = voice observation.
- **Count tag**: outline pill, `#3A3935` border, Oswald 10–11 uppercase `#CDCAC3` (`3 LOGS`).
- **Table**: header 38–40px on `#242321`, Oswald 12/500 uppercase, letter-spacing 1.4, `#97958F`. Rows ≥58px, 1px `#2A2927` dividers, hover `#22211F`, whole row clickable. Columns `minmax(0,1.6fr) minmax(0,1.1fr) 88px 144px 48px`, 12px gap, 20px side padding. Machine cell: mono ID 13/500 over type 13px `#97958F`. `Unassigned` operators in `#97958F`.
- **Links** (`View all 8 →`, `View all incidents →`): Oswald 13/500 uppercase, letter-spacing 1.2, accent, arrow icon, no wrap.
- **Lesson blocks** (training): one 10px-tall block per assigned lesson, radius 2, 4px gap; done = accent, not done = `#2E2D2A`.

---

## Screen 1 — Overview
Screenshots: `screenshots/dashboard/01-overview-construction.png`, `02-overview-machine-history.png`, `06-overview-mining.png`.
1. Kicker `SITE01 · METRO DEPOT · WED 23 SEP` + H1 `FLEET OVERVIEW`.
2. **KPI row**: 4 tiles, `repeat(auto-fit, minmax(210px,1fr))`, 16px gap. Each tile (20 padding, 14 gap): label Oswald 13/500 uppercase `#97958F` + ring icon on the right; value Oswald 52/1 700 tabular; foot 13px `#97958F`.
   - `ACTIVE MACHINES` (truck) — `6` + ` / 8` (24px `#97958F`) — `3 via phone sensors`
   - `SAFETY ALERTS TODAY` (shield-alert) — `3`; number **and ring turn red** when > 0 — `1 yesterday`
   - `OPEN INCIDENTS` (clipboard-list) — `5` — `Logged since 06:00`
   - `AVG IDLE TIME` (clock) — `22%` **in the accent** — `+3 pts vs yesterday`
3. Two-column band (`flex: 3 1 540px` / `flex: 2 1 340px`, 24 gap, stacks on tablet):
   - **FLEET STATUS**: card title Oswald 20/600 uppercase + `View all 8 →` link (→ Fleet tab). Table of the 6 machines that aren't offline. Row click opens the machine drawer.
   - **INCIDENTS BY MACHINE**: subline `Latest log per machine · click for history`. One row per machine with logs (max 5), newest incident first. Row (≥62px, grid `8px 1fr auto 18px`): dot · mono ID + count tag · latest title 14px (ellipsis) · mono time 12px (`Today 14:02` / `Yest. 16:40`) · chevron. Click expands the row (bg `#22211F`, chevron 180°) to show that machine's whole history newest first: 6px dot, title 14/20, kind label Oswald 11 uppercase `#97958F`, mono time; 1px dashed `#34332F` separators; 40px left indent. One machine open at a time. A history entry opens the Incidents tab with that log expanded. Footer link `View all incidents →`.
4. **IDLE TIME THIS WEEK** card: subline `Fleet average · last 7 days`. 180px plot, y labels `40% / 20% / 0%` in Oswald 12 `#97958F`, only a 1px `#3A3935` baseline. 7 accent bars (max 72px wide, radius 4 4 0 0, 16px gap). Hover a bar: its value appears above it (Oswald 15/700) and the others drop to 35% opacity. Day labels Oswald 12 uppercase `#97958F`; `TODAY` in the accent, 600.

## Screen 2 — Fleet
Screenshot: `screenshots/dashboard/03-fleet-drawer.png`.
- Kicker `SITE01 · METRO DEPOT`, H1 `FLEET`, subline `8 machines · 5 on phone sensors · 3 on telematics`.
- Same table, all 8 machines. The row whose drawer is open gets `#22211F`.
- **Machine drawer** (also opens from Overview): fixed right, `width: min(440px, 100%)`, `#1D1C1A`, left border 1px `#2E2D2A`, shadow `-16px 0 40px rgba(0,0,0,0.5)`, backdrop `rgba(0,0,0,0.6)` (click closes).
  - Head (24 padding): small hazard stripe + mono ID in the accent; 36px round outline close button; machine type Oswald 30/1.05 700 uppercase; status + source tags.
  - Rows (14px vertical padding, `#2A2927` dividers): label Oswald 12 uppercase `#97958F` on the left, value 15px on the right. `OPERATOR` (`Ravi Shankar · OP1006`) · `LAST TASK` · `IDLE TODAY` (Oswald 20/700, `—` if offline) · `OPEN FLAGS` (dotted list or `None`) · `TRAINING COMPLIANCE` (`2 of 3 lessons · latest 84` + lesson blocks) · `INCIDENT LOG` (`3 LOGS` on the right, then the history newest first; clicking an entry opens it on the Incidents tab; `Nothing logged` if empty).
  - Note box (radius 12, 1px border, info icon, 13/20 `#CDCAC3`). Phone machines: accent border + accent icon, `No telematics hardware on this machine. Its data comes from the operator’s phone: camera, motion sensors, GPS and Bluetooth.` Telematics machines: `#2E2D2A` border, `Product Link telematics, plus the operator’s phone for seatbelt, fatigue and proximity.`

## Screen 3 — Incidents
Screenshot: `screenshots/dashboard/04-incidents-by-machine.png`.
- Kicker, H1 `INCIDENTS`, subline `Safety alerts and operator observations, grouped by machine. Newest first.`
- Left column (200px): 3 filter buttons, 44px, radius 10, 1px border, Oswald 14/500 uppercase + count on the right. Selected: accent tint fill (`#2E2710` / `#33230F`), accent border and text. Others: transparent, `#2E2D2A` border, `#CDCAC3` text. `ALL` · `SAFETY` (safety + unusual behavior) · `OBSERVATIONS` (voice logs).
- Right: one group per machine, ordered by newest incident.
  - Group header: mono ID 14/500 **in the accent** · type 14px · `· operator` 13px `#97958F` · count tag on the right.
  - Card shows **only the latest log** by default, marked with a solid accent `LATEST` tag (16px, Oswald 10/600, `#141414`) next to its kind label.
  - If there are older logs: footer button (46px, `#181817`, Oswald 13 uppercase accent) `SHOW HISTORY · 2 EARLIER` / `HIDE HISTORY`.
  - Log row (≥60px): dot · title 15px + kind label Oswald 11 uppercase `#97958F` · mono time · chevron. Expanded (padding `4 20 20 40`): 4-column grid of Oswald 11 uppercase labels over 14px values — MACHINE (`EXC004 · Cat 320 Excavator`), OPERATOR (`Arjun Kumar OP1001`), LOCATION, GPS (mono). Voice logs add a transcript box (`#242321`, radius 12, accent mic label `VOICE LOG TRANSCRIPT`, quote 15/23). Alerts and flags add a detail sentence 14/21 `#CDCAC3`.

## Screen 4 — Training
Screenshot: `screenshots/dashboard/05-training.png`.
- Kicker, H1 `TRAINING`, subline `Lessons assigned after behavior flags, plus required modules`.
- One tile (max-width 340, graduation-cap ring): `TEAM COMPLIANCE` · `78%` in the accent (Oswald 52) · `14 of 18 assigned lessons complete`.
- Table card: header `OPERATOR / LESSONS / DONE / LATEST SCORE`. Rows ≥66px, grid `minmax(0,1.2fr) minmax(140px,1.4fr) 104px 96px`, 24 gap: name 15/500 over mono `EXC004 · OP1001` 12px · lesson blocks · `2 / 3 LESSONS` Oswald 13 uppercase `#CDCAC3` · score Oswald 24/700, right-aligned.

---

## Interactions
- Tabs switch screens and close the drawer.
- The vertical toggle swaps site data and accent (links, tags, bars, rings, kicker all follow), and resets the drawer, expanded rows, history and filters.
- Fleet rows open the drawer; ✕ or backdrop closes it.
- Incidents by machine rows expand in place; history entries jump to the Incidents tab with that log open.
- Incidents: filters, per-machine history toggle, per-log details toggle.
- Chart hover shows the value.
- Focus ring: 2px accent, offset 2. No login, no settings.

## State
`vertical`, `tab`, `drawerMachineId`, `expandedMachineId` (Overview), `historyOpen{machineId}`, `openIncident{id}`, `incidentFilter`, `hoverBar`.
Data: `machines` (id, type, operator, opId, status, hasTelematics, lastTask, idlePct, flags[], training{done,total,latestScore}), `incidents` (id, machineId, kind: safety|anomaly|observation, title, ts, location, gps, transcript?, detail?), `idleByDay[7]`. Sort incidents by `ts` descending everywhere; in Firestore query per machine with `orderBy('ts','desc')`.

## Design tokens
| Token | Value |
|---|---|
| page bg | `#141414` |
| card | `#1D1C1A` |
| raised (table header, transcript, owner pill) | `#242321` |
| row hover / selected | `#22211F` |
| history footer | `#181817` |
| text / secondary / muted / faint | `#F5F3EE` / `#CDCAC3` / `#97958F` / `#6F6D68` |
| border / row divider / strong border | `#2E2D2A` / `#2A2927` / `#3A3935` |
| Construction accent / tint | `#F6C611` / `#2E2710` |
| Mining accent / tint | `#F28C28` / `#33230F` |
| on-accent text | `#141414` |
| danger / alert text | `#E5484D` / `#FF8589` |
| anomaly dot / observation dot | `#E0A21A` / `#8A8882` |
| radius | 2 lesson blocks · 4 bar tops · 6 logo · 10 filters · 11–12 tags · 12 note/transcript · 16 cards · 17 pills |
| spacing | 4 · 8 · 12 · 16 · 20 · 24 · 28 · 32 · 40 |
| type | Oswald 10–16 labels/tags/tabs · 20 card titles · 24–30 scores/drawer title · 48 H1 · 52 KPI; Inter 13–15; JetBrains Mono 12–14 |
| fonts | Oswald 500/600/700 · Inter 400/500/600 · JetBrains Mono 400/500 |

## Mock data
- **Construction · SITE01 Metro depot** (owner Deepa Menon): EXC004 Cat 320 Excavator (Arjun Kumar, In use, Phone) · GRD002 Cat 140 Motor Grader (Priya Nair, In use, Telematics) · LDR003 Cat 950 Wheel Loader (Ravi Shankar, In use, Phone) · DZR004 Cat D6 Dozer (Suresh Iyer, Idle, Telematics) · BHL005 Cat 432 Backhoe Loader (Kiran Rao, In use, Phone) · TRK006 Cat 730 Articulated Truck (Manoj Das, In use, Telematics) · CMP007 Cat CS56 Compactor (Offline, Phone) · EXC008 Cat 313 Excavator (Offline, Phone).
- **Mining · SITE03 North pit** (owner Eswar Prasad): HT012 Cat 777 Haul Truck (Bala Murugan, In use, Telematics) · SH02 Cat 6040 Hydraulic Shovel · HT009 Cat 777 Haul Truck (Phone) · LV03 Light Vehicle (Phone) · DR07 Cat MD6250 Drill (Idle) · DZ08 Cat D10 Dozer (Phone) · HT014 (Offline) · WL05 Cat 992 Wheel Loader (Offline).
- Incidents: 7 construction / 6 mining over today and yesterday. The full list, with times, GPS and transcripts, is in `SITES` in the prototype.

## Files
- `prototypes/Fleet Dashboard.dc.html` — the dashboard prototype.
- `prototypes/support.js` — runtime needed to open it.
- `screenshots/dashboard/` — 01 overview (construction) · 02 overview with EXC004's history expanded · 03 fleet + machine drawer · 04 incidents by machine with history open · 05 training · 06 overview (mining). The spec values win if a screenshot differs slightly.
