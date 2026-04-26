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
class StrongsEntry {
  final String number;
  final String lemma;
  final String translit;
  final String pronunciation;
  final String? partOfSpeech;
  final String gloss;
  final String definition;
  final String? derivation;
  final String? glossZh;
  final String? definitionZh;

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
  });

  /// Whether the [locale] is Chinese (simplified or traditional).
  static bool _isZh(String locale) =>
      locale.startsWith('zh');

  /// Returns the gloss appropriate for [locale]. For Chinese locales,
  /// prefers [glossZh] when present; falls back to [gloss] otherwise.
  String localizedGloss(String locale) {
    if (_isZh(locale) && (glossZh ?? '').isNotEmpty) return glossZh!;
    return gloss;
  }

  /// Returns the full definition appropriate for [locale], with the
  /// same fallback semantics as [localizedGloss].
  String localizedDefinition(String locale) {
    if (_isZh(locale) && (definitionZh ?? '').isNotEmpty) {
      return definitionZh!;
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
    );
  }
}
