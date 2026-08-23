import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Traditional Strong's lexicon and the Traditional Bible are set in two
/// different orthographies, and the word-tap sheet shows them side by side.
///
/// This is not a defect and nothing false is printed — every character below is
/// legitimate Traditional Chinese. It is a consequence of provenance, measured
/// on 2026-08-23 by tools/audit_lexicon_provenance.py: `assets/strongs/*.json`
/// are `opencc -c s2t` output (28,276 of 28,377 field pairs byte-identical),
/// while `assets/cuvs-yhwh-tr.json` was made by a naive per-character map that
/// opencc had no hand in. s2t writes OpenCC's own standard-Traditional forms,
/// so the lexicon says 作爲 where the verse above it says 作為.
///
/// It is pinned rather than swept because harmonising 2,816 positions is an
/// edition-wide typographic choice, of the same kind as the 兇/凶 and
/// full-width-quotes questions already waiting on the user — and because this
/// repo has a history of exactly this being done silently as a side effect of
/// some other pass. Both columns are absolute: neither file mixes the two
/// forms, so a single stray hit here means a sweep has started.
///
/// If the user decides to harmonise, these numbers are the work order; change
/// them deliberately in the same commit as the repair.
void main() {
  late String lexicon;
  late String bible;

  setUpAll(() {
    final buffer = StringBuffer();
    for (final name in ['hebrew.json', 'greek.json']) {
      final doc =
          json.decode(File('assets/strongs/$name').readAsStringSync())
              as Map<String, dynamic>;
      for (final entry in doc.values) {
        final e = entry as Map<String, dynamic>;
        for (final field in ['glossZhTw', 'defZhTw']) {
          final value = e[field];
          if (value is String) buffer.write(value);
        }
      }
    }
    lexicon = buffer.toString();

    final verses =
        (json.decode(File('assets/cuvs-yhwh-tr.json').readAsStringSync())
                as List)
            .cast<Map<String, dynamic>>();
    bible = verses.map((v) => v['text'] as String).join();
  });

  /// (the form opencc s2t writes, the form the Bible text writes,
  ///  count in the lexicon, count in the Bible)
  const divergences = <List<Object>>[
    ['爲', '為', 1883, 7952],
    ['羣', '群', 195, 323],
    ['衆', '眾', 195, 1895],
    ['着', '著', 419, 2651],
    ['喫', '吃', 77, 1043],
    ['牀', '床', 47, 80],
  ];

  int count(String haystack, String needle) =>
      needle.allMatches(haystack).length;

  test('the lexicon keeps opencc s2t orthography — 2,816 positions', () {
    var total = 0;
    for (final row in divergences) {
      final openccForm = row[0] as String;
      final bibleForm = row[1] as String;
      final expected = row[2] as int;
      expect(count(lexicon, openccForm), expected,
          reason: 'lexicon $openccForm moved — a sweep has started, or the '
              'lexicon has been reconverted');
      expect(count(lexicon, bibleForm), bibleForm == '吃' ? 5 : 0,
          reason: 'lexicon gained $bibleForm — the two orthographies are '
              'being mixed rather than chosen between');
      total += expected;
    }
    expect(total, 2816);
  });

  test('the Bible text uses none of them', () {
    for (final row in divergences) {
      final openccForm = row[0] as String;
      final bibleForm = row[1] as String;
      expect(count(bible, openccForm), 0,
          reason: 'the Traditional Bible gained $openccForm — the lexicon\'s '
              'orthography must never leak into scripture');
      expect(count(bible, bibleForm), row[3] as int,
          reason: 'the Traditional Bible lost $bibleForm');
    }
  });

  test('the two lexicon repairs opencc did not make are still there', () {
    // 88 崙 (Hebron and fifteen other names, cf0782d) and 21 姪 (Lot's
    // nephew, ca09531) are the only hand edits the lexicon has ever had. They
    // disagree with opencc, so a reconversion would silently undo them.
    expect(lexicon.contains('希伯崙'), isTrue);
    expect(count(lexicon, '侄'), 0,
        reason: 'the lexicon spelt a nephew 侄 again — the Bible text beside '
            'it reads 姪');
  });
}
