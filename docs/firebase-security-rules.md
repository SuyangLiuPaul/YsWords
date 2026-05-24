# Firebase Security Rules — audit

2026-05-24 (v1.3.24)

The YsWords cross-device sync (notes / bookmarks / highlights / BYOK
Gemini key) stores per-user data in **Firebase Realtime Database**.
The rules are NOT in this repo — they live in the Firebase Console
at:

  https://console.firebase.google.com/project/ysword/database/ysword-default-rtdb/rules

This document records:
  1. Which RTDB paths the YsWords client reads/writes
  2. The minimum-correct rules each path needs
  3. How to verify the live rules match

## Paths the client uses

From `lib/services/realtime_db_sync_service.dart` + `cloud_auth_service.dart`:

| Path | Read | Write | Notes |
|---|---|---|---|
| `users/{uid}/sync` | ✓ | ✓ | Profile sync blob (notes/bookmarks/highlights/last-read) |
| `users/{uid}/account/geminiApiKey` | ✓ | ✓ | BYOK Gemini API key, separate path so it survives profile switches |

No other paths are read/written by the client.

## Required rules

The rules MUST enforce that **only the signed-in user's own UID can
read/write their own subtree**. The minimum-correct ruleset:

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read":  "auth != null && auth.uid === $uid",
        ".write": "auth != null && auth.uid === $uid"
      }
    }
  }
}
```

What this guarantees:
- **Unauthenticated read/write** → blocked at every path.
- **User A reading user B's data** → blocked (`auth.uid !== $uid`).
- **User A writing under user B's path** → blocked.
- **Top-level read/write** (`/`) → blocked (no rule allows it).

## Verifying the live rules

### One-time check (manual)

1. Open the Firebase Console URL above.
2. Confirm the rules JSON contains the `.read` + `.write` predicates
   above for the `users/$uid` path.
3. Use Firebase's "Rules Playground" tab to simulate:
   - `Set` at `/users/USER_A/sync` while authenticated as USER_B
     → expect DENIED
   - `Get` at `/users/USER_A/sync` while authenticated as USER_A
     → expect ALLOWED
   - `Get` at `/users/USER_A/sync` while unauthenticated
     → expect DENIED

### Automated check (future round)

Firebase provides an emulator (`firebase emulators:start
--only database`) that lets us run a Dart/JS unit test against
fake auth contexts. Not wired today — open as a future task.

## What's NOT covered by these rules

- **The BYOK Gemini key itself** — visible to anyone who has the
  user's UID + valid auth token (i.e., the user themselves on
  another device). This is by design (cross-device sync needs it).
  Defense-in-depth would be encrypting the value at rest using a
  device-bound key, but the threat model (a malicious actor on
  another of the user's devices) is already covered by the user's
  Google account security.
- **DDoS / volumetric attack** on RTDB — Firebase enforces its
  own per-project quota; rules don't help here. If a single user's
  account starts thrashing writes, the only mitigation is to
  bump the quota or temporarily disable the user.
- **Privilege escalation through Firebase Auth custom claims** —
  the project doesn't use custom claims today; if added in future,
  the rules above would need to reference them.

## When to revisit

- Adding a new RTDB path → add a new rule branch + update the
  table above.
- Adding Firestore collections (currently unused) → write
  equivalent `firestore.rules` and dump them into this file.
- Adding shared / public data (e.g., a community-curated bookmark
  list) → that's a NEW top-level path; needs its own ruleset.

## Last audit

- **2026-05-24 (v1.3.24)** — initial audit. User confirmed via memory
  note "Firebase rules enforce per-uid isolation". This doc captures
  the verification procedure so a future agent can re-run it.
