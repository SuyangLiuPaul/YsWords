import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sixteenth instalment of the converter-hole defect (see
/// traditional_classifier_test.dart for 隻 and the sibling files for 淨/牆/餘,
/// 髮, 穀, 鬆, 干/乾, 卜, 恆, 凌, 症 and 癒) — and the first one to reach a
/// proper NAME. The converter never once wrote 崙, so the Traditional Bible
/// misspelt 希伯崙 — Hebron, Abraham's burial place and David's first capital —
/// in 69 verses, along with fifteen other names: 155 positions in all.
///
/// The app was contradicting itself out loud. assets/section_titles.json heads
/// 撒母耳記下 2 with 「大衛在希伯崙作猶大王」 and the verse underneath it read
/// 希伯侖.
///
/// Two things make this instalment different from its predecessors.
///
/// First, 侖 is a live Traditional character — 加侖 is a gallon — so "the
/// witness holds none of it" was not sufficient on its own. The verse asset
/// happens to contain no gallon, so the class moves whole there; the Strong's
/// lexicon does contain gallons, so it is a split and was fixed name by name.
/// greek.json is left completely alone: all six of its 侖 are 加侖.
///
/// Second, this defect can be confirmed WITHOUT the external witness, which
/// matters because the witness blob was dropped from the working tree at
/// v1.4.5. assets/cuvs-yhwh.json — the Simplified edition this file was
/// converted from — distinguishes 仑 from 伦 perfectly well, and its
/// distribution now matches ours on every verse. That is the last test here and
/// it is the one that would still catch a regression in ten years.
void main() {
  late List<Map<String, dynamic>> verses;
  late String blob;

  setUpAll(() {
    verses =
        (json.decode(File('assets/cuvs-yhwh-tr.json').readAsStringSync())
                as List)
            .cast<Map<String, dynamic>>();
    blob = verses.map((v) => v['text'] as String).join();
  });

  String textOf(String book, String chapter, String verse) => verses
      .firstWhere((v) =>
          v['book'] == book &&
          '${v['chapter']}' == chapter &&
          '${v['verse']}' == verse)['text'] as String;

  int count(String s) => blob.split(s).length - 1;

  test('the ridge glyph is written 崙, and the wrong form is absent entirely',
      () {
    expect(count('崙'), 155);
    expect(count('侖'), 0);
  });

  test('every name that carries it, by longest match', () {
    // 拉沙崙 is listed apart because 沙崙 is a substring of it — a naive count
    // of 沙崙 returns 10 and double-counts 約書亞記 12:18. 義伯崙 (書 19:28) is
    // easy to miss. Both were caught only after the enumeration was re-derived
    // by tokenising the 155 positions rather than by summing a list of names.
    const names = {
      '希伯崙': 69, // Hebron
      '希斯崙': 17, // Hezron
      '伯和崙': 15, // Beth-horon
      '以弗崙': 13, // Ephron
      '亞雅崙': 9, // Aijalon
      '伸崙': 7, // Shimron
      '耶書崙': 4, // Jeshurun
      '米崙': 2, // Merom
      '米磯崙': 2, // Migron
      '拉沙崙': 1, // Lassharon
      '西斐崙': 1, // Ziphron
      '基撒崙': 1, // Chesalon
      '施基崙': 1, // Shicron
      '哈崙': 1, // Haron
      '何崙': 1, // Holon
      '希崙': 1, // Helon
      '義伯崙': 1, // Ebron
    };
    names.forEach((name, n) => expect(count(name), n, reason: name));
    // 沙崙 (Sharon) standalone, i.e. excluding the 拉沙崙 that contains it.
    expect(count('沙崙') - count('拉沙崙'), 9);
    final total =
        names.values.reduce((a, b) => a + b) + (count('沙崙') - count('拉沙崙'));
    expect(total, 155, reason: 'the enumeration must account for every 崙');
  });

  test('the verses a reader would notice read correctly', () {
    expect(textOf('創世紀', '13', '18'), contains('來到希伯崙幔利的橡樹'));
    expect(textOf('創世紀', '23', '2'), contains('就是希伯崙'));
    expect(textOf('創世紀', '23', '19'), contains('（幔利就是希伯崙）'));
    expect(textOf('撒母耳記下', '2', '11'), contains('大衛在希伯崙作猶大家的王'));
    expect(textOf('民數記', '13', '22'), contains('原來希伯崙城被建造'));
    expect(textOf('雅歌', '2', '1'), contains('我是沙崙的玫瑰花'));
    expect(textOf('申命記', '33', '26'), contains('耶書崙哪'));
    expect(textOf('約書亞記', '10', '12'), contains('你要止在亞雅崙谷'));
  });

  test('the section titles above those verses now agree with them', () {
    // The defect was visible on one screen: this heading and the verse under it.
    final titles = File('assets/section_titles.json').readAsStringSync();
    expect(titles, contains('大衛在希伯崙作猶大王'));
    expect(titles.contains('侖'), isFalse);
  });

  test("the base text's own 倫 spellings are preserved, not normalised", () {
    // 和合本 itself is inconsistent: it spells the same names 希斯倫 and 亞雅倫
    // at these three places, where 新標點 normalises them to 崙. Ours agrees
    // with the witness at all of them. Repairing a converter hole is not a
    // licence to edit the base text, so these must survive untouched.
    expect(textOf('創世紀', '46', '12'), contains('法勒斯的兒子是希斯倫'));
    expect(textOf('民數記', '26', '21'), contains('屬希斯倫的，有希斯倫族'));
    expect(textOf('士師記', '1', '35'), contains('亞雅倫並沙賓'));
    expect(count('倫'), 853);
  });

  test('the Strong\'s lexicon keeps its gallons and fixes only names', () {
    final hebrew = File('assets/strongs/hebrew.json').readAsStringSync();
    final greek = File('assets/strongs/greek.json').readAsStringSync();
    // greek.json was a false alarm: all six of its 侖 are 加侖, a gallon, and it
    // already spelt 希斯崙 correctly. Untouched, and pinned so a later sweep
    // does not "finish the job" and print 加崙.
    expect('加侖'.allMatches(greek).length, 6);
    expect('侖'.allMatches(greek).length, 6);
    expect('希斯崙'.allMatches(greek).length, 2);
    // hebrew.json is a genuine split: opencc's phrase table knew 希斯崙 and
    // 沙崙 but not 希伯崙, so half the names in one file were already right.
    expect('加侖'.allMatches(hebrew).length, 2);
    expect('侖'.allMatches(hebrew).length, 2, reason: 'only the gallons remain');
    expect('希伯崙'.allMatches(hebrew).length, 63);
  });

  test('西伯崙 is fixed as a glyph, and its 西/希 typo is left for the user', () {
    // H6814 (Zoan) reads 「在西伯崙之後7年建立」; 民數記 13:22 in our own Bible
    // reads 「希伯崙城被建造比埃及的鎖安城早七年」 — the same fact in the same
    // words, so this is 希伯崙 under a 西/希 typo in the Simplified source.
    //
    // What licenses the glyph fix is NOT "a name ending in 西伯 must be 崙" —
    // that rule is false, and H2811 in this same file is the counter-example:
    // 「西伯倫族的哈沙比雅」, the Kohathite clan, which our Bible spells 希伯倫
    // twelve times. It is the Simplified twin that settles it. Simplified
    // distinguishes 仑 from 伦, these three read 西伯仑, and 仑 here is 崙.
    //
    // The 西/希 letter itself is in the Simplified fields too, so correcting it
    // would be an editorial change to the source. Queued, not guessed at.
    final lex = json.decode(File('assets/strongs/hebrew.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(lex['H6814']['defZhTw'] as String, contains('在西伯崙之後7年建立'));
    expect(lex['H5555']['glossZhTw'] as String, contains('在西伯崙東方'));
    expect(lex['H6814']['defZh'] as String, contains('西伯仑'),
        reason: 'the Simplified source is untouched — the typo is still queued');
    // The counter-example, pinned so the false rule cannot come back: the clan
    // is 倫, its Simplified twin is 伦, and neither was touched.
    expect(lex['H2811']['defZhTw'] as String, contains('西伯倫族'));
    expect(lex['H2811']['defZh'] as String, contains('西伯伦族'));
  });

  test('the Hebronite clan is spelt 希伯倫 and was not swept into 希伯崙', () {
    // 12 verses name the Kohathite clan, and they take 倫, not 崙. They sit one
    // character away from the 69 verses that were changed, so they are the
    // nearest false positive this repair had and are pinned deliberately.
    expect(count('希伯倫'), 12);
    expect(textOf('出埃及記', '6', '18'), contains('希伯倫'));
    expect(textOf('民數記', '26', '58'), contains('希伯倫族'));
    expect(textOf('歷代志上', '26', '31'), contains('希伯倫族'));
  });

  test('the Simplified source confirms every position, verse by verse', () {
    // The strongest check available, and the only one here that does not lean
    // on the dropped witness blob. assets/cuvs-yhwh.json is the file this
    // Traditional edition was converted FROM, and Simplified distinguishes 仑
    // from 伦 perfectly well — the merge happened on the way out, not on the
    // way in. So if any 崙 sat where a 倫 belongs, or the sweep had caught a
    // 倫, this would fail on that verse.
    final simplified =
        (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
    final byId = {for (final v in verses) v['id'] as String: v['text'] as String};
    final offenders = <String>[];
    for (final v in simplified) {
      final source = v['text'] as String;
      final tr = byId[v['id'] as String];
      expect(tr, isNotNull, reason: '${v['id']}');
      if ('仑'.allMatches(source).length != '崙'.allMatches(tr!).length ||
          '伦'.allMatches(source).length != '倫'.allMatches(tr).length) {
        offenders.add('${v['book']} ${v['chapter']}:${v['verse']}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Re-run tools/repair_tr_ridge_glyph.py.');
  });
}
