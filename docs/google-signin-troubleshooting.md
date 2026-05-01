# Google Sign-In Troubleshooting

> Last updated: 2026-05-01
> Owner: `lib/services/cloud_auth_service.dart`
> Related: `lib/firebase_options.dart`, `lib/services/cloud_sync_service.dart`

This is the canonical document for diagnosing and fixing Google sign-in
failures on YsWords. The flow has broken many times, in many different
ways — every recurrence has been a layer described below. Walk this
list top-to-bottom whenever a user reports it doesn't work.

---

## How sign-in actually works

```
User taps "Sign in with Google"
        │
        ▼
CloudAuthService.signInWithGoogleAndAdoptProfile()
        │
        ▼
CloudAuthService.signInWithGoogle()
        │
        ├─► (preferred) FirebaseAuth.signInWithPopup(GoogleAuthProvider)
        │        Opens a popup window to ysword.firebaseapp.com → Google
        │        consent → callback → returns User credential.
        │
        └─► (fallback) FirebaseAuth.signInWithRedirect(GoogleAuthProvider)
                 Navigates the WHOLE PAGE to Google. After Google → Firebase
                 → back to yswords.netlify.app, the credential is captured
                 by getRedirectResult() called during init().
        │
        ▼
ProfileService.adopt(displayName) — creates or switches to a local
profile matching the Google display name (or email prefix as fallback)
        │
        ▼
CloudSyncService.start() — subscribes to Firestore /users/{uid}/profileData/main
```

**Key files:**

| File | Role |
|---|---|
| `lib/services/cloud_auth_service.dart` | The auth state-machine. Init, sign-in, sign-out, current-user, redirect-result capture |
| `lib/services/cloud_sync_service.dart` | Firestore read/write of highlights + bookmarks |
| `lib/firebase_options.dart` | Project ID `ysword`, authDomain `ysword.firebaseapp.com` |
| `lib/services/profile_service.dart` | Local profile adopt logic |
| `web/index.html` | Cache-bust + service-worker self-heal that can interfere with the OAuth callback |

---

## Failure modes — the full catalogue

### 1. "Sign-in cancelled" / "popup-closed-by-user"

**Symptom**: User clicks Sign in with Google → Google popup opens →
they pick an account → popup closes immediately → `Sign-in cancelled`
SnackBar appears.

**Real cause** (almost always): Safari blocks third-party cookies in
the popup, so the popup completes Google's OAuth but can't post the
credential back to the parent window. The parent times out and treats
it as "user closed the popup".

**Fix path**:
- Code-level: `signInWithGoogle()` catches this error code and falls
  back to `signInWithRedirect()`. The redirect flow doesn't depend on
  third-party cookies because the whole page navigates.
- User-level: ask the reporter to try Chrome instead of Safari, or to
  enable "Allow All Cookies" in Safari Settings → Privacy & Security.
- Browser-level (iOS): iOS 17+ Safari is increasingly hostile to
  third-party cookies; redirect flow is the only reliable option there.

### 2. "Null check operator used on a null value" inside `currentUser`

**Symptom**: Error message `[FirebaseAuth.currentUser] minified:Hj:
Null check operator used on a null value`.

**Real cause**: `firebase_auth_web` SDK has a `!` somewhere in its
`currentUser` getter that fires when JS-side persisted state is half-
initialized or corrupt. Triggers:
- Browser private/incognito mode
- localStorage / IndexedDB blocked by user setting or extension
- Ad-blocker resetting Firebase persistence
- Half-state after a previous failed sign-out
- Cross-origin iframe scenarios

**Fix path** (already shipped, round 47):
- `_doInit()` wraps `auth.currentUser` in try/catch and treats
  exceptions as `null` instead of failing the whole init.
- `userChanges()` listener wraps each event in try/catch + has an
  `onError` handler so a single bad event can't kill the listener.
- `cloud_sync_service.dart` reads `currentUser` once into a local
  before any Firestore call, null-checking before use.

### 3. "auth/unauthorized-domain"

**Symptom**: Sign-in fails immediately, error message says
"This domain is not authorized for sign-in."

**Real cause**: The current page's domain is missing from
Firebase Console → Authentication → Settings → Authorized domains.

**Fix**:
1. Open https://console.firebase.google.com/
2. Project: `ysword`
3. Authentication → Settings → Authorized domains
4. Add: `yswords.netlify.app` (and any preview-deploy URLs you use,
   e.g. `*.yswords.netlify.app` won't work — Firebase doesn't
   honour wildcards; you have to add each branch deploy individually
   if you want them all).

`localhost` is in the list by default for dev; production needs the
public domain explicitly.

### 4. "auth/operation-not-allowed"

**Symptom**: `Google sign-in is not enabled on this Firebase project.`

**Real cause**: Google provider is disabled in Firebase Console.

**Fix**:
1. Firebase Console → Authentication → Sign-in method
2. Find "Google" in the list → enable
3. Set the project support email
4. Save

### 5. "auth/popup-blocked"

**Symptom**: Nothing visible happens when the user taps the button.

**Real cause**: Browser popup-blocker. Modern browsers require popups
to be initiated by a synchronous user gesture; if our handler does
ANYTHING async before calling `signInWithPopup`, the popup-trust
window has expired.

