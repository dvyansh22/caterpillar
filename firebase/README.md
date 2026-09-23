# firebase/ — Backend Infrastructure Config

**Owner:** P4

Firebase config for Auth, Firestore, Storage, Cloud Messaging, and Cloud Functions.

## Files
- `firebase.json` — project config (rules/functions wiring)
- `firestore.rules` — role-based access rules (operator/technician/owner/admin)
- `storage.rules` — media scoped to org
- `firestore.indexes.json` — composite indexes
- `functions/` — Cloud Functions (e.g. incident → notify owner; behavior flag → assign training)

## Collections (data model — freeze in Phase 0)
`users, machines, tasks, incidents, telematics, training, behaviorFlags, sosEvents`

## Deploy
```
firebase login
firebase use <project-id>
firebase deploy --only firestore:rules,storage,functions
```

> Do NOT commit `google-services.json` / `GoogleService-Info.plist` / service-account keys — they are
> git-ignored.
