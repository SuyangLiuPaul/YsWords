/// The inline Strong's numbers a tagged line prints after each word.
///
/// Ported from SeekSparks on 2026-09-08, trimmed to the two rules the
/// Exegesis sheet needs. It is here because of the second half of what
/// the owner asked for that day — 「words要看选择可以看到的**有数字的**」,
/// the reader should be able to SEE the numbered line — and because
/// this app could not print one. `originals_sheet.dart` has rendered a
/// tagged running line since it was ported, with a dotted underline
/// under every tappable word and **no numbers anywhere in it** — the
/// numbers appeared only on the original-language chips BELOW the line,
/// never in it. The form 精读圣经 prints, and the one in the screenshot
/// he sent, is
///
///     地<0776>是<01961>空虚<08414>混沌<0922>，渊<08415>面<06440>黑暗<02822>；
///
/// Three distinct things share that position, and telling them apart is
/// the whole reason such a line stays readable:
///
///   * the word's own lexical number      — the accent colour
///   * grammar / TVM parsing codes        — dimmer
///   * numbers the original has that this
///     translation does not render        — parenthesised
///
/// Pure functions, in `utils/` rather than inside the widget, because
/// both rules below are the kind of thing that should be pinned by a
/// test rather than read off a screenshot.
library;

import 'package:flutter/foundation.dart';

enum StrongsNumberKind {
  /// The number for the word actually on screen.
  lexical,

  /// Hebrew stem/aspect, Greek tense-voice-mood.
  grammar,

  /// Present in the original, unrendered in the translation — the
  /// Hebrew object marker אֵת, the Greek article.
  implied,
}

@immutable
class StrongsNumberToken {
  const StrongsNumberToken(this.text, this.kind);

  /// Exactly as it should be printed, parentheses included.
  final String text;
  final StrongsNumberKind kind;

  @override
  bool operator ==(Object other) =>
      other is StrongsNumberToken && other.text == text && other.kind == kind;

  @override
  int get hashCode => Object.hash(text, kind);

  @override
  String toString() => '$text(${kind.name})';
}

/// The numbers to print after one tagged word, in print order.
///
/// Implied numbers come FIRST. That looks backwards until you check the
/// source: `天<WH853x><WH8064>` and `以撒<WG3588x><WG2464>` both put the
/// unrendered word ahead of the one on screen, because that is the order
/// the Hebrew and the Greek are in — אֵת before שָׁמַיִם, τόν before Ἰσαάκ.
/// Printing them in that order keeps the line aligned with the original
/// rather than with our own parse of it.
List<StrongsNumberToken> inlineStrongsNumbers({
  required String strongs,
  List<String> grammar = const [],
  List<String> implied = const [],
}) =>
    [
      for (final i in implied)
        if (i.isNotEmpty) StrongsNumberToken('($i)', StrongsNumberKind.implied),
      if (strongs.isNotEmpty)
        StrongsNumberToken(strongs, StrongsNumberKind.lexical),
      for (final g in grammar)
        if (g.isNotEmpty) StrongsNumberToken(g, StrongsNumberKind.grammar),
    ];

/// The Chinese closing/separator marks split off a tagged run's trailing
/// edge — comma, full stop, semicolon, colon, exclamation, question,
/// dùn hào, and the bracket/quote closers this corpus actually uses.
/// Deliberately the CJK "cannot start a line" set: every mark Chinese
/// typesetting hangs at a line's end and nothing that opens, so nothing
/// legitimately CJK-and-trailing is left un-split and nothing that could
/// open a clause is mistaken for a closer.
const _kCjkTrailingPunctuation = '，。；：！？、）〕」』】》〉';

/// Splits a tagged run's word text into (stem, trailing punctuation).
///
/// `cuvs-yhwh`'s source format bakes trailing punctuation straight into
/// the tagged word — `{"w":"起初，","s":"H7225"}` for Genesis 1:1 —
/// because that is how the upstream module stores it, and it is not a
/// one-off: 93,722 of 367,649 runs, 25.5%. H7225 tags רֵאשִׁית,
/// "beginning"; the CUV's own comma has no Hebrew behind it. Printing
/// the run as-is puts the number after punctuation the number is not
/// FOR — 起初，H7225 reads as though H7225 tagged the comma. This is the
/// split; the caller puts the numbers between the two halves, so the
/// line reads 起初H7225， instead.
///
/// Only the MAXIMAL TRAILING run is taken. Leading or mid-run
/// punctuation — a separator opening the next item, a 〔note〕 folded
/// into the same run — is untouched, because it is not trailing this
/// word's own content and splitting it would misattribute it.
///
/// English tagged editions carry the identical baked-in convention
/// (25,606 BSB runs end in ASCII `,.;:!?`) and are deliberately left
/// alone: a citation mark after a comma is ordinary English
/// typesetting, so "correct by the same logic as Chinese" is not "wrong
/// the same way".
(String stem, String trailing) splitTrailingCjkPunctuation(String word) {
  var i = word.length;
  while (i > 0 && _kCjkTrailingPunctuation.contains(word[i - 1])) {
    i--;
  }
  return (word.substring(0, i), word.substring(i));
}
