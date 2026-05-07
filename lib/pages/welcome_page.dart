import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/widgets/google_g_logo.dart';
import 'package:yswords/widgets/liquid_glass.dart';

/// One-time gate shown on first launch (and accessible later from
/// Settings → Switch profile). Lets the user pick a name so their
/// notes / bookmarks / highlights / reading-plan progress are kept
/// separate from anyone else who uses the same browser.
///
/// Two paths: "Sign in" lets them name a profile; "Continue as
/// guest" defaults to the always-present Guest profile. Either way
/// the gate marks itself seen and falls through to the home page.
class WelcomePage extends StatefulWidget {
  final VoidCallback onDone;
  const WelcomePage({super.key, required this.onDone});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _nameController = TextEditingController();
  bool _signingIn = false;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continueAsGuest() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ProfileService.instance.setCurrent(ProfileService.guestId);
    await ProfileService.instance.markWelcomeSeen();
    if (!mounted) return;
    widget.onDone();
  }

  /// Trigger Firebase's Google popup. Profile reconciliation
  /// (find-by-display-name or create) lives in
  /// `signInWithGoogleAndAdoptProfile` so welcome / dashboard /
  /// floating-header menu all share the same flow.
  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    // Recover from a boot-time init failure: if Firebase is not yet
    // configured but credentials are present, retry init once before
    // attempting sign-in. Clears the most common transient failure
    // (network blip during cold start) without making the user dig
    // into Settings.
    final auth = CloudAuthService.instance;
    if (!auth.isConfigured && auth.hasFirebaseCredentials) {
      await auth.retryInit();
      if (!mounted) return;
      if (!auth.isConfigured) {
        setState(() => _busy = false);
        messenger.showSnackBar(SnackBar(
          content: Text(
            auth.initError ??
                'Cloud sign-in unavailable. Check your network and retry.',
          ),
          duration: const Duration(seconds: 4),
        ));
        return;
      }
    }
    final result = await CloudAuthService.instance
        .signInWithGoogleAndAdoptProfile();
    if (!mounted) return;
    if (!result.isOk) {
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(
        content: Text(result.errorMessage ?? 'Sign-in failed.'),
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    // Mark welcome seen even if the user later signs out — they've
    // explicitly answered the gate's question and shouldn't see it
    // again on the next launch.
    await ProfileService.instance.markWelcomeSeen();
    if (!mounted) return;
    widget.onDone();
  }

  Future<void> _signIn() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    final svc = ProfileService.instance;
    // If a profile with that exact name already exists, switch to it
    // — we don't want a careless typo to spawn duplicates.
    final existing = svc.profiles
        .where((p) => p.name.toLowerCase() == name.toLowerCase());
    if (existing.isNotEmpty) {
      await svc.setCurrent(existing.first.id);
    } else {
      final p = await svc.create(name);
      await svc.setCurrent(p.id);
    }
    await svc.markWelcomeSeen();
    if (!mounted) return;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / title
                  Container(
                    height: 76,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    width: 76,
                    child: Icon(Icons.menu_book_rounded,
                        color: scheme.primary, size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'YsWords',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontSize: (settings.fontSize + 12)
                          .clamp(24.0, 36.0)
                          .toDouble(),
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    uiStrings['welcomeTagline']?[locale] ??
                        'Personal Bible study, on every device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontSize: (settings.fontSize - 2)
                          .clamp(12.0, 18.0)
                          .toDouble(),
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 2026-05-07: spiritual disclaimer. The user wants
                  // every onboarding path to set the right expectation:
                  // YsWords is a tool that can help, but the Bible is
                  // God's word and the Holy Spirit is the primary
                  // teacher. AI features (explanations, search, etc.)
                  // are for reference only and can make mistakes.
                  //
                  // 2026-05-08 (v1.1.0 — Liquid Glass): container
                  // upgraded to LiquidGlassCard. The disclaimer is
                  // the user's first impression of the app, so we
                  // want it to look premium / modern from the very
                  // first frame.
                  LiquidGlassCard(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    borderRadius: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_stories_rounded,
                                size: 16, color: scheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                uiStrings['welcomeDisclaimerTitle']
                                        ?[locale] ??
                                    'A reading companion, not a replacement',
                                style: TextStyle(
                                  fontFamily: settings.fontFamily,
                                  fontSize: (settings.fontSize - 2)
                                      .clamp(12.0, 15.0)
                                      .toDouble(),
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          uiStrings['welcomeDisclaimerBody']?[locale] ??
                              'YsWords is a tool to help you study. The '
                                  'Bible itself is God\'s Word, and the Holy '
                                  'Spirit is the primary teacher. AI '
                                  'features (explanations / search) are '
                                  'for reference only and can make '
                                  'mistakes — always verify with Scripture '
                                  'and trust the Spirit\'s guidance above '
                                  'any tool.',
                          style: TextStyle(
                            fontFamily: settings.fontFamily,
                            fontSize: (settings.fontSize - 3)
                                .clamp(11.0, 13.0)
                                .toDouble(),
                            color: scheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!_signingIn) ...[
                    Text(
                      uiStrings['welcomeChooseHowToUse']?[locale] ??
                          'How would you like to use YsWords?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontSize: settings.fontSize,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Cloud sign-in (Firebase Google popup) — shown
                    // only when the user has finished the
                    // firebase_options.dart setup. Otherwise the
                    // only "Sign in" option is the local-profile
                    // path further down.
                    if (CloudAuthService.instance.isConfigured ||
                        CloudAuthService.instance.hasFirebaseCredentials) ...[
                      // Google brand button — white background +
                      // multi-color G logo + slate text — matches
                      // Google's web sign-in button guidelines. When
                      // hasFirebaseCredentials is true but
                      // isConfigured is false, init failed at boot;
                      // the button is enabled and a click triggers
                      // retryInit() before falling through to sign-in
                      // so a transient error doesn't block the user.
                      OutlinedButton(
                        onPressed: _busy ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1F1F1F),
                          side: const BorderSide(
                              color: Color(0xFFDADCE0), width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const GoogleGLogo(size: 20),
                            const SizedBox(width: 12),
                            Text(
                              uiStrings['welcomeSignInGoogle']?[locale] ??
                                  'Sign in with Google',
                              style: TextStyle(
                                fontFamily: settings.fontFamily,
                                fontSize: (settings.fontSize)
                                    .clamp(13.0, 18.0)
                                    .toDouble(),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    FilledButton.tonalIcon(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _signingIn = true),
                      icon: const Icon(Icons.person_outline),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          CloudAuthService.instance.isConfigured
                              ? (uiStrings['welcomeLocalProfile']
                                      ?[locale] ??
                                  'Local profile (this device only)')
                              : (uiStrings['welcomeSignIn']?[locale] ??
                                  'Sign in'),
                          style: TextStyle(
                              fontFamily: settings.fontFamily,
                              fontSize: (settings.fontSize)
                                  .clamp(13.0, 18.0)
                                  .toDouble()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _continueAsGuest,
                      icon: const Icon(Icons.no_accounts_outlined),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          uiStrings['welcomeContinueGuest']?[locale] ??
                              'Continue as guest',
                          style: TextStyle(
                              fontFamily: settings.fontFamily,
                              fontSize: (settings.fontSize)
                                  .clamp(13.0, 18.0)
                                  .toDouble()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      CloudAuthService.instance.isConfigured
                          ? (uiStrings['welcomeCloudNotice']?[locale] ??
                              'Sign in to sync across devices, or use a local profile / guest if you prefer to keep everything on this device.')
                          : (uiStrings['welcomeLocalOnlyNotice']
                                  ?[locale] ??
                              'Profiles are stored only on this device. No password, no server.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontSize: (settings.fontSize - 4)
                            .clamp(11.0, 16.0)
                            .toDouble(),
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ] else ...[
                    Text(
                      uiStrings['welcomeNamePrompt']?[locale] ??
                          "What should we call you?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontSize: settings.fontSize,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => _signIn(),
                      decoration: InputDecoration(
                        hintText: uiStrings['welcomeNameHint']?[locale] ??
                            'Your name',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _busy
                                ? null
                                : () =>
                                    setState(() => _signingIn = false),
                            child: Text(
                                uiStrings['back']?[locale] ?? 'Back'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy ? null : _signIn,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8),
                              child: Text(
                                uiStrings['welcomeSignIn']?[locale] ??
                                    'Sign in',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
