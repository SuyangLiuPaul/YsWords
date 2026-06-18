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

// 2026-05-19 (v1.2.61): extended regex now also matches compact
// references with multiple verse-specs separated by commas:
//   [Book Ch:V]            — single verse
//   [Book Ch:V-V]          — verse range
//   [Book Ch:V,V,V-V,V]    — comma-list mixing singles + ranges
//   [Book Ch:V，V，V-V]      — Chinese full-width commas
//
// The verse-spec group captures the WHOLE comma-list (e.g.
// "2,5,7,9-10"); parsing into individual verses happens in
// [_parseVerseSpec] which the span-builder calls before
// constructing the [NoteReferenceMatch].
final _referenceRegex = RegExp(
  // Book group 1: any non-bracket chars (filtered post-match through
  //               resolveBookName so typos and made-up names fall
  //               back to plain text without crashing)
  // Chapter group 2: ASCII digits
  // Verse-spec group 3: one or more (digit-range) tokens separated by
  //                     commas. A token is `\d+(?:[-–]\d+)?` —
  //                     a single number or a hyphenated range.
  r'\[([^\[\]]+?)[ 　]+(\d+)[:：]'
  r'(\d+(?:[-–]\d+)?(?:[,，]\s*\d+(?:[-–]\d+)?)*)\]',
);

class NoteReferenceMatch {
  /// Canonical English book name (resolved via [bookNameToEnglish]).
  /// Always one of the 66 canon books — invalid refs are filtered
  /// out by the parser before this object is constructed.
  final String englishBook;
  final int chapter;

  /// First verse referenced (lowest of [verses]). Kept for
  /// backwards compatibility with v1.2.59 callers — the jump-to
  /// path lands on this verse.
  final int verseStart;

  /// Last verse in the FIRST contiguous range. Equivalent to
  /// `verses.last` for a single-range ref like `1:2-5`. For comma-
  /// lists like `1:2,5,7,9-10` it's `verses[1] == 2`, NOT 10 —
  /// callers wanting the absolute last verse should use
  /// `verses.last`. Kept for v1.2.59 callsite compatibility.
  final int? verseEnd;

  /// 2026-05-19 (v1.2.61): full flat list of every verse the ref
  /// covers, sorted ascending, de-duplicated.  For `[Gen 1:2,5,7,9-10]`
  /// this is `[2, 5, 7, 9, 10]`. Single-verse refs have length 1.
  /// Range refs are exploded into the full set. Empty list never
  /// occurs — parser only constructs valid matches.
  final List<int> verses;

  const NoteReferenceMatch({
    required this.englishBook,
    required this.chapter,
    required this.verseStart,
    this.verseEnd,
    this.verses = const [],
  });
}

