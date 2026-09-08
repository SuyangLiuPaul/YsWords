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

  test('the lexicon is set in this edition\'s orthography — 2,930 positions',
      () {
    // 2026-09-08: 為 1883→1976, 眾 195→202, 著 419→427, 群 195→196. All 114
    // new positions are characters `glossZhTw` picked up out of its own
    // `defZhTw` when `tools/repair_zh_gloss_linebreaks.py` rejoined the
    // sense CBOL had wrapped — the gloss now says more of what the body
    // beside it already said. That is the growth this file's doc comment
    // calls the sanctioned direction; nothing was re-converted.
    const edition = <String, int>{
      '為': 1976,
      '群': 196,
      '眾': 202,
      '著': 427,
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

  test('the Simplified aspect particle 着 was left alone — 374 positions',
      () {
    // 419 original 着 in glossZh/defZh minus the 51 zhù-sense repair above
    // gave 368, plus 6 that the 2026-09-08 gloss rejoin lifted out of the
    // definition bodies and into the glosses beside them (G4102 包含着,
    // G5330 按着, G5502 向着, H2652 因着, H3316 and H5912 为着 — every one
    // the aspect particle, none of them a zhù bigram).
    // A blanket sweep here would corrupt all 374 — this number is what
    // proves the repair was bigram-targeted, not a find-and-replace.
    expect(count(sc, '着'), 374);
  });

  test('the Bible text is unaffected and unswept', () {
    for (final ch in ['爲', '羣', '衆', '着', '喫', '牀']) {
      expect(count(bible, ch), 0,
          reason: 'the Traditional Bible gained $ch');
    }
    // 2026-09-09, the publisher sync. Three of the six moved and 為 /
    // 群 / 床 did not shift by a character. None of the three is an
    // orthography choice — this test's floor still holds, and the sweep
    // it guards still has not touched the Bible.
    //
    //   眾 1,895 → 1,896. Speaker labels inside 雅歌's `<note:>` markers
    //   were rewritten — 男 → 眾人 (1:8), 眾女 → 佳偶 (3:6), 男 → 良人
    //   with the second label dropped (5:1), 女的兄弟 → 眾人 (8:8) — and
    //   the note at 耶利米哀歌 2:4 was reworded. Note labels, not
    //   scripture; +1 net.
    //
    //   著 2,651 → 2,648, and this one is a repair we were owed. THREE
    //   verses of 耶利米書 had 著 standing where 裏 belongs — 7:20
    //   「地著的出產」, 20:2 「雅偉殿著便雅憫高門」, 26:15 「到你們這著
    //   來」 — a corrupted glyph, not an orthography, and the official
    //   和合本繁體 reads 裡 in all three. The sync fixed them. The other
    //   two positions are note rewordings (歷代志下 30:21 dropped 向著 →
    //   向, 約翰福音 3:36 now quotes 得不著永生 in its note): −3 net.
    //
    //   吃 1,043 → 1,044. 以賽亞書 33:4's note was reworded to quote the
    //   word it glosses (「"吃"原文是"斂"」); the running text is
    //   unchanged. +1.
    const edition = <String, int>{
      '為': 7952,
      '群': 323,
      '眾': 1896,
      '著': 2648,
      '吃': 1044,
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
