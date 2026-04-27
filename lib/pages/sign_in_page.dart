import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Email + password sign-in / sign-up page. Used both from the
/// first-launch welcome gate and from Settings → Profiles → Sign in
/// to cloud. Toggles between "Sign in" (existing account) and
/// "Create account" (new) via a single switch button — fewer
/// surfaces than two separate pages.
///
/// On success, switches the active local profile to the
/// authenticated user's email-derived profile so cloud-synced data
/// has somewhere to land in local storage too.
class SignInPage extends StatefulWidget {
  /// Called after a successful sign-in / sign-up. Lets the host
  /// decide what to do next (welcome gate dismisses; settings page
  /// pops back).
  final VoidCallback? onSuccess;

  const SignInPage({super.key, this.onSuccess});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;
  bool _busy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final auth = CloudAuthService.instance;
    final result = _isSignUp
        ? await auth.signUp(email: email, password: password)
        : await auth.signIn(email: email, password: password);
    if (!mounted) return;
    if (!result.isOk) {
      setState(() {
        _busy = false;
        _errorMessage = result.errorMessage;
      });
      return;
    }
    // Switch (or create) a local profile keyed off the email so
    // future sign-outs don't lose the just-synced cloud snapshot.
    final svc = ProfileService.instance;
    final namePart = email.split('@').first;
    final existing = svc.profiles
        .where((p) => p.name.toLowerCase() == namePart.toLowerCase());
    if (existing.isNotEmpty) {
      await svc.setCurrent(existing.first.id);
    } else {
      final p = await svc.create(namePart);
      await svc.setCurrent(p.id);
    }
    await svc.markWelcomeSeen();
    if (!mounted) return;
    widget.onSuccess?.call();
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Enter your email first.');
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final err = await CloudAuthService.instance.sendPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _errorMessage = err ?? 'Reset link sent — check your email.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final ttl = _isSignUp
        ? (uiStrings['signUpTitle']?[locale] ?? 'Create account')
        : (uiStrings['signInTitle']?[locale] ?? 'Sign in');

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(ttl),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.cloud_outlined,
                        size: 56, color: scheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      _isSignUp
                          ? (uiStrings['signUpSubtitle']?[locale] ??
                              'Create a free account to sync notes, bookmarks and progress across devices.')
                          : (uiStrings['signInSubtitle']?[locale] ??
                              'Sign in to sync your notes, bookmarks and reading-plan progress across devices.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText:
                            uiStrings['emailLabel']?[locale] ?? 'Email',
                        prefixIcon: const Icon(Icons.alternate_email),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return uiStrings['emailRequired']?[locale] ??
                              'Enter your email.';
                        }
                        if (!v.contains('@')) {
                          return uiStrings['emailInvalid']?[locale] ??
                              'Invalid email.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: _isSignUp
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText:
                            uiStrings['passwordLabel']?[locale] ?? 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return uiStrings['passwordRequired']?[locale] ??
                              'Enter your password.';
                        }
                        if (_isSignUp && v.length < 6) {
                          return uiStrings['passwordTooShort']?[locale] ??
                              '6+ characters please.';
                        }
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 18, color: scheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : Text(ttl),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _isSignUp = !_isSignUp;
                                    _errorMessage = null;
                                  }),
                          child: Text(
                            _isSignUp
                                ? (uiStrings['signInToggleExisting']
                                        ?[locale] ??
                                    'Already have an account? Sign in')
                                : (uiStrings['signInToggleNew']?[locale] ??
                                    'Create new account'),
                          ),
                        ),
                        if (!_isSignUp)
                          TextButton(
                            onPressed: _busy ? null : _resetPassword,
                            child: Text(
                              uiStrings['forgotPassword']?[locale] ??
                                  'Forgot password?',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
