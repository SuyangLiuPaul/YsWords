import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Strong's lexicon's Traditional fields used to be set in OpenCC's
/// standard-Traditional orthography (爲/着/羣/衆/喫/牀) while the Bible text
/// was set in this edition's (為/著/群/眾/吃/床) — 2,816 positions sitting side
/// by side on the word-tap sheet. The user delegated the choice
/// (「这个你决定吧」) and the loop chose to follow the edition, on the same
/// reasoning as the 2026-09-02 ruling for `biblexg-v2-tr`
/// (「参考和合本最新版本的繁体版…用他们的」): `originals_sheet.dart` renders the
/// gloss and the tapped verse in ONE panel, so adjacency — not volume — is
/// what settled it.
///
/// `tools/reset_lexicon_orthography.py --apply --user-ruled` did the sweep
/// (`glossZhTw`/`defZhTw` only, 2,816 positions). In the same pass,
/// `tools/repair_lexicon_zhu_glyph.py` fixed 51 positions in `glossZh`/
/// `defZh` that were wrong in BOTH orthographies: 著名/著稱/著作/著述/顯著
/// spelt with 着, which is never the zhù reading. The Traditional side
/// already read the same 51 words as 着 before the sweep, so the blanket
/// 着→著 sweep fixed them there for free — the Simplified side needed its own
/// targeted repair, which is what the second script does.
///
/// This is now a work order in the OTHER direction from before the sweep: a
/// stray hit of an opencc form below means the lexicon regressed, and the
/// edition-form counts are a floor that should only ever grow (new entries),
/// never shrink back toward the opencc numbers.
void main() {
  late String tw;
  late String sc;
  late Map<String, dynamic> hebrew;
  late Map<String, dynamic> greek;
  late String bible;

  setUpAll(() {
    final twBuf = StringBuffer();
    final scBuf = StringBuffer();
    hebrew =
        json.decode(File('assets/strongs/hebrew.json').readAsStringSync())
            as Map<String, dynamic>;
    greek = json.decode(File('assets/strongs/greek.json').readAsStringSync())
        as Map<String, dynamic>;
    for (final doc in [hebrew, greek]) {
      for (final entry in doc.values.cast<Map<String, dynamic>>()) {
        for (final field in ['glossZhTw', 'defZhTw']) {
          final value = entry[field];
          if (value is String) twBuf.write(value);
        }
        for (final field in ['glossZh', 'defZh']) {
          final value = entry[field];
          if (value is String) scBuf.write(value);
        }
      }
    }
    tw = twBuf.toString();
    sc = scBuf.toString();

    final verses =
        (json.decode(File('assets/cuvs-yhwh-tr.json').readAsStringSync())
                as List)
            .cast<Map<String, dynamic>>();
    bible = verses.map((v) => v['text'] as String).join();
  });

  int count(String haystack, String needle) =>
      needle.allMatches(haystack).length;

  test('the lexicon holds none of the opencc-orthography forms', () {
    for (final ch in ['爲', '羣', '衆', '着', '喫', '牀']) {
      expect(count(tw, ch), 0,
          reason: 'lexicon regressed to opencc s2t orthography: $ch');
    }
  });

  test('the lexicon is set in this edition\'s orthography — 2,816 positions',
      () {
    const edition = <String, int>{
      '為': 1883,
      '群': 195,
      '眾': 195,
      '著': 419,
      '吃': 82, // 5 original 口吃 (stammer) + 77 swept from 喫 (eat)
      '床': 47,
    };
    edition.forEach((ch, expected) {
      expect(count(tw, ch), expected, reason: 'lexicon $ch count moved');
    });
  });

  test('the stammer stays a stammer — H3933 and G945 are 口吃, not eating',
      () {
    String field(String id, String name) {
      final doc = id.startsWith('H') ? hebrew : greek;
      return (doc[id] as Map<String, dynamic>)[name] as String;
    }

    expect(
        count(field('H3933', 'glossZhTw'), '口吃') +
            count(field('H3933', 'defZhTw'), '口吃'),
        greaterThan(0));
    expect(
        count(field('G945', 'glossZhTw'), '口吃') +
            count(field('G945', 'defZhTw'), '口吃'),
        greaterThan(0));
    expect(count(tw, '喫'), 0,
        reason: '喫 must be zero corpus-wide post-sweep');
    expect(count(sc, '喫'), 0);
  });

  test('the 51 zhù-sense 着 in the Simplified fields are gone', () {
    for (final bigram in ['着名', '着称', '着作', '着述', '显着']) {
      expect(count(sc, bigram), 0,
          reason: '$bigram — re-run tools/repair_lexicon_zhu_glyph.py');
    }
    for (final bigram in ['著名', '著称', '著作', '著述', '显著']) {
      expect(count(sc, bigram), greaterThan(0), reason: bigram);
    }
  });

  test('the Simplified aspect particle 着 was left alone — 368 positions',
      () {
    // 419 original 着 in glossZh/defZh minus the 51 zhù-sense repair above.
    // A blanket sweep here would corrupt all 368 — this number is what
    // proves the repair was bigram-targeted, not a find-and-replace.
    expect(count(sc, '着'), 368);
  });

  test('the Bible text is unaffected and unswept', () {
    for (final ch in ['爲', '羣', '衆', '着', '喫', '牀']) {
      expect(count(bible, ch), 0,
          reason: 'the Traditional Bible gained $ch');
    }
    const edition = <String, int>{
      '為': 7952,
      '群': 323,
      '眾': 1895,
      '著': 2651,
      '吃': 1043,
      '床': 80,
    };
    edition.forEach((ch, expected) {
      expect(count(bible, ch), expected, reason: 'Bible $ch count moved');
    });
  });

  test('the two lexicon repairs opencc did not make are still there', () {
    // 88 崙 (Hebron and fifteen other names, cf0782d) and 21 姪 (Lot's
    // nephew, ca09531) are the only hand edits the lexicon has ever had. They
    // disagree with opencc, so a reconversion would silently undo them.
    expect(tw.contains('希伯崙'), isTrue);
    expect(count(tw, '侄'), 0,
        reason: 'the lexicon spelt a nephew 侄 again — the Bible text beside '
            'it reads 姪');
  });
}
