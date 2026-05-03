# Google Sign-In Troubleshooting

> Last updated: 2026-05-03 (added §9 stale-registrant failure mode)
> Owner: `lib/services/cloud_auth_service.dart`
> Related: `lib/firebase_options.dart`, `lib/services/cloud_sync_service.dart`,
> `.dart_tool/flutter_build/<hash>/web_plugin_registrant.dart` (generated)

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
| `.dart_tool/flutter_build/<hash>/web_plugin_registrant.dart` | **Generated**, **cached**. Must contain `FirebaseCoreWeb`, `FirebaseAuthWeb`, `FirebaseFirestoreWeb` — see §9. We also self-register defensively in `init()` |

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

### 9. `UnimplementedError: signInWithPopup() is only supported on web based platforms` (or `getRedirectResult() is not implemented`)

**Symptom**: Console shows one or both of these literal errors when
the Sign-in button is tapped, on web:

```
UnimplementedError: signInWithPopup() is only supported on web based platforms
UnimplementedError: getRedirectResult() is not implemented
CloudAuthService: getRedirectResult skipped: UnimplementedError: ...
signInWithPopup non-Firebase error: UnimplementedError: ...
```

The popup never opens. Both popup and redirect fallback throw the
same error. The user sees "Sign-in not working" with no popup at all.
This affects every browser, not just Safari or iOS PWA — the
"third-party cookie" red herring (#1) does not apply here.

**Real cause**: Flutter's auto-generated web plugin registrant —
`.dart_tool/flutter_build/<hash>/web_plugin_registrant.dart` —
shipped stale. The file is **cached per build hash** and a stale
cache can ship containing only `SharedPreferencesPlugin.registerWith(registrar)`,
omitting all the Firebase web delegates. With no `FirebaseAuthWeb`
registered, `FirebaseAuthPlatform.instance` stays at the default
`MethodChannelFirebaseAuth`, which throws `UnimplementedError` on
every web-only OAuth method (`signInWithPopup`, `signInWithRedirect`,
`getRedirectResult`).

A healthy registrant looks like:

```dart
import 'package:cloud_firestore_web/cloud_firestore_web.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

void registerPlugins([final Registrar? pluginRegistrar]) {
  final Registrar registrar = pluginRegistrar ?? webPluginRegistrar;
  FirebaseFirestoreWeb.registerWith(registrar);
  FirebaseAuthWeb.registerWith(registrar);
  FirebaseCoreWeb.registerWith(registrar);
  SharedPreferencesPlugin.registerWith(registrar);
  registrar.registerMessageHandler();
}
```

**Verification on disk**:

```bash
find .dart_tool -name "web_plugin_registrant.dart" -exec cat {} \;
# Must list all four .registerWith(...) lines above. If only
# SharedPreferencesPlugin is present, you have this bug.
```

**Verification in deployed bundle** (dart2js minifies, but the
class name `FirebaseAuthWeb` is retained as a runtime-type string
for our defensive check):

```bash
curl -sL https://yswords.netlify.app/main.dart.js \
  | grep -o "FirebaseAuthWeb" | head -1
# Should print: FirebaseAuthWeb
# If empty, the build shipped without the web plugin.
```

**Fix path** — two layers, both shipped:

1. **Immediate** (manual recovery):

   ```bash
   flutter clean
   flutter pub get        # regenerates web_plugin_registrant.dart
   flutter build web --release
   ```

   Verify the registrant on disk before deploying. The `flutter clean`
   is the critical step — `pub get` alone won't always rewrite a
   cached registrant.

2. **Permanent** (commit `3222acd`, May 2026):
   `CloudAuthService._doInit()` self-registers all three Firebase web
   delegates via their `registerWith()` methods, guarded by a
   `runtimeType.toString() != 'FirebaseAuthWeb'` check so we don't
   double-register when the auto-registrant DID run. `registerWith`
   is idempotent so it's safe in both cases. This means a future
   stale `.dart_tool` cannot resurface the bug — Firebase web
   delegates will always be present at runtime.

**Why this happened**: The auto-registrant cache is keyed on a hash
that doesn't always invalidate when the dependency graph changes
under it (Flutter pub-dep upgrades, branch switches, partial
`flutter clean`). Once a registrant is generated without the
Firebase plugins for *any* reason — e.g. a transient `pub get`
failure — the cached file persists and ships with the next build
unless something explicitly invalidates it. The defensive
self-registration in `init()` makes this a non-issue going forward.

**How to keep it that way**: Don't remove the
`FirebaseAuthWeb.registerWith(...)` block from
`CloudAuthService._doInit()` even if the registrant looks correct
on disk. The whole point is that we no longer trust the registrant.

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

### F. Is the web plugin registrant intact?

```bash
find .dart_tool -name "web_plugin_registrant.dart" -exec cat {} \;
```

Must list `FirebaseCoreWeb.registerWith`, `FirebaseAuthWeb.registerWith`,
`FirebaseFirestoreWeb.registerWith`. If any are missing, `flutter clean
&& flutter pub get` regenerates it. See §9.

(For deployed builds, the defensive self-registration in `init()`
makes this less critical — but a stale registrant during *local
dev* will still bite you with the same UnimplementedError until
`init()` runs.)

### G. Test on a different network

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
- **Flutter web plugin registrant cache** — even with our defensive
  self-registration, if the registrant ever omits Firebase plugins
  the **local dev experience** will throw UnimplementedError before
  `init()` runs. If a future `flutter` upgrade changes the registrant
  format and breaks our `runtimeType.toString() != 'FirebaseAuthWeb'`
  check, sign-in will break silently. Whenever pubspec or Flutter
  major versions change, re-verify with the §9 disk + bundle checks.

---

## Change history

| Date | Commit | Failure mode | Fix |
|---|---|---|---|
| 2026-05-03 | `3222acd` | §9 stale registrant — UnimplementedError on every OAuth call | Self-register Firebase web delegates in `init()`, idempotently |
| 2026-05-03 | `ebd1e92` | Popup succeeds but `_user` stays null | Manually mirror `cred.user` into notifier after `signInWithPopup` returns |
| 2026-05-03 | (this doc) | – | Added §9, §F.G, change history |
| 2026-05-01 | `c147cfe` | §1 popup-closed-by-user / Safari third-party cookies | Redirect fallback + retryable-as-redirect codes |
| 2026-04-28 | – | §2 currentUser null-check | try/catch around `auth.currentUser` |
| 2026-04-15 | – | §6 channel-error / Pigeon | Force `FirebaseCoreWeb` delegate in init |
