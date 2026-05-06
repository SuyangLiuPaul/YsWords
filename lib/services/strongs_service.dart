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
  static Future<List<StrongsEntry>> searchByLemma(
    String query, {
    int limit = 12,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final norm = _normaliseForLemma(q);
    if (norm.isEmpty) return const [];

    final hasGreekScript = RegExp(r'[Ͱ-Ͽἀ-῿]').hasMatch(q);
    final hasHebrewScript = RegExp(r'[֐-׿יִ-ﭏ]').hasMatch(q);
    final scanGreek = hasGreekScript || (!hasGreekScript && !hasHebrewScript);
    final scanHebrew =
        hasHebrewScript || (!hasGreekScript && !hasHebrewScript);

    final results = <_LemmaMatch>[];

    if (scanGreek) {
      _greek ??=
          await (_greekLoading ??= _load('assets/strongs/greek.json'));
      _scanLexicon(_greek!, q, norm, hasGreekScript, results);
    }
    if (scanHebrew) {
      _hebrew ??=
          await (_hebrewLoading ??= _load('assets/strongs/hebrew.json'));
      _scanLexicon(_hebrew!, q, norm, hasHebrewScript, results);
    }

    results.sort((a, b) => a.score.compareTo(b.score));
    return results.take(limit).map((m) => m.entry).toList();
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
      if (score != null) {
        out.add(_LemmaMatch(entry: entry, score: score));
      }
    }
  }
}

/// Internal scoring tuple for [StrongsService.searchByLemma].
class _LemmaMatch {
  final StrongsEntry entry;
  final int score;
  const _LemmaMatch({required this.entry, required this.score});
}
