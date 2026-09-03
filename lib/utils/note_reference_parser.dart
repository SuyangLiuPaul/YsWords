import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:yswords/utils/note_markdown.dart';
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
/// `[Book Ch:V]` becomes a styled [TextSpan] — tappable (invoking
/// [onRefTap]) when [onRefTap] is provided. Everything else flows
/// through as plain text.
///
/// [onRefTap] is optional: pass `null` for read-only rendering
/// without tap handling (a [TapGestureRecognizer] fighting an
/// editable field's own selection gesture detector is the kind of
/// thing that's easy to get subtly wrong, so editable callers —
/// see the note editor's ref-highlighting `TextEditingController`
/// — skip it entirely and rely on the separate ref-chip strip for
/// tap-to-preview).
///
/// [refBackgroundColor], when supplied, paints a solid block behind
/// each matched reference (in addition to [refColor]'s text tint),
/// giving it a pill-like look. Omit for the original underlined-link
/// style.
///
/// Returns a single-element list with one plain [TextSpan] when
/// [noteText] is empty or contains no references — keeps callers
/// simple (always render the result via `RichText(text:
/// TextSpan(children: spans))`).
///
/// 2026-09-03: [markdown] layers the note formatting subset —
/// `**bold**`, `*italic*` / `_italic_`, `- ` lists — on top of the
/// reference spans. It defaults to [NoteMarkdownMode.render] so that
/// any display site added later is formatted without having to
/// remember to ask; the two callers that must opt out say so
/// explicitly:
///
///   • the note editor's `_RefHighlightingController` passes
///     [NoteMarkdownMode.source], because a `TextEditingController`'s
///     spans must contain exactly the controller's characters and
///     [spliceComposingUnderline] indexes them by absolute offset.
///   • [NoteMarkdownMode.off] reproduces the pre-formatting behaviour
///     verbatim, for anything that needs the literal text.
///
/// Formatting is applied on top of the reference styling, not instead
/// of it, so `**[John 3:16] matters**` keeps its tappable, underlined
/// reference AND draws bold.
List<InlineSpan> buildNoteSpans({
  required String noteText,
  required TextStyle baseStyle,
  required Color refColor,
  void Function(NoteReferenceMatch ref)? onRefTap,
  Color? refBackgroundColor,
  NoteMarkdownMode markdown = NoteMarkdownMode.render,
}) {
  if (noteText.isEmpty) {
    return [TextSpan(text: '', style: baseStyle)];
  }

  // A complete tiling of noteText, or empty when formatting is off —
  // in which case [emit] falls back to one span per segment, exactly
  // the shape this function returned before formatting existed.
  final runs = markdown == NoteMarkdownMode.off
      ? const <NoteMarkdownRun>[]
      : scanNoteMarkdown(noteText);

  final spans = <InlineSpan>[];

  /// Append `noteText[a..b)` styled with [style], split wherever the
  /// formatting runs change. [recognizer] is shared across the slices
  /// of one reference so a bold reference stays a single tap target.
  void emit(int a, int b, TextStyle style, {GestureRecognizer? recognizer}) {
    if (b <= a) return;
    if (runs.isEmpty) {
      spans.add(TextSpan(
          text: noteText.substring(a, b),
          style: style,
          recognizer: recognizer));
      return;
    }
    for (final run in runs) {
      if (run.end <= a) continue;
      if (run.start >= b) break;
      final lo = run.start < a ? a : run.start;
      final hi = run.end > b ? b : run.end;
      if (hi <= lo) continue;
      if (run.isMarker && markdown == NoteMarkdownMode.render) {
        // Delimiters vanish; a list marker becomes its bullet glyph,
        // emitted once even if a reference splits the segment.
        if (run.renderAs.isEmpty || lo != run.start) continue;
        spans.add(TextSpan(
          text: run.renderAs,
          style: styleForNoteRun(run, style, markdown),
          recognizer: recognizer,
        ));
        continue;
      }
      spans.add(TextSpan(
        text: noteText.substring(lo, hi),
        style: styleForNoteRun(run, style, markdown),
        recognizer: recognizer,
      ));
    }
  }

  int cursor = 0;
  for (final m in _referenceRegex.allMatches(noteText)) {
    // Plain prefix between previous cursor and this match
    if (m.start > cursor) {
      emit(cursor, m.start, baseStyle);
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
      emit(
        m.start,
        m.end,
        refBackgroundColor != null
            // Pill look (note editor, inline highlight): solid
            // background instead of the underlined-link treatment —
            // dotted underlines read as "tap me" against a plain
            // background, but inside an editable field with no tap
            // handler that promise would be broken.
            ? baseStyle.copyWith(
                color: refColor,
                fontWeight: FontWeight.w600,
                backgroundColor: refBackgroundColor,
              )
            : baseStyle.copyWith(
                color: refColor,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: refColor.withValues(alpha: 0.7),
                decorationThickness: 1.2,
              ),
        recognizer: onRefTap == null
            ? null
            : (TapGestureRecognizer()..onTap = () => onRefTap(ref)),
      );
    } else {
      // Looks like a reference but the book name isn't canonical
      // (typo, made-up name, or untranslated abbreviation we don't
      // alias). Fall through to plain text so the user sees what
      // they typed — never a silent drop.
      emit(m.start, m.end, baseStyle);
    }
    cursor = m.end;
  }
  // Trailing plain text after the last match
  if (cursor < noteText.length) {
    emit(cursor, noteText.length, baseStyle);
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

/// 2026-08-02: splice the platform's IME composing-region underline
/// into an already-styled span list (e.g. from [buildNoteSpans])
/// WITHOUT discarding the rest of that styling.
///
/// Field report: the note editor's ref-highlighting controller used
/// to bail out to a completely plain render for the WHOLE text
/// whenever ANY composing session was active anywhere in the note —
/// so every already-inserted `[Book Ch:V]` pill (English or Chinese)
/// would flicker back to plain text on every pinyin keystroke, even
/// far from the composing cursor, then snap back once the syllable
/// committed. "如果中文英文插入这个不是跟着变的" (typing Chinese/
/// English, the highlight doesn't keep up).
///
/// [composing] must be a valid, non-collapsed range (callers should
/// check `value.isComposingRangeValid` first — this function doesn't
/// re-derive that from a bare `TextEditingValue` because
/// `TextEditingController.value.composing` is what callers already
/// have on hand). [spans] must be the FLAT `TextSpan(text: ..., style:
/// ...)` list [buildNoteSpans] returns (no nested children) — that's
/// the only shape this walks.
List<InlineSpan> spliceComposingUnderline(
  List<InlineSpan> spans,
  TextRange composing, {
  TextStyle? fallbackStyle,
}) {
  final spliced = <InlineSpan>[];
  var consumed = 0;
  for (final span in spans) {
    if (span is! TextSpan || span.text == null) {
      spliced.add(span);
      continue;
    }
    final spanText = span.text!;
    final start = consumed;
    final end = consumed + spanText.length;
    consumed = end;
    if (end <= composing.start || start >= composing.end) {
      // This span doesn't overlap the composing range at all.
      spliced.add(span);
      continue;
    }
    final composingStyle = (span.style ?? fallbackStyle)
            ?.merge(const TextStyle(decoration: TextDecoration.underline)) ??
        const TextStyle(decoration: TextDecoration.underline);
    final localStart = (composing.start - start).clamp(0, spanText.length);
    final localEnd = (composing.end - start).clamp(0, spanText.length);
    if (localStart > 0) {
      spliced.add(TextSpan(
          text: spanText.substring(0, localStart), style: span.style));
    }
    spliced.add(TextSpan(
        text: spanText.substring(localStart, localEnd),
        style: composingStyle));
    if (localEnd < spanText.length) {
      spliced.add(TextSpan(
          text: spanText.substring(localEnd), style: span.style));
    }
  }
  return spliced;
}

/// 2026-08-02: rewrites every matched `[Book Ch:V]` reference's BOOK
/// NAME to [displayBookFor]'s answer, leaving chapter/verse digits,
/// non-reference text, and any bracket-shaped-but-invalid text
/// completely untouched.
///
/// Field request: a user typing a quick English abbreviation like
/// `[1 Kings 17:21]` in an otherwise-Chinese note saw the ref-chip
/// strip correctly preview it as "列王纪上 17:21" (chips always
/// localize for display — see [buildNoteSpans]'s note-editor caller),
/// but the note BODY stayed in English, which read as inconsistent:
/// "你看下面是列王纪上但是文字是1King". Call this once at SAVE time
/// (not on every keystroke) — see `showNoteEditor`'s Save handler —
/// so normalizing a reference's script never fights the user's live
/// cursor position while they're still typing.
///
/// [displayBookFor] takes the resolved CANONICAL English book name
/// and returns the name to substitute — callers pass
/// `(canonical) => localeAwareBookName(canonical, locale, currentVersion)`,
/// the exact same resolution the chip strip already uses, so the
/// saved text and the chip preview always agree.
String normalizeNoteReferenceBookNames(
  String noteText,
  String Function(String canonicalEnglishBook) displayBookFor,
) {
  if (noteText.isEmpty) return noteText;
  final buffer = StringBuffer();
  var cursor = 0;
  for (final m in _referenceRegex.allMatches(noteText)) {
    final rawBook = m.group(1)?.trim() ?? '';
    final canonical = resolveBookName(rawBook);
    final chapter = int.tryParse(m.group(2) ?? '');
    final verseSpec = m.group(3) ?? '';
    final verses = _parseVerseSpec(verseSpec);
    if (canonical == null || chapter == null || verses.isEmpty) {
      continue; // Not a real reference — leave verbatim.
    }
    final replacement = formatCompactReference(
      englishBook: canonical,
      chapter: chapter,
      verses: verses,
      displayBook: displayBookFor(canonical),
    );
    if (replacement.isEmpty) continue; // Defensive — shouldn't happen.
    buffer.write(noteText.substring(cursor, m.start));
    buffer.write(replacement);
    cursor = m.end;
  }
  buffer.write(noteText.substring(cursor));
  return buffer.toString();
}
