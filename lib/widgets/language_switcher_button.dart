import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';

/// One-tap interface-language switcher, extracted from the version
/// that first shipped on the Home dashboard (2026-08-02 field
/// request: "a visible language switcher instead of digging into
/// Settings → App → Interface Language every time").
///
/// 2026-08-03: user asked for it on EVERY page, not just Home — the
/// Dashboard-only copy was inlined there, so this widget makes it a
/// one-line drop-in for every other page's AppBar `actions` instead
/// of duplicating the PopupMenuButton everywhere. Calls the same
/// `settings.setLocale`the Settings dropdown and the Dashboard
/// switcher already used, so all three stay in sync — none of them
/// is "the real one".
class LanguageSwitcherButton extends StatelessWidget {
  const LanguageSwitcherButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    return PopupMenuButton<String>(
      tooltip:
          uiStrings['interfaceLanguage']?[locale] ?? 'Interface Language',
      icon: const Icon(Icons.language_rounded),
      initialValue: locale,
      onSelected: (val) => settings.setLocale(val),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'zh-Hans', child: Text('简体中文')),
        PopupMenuItem(value: 'zh-Hant', child: Text('繁體中文')),
        PopupMenuItem(value: 'en', child: Text('English')),
      ],
    );
  }
}
