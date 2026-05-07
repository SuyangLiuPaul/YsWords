# YsWords — One-time cloud setup

This is the **developer setup** required to make cloud features
(Realtime Database sync + Gemini AI) work in production. It only
has to be done once, by the project owner, mostly in the Firebase
Console + Netlify dashboard.

End users never need to enable any APIs — they just sign in with
Google and click "Allow" on the standard sign-in dialog (no
Drive permissions, no extra scopes).

If cloud features are broken, the app **still works** — just in
degraded mode:
* Sync goes local-only (highlights / bookmarks stay on the device)
* AI features show *"not available right now"* friendly messages

## TL;DR — fastest path (≤2 minutes)

The walkthrough has 5 steps. Only **Step 2 (Gemini API enable)**
has a CLI equivalent — the rest are UI-only by Firebase / Google
design.

**Run this for Step 2:**

| If you have… | Do this |
| --- | --- |
| nothing installed | Open <https://shell.cloud.google.com>, paste:<br>`bash <(curl -s https://raw.githubusercontent.com/SuyangLiuPaul/YsWords/main/scripts/enable-cloud-apis.sh)` |
| `gcloud` CLI installed | Run `bash scripts/enable-cloud-apis.sh` from the repo root |
| prefer clicking | Use the in-app diagnostic — Settings → Account → "Run check" → "Open in Cloud Shell" button |

**Then do steps 1, 3, 4, 5 (UI only):**

Open the in-app diagnostic — **Settings → Account → "Run check"**
— each failure shows a one-click Firebase / Netlify deep-link.
The "Cloud setup walkthrough" card (collapsible, just below the
diagnostic) has all 5 steps with ⓘ icons explaining why each
matters and what breaks without it.

## What changed in 2026-05-06

Sync moved off Google Drive onto **Firebase Realtime Database**.
- ✅ End users sign in with Google → instantly synced (no Drive
  permission dialog)
- ✅ Other users can use the app freely (no OAuth scope verification
  needed for >100 users)
- ✅ Different transport from Firestore (WebSocket vs WebChannel)
  so it works on more networks

Trade-off: data lives at `users/{uid}/sync` in Firebase, not in
the user's own Drive. The "user owns their data" story is weaker,
but the UX is dramatically cleaner for non-technical users.

## Manual checklist

If you want to do it yourself without the diagnostic, here's the
full walkthrough.

### 1. Enable Firebase Realtime Database

Sync writes each user's highlights / bookmarks / notes / reading-plan
progress to `users/{uid}/sync` in Realtime Database. RTDB is a
**separate product** from Firestore — uses WebSocket transport
(works on more networks), and doesn't need any extra OAuth scope.

→ **Open https://console.firebase.google.com/project/ysword/database**

→ Click **Create Database** → pick a region (US-central is fine) →
   **Start in locked mode** (we'll open the rules in Step 3).

Without this, sign-in works but every sync write fails with code
`database-disabled`.

### 2. Enable the Generative Language API (Gemini)

The Netlify functions (`aiExplainWord`, `aiSearch`) call
`https://generativelanguage.googleapis.com` via API key. The API
must be enabled in whichever project owns the API key.

→ **Open https://console.cloud.google.com/apis/library/generativelanguage.googleapis.com?project=ysword**

→ Click **Enable**.

(If you're using a Gemini key generated through https://aistudio.google.com/apikey,
the API is auto-enabled in the project that key was generated in.
Worth double-checking.)

### 3. Set Realtime Database security rules

Default rules deny everything. Open them up so authenticated users
can read/write their own `users/<uid>/*` path.

→ **Open https://console.firebase.google.com/project/ysword/database/ysword-default-rtdb/rules**

→ Replace the rules JSON with:

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "auth != null && auth.uid == $uid",
        ".write": "auth != null && auth.uid == $uid"
      }
    }
  }
}
```

→ **Publish**.

Without this, every sync operation returns `permission_denied`.
The in-app diagnostic surfaces this with an "Open RTDB rules"
fix-link.

#### Why no OAuth scope verification anymore?

The previous setup used Drive's `drive.file` scope which is
"sensitive" — apps in Production mode may show a "this app isn't
verified" warning until they're submitted for review. Switching to
Firebase Realtime Database means we use **only `email + profile`
scopes** at sign-in, neither of which is classified sensitive. Any
Google user can sign in without verification gymnastics.

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

### 6. Set up the in-app feedback email pipeline (optional)

The dashboard has a **Feedback** tile that opens a form. When the
user taps **Send**, the Flutter client POSTs the structured payload
to `/api/submitFeedback`, which forwards it via [Resend](https://resend.com)
to your inbox. If `RESEND_API_KEY` is missing, the app falls back
to a `mailto:` link automatically — feedback is never silently lost.

**Setup (~5 min):**

1. Sign up free at <https://resend.com> (3 000 emails / month free
   tier, no credit card).
2. **API Keys → Create API Key** → copy the `re_...` value.
3. Set the env vars in Netlify (UI or CLI):

   ```bash
   netlify env:set RESEND_API_KEY "re_..."
   netlify env:set FEEDBACK_TO   "your-inbox@example.com"   # optional
   netlify env:set FEEDBACK_FROM "YsWords Feedback <feedback@yourdomain.com>"  # optional
   ```

4. Redeploy: `netlify deploy --prod --dir=build/web` (or wait for
   the next push).

**Free-tier constraint:** Resend without a verified sender domain
only allows sending **to the email tied to the API-key account**.
That's fine for "all feedback goes to the developer's inbox"; if
you want the user to receive a copy as well (the in-form
*"Send a copy to me"* checkbox), you need to verify a domain at
**Resend → Domains** (4 DNS records, ~10 min). Once verified, the
function's CC retry kicks in automatically — no code change.

**Test:**

```bash
curl -X POST https://yswords.netlify.app/api/submitFeedback \
  -H "Content-Type: application/json" \
  -d '{"category":"General","message":"setup test"}'
