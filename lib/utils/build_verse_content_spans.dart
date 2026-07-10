import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/constants/text_patterns.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// Builds InlineSpan list for a single verse (number + text with annotations).
/// Shared by VerseWidget and ParagraphGroupWidget.
List<InlineSpan> buildVerseContentSpans({
  required Verse verse,
  required BuildContext context,
  required AppSettings settings,
  required String locale,
  required bool isSelected,
  bool superscriptVerseNum = false,
  VoidCallback? onTextTap,
  Color? spanBgColor,
}) {
  final isReferenceLine = verse.paragraphType == 'reference';

  // 2026-05-07: pre-process the raw text to drop stray spaces sitting
  // between a [/{/<note: annotation and adjacent CJK characters.
  // Several CUVS-Yahweh verses ship with English-style spacing
  // around bracketed alternatives (e.g. `主[雅伟] 的道`) which leaves
  // a visible gap between the annotation and the following Chinese
  // character. `collapseAnnotationSpacing` is CJK-aware so it does
  // not affect English contexts like `the [LORD] God`.
  //
  // 2026-05-19 (v1.2.57): keep INTERNAL `\n` characters so OT-quote
  // poetry (LJK2 / biblexg-v2 verses with `paragraphType: 'reference'`)
  // renders with the line breaks the upstream data marked — e.g.
  // Matt 2:6 quoting Micah 5:2 now lays out as 5 stanzas instead of
  // one run-on line. Only TRAILING whitespace (including the LEB-
  // style `…earth--\n` trailing newline) is stripped via `trimRight`.
  final original =
      collapseAnnotationSpacing(verse.text.trimRight());
  final raw = original;
  final parts = raw
      .splitMapJoin(
        combinedPattern,
        onMatch: (m) => '||${m[0]}||',
        onNonMatch: (n) => n,
      )
      .split('||');
  final spans = <InlineSpan>[];
  // Verse number span — uses the theme primary color in both modes
  // so the user's chosen color tints all reading-surface chrome
  // consistently. Paragraph-mode superscript variant is rendered at
  // 80% alpha so it stays subtle next to continuous prose;
  // verse-by-verse uses full primary so it reads like a clear label.
  final verseNumColor = isSelected
      ? Theme.of(context).colorScheme.onPrimaryContainer
      : (superscriptVerseNum
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.80)
          : Theme.of(context).colorScheme.primary);

  final verseNumStyle = TextStyle(
    fontSize:
        superscriptVerseNum ? settings.fontSize * 0.65 : settings.fontSize,
    height: superscriptVerseNum ? 1.0 : settings.lineSpacing,
    fontWeight: superscriptVerseNum ? FontWeight.w600 : FontWeight.w500,
    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
    fontStyle: isReferenceLine ? FontStyle.italic : FontStyle.normal,
    color: verseNumColor,
  );

  spans.add(WidgetSpan(
    alignment: superscriptVerseNum
        ? PlaceholderAlignment.top
        : PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (onTextTap != null) {
          onTextTap();
          return;
        }
        final toCopy = '${verse.verseLabel} ${sanitizeVerseText(verse.text)}';
        final ok = await ClipboardHelper.copyText(toCopy);
        if (!context.mounted) return;
        final msg = ok
            ? (uiStrings['copiedVerse']?[locale] ?? 'Copied verse {verse}')
                .replaceAll('{verse}', verse.verseLabel)
            : (uiStrings['shareLinkFailed']?[locale] ??
                'Copy failed — clipboard unavailable');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      },
      child: Padding(
        // Slight right gap so number doesn't glue onto the first character.
        // Superscript needs less right-pad because it's smaller.
        padding: EdgeInsets.only(
          right: superscriptVerseNum ? 3 : 4,
          // Lift superscript a touch so it sits visually above the baseline.
          top: superscriptVerseNum ? settings.fontSize * 0.05 : 0,
        ),
        // 2026-06-18 (v1.3.90): softWrap:false + maxLines:1 so a 2-digit
        // verse number (e.g. "10") never character-breaks into "1"/"0" on
        // two lines when the WidgetSpan child is handed a tight width
        // constraint in a narrow pane (reported on iPad split view,
        // paragraph mode). The number is always a few chars, so disabling
        // wrap can't cause visible overflow.
        child: Text(
          verse.verseLabel,
          style: verseNumStyle,
          softWrap: false,
          maxLines: 1,
        ),
      ),
    ),
  ));

  // Build text and badge spans
  String? lastPart;
  for (var part in parts) {
    final isNoteOnly =
        part.trim().startsWith('<note:') && part.trim().endsWith('>');
    final wasBraceOnly = lastPart != null &&
        lastPart.trim().startsWith('{') &&
        lastPart.trim().endsWith('}');
    if (isNoteOnly && wasBraceOnly) {
      lastPart = part;
      continue;
    }
    if (bracePattern.hasMatch(part)) {
      final annotation = bracePattern.firstMatch(part)!.group(1)!;
      // 2026-05-19 (v1.2.55): theme-aware border + bg for the
      // `{clarification}` chip. Previously hardcoded teal which
      // clashed with any non-teal primary colour the user picked.
      // Now uses `colorScheme.primary` at low alpha so the chip
      // follows the user's chosen palette and stays subtle but
      // unambiguously clickable.
      final scheme = Theme.of(context).colorScheme;
      final bgColor =
          scheme.primary.withValues(alpha: 0.12);
      final borderColor = scheme.primary.withValues(alpha: 0.55);
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: () {
            final verseText = verse.text.replaceAll('\n', '');
            final braceFull = '{$annotation}';
            final braceIndex = verseText.indexOf(braceFull);
            String? extractedNote;
            if (braceIndex != -1) {
              final afterBrace =
                  verseText.substring(braceIndex + braceFull.length);
              final nextAnnotation =
                  RegExp(r'''^([\s.,;:""'""]*)<note:([^>]+)>''')
                      .firstMatch(afterBrace);
              if (nextAnnotation != null) {
                extractedNote = nextAnnotation.group(2);
              }
            }
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(
                  uiStrings['note']?[locale] ?? 'Note',
                  style: TextStyle(
                    fontSize: settings.fontSize + 2,
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Text(extractedNote ?? annotation),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      uiStrings['ok']?[locale] ?? 'OK',
                      style: TextStyle(
                        fontSize: settings.fontSize,
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                      ),
                    ),
                  )
                ],
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            margin: EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Builder(
              builder: (_) {
                final badgeSpans = <InlineSpan>[];
                final regex = RegExp(r'\[([^\[\]]+)\]');
                final matches = regex.allMatches(annotation);

                // 2026-05-19 (v1.2.55): inside-chip text colour
                // switched from `onSecondaryContainer` (high-contrast
                // on the old teal-bg variant) to the regular body
                // text colour, since the new bg is now a much
                // lighter primary-tint (alpha 0.12). Normal body
                // colour reads more naturally as "this is verse
                // text, slightly tinted to mark it clickable".
                final bodyColor = Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.color ??
                    scheme.onSurface;
                if (matches.isNotEmpty) {
                  int lastEnd = 0;
                  for (final match in matches) {
                    if (match.start > lastEnd) {
                      badgeSpans.add(TextSpan(
                        text: annotation.substring(lastEnd, match.start),
                        style: TextStyle(
                          fontSize: settings.fontSize,
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                          height: settings.lineSpacing,
                          color: bodyColor,
                        ),
                      ));
                    }
                    final text = match.group(1)!;
                    badgeSpans.add(TextSpan(
                      text: text,
                      style: TextStyle(
                        fontSize: settings.fontSize,
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        height: settings.lineSpacing,
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted,
                        // 2026-05-07: same toning-down as the
                        // top-level square-bracket case — softer
                        // dotted underline so divine-name substitutes
                        // and LEB editorial inserts are marked
                        // without dominating the line.
                        decorationColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.5),
                        decorationThickness: 1.0,
                        color: bodyColor,
                      ),
                    ));
                    lastEnd = match.end;
                  }
                  if (lastEnd < annotation.length) {
                    badgeSpans.add(TextSpan(
                      text: annotation.substring(lastEnd),
                      style: TextStyle(
                        fontSize: settings.fontSize,
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        height: settings.lineSpacing,
                        color: bodyColor,
                      ),
                    ));
                  }

                  return RichText(text: TextSpan(children: badgeSpans));
                } else {
                  return Text(
                    annotation,
                    style: TextStyle(
                      fontSize: settings.fontSize,
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                      height: settings.lineSpacing,
                      color: bodyColor,
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ));
      lastPart = part;
      continue;
    }
    if (squarePattern.hasMatch(part)) {
      final annotation = squarePattern.firstMatch(part)!.group(1)!;
      // 2026-05-07 (post-fix): the dotted underline used to be 2.0 px
      // in the theme's primary color, which read as a heavy "edit
      // mark" beneath divine-name substitutions like [雅伟] and
      // editorial inserts in LEB. The user found this noisy. Tone
      // down to 1.0 px with a softened (50% alpha) decoration color
      // — still legible as a marker that the word is bracketed but
      // no longer dominates the line.
      // 2026-06-30: the bracketed editorial notation ([雅伟] where the
      // original had a pronoun referring to Yahweh, LEB inserts, etc.) is
      // itself a notation, so mark it in the theme accent — same as the
      // <note:> footnote marker — with a clean thin underline for the tap
      // affordance. (User confirmed they want the [] notation coloured too.)
      spans.add(TextSpan(
        text: annotation,
        recognizer: onTextTap != null
            ? (TapGestureRecognizer()..onTap = onTextTap)
            : null,
        style: TextStyle(
          fontSize: settings.fontSize,
          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
          height: settings.lineSpacing,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.solid,
          decorationColor: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.45),
          decorationThickness: 1.0,
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.primary,
          backgroundColor: spanBgColor,
        ),
      ));
      lastPart = part;
      continue;
    }
    if (notePattern.hasMatch(part) &&
        !bracePattern.hasMatch(part) &&
        !(part.trim().startsWith('<note:') &&
            part.trim().endsWith('>') &&
            (lastPart?.trim().endsWith('}') ?? false))) {
      final note = notePattern.firstMatch(part)!.group(1)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.bottom,
        child: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(
                  uiStrings['note']?[locale] ?? 'Note',
                  style: TextStyle(
                    fontSize: settings.fontSize + 2,
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Text(note),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      uiStrings['ok']?[locale] ?? 'OK',
                      style: TextStyle(
                        fontSize: settings.fontSize,
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                      ),
                    ),
                  )
                ],
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(right: 4.0, left: 2.0, bottom: 5.0),
            child: Icon(
              // 2026-05-19 (v1.2.55): note-marker glyph + size tuned.
              // The book icon at fontSize * 1.2 used to dominate the
              // line — especially in paragraph mode where notes
              // appear mid-prose. Switched to the smaller
              // `Icons.notes_rounded` at fontSize * 0.9, which reads
              // as a discoverable footnote marker without breaking
              // the prose flow. biblexg-v2 (~1,133 notes across NT)
              // and LEB (~23k) both render this way.
              Icons.notes_rounded,
              size: settings.fontSize * 0.9,
              // 2026-06-30: accent colour (was a faint onSurfaceVariant grey)
              // so the footnote marker reads clearly as a tappable notation,
              // matching the coloured [...] insertions above.
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ));
      lastPart = part;
      continue;
    }
    {
      // Round 56: normalize the visible chunk before rendering — strips
      // the pilcrow/section markers some Bible versions ship in their
      // asset JSON and rewrites 耶和华/耶和華/the LORD into 雅伟/雅偉/
      // Yahweh so the divine name is consistent across every version.
      // `displayCleanup` preserves leading/trailing spaces between
      // adjacent chunks (sanitizeForSearch's `.trim()` would collapse
      // them and merge words across span boundaries).
      spans.add(TextSpan(
        text: displayCleanup(part),
        recognizer: onTextTap != null
            ? (TapGestureRecognizer()..onTap = onTextTap)
            : null,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: settings.fontSize,
              height: settings.lineSpacing,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).textTheme.bodyLarge?.color,
              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
              fontStyle: isReferenceLine ? FontStyle.italic : FontStyle.normal,
              backgroundColor: spanBgColor,
            ),
      ));
      lastPart = part;
    }
  }

  return spans;
}
