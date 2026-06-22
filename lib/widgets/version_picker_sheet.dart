import 'package:flutter/material.dart';

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// 2026-06-22 v3 (post-Safari-crash): language-grouped version popup.
///
/// History of the design space:
///   • v1.3.98 used `showModalBottomSheet` — user feedback was
///     "感觉这个新的version的方式真的很不和谐" (it slid up from the bottom,
///     foreign placement).
///   • v1.3.100 used a custom `PopupMenuEntry<String>` subclass hosted
///     inside a `PopupMenuButton<String>` — that crashed on iPhone
///     Safari ("Null check operator used on a null value" deep inside
///     Flutter's PopupMenuRoute layout after a few opens) and was
///     reverted in v1.3.101 back to the old flat menu.
///   • v3 (this file) uses **`showMenu` with a regular `PopupMenuItem`
///     whose `enabled: false` prevents the dismiss-on-tap that
///     PopupMenuItems do, then a `StatefulBuilder` inside it manages
///     the language tab + version list**. No PopupMenuEntry subclass,
///     no custom `represents`/`height` overrides — only the well-worn
///     "PopupMenuItem hosts a stateful child" pattern.
///
/// The pill row at the top matches the chapter picker's `_testamentButton`
/// vocabulary (TextButton, primary-when-selected, 14px rounded, outline
/// border, bold). Tapping a pill swaps the editions list. Tapping a
/// version row calls `Navigator.pop(ctx, version.value)` to close the
/// menu and return the picked value, which the host wires into the
/// existing `onVersionSelected` pipeline.
Future<String?> showLanguageGroupedVersionMenu({
  required BuildContext context,
  required RelativeRect position,
  required String currentVersion,
  required AppSettings settings,
}) {
  final scheme = Theme.of(context).colorScheme;
  final initialLang = (() {
    var l = bibleVersionLanguage(currentVersion);
    final order = bibleLanguageOrder;
    if (!order.contains(l) && order.isNotEmpty) l = order.first;
    return l;
  })();

  return showMenu<String>(
    context: context,
    position: position,
    color: scheme.surface,
    elevation: 8,
    constraints: const BoxConstraints(
      minWidth: 240,
      maxWidth: 320,
    ),
    items: [
      PopupMenuItem<String>(
        enabled: false,
        padding: EdgeInsets.zero,
        child: _LanguageGroupedVersionBody(
          initialLang: initialLang,
          currentVersion: currentVersion,
          settings: settings,
        ),
      ),
    ],
  );
}

class _LanguageGroupedVersionBody extends StatefulWidget {
  const _LanguageGroupedVersionBody({
    required this.initialLang,
    required this.currentVersion,
    required this.settings,
  });

  final String initialLang;
  final String currentVersion;
  final AppSettings settings;

  @override
  State<_LanguageGroupedVersionBody> createState() =>
      _LanguageGroupedVersionBodyState();
}

class _LanguageGroupedVersionBodyState
    extends State<_LanguageGroupedVersionBody> {
  late String _lang;

  @override
  void initState() {
    super.initState();
    _lang = widget.initialLang;
  }

  String _t(String key, String fallback) =>
      uiStrings[key]?[widget.settings.locale] ?? fallback;

  String _langLabel(String lang) {
    switch (lang) {
      case 'en':
        return _t('versionLangEnglish', 'English');
      case 'zh-Hant':
        return _t('versionLangTraditional', 'Traditional');
      case 'zh-Hans':
      default:
        return _t('versionLangSimplified', 'Simplified');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = widget.settings;
    final languages = bibleLanguageOrder;
    final versions = versionsForLanguage(_lang);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (languages.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                for (var i = 0; i < languages.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _languagePill(
                      context: context,
                      selected: languages[i] == _lang,
                      label: _langLabel(languages[i]),
                      onPressed: () => setState(() => _lang = languages[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (languages.length > 1)
          Divider(
            height: 1,
            thickness: 0.5,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        for (final v in versions)
          InkWell(
            onTap: () {
              final isCurrent = v.value == widget.currentVersion;
              if (isCurrent) {
                Navigator.pop<String>(context);
              } else {
                Navigator.pop<String>(context, v.value);
              }
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          v.menuLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: settings.fontFamily,
                            fontFamilyFallback: kCjkFontFallback,
                            fontSize: 14.5,
                            fontWeight: v.value == widget.currentVersion
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: v.value == widget.currentVersion
                                ? scheme.primary
                                : scheme.onSurface,
                          ),
                        ),
                        if (v.editionYear.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              v.editionYear,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: settings.fontFamily,
                                fontFamilyFallback: kCjkFontFallback,
                                fontSize: 11,
                                color: scheme.onSurface
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (v.value == widget.currentVersion)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.check_rounded,
                          size: 18, color: scheme.primary),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _languagePill({
    required BuildContext context,
    required bool selected,
    required String label,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final settings = widget.settings;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: selected
            ? scheme.primary.withValues(alpha: 0.92)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.52),
        foregroundColor: selected ? scheme.onPrimary : scheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        padding: EdgeInsets.symmetric(
            horizontal: 10 * settings.menuScale,
            vertical: 8 * settings.menuScale),
        minimumSize: const Size(0, 36),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: settings.fontSize.clamp(12.0, 15.0).toDouble(),
            fontFamily: settings.fontFamily,
            fontFamilyFallback: kCjkFontFallback,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
