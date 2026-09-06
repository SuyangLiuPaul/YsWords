import 'dart:async' show StreamSubscription, TimeoutException;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;

import 'package:yswords/firebase_options.dart';
import 'package:yswords/services/profile_service.dart';
// 2026-05-20 (v1.2.67 follow-up): the v1.2.49 "self-register
// Firebase web plugins" block (lines ~177-224 below) used to
// `import 'package:cloud_firestore_web/...'`, etc. directly,
// which transitively pulls in `dart:ui_web` and breaks the
// iOS / Android compile. All the web-only imports + the
// registration body now live in `web_plugin_registrants_web.dart`;
// the native build resolves to a no-op stub. Web behaviour is
// byte-for-byte identical.
import 'package:yswords/services/web_plugin_registrants.dart'
    show registerWebPluginsIfNeeded;

/// Result of a sign-in / sign-up attempt. Carries either the
/// authenticated [User] or a friendly [errorMessage] suitable for
/// displaying directly in a SnackBar / form field.
///
/// 2026-09-06 (email/password sign-in): gained [errorCode]. The
/// pre-existing Google paths only ever needed one English sentence in
/// a SnackBar, so a pre-formatted [errorMessage] was enough. The email
/// form has to say six different things in three locales AND decide
/// whether to surface the password-reset escape hatch, and neither of
/// those decisions can be made by string-matching an English sentence.
/// The raw FirebaseAuth code travels to the UI, which localises it via
/// [messageKeyForCode]. [errorMessage] is kept and still populated so
/// every existing call site compiles and behaves identically.
class CloudAuthResult {
  final User? user;
  final String? errorMessage;

  /// Raw FirebaseAuth error code (`wrong-password`, `invalid-email`,
  /// …) or one of this class's own `yswords/*` sentinels. Null on
  /// success and on the legacy paths that never set it.
  final String? errorCode;

  bool get isOk => user != null;
  const CloudAuthResult.ok(this.user)
      : errorMessage = null,
        errorCode = null;
  const CloudAuthResult.error(this.errorMessage, {this.errorCode})
      : user = null;
}

/// Result of an auth action that produces no [User] — today that is
/// only "send a password-reset email". [CloudAuthResult] cannot model
/// it, because its `isOk` is defined as `user != null` and a
/// successful reset has no user to return.
class CloudAuthActionResult {
  final bool isOk;
  final String? errorCode;
  const CloudAuthActionResult.ok()
      : isOk = true,
        errorCode = null;
  const CloudAuthActionResult.error(this.errorCode) : isOk = false;
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
  // 2026-05-10 (v1.2.21): track the userChanges() subscription so
  // `retryInit()` can cancel the previous one before opening a
  // fresh stream. Without this, every Retry on the cloud-init
  // failure surface added another permanent listener — typically
  // bounded (1-3 retries per session) but still leaky.
  StreamSubscription<User?>? _userChangesSub;
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

  // ===================================================================
  // Lazy init — 2026-09-06, the mechanism that lets the China build
  // ship sign-in without paying for it at boot.
  // ===================================================================

  /// Upper bound on [ensureInitialized]. `_doInit` makes several
  /// awaited network calls to Google-owned hosts; on a network that
  /// silently blackholes them the browser's own TCP/TLS timeout is far
  /// longer than any reader will wait. A tap that produces a spinner
  /// which never resolves is worse than no button at all, so this is
  /// deliberately short enough to fail in front of the reader while
  /// they still remember pressing it.
  static const Duration kLazyInitTimeout = Duration(seconds: 12);

  /// Upper bound on a single email/password operation once Firebase
  /// is up. Same reasoning as [kLazyInitTimeout]; a little longer
  /// because by this point we know the host answered at least once.
  static const Duration kAuthOpTimeout = Duration(seconds: 20);

