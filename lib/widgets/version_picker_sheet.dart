import 'package:flutter/material.dart';

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// 2026-06-22: language-grouped Bible-version picker.
///
/// Replaces the old flat `PopupMenuButton` (one long list of all ~14
/// editions, which the user found "看起来很多看起来很难受") with a bottom
/// sheet that first offers a language tab — English / 繁體 / 简体 — and
/// then only the editions in that language. The tab defaults to the
/// CURRENT version's language so the user lands on the right group with
/// zero extra taps.
///
/// Behaviour-preserving: it calls [onSelected] with the chosen version
/// code (only when it differs from [currentVersion]); the caller's
/// existing version-switch pipeline is untouched. Used by BOTH the
/// primary and the split-view secondary reading panes.
Future<void> showVersionPickerSheet({
  required BuildContext context,
  required String currentVersion,
  required ValueChanged<String> onSelected,
  required AppSettings settings,
}) {
  final locale = settings.locale;
  String t(String key, String fallback) =>
      uiStrings[key]?[locale] ?? fallback;

  String langLabel(String lang) {
    switch (lang) {
      case 'en':
        return t('versionLangEnglish', 'English');
      case 'zh-Hant':
        return t('versionLangTraditional', 'Traditional');
      case 'zh-Hans':
      default:
        return t('versionLangSimplified', 'Simplified');
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      final scheme = Theme.of(sheetCtx).colorScheme;
      final languages = bibleLanguageOrder;
      // Land on the tab for the version currently in use.
      String selectedLang = bibleVersionLanguage(currentVersion);
      if (!languages.contains(selectedLang) && languages.isNotEmpty) {
        selectedLang = languages.first;
      }
      // Cap the sheet height so a long list scrolls inside the sheet
      // rather than shoving it off-screen; centre + width-cap on tablet /
      // desktop so it doesn't stretch edge-to-edge.
      final maxSheetHeight = MediaQuery.of(sheetCtx).size.height * 0.72;

      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final versions = versionsForLanguage(selectedLang);
          return SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  maxHeight: maxSheetHeight,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          t('versionPickerTitle', 'Choose a version'),
                          style: TextStyle(
                            fontFamily: settings.fontFamily,
                            fontFamilyFallback: kCjkFontFallback,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    // Language tabs. Hidden when only one language ships
                    // (defensive — keeps a single-language build clean).
                    if (languages.length > 1)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            segments: [
                              for (final lang in languages)
                                ButtonSegment<String>(
                                  value: lang,
                                  label: Text(
                                    langLabel(lang),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: settings.fontFamily,
                                      fontFamilyFallback: kCjkFontFallback,
                                    ),
                                  ),
                                ),
                            ],
                            selected: {selectedLang},
                            showSelectedIcon: false,
                            onSelectionChanged: (s) => setSheetState(
                                () => selectedLang = s.first),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        itemCount: versions.length,
                        itemBuilder: (ctx, i) {
                          final v = versions[i];
                          final isCurrent = v.value == currentVersion;
                          return ListTile(
                            title: Text(
                              v.menuLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: settings.fontFamily,
                                fontFamilyFallback: kCjkFontFallback,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isCurrent
                                    ? scheme.primary
                                    : scheme.onSurface,
                              ),
                            ),
                            subtitle: v.editionYear.isEmpty
                                ? null
                                : Text(
                                    v.editionYear,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: settings.fontFamily,
                                      fontFamilyFallback: kCjkFontFallback,
                                      fontSize: 12,
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.55),
                                    ),
                                  ),
                            trailing: isCurrent
                                ? Icon(Icons.check_rounded,
                                    color: scheme.primary)
                                : null,
                            onTap: () {
                              Navigator.of(ctx).pop();
                              if (v.value != currentVersion) {
                                onSelected(v.value);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