# Expected: {"ok":true} and an email in your inbox.
# {"error":"...RESEND_API_KEY missing..."} 503 = step 6 not done;
# the app gracefully falls back to mailto: until you finish.
```

Email body includes a structured diagnostic block:
```
─── Feedback details ────────────────────
Category    : Bug
Name        : ...
Signed-in   : user@example.com
Reply-to    : ...
Copy-to     : ... (CC requested)
Submitted   : 2026-05-07 13:35:08 UTC
User local  : 2026-05-07 23:35:08 (UTC+10:00)

─── App context ─────────────────────────
App locale   : zh-Hans
Bible version: cuvs-yhwh
Last position: 创世纪 1
Theme        : dark

─── Client environment ──────────────────
Screen       : 1920×1080 px @ 2.00× DPR
Browser lang : en-AU
Browser      : Chrome on macOS
User-Agent   : ...

─── Server-side ─────────────────────────
IP           : ...
Country      : ...
Referer      : ...
Origin       : ...
```

## Verification flow

After completing steps 1–6:

1. Open <https://yswords.netlify.app> in an incognito tab.
2. Open DevTools → Console.
3. Sign in with Google. Console should log a successful
   `signInWithPopup` (and **no** `auth/unauthorized-domain`).
4. Highlight a verse → it should sync to Firebase Realtime
   Database almost immediately. Verify in the Firebase Console
   under **Realtime Database → users/{your uid}/sync** — you
   should see a base64-encoded JSON blob.
5. Open Settings → About → **Run check** — every probe should
   be ✅ (Auth ✓, RTDB ✓, AI proxy ✓).
6. Tap any Greek/Hebrew word in a verse → AI explanation should
   appear within ~5 seconds.
7. Dashboard → **Feedback** tile → type a test message → **Send**
   → snackbar reads "Feedback sent. Thank you!" → email lands
   in your configured inbox within seconds.

## Troubleshooting

The Cloud Setup Diagnostic (Settings → About → Run check) covers
most cases. Common failures:

| Symptom | Most likely cause | Fix step |
| --- | --- | --- |
| Sync silently fails with `permission_denied` | Step 3 missed | Set RTDB security rules |
| Sync writes return `database-disabled` | Step 1 missed | Create the Realtime Database in Firebase |
| `auth/unauthorized-domain` on sign-in | Step 4 missed | Add `yswords.netlify.app` to Firebase Authorized domains |
| AI proxy returns 503 | Step 5 missed | Set `GEMINI_API_KEY` in Netlify env |
| AI proxy returns 404 | Function not deployed | `netlify deploy --prod` |
| Feedback form falls back to mailto: | Step 6 missed | Set `RESEND_API_KEY` in Netlify env |
| Feedback `403 validation_error` from Resend | No verified sending domain | Verify a domain at resend.com/domains, then set `FEEDBACK_FROM` |
| Feedback CC to user not delivered | Same as above | Verify a domain to allow CC to non-owner addresses |
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

## Required env-var summary

| Variable | Used by | Purpose | Without it |
| --- | --- | --- | --- |
| `GEMINI_API_KEY` | `aiSearch`, `aiBibleSearch`, `aiExplainWord` | Calls Gemini for AI explanations / search | All AI returns 503 → app shows "not available" |
| `GEMINI_API_KEY_BACKUP_2..9` | same as above | Failover after free-tier quota | First key still works on quota |
| `GEMINI_MODEL` | same as above | Override model (default `gemini-2.5-flash-lite`) | Default model used |
| `RESEND_API_KEY` | `submitFeedback` | Sends feedback emails via Resend | Form falls back to `mailto:` |
| `FEEDBACK_TO` | `submitFeedback` | Recipient address (default `paulsyliu@gmail.com`) | Default used |
| `FEEDBACK_FROM` | `submitFeedback` | Sender address (default `onboarding@resend.dev`) | Default sandbox sender used |

## Reference

* `lib/services/cloud_auth_service.dart` — Firebase Google sign-in
* `lib/services/realtime_db_sync_service.dart` — Realtime Database sync
* `lib/services/feedback_service.dart` — feedback POST client
* `lib/widgets/cloud_setup_diagnostic.dart` — the Run-check widget
* `netlify/functions/aiExplainWord.mjs` — Gemini for word study
* `netlify/functions/aiSearch.mjs` — Gemini for Bible-evidence AI search
* `netlify/functions/aiBibleSearch.mjs` — Gemini for verse-ref AI search
* `netlify/functions/submitFeedback.mjs` — Resend feedback forwarder
* `docs/drive-sync-setup.md` — earlier Drive-only sync doc (superseded by RTDB; kept for history)
