# Handoff: Smart Operator Assistant — complete design

This is the complete design package for the Smart Operator Assistant (repo `dvyansh22/caterpillar`). It contains two products that share one visual system:

1. **Operator app** (phone): login → pre-start safety gate → welcome → Task / Learning Hub / Profile, with a floating SOS button. → **`OPERATOR_APP.md`**
2. **Owner / Fleet dashboard** (web): Overview, Fleet, Incidents, Training, with a Construction/Mining toggle. → **`FLEET_DASHBOARD.md`**

## Theme: Night Shift (dark)
Both products use one dark theme for work sites. It is based on the "Night Shift" artifact: a near-black background, dark cards with thin borders, Caterpillar yellow as the one strong color, and condensed uppercase type for headings, numbers, labels and buttons.
- **Type:** **Oswald** (Google Fonts, weights 500/600/700), always uppercase, for page and screen titles, big numbers, kickers/labels, buttons, chips and tabs. Label letter-spacing is 0.8–1.4px; headlines use 0.4px with line-height about 0.9× the size. **Inter** 400/500/600 for body text, list items and values. **JetBrains Mono** 400/500 for IDs, times, GPS and packets.
- **Text on accent fills** (buttons, active chips, logo tile) is always `#141414`, never white.
- **Accent tints** are dark (`#2E2710` construction, `#33230F` mining) with the accent itself as the text color on them.
- **Success** is a bright green `#3DF58A` on `#0F3A22`, used only for passed checks, done/completed tags and finished SOS relay steps.
- **Danger** (SOS, safety alerts) stays red: `#E5484D`.
- Buttons are 10px-radius blocks, not pills. Chips/tags are 12px radius. Cards stay 16px radius with a 1px `#2E2D2A` border and no shadow.
- **Hazard-stripe kickers:** a small block of 45° accent stripes before a short uppercase accent label. On the phone it sits before the date on the task list; on the dashboard it sits above every page title and in the machine drawer.
- **Icons** are Lucide line icons. On the dashboard, KPI icons sit in 32px accent outline rings.
- **Tags:** solid accent for the active state (`In use`, `In progress`, `Latest`), accent outline for `Phone sensors`, grey outline for everything neutral.

## How to use this package
- The HTML files in `prototypes/` are **design references**, not production code. Rebuild them in the Flutter app in `app/`: the mobile build for the operator app and the `flutter build web` build for the dashboard, per `app/README.md`. Use Material 3, Riverpod, GoRouter and `fl_chart`.
- Each spec is self-contained: layout, exact colors, type sizes, copy, interactions, state and mock data.
- To click through a prototype, open it in a browser from inside `prototypes/`. It needs `support.js`; the operator app also needs `ios-frame.jsx`.
- If a screenshot and a spec ever disagree, the spec wins.

## End-to-end flow (how the two products connect)
1. The operator signs in; their account sets role + vertical (construction or mining).
2. The safety gate checks the seatbelt (telematics `SeatbeltStatus`) and the front camera. Any failure locks the app.
3. The operator works through task cards, each with an ML-predicted time. During a task, voice logs are saved as **observations** → they appear on the dashboard under that machine (Incidents tab, and "Incidents by machine" on Overview).
4. Behavior flags (e.g. harsh throttle) auto-assign a Learning Hub lesson → the score appears in the operator's Profile and on the dashboard's **Training** tab, and in the machine drawer.
5. SOS (floating button, 2-second hold) broadcasts over Bluetooth, is relayed by nearby phones, reaches the cloud, and notifies the site manager or dispatcher → it shows as a safety alert on the dashboard.
6. Machines without telematics are fed by the operator's phone and show a **Phone sensors** badge everywhere on the dashboard. That badge is the product's main differentiator.

## Shared design tokens
| Token | Value |
|---|---|
| bg | `#141414` |
| card | `#1D1C1A` |
| surface-2 | `#242321` |
| ink / ink-2 / muted / muted-2 | `#F5F3EE` / `#CDCAC3` / `#A3A19B` (app) · `#97958F` (dashboard) / `#85837D` |
| divider / strong border | `#2E2D2A` / `#3A3935` |
| Construction accent / tint / ink | `#F6C611` / `#2E2710` / `#F6C611` |
| Mining accent / tint / ink | `#F28C28` / `#33230F` / `#F28C28` |
| success (bright green) | `#3DF58A` on `#0F3A22` |
| danger | `#E5484D`, error text `#FF8589`, error bg `#3A1A1B` |
| fonts | Oswald (uppercase display) · Inter (body) · JetBrains Mono (IDs, times); tabular figures for numbers |
| on-accent text | `#141414` |
| radius | 8 inputs · 10 buttons, filters · 11–12 tags · 16 cards · pill toggles |

Suggested Flutter setup: `ThemeData(brightness: Brightness.dark)` with a `ThemeExtension` for the neutral tokens plus a `VerticalTheme` (accent/tint/ink) provided by Riverpod from the signed-in user's `vertical`.

## Package contents
```
OPERATOR_APP.md          full spec for the phone app
FLEET_DASHBOARD.md       full spec for the web dashboard
prototypes/
  Smart Operator Prototype.dc.html
  Fleet Dashboard.dc.html
  support.js             runtime for both prototypes
  ios-frame.jsx          iPhone bezel (presentation only)
screenshots/
  operator/   01-login … 11-profile
  dashboard/  01-overview-construction … 06-overview-mining
```

## Source docs in the repo
`docs/DESIGN.md` §4.8, §13, §16–18 · `docs/SRS.md` §3, §5, §6 · `ml/data/raw/task_history_sample.csv` (task mock data).
