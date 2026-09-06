// Email + password sign-in, sign-up and password reset.
//
// 2026-09-06. Ships in EVERY build, China included — see
// `lib/constants/build_flags.dart` for why the compile-time China
// flag is the wrong thing to gate this on, and
// `docs/HANDOVER-2026-09-06.md` for the two rulings this file
// implements.
//
// SECURITY — the whole of it, in one place:
//   • The password lives in a `TextEditingController` and reaches
//     exactly one destination: the FirebaseAuth SDK call it is an
//     argument to. It is never printed, logged, persisted, put into
//     an error string, or sent anywhere else.
//   • It is never trimmed. A leading or trailing space is part of the
//     credential.
//   • `autofillHints` are set so the platform password manager can do
//     its job; the app itself stores nothing.
//
// The two rulings, implemented:
//   • **Collision.** On `email-already-in-use` /
//     `account-exists-with-different-credential` this shows ONE
//     sentence and ONE button, which mails a password reset to the
//     address just typed. It does not detect which provider owns the
//     account and does not link accounts, because a reset on a
//     Google-only Firebase account ADDS a password credential to that
//     same UID — the answer is identical either way, so the copy names
//     no provider and enumeration protection stays on.
//   • **Sign-in.** With enumeration protection on, a Google-only
//     account handed a password gets a generic `invalid-credential`,
//     indistinguishable from a typo. "Forgot password?" is therefore
//     visible on the sign-in form at all times, and the same reset
//     button is surfaced directly beneath that error.
//
// Every network call is bounded. A reader who taps the button on a
// network that blackholes Google gets a sentence in their own
// language, not a spinner that never resolves.

import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// Injection seams. Production wires these to [CloudAuthService]; the
/// tests wire them to fakes, which is the only way the error, reset
/// and timeout branches can be exercised at all — a widget test has no
/// Firebase backend, and a form whose failure paths are untested is
/// exactly the form that ships a spinner that never resolves.
typedef EmailAuthAction = Future<CloudAuthResult> Function(
    String email, String password);
typedef PasswordResetAction = Future<CloudAuthActionResult> Function(
    String email);

/// Show the sheet. Returns true when the reader ended up signed in.
Future<bool?> showEmailAuthSheet(
  BuildContext context, {
  required String locale,
  String? fontFamily,
  double fontSize = 16,
  EmailAuthAction? signIn,
  EmailAuthAction? createAccount,
  PasswordResetAction? sendReset,
  VoidCallback? onSignedIn,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: EmailAuthSheet(
        locale: locale,
        fontFamily: fontFamily,
        fontSize: fontSize,
        signIn: signIn,
        createAccount: createAccount,
        sendReset: sendReset,
        onSignedIn: onSignedIn,
      ),
    ),
  );
}

class EmailAuthSheet extends StatefulWidget {
  final String locale;
  final String? fontFamily;
  final double fontSize;

  /// Defaults to [CloudAuthService.signInWithEmailAndAdoptProfile].
  final EmailAuthAction? signIn;

  /// Defaults to [CloudAuthService.createAccountWithEmailAndAdoptProfile].
  final EmailAuthAction? createAccount;

  /// Defaults to [CloudAuthService.sendPasswordResetEmail].
  final PasswordResetAction? sendReset;

  /// Called once, after a sign-in or sign-up actually succeeded. This
  /// is where `RealtimeDbSyncService.init()` is started — lazily,
  /// after a real credential exists, never at boot.
  final VoidCallback? onSignedIn;

  /// Start in create-account mode instead of sign-in mode.
  final bool startInCreateMode;

  const EmailAuthSheet({
    super.key,
    required this.locale,
    this.fontFamily,
    this.fontSize = 16,
    this.signIn,
    this.createAccount,
    this.sendReset,
    this.onSignedIn,
    this.startInCreateMode = false,
  });

