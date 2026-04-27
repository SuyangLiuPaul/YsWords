import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:provider/provider.dart';

/// First-run onboarding carousel. ~4 slides explaining the
/// non-obvious features (daily verse, reading plans, library,
/// cloud sync). Shown once per device — flag stored globally in
/// SharedPreferences so even profile switches don't re-trigger it.
///
/// Built as a Dialog (rather than a full screen) so it can sit on
/// top of the Dashboard without disturbing the navigator stack —
/// dismissing returns the user to the same Dashboard they were
/// already on.
class OnboardingDialog extends StatefulWidget {
  const OnboardingDialog({super.key});

  static const _kSeen = 'onboarding.seen.v1';

  /// Whether the user has already dismissed the tour. Bumped to
  /// `.v2` etc. when a future round wants to re-introduce it for
  /// returning users.
  static Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSeen) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeen, true);
  }

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingDialog.markSeen();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final slides = _slides(locale);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 240,
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemCount: slides.length,
                  itemBuilder: (_, i) {
                    final s = slides[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(s.icon,
                                size: 32, color: scheme.primary),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            s.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.body,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // Page indicator dots.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(slides.length, (i) {
                  final selected = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: selected ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary
                          : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: _finish,
                    child:
                        Text(uiStrings['skip']?[locale] ?? 'Skip'),
                  ),
                  const Spacer(),
                  if (_index < slides.length - 1)
                    FilledButton(
                      onPressed: () => _controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child:
                            Text(uiStrings['next']?[locale] ?? 'Next'),
                      ),
                    )
                  else
                    FilledButton(
                      onPressed: _finish,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Text(
                            uiStrings['getStarted']?[locale] ??
                                'Get started'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_Slide> _slides(String locale) => [
        _Slide(
          icon: Icons.menu_book_outlined,
          title: uiStrings['onboardWelcomeTitle']?[locale] ??
              'Welcome to YsWords',
          body: uiStrings['onboardWelcomeBody']?[locale] ??
              'A bilingual Bible reader. Tap "Continue reading" any time to open the verse list with sidebar, search, originals, and cross-references.',
        ),
        _Slide(
          icon: Icons.event_available_outlined,
          title: uiStrings['onboardPlansTitle']?[locale] ??
              'Reading plans',
          body: uiStrings['onboardPlansBody']?[locale] ??
              'Pick a one-year, chronological, or McCheyne plan in Settings — today\'s readings show on this Home page automatically.',
        ),
        _Slide(
          icon: Icons.collections_bookmark_outlined,
          title: uiStrings['onboardLibraryTitle']?[locale] ??
              'Notes & bookmarks',
          body: uiStrings['onboardLibraryBody']?[locale] ??
              'Long-press a verse to add a note, bookmark, or color highlight. Find them all in Library and Highlights.',
        ),
        _Slide(
          icon: Icons.cloud_outlined,
          title:
              uiStrings['onboardCloudTitle']?[locale] ?? 'Sync & profiles',
          body: uiStrings['onboardCloudBody']?[locale] ??
              'Sign in with Google to sync everything across devices, or use a local profile to keep things on this device only.',
        ),
      ];
}

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
  });
}
