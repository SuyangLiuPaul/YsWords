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
  ///
  /// 2026-05-24 (v1.3.33): when a Chinese gloss is just a grammar
  /// prefix (e.g. `glossZh = "接所有格:"` for G1537 ἐκ), it's
  /// useless on its own — the actual translation lives in `defZh`.
  /// In that case we synthesise a richer gloss by extracting the
  /// first translation phrase from `defZh`. Detected via the
  /// gloss ending in `:` or `：`, OR being very short (≤4 chars)
  /// and ending in a particle that indicates "see below".
  String localizedGloss(String locale) {
    String? raw;
    String? rawDef;
    if (locale == 'zh-Hant') {
      if ((glossZhTw ?? '').isNotEmpty) raw = glossZhTw;
      if ((definitionZhTw ?? '').isNotEmpty) rawDef = definitionZhTw;
      raw ??= (glossZh?.isNotEmpty ?? false) ? glossZh : null;
      rawDef ??= (definitionZh?.isNotEmpty ?? false) ? definitionZh : null;
    } else if (locale.startsWith('zh')) {
      if ((glossZh ?? '').isNotEmpty) raw = glossZh;
      if ((definitionZh ?? '').isNotEmpty) rawDef = definitionZh;
    }
    raw ??= gloss;
    if (raw.isNotEmpty && _isStubGloss(raw) && rawDef != null) {
      final extracted = _extractFirstPhrase(rawDef);
      if (extracted.isNotEmpty) {
        // Combine the grammar prefix + extracted translation so the
        // user sees both "接所有格: 从...出来, 出于" rather than
        // just the bare prefix.
        return raw.endsWith(':') || raw.endsWith('：')
            ? '$raw $extracted'
            : '$raw — $extracted';
      }
    }
    return raw;
  }

  /// Detects a `glossZh` that's just a grammar prefix or punctuation
  /// — the real translation lives in `defZh`.
  static bool _isStubGloss(String g) {
    final t = g.trim();
    if (t.isEmpty) return true;
    if (t.endsWith(':') || t.endsWith('：')) return true;
    // Pure punctuation / numbers only.
    if (RegExp(r'^[\s\d.,;:：，。;()()\[\]【】]+$').hasMatch(t)) return true;
    return false;
  }

  /// Pull the first meaningful translation phrase out of a `defZh`
  /// body. CBOL Chinese definitions follow several shapes:
  ///
  /// Shape A (most common — numbered list):
  ///   `1) [translation], [translation]...\n2) ...\n同义词 见 N`
  ///
  /// Shape B (no list, header metadata first):
  ///   `[strongs-id] [translit] {pron}\n\n源自 [ref]; 形容词\n\n
  ///    AV - [english-occurrences]\n\n[chinese-translation]`
  ///
  /// We try Shape A first (look for `1)`), and fall back to Shape B
  /// by skipping any line that's pure metadata: transliteration with
  /// `{...}` braces, lines starting with `源自/AV/TDNT/TWOT/钦定本/BDB`,
  /// lines that are mostly ASCII (English gloss / etymology).
  /// Clamp at ~36 chars to keep the gloss card-sized.
  static String _extractFirstPhrase(String def) {
    final raw = def.trim();
    if (raw.isEmpty) return '';
    // Try Shape A: find the first `1)` or `1.` list marker and
    // extract its clause.
    final m = RegExp(r'^[\s\(（]?1[\.\)）][\s]?(.+?)(?=\n[\s\(（]?2[\.\)）]|\n#|同义词|同義詞|$)',
        multiLine: false, dotAll: true).firstMatch(raw);
    String? body;
    if (m != null) {
      body = m.group(1)?.trim();
    } else {
      // Look for a `1)` anywhere in the text (sometimes it's after
      // metadata blocks separated by blank lines).
      final idx = raw.indexOf(RegExp(r'(^|\n)[\s\(（]?1[\.\)）]'));
      if (idx >= 0) {
        var tail = raw.substring(idx);
        tail = tail.replaceFirst(RegExp(r'^[\s\n]*[\s\(（]?1[\.\)）][\s]?'), '');
        final cut = [
          tail.indexOf(RegExp(r'\n[\s\(（]?2[\.\)）]')),
          tail.indexOf('同义词'),
          tail.indexOf('同義詞'),
          tail.indexOf('\n#'),
        ].where((i) => i > 0).fold<int>(tail.length, (a, b) => a < b ? a : b);
        body = tail.substring(0, cut).trim();
      }
    }
    // Shape B fallback: pick the first line that's mostly CJK +
    // not a metadata header.
    if (body == null || body.isEmpty) {
      for (final line in raw.split('\n')) {
        final t = line.trim();
        if (t.isEmpty) continue;
        if (RegExp(r'^[\s\d]+[a-zA-Z]').hasMatch(t)) continue; // ID + translit
        if (RegExp(r'^(源自|AV|TDNT|TWOT|钦定本|欽定本|BDB|形容词|形容詞|名词|名詞|动词|動詞|副词|副詞|代词|代詞|介词|介詞|虚词|虛詞|连词|連詞|数词|數詞|冠词|冠詞|专有名词|專有名詞|字根型|阴性名词|陰性名詞|阳性名词|陽性名詞)').hasMatch(t)) continue;
        // Skip lines with `{...}` (pronunciation/transliteration).
        if (t.contains('{') && t.contains('}')) continue;
        // CJK ratio: only accept lines where >40% chars are CJK.
        final cjkCount = t.runes
            .where((r) => (r >= 0x3400 && r <= 0x9FFF) ||
                (r >= 0x20000 && r <= 0x2FA1F))
            .length;
        if (cjkCount * 100 < t.runes.length * 40) continue;
        body = t;
        break;
      }
    }
    if (body == null || body.isEmpty) return '';
    // Drop trailing reference markers like "(#约 10:39|)".
    body = body.replaceAll(RegExp(r'\s*\(#[^)]*\)'), '').trim();
    // Drop trailing ASCII tails (CBOL sometimes appends English).
    body = body.replaceFirst(RegExp(r'\s*[A-Za-z;,.\s]+$'), '').trim();
    // Collapse whitespace.
    body = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (body.length > 36) body = '${body.substring(0, 36)}…';
    return body;
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

  /// 2026-05-07: detect proper nouns (names of people, places, deities,
  /// nations) so the UI can render BOTH the English and Chinese
  /// glosses side-by-side instead of just the locale-preferred one.
  ///
  /// **Why we need both for proper nouns**: the two lexicon sources
  /// emphasize different aspects:
  ///   • English Strong's (1890s, public domain) → **etymology**
  ///     ("Sceva" → Latin scaevus → "left-handed")
  ///   • CBOL Chinese (modern) → **biblical identification**
  ///     ("Sceva" → "一个祭司长，住在以弗所")
  /// Both are factually correct, but a user seeing only one feels
  /// like the data contradicts itself ("why does English say
  /// 'left-handed' but Chinese says 'high priest'?"). Showing both
  /// with clear labels turns the apparent contradiction into a
  /// useful "etymology + role" view.
  ///
  /// Heuristic uses the [definition] string — if it contains
  /// proper-noun markers like "of Hebrew origin", ", an Israelite",
  /// "an apostle", or "a city / town / region / mountain / river",
  /// we treat it as a proper noun. Audited across the bundled
  /// lexicon (Greek 5,523 + Hebrew 8,674): ~1,943 entries flagged
  /// (~14%), of which ~158 actually have noticeably different
  /// English vs Chinese glosses.
  bool get isProperNoun {
    final d = definition.toLowerCase();
    if (d.isEmpty) return false;
    const markers = <String>[
      'of hebrew origin',
      'of greek origin',
      'of latin origin',
      'of egyptian origin',
      'of aramaic origin',
      'of persian origin',
      'of phoenician origin',
      'of babylonian origin',
      'of foreign origin',
      'of uncertain (foreign) derivation',
      ', an israelite',
      ', a hebrew',
      ', an israelitish',
      ', a jew',
      ', a jewess',
      ', a jewish',
      ', an apostle',
      ', a christian',
      ', a disciple',
      ', a prophet',
      ', a prophetess',
      ', a king',
      ', a queen',
      ', a priest',
      ', a high priest',
      ' the son of',
      ' the daughter of',
      'a city ',
      'a town ',
      'a region ',
      'a place ',
      'a mountain ',
      'a river ',
      'a country ',
      'an island ',
      'a sea ',
      'a god',
      'a goddess',
      'an idol',
    ];
    for (final m in markers) {
      if (d.contains(m)) return true;
    }
    return false;
  }

  /// Returns the cross-locale gloss most useful when this entry is a
  /// proper noun. For [locale] = 'en', returns the Chinese gloss
  /// (`glossZh`) which typically carries the biblical identification;
  /// for any zh locale, returns the English gloss which carries the
  /// etymology. Empty string when no complementary gloss exists.
  /// Callers render this with a clear label like "(此处指 / role)" or
  /// "(etymology / 词源)".
  String complementaryGloss(String locale) {
    if (locale.startsWith('zh')) {
      // User reading in Chinese; complementary view is the English
      // etymology that they'd otherwise miss.
      return gloss;
    }
    // User reading in English; complementary view is the Chinese
    // biblical identification.
    if (locale == 'zh-Hant') {
      if ((glossZhTw ?? '').isNotEmpty) return glossZhTw!;
    }
    return glossZh ?? '';
  }

  /// 2026-05-07 follow-up: same idea as [complementaryGloss] but for
  /// the longer DEFINITION text. The user noticed that even with the
  /// gloss section showing both perspectives, the definition body
  /// below still showed only the locale-preferred version, so e.g.
  /// English readers saw the etymology paragraph and Chinese readers
  /// saw the contextual paragraph — looking inconsistent. Returning
  /// the cross-locale definition here lets the UI render BOTH bodies
  /// for proper nouns.
  String complementaryDefinition(String locale) {
    if (locale.startsWith('zh')) {
      return definition;
    }
    if (locale == 'zh-Hant') {
      if ((definitionZhTw ?? '').isNotEmpty) return definitionZhTw!;
    }
    return definitionZh ?? '';
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
