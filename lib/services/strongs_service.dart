import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:yswords/models/strongs.dart';

/// Lazy loader for Strong's Greek + Hebrew lexicons. The two files are
/// loaded independently the first time a number from that language is
/// requested, so a NT-only session never pays the Hebrew load cost.
class StrongsService {
  static Map<String, StrongsEntry>? _greek;
  static Map<String, StrongsEntry>? _hebrew;
  static Future<Map<String, StrongsEntry>>? _greekLoading;
  static Future<Map<String, StrongsEntry>>? _hebrewLoading;

  // Reverse-derivation index: root Strong's# → set of entries derived from it.
  // Built lazily once per language after the lexicon is first loaded.
  static Map<String, Set<String>>? _greekReverseIdx;
  static Map<String, Set<String>>? _hebrewReverseIdx;

  static Map<String, Set<String>> _buildReverseIdx(
      Map<String, StrongsEntry> lexicon) {
    final re = RegExp(r'([GH]\d+)');
    final idx = <String, Set<String>>{};
    for (final entry in lexicon.entries) {
      for (final m in re.allMatches(entry.value.derivation ?? '')) {
        idx.putIfAbsent(m.group(1)!, () => {}).add(entry.key);
      }
    }
    return idx;
  }

  static Future<Map<String, StrongsEntry>> _load(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final entry in map.entries)
        entry.key:
            StrongsEntry.fromJson(entry.key, entry.value as Map<String, dynamic>)
    };
  }

  static Future<Map<String, StrongsEntry>> _lexiconFor(String number) async {
    await lookup(number);
    return number.startsWith('G') ? (_greek ?? {}) : (_hebrew ?? {});
  }

  static Map<String, Set<String>> _reverseIdxFor(
      String number, Map<String, StrongsEntry> lexicon) {
    if (number.startsWith('G')) {
      return _greekReverseIdx ??= _buildReverseIdx(lexicon);
    } else {
      return _hebrewReverseIdx ??= _buildReverseIdx(lexicon);
    }
  }

  /// Returns Strong's entries in the same word family as [number]:
  /// - siblings: other entries that share the same immediate root
  ///   (only when the root group has ≤ 25 children, to avoid flooding
  ///    the UI with unrelated preposition-prefixed words)
  /// - children: entries derived directly from [number]
  /// Results are sorted by Strong's number and capped at 20.
  static Future<List<StrongsEntry>> wordFamily(String number) async {
    if (number.isEmpty) return const [];
    final lexicon = await _lexiconFor(number);
    if (lexicon.isEmpty) return const [];
    final idx = _reverseIdxFor(number, lexicon);

    final self = lexicon[number];
    if (self == null) return const [];

    final derivRe = RegExp(r'([GH]\d+)');
    final selfParents = derivRe
        .allMatches(self.derivation ?? '')
        .map((m) => m.group(1)!)
        .toSet();

    final related = <String>{};
    // Siblings — only include when parent group is small enough to be meaningful.
    for (final parent in selfParents) {
      final siblings = idx[parent] ?? {};
      if (siblings.length <= 25) related.addAll(siblings);
    }
    // Children — always include regardless of group size.
    related.addAll(idx[number] ?? {});
    // Strip self and direct parents (parents already shown in derivation line).
    related
      ..remove(number)
      ..removeAll(selfParents);

    final sorted = related.toList()
      ..sort((a, b) {
        final na = int.tryParse(a.substring(1)) ?? 0;
        final nb = int.tryParse(b.substring(1)) ?? 0;
        return na.compareTo(nb);
      });
    return sorted
        .take(20)
        .map((n) => lexicon[n])
        .whereType<StrongsEntry>()
        .toList();
  }

  /// Returns Strong's entries explicitly cross-referenced in [number]'s
  /// definition as "compare G/H####" — a weak-synonym / see-also list.
  static Future<List<StrongsEntry>> compareWords(String number) async {
    if (number.isEmpty) return const [];
    final lexicon = await _lexiconFor(number);
    if (lexicon.isEmpty) return const [];

    final self = lexicon[number];
    if (self == null) return const [];

    final re = RegExp(r'compare\s+([GH]\d+)', caseSensitive: false);
    final nums =
        re.allMatches(self.definition).map((m) => m.group(1)!).toSet();
    return nums.map((n) => lexicon[n]).whereType<StrongsEntry>().toList();
  }

  static Future<StrongsEntry?> lookup(String number) async {
    if (number.isEmpty) return null;
    final isGreek = number.startsWith('G');
    final isHebrew = number.startsWith('H');
    if (!isGreek && !isHebrew) return null;
    if (isGreek) {
      _greek ??= await (_greekLoading ??=
          _load('assets/strongs/greek.json'));
      return _greek![number];
    } else {
      _hebrew ??= await (_hebrewLoading ??=
          _load('assets/strongs/hebrew.json'));
      return _hebrew![number];
    }
  }

  /// 2026-05-07: search the lexicon by lemma OR transliteration —
  /// the user types Greek/Hebrew text directly (e.g. "ἀγάπη",
  /// "אהבה") OR a romanised form (e.g. "agape", "ahavah") and we
  /// match against the entry's `lemma` and `translit` fields.
  ///
  /// Both lexicons are scanned when the input could plausibly match
  /// either (Latin-letter input). For Greek-script input we only
  /// scan the Greek lexicon; for Hebrew-script we only scan Hebrew.
  /// Diacritics and case are normalised so "Agape" matches "agápē".
  ///
  /// Returns up to [limit] best matches (exact > prefix > contains)
  /// in score order. Empty list if nothing matched. Used by the
  /// search page when the user input doesn't look like English /
  /// Chinese / a Strong's number.
  /// 2026-05-07 (v6): explicit alias table for high-frequency
  /// theological terms whose CBOL Chinese gloss is descriptive
  /// rather than a literal name. H3068 (YHWH) is the prime case:
  /// its glossZh is "独一真神的专有名词" (a description, not the
  /// name). User intent for 雅伟 / 耶和华 / Yahweh / YHWH is
  /// unambiguously H3068, so we pin it.
  static const Map<String, String> _aliasToStrongs = {
    // YHWH (Hebrew) — divine name. All common spellings collapse
    // to H3068, the canonical YHWH entry.
    // 2026-05-10 (v1.2.33): added 雅偉 as canonical traditional
    // form alongside the historical 雅威 (kept for backward
    // compatibility — users who searched 雅威 in v≤1.2.32 sessions
    // shouldn't get a "no match"). Project canonical is 雅伟 / 雅偉.
    '雅伟': 'H3068',
    '雅偉': 'H3068',
    '雅威': 'H3068',
    '耶和华': 'H3068',
    '耶和華': 'H3068',
    'yahweh': 'H3068',
    'jehovah': 'H3068',
    'yhwh': 'H3068',
    // Jesus — the entry for the proper name (G2424). Even though
    // the CBOL gloss already begins with "耶稣, ...", an explicit
    // pin guarantees the canonical entry wins regardless of
    // ranking edge-cases.
    '耶稣': 'G2424',
    '耶穌': 'G2424',
    'jesus': 'G2424',
    'iesous': 'G2424',
  };

  static Future<List<StrongsEntry>> searchByLemma(
    String query, {
    int limit = 12,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final norm = _normaliseForLemma(q);
    if (norm.isEmpty) return const [];

    // Pinned alias: explicit Chinese / English term → Strong's
    // number (e.g. 雅伟 / Yahweh / YHWH → H3068). When a query
    // matches one of these, surface that entry first; the regular
    // gloss / lemma scan still runs to populate suggestions.
    final pinned = _aliasToStrongs[q] ?? _aliasToStrongs[q.toLowerCase()];

    final hasGreekScript = RegExp(r'[Ͱ-Ͽἀ-῿]').hasMatch(q);
    final hasHebrewScript = RegExp(r'[֐-׿יִ-ﭏ]').hasMatch(q);
    // 2026-05-07 (v6): also accept Chinese-character queries -
    // matched against glossZh / glossZhTw on each entry. Without
    // this, searching "耶稣" or "神" in Word-Study returned zero
    // because Greek / Hebrew lemmas obviously do not contain CJK.
    // When CJK is present we scan BOTH testaments because the
    // right Strong's number is in whichever testament that word
    // belongs to.
    final hasCjk = RegExp(r'[一-鿿]').hasMatch(q);
    final scanGreek = hasGreekScript ||
        hasCjk ||
        (!hasGreekScript && !hasHebrewScript);
    final scanHebrew = hasHebrewScript ||
        hasCjk ||
        (!hasGreekScript && !hasHebrewScript);

    final results = <_LemmaMatch>[];

    if (scanGreek) {
      _greek ??=
          await (_greekLoading ??= _load('assets/strongs/greek.json'));
      _scanLexicon(_greek!, q, norm, hasGreekScript, hasCjk, results);
    }
    if (scanHebrew) {
      _hebrew ??=
          await (_hebrewLoading ??= _load('assets/strongs/hebrew.json'));
      _scanLexicon(_hebrew!, q, norm, hasHebrewScript, hasCjk, results);
    }

    results.sort((a, b) => a.score.compareTo(b.score));
    final out = results.take(limit).map((m) => m.entry).toList();

    // If a pinned alias matched and the entry exists, hoist it to
    // the front of the result list (or insert if absent).
    if (pinned != null) {
      _greek ??=
          await (_greekLoading ??= _load('assets/strongs/greek.json'));
      _hebrew ??=
          await (_hebrewLoading ??= _load('assets/strongs/hebrew.json'));
      final entry = pinned.startsWith('G')
          ? _greek![pinned]
          : pinned.startsWith('H')
              ? _hebrew![pinned]
              : null;
      if (entry != null) {
        out.removeWhere((e) => e.number == pinned);
        out.insert(0, entry);
        if (out.length > limit) out.removeLast();
      }
    }
    return out;
  }

  /// Lower-case + strip combining diacritics so "Agápē" / "agape" /
  /// "AGAPÉ" all hash to the same key. Greek ί → ι, ή → η, etc.
  /// Hebrew vowel points (combining diacritics) stripped so the
  /// consonantal lemma matches what users typically type.
  static String _normaliseForLemma(String s) {
    final lower = s.toLowerCase().trim();
    // Strip combining marks (NFD-decompose, drop \p{Mn}-equivalents).
    final out = StringBuffer();
    for (final r in lower.runes) {
      // Skip combining diacritical marks (U+0300..036F, Greek/Coptic
      // diacritics in U+1AB0+, Hebrew points U+0591..05BD/05BF/05C1-5).
      if (r >= 0x0300 && r <= 0x036F) continue;
      if (r >= 0x0591 && r <= 0x05BD) continue;
      if (r == 0x05BF) continue;
      if (r >= 0x05C1 && r <= 0x05C7) continue;
      if (r >= 0x1AB0 && r <= 0x1AFF) continue;
      out.writeCharCode(r);
    }
    return out.toString();
  }

  static void _scanLexicon(
    Map<String, StrongsEntry> lex,
    String rawQuery,
    String normQuery,
    bool isOriginalScript,
    bool hasCjk,
    List<_LemmaMatch> out,
  ) {
    for (final entry in lex.values) {
      // Match against lemma (original script) and translit
      // (romanised). Both normalised the same way so "ἀγάπη" /
      // "agape" / "Agápē" all hit the same entry.
      final lemmaNorm = _normaliseForLemma(entry.lemma);
      final translitNorm = _normaliseForLemma(entry.translit);
      int? score;
      // 0 = exact lemma; 1 = exact translit; 2 = prefix; 3 = contains.
      if (lemmaNorm == normQuery) {
        score = 0;
      } else if (translitNorm == normQuery) {
        score = 1;
      } else if (lemmaNorm.startsWith(normQuery) ||
          translitNorm.startsWith(normQuery)) {
        score = 2;
      } else if (lemmaNorm.contains(normQuery) ||
          translitNorm.contains(normQuery)) {
        score = 3;
      }
      // 2026-05-07 (v6): CJK input also matches the Chinese gloss
      // fields. CBOL glosses are typically comma- or semicolon-
      // delimited lists like "耶稣, 上帝的儿子, ..." with the
      // primary meaning first. Splitting on punctuation lets us
      // score an exact match against the FIRST segment as score
      // 0 (best), so G2424 ('耶稣, ...') wins over G2494
      // ('耶稣的祖先之一 ...') for the query "耶稣". Without the
      // split, both would score 2 (prefix) and ranking would be
      // arbitrary by lexicon-key order.
      if (score == null && hasCjk) {
        // 2026-05-07 (v7): tightened CJK matching. The previous
        // version allowed substring contains-matching, which
        // produced false hits like "天地" matching G460
        // glossZh "无法无天地 ..." (the idiom for "lawlessly").
        // Chinese words combine in unpredictable ways; substring
        // overlap is almost never a real semantic match.
        //
        // Policy now: ONLY allow these match grades for CJK:
        //   0 - the query is exactly one of the comma-delimited
        //       segments of the gloss (the strongest signal --
        //       the user typed the canonical Chinese rendering
        //       of this Strong's word).
        //   1 - whole-field equality (rare but unambiguous).
        // No prefix, no substring, no contains. If a CJK query
        // doesn't have a clean segment-level match, fall through
        // to "no lexicon entry" rather than surface a wrong word.
        // The pinned alias table at the top of searchByLemma
        // covers high-frequency theological terms whose CBOL
        // gloss is too thin / abstract for segment matching
        // (雅伟 / 耶稣 / etc.).
        //
        // Divine-name normalization still applies before matching
        // (耶和华 -> 雅伟, 耶和華 -> 雅偉).
        final candidates = <String>[
          _normaliseDivineGloss((entry.glossZh ?? '').trim()),
          _normaliseDivineGloss((entry.glossZhTw ?? '').trim()),
        ];
        final segSplit = RegExp(r'[,，;；、]');
        for (final gloss in candidates) {
          if (gloss.isEmpty) continue;
          if (gloss == rawQuery) {
            score = (score == null || score > 1) ? 1 : score;
          }
          for (final seg
              in gloss.split(segSplit).map((s) => s.trim())) {
            if (seg.isEmpty) continue;
            if (seg == rawQuery) {
              score = 0;
              break;
            }
          }
          if (score == 0) break;
        }
      }
      if (score != null) {
        out.add(_LemmaMatch(entry: entry, score: score));
      }
    }
  }
  /// 2026-05-07 (v6): mirror of `_normalizeDivineNames` from
  /// text_patterns.dart, applied to Strong's Chinese glosses
  /// before matching. Maps `耶和华 → 雅伟` (Hans) and
  /// `耶和華 → 雅偉` (Hant) so the user's "雅伟" / "雅偉" query
  /// finds entries whose raw CBOL gloss still uses the older
  /// transliteration form.
  ///
  /// 2026-05-10 (v1.2.33): traditional output corrected from
  /// `雅威` → `雅偉` to match the project canonical pairing
  /// 雅伟 / 雅偉. The alias map at the top of `searchByLemma`
  /// keeps `雅威 → H3068` for backward-compat input-side matching
  /// (so users who type `雅威` still find YHWH).
  static String _normaliseDivineGloss(String s) {
    if (s.isEmpty) return s;
    return s
        .replaceAll('耶和华', '雅伟')
        .replaceAll('耶和華', '雅偉');
  }
}

/// Internal scoring tuple for [StrongsService.searchByLemma].
class _LemmaMatch {
  final StrongsEntry entry;
  final int score;
  const _LemmaMatch({required this.entry, required this.score});
}
