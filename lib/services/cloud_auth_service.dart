import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_web/cloud_firestore_web.dart'
    show FirebaseFirestoreWeb;
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    show FirebaseAuthPlatform;
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_web/firebase_auth_web.dart' show FirebaseAuthWeb;
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart'
    show FirebasePlatform;
// ignore: depend_on_referenced_packages
import 'package:firebase_core_web/firebase_core_web.dart' show FirebaseCoreWeb;
import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/flutter_web_plugins.dart' show webPluginRegistrar;

import 'package:yswords/firebase_options.dart';
import 'package:yswords/services/profile_service.dart';

/// Result of a sign-in / sign-up attempt. Carries either the
/// authenticated [User] or a friendly [errorMessage] suitable for
/// displaying directly in a SnackBar / form field.
class CloudAuthResult {
  final User? user;
  final String? errorMessage;
  bool get isOk => user != null;
  const CloudAuthResult.ok(this.user) : errorMessage = null;
  const CloudAuthResult.error(this.errorMessage) : user = null;
}

/// Wraps Firebase Auth with a clear `isConfigured` gate so the app
/// keeps booting (and falls back to local-only profiles) when the
/// user hasn't set up a Firebase project yet.
///
/// All methods are no-ops when [isConfigured] is false — UIs check
/// it before showing any cloud affordance.
class CloudAuthService extends ChangeNotifier {
  static final CloudAuthService instance = CloudAuthService._();
  CloudAuthService._();

  bool _ready = false;
  bool _configured = false;
  String? _initError;
  User? _user;

  /// OAuth access token captured during the most recent Google sign-in
  /// — used by DriveSyncService to call the Drive REST API on the
  /// user's behalf without requiring them to set up anything in
  /// Google Cloud. Lives in memory only (don't persist; can be
  /// re-acquired via [refreshDriveAccessToken] which trigger
  /// a silent popup with `prompt:''` so Google skips the consent
  /// dialog when the user already granted the scope).
  String? _driveAccessToken;
  DateTime? _driveTokenExpiresAt;

  /// Drive scope — `drive.file` instead of `drive.appdata` so the
  /// sync file is **visible** in the user's My Drive (a single
  /// `YsWords.json` at the root). Per-file scope: app can only see
  /// files it created or files the user explicitly opened via a
  /// Drive picker, NOT arbitrary user files. Same sensitivity tier
  /// as `drive.appdata` for OAuth-consent verification purposes.
  ///
  /// Why visible (`drive.file`) over hidden (`drive.appdata`):
  /// the user explicitly wanted to see "YsWords" in their Drive
  /// rather than have an invisible app-private blob. Trade-off: the
  /// user can manually delete the file (which would reset sync) but
  /// they always know what data the app is storing on their behalf.
  static const String driveFileScope =
      'https://www.googleapis.com/auth/drive.file';

  /// Backwards-compat alias — kept so existing call sites that
  /// imported `driveAppDataScope` keep compiling. New code should
  /// use [driveFileScope].
  @Deprecated('Use driveFileScope instead — switched 2026-05')
  static const String driveAppDataScope = driveFileScope;

  /// Latest captured Drive OAuth access token, or null if we don't
  /// have one (never signed in, or expired). Caller should call
  /// [refreshDriveAccessToken] when it gets a 401 from Drive.
  String? get driveAccessToken {
    if (_driveAccessToken == null) return null;
    final exp = _driveTokenExpiresAt;
    if (exp != null && DateTime.now().isAfter(exp)) return null;
    return _driveAccessToken;
  }

  bool get hasDriveAccessToken => driveAccessToken != null;

  /// True once [init] has finished (regardless of success/failure).
  bool get ready => _ready;

  /// True only when both the Firebase config has real values and
  /// `Firebase.initializeApp` succeeded. When false but
  /// [firebaseConfigured] is true, [initError] explains why init
  /// failed. UIs should still surface the Google sign-in affordance
  /// (disabled, with [initError] as the reason + a Retry button) so
  /// a transient init failure doesn't silently hide the whole
  /// account section.
  bool get isConfigured => _configured;