  /// Sentinel codes this service raises itself. Namespaced so they can
  /// never collide with a real FirebaseAuth code.
  static const String codeUnavailable = 'yswords/auth-unavailable';
  static const String codeTimeout = 'yswords/timeout';
  static const String codeMissingEmail = 'yswords/missing-email';
  static const String codeMissingPassword = 'yswords/missing-password';

  Future<bool>? _initInFlight;

  /// Initialise Firebase **on demand**, and report whether it worked.
  ///
  /// [init] is called from `main()` only when `!kChinaMode`, because
  /// the China build must not pay Firebase latency at boot (see
  /// `build_flags.dart`). That left China-build readers with no route
  /// to an account at all. This is the other half: the sign-in form
  /// calls it the moment the reader actually asks to sign in, so the
  /// cost is paid by the person who asked for it and by nobody else.
  ///
  /// Idempotent, and safe against double-taps: concurrent callers
  /// share one in-flight future rather than starting a second
  /// `Firebase.initializeApp`.
  ///
  /// Returns true when [isConfigured] ended up true. On timeout the
  /// underlying `_doInit` is left running (it may still land and flip
  /// `isConfigured` later, which every UI picks up through
  /// [ChangeNotifier]) but this future completes false so the caller
  /// can say something honest instead of spinning.
  Future<bool> ensureInitialized({Duration? timeout}) {
    if (_ready && _configured) return Future<bool>.value(true);
    final inFlight = _initInFlight;
    if (inFlight != null) return inFlight;
    final future = _doInit()
        .timeout(timeout ?? kLazyInitTimeout)
        .then((_) => _configured)
        .catchError((Object e) {
      // A TimeoutException here is not a bug and not something the
      // reader can act on beyond "try again" — record it the same way
      // a failed init is recorded so Settings' existing error surface
      // stays truthful, and let the caller show the friendly sentence.
      _initError ??= '[lazy-init] $e';
      return false;
    }).whenComplete(() {
      _initInFlight = null;
    });
    _initInFlight = future;
    return future;
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

  /// Web Firebase options with `authDomain` pointed at the CURRENT
  /// origin instead of the project default `ysword.firebaseapp.com`.
  ///
  /// 2026-08-02: this is the client half of Firebase's documented
  /// Option 3 for apps not hosted on Firebase Hosting —
  /// https://firebase.google.com/docs/auth/web/redirect-best-practices
  /// The server half is the `/__/auth/*` reverse proxy in netlify.toml;
  /// the two only work as a pair. Pointing authDomain at our own
  /// origin makes the sign-in helper same-origin with the app, which
  /// removes the third-party storage access that browsers began
  /// blocking in 2024 and that was silently losing the credential on
  /// the way back from Google (getRedirectResult() → null user).
  ///
  /// Derived at runtime rather than baked in because dev, qat and prod
  /// all ship from ONE build (see tools/release_web.sh), so there is no
  /// single correct compile-time value.
  ///
  /// localhost is deliberately left on the default firebaseapp.com
  /// authDomain: `flutter run -d chrome` has no Netlify in front of it
  /// to serve the proxy, so an origin-based authDomain would 404 the
  /// handler. Local dev keeps working the way it always has.
  FirebaseOptions _webOptions() {
    const base = DefaultFirebaseOptions.web;
    final host = Uri.base.host;
    if (host == 'localhost' || host == '127.0.0.1') return base;
    return FirebaseOptions(
      apiKey: base.apiKey,
      appId: base.appId,
      messagingSenderId: base.messagingSenderId,
      projectId: base.projectId,
      authDomain: Uri.base.authority,
      storageBucket: base.storageBucket,
      measurementId: base.measurementId,
      databaseURL: base.databaseURL,
    );
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
      // 2026-05-21 (v1.2.68 → revised): native builds now ship
      // platform-specific Firebase config:
      //   • iOS    — ios/Runner/GoogleService-Info.plist
      //              (added to Xcode project's Runner target
      //              Resources phase; Firebase.initializeApp()
      //              with NO options auto-loads it via the
      //              FirebaseApp.configure() pattern in the
      //              native iOS SDK)
      //   • Android — android/app/google-services.json
      //               (read by the com.google.gms.google-services
      //               gradle plugin in android/app/build.gradle.kts;
      //               Firebase.initializeApp() with NO options
      //               auto-loads from generated FirebaseInitProvider)
      // Web still uses DefaultFirebaseOptions.web because the
      // generated-from-FlutterFire pattern doesn't apply to web —
      // we hand-wrote the web options in firebase_options.dart.
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
        // 2026-05-20 (v1.2.67): the full registration body —
        // FirebaseCoreWeb.registerWith / FirebaseAuthWeb /
        // FirebaseFirestoreWeb / FirebaseDatabaseWeb — moved to
        // lib/services/web_plugin_registrants_web.dart so the
        // native compile path doesn't pull in `dart:ui_web` via
        // those packages. Same belt-and-braces behaviour as
        // v1.2.49 — idempotent, safe to call when the auto-
        // registrant already ran.
        registerWebPluginsIfNeeded();
      }
      // 2026-08-03: step-by-step print()s (not debugPrint — silenced
      // in release) added to pin down a report of the whole init
      // silently never completing (no FAILED log either, so not an
      // exception — a hang on some awaited step before
      // getRedirectResult, which already had its own logging).
      // ignore: avoid_print
      print('[CloudAuthService] step=$step starting Firebase.initializeApp');
      step = 'Firebase.initializeApp';
      // 2026-05-21 (v1.2.68): use DefaultFirebaseOptions.web on web,
      // but on native (iOS / Android) pass NO options so the native
      // SDK auto-loads from the platform config file (GoogleService-
      // Info.plist on iOS, google-services.json on Android via the
      // gradle plugin). Calling initializeApp with the web options
      // on iOS crashed with `'com.firebase.core': Configuration fails.
      // … invalid GOOGLE_APP_ID` because the web app's GOOGLE_APP_ID
      // doesn't match the iOS bundle.
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: _webOptions(),
        );
      } else {
        await Firebase.initializeApp();
      }
      // ignore: avoid_print
      print('[CloudAuthService] Firebase.initializeApp done, authDomain=${kIsWeb ? _webOptions().authDomain : "n/a"}');
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
      // Cancel any prior subscription from a previous retryInit
      // pass. v1.2.21: was untracked → every retry leaked another
      // permanent listener.
      _userChangesSub?.cancel();
      _userChangesSub = auth.userChanges().listen((u) {
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
        // 2026-08-02: use print(), not debugPrint() — debugPrint is
        // silenced in release builds (see release_web.sh /
        // main.dart's kReleaseMode gate), so every debugPrint() in
        // this block was invisible in exactly the deployed build
        // where redirect sign-in needed diagnosing. print() survives
        // release (same reasoning as the catch-all handler below).
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
              // ignore: avoid_print
              print(
                  '[CloudAuthService] captured Drive access token from redirect result');
            }
            // ignore: avoid_print
            print('[CloudAuthService] picked up redirect sign-in for ${pending.user!.email}');
            // 2026-08-02 (redirect-primary refactor): the popup path's
            // signInWithGoogleAndAdoptProfile() always ran profile
            // adoption (match-or-create a local Profile by the Google
            // display name) right after a successful sign-in. This
            // getRedirectResult() branch never did — a minor gap while
            // redirect was only a rare popup-blocked fallback, but a
            // first-class bug now that redirect is the ONLY web sign-in
            // path: every web sign-in would authenticate with Firebase
            // but silently stay on whatever local profile (usually
            // Guest) was active before. Call the same adoption logic
            // here too.
            // ignore: unawaited_futures
            _adoptProfileFor(pending.user!);
          } else {
            // 2026-08-02: diagnose the "redirected back but still
            // shows signed out" report. getRedirectResult() returning
            // a null user is indistinguishable, from the public API
            // alone, between "no redirect was pending" (the normal
            // case on almost every page load) and "a redirect WAS
            // pending but its result was lost" (third-party-storage
            // restrictions breaking the ysword.firebaseapp.com
            // authDomain hop — see docs/google-signin-troubleshooting.md
            // §1, §3). Logging auth.currentUser right after tells them
            // apart: if Firebase's own session restore (independent of
            // getRedirectResult, backed by IndexedDB persistence)
            // picked up a signed-in user anyway, the redirect actually
            // succeeded server-side and this is just a UI/state-sync
            // gap; if currentUser is ALSO null, the redirect genuinely
            // never completed and the fix is domain/storage-related,
            // not code.
            // ignore: avoid_print
            print('[CloudAuthService] getRedirectResult: no pending user '
                '(auth.currentUser=${auth.currentUser?.email ?? "null"})');
          }
        } catch (e) {
          // ignore: avoid_print
          print('[CloudAuthService] getRedirectResult failed: $e');
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
      // 2026-05-21 (v1.2.68): same platform gate as the main
      // signInWithGoogle path — signInWithPopup is web-only.
      final cred = await _googleSignIn(provider);
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

  /// Platform-aware Google sign-in for non-web platforms.
  ///
  /// 2026-08-02 (redirect-primary refactor): web no longer calls this
  /// method as part of [signInWithGoogle] — see that method's own doc
  /// comment for the current web flow (`signInWithRedirect`, always).
  /// Requirements for web sign-in (one-time Firebase Console setup —
  /// Google provider enabled, `yswords.netlify.app` + preview-deploy
  /// URLs in Authorized domains) still apply; see
  /// `docs/google-signin-troubleshooting.md` for the full story of how
  /// web sign-in evolved (popup-primary → popup-with-redirect-fallback
  /// → redirect-primary).
  ///
  /// 2026-05-22 (v1.2.71): platform-aware Google sign-in helper. The
  /// firebase_auth macOS plugin literally returns null for
  /// `signInWithProvider` (see FLTFirebaseAuthPlugin.m line 1701:
  /// `signInWithProvider is not supported on the MacOS platform`),
  /// which the Dart side then surfaces as the "Host platform returned
  /// null value for non-null return value" error.
  ///
  /// To get a real Firebase credential on macOS we go through
  /// google_sign_in instead — it uses GIDSignIn under the hood,
  /// opens a browser, gets a Google ID token, and we exchange that
  /// for a Firebase credential via signInWithCredential. End state
  /// is identical for the rest of the app (FirebaseAuth.currentUser
  /// is populated the same way).
  ///
  /// Throws [FirebaseAuthException] with code `cancelled` when the
  /// user dismisses the macOS Google sign-in sheet.
  ///
  /// 2026-08-02: web is no longer routed through this helper for the
  /// primary sign-in flow — see [signInWithGoogle], which calls
  /// `signInWithRedirect` directly for `kIsWeb`. This method now
  /// only serves non-web platforms; it's still used by
  /// [refreshDriveAccessToken]'s (currently unreachable — see that
  /// method's doc comment) silent-popup path, which is why the web
  /// branch stays removed rather than the whole method.
  Future<UserCredential> _googleSignIn(GoogleAuthProvider provider) async {
    if (kIsWeb) {
      return FirebaseAuth.instance.signInWithPopup(provider);
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final signIn = gsi.GoogleSignIn(
        scopes: provider.scopes.isEmpty
            ? const ['email', 'profile']
            : provider.scopes,
      );
      final account = await signIn.signIn();
      if (account == null) {
        throw FirebaseAuthException(
          code: 'cancelled',
          message: 'Google sign-in cancelled by user.',
        );
      }
      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
      return FirebaseAuth.instance.signInWithCredential(credential);
    }
    // iOS / Android: ASWebAuthenticationSession-based provider flow.
    return FirebaseAuth.instance.signInWithProvider(provider);
  }

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
    // 2026-05-06: Drive scope was previously requested here for the
    // Drive-based sync. We dropped it when sync moved to Firebase
    // Realtime Database (RealtimeDbSyncService). Other users now see
    // a normal Google sign-in dialog (just email + profile) instead
    // of the more alarming "this app wants to manage your Drive
    // files" prompt — significantly better UX for a Bible-study
    // tool. The driveFileScope constant + refreshDriveAccessToken
    // are kept around in case we ever re-enable Drive as an opt-in
    // backup, but no UI requests them today.
    // Always show the chooser even if there's a single signed-in
    // Google account, so users on shared devices can pick the
    // right one.
    provider.setCustomParameters({'prompt': 'select_account'});

    // 2026-08-02 (redirect-primary refactor): web now goes straight to
    // signInWithRedirect instead of trying signInWithPopup first. This
    // used to be a fallback-only path (see _isRetryableAsRedirect,
    // removed) for the handful of browser conditions where popup
    // can't complete; it's now the ONLY web path, because strict
    // Cross-Origin-Opener-Policy (required for the crossOriginIsolated
    // context Flutter's multithreaded skwasm web renderer needs) is
    // incompatible with signInWithPopup's window.opener relationship.
    // The page navigates away here; getRedirectResult() in _doInit()
    // picks up the credential (including profile adoption via
    // _adoptProfileFor) on the next load. Non-web platforms are
    // unaffected — they never used popup on web's terms to begin
    // with (native provider flow / google_sign_in package).
    if (kIsWeb) {
      try {
        await FirebaseAuth.instance.signInWithRedirect(provider);
        return const CloudAuthResult.error('Redirecting to Google…');
      } on FirebaseAuthException catch (e) {
        return CloudAuthResult.error(_friendlyError(e));
      } catch (e) {
        return CloudAuthResult.error(e.toString());
      }
    }

    try {
      // 2026-05-21 (v1.2.68 / v1.2.71): platform-aware Google sign-in.
      // iOS / Android → signInWithProvider. macOS → google_sign_in +
      // signInWithCredential (firebase_auth's signInWithProvider is
      // hard-coded to return null on macOS — FLTFirebaseAuthPlugin.m
      // line 1701).
      final cred = await _googleSignIn(provider);
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
      // Non-web platform failure (iOS/Android provider flow, or
      // macOS google_sign_in). No redirect fallback here — that was
      // web-only machinery, now handled entirely by the kIsWeb
      // early-return above.
      return CloudAuthResult.error(_friendlyError(e));
    } catch (e) {
      return CloudAuthResult.error(e.toString());
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
    await _adoptProfileFor(result.user!);
    return result;
  }

  // ===================================================================
  // Email + password — 2026-09-06.
  //
  // SECURITY, and it is short enough to have no excuse for getting
  // wrong: the password reaches exactly one place, the FirebaseAuth
  // SDK call it is an argument to. It is never printed, never
  // persisted, never put in an error string, never sent anywhere else,
  // and never trimmed (trimming would silently change the credential).
  // `test/email_auth_service_test.dart` reads this file back and fails
  // if a logging call in it ever mentions a password.
  // ===================================================================

  /// Create a new account, then run the same local-profile
  /// reconciliation the Google path runs.
  ///
  /// On `email-already-in-use` the caller must NOT try to work out
  /// which provider owns the address. See [isAccountCollision].
  Future<CloudAuthResult> createAccountWithEmailAndAdoptProfile({
    required String email,
    required String password,
    Duration? timeout,
  }) {
    return _emailCall(
      email: email,
      password: password,
      timeout: timeout,
      run: (auth, trimmedEmail) => auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      ),
    );
  }

  /// Sign in with an existing email/password account, then run the
  /// same local-profile reconciliation the Google path runs — so an
  /// email reader lands on the same local [Profile] rather than in a
  /// second notion of identity.
  Future<CloudAuthResult> signInWithEmailAndAdoptProfile({
    required String email,
    required String password,
    Duration? timeout,
  }) {
    return _emailCall(
      email: email,
      password: password,
      timeout: timeout,
      run: (auth, trimmedEmail) => auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      ),
    );
  }

  /// Shared body of the two calls above: validate locally, make sure
  /// Firebase is up (lazily — this is the China build's only route),
  /// run the SDK call under a bound, adopt the local profile.
  /// Normalise a typed email address before it reaches Firebase.
  ///
  /// Trim only. Deliberately NOT lower-cased: the local part of an
  /// address is case-sensitive by RFC and Firebase does its own
  /// canonicalisation; folding it here would be this app inventing a
  /// second, disagreeing rule.
  ///
  /// Pulled out as a named static because the corresponding
  /// *non*-treatment of the password is the security-relevant half,
  /// and a rule you can point at is easier to keep than one inlined
  /// in three call sites.
  static String normalizeEmail(String email) => email.trim();

  Future<CloudAuthResult> _emailCall({
    required String email,
    required String password,
    required Duration? timeout,
    required Future<UserCredential> Function(FirebaseAuth, String) run,
  }) async {
    final trimmedEmail = normalizeEmail(email);
    if (trimmedEmail.isEmpty) {
      return const CloudAuthResult.error(
        'Enter your email address.',
        errorCode: codeMissingEmail,
      );
    }
    // NOT trimmed. A leading or trailing space is a legitimate part of
    // a password and silently stripping it would make an account
    // unopenable by the credential that created it.
    if (password.isEmpty) {
      return const CloudAuthResult.error(
        'Enter your password.',
        errorCode: codeMissingPassword,
      );
    }
    if (!await ensureInitialized()) {
      return const CloudAuthResult.error(
        'Sign-in is unavailable right now.',
        errorCode: codeUnavailable,
      );
    }
    try {
      final cred = await run(FirebaseAuth.instance, trimmedEmail)
          .timeout(timeout ?? kAuthOpTimeout);
      final user = cred.user;
      if (user == null) {
        // Should not happen on these two APIs, but a null here would
        // otherwise render as a silent no-op button.
        return const CloudAuthResult.error(
          'Sign-in did not complete.',
          errorCode: codeUnavailable,
        );
      }
      // Mirror into the notifier immediately rather than waiting for
      // userChanges() — same reason as the Google popup path: the
      // stream can be delayed or suppressed by browser storage
      // partitioning, and the UI must not keep reading "signed out"
      // after a successful sign-in.
      _user = user;
      notifyListeners();
      await _adoptProfileFor(user);
      return CloudAuthResult.ok(user);
    } on FirebaseAuthException catch (e) {
      return CloudAuthResult.error(_friendlyError(e), errorCode: e.code);
    } on TimeoutException {
      return const CloudAuthResult.error(
        'Timed out.',
        errorCode: codeTimeout,
      );
    } catch (e) {
      return CloudAuthResult.error(e.toString(), errorCode: codeUnavailable);
    }
  }

  /// Send a password-reset email to [email].
  ///
  /// This is the single escape hatch behind both rulings recorded in
  /// `docs/HANDOVER-2026-09-06.md`:
  ///
  ///   • **Account collision.** A reset on a Google-only Firebase
  ///     account ADDS a password credential to that same UID — same
  ///     account, same data, both methods work afterwards. So the app
  ///     never needs to know which provider already owns the address,
  ///     the copy names no provider, and email-enumeration protection
  ///     stays ON.
  ///   • **Sign-in.** With enumeration protection on, a Google-only
  ///     account that is handed a password gets a generic
  ///     `invalid-credential`, indistinguishable from a typo. The
  ///     reset offer therefore has to be visible on that error rather
  ///     than buried.
  ///
  /// Deliberately reports success without asking whether the address
  /// exists — telling the reader "no such user" is the enumeration
  /// leak the protection exists to close. `user-not-found` is mapped
  /// to success for the same reason.
  Future<CloudAuthActionResult> sendPasswordResetEmail(
    String email, {
    Duration? timeout,
  }) async {
    final trimmedEmail = normalizeEmail(email);
    if (trimmedEmail.isEmpty) {
      return const CloudAuthActionResult.error(codeMissingEmail);
    }
    if (!await ensureInitialized()) {
      return const CloudAuthActionResult.error(codeUnavailable);
    }
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: trimmedEmail)
          .timeout(timeout ?? kAuthOpTimeout);
      return const CloudAuthActionResult.ok();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return const CloudAuthActionResult.ok();
      }
      return CloudAuthActionResult.error(e.code);
    } on TimeoutException {
      return const CloudAuthActionResult.error(codeTimeout);
    } catch (_) {
      return const CloudAuthActionResult.error(codeUnavailable);
    }
  }

  /// True for the two codes that mean "this address already has an
  /// account, by some method". Per the 2026-09-06 ruling the app does
  /// **not** detect which method and does **not** build account
  /// linking — the answer is identical either way.
  static bool isAccountCollision(String? code) =>
      code == 'email-already-in-use' ||
      code == 'account-exists-with-different-credential';

  /// True when the UI must surface the password-reset button on this
  /// error. Covers the collision codes plus every "that didn't open
  /// the account" code — including the generic `invalid-credential`
  /// that enumeration protection collapses a Google-only account and
  /// a plain typo into.
  static bool shouldOfferPasswordReset(String? code) =>
      isAccountCollision(code) ||
      code == 'invalid-credential' ||
      // Firebase's newer identity-platform backends return this
      // spelling for the same collapsed case.
      code == 'invalid-login-credentials' ||
      code == 'wrong-password' ||
      code == 'user-not-found';

  /// Fallback `ui_strings` key for a code with no specific sentence.
  static const String authErrorFallbackKey = 'authErrGeneric';

  /// Map a FirebaseAuth code (or one of this class's own sentinels)
  /// onto a `ui_strings` key, so the reader gets a sentence in their
  /// own locale rather than a machine code.
  ///
  /// Lives here, next to the codes, rather than in the widget: the
  /// widget is not the only surface that will ever need it, and a
  /// pure function is the only part of this file a test without a
  /// Firebase backend can genuinely exercise.
  static String messageKeyForCode(String? code) {
    switch (code) {
      case 'wrong-password':
        return 'authErrWrongPassword';
      case 'user-not-found':
        return 'authErrUserNotFound';
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'authErrInvalidCredential';
      case 'weak-password':
        return 'authErrWeakPassword';
      case 'invalid-email':
        return 'authErrInvalidEmail';
      case 'network-request-failed':
        return 'authErrNetwork';
      case 'too-many-requests':
        return 'authErrTooManyRequests';
      case 'email-already-in-use':
      case 'account-exists-with-different-credential':
        return 'authErrEmailInUse';
      case 'user-disabled':
        return 'authErrUserDisabled';
      case 'operation-not-allowed':
        return 'authErrEmailNotEnabled';
      case 'missing-password':
      case codeMissingPassword:
        return 'authErrMissingPassword';
      case codeMissingEmail:
        return 'authErrMissingEmail';
      case codeTimeout:
        return 'authErrTimeout';
      case codeUnavailable:
        return 'authErrInitUnavailable';
    }
    return authErrorFallbackKey;
  }

  /// Match-or-create a local [Profile] by the signed-in Google
  /// account's display name (falling back to the email prefix), and
  /// switch to it. Shared by every path that lands a successful
  /// Google sign-in: the synchronous popup/native-provider success
  /// path above, and the web `getRedirectResult()` handler in
  /// [_doInit] — redirect completes on a fresh page load, so it can't
  /// return a result inline the way popup does, but the user still
  /// needs the same profile reconciliation.
  Future<void> _adoptProfileFor(User user) async {
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