**Fix path**:
- Code-level: `onPressed: () => signInWithGoogleAndAdoptProfile()`
  must be the first await target — no `await Future.delayed(...)` or
  even `await context.read<...>()` BEFORE the popup call.
- Currently in `cloud_auth_service.dart:244`: the popup is the first
  await; the only sync code before is `_configured` check + provider
  build. This is correct.
- Fallback: redirect flow doesn't have this restriction; we trigger
  it automatically when popup is blocked.

### 6. "Network request failed"

**Symptom**: Sign-in fails with `Network error — check your connection.`

**Real causes** (in order of frequency):
1. User actually offline.
2. Firewall / VPN blocking `*.firebaseio.com` or `securetoken.google.com`.
3. Corporate proxy intercepting TLS but missing Firebase certs.

**Fix path**: nothing we can do from code. Tell the user to check
connectivity, disable VPN, or try a different network.

### 7. Sign-in succeeds but cloud sync stays "Disabled"

**Symptom**: Auth shows the user as signed in, but cloud sync status
stays grey/disabled.

**Real cause**: `CloudSyncService._onAuthChanged` ran when
`currentUser` was null due to one of the failures above, and the
`userChanges()` event for the new user didn't re-fire.

**Fix path** (shipped round 47): `_onAuthChanged` reads `currentUser`
into a local + null-checks. If you suspect a stuck state, the
floating-header overflow → **Reload** button now re-runs init + the
sync subscription.

### 8. Cache stale — old build doesn't have the fix

**Symptom**: A bug we know is fixed reproduces on the user's device.

**Real cause**: Service worker caching + browser HTTP cache. The
self-heal block in `web/index.html` handles this on every page load
(unregisters SW, clears caches if the build stamp changed), but if
the user is offline at the moment of self-heal it can stall.

**Fix path**:
- iOS Safari: Settings → Safari → Clear History and Website Data
- Chrome: DevTools → Application → Service Workers → Unregister →
  Clear Storage → Refresh
- Or in any browser: open the site in a Private window once to see
  if a fresh build resolves it.

---

## Diagnostic checklist for the next bug report

Run through these in order. The first one that fails is your bug.

### A. Is the build current?

```bash
curl -sI https://yswords.netlify.app/main.dart.js | grep -E '^(date|etag):'
```

Compare ETag against the latest deploy in Netlify dashboard. If
they don't match, the user's seeing a stale build → tell them to
clear cache.

### B. Is Firebase config valid?

```bash
grep -A2 'projectId\|authDomain\|appId' lib/firebase_options.dart | head -10
```

Should show `projectId: 'ysword'`, `authDomain: 'ysword.firebaseapp.com'`,
and a non-empty `appId`. If any are placeholder strings, the build
was created without a Firebase project.

### C. Is the domain authorized?

Open Firebase Console → Authentication → Settings → Authorized
domains. Confirm `yswords.netlify.app` is in the list.

### D. Is Google provider enabled?

Firebase Console → Authentication → Sign-in method → Google should
be **enabled**, not just listed.

### E. Reproduce in DevTools

Open the app in Chrome (NOT Safari) with DevTools open. Sign-in
attempt should produce one of:

- A successful `User` object in `[CloudAuthService] Step:` logs
- A specific `FirebaseAuthException(code: ...)` we can map to the
  failure modes above
- A "Null check operator" stack — see #2 above

### F. Test on a different network

If a user reports it fails on their corporate wifi, confirm by
asking them to try on cellular or home wifi. Firewall / TLS
intercept (#6) is the most common "everything looks fine but it
doesn't work" cause.

---

## How to test changes

1. **Local dev** — `flutter run -d chrome` or
   `flutter run -d <ios-device>`. Sign in / out repeatedly.
2. **Staging** — there's no staging environment; `yswords.netlify.app`
   is production. Test by landing the change on the worktree branch
   first, then deploying via CLI before merging to main.
3. **Browsers to cover**:
   - Chrome (desktop + Android)
   - Safari (desktop + iOS) — most common Google-sign-in failures
   - iOS Safari **in PWA mode** (Add-to-Home-Screen) — separate beast
4. **Verification matrix**:
   - Fresh install → sign in → see user in greeting card
   - Sign out → sign in different account → profile switches
   - Reload mid-sign-in → state recovers
   - Browser private window → falls back to redirect

---

## When sign-in WILL break next

Things to keep an eye on:

- **iOS 26+ Safari may drop popup support entirely**. If
  `signInWithPopup` stops working on iOS, the redirect fallback is
  the safety net — make sure it's tested.
- **firebase_auth 6.x → 7.x migration** — past major bumps (4 → 6)
  broke us with PlatformException(channel-error). Re-test the full
  matrix before / after any pubspec major bump.
- **Firebase Console policy changes** — Google has tightened auth
  domain rules a few times. If a sign-in starts failing with
  "auth/unauthorized-domain" without a deploy on our side, check
  the console first.
- **Apple's third-party cookie crackdown** — every iOS major bump
  puts another bullet in popup OAuth. Redirect is the long-term
  answer.
