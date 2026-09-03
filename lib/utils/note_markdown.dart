// 2026-09-03 — formatting for user notes: bold, italic, lists.
//
// User, 2026-08-16: "notes要加format之类的可以做？在chapter里面做笔记的
// 时候". The scope chosen over a full rich-text editor is deliberately
// three things — **bold**, *italic*, and lists — and the storage
// decision follows from the fact that notes SYNC:
//
//   A note is still exactly what it has always been: a plain `String`
//   in `MainProvider._verseNotes`, `jsonEncode`d into SharedPreferences
//   and into the RTDB snapshot. What changed is that the string is now
//   *interpreted* as this small Markdown subset when it is drawn.
//
// That is the whole migration story: there isn't one. Every note ever
// written is already a valid document in this subset, an older build
// that doesn't know about formatting still reads and writes the same
// field, and `RealtimeDbSyncService._mergeSnapshots` keeps merging
// opaque strings per verse id exactly as before. A structured document
// — a wrapper object, a schema version, a delta list — would have made
// every existing note a thing needing conversion, on every device, with
// no way to roll back. `test/note_formatting_migration_test.dart` pins
// the round trip that makes the claim checkable.
//
// ── Why this is NOT `ai_markdown.dart` ──────────────────────────────
//
// `parseAiMarkdown` exists for text a MODEL wrote, where a stray
// asterisk is noise and eating it is a favour. This text a PERSON
// wrote, years before the feature existed, and eating one of their
// characters is data loss. So the inline grammar here follows
// CommonMark's flanking rules, which `ai_markdown.dart` does not:
//
//   • an opening delimiter may not be followed by whitespace
//   • a closing delimiter may not be preceded by whitespace
//   • `_` may not sit against a word character on the outside
//
// Which is precisely what keeps `5 * 4 = 20`, `a * b * c`,
// `Priority: * high * urgent`, `snake_case_name` and a row of
// underscores used as a fill-in-the-blank rendering as themselves.
// `ai_markdown.dart`'s pattern italicises the first three.
//
// ── Why the editor and the reader render differently ────────────────
//
// The note editor draws through `_RefHighlightingController`, a
// `TextEditingController` subclass. Flutter requires the spans that
// `buildTextSpan` returns to contain exactly the controller's
// characters — and `spliceComposingUnderline` walks that same span list
// by absolute character offset to place the IME underline. So the
// editor uses [NoteMarkdownMode.source], where delimiters are STYLED
// but never removed, and the reader uses [NoteMarkdownMode.render],
// where they are hidden.

import 'package:flutter/widgets.dart';

/// How note text should be drawn.
enum NoteMarkdownMode {
  /// No formatting at all. Spans reproduce the input verbatim.
  off,

  /// Read-only display: emphasis is applied and its delimiters are
  /// hidden; a `- ` list marker is drawn as `• `.
  render,

  /// Editable field: emphasis is applied, but every delimiter
  /// character stays in the span text, so the concatenated result is
  /// identical to the input. Required inside a `TextEditingController`.
  source,
}

/// One contiguous slice of the source note text and how it is drawn.
///
/// [scanNoteMarkdown] returns these as a complete, non-overlapping,
/// ascending tiling of the input — concatenating `text.substring(start,
/// end)` over the whole list reproduces the input exactly.
@immutable
class NoteMarkdownRun {
  /// Inclusive start index into the source note text.
  final int start;

  /// Exclusive end index into the source note text.
  final int end;

  final bool bold;
  final bool italic;

  /// The run is formatting punctuation (`**`, `*`, `_`, a `- ` list
  /// bullet), not content the user typed to be read. [NoteMarkdownMode.render]
  /// replaces it with [renderAs]; [NoteMarkdownMode.source] draws it dimmed.
  final bool isMarker;

  /// What [NoteMarkdownMode.render] draws in this run's place. Empty
  /// for emphasis delimiters (they vanish), `'• '` for a list bullet.
  /// Meaningless when [isMarker] is false.
  final String renderAs;

  const NoteMarkdownRun({
    required this.start,
    required this.end,
    this.bold = false,
    this.italic = false,
    this.isMarker = false,
    this.renderAs = '',
  });

  bool get isPlain => !bold && !italic && !isMarker;
}

// A bullet list item: optional indent, one of `-` `*` `+`, at least one
// space, then content. Requiring content is what stops a bare `"* "`
// note from losing its asterisk, and requiring the space is what keeps
// `*italic*` at the start of a line from being read as a bullet.
final RegExp _kBulletLine = RegExp(r'^([ \t]*)([-*+])([ \t]+)(?=\S)');

// An ordered list item. Matched only so callers can reason about it;
// nothing is rewritten, because the number the user typed IS the
// marker — replacing it would lose their numbering.
final RegExp _kOrderedLine = RegExp(r'^([ \t]*)(\d{1,9}[.)])([ \t]+)(?=\S)');

