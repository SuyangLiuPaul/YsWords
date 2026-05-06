# YsWords — One-time cloud setup

This is the **developer setup** required to make cloud features
(Drive sync, Gemini AI) work in production. It only has to be done
once, by the project owner, in Google Cloud Console.

End users never need to enable any APIs — they just sign in with
Google and click "Allow" on the OAuth consent screen.

If cloud features are broken, the app **still works** — just in
degraded mode:
* Sync goes local-only (highlights / bookmarks stay on the device)
* AI features show *"not available right now"* friendly messages

## TL;DR — fastest path (≤2 minutes)

You actually don't have to walk through five pages. Two of the
five steps (the API enablements) can be automated. Three are
UI-only by Google design.

**Automate steps 1 + 2 — pick one of:**

| If you have… | Do this |
| --- | --- |
| nothing installed | Open <https://shell.cloud.google.com>, paste:<br>`bash <(curl -s https://raw.githubusercontent.com/SuyangLiuPaul/YsWords/main/scripts/enable-cloud-apis.sh)` |
| `gcloud` CLI installed | Run `bash scripts/enable-cloud-apis.sh` from the repo root |
| just like clicking | Use the in-app diagnostic — Settings → Account → "Run check" → "Open in Cloud Shell" button |

**Then do steps 3, 4, 5 (no CLI exists for these — UI only):**

Open the in-app diagnostic — **Settings → Account → "Run check"**
— each failure shows a one-click Cloud Console deep-link. The
"Cloud setup walkthrough" card (collapsible, just below the
diagnostic) has all 5 steps with ⓘ icons explaining why each
matters and what breaks without it.

## Manual checklist

If you want to do it yourself without the diagnostic, here's the
full walkthrough.

### 1. Enable the Drive API

The app calls `https://www.googleapis.com/drive/v3/files` to read &
write the `YsWords.json` sync file in each user's Drive. The Drive
API has to be enabled in the project that owns the OAuth client.

→ **Open https://console.cloud.google.com/apis/library/drive.googleapis.com?project=ysword**

→ Click **Enable**. Takes ~30 seconds to propagate.

Without this, every Drive REST call returns:
```
403 Forbidden — Drive API has not been used in project ysword before
or it is disabled. Enable it by visiting …
```

### 2. Enable the Generative Language API (Gemini)

The Netlify functions (`aiExplainWord`, `aiSearch`) call
`https://generativelanguage.googleapis.com` via API key. The API
must be enabled in whichever project owns the API key.

→ **Open https://console.cloud.google.com/apis/library/generativelanguage.googleapis.com?project=ysword**

→ Click **Enable**.

(If you're using a Gemini key generated through https://aistudio.google.com/apikey,
the API is auto-enabled in the project that key was generated in.
Worth double-checking.)

### 3. Add the `drive.file` scope to the OAuth consent screen

The app requests `https://www.googleapis.com/auth/drive.file` at
sign-in time. Google rejects scope grants that aren't pre-listed on
the consent screen.

→ **Open https://console.cloud.google.com/apis/credentials/consent?project=ysword**

→ Click **Edit App** (or the equivalent for your consent screen)

→ On the **Scopes** step, click **Add or Remove Scopes**

→ Search for `drive.file` and check
  `https://www.googleapis.com/auth/drive.file`. Description:
  *"See, edit, create, and delete only the specific Google Drive
  files you use with this app"*

→ Save & continue.

(If you previously added `drive.appdata`, remove it — we switched on
2026-05-06.)

### 4. Add `yswords.netlify.app` to Firebase Authorized domains

Firebase Auth rejects sign-in attempts from non-authorized origins.

→ **Open https://console.firebase.google.com/project/ysword/authentication/settings**

→ Under **Authorized domains**, ensure `yswords.netlify.app` is
  listed. Add it if missing.

### 5. Set Gemini API key in Netlify env vars

The AI proxy functions read the key from `GEMINI_API_KEY`.

→ **Open https://app.netlify.com/projects/yswords/configuration/env**

→ Add (or confirm):
  - `GEMINI_API_KEY` = (your key from https://aistudio.google.com/apikey)
  - Optional: `GEMINI_API_KEY_BACKUP_2..9` for extra free-tier capacity
    (the function falls back through them on quota exhaustion)
  - Optional: `GEMINI_MODEL` (default `gemini-2.5-flash-lite`)

→ Trigger a redeploy or wait for the next push.

## Verification flow

After completing steps 1–5:

1. Open https://yswords.netlify.app in an incognito tab
2. Open DevTools → Console
3. Sign in with Google
4. Console should log: `[CloudAuth] popup signin: captured Drive
   access token (XXX chars)` ✅
5. Open https://drive.google.com in another tab — you should see
   `YsWords.json` at the top of My Drive
6. Open Settings → About → "Run check" — every probe should be ✅
7. Tap any Greek/Hebrew word in a verse → AI explanation should
   appear within ~5 seconds

## Troubleshooting

The Cloud Setup Diagnostic (Settings → About → Run check) covers
most cases. Common failures:

| Symptom | Most likely cause | Fix step |
| --- | --- | --- |
| `[CloudAuth] popup signin: NO Drive access token` | Step 3 missed | Add `drive.file` to consent screen |
| Drive REST shows 403 + "API has not been used" | Step 1 missed | Enable Drive API |
| `auth/unauthorized-domain` | Step 4 missed | Add yswords.netlify.app to Firebase |
| AI proxy returns 503 | Step 5 missed | Set GEMINI_API_KEY in Netlify |
| AI proxy returns 404 | Function not deployed | `netlify deploy --prod` |
| OAuth says "this app isn't verified" | Consent screen in production mode without verification | Switch to Testing mode in OAuth consent screen, add yourself as test user |
| `org_internal` workspace blocking | User on Google Workspace where admin blocks third-party apps | Out of our control; user must use a personal Google account |

## Why "users don't need to enable APIs"

A common confusion: end users don't have Google Cloud projects.
APIs are enabled at the **project level** (the project that owns the
OAuth client = the YsWords project), not at the user level.

When a user signs in:
* OAuth client is YsWords' (project `ysword`)
* Scopes are requested against the user's Google account
* User clicks Allow → grants the YsWords app access to the requested
  scope
* App calls Drive API using user's OAuth token + YsWords' API enablement
* Storage uses **the user's Drive quota** (15 GB free), but API
  request quota uses **YsWords' project quota** (1 billion/day, basically
  unhittable)

The user's only "setup" is one Allow click on the consent screen.

## Why we can't auto-enable APIs from the app

Google Cloud doesn't expose a programmatic way for an app to enable
its own APIs — that's a project-owner action by design (otherwise
any app could silently turn on billable APIs). The Cloud Setup
Diagnostic gets the closest possible: it tells you exactly which
API isn't enabled and gives you a one-click deep-link to the
Cloud Console page that enables it.

## Reference

* `lib/services/cloud_auth_service.dart` — OAuth + Drive scope handling
* `lib/services/drive_sync_service.dart` — Drive REST calls
* `lib/widgets/cloud_setup_diagnostic.dart` — the Run-check widget
* `netlify/functions/aiExplainWord.mjs` — Gemini for word study
* `netlify/functions/aiSearch.mjs` — Gemini for AI search
* `docs/drive-sync-setup.md` — earlier Drive-only doc (subset of this)
