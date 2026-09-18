import 'package:flutter/material.dart';

import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/utils/font_catalog.dart' show kCjkFontFallback;

/// Every note a verse carries, set as one numbered block under it.
///
/// 2026-09-14, adopted from the 雅偉的話 app on the owner's instruction:
/// 「yahwehdehua app apk的 close和expand连在一起的其实设计得非常合理 …
/// 要用adopt yahwehdehua这个设计 … apply在这两个app三个界面上」.
///
/// WHAT IT REPLACES, AND WHY EACH PART OF IT IS THE WAY IT IS. This app
/// used to draw a book icon at each note's position and open that one
/// note as a boxed card in the middle of the sentence. Three complaints,
/// and the new shape answers each one:
///
///   * 「根本看不清」 — the notes had no structure. 梁家鏗's 羅馬書 8:26
///     carries several, and run together they are a wall with nothing to
///     say where one ends. **Numbered, one per line**: the numbers are
///     the only structure the notes come with, so they are the structure
///     used. A superscript in the verse points at the line below.
///   * 「para mode不好按」 — the tap target was a glyph a few pixels
///     wide, mid-prose. **There is nothing to tap to read a note now**:
///     the notes are already on screen, and the only control is the
///     underlined label, which is words wide.
///   * 「words你就截开几段用起来很难受」 — opening a note in place split
///     the verse into pieces. **The block sits after the verse**, so the
///     scripture is never cut.
///
/// 2026-09-14, second pass, from the 雅偉的話 WEB reader rather than its
/// app — 「这种可以打开在words sword reader parallel mode 三个页面apply
/// 就很好」, with the control circled. The first pass truncated the notes
/// at 160 characters and put an underlined link at the seam; this one is
/// what that site actually does, and it is better in two ways:
///
///   * The control is a **pill** — 「譯者註 ▾」 — outlined when shut and
///     filled when open. It is a button-shaped thing with a border, not
///     a run of underlined words, so on a phone it reads as pressable
///     before you press it.
///   * Opening shows **all** of the notes. A half-note ending in `…` is
///     not something anyone wanted to read; the reader either wants the
///     apparatus or does not.
///
/// Its CSS (`.fnote-fold > summary`, `css/bible.css`) is a `<details>`
/// with `border-radius: 999px` and a `::after` of ▾ / ▴, and that is
/// what this reproduces.
///
/// A SHORT block is not folded at all, which is that site's rule too:
/// it wraps only the notes that are longer than the verse they hang off.
/// Putting 參4.6、16 behind a button would make the reader work for six
/// characters.
class VerseNotesBlock extends StatefulWidget {
  const VerseNotesBlock({
    super.key,
    required this.notes,
    required this.settings,
    required this.locale,
    this.textInsets = EdgeInsets.zero,
    this.preview = kNotePreviewChars,
  });

  /// In reading order: the `<note: …>` markers as they appear in the
  /// verse, then the edition's block-level apparatus.
  final List<String> notes;
  final AppSettings settings;
  final String locale;

  /// The margins of the VERSE TEXT this apparatus hangs under.
  ///
  /// 2026-09-16 「我在words上看这个标记是不是要有些indentation呢」, of
  /// 哥林多后书 5's 「① "凭据"：原文是"质"」 — the note's marker sat
  /// LEFT of the verse it belongs to. The block had an inset of its own
  /// (0.6 em, added when it used to run edge to edge: 「一方面在两侧很难
  /// 看」) but that inset was measured from the page, not from the text,
  /// and the reader's paragraph starts further in than 0.6 em. So the
  /// one thing on the page that is subordinate to the verse was the one
  /// thing standing outside its margin.
  ///
  /// Passed in rather than recomputed here: the two callers — paragraph
  /// mode and verse-by-verse mode — already hold their own indent, and
  /// a second copy of that arithmetic would drift from theirs.
  final EdgeInsets textInsets;

  /// Characters of the block to show before folding the rest. 0 never
  /// folds.
  final int preview;

  @override
  State<VerseNotesBlock> createState() => _VerseNotesBlockState();
}

/// 160, which is the 雅偉的話 app's own figure. Long enough that a
/// one-line note is never folded and the reader sees it whole; short
/// enough that 梁家鏗's 約翰福音 1:1 — twenty-six notes, some thousands
/// of characters — does not bury the chapter.
const int kNotePreviewChars = 160;

/// A pill, i.e. a radius larger than the box can ever be tall.
const double _kPillRadius = 999.0;

const String _nbsp = ' ';
const List<String> _superscripts = [
  '⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹',
];

