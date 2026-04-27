import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:yswords/firebase_options.dart';

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
  User? _user;

  /// True once [init] has finished (regardless of success/failure).
  bool get ready => _ready;

  /// True only when both the Firebase config has real values and
  /// `Firebase.initializeApp` succeeded. UIs should hide cloud
  /// features when this is false.
  bool get isConfigured => _configured;

  /// Currently signed-in cloud user, or null if not signed in
  /// (or Firebase isn't configured).
  User? get currentUser => _user;
  bool get isSignedIn => _user != null;

  /// Initialise Firebase if config has been filled in. Safe to call
  /// from main(); on misconfiguration logs a debug message and
  /// returns without throwing.
  Future<void> init() async {
    if (_ready) return;
    try {
      if (!firebaseConfigured) {
        // Stub config — leave _configured false so the rest of the
        // app stays on local-only profiles. No network calls.
        _ready = true;
        return;
      }
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.web,
      );
      _configured = true;
      _user = FirebaseAuth.instance.currentUser;
      // Reflect future sign-in / sign-out events into our notifier.
      FirebaseAuth.instance.userChanges().listen((u) {
        _user = u;
        notifyListeners();
      });
    } catch (e, st) {
      debugPrint('CloudAuthService.init failed: $e\n$st');
      _configured = false;
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  /// Sign in an existing account. Returns a result with the user on
  /// success or a friendly localized-ish error string on failure.
  /// (We keep error messages in English here — UI layer can map
  /// them via uiStrings if needed.)
  Future<CloudAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    if (!_configured) {
      return const CloudAuthResult.error('Cloud sync not configured.');
    }
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return CloudAuthResult.ok(cred.user);
    } on FirebaseAuthException catch (e) {
      return CloudAuthResult.error(_friendlyError(e));
    } catch (e) {
      return CloudAuthResult.error(e.toString());
    }
  }

  /// Create a new account. Same return shape as [signIn].
  Future<CloudAuthResult> signUp({
    required String email,
    required String password,
  }) async {
    if (!_configured) {
      return const CloudAuthResult.error('Cloud sync not configured.');
    }
    try {
      final cred =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return CloudAuthResult.ok(cred.user);
    } on FirebaseAuthException catch (e) {
      return CloudAuthResult.error(_friendlyError(e));
    } catch (e) {
      return CloudAuthResult.error(e.toString());
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

  /// Sign in with Google via Firebase's web popup flow. Uses
  /// `signInWithPopup(GoogleAuthProvider)` which opens a Google
  /// accounts window, completes OAuth via the project's authDomain
  /// (ysword.firebaseapp.com), and returns a Firebase credential
  /// without us having to wire up the `google_sign_in` package or
  /// add SDK script tags to web/index.html.
  ///
  /// Requirements (one-time):
  ///   1. Firebase Console → Authentication → Sign-in method →
  ///      Google → Enable.
  ///   2. The popup is initiated by a user click — modern browsers
  ///      block popups otherwise. Calling this from a button's
  ///      onPressed handler satisfies the gesture requirement.
  Future<CloudAuthResult> signInWithGoogle() async {
    if (!_configured) {
      return const CloudAuthResult.error('Cloud sync not configured.');
    }
    try {
      final provider = GoogleAuthProvider();
      // Always show the chooser even if there's a single signed-in
      // Google account, so users on shared devices can pick the
      // right one.
      provider.setCustomParameters({'prompt': 'select_account'});
      final cred =
          await FirebaseAuth.instance.signInWithPopup(provider);
      return CloudAuthResult.ok(cred.user);
    } on FirebaseAuthException catch (e) {
      return CloudAuthResult.error(_friendlyError(e));
    } catch (e) {
      return CloudAuthResult.error(e.toString());
    }
  }

  /// Send a password-reset email. Same friendly-error treatment.
  Future<String?> sendPasswordReset(String email) async {
    if (!_configured) return 'Cloud sync not configured.';
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e);
    } catch (e) {
      return e.toString();
    }
  }

  /// Map FirebaseAuth's machine codes to short, plain-English
  /// strings. Anything we don't recognise falls through to
  /// `e.message ?? code`.
  static String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password is too weak (use 6+ characters).';
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
