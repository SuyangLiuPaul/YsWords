/// What a `[bracketed]` span inside scripture text actually is.
///
/// Ported from SeekSparks, trimmed to the part YsWords needs: telling
/// an editorial *referent gloss* apart from a *supplied word*.
///
/// The distinction is load-bearing for Strong's tagging. `主[雅伟]`
/// brackets a name the editors put beside 主 to say who is meant — the
/// bracket names the word printed in FRONT of it and renders no Greek
/// or Hebrew word of its own. A supplied word like the BSB's inserted
/// `[is]` is different: it stands for nothing in the original either,
/// but it is ordinary inserted prose, not a pointer at its neighbour.
///
/// Anything outside the two closed sets is treated as supplied, which
/// is the right default — bracketed insertions vastly outnumber
/// glosses, and mis-classifying one as a gloss would move a Strong's
/// number onto the wrong word.
library;

enum ScriptureSpanKind {
  /// A word the translators added; stands for nothing in the original.
  supplied,

  /// The divine name, restored beside the word it renders.
  divineName,

  /// Another editorial referent — 基督, Messiah.
  gloss,
}

/// Divine-name tokens, in every form the bundled assets use.
///
/// `耶和华`/`耶和華` are included because a bracket carrying them makes
/// the same claim in a non-restored edition, even though no asset
/// shipped here currently writes one.
const Set<String> _divineNameTokens = {
  '雅伟',
  '雅偉',
  '雅威',
  'Yahweh',
  'YHWH',
  'YHVH',
  '耶和华',
  '耶和華',
};

/// Referent glosses that are not the divine name.
///
/// 耶稣/耶穌 joined this set on 2026-09-02, with the restoration of the
/// edition's third marker. 和合本雅偉版 marks the referent of 主 three
/// ways — `主[雅偉]` Yahweh, `主#` 基督, `主*` 耶穌 — and only the first
/// two had ever reached a reader: the asterisk was deleted twice as
/// importer noise. Without 耶穌 here the 123 restored brackets classify
/// as `supplied`, i.e. as words the translators added, which is the
/// opposite of what they are — the bracket names the 主 in front of it.
const Set<String> _referentTokens = {
  '基督',
  'Christ',
  'Messiah',
  '弥赛亚',
  '彌賽亞',
  '耶稣',
  '耶穌',
  'Jesus',
};

ScriptureSpanKind bracketSpanKind(String body) {
  final b = body.trim();
  if (_divineNameTokens.contains(b)) return ScriptureSpanKind.divineName;
  if (_referentTokens.contains(b)) return ScriptureSpanKind.gloss;
  return ScriptureSpanKind.supplied;
}

/// Whether a bracketed body is an editorial referent gloss rather than
/// a supplied word.
bool isReferentGloss(String body) =>
    bracketSpanKind(body) != ScriptureSpanKind.supplied;