  @override
  State<EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends State<EmailAuthSheet> {
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();

  late bool _createMode = widget.startInCreateMode;
  bool _busy = false;
  bool _obscure = true;

  /// `ui_strings` key of the sentence to show, or null for none.
  String? _messageKey;

  /// The raw code behind [_messageKey]. Drives whether the reset
  /// button is surfaced. Null when the message is not an error.
  String? _errorCode;

  /// True once a reset mail has been requested in this session, so the
  /// confirmation replaces the offer rather than sitting beside it.
  bool _resetSent = false;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  String _t(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  EmailAuthAction get _signIn =>
      widget.signIn ??
      (e, p) => CloudAuthService.instance
          .signInWithEmailAndAdoptProfile(email: e, password: p);

  EmailAuthAction get _createAccount =>
      widget.createAccount ??
      (e, p) => CloudAuthService.instance
          .createAccountWithEmailAndAdoptProfile(email: e, password: p);

  PasswordResetAction get _sendReset =>
      widget.sendReset ??
      (e) => CloudAuthService.instance.sendPasswordResetEmail(e);

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _messageKey = null;
      _errorCode = null;
      _resetSent = false;
    });
    // Read the password out of the controller here and pass it
    // straight through. It is not stored on the State, not logged,
    // and not trimmed.
    final action = _createMode ? _createAccount : _signIn;
    final result = await action(_emailCtl.text, _passwordCtl.text);
    if (!mounted) return;
    if (result.isOk) {
      widget.onSignedIn?.call();
      // 2026-09-06: `_busy` is cleared when the pop does NOT happen.
      // Found by `email_auth_sheet_test.dart`, and it is the same
      // defect class the brief warns about from the other direction:
      // if this widget is ever hosted somewhere the route cannot be
      // popped, leaving `_busy` true parks a spinner on screen
      // forever after a sign-in that actually SUCCEEDED.
      final popped = await Navigator.of(context).maybePop(true);
      if (!popped && mounted) {
        setState(() => _busy = false);
      }
      return;
    }
    setState(() {
      _busy = false;
      _errorCode = result.errorCode;
      _messageKey = CloudAuthService.messageKeyForCode(result.errorCode);
    });
  }

  Future<void> _requestReset() async {
    if (_busy) return;
    setState(() {
      _busy = true;
    });
    final result = await _sendReset(_emailCtl.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.isOk) {
        _resetSent = true;
        _errorCode = null;
        _messageKey = 'authResetSent';
      } else {
        _errorCode = result.errorCode;
        _messageKey = CloudAuthService.messageKeyForCode(result.errorCode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    final titleStyle = TextStyle(
      fontFamily: widget.fontFamily,
      fontFamilyFallback: kCjkFontFallback,
      fontSize: (widget.fontSize + 2).clamp(16.0, 22.0).toDouble(),
      fontWeight: FontWeight.w600,
    );
    final bodyStyle = TextStyle(
      fontFamily: widget.fontFamily,
      fontFamilyFallback: kCjkFontFallback,
      fontSize: (widget.fontSize - 3).clamp(12.0, 16.0).toDouble(),
    );

    // The reset offer appears on the collision codes AND on the
    // generic invalid-credential a Google-only account produces. It is
    // one button doing one thing in both cases, because the fix is the
    // same in both cases.
    final offerReset = !_resetSent &&
        CloudAuthService.shouldOfferPasswordReset(_errorCode);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _createMode
                  ? _t('authSheetTitleCreate', 'Create an account')
                  : _t('authSheetTitleSignIn', 'Sign in with email'),
              style: titleStyle,
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('emailAuth.email'),
              controller: _emailCtl,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _t('authEmailLabel', 'Email address'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('emailAuth.password'),
              controller: _passwordCtl,
              enabled: !_busy,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: [
                _createMode
                    ? AutofillHints.newPassword
                    : AutofillHints.password,
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: _t('authPasswordLabel', 'Password'),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (_messageKey != null) ...[
              const SizedBox(height: 12),
              Text(
                key: const Key('emailAuth.message'),
                _t(_messageKey!, _messageKey!),
                style: bodyStyle.copyWith(
                  color: _resetSent ? scheme.onSurfaceVariant : scheme.error,
                ),
              ),
            ],
            if (offerReset) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('emailAuth.sendReset'),
                onPressed: _busy ? null : _requestReset,
                icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                label: Text(
                  _t('authResetSendButton', 'Email me a reset link'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('emailAuth.submit'),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : Text(
                      _createMode
                          ? _t('authCreateAction', 'Create account')
                          : _t('authSignInAction', 'Sign in'),
                    ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  key: const Key('emailAuth.toggleMode'),
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _createMode = !_createMode;
                            _messageKey = null;
                            _errorCode = null;
                            _resetSent = false;
                          }),
                  child: Text(
                    _createMode
                        ? _t('authSwitchToSignIn',
                            'Already have an account? Sign in')
                        : _t('authSwitchToCreate',
                            'No account yet? Create one'),
                    style: TextStyle(fontSize: bodyStyle.fontSize),
                  ),
                ),
                // Never buried: present on the sign-in form whether or
                // not anything has failed yet.
                if (!_createMode)
                  TextButton(
                    key: const Key('emailAuth.forgot'),
                    onPressed: _busy ? null : _requestReset,
                    child: Text(
                      _t('authForgotPassword', 'Forgot password?'),
                      style: TextStyle(fontSize: bodyStyle.fontSize),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              uiStrings['authNoticeNotSignedIn']?[locale] ??
                  'Sign in with an email address to sync highlights, '
                      'notes and bookmarks across devices.',
              style: bodyStyle.copyWith(
                fontSize: (widget.fontSize - 5).clamp(11.0, 14.0).toDouble(),
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
