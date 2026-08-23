import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every key in the sermon reverse index must name a passage that
/// actually exists — otherwise a sermon is filed under a reference
/// nobody can navigate to, and it is unreachable by that path.
///
/// 2026-08-23: seven keys failed this. Four were chapter/verse
/// confusions in one-chapter books ("Jude 6 confirms this" indexed as
/// Jude chapter 6); three were prose numbers read as chapters — the
/// Chinese conjunction 但 in 「但20分钟」/「但48小时」 taken as the
/// Daniel abbreviation, and "occurs in Deuteronomy 43 times" taken as
/// a chapter. All seven repaired IN refs.json directly, because the
/// shipped index was built by a richer extractor generation than the
/// one in scripts/ — a wholesale regeneration today would silently
/// drop dozens of prose-derived references (measured: −32 keys).
/// This test is what keeps the next bad key from shipping quietly.
void main() {
  late final Map<String, dynamic> refs = jsonDecode(
          File('assets/sermons/refs.json').readAsStringSync())
      as Map<String, dynamic>;

  // KJV is the resolution corpus: full canon, and its book names are
  // the same canonical English strings the extractor emits.
  late final Map<String, Map<int, Set<int>>> canon = () {
    final out = <String, Map<int, Set<int>>>{};
    final rows = jsonDecode(File('assets/kjv.json').readAsStringSync())
        as List<dynamic>;
    for (final r in rows) {
      final m = r as Map<String, dynamic>;
      final book = m['book'] as String;
      final ch = int.parse(m['chapter'] as String);
      final v = int.parse(m['verse'] as String);
      ((out[book] ??= {})[ch] ??= <int>{}).add(v);
    }
    return out;
  }();

  test('every byVerse key resolves to a real book, chapter and verse',
      () {
    final bad = <String>[];
    for (final key in (refs['byVerse'] as Map).keys.cast<String>()) {
      final space = key.lastIndexOf(' ');
      if (space == -1) {
        bad.add('$key (no chapter at all)');
        continue;
      }
      final book = key.substring(0, space);
      final tail = key.substring(space + 1);
      final colon = tail.indexOf(':');
      final ch =
          int.tryParse(colon == -1 ? tail : tail.substring(0, colon));
      final verse =
          colon == -1 ? null : int.tryParse(tail.substring(colon + 1));
      final chapters = canon[book];
      if (chapters == null) {
        bad.add('$key (unknown book "$book")');
      } else if (ch == null || !chapters.containsKey(ch)) {
        bad.add('$key ($book has ${chapters.length} chapters)');
      } else if (verse != null && !chapters[ch]!.contains(verse)) {
        bad.add('$key ($book $ch has ${chapters[ch]!.length} verses)');
      }
    }
    expect(bad, isEmpty,
        reason: 'unresolvable sermon references:\n  ${bad.join('\n  ')}');
  });

  test('the four one-chapter repairs landed, sermons intact', () {
    final bv = refs['byVerse'] as Map;
    expect(bv['Jude 1:6'], ['115']);
    expect(bv['Jude 1:11'], ['420']);
    expect(bv['2 John 1:7'], ['239']);
    expect(bv['2 John 1:10'], ['056']);
    for (final gone in [
      'Jude 6', 'Jude 11', '2 John 7', '2 John 10',
      'Daniel 20', 'Daniel 48', 'Deuteronomy 43',
    ]) {
      expect(bv.containsKey(gone), isFalse, reason: '$gone should be gone');
    }
  });
}
