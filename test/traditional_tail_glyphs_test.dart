import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Eighteenth instalment of the converter-hole defect (see
/// traditional_classifier_test.dart for 隻 and the sibling files for 淨/牆/餘,
/// 髮, 穀, 鬆, 干/乾, 卜, 恆, 凌, 症, 癒, 崙 and 咸): 鹼 (lye) at six positions
/// and 姪 (a sibling's child) at five.
///
/// These two were the tail of the character-inventory diff, below the cut-off
/// at which that diff had ever been read. Most of the tail is NOT a defect —
/// the "we hold zero of it" signature fires just as loudly when both forms are
/// live Traditional characters — so each of the eleven was checked against two
/// independent Traditional witnesses, which agree at all eleven and disagree
/// with ours alone:
///
///   * git blob 7a2dc43, the 和合本 Traditional dropped at v1.4.5;
///   * a published 新標點和合本 (ebible `cmn-cu89t`).
///
/// Both read 6 鹼 / 0 堿 and 5 姪 / 0 侄, at these same verses.
///
/// WHAT THIS TEST IS NOT ALLOWED TO IMPLY. 堿 and 侄 are not Simplified-only
/// glyphs — both encode in Big5, and 堿 is listed under 鹼 in the MOE 異體字
/// 字典. The defect is not "an impossible character"; it is that no published
/// Traditional 和合本 sets them here. That distinction is why the last test
/// below deliberately leaves 跡 and 鏈 alone even though they carry the very
/// same partition signature.
void main() {
  late List<Map<String, dynamic>> verses;
  late String blob;
  late Map<String, dynamic> hebrew;
  late Map<String, dynamic> greek;

  setUpAll(() {
    verses =
        (json.decode(File('assets/cuvs-yhwh-tr.json').readAsStringSync())
                as List)
            .cast<Map<String, dynamic>>();
    blob = verses.map((v) => v['text'] as String).join();
    hebrew = json.decode(File('assets/strongs/hebrew.json').readAsStringSync())
        as Map<String, dynamic>;
    greek = json.decode(File('assets/strongs/greek.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  String textOf(String id) =>
      verses.firstWhere((v) => v['id'] == id)['text'] as String;

  int count(String s) => blob.split(s).length - 1;

  test('the corpus holds six 鹼 and five 姪, and none of the forms they replaced',
      () {
    expect(count('鹼'), 6);
    expect(count('姪'), 5);
    expect(count('堿'), 0);
    expect(count('侄'), 0);
  });

  test('all six alkalis read 鹼', () {
    expect(textOf('018009030'), contains('用鹼潔淨我的手'));
    expect(textOf('019107034'), contains('使肥地變為鹼地'));
    expect(textOf('020025020'), contains('又如鹼上倒醋'));
    expect(textOf('024002022'), contains('你雖用鹼、多用肥皂洗濯'));
    expect(textOf('024017006'), contains('無人居住的鹼地'));
    expect(textOf('039003002'), contains('如漂布之人的鹼'));
  });

  test('Lot is Abram\'s 姪兒, and Ahaziah\'s kin are 姪子', () {
    expect(textOf('001012005'), contains('撒萊和姪兒羅得'));
    expect(textOf('001014012'), contains('亞伯蘭的姪兒羅得'));
    expect(textOf('001014014'), contains('亞伯蘭聽見他姪兒'));
    expect(textOf('001014016'), contains('連他姪兒羅得'));
    expect(textOf('014022008'), contains('亞哈謝的眾姪子'));
  });

  test('the lexicon spells Lot\'s kinship the same way the text does', () {
    // The Traditional lexicon fields are opencc output and opencc has no
    // 侄 → 姪 mapping at all, so all 21 came through unconverted. A reader who
    // taps 羅得 on the Originals sheet would otherwise be shown a spelling the
    // verse beside it no longer uses.
    expect(hebrew['H3876']['glossZhTw'] as String, contains('亞伯拉罕的姪子'));
    expect(greek['G3091']['glossZhTw'] as String, contains('亞伯拉罕的姪子'));
    expect(hebrew['H3252']['glossZhTw'] as String, contains('亞伯拉罕的姪女'));
    expect(hebrew['H3083']['defZhTw'] as String, contains('大衛的一個姪子'));

    int lexCount(Map<String, dynamic> lex, String glyph, bool traditional) {
      var n = 0;
      for (final entry in lex.values) {
        (entry as Map<String, dynamic>).forEach((field, value) {
          if (value is! String) return;
          if (field.endsWith('ZhTw') != traditional) return;
          if (!traditional && !field.endsWith('Zh')) return;
          n += value.split(glyph).length - 1;
        });
      }
      return n;
    }

    // The Simplified twin is the per-field witness and must still hold exactly
    // the count the Traditional side now holds — 20 in Hebrew, 2 in Greek.
    // Hebrew was 19 a side until 2026-09-08: rejoining CBOL's wrapped senses
    // (`tools/repair_zh_gloss_linebreaks.py`) carried H6667's clause about
    // Jehoiachin, the nephew Nebuchadnezzar deported, into the gloss beside
    // the body that already held it. The two sides moved together, which is
    // the only thing this pair of numbers is here to check.
    expect(lexCount(hebrew, '姪', true), 20);
    expect(lexCount(hebrew, '侄', false), 20);
    expect(lexCount(greek, '姪', true), 2);
    expect(lexCount(greek, '侄', false), 2);
    expect(lexCount(hebrew, '侄', true), 0);
    expect(lexCount(greek, '侄', true), 0);
  });

  test('the Simplified source is untouched and still arbitrates', () {
    // Unlike 咸/鹹, Simplified keeps both distinctions the converter lost, so
    // the evidence for this repair stays inside the repo. 碱 is what the
    // converter turned into 堿; 侄 is what it failed to turn into anything.
    final simplified =
        (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
    final source = simplified.map((v) => v['text'] as String).join();
    expect('碱'.allMatches(source).length, 6);
    expect('侄'.allMatches(source).length, 5);
  });

  test('the hand-authored Traditional already agreed, and still does', () {
    // assets/family_tree.json was written by hand, never converted, and is the
    // one place in the repo that had 姪 before this repair.
    final tree = json.decode(File('assets/family_tree.json').readAsStringSync())
        as Map<String, dynamic>;
    final people = (tree['people'] as List).cast<Map<String, dynamic>>();
    final hant = people.map((p) => '${p['summaryZhHant'] ?? ''}').join();
    expect(hant, contains('亞伯拉罕的姪子'));
    expect(hant, contains('她姪子暗蘭'));
    expect(hant.contains('侄'), isFalse);
  });

  test('跡 and 鏈 were swept on 2026-09-14, per occurrence and not as a class',
      () {
    // This test used to pin 103 跡 / 0 蹟 and 60 鏈 / 0 鍊 as deliberately NOT
    // swept, on the grounds that both are standard Traditional spellings that
    // read correctly, so nothing false was printed and restoring 神蹟 and 金鍊
    // was "an improvement for the user to ask for". It was asked for
    // (「雅伟和合本可以change」), and the sweep it warned about is not what
    // happened: every one of these positions was read in the published 和合本
    // at its own verse, and only the ones 和合本 spells differently moved.
    //
    // What survives is the check that this was positional. Nine 跡 remain,
    // and they are the nine the 和合本 also writes with 跡 — 痕跡 ×3, 蹤跡 ×2,
    // 異跡, 火跡, 實跡, 筆跡 — while 神蹟 and the rest took 蹟. A class-level
    // verdict would have left none.
    expect(count('蹟'), 94);
    expect(count('跡'), 9);
    expect(count('鍊'), 10);
    expect(count('鏈'), 50);
    for (final word in ['痕跡', '蹤跡', '筆跡']) {
      expect(blob, contains(word), reason: '$word is the 和合本 spelling');
    }
  });
}
