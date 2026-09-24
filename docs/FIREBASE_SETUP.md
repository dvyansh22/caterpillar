# Firebase Setup — activating real auth (P4)

The app ships with a **swappable auth layer** (`app/lib/services/auth_service.dart`):
- `MockAuthService` (default) — validates the demo accounts `arjun`/`bala`, no backend.
- `FirebaseAuthService` — real Firebase Auth (email/password) + a Firestore `users/{uid}` profile.

Nothing in the UI changes when you switch. The switch is the build flag `USE_FIREBASE`
(`app/lib/core/config.dart`).

> The only step that can't be automated is **creating the Firebase project** — it needs your Google
> account. Everything else is below.

## 1. Create the project (console)
1. Go to <https://console.firebase.google.com> → **Add project** (e.g. `smart-operator`).
2. **Build → Authentication → Get started → Email/Password → Enable**. Also enable **Anonymous**:
   the web build opens the owner dashboard with an anonymous sign-in so the Firestore rules
   (`request.auth != null`) let it read.
3. **Build → Firestore Database → Create database** (start in test mode for the hackathon; the
   production rules live in `firebase/firestore.rules`).

## 2. Generate `firebase_options.dart`
Requires Node and the Dart SDK (bundled with Flutter).
```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login                 # opens your browser — your Google account
cd app
flutterfire configure          # pick the project; select android, ios, web
```
This writes `app/lib/firebase_options.dart`. The committed file is already configured for the
team project `smart-operator-56cf4`. Only re-run this if you use your own project or add a platform;
platforms that aren't configured throw `UnsupportedError`.

## 3. Seed the demo accounts + profiles (automated)
Instead of creating the two auth users and their `users/{uid}` docs by hand, run the seed script:
1. Firebase console → **Project settings → Service accounts → Generate new private key** → save it as
   `firebase/serviceAccount.json` (git-ignored).
2. From the repo:
   ```bash
   cd firebase
   npm install
   npm run seed
   ```
This creates `arjun@smartoperator.demo` and `bala@smartoperator.demo` (password `demo1234`) and their
Firestore `users/{uid}` profiles. The app expands a bare username to `<username>@smartoperator.demo`.
- **Profiles:** `seed.js` holds its own copy of the data in `app/lib/data/mock_data.dart`; keep the two in sync.
- **Not seeded:** the `tasks` collection (the app falls back to its built-in demo tasks) and role
  custom claims.

## 4. Run with Firebase enabled
```bash
flutter run --dart-define=USE_FIREBASE=true
# or web:  flutter run -d chrome --dart-define=USE_FIREBASE=true
```
Without the flag the app keeps using mock auth, so `main` builds and runs even before Firebase exists.

## Data (done) and next steps
- Tasks, incidents and training already go through the swappable repositories
  (`DataRepository` → `MockDataRepository` / `FirebaseDataRepository`):
  - tasks are read by vertical;
  - incidents and training are written.
- Next: seed `tasks` into Firestore so the app stops falling back to its demo tasks.
- Roles (operator/technician/owner/admin) are Firebase Auth **custom claims** — set them via a small
  Cloud Function or the Admin SDK; `firebase/firestore.rules` already reads `request.auth.token.role`.
