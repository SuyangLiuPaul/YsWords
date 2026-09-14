import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

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
/// The label sits at the END of the truncated text, in the same
/// paragraph, not on a row of its own — 「close和expand连在一起」. That
/// is the part the owner singled out, and it is why this is a
/// `Text.rich` with a `TapGestureRecognizer` rather than a Column with a
/// chevron.
///
/// Folded by default. An expander that starts open saves nobody
/// anything.
class VerseNotesBlock extends StatefulWidget {
  const VerseNotesBlock({
    super.key,
    required this.notes,
    required this.settings,
    required this.locale,
    this.preview = kNotePreviewChars,
  });

  /// In reading order: the `<note: …>` markers as they appear in the
  /// verse, then the edition's block-level apparatus.
  final List<String> notes;
  final AppSettings settings;
  final String locale;

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

const String _nbsp = ' ';
const List<String> _superscripts = [
  '⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹',
];

/// `12` → `¹²`. Shared with the inline markers so a superscript in the
/// verse and a superscript in the block are the same glyphs.
String superscriptNumber(int n) {
  final b = StringBuffer();
  for (final code in n.toString().codeUnits) {
    b.write(_superscripts[code - 0x30]);
  }
  return b.toString();
}

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

    final buf = StringBuffer();
    for (var i = 0; i < widget.notes.length; i++) {
      if (i > 0) buf.write('\n');
      buf
        ..write(superscriptNumber(i + 1))
        ..write(_nbsp)
        ..write(widget.notes[i].trim());
    }
    final all = buf.toString();

    final style = TextStyle(
      fontSize: fs * 0.85,
      height: widget.settings.lineSpacing,
      fontFamily: widget.settings.fontFamily,
      fontFamilyFallback: kCjkFontFallback,
      color: scheme.onSurfaceVariant,
    );
    final folds = widget.preview > 0 && all.length > widget.preview;
    final label = _expanded
        ? (uiStrings['notesShowLess']?[widget.locale] ?? 'Show fewer notes')
        : (uiStrings['notesShowAll']?[widget.locale] ?? 'Show all notes');

    final spans = <InlineSpan>[
      TextSpan(
        text: folds && !_expanded
            ? '${all.substring(0, widget.preview)}… '
            : all,
        style: style,
      ),
      if (folds)
        TextSpan(
          text: _expanded ? '  $label' : label,
          style: style.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: scheme.primary,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => setState(() => _expanded = !_expanded),
        ),
    ];

    return Padding(
      padding: EdgeInsets.only(top: fs * 0.3, bottom: fs * 0.15),
      child: Text.rich(TextSpan(children: spans)),
    );
  }
}