  /// Whether this build has Firebase project credentials filled in
  /// (regardless of whether init succeeded). UIs use this to decide
  /// whether to show the cloud-sync surface at all — if false, the
  /// app is a local-only build and there's nothing to retry.
  bool get hasFirebaseCredentials => firebaseConfigured;

  /// Last error message from [init] (or [retryInit]). Null when
  /// init succeeded. Format is whatever Firebase / dart:js threw —
  /// surfaced to UI so the user can see *why* sign-in is disabled.
  String? get initError => _initError;

  /// Currently signed-in cloud user, or null if not signed in
  /// (or Firebase isn't configured).
  User? get currentUser => _user;
  bool get isSignedIn => _user != null;

  /// Initialise Firebase if config has been filled in. Safe to call
  /// from main(); on misconfiguration logs a debug message and
  /// returns without throwing.
  Future<void> init() async {
    if (_ready && _configured) return;
    await _doInit();
  }

  /// Re-run init after a transient failure. Wired to a "Retry" button
  /// on Settings so users aren't stuck if the first attempt failed
  /// due to a network blip or a momentarily-revoked API key.
  Future<void> retryInit() async {
    _ready = false;
    _configured = false;
    _initError = null;
    notifyListeners();
    await _doInit();
  }

  Future<void> _doInit() async {
    // Step-by-step init so we can pinpoint WHICH operation failed —
    // initializeApp, FirebaseAuth.instance access, or userChanges()
    // — instead of lumping them under one opaque error string.
    String step = 'init';
    try {
      if (!firebaseConfigured) {
        // Stub config — leave _configured false so the rest of the
        // app stays on local-only profiles. No network calls.
        _initError = null;
        return;
      }
      // Force FirebaseCoreWeb to be the platform delegate before
      // calling initializeApp. The auto-generated web plugin
      // registrant should already do this, but in some builds (we've
      // seen this with the firebase_core 4.x family) the dart2js
      // tree-shake or the registrant ordering leaves
      // FirebasePlatform.instance at the default MethodChannelFirebase
      // — which then throws PlatformException(channel-error, ...
      // FirebaseCoreHostApi.initializeCore) because there's no
      // Pigeon receiver on web.
      //
      // Setting BOTH FirebasePlatform.instance AND
      // Firebase.delegatePackingProperty (the lazy cache inside
      // firebase_core) guarantees the web delegate is used regardless
      // of registrant timing.
      if (kIsWeb) {
        step = 'web plugin registrants';
        // Belt-and-braces: register every Firebase web delegate
        // ourselves. Flutter's generated `web_plugin_registrant.dart`
        // is supposed to do this on app boot, but the file is *cached*
        // in `.dart_tool/flutter_build/<hash>/` and we've seen builds
        // ship with a stale cache where only `SharedPreferencesPlugin`
        // got registered — leaving `FirebaseAuthPlatform.instance` at
        // the default `MethodChannelFirebaseAuth`, which throws
        // `UnimplementedError: signInWithPopup() is only supported on
        // web based platforms` for every OAuth call. The symptom on
        // production was Google sign-in silently failing in iOS PWA
        // and Chrome alike. Re-registering here is idempotent — each
        // plugin's `registerWith` is safe to call again — so we're
        // safe even when the cache *did* run.
        try {
          if (FirebasePlatform.instance is! FirebaseCoreWeb) {
            FirebaseCoreWeb.registerWith(webPluginRegistrar);
          } else {
            // Auto-registrant already wired things up — clear the
            // lazy delegate cache so Firebase picks up the live one.
            // ignore: invalid_use_of_visible_for_testing_member
            Firebase.delegatePackingProperty = FirebasePlatform.instance;
          }
          if (FirebaseAuthPlatform.instance.runtimeType.toString() !=
              'FirebaseAuthWeb') {
            FirebaseAuthWeb.registerWith(webPluginRegistrar);
          }
          // Firestore: cheap to re-register; ensures the web delegate
          // is the one Firestore uses for Channel transport.
          FirebaseFirestoreWeb.registerWith(webPluginRegistrar);
        } catch (e) {
          // Soft-fail: if registration throws because the plugin is
          // already wired and the setter verification trips, fall
          // through. We'd rather report the *real* downstream error
          // (initializeApp etc.) than mask it with this one.
          debugPrint('CloudAuthService: web registrant setup: $e');
        }
      }
      step = 'Firebase.initializeApp';
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.web,
      );
      // Tell Firestore to auto-detect when the WebChannel transport
      // is being blocked (some browser extensions, corporate
      // proxies, mobile carrier networks) and fall back to long-
      // polling. Without this, set() can hang indefinitely and the
      // user sees a generic 30 s timeout with no clue why. This has
      // to be set BEFORE any Firestore call — doing it right after
      // initializeApp is the canonical place.
      if (kIsWeb) {
        try {
          step = 'Firestore.settings';
          FirebaseFirestore.instance.settings = const Settings(
            webExperimentalAutoDetectLongPolling: true,
          );
        } catch (e) {
          // Settings can only be set once per app instance. If we
          // somehow get here twice (hot-restart in dev) the second
          // assignment throws — non-fatal, the first one stuck.
          debugPrint('CloudAuthService: Firestore settings: $e');
        }
      }
      step = 'FirebaseAuth.instance';
      final auth = FirebaseAuth.instance;
      step = 'FirebaseAuth.currentUser';
      // firebase_auth_web has been observed to throw 'Null check
      // operator used on a null value' from inside `currentUser`
      // when the persisted JS auth state is corrupted (browser
      // privacy mode, blocked localStorage, ad-blocker resetting
      // IndexedDB). Treat that as "no current user" instead of
      // letting it mark the whole init as failed — the userChanges
      // stream below will deliver the real user once the SDK
      // settles, OR the user can sign in fresh.
      try {
        _user = auth.currentUser;
      } catch (e, st) {
        debugPrint('CloudAuthService: currentUser threw, treating as null: $e\n$st');
        _user = null;
      }
      step = 'FirebaseAuth.userChanges';
      // Reflect future sign-in / sign-out events into our notifier.
      // Same defensive try/catch on each emission — once we've seen
      // currentUser misbehave, individual stream events can also
      // arrive in weird shapes. We never want a single bad event to
      // break the listener for the rest of the session.
      auth.userChanges().listen((u) {
        try {
          _user = u;
          notifyListeners();
        } catch (e) {
          debugPrint('CloudAuthService: userChanges handler error: $e');
        }
      }, onError: (Object e) {
        debugPrint('CloudAuthService: userChanges stream error: $e');
      });
      // Pick up any pending sign-in result from a redirect flow that
      // ran on the previous page load. Without this, the redirect
      // fallback in signInWithGoogle() would lose the credential
      // (page navigates back from Google but nothing reads the
      // stashed result). Soft-fail — most loads have no pending
      // redirect and getRedirectResult returns a null user; we only
      // care about the success path.
      if (kIsWeb) {
        step = 'FirebaseAuth.getRedirectResult';
        try {
          final pending = await auth.getRedirectResult();
          if (pending.user != null) {
            _user = pending.user;
            // 2026-05 fix: also capture the Drive OAuth access token
            // from the redirect result — same as the popup path does.
            // Missing this meant Safari/PWA users (which fall back to
            // redirect signin) signed in successfully but Drive sync
            // immediately reported "Reconnect Google Drive" because
            // _driveAccessToken was never populated.
            final c = pending.credential;
            if (c is OAuthCredential && c.accessToken != null) {
              _driveAccessToken = c.accessToken;
              _driveTokenExpiresAt =
                  DateTime.now().add(const Duration(minutes: 55));
              debugPrint(
                  'CloudAuthService: captured Drive access token from redirect result');
            }
            debugPrint('CloudAuthService: picked up redirect sign-in for ${pending.user!.email}');
          }
        } catch (e) {
          debugPrint('CloudAuthService: getRedirectResult skipped: $e');
        }
      }
      _configured = true;
      _initError = null;
    } catch (e, st) {
      // Both debugPrint and stderr — Flutter web's console.error shows
      // up red in DevTools, easier for the user to copy/paste back.
      // ignore: avoid_print
      print('[CloudAuthService] FAILED at step=$step :: $e');
      // ignore: avoid_print
      print('[CloudAuthService] stack: $st');
      debugPrint('CloudAuthService._doInit failed at step=$step: $e\n$st');
      _configured = false;
      _initError = '[$step] ${e.runtimeType}: $e';
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  /// Sign out from Firebase Auth. Doesn't touch local profiles —
  /// the user stays on the same local profile, just without cloud
  /// sync until they sign back in.
  Future<void> signOut() async {
    if (!_configured) return;
    _driveAccessToken = null;
    _driveTokenExpiresAt = null;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('signOut failed: $e');
    }
  }