/// Parses a verse-spec like "2", "2-5", "2,5,7,9-10" into a sorted
/// de-duplicated flat list. Returns an empty list when the spec
/// is malformed (any token fails to parse). Tolerates both ASCII
/// and CJK comma separators + hyphen / em-dash range markers.
List<int> _parseVerseSpec(String spec) {
  final out = <int>{};
  // Split on either ASCII `,` or CJK `，`. The capturing group
  // catches both characters so we don't have to normalize first.
  final tokens = spec.split(RegExp(r'[,，]'));
  for (var raw in tokens) {
    final token = raw.trim();
    if (token.isEmpty) return const [];
    // Range or single? `-` or `–`.
    final rangeMatch = RegExp(r'^(\d+)[-–](\d+)$').firstMatch(token);
    if (rangeMatch != null) {
      final lo = int.tryParse(rangeMatch.group(1)!);
      final hi = int.tryParse(rangeMatch.group(2)!);
      if (lo == null || hi == null || lo > hi) return const [];
      for (var i = lo; i <= hi; i++) {
        out.add(i);
      }
    } else {
      final v = int.tryParse(token);
      if (v == null) return const [];
      out.add(v);
    }
  }
  final list = out.toList()..sort();
  return list;
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
    final verseSpec = m.group(3) ?? '';
    final verses = _parseVerseSpec(verseSpec);

    if (canonical != null &&
        chapter != null &&
        verses.isNotEmpty) {
      // Compute v1.2.59-shape verseStart / verseEnd for backwards
      // compatibility (jump-to lands on verseStart). For a comma-
      // list like 2,5,7,9-10 → verseStart=2, verseEnd=null (no
      // single contiguous range covers the whole spec); for a
      // pure range 2-5 → verseStart=2, verseEnd=5.
      final isContiguous = verses.last == verses.first + verses.length - 1;
      final ref = NoteReferenceMatch(
        englishBook: canonical,
        chapter: chapter,
        verseStart: verses.first,
        verseEnd:
            (verses.length > 1 && isContiguous) ? verses.last : null,
        verses: verses,
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

/// 2026-05-20 (v1.2.65): extract every parseable `[Book Ch:V…]`
/// reference from [noteText] as a list of [NoteReferenceMatch].
///
/// Used by the note editor's live ref-chip strip (the chips that
/// appear below the TextField as the user types or inserts refs
/// via the picker). Each chip taps to open the same VersePopupSheet
/// the Library Notes view uses, so the user can preview a referenced
/// verse WITHOUT having to save the note first.
///
/// Identical filtering rules to [buildNoteSpans]:
///   • Book name must resolve via [resolveBookName] (English canonical,
///     common abbreviations, Chinese short / full forms)
///   • Verse spec must parse to a non-empty sorted list of positive
///     integers
///   • Malformed refs (typo book, inverted range, empty spec) are
///     silently dropped — chip simply doesn't render
///
/// Returns the matches in source order (left-to-right in the
/// note text). Duplicates are NOT deduped — if the user wrote
/// `[John 3:16]` twice the chip strip shows two chips. (Library
/// rendering does the same; cheap and predictable.)
List<NoteReferenceMatch> extractNoteReferences(String noteText) {
  if (noteText.isEmpty) return const [];
  final out = <NoteReferenceMatch>[];
  for (final m in _referenceRegex.allMatches(noteText)) {
    final rawBook = m.group(1)?.trim() ?? '';
    final canonical = resolveBookName(rawBook);
    final chapter = int.tryParse(m.group(2) ?? '');
    final verseSpec = m.group(3) ?? '';
    final verses = _parseVerseSpec(verseSpec);
    if (canonical == null || chapter == null || verses.isEmpty) {
      continue;
    }
    final isContiguous =
        verses.last == verses.first + verses.length - 1;
    out.add(NoteReferenceMatch(
      englishBook: canonical,
      chapter: chapter,
      verseStart: verses.first,
      verseEnd: (verses.length > 1 && isContiguous) ? verses.last : null,
      verses: verses,
    ));
  }
  return out;
}

/// Convenience: a `[Book Ch:V]` template the picker sheet emits.
/// Centralised here so the parser regex and the picker output
/// can't drift apart.
/// [displayBook] (v1.3.90): the book name actually written into the
/// bracket — a localized name (e.g. 约翰福音) so the inserted reference
/// reads in the user's language. Defaults to [englishBook] for callers
/// that want the canonical English form. The parser resolves localized
/// names back to English, so the round-trip stays lossless (covered by
/// note_reference_localized_roundtrip_test.dart).
String formatReferenceForInsertion({
  required String englishBook,
  required int chapter,
  required int verse,
  String? displayBook,
}) =>
    '[${displayBook ?? englishBook} $chapter:$verse]';

/// 2026-05-19 (v1.2.61): compact reference formatter for the new
/// multi-select picker. Takes a list of verse numbers and produces
/// the shortest valid reference string, collapsing consecutive
/// verses into ranges.
///
///   [2]           → "[Book 1:2]"
///   [2,3,4,5]     → "[Book 1:2-5]"
///   [2,5]         → "[Book 1:2,5]"
///   [2,3,5,7,9,10] → "[Book 1:2-3,5,7,9-10]"
///   [] / chapter ≤ 0 / verses with non-positive entries
///                  → "" (no reference; caller should treat as
///                       "user cancelled" and not insert anything)
///
/// Output is always parseable by the v1.2.61 [_referenceRegex] so
/// the picker → insertion → re-parse round-trip is lossless.
String formatCompactReference({
  required String englishBook,
  required int chapter,
  required List<int> verses,
  String? displayBook,
}) {
  if (englishBook.isEmpty || chapter <= 0 || verses.isEmpty) return '';
  // Dedupe + sort
  final seen = <int>{};
  final sorted = verses.where((v) {
    if (v <= 0 || !seen.add(v)) return false;
    return true;
  }).toList()
    ..sort();
  if (sorted.isEmpty) return '';

  // Group consecutive verses into ranges
  final parts = <String>[];
  int start = sorted.first;
  int end = start;
  for (var i = 1; i < sorted.length; i++) {
    final v = sorted[i];
    if (v == end + 1) {
      end = v;
    } else {
      parts.add(start == end ? '$start' : '$start-$end');
      start = v;
      end = v;
    }
  }
  parts.add(start == end ? '$start' : '$start-$end');

  return '[${displayBook ?? englishBook} $chapter:${parts.join(',')}]';
}
