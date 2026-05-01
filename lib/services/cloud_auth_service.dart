import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart'
    show FirebasePlatform;
// ignore: depend_on_referenced_packages
import 'package:firebase_core_web/firebase_core_web.dart' show FirebaseCoreWeb;
import 'package:flutter/foundation.dart';

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
        step = 'FirebaseCoreWeb delegate setup';
        try {
          // Only force-set the delegate if the auto-registrant didn't
          // run for any reason. Creating a NEW FirebaseCoreWeb when
          // the auto-registered one is already the active delegate
          // produces two distinct Dart-side instances, which
          // Firestore can race against (Firestore plugin uses the
          // delegate that was active at its own registerWith time)
          // and that race showed up as 30 s sync timeouts.
          if (FirebasePlatform.instance is! FirebaseCoreWeb) {
            final web = FirebaseCoreWeb();
            FirebasePlatform.instance = web;
            // ignore: invalid_use_of_visible_for_testing_member
            Firebase.delegatePackingProperty = web;
          } else {
            // Auto-registrant already wired things up — just clear
            // any previously-cached Firebase delegate so it picks
            // up the live one rather than a stale instance.
            // ignore: invalid_use_of_visible_for_testing_member
            Firebase.delegatePackingProperty = FirebasePlatform.instance;
          }
        } catch (e) {
          // Soft-fail: if for any reason instantiating FirebaseCoreWeb
          // throws (e.g. it's already wired correctly and the setter
          // verification trips), fall through and let initializeApp
          // try its luck. We'd rather report the *real* downstream
          // error than mask it with this one.
          debugPrint('CloudAuthService: web delegate setup failed: $e');
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
      _user = auth.currentUser;
      // Resolve any pending redirect sign-in from a previous page load
      // (signInWithRedirect on mobile browsers navigates away and back).
      // On desktop or when there's no pending redirect, this returns
      // null immediately.
      try {
        step = 'FirebaseAuth.getRedirectResult';
        final redirectResult = await auth.getRedirectResult();
        if (redirectResult.user != null) {
          _user = redirectResult.user;
        }
      } catch (e) {
        // Non-fatal — the redirect result may fail if no redirect
        // happened or if the credential expired. Just log and continue.
        debugPrint('CloudAuthService: getRedirectResult: $e');
      }
      step = 'FirebaseAuth.userChanges';
      // Reflect future sign-in / sign-out events into our notifier.
      auth.userChanges().listen((u) {
        _user = u;
        notifyListeners();
      });
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
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('signOut failed: $e');
    }
  }

  /// Sign in with Google via Firebase Auth.
  ///
  /// On web, uses signInWithRedirect (full-page redirect to Google
  /// then back) which works on all browsers including iOS Safari
  /// and Android Chrome. signInWithPopup does NOT work on mobile
  /// browsers (throws UnimplementedError).
  ///
  /// After the redirect returns, getRedirectResult in [_doInit]
  /// resolves the pending credential.
  Future<CloudAuthResult> signInWithGoogle() async {
    if (!_configured) {
      return const CloudAuthResult.error('Cloud sync not configured.');
    }
    try {
      final provider = GoogleAuthProvider();
      provider.setCustomParameters({'prompt': 'select_account'});
      if (kIsWeb) {
        // Redirect works everywhere (desktop + mobile browsers).
        await FirebaseAuth.instance.signInWithRedirect(provider);
        // Never reached — browser navigates away. On return,
        // _doInit's getRedirectResult() picks up the credential.
        return const CloudAuthResult.error('Redirecting…');
      }
      // Non-web platforms use popup (if ever needed).
      final cred =
          await FirebaseAuth.instance.signInWithPopup(provider);
      return CloudAuthResult.ok(cred.user);
    } on FirebaseAuthException catch (e) {
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
