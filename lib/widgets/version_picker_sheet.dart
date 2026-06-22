import 'package:flutter/material.dart';

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// 2026-06-22 v2: language-grouped Bible-version popup.
///
/// First attempt was a `showModalBottomSheet` with a SegmentedButton —
/// user reported it felt 不和谐 ("not natural"), because (a) it slid up
/// from the bottom, totally different from the old version popup which
/// dropped directly under the chip, and (b) SegmentedButton was a heavier
/// Material 3 widget than the rest of the picker UI uses. The chapter
/// picker uses `_testamentButton`-style pills inline. So this v2 keeps
/// the familiar placement (popup directly under the chip — same machinery
/// the old flat menu used) and mimics the chapter picker's pill row at
/// the top.
///
/// Exposed as a `PopupMenuEntry<String>` so it slots straight into the
/// existing `PopupMenuButton<String>` pattern used by the version chip.
/// The pills swap which language's editions are shown; tapping an
/// edition calls `Navigator.pop<String>(context, version)` which the
/// `PopupMenuButton`'s `onSelected` already wires into the existing
/// version-switch pipeline (untouched).
class LanguageGroupedVersionEntry extends PopupMenuEntry<String> {
  const LanguageGroupedVersionEntry({
    super.key,
    required this.currentVersion,
    required this.settings,
  });

  final String currentVersion;
  final AppSettings settings;

  @override
  // Enough room for the pill row + a short list. The body grows naturally
  // and the inner ListView scrolls if needed, so this is a lower bound,
  // not a hard cap.
  double get height => 260;

  @override
  bool represents(String? value) => false;

  @override
  State<LanguageGroupedVersionEntry> createState() =>
      _LanguageGroupedVersionEntryState();
}

class _LanguageGroupedVersionEntryState
    extends State<LanguageGroupedVersionEntry> {
  late String _lang;

  @override
  void initState() {
    super.initState();
    _lang = bibleVersionLanguage(widget.currentVersion);
    final order = bibleLanguageOrder;
    if (!order.contains(_lang) && order.isNotEmpty) {
      _lang = order.first;
    }
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

    return ConstrainedBox(
      constraints: const BoxConstraints(
        // Keep the menu narrow enough that long Chinese labels still fit
        // without pushing past common phone widths.
        minWidth: 240,
        maxWidth: 320,
        maxHeight: 380,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pill row — same visual vocabulary as the chapter picker's
          // _testamentButton (TextButton with primary-when-selected
          // background, 14px rounded, outline border, bold weight).
          if (languages.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Row(
                children: [
                  for (var i = 0; i < languages.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _languagePill(
                        context: context,
                        selected: languages[i] == _lang,
                        label: _langLabel(languages[i]),
                        onPressed: () =>
                            setState(() => _lang = languages[i]),
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
          // Editions for the selected language. A `Column` inside a
          // `SingleChildScrollView` (not a `ListView`) — PopupMenuButton
          // measures intrinsic widths to size the menu, which is a no-go
          // for sliver-based viewports. There are at most ~7 versions
          // per language so the Column build is trivially cheap.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final v in versions)
                    _versionRow(
                      context: context,
                      version: v,
                      isCurrent: v.value == widget.currentVersion,
                      settings: settings,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _versionRow({
    required BuildContext context,
    required BibleVersionInfo version,
    required bool isCurrent,
    required AppSettings settings,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        // Re-tap on the current edition: close cleanly with no change.
        // A different edition: pop with the value so the host
        // PopupMenuButton's onSelected fires the version switch.
        if (isCurrent) {
          Navigator.pop<String>(context);
        } else {
          Navigator.pop<String>(context, version.value);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    version.menuLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize: 14.5,
                      fontWeight: isCurrent
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isCurrent
                          ? scheme.primary
                          : scheme.onSurface,
                    ),
                  ),
                  if (version.editionYear.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        version.editionYear,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontFamilyFallback: kCjkFontFallback,
                          fontSize: 11,
                          color:
                              scheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isCurrent)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.check_rounded,
                    size: 18, color: scheme.primary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _languagePill({
    required BuildContext context,
    required bool selected,
    required String label,
    required VoidCallback onPressed,
  }) {
    // Mirrors _testamentButton in book_chapter_picker.dart so the version
    // popup and the chapter picker speak the same visual language.
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
