import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:yswords/utils/reference_parser.dart' show resolveBookName;

/// 2026-05-19 (v1.2.59): parses user-written note text and returns
/// an [InlineSpan] list where any `[Book Ch:V]` or `[Book Ch:V-V]`
/// pattern is rendered as a tappable verse reference.
///
/// Supported reference forms (matched by [_referenceRegex]):
///   • `[John 3:16]`           — single-verse English
///   • `[John 3:16-18]`        — verse range, ASCII hyphen
///   • `[John 3:16–18]`        — verse range, em-dash
///   • `[约翰福音 3:16]`        — CJK book name (full)
///   • `[约 3:16]`              — CJK book name (abbreviation — if
///                                resolvable by [bookNameToEnglish])
///   • `[Matt 5:1]` / `[1 Cor 13:4]` — multi-word book names
///   • `[Genesis 1:1：2]`       — full-width colon (CJK)
///
/// Anything inside `[…]` that doesn't match this shape is left as
/// plain text (no link), so the parser is safe to run over any
/// pre-existing note that the user typed before this feature
/// existed.
///
/// The caller passes a handler [onRefTap] which receives the
/// resolved canonical English book name + chapter + verse-start.
/// Verse range end is dropped — the jump lands on the first verse,
/// matching every other navigation surface in the app.
///
/// Plain (non-reference) text gets the [baseStyle] caller supplies.
/// References inherit [baseStyle] then override colour + add a
/// dotted underline, so font / size / italic flow through cleanly.

final _referenceRegex = RegExp(
  // [Book Chapter:Verse(-VerseEnd)?]
  // Book: 1+ non-bracket chars (lets us match 'John', '1 Corinthians',
  //       '约翰福音', '约' etc. — we filter post-match via
  //       bookNameToEnglish)
  // Chapter / verse: ASCII digits (most translations stay ASCII even
  //       for CJK locales; the data we ship does)
  // Separator: `:` or `：` (full-width)
  // Range separator: `-` or `–`
  r'\[([^\[\]]+?)[ 　]+(\d+)[:：](\d+)(?:[-–](\d+))?\]',
);

class NoteReferenceMatch {
  /// Canonical English book name (resolved via [bookNameToEnglish]).
  /// Always one of the 66 canon books — invalid refs are filtered
  /// out by the parser before this object is constructed.
  final String englishBook;
  final int chapter;
  final int verseStart;
  final int? verseEnd;

  const NoteReferenceMatch({
    required this.englishBook,
    required this.chapter,
    required this.verseStart,
    this.verseEnd,
  });
}

/// Builds an [InlineSpan] list from [noteText]. Any well-formed
/// `[Book Ch:V]` becomes a tappable [TextSpan] that invokes
/// [onRefTap] when tapped. Everything else flows through as plain
/// text.
///
/// Returns a single-element list with one plain [TextSpan] when
/// [noteText] is empty or contains no references — keeps callers
/// simple (always render the result via `RichText(text:
/// TextSpan(children: spans))`).
List<InlineSpan> buildNoteSpans({
  required String noteText,
  required TextStyle baseStyle,
  required Color refColor,
  required void Function(NoteReferenceMatch ref) onRefTap,
}) {
  if (noteText.isEmpty) {
    return [TextSpan(text: '', style: baseStyle)];
  }

  final spans = <InlineSpan>[];
  int cursor = 0;
  for (final m in _referenceRegex.allMatches(noteText)) {
    // Plain prefix between previous cursor and this match
    if (m.start > cursor) {
      spans.add(TextSpan(
        text: noteText.substring(cursor, m.start),
        style: baseStyle,
      ));
    }

    final rawBook = m.group(1)?.trim() ?? '';
    // Use the shared resolver from reference_parser.dart, which
    // handles canonical English names, common English abbreviations
    // ('Matt', 'Mk', 'Lk', 'Jn', '1 Cor', …), Chinese short forms
    // ('约', '太', '罗'), and Simplified/Traditional full names. The
    // `bookNameToEnglish` map alone only covers the canonical
    // English + full Chinese forms.
    final canonical = resolveBookName(rawBook);
    final chapter = int.tryParse(m.group(2) ?? '');
    final vStart = int.tryParse(m.group(3) ?? '');
    final vEnd = int.tryParse(m.group(4) ?? '');

    if (canonical != null && chapter != null && vStart != null) {
      // Valid reference — render as tappable.
      final ref = NoteReferenceMatch(
        englishBook: canonical,
        chapter: chapter,
        verseStart: vStart,
        verseEnd: vEnd,
      );
      spans.add(TextSpan(
        text: noteText.substring(m.start, m.end),
        style: baseStyle.copyWith(
          color: refColor,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
          decorationColor: refColor.withValues(alpha: 0.7),
          decorationThickness: 1.2,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => onRefTap(ref),
      ));
    } else {
      // Looks like a reference but the book name isn't canonical
      // (typo, made-up name, or untranslated abbreviation we don't
      // alias). Fall through to plain text so the user sees what
      // they typed — never a silent drop.
      spans.add(TextSpan(
        text: noteText.substring(m.start, m.end),
        style: baseStyle,
      ));
    }
    cursor = m.end;
  }
  // Trailing plain text after the last match
  if (cursor < noteText.length) {
    spans.add(TextSpan(
      text: noteText.substring(cursor),
      style: baseStyle,
    ));
  }
  return spans.isEmpty ? [TextSpan(text: noteText, style: baseStyle)] : spans;
}

/// Convenience: a `[Book Ch:V]` template the picker sheet emits.
/// Centralised here so the parser regex and the picker output
/// can't drift apart.
String formatReferenceForInsertion({
  required String englishBook,
  required int chapter,
  required int verse,
}) =>
    '[$englishBook $chapter:$verse]';