  /// Re-acquire the Drive OAuth access token without requiring user
  /// interaction (most of the time). Uses a silent popup with
  /// `prompt:''` — Google skips the consent screen when the user has
  /// already granted the requested scopes, so the popup closes
  /// almost instantly. Falls back to a normal popup if the silent
  /// path fails (e.g. user revoked the grant from their Google
  /// account settings).
  ///
  /// Called by DriveSyncService when:
  /// 1. App boots with a signed-in user but no in-memory access
  ///    token (we don't persist it across reloads for safety).
  /// 2. A Drive REST call returns 401 (token expired).
  ///
  /// Returns true on success, false when even the interactive popup
  /// failed — caller surfaces "Reconnect Google Drive" UI.
  Future<bool> refreshDriveAccessToken({bool interactive = false}) async {
    if (!_configured) return false;
    if (!isSignedIn) return false;
    final provider = GoogleAuthProvider();
    provider.addScope('email');
    provider.addScope('profile');
    provider.addScope(driveFileScope);
    // `prompt: ''` (empty) lets Google skip the consent screen when
    // the user already granted these scopes. Switch to `consent` for
    // forced re-consent (interactive=true means user explicitly hit
    // "Reconnect Drive").
    provider.setCustomParameters({
      'prompt': interactive ? 'consent' : '',
      // Hint to silently use the currently-signed-in user without
      // showing the account picker.
      if (currentUser?.email != null) 'login_hint': currentUser!.email!,
    });
    try {
      final cred = await FirebaseAuth.instance.signInWithPopup(provider);
      final c = cred.credential;
      if (c is OAuthCredential && c.accessToken != null) {
        _driveAccessToken = c.accessToken;
        _driveTokenExpiresAt =
            DateTime.now().add(const Duration(minutes: 55));
        notifyListeners();
        // ignore: avoid_print
        print(
            '[CloudAuth] refreshDriveAccessToken (interactive=$interactive): '
            'OK, captured ${c.accessToken!.length} chars');
        return true;
      }
      // ignore: avoid_print
      print(
          '[CloudAuth] refreshDriveAccessToken (interactive=$interactive): '
          'no accessToken in credential. cred type=${c?.runtimeType}');
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('[CloudAuth] refreshDriveAccessToken failed: $e');
      debugPrint('refreshDriveAccessToken failed: $e');
      return false;
    }
  }

