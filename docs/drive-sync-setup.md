# Drive sync — Google Cloud Console setup

The app uses **Google Drive AppData** instead of Firestore for syncing
highlights / bookmarks / notes / reading-plan progress across the
user's devices. The sync code lives at
`lib/services/drive_sync_service.dart`; the auth scope + token capture
live at `lib/services/cloud_auth_service.dart`.

For sync to actually work in production, the **Firebase project's
underlying Google Cloud project** needs two one-time configurations.
This is NOT something the app code can do for you — it has to be done
in the Cloud Console as the project owner.

If sync is showing "Reconnect Google Drive" or DevTools console shows
`403 Drive API access denied`, it's almost always because one of the
two steps below was missed.

## Step 1 — Enable the Drive API

1. Open https://console.cloud.google.com/apis/library/drive.googleapis.com
2. Confirm the project at the top is **`ysword`** (or whatever the
   Firebase project is called)
3. Click **Enable**. Takes ~30 seconds to propagate.

Without this, every Drive REST call returns:
```
403 Forbidden — The Drive API has not been used in project … before
or it is disabled. Enable it by visiting https://console.developers...
```

## Step 2 — Add the `drive.file` scope to the OAuth consent screen

(2026-05-06: scope changed from `drive.appdata` to `drive.file` so the
sync file is **visible** in the user's My Drive as `YsWords.json`.
If you previously added `drive.appdata`, replace it with `drive.file`
— or keep both during a transition.)

1. Open https://console.cloud.google.com/apis/credentials/consent
2. Click **Edit App** (or the equivalent for your consent screen)
3. On the **Scopes** step, click **Add or Remove Scopes**
4. Search for `drive.file` and check
   `https://www.googleapis.com/auth/drive.file`. Description:
   *"See, edit, create, and delete only the specific Google Drive
   files you use with this app"*
5. Save & continue

Without this, the OAuth popup shows the "verifications required" /
"this scope is not approved for this app" screen, and signins fail
silently — `cred.credential` comes back without a Drive access token.

### Verification status — do I need to submit for review?

`drive.file` is classified as a **sensitive scope** (not
restricted). For apps in **Testing** mode (default for personal
projects), it works for any account on your test-users list without
verification. For apps in **Production** mode with public users,
Google may show a "this app isn't verified" warning until you submit
the OAuth consent screen for review.

For a small Bible study app on Netlify, leaving the project in
Testing mode and adding test users is the simplest path.

## Step 3 — Add `yswords.netlify.app` to authorized domains

Already done as part of the Firebase Auth setup, but worth confirming:

1. Open https://console.firebase.google.com/project/ysword/authentication/settings
2. Under **Authorized domains**, ensure `yswords.netlify.app` is
   listed. Add it if missing.

This is a Firebase Auth requirement (separate from the Drive API
enabling), but signin won't even reach the Drive scope grant step
without it.

## How to verify it's working

1. Open https://yswords.netlify.app in a fresh tab (or hard-refresh)
2. Open DevTools → Console
3. Sign in with Google. Look for one of these log lines:
   - `[CloudAuth] popup signin: captured Drive access token (XXX chars)` — ✅ working
   - `[CloudAuth] popup signin: NO Drive access token in credential` — ❌ either Step 1 or Step 2 missed
4. Tap a verse, highlight it
5. Check Settings → Account → Sync. Should say "Synced just now"
6. Sign in on a second device with the same account → highlight should appear

## Diagnosing failures

| Symptom | Most likely cause | Fix |
| --- | --- | --- |
| `403 Drive API access denied (403)` in lastError | Step 1 not done | Enable Drive API in Cloud Console |
| `popup signin: NO Drive access token` in console | Step 2 not done | Add `drive.appdata` scope to consent screen |
| "Reconnect Google Drive" shows immediately | User signed in before scope was added | Click the Reconnect button (interactive consent) |
| Sync silently does nothing | Auth state cached but no Drive permission | Sign out / sign in to re-grant |
| `auth/unauthorized-domain` | Step 3 not done | Add yswords.netlify.app to Firebase Authorized domains |

## Visible vs hidden file location

The current implementation uses the **`drive.file`** scope — files are
created at the root of My Drive as `YsWords.json`, **visible** in
the user's normal Drive UI alongside their other files.

Why visible (vs. the originally-shipped hidden `appDataFolder`):
* User explicitly wanted to see the file in their Drive — they want
  to know what data the app stores on their behalf
* `drive.file` is per-file scope (app can only see files it created),
  so the privacy story is the same
* User can manually delete the file (which would reset sync) — that's
  a feature, not a bug

## Why Drive and not Firestore?

The previous `CloudSyncService` (Firestore-based) was unreliable in
practice — Firestore's WebChannel transport gets blocked on some
networks / browser extensions, IndexedDB cross-tab sync is flaky,
and users reported "I sync on my phone, my laptop never sees it."

Drive AppData:
* User owns the data — lives in their own Drive
* Plain HTTPS to `drive.googleapis.com` — no special transport
* The file (`yswords-sync.json`) is hidden from the user's normal
  Drive UI (`appDataFolder` is invisible in drive.google.com), but
  still in their personal storage
* No Firebase/Firestore quota costs
* No setup needed by the user — `appDataFolder` is automatic