// Inline emphasis, longest delimiter first so `***x***` is not
// mis-tokenised as `**` + `*`.
//
//   group 1: ***bold italic***
//   group 2: **bold**
//   group 3: *italic*
//   group 4: _italic_
//
// `(?![\s*])` on an opener and `(?<![\s*])` on a closer are the
// flanking rules. `[^*\n]` / `[^_\n]` keep emphasis inside one line and
// stop a run of delimiters (`****`, `___`) from pairing with itself.
final RegExp _kInlineEmphasis = RegExp(
  r'\*\*\*(?![\s*])([^*\n]+?)(?<![\s*])\*\*\*'
  r'|\*\*(?![\s*])([^*\n]+?)(?<![\s*])\*\*'
  r'|\*(?![\s*])([^*\n]+?)(?<![\s*])\*'
  r'|(?<![\w_])_(?!\s)([^_\n]+?)(?<!\s)_(?![\w_])',
);

/// Whether [line] is a list item under this subset — bullet or ordered.
/// Exposed for the editor's list toggle, which needs to know whether to
/// add a marker or strip one.
bool isNoteListLine(String line) =>
    _kBulletLine.hasMatch(line) || _kOrderedLine.hasMatch(line);

/// Parse [text] into a complete tiling of [NoteMarkdownRun]s.
///
/// Never throws and never drops a character: for text containing no
/// formatting this returns a single plain run covering the whole input.
List<NoteMarkdownRun> scanNoteMarkdown(String text) {
  if (text.isEmpty) return const [];

  // ── Pass 1: line-leading list markers. ────────────────────────────
  // Done first so a `* item` bullet can never be confused with an
  // unterminated `*italic` opener, and so pass 2 can skip the region.
  final markers = <NoteMarkdownRun>[];
  var lineStart = 0;
  while (lineStart <= text.length) {
    var lineEnd = text.indexOf('\n', lineStart);
    if (lineEnd < 0) lineEnd = text.length;
    final line = text.substring(lineStart, lineEnd);
    final bullet = _kBulletLine.firstMatch(line);
    if (bullet != null) {
      // Cover the marker character and the spaces after it; the
      // indent (group 1) stays as the user typed it.
      final indent = bullet.group(1)!.length;
      markers.add(NoteMarkdownRun(
        start: lineStart + indent,
        end: lineStart + bullet.end,
        isMarker: true,
        renderAs: '• ',
      ));
    }
    if (lineEnd >= text.length) break;
    lineStart = lineEnd + 1;
  }

  bool overlapsMarker(int start, int end) {
    for (final m in markers) {
      if (start < m.end && m.start < end) return true;
    }
    return false;
  }

  // ── Pass 2: inline emphasis. ──────────────────────────────────────
  final pieces = <NoteMarkdownRun>[...markers];
  for (final m in _kInlineEmphasis.allMatches(text)) {
    if (overlapsMarker(m.start, m.end)) continue;

    final int delimLength;
    final bool bold;
    final bool italic;
    if (m.group(1) != null) {
      delimLength = 3;
      bold = true;
      italic = true;
    } else if (m.group(2) != null) {
      delimLength = 2;
      bold = true;
      italic = false;
    } else {
      delimLength = 1;
      bold = false;
      italic = true;
    }

    final contentStart = m.start + delimLength;
    final contentEnd = m.end - delimLength;
    pieces
      ..add(NoteMarkdownRun(
        start: m.start,
        end: contentStart,
        bold: bold,
        italic: italic,
        isMarker: true,
      ))
      ..add(NoteMarkdownRun(
        start: contentStart,
        end: contentEnd,
        bold: bold,
        italic: italic,
      ))
      ..add(NoteMarkdownRun(
        start: contentEnd,
        end: m.end,
        bold: bold,
        italic: italic,
        isMarker: true,
      ));
  }

  if (pieces.isEmpty) {
    return [NoteMarkdownRun(start: 0, end: text.length)];
  }

  // ── Tile the gaps with plain runs. ────────────────────────────────
  pieces.sort((a, b) => a.start.compareTo(b.start));
  final out = <NoteMarkdownRun>[];
  var cursor = 0;
  for (final p in pieces) {
    if (p.start > cursor) {
      out.add(NoteMarkdownRun(start: cursor, end: p.start));
    }
    out.add(p);
    cursor = p.end;
  }
  if (cursor < text.length) {
    out.add(NoteMarkdownRun(start: cursor, end: text.length));
  }
  return out;
}

/// The style [run] should be drawn in, given the caller's [base].
///
/// Emphasis is applied as an override rather than a toggle: a note
/// whose base style is already italic still shows `*italic*` as
/// italic, so the reader never has to guess which convention is in
/// force. (The Library note tile's blanket italic was dropped for
/// exactly this reason when formatting shipped.)
TextStyle styleForNoteRun(
  NoteMarkdownRun run,
  TextStyle base,
  NoteMarkdownMode mode,
) {
  var style = base;
  if (run.bold) style = style.copyWith(fontWeight: FontWeight.w700);
  if (run.italic) style = style.copyWith(fontStyle: FontStyle.italic);
  if (run.isMarker && mode == NoteMarkdownMode.source) {
    // Source mode has to draw the delimiters — dimmed, so the user can
    // see and edit them without them competing with their own words.
    // Render mode never gets here: it drops delimiters entirely, and a
    // list bullet's replacement glyph is meant to be fully visible.
    final color = style.color;
    if (color != null) {
      style = style.copyWith(color: color.withValues(alpha: 0.38));
    }
  }
  return style;
}