  /// Sign in with Google via Firebase's web flow.
  ///
  /// **Two-tier strategy** — see `docs/google-signin-troubleshooting.md`
  /// for the full story:
  ///
  /// 1. **Popup** (`signInWithPopup`) is tried first. Fast, in-place,
  ///    no navigation. Works in most desktop browsers.
  ///
  /// 2. **Redirect** (`signInWithRedirect`) is the fallback when
  ///    popup fails for any reason that suggests it CAN'T succeed
  ///    on this browser — popup-blocker, third-party cookies blocked
  ///    (Safari especially in PWA mode), web-storage unsupported, or
  ///    any of Firebase's catch-all internal errors that historically
  ///    correlate with cross-origin handshake failures.
  ///
  ///    Redirect navigates the WHOLE PAGE to Google. After the user
  ///    consents and Google bounces back to ysword.firebaseapp.com →
  ///    yswords.netlify.app, `_doInit()` picks up the credential via
  ///    `getRedirectResult()`. This call returns BEFORE the redirect
  ///    happens; the user sees the page navigate away and the result
  ///    text "Redirecting to Google…" briefly before they're gone.
  ///
  /// Requirements (one-time, see troubleshooting doc):
  ///   1. Firebase Console → Authentication → Sign-in method →
  ///      Google → Enable.
  ///   2. Firebase Console → Authentication → Settings → Authorized
  ///      domains → must include `yswords.netlify.app` (and any
  ///      preview-deploy URLs you use).
  ///   3. The popup is initiated by a user click — modern browsers
  ///      block popups otherwise. Calling this from a button's
  ///      onPressed handler satisfies the gesture requirement.
  Future<CloudAuthResult> signInWithGoogle() async {
    if (!_configured) {
      return const CloudAuthResult.error('Cloud sync not configured.');
    }
    final provider = GoogleAuthProvider();
    // Explicit OAuth scopes — Firebase defaults are usually fine, but
    // some older client configurations omit `email`/`profile` which
    // makes the resulting User have null displayName/email and breaks
    // the local-profile reconciliation in
    // signInWithGoogleAndAdoptProfile().
    provider.addScope('email');
    provider.addScope('profile');
    // Drive AppData scope — added 2026-05 alongside the migration
    // from Firestore to Google Drive sync. Asks for write access to
    // a hidden, app-private folder in the user's Drive (NOT their
    // main Drive content). Used by `DriveSyncService` to read/write
    // the single `yswords-sync.json` file that holds highlights /
    // bookmarks / notes / reading-plan progress. The user grants
    // this once at sign-in time and never has to pick a folder —
    // `appDataFolder` is automatic.
    provider.addScope(driveFileScope);
    // Always show the chooser even if there's a single signed-in
    // Google account, so users on shared devices can pick the
    // right one.
    provider.setCustomParameters({'prompt': 'select_account'});

    // 1. Popup first.
    try {
      final cred =
          await FirebaseAuth.instance.signInWithPopup(provider);
      // Capture the Drive OAuth access token from the credential
      // object. firebase_auth_web exposes it via OAuthCredential's
      // accessToken field. Tokens are typically valid for ~1 hour;
      // we stamp an expiry so DriveSyncService can pre-emptively
      // refresh before hitting a 401. If credential is null (some
      // browsers' redirect flow doesn't carry it), we fall back to
      // refreshDriveAccessToken on first Drive call.
      final c = cred.credential;
      if (c is OAuthCredential && c.accessToken != null) {
        _driveAccessToken = c.accessToken;
        // Conservative 55-min expiry (real token is ~1 hour) so we
        // refresh slightly early.
        _driveTokenExpiresAt =
            DateTime.now().add(const Duration(minutes: 55));
        // ignore: avoid_print
        print(
            '[CloudAuth] popup signin: captured Drive access token '
            '(${c.accessToken!.length} chars)');
      } else {
        // ignore: avoid_print
        print(
            '[CloudAuth] popup signin: NO Drive access token in '
            'credential. credential type=${c?.runtimeType}, '
            'accessToken=${c is OAuthCredential ? c.accessToken : "n/a"}. '
            'Will fall back to silent-refresh on first Drive call.');
      }
      // Manually mirror the user into our notifier in case
      // `userChanges()` doesn't fire — Chrome 115+ third-party cookie
      // partitioning can prevent the auth iframe (running on
      // ysword.firebaseapp.com) from syncing IndexedDB back to the
      // host (yswords.netlify.app), so onAuthStateChanged silently
      // never fires even though the popup returned a valid
      // UserCredential. Without this, the popup closes successfully
      // but the UI keeps showing "signed out" — the symptom matching
      // the user's "Google auth not working" report after deploy.
      if (cred.user != null) {
        _user = cred.user;
        notifyListeners();
      }
      return CloudAuthResult.ok(cred.user);
    } on FirebaseAuthException catch (e) {
      // Some failure codes mean popup CAN'T complete on this browser
      // — try redirect instead. Others mean the user explicitly
      // declined or there's a config problem we shouldn't paper over.
      if (kIsWeb && _isRetryableAsRedirect(e)) {
        debugPrint('signInWithPopup failed (${e.code}); falling back to redirect.');
        try {
          await FirebaseAuth.instance.signInWithRedirect(provider);
          // Page navigates here; the credential will be captured by
          // getRedirectResult() during the next init. The line below
          // only runs in browsers that don't actually navigate (rare
          // — usually means the redirect itself was blocked).
          return const CloudAuthResult.error(
              'Redirecting to Google…');
        } on FirebaseAuthException catch (e2) {
          return CloudAuthResult.error(_friendlyError(e2));
        } catch (e2) {
          return CloudAuthResult.error(e2.toString());
        }
      }
      return CloudAuthResult.error(_friendlyError(e));
    } catch (e) {
      // Non-FirebaseAuthException failures (web-only crashes, JS
      // interop errors). Try redirect once before giving up — these
      // sometimes also indicate the popup mechanism is unhealthy.
      if (kIsWeb) {
        debugPrint('signInWithPopup non-Firebase error: $e — trying redirect.');
        try {
          await FirebaseAuth.instance.signInWithRedirect(provider);
          return const CloudAuthResult.error(
              'Redirecting to Google…');
        } catch (e2) {
          return CloudAuthResult.error(e2.toString());
        }
      }
      return CloudAuthResult.error(e.toString());
    }
  }

