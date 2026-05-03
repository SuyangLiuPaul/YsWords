/// A Strong's Concordance dictionary entry.
///
/// `number` is the Strong's identifier prefixed by language: "G####" for
/// Greek (NT), "H####" for Hebrew (OT). Lookups branch on this prefix so
/// the two lexicon files can be loaded independently.
///
/// English fields (`gloss`, `definition`) come from openscriptures/strongs.
/// Optional Chinese fields (`glossZh`, `definitionZh`) come from CBOL
/// (bible.fhl.net) under CC-BY-NC-SA 4.0; coverage is ~99% but a small
/// number of entries lack a Chinese match, hence the nullable type.
///
/// The CBOL data is **Simplified Chinese only** (verified across all
/// 14k+ entries). To serve `zh-Hant` users without character-script
/// inconsistency, `scripts/build_strongs_traditional.py` runs each
/// Simplified field through `opencc -c s2t.json` and stores the
/// result alongside as `glossZhTw` / `defZhTw`. Two pre-computed
/// fields per entry, no runtime conversion. See round-50 fix in
/// HANDOFF.md / commit history.
class StrongsEntry {
  final String number;
  final String lemma;
  final String translit;
  final String pronunciation;
  final String? partOfSpeech;
  final String gloss;
  final String definition;
  final String? derivation;
  /// Simplified Chinese (CBOL). Used directly for `zh-Hans`.
  final String? glossZh;
  final String? definitionZh;
  /// Traditional Chinese, OpenCC s2t conversion of [glossZh] /
  /// [definitionZh] respectively. Used for `zh-Hant`. Null when the
  /// Simplified counterpart was missing in CBOL.
  final String? glossZhTw;
  final String? definitionZhTw;

  const StrongsEntry({
    required this.number,
    required this.lemma,
    required this.translit,
    required this.pronunciation,
    this.partOfSpeech,
    required this.gloss,
    required this.definition,
    this.derivation,
    this.glossZh,
    this.definitionZh,
    this.glossZhTw,
    this.definitionZhTw,
  });

  /// Returns the gloss appropriate for [locale].
  ///
  /// - `zh-Hant` → [glossZhTw], falls back to [glossZh] then [gloss].
  /// - `zh-Hans` (or any other `zh-…` script) → [glossZh] then [gloss].
  /// - everything else → [gloss].
  String localizedGloss(String locale) {
    if (locale == 'zh-Hant') {
      if ((glossZhTw ?? '').isNotEmpty) return glossZhTw!;
      if ((glossZh ?? '').isNotEmpty) return glossZh!;
    } else if (locale.startsWith('zh')) {
      if ((glossZh ?? '').isNotEmpty) return glossZh!;
    }
    return gloss;
  }

  /// Returns the full definition appropriate for [locale], with the
  /// same fallback semantics as [localizedGloss].
  String localizedDefinition(String locale) {
    if (locale == 'zh-Hant') {
      if ((definitionZhTw ?? '').isNotEmpty) return definitionZhTw!;
      if ((definitionZh ?? '').isNotEmpty) return definitionZh!;
    } else if (locale.startsWith('zh')) {
      if ((definitionZh ?? '').isNotEmpty) return definitionZh!;
    }
    return definition;
  }

  factory StrongsEntry.fromJson(String number, Map<String, dynamic> json) {
    return StrongsEntry(
      number: number,
      lemma: (json['lemma'] ?? '') as String,
      translit: (json['translit'] ?? '') as String,
      pronunciation: (json['pron'] ?? '') as String,
      partOfSpeech: json['pos'] as String?,
      gloss: (json['gloss'] ?? '') as String,
      definition: (json['def'] ?? '') as String,
      derivation: json['deriv'] as String?,
      glossZh: json['glossZh'] as String?,
      definitionZh: json['defZh'] as String?,
      glossZhTw: json['glossZhTw'] as String?,
      definitionZhTw: json['defZhTw'] as String?,
    );
  }
}
