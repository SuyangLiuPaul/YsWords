import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/services/leb_insights_service.dart';

/// 2026-05-18 (v1.2.53): cross-version LEB translator-insights
/// overlay chip.
///
/// Returns an [InlineSpan] (suitable for adding to the verse's
/// RichText / TextSpan list) when ALL of the following hold:
///   • [settings].showLebInsights is `true`
///   • [currentVersion] is NOT `'leb'` (LEB readers already see
///     these notes inline — adding a duplicate chip would be
///     noise)
///   • [LebInsightsService] has finished loading (boot path
///     awaits this; safe to call before but produces no chip)
///   • LEB has at least one `<note: …>` annotation for the
///     matching `book / chapter / verse`
///
/// Returns `null` when any guard fails. The render path can
/// short-circuit with `if (span != null) spans.add(span)`.
///
/// The chip is a small superscript ⓘ rendered at ~0.65× the
/// verse text size, in the theme's primary colour at 80 % alpha
/// — visually similar to the existing `<note: …>` book-icon
/// glyph but distinct so users can tell "this is from LEB, not
/// from the version I'm reading".
///
/// Tap → [AlertDialog] listing every LEB note for this verse,
/// each on its own bullet, with a small attribution footer
/// ("Source: Lexham English Bible"). Same OK / Close pattern
/// as the existing note popup in `build_verse_content_spans`.
InlineSpan? buildLebInsightChip({
  required Verse verse,
  required BuildContext context,
  required AppSettings settings,
  required String currentVersion,
  required bool isSelected,
}) {
  if (!settings.showLebInsights) return null;
  // LEB readers already see the notes inline — skip.
  if (currentVersion == 'leb') return null;
  if (!LebInsightsService.instance.isReady) return null;
  final notes = LebInsightsService.instance.notesFor(
    verse.book,
    verse.chapter,
    verse.verse,
  );
  if (notes.isEmpty) return null;

  final scheme = Theme.of(context).colorScheme;
  final fg = isSelected
      ? scheme.onPrimaryContainer.withValues(alpha: 0.85)
      : scheme.primary.withValues(alpha: 0.80);
  final iconSize = (settings.fontSize * 0.85).clamp(11.0, 18.0);

  final locale = settings.locale;
  return WidgetSpan(
    alignment: PlaceholderAlignment.top,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showLebNotesDialog(
        context: context,
        notes: notes,
        settings: settings,
        locale: locale,
        verse: verse,
      ),
      child: Padding(
        padding: EdgeInsets.only(left: 2.0, right: 1.0, top: settings.fontSize * 0.05),
        child: Icon(
          Icons.info_outline_rounded,
          size: iconSize,
          color: fg,
          semanticLabel: uiStrings['lebInsightDialogTitle']?[locale] ??
              'LEB Translator Notes',
        ),
      ),
    ),
  );
}

void _showLebNotesDialog({
  required BuildContext context,
  required List<String> notes,
  required AppSettings settings,
  required String locale,
  required Verse verse,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: settings.fontSize + 4,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              uiStrings['lebInsightDialogTitle']?[locale] ??
                  'LEB Translator Notes',
              style: TextStyle(
                fontSize: settings.fontSize + 2,
                fontFamily: settings.fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verse reference header so the user sees which verse
            // these notes belong to (useful when the chip was
            // tapped from a multi-verse paragraph).
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${verse.book} ${verse.chapter}:${verse.verseLabel}',
                style: TextStyle(
                  fontSize: settings.fontSize - 1,
                  fontFamily: settings.fontFamily,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Icon(
                        Icons.fiber_manual_record,
                        size: 6,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        note,
                        style: TextStyle(
                          fontSize: settings.fontSize,
                          fontFamily: settings.fontFamily,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                uiStrings['lebInsightAttribution']?[locale] ??
                    'Source: Lexham English Bible',
                style: TextStyle(
                  fontSize: settings.fontSize - 3,
                  fontFamily: settings.fontFamily,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            uiStrings['ok']?[locale] ?? 'OK',
            style: TextStyle(
              fontSize: settings.fontSize,
              fontFamily: settings.fontFamily,
            ),
          ),
        ),
      ],
    ),
  );
}