/// `3` → `③`. The note marker, in the verse and in the block.
///
/// 2026-09-15: 「这个看起来很confuse 你可能右上角 圈圈数字」. A bare
/// superscript was the wrong glyph for this, and the photograph showed
/// exactly why: the verse numbers in this reader are ALSO small raised
/// numbers, so `…蒙召的人。⁴⁵⁶⁷⁸ ²⁹因為神…` is two different numbering
/// systems in one run of characters with nothing to tell them apart. A
/// reader cannot see where the notes end and verse 29 begins.
///
/// Circled digits are one codepoint each (U+2460 ①, U+3251 ㉑, U+32B1
/// ㊱) and reach 50, which covers 梁家鏗's worst verse — 約翰福音 1:1
/// carries twenty-six. Past 50 it falls back to the superscript, which
/// no edition in either app reaches.
String superscriptNumber(int n) {
  if (n >= 1 && n <= 20) return String.fromCharCode(0x2460 + n - 1);
  if (n >= 21 && n <= 35) return String.fromCharCode(0x3251 + n - 21);
  if (n >= 36 && n <= 50) return String.fromCharCode(0x32B1 + n - 36);
  final b = StringBuffer();
  for (final code in n.toString().codeUnits) {
    b.write(_superscripts[code - 0x30]);
  }
  return b.toString();
}

/// Whether [text] is entirely note-marker glyphs — used to spot a run of
/// markers that should collapse into a range.
bool isNoteMarkerText(String text) =>
    text.isNotEmpty &&
    text.runes.every((r) =>
        (r >= 0x2460 && r <= 0x2473) ||
        (r >= 0x3251 && r <= 0x325F) ||
        (r >= 0x32B1 && r <= 0x32BF) ||
        '⁰¹²³⁴⁵⁶⁷⁸⁹⁻\u2060'.runes.contains(r));

class _VerseNotesBlockState extends State<VerseNotesBlock> {
  bool _expanded = false;

  @override
  void didUpdateWidget(VerseNotesBlock old) {
    super.didUpdateWidget(old);
    // A different verse in the same slot folds again; the same verse
    // redrawn — a font-size change, a selection — keeps what the reader
    // opened.
    if (old.notes.length != widget.notes.length ||
        (old.notes.isNotEmpty &&
            widget.notes.isNotEmpty &&
            old.notes.first != widget.notes.first)) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notes.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final fs = widget.settings.fontSize;

    // One ROW per note: the number hangs in its own column and the
    // note's continuation lines align under its first character rather
    // than under the number.
    //
    // 2026-09-14: 「yahwehdehua是 1234很好段但是都在那个注释里面」 —
    // the numbers belong to the block and read as its structure, which
    // they only do when they line up. Running the whole thing through
    // one `Text` put every wrapped line hard against the margin and the
    // numbering stopped being visible as numbering.
    final style = TextStyle(
      fontSize: fs * 0.85,
      height: widget.settings.lineSpacing,
      fontFamily: widget.settings.fontFamily,
      fontFamilyFallback: kCjkFontFallback,
      color: scheme.onSurfaceVariant,
    );
    final all = [
      for (var i = 0; i < widget.notes.length; i++)
        '${superscriptNumber(i + 1)}$_nbsp${widget.notes[i].trim()}',
    ].join('\n');
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.notes.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: fs * 0.12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: fs * 1.1,
                  child: Text(
                    superscriptNumber(i + 1),
                    style: style.copyWith(color: scheme.primary),
                  ),
                ),
                Expanded(child: Text(widget.notes[i].trim(), style: style)),
              ],
            ),
          ),
      ],
    );

    final folds = widget.preview > 0 && all.length > widget.preview;

    // Inset on BOTH sides, FROM THE VERSE'S OWN MARGINS.
    // 「一方面在两侧很难看」: the block used to run edge to edge while
    // the verse above it sat inside a margin, so the apparatus looked
    // like a different document rather than a note on this one. The
    // 0.6 em is what makes it read as subordinate to the verse, and it
    // only does that when it is measured from where the verse starts —
    // see [textInsets].
    final inset = EdgeInsets.fromLTRB(
      widget.textInsets.left + fs * 0.6,
      fs * 0.3,
      widget.textInsets.right + fs * 0.6,
      fs * 0.15,
    );

    if (!folds) {
      return Padding(padding: inset, child: body);
    }

    final label =
        uiStrings['notesFoldLabel']?[widget.locale] ?? "Translator's notes";
    return Padding(
      padding: inset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The pill. `InkWell` inside a `ClipRRect` of the same radius
          // so the press ripple keeps the shape rather than filling a
          // rectangle behind it.
          ClipRRect(
            borderRadius: BorderRadius.circular(_kPillRadius),
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: fs * 0.5, vertical: fs * 0.12),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.primary),
                  borderRadius: BorderRadius.circular(_kPillRadius),
                  color: _expanded ? scheme.primary : null,
                ),
                child: Text(
                  '$label ${_expanded ? '▴' : '▾'}',
                  style: TextStyle(
                    fontSize: fs * 0.8,
                    fontFamily: widget.settings.fontFamily,
                    fontFamilyFallback: kCjkFontFallback,
                    color: _expanded ? scheme.onPrimary : scheme.primary,
                  ),
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: EdgeInsets.only(top: fs * 0.25),
              child: body,
            ),
        ],
      ),
    );
  }
}
