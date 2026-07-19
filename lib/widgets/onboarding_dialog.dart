import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/build_flags.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:provider/provider.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

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

  /// Storage key for the "I've seen the tour" flag. Bumped to `v3` in
  /// 2026-05-09 (v1.2.9) — the v2 tour pre-dated the AI features
  /// (AI Bible search, AI Word explanation / BDAG-style exegesis,
  /// BYOK Test button) which are now central to the app. Existing
  /// v2-flag users now see the refreshed 6-slide tour once before
  /// their flag migrates to v3. Future bumps (v4+) re-introduce
  /// the tour when more major surfaces ship. v1 → v2 was the last
  /// such bump, in Round 55.
  static const _kSeen = 'onboarding.seen.v3';

  static Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSeen) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeen, true);
  }

  /// Manually re-trigger the tour from Settings → About → "Show tour
  /// again". Clears the v2 seen flag and lets the dashboard's auto-
  /// open path show the dialog the next time the user lands there.
  /// We don't pop the dialog directly here so the caller can choose
  /// to open it inline (without leaving Settings) or just let the
  /// next dashboard mount handle it.
  static Future<void> markUnseen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSeen);
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
              // Illustration + text carousel. Capped at 240px on roomy
              // screens (its original fixed height — unchanged there),
              // but Flexible so it shrinks on short viewports instead of
              // pushing the dots + buttons past the dialog's max height.
              // Each page additionally scrolls internally (see below) so
              // a long slide body at a large font size can never overflow
              // the area it is given. Together these stop the ~4px bottom
              // overflow seen on tall phones (long body vs the fixed 240)
              // and the larger overflow on short ones.
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemCount: slides.length,
                    itemBuilder: (_, i) {
                      final s = slides[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        // Center the content when it fits (identical to the
                        // old layout) but allow it to scroll when the body
                        // is taller than the available height.
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight),
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
                                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                      fontSize: (settings.fontSize + 2)
                                          .clamp(16.0, 26.0)
                                          .toDouble(),
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    s.body,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                      fontSize: (settings.fontSize - 2)
                                          .clamp(12.0, 18.0)
                                          .toDouble(),
                                      height: 1.4,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
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
          icon: Icons.menu_book_rounded,
          title: uiStrings['onboardWelcomeTitle']?[locale] ??
              'Welcome to YsWords',
          body: uiStrings['onboardWelcomeBody']?[locale] ??
              'A bilingual Bible reader with 14 translations across English and Chinese. The "Read Bible" card on Home picks up exactly where you left off.',
        ),
        _Slide(
          icon: Icons.format_color_fill,
          title: uiStrings['onboardReadTitle']?[locale] ??
              'Read, highlight, study',
          body: uiStrings['onboardReadBody']?[locale] ??
              'Long-press a verse for color highlights, bookmarks, and notes. Tap any reference to jump; tap a Strong\'s word for originals. Search the whole Bible from the header.',
        ),
        // 2026-05-09 (v1.2.9): AI slide inserted between Read and
        // Sermons. Read introduces the basic study surface (long-
        // press / refs / Strong's), AI tells the user what they can
        // ask the model to do on top of it, then Sermons + Discover
        // show the rest of the content layer. Order matters — AI
        // before Sermons so users frame Sermons as "more reading
        // material" not "AI replaces sermons".
        _Slide(
          icon: Icons.smart_toy_outlined,
          title: uiStrings['onboardAiTitle']?[locale] ??
              'AI study helpers',
          body: uiStrings['onboardAiBody']?[locale] ??
              'Search the Bible by theme ("love", "faith"), tap any Greek or Hebrew word for a BDAG-style deep dive, or ask questions about archaeology and manuscripts. Powered by Gemini — paste your own free key in Settings → AI (and tap Test to verify) to skip the shared developer pool.',
        ),
        _Slide(
          icon: Icons.headset_mic_rounded,
          title: uiStrings['onboardSermonsTitle']?[locale] ?? 'Sermons',
          body: uiStrings['onboardSermonsBody']?[locale] ??
              '587 expository sermons in EN / 简 / 繁. Verse refs in the body open a popup so you can peek at scripture without leaving. Home shows a "Resume sermon" card with your progress.',
        ),
        _Slide(
          icon: Icons.explore_outlined,
          title: uiStrings['onboardDiscoverTitle']?[locale] ?? 'Discover',
          body: uiStrings['onboardDiscoverBody']?[locale] ??
              'Bible Timeline (97 events), Family Tree (277 people), and Bible Evidence (225 archaeology / manuscript / science finds) — all reachable from Home.',
        ),
        // 2026-05-10 (v1.2.11): China build (`kChinaMode`) skips
        // Firebase init at boot, so the Google-sign-in line in the
        // default body would just confuse — the user goes looking
        // for a button v1.2.1 deliberately hid. Swap to the China-
        // specific copy that names the local-only reality.
        _Slide(
          icon: Icons.tune_rounded,
          title: kChinaMode
              ? (uiStrings['onboardCustomizeTitleChina']?[locale] ??
                  'Customize')
              : (uiStrings['onboardCustomizeTitle']?[locale] ??
                  'Customize & sync'),
          body: kChinaMode
              ? (uiStrings['onboardCustomizeBodyChina']?[locale] ??
                  'Drag-reorder or hide any block under Settings → Dashboard layout. Pick a reading plan. In the China build, highlights, notes, and bookmarks all stay on this device.')
              : (uiStrings['onboardCustomizeBody']?[locale] ??
                  'Drag-reorder or hide any block under Settings → Dashboard layout. Pick a reading plan. Sign in with Google to sync bookmarks, notes, and highlights across devices.'),
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