  /// Whether a popup failure looks like a "this browser can't do
  /// popup OAuth, retry with redirect" situation. See
  /// docs/google-signin-troubleshooting.md §1, §5.
  bool _isRetryableAsRedirect(FirebaseAuthException e) {
    switch (e.code) {
      case 'popup-blocked':            // browser popup blocker
      case 'popup-closed-by-user':     // Safari third-party-cookie
      case 'cancelled-popup-request':  // multiple-popup race
      case 'web-storage-unsupported':  // localStorage/IndexedDB blocked
      case 'internal-error':           // catch-all that often = above
      case 'network-request-failed':   // sometimes the popup window
        return true;
      default:
        return false;
    }
  }

  /// One-shot Google sign-in + local-profile reconciliation. Used by
  /// every UI surface that exposes the sign-in button (welcome page,
  /// dashboard greeting card, floating-header menu, settings →
  /// account section). Centralised so future tweaks (e.g. account-
  /// picker UX, profile-name conflict handling) only have to be
  /// made once.
  ///
  /// Returns [CloudAuthResult.ok] with the authenticated user on
  /// success — local profile is automatically created or switched
  /// to one matching the Google display name (or email prefix as
  /// fallback). On failure returns the friendly error string.
  Future<CloudAuthResult> signInWithGoogleAndAdoptProfile() async {
    final result = await signInWithGoogle();
    if (!result.isOk) return result;
    final user = result.user!;
    final svc = ProfileService.instance;
    final namePart = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email ?? 'user').split('@').first;
    final existing = svc.profiles
        .where((p) => p.name.toLowerCase() == namePart.toLowerCase());
    if (existing.isNotEmpty) {
      await svc.setCurrent(existing.first.id);
    } else {
      final p = await svc.create(namePart);
      await svc.setCurrent(p.id);
    }
    return result;
  }

  /// Map FirebaseAuth's machine codes to short, plain-English
  /// strings. Anything we don't recognise falls through to
  /// `e.message ?? code`.
  static String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts — please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error — check your connection.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Sign-in cancelled.';
      case 'popup-blocked':
        return 'Popup blocked — allow popups for this site and try again.';
      case 'unauthorized-domain':
        return 'This domain is not authorized for sign-in. '
            'Add it in Firebase → Authentication → Settings → Authorized domains.';
      case 'operation-not-allowed':
        return 'Google sign-in is not enabled on this Firebase project. '
            'Enable it in Firebase → Authentication → Sign-in method.';
    }
    return e.message ?? e.code;
  }
}