// ── Editor actions ───────────────────────────────────────────────────
//
// Users should not have to know Markdown to get bold text; the editor
// carries a three-button strip and these are the pure functions behind
// it. Kept here, away from the widget, so the wrapping/unwrapping rules
// are unit-testable — see `test/note_formatting_editor_test.dart`.

/// What the note editor's formatting strip can do.
enum NoteFormatAction { bold, italic, bulletList }

/// The text a formatting action produces and where the selection lands.
@immutable
class NoteFormatEdit {
  final String text;
  final TextSelection selection;
  const NoteFormatEdit({required this.text, required this.selection});
}

/// Apply [action] to [selection] within [text], toggling: a selection
/// already wrapped in the delimiter is unwrapped, and a line already
/// bulleted loses its bullet.
///
/// With an empty selection, bold/italic insert the delimiter pair and
/// place the caret between them, so tapping **B** and typing works the
/// way it does in every other editor.
NoteFormatEdit applyNoteFormat(
  String text,
  TextSelection selection,
  NoteFormatAction action,
) {
  // A selection the field never established (offset -1) means "no
  // cursor"; append at the end rather than throwing on a bad range.
  final start = selection.start < 0 ? text.length : selection.start;
  final end = selection.end < 0 ? text.length : selection.end;
  final lo = start < end ? start : end;
  final hi = start < end ? end : start;

  if (action == NoteFormatAction.bulletList) {
    return _toggleBullets(text, lo, hi);
  }

  final delim = action == NoteFormatAction.bold ? '**' : '*';
  final selected = text.substring(lo, hi);

  // Already wrapped, inside the selection? Unwrap.
  if (selected.length > delim.length * 2 &&
      selected.startsWith(delim) &&
      selected.endsWith(delim)) {
    final inner = selected.substring(delim.length, selected.length - delim.length);
    return NoteFormatEdit(
      text: text.replaceRange(lo, hi, inner),
      selection: TextSelection(baseOffset: lo, extentOffset: lo + inner.length),
    );
  }

  // Already wrapped, just outside the selection? Unwrap that instead,
  // so selecting the word inside `**word**` and tapping B un-bolds it.
  final before = lo - delim.length;
  if (before >= 0 &&
      hi + delim.length <= text.length &&
      text.substring(before, lo) == delim &&
      text.substring(hi, hi + delim.length) == delim) {
    final stripped =
        text.replaceRange(hi, hi + delim.length, '').replaceRange(before, lo, '');
    return NoteFormatEdit(
      text: stripped,
      selection: TextSelection(
          baseOffset: before, extentOffset: before + selected.length),
    );
  }

  final wrapped = '$delim$selected$delim';
  return NoteFormatEdit(
    text: text.replaceRange(lo, hi, wrapped),
    selection: selected.isEmpty
        // Caret between the delimiters, ready to type.
        ? TextSelection.collapsed(offset: lo + delim.length)
        : TextSelection(
            baseOffset: lo + delim.length,
            extentOffset: lo + delim.length + selected.length),
  );
}

/// Add `- ` to every line the selection touches, or strip it from all
/// of them when every touched line already has a list marker.
NoteFormatEdit _toggleBullets(String text, int lo, int hi) {
  // Widen to whole lines — a bullet belongs to a line, not a word.
  var blockStart = text.lastIndexOf('\n', lo > 0 ? lo - 1 : 0);
  blockStart = blockStart < 0 ? 0 : blockStart + 1;
  if (lo == 0) blockStart = 0;
  var blockEnd = text.indexOf('\n', hi);
  if (blockEnd < 0) blockEnd = text.length;

  final lines = text.substring(blockStart, blockEnd).split('\n');
  final allListed = lines.every((l) => l.trim().isEmpty || isNoteListLine(l));

  final rewritten = lines.map((l) {
    if (l.trim().isEmpty) return l;
    if (allListed) {
      final bullet = _kBulletLine.firstMatch(l);
      if (bullet != null) {
        return l.substring(0, bullet.group(1)!.length) + l.substring(bullet.end);
      }
      final ordered = _kOrderedLine.firstMatch(l);
      if (ordered != null) {
        return l.substring(0, ordered.group(1)!.length) +
            l.substring(ordered.end);
      }
      return l;
    }
    if (isNoteListLine(l)) return l;
    // Preserve the line's own indent, insert the marker after it.
    final indent = RegExp(r'^[ \t]*').firstMatch(l)!.end;
    return '${l.substring(0, indent)}- ${l.substring(indent)}';
  }).toList();

  final block = rewritten.join('\n');
  return NoteFormatEdit(
    text: text.replaceRange(blockStart, blockEnd, block),
    selection: TextSelection(
      baseOffset: blockStart,
      extentOffset: blockStart + block.length,
    ),
  );
}
