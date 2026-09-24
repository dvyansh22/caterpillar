# firebase/ — Backend Infrastructure Config

**Owner:** P4

Firebase config for Auth, Firestore and Storage. The project ID is `smart-operator-56cf4` (see
[`docs/FIREBASE_SETUP.md`](../docs/FIREBASE_SETUP.md)). Cloud Messaging and Cloud Functions are
planned; neither is set up yet.

## Files
- `firebase.json` — project config (rules/indexes wiring; also declares `functions/`)
- `firestore.rules` — role-based access rules (operator/technician/owner/admin)
- `storage.rules` — any signed-in user can read/write for now (tighten to org/owner paths later)
- `firestore.indexes.json` — composite indexes
- `seed.js` + `package.json` — seeds the demo users/profiles (`npm install && node seed.js`, see setup doc)
- `functions/` — placeholder, **no Cloud Functions yet** (planned: incident → notify owner; behavior flag → assign training)

## Collections (data model)
`users, machines, tasks, incidents, telematics, training, behaviorFlags, sosEvents`.
The app currently reads `tasks` (by vertical) and writes `incidents` and `training`.

## Deploy
```
firebase login
firebase use <project-id>
firebase deploy --only firestore:rules,storage
```
Don't add `functions` to the deploy until there is code in `functions/`; it would fail.

> Do NOT commit `google-services.json` / `GoogleService-Info.plist` / service-account keys — they are
> git-ignored.
