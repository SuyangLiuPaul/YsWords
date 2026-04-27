import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/profile_service.dart';

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
                      fontSize: 28,
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
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (!_signingIn) ...[
                    Text(
                      uiStrings['welcomeChooseHowToUse']?[locale] ??
                          'How would you like to use YsWords?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _signingIn = true),
                      icon: const Icon(Icons.person_outline),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          uiStrings['welcomeSignIn']?[locale] ?? 'Sign in',
                          style: const TextStyle(fontSize: 15),
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
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      uiStrings['welcomeLocalOnlyNotice']?[locale] ??
                          'Profiles are stored only on this device. No password, no server.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
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
                        fontSize: 14,
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
