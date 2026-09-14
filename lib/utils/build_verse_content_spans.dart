import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/constants/text_patterns.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/widgets/verse_notes_block.dart'
    show superscriptNumber;
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
  /// The footnotes this line currently has open, and the way to toggle
  /// one. Given both, a note opens UNDER the line; given neither, it
  /// opens in a dialog as it always has.
  List<String>? noteSink,
  // False only for a psalm superscription, which has no verse number to
  // show. Everything else about the line — `[insert]` brackets and
  // `<note: …>` markers — renders exactly as it does in verse text.
  bool showVerseNumber = true,
  /// The edition these verses came from, so `[...]` can be rendered with
  /// its brackets intact in the editions where the brackets ARE the
  /// notation. Null (the default) keeps the pre-2026-09-01 behaviour of
  /// showing the bracketed word styled but bare, which is still right
  /// for LEB and NASB. Callers pass the PANE's version — each split-view
  /// pane has its own `MainProvider`, so `renderedVersion` is per-pane
  /// and the two sides can legitimately differ.
  String? versionCode,
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
  // consistently. Both modes now use the FULL primary.
  //
  // Paragraph mode used to reduce it to 80% alpha "so it stays subtle
  // next to continuous prose", which measured 4.07:1 at 13 px against
  // the default surface — under the 4.5 bar for text that size. The
  // subtlety it was buying is already carried by the size and the
  // superscript baseline; the alpha was buying a second helping of it
  // with legibility.
  //
  // Worth naming the shape of the bug rather than just the number: an
  // alpha reduction of `primary` has NO lower bound, because `primary`
  // is whatever theme colour the reader picked in Settings. A pale seed
  // makes it worse and nothing in the app notices.
  final verseNumColor = isSelected
      ? Theme.of(context).colorScheme.onPrimaryContainer
      : Theme.of(context).colorScheme.primary;

  final verseNumStyle = TextStyle(
    fontSize:
        superscriptVerseNum ? settings.fontSize * 0.65 : settings.fontSize,
    height: superscriptVerseNum ? 1.0 : settings.lineSpacing,
    fontWeight: superscriptVerseNum ? FontWeight.w600 : FontWeight.w500,
    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
    fontStyle: isReferenceLine ? FontStyle.italic : FontStyle.normal,
    color: verseNumColor,
  );

  // 2026-09-14: the number does what the verse does, and nothing else.
  //
  // It used to fall back to "copy this verse to the clipboard" whenever
  // [onTextTap] was null — twenty lines of clipboard-and-snackbar that
  // NO caller could reach: both widgets that show a verse number pass
  // [onTextTap], and the third caller (a psalm superscription) passes
  // `showVerseNumber: false`. Dead, but not harmless, because of where
  // it sat: any future caller that forgot the callback would have had
  // its readers silently overwrite the clipboard by tapping a number
  // that looks exactly like the text around it. A fallback that
  // diverges from the live path is worse than no fallback.
  //
  // Worth being plain about the target size, since this is the smallest
  // one in the reading pane: in paragraph mode the number is
  // `fontSize * 0.65` — about 11 px at the default — which is nowhere
  // near the 24 px of WCAG 2.5.8. It is not a violation and it is not
  // worth padding. 2.5.8's inline exception covers a target sized by
  // the line height of the text it sits in, and more to the point the
  // number is not a separate target at all: it does the same thing as
  // the several lines of verse wrapped around it, so a miss costs the
  // reader nothing. Padding it to 24 px would push prose apart on every
  // line of every chapter to fix a miss that has no consequence.
  final verseNumChild = Padding(
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
  );

  final verseNumSpan = WidgetSpan(
    alignment: superscriptVerseNum
        ? PlaceholderAlignment.top
        : PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    // No callback, no gesture detector: an opaque hit region that does
    // nothing still swallows the tap meant for the text underneath it.
    child: onTextTap == null
        ? verseNumChild
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTextTap,
            child: verseNumChild,
          ),
  );
  if (showVerseNumber) spans.add(verseNumSpan);

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
      //
      // 2026-09-01: the accent alone is not enough, and colour was
      // carrying meaning it cannot carry. In 和合本雅伟版 the brackets
      // are the EDITION'S OWN notation for an editorial insertion — the
      // Greek of Matt 1:20 reads ἄγγελος κυρίου, "an angel of the
      // Lord", so 雅伟 there is supplied by the editor, not translated
      // from the text. Printing it as bare coloured text says only
      // "this word is special"; a reader has no way to learn from a
      // colour that the word is not in the original, and the natural
      // reading is that it is. The user reported exactly that risk.
      //
      // So the brackets are restored AROUND the existing styling
      // rather than replacing it — both, not either. Two further facts
      // decided the scope:
      //
      //   * the asset already ships them. `主[雅偉]的使者` is what is
      //     in cuvs-yhwh-tr.json; this render path was consuming them.
      //     The prerendered /read/ pages never did, so the crawlable
      //     page and the app disagreed about the same verse.
      //   * measured across the shipped assets, `[...]` means different
      //     things per edition: cuvs-yhwh(-tr) has 229 spans and only
      //     TWO distinct ones, [雅伟] (212) and [基督] (17) — both
      //     referent insertions. LEB has 29,652, overwhelmingly
      //     supplied function words ([the], [is], [are]); NASB has 6,
      //     whole disputed sentences. Bracketing LEB's would put
      //     visible brackets around thirty thousand English function
      //     words, which is a different product decision nobody asked
      //     for. Hence version-scoped, per the user's own wording
      //     ("both simplified and traditional 雅偉版本").
      final showBrackets = versionCode != null &&
          kBracketPreservingVersions.contains(versionCode);
      spans.add(TextSpan(
        text: showBrackets ? '[$annotation]' : annotation,
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
      if (noteSink != null) {
        // 2026-09-14: the 雅偉的話 shape, adopted whole on the owner's
        // instruction. The marker is a superscript NUMBER and the note
        // goes to the caller, which sets every note of the verse as one
        // numbered block underneath — see `lib/widgets/verse_notes_block.dart`
        // for why each part of it is the way it is.
        //
        // 「根本看不清」 / 「para mode不好按」 / 「你就截开几段用起来很
        // 难受」: the notes had no structure, the tap target was a glyph
        // a few pixels wide mid-prose, and opening one cut the verse
        // into pieces. One shape caused all three.
        noteSink.add(note.trim());
        // Consecutive markers collapse to a range: `¹⁻⁵`, not `¹²³⁴⁵`.
        // Five superscripts in a row read as the single number 12345 —
        // you cannot see where one ends — and 梁家鏗 puts runs of them
        // at the end of a verse constantly. A run only happens where the
        // notes share a position, so the range loses nothing.
        final previous = spans.isEmpty ? null : spans.last;
        if (previous is TextSpan &&
            previous.text != null &&
            _isNoteMarker(previous.text!)) {
          spans[spans.length - 1] = TextSpan(
            text: '${_markerStart(previous.text!)}\u2060⁻\u2060'
                '${superscriptNumber(noteSink.length)}',
            style: previous.style,
          );
          lastPart = part;
          continue;
        }
        spans.add(TextSpan(
          text: superscriptNumber(noteSink.length),
          style: TextStyle(
            fontSize: settings.fontSize * 0.75,
            fontFamily: settings.fontFamily,
            fontFamilyFallback: kCjkFontFallback,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.primary,
            backgroundColor: spanBgColor,
          ),
        ));
        lastPart = part;
        continue;
      }
      // No sink: a caller with nowhere to put a block still answers a
      // tap, with the dialog this used to open everywhere.
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
                    fontFamily: settings.fontFamily,
                    fontFamilyFallback: kCjkFontFallback,
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
                        fontFamily: settings.fontFamily,
                        fontFamilyFallback: kCjkFontFallback,
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
              Icons.notes_rounded,
              size: settings.fontSize * 0.9,
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

/// Whether a span's text is one of this file's own note markers — a run
/// of superscript digits, optionally already a range.
bool _isNoteMarker(String text) =>
    text.isNotEmpty &&
    text.runes.every((r) => '⁰¹²³⁴⁵⁶⁷⁸⁹⁻\u2060'.runes.contains(r));

/// The first number of a marker that may already be a range.
String _markerStart(String text) => text.split('\u2060').first;
