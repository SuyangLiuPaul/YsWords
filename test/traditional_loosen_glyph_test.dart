import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Eighth instalment of the converter-hole defect (see
/// traditional_classifier_test.dart for 隻, traditional_leftover_glyphs_test
/// .dart for 淨/牆/餘, traditional_hair_glyph_test.dart for 髮,
/// traditional_beard_glyph_test.dart for 鬍/鬚/採, traditional_flour_glyph_test
/// .dart for 麵, traditional_jar_glyph_test.dart for 罈 and
/// traditional_grain_glyph_test.dart for 穀). Simplified 松 collapses two
/// Traditional characters — 松 (the pine) and 鬆 (loose, slack, to let go) — and
/// the converter resolved every one of them to the tree, so 「總要向他松開手」,
/// 「必不放松」 and 「鎖鏈也都松開了」 all printed the pine.
///
/// What makes this instalment cheap to pin, unlike 髮 or 穀, is that all 51
/// occurrences sit in one of ten fixed collocations and the two groups are
/// disjoint and exhaustive. Both directions are pinned below: a blanket
/// 松→鬆 substitution fails the third test, a revert fails the first two and
/// the fourth.
void main() {
  const path = 'assets/cuvs-yhwh-tr.json';

  late List<Map<String, dynamic>> verses;
  late String blob;

  setUpAll(() {
    verses = (json.decode(File(path).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    blob = verses.map((v) => v['text'] as String).join();
  });

  String textOf(String book, String chapter, String verse) => verses
      .firstWhere((v) =>
          v['book'] == book &&
          '${v['chapter']}' == chapter &&
          '${v['verse']}' == verse)['text'] as String;

  int count(String s) => blob.split(s).length - 1;

  test('loosening is written 鬆, in the number the witness has', () {
    expect(count('鬆'), 24);
    expect(count('松'), 27);
  });

  test('no reading that can only be loosening is left setting 松', () {
    const cues = <String>['松緩', '松手', '松開', '輕松', '放松'];
    final offenders = <String>[];
    for (final v in verses) {
      final text = v['text'] as String;
      for (final cue in cues) {
        if (!text.contains(cue)) continue;
        offenders.add('${v['book']} ${v['chapter']}:${v['verse']} — $cue');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Re-run tools/repair_tr_loosen_glyph.py.');
  });

  test('the pine still reads 松', () {
    // A blanket 松→鬆 substitution would break every one of these. 杜松 is the
    // KJV "heath", 松類 the parenthetical gloss on 羅騰樹 ("juniper"), and
    // 松香 the pitch of the ark — none is a tree name a rule would spot.
    expect(textOf('創世紀', '6', '14'), contains('裏外抹上松香'));
    expect(textOf('列王紀上', '6', '34'), contains('用松木做門兩扇'));
    expect(textOf('以賽亞書', '55', '13'), contains('松樹長出'));
    expect(textOf('耶利米書', '17', '6'), contains('沙漠的杜松'));
    expect(textOf('列王紀上', '19', '4'), contains('松類'));
    expect(textOf('撒迦利亞書', '11', '2'), contains('松樹啊，應當哀號'));
  });

  test('the verses a reader would notice read correctly', () {
    // KJV: "open thine hand wide", "will not let it go", "loose the bands of
    // wickedness", "the law is slacked", "ease thou somewhat".
    expect(textOf('申命記', '15', '8'), contains('總要向他鬆開手'));
    expect(textOf('約伯記', '27', '6'), contains('必不放鬆'));
    expect(textOf('以賽亞書', '58', '6'), contains('鬆開兇惡的繩'));
    expect(textOf('哈巴谷書', '1', '4'), contains('因此律法放鬆'));
    expect(textOf('歷代志下', '10', '4'), contains('負的重軛輕鬆些'));
    expect(textOf('使徒行傳', '16', '26'), contains('鎖鏈也都鬆開了'));
    // 松 opens this verse, so it is the one position with no left-hand context
    // to match the witness on — pinned in full because of it.
    expect(textOf('約伯記', '30', '11'), startsWith('鬆開他們的繩索'));
  });

  test('the ten collocations account for every 松 and 鬆 in the corpus', () {
    // The structural fact behind the repair, and the reason it needed no
    // judgement call: the two groups are disjoint and exhaustive, and every
    // verse holds exactly one occurrence, so no verse mixes the readings.
    const pine = <String>['松香', '松木', '松類', '松樹', '杜松'];
    const loosen = <String>['鬆緩', '鬆手', '鬆開', '輕鬆', '放鬆'];
    int total(List<String> cues) =>
        cues.fold(0, (sum, cue) => sum + count(cue));
    expect(total(pine), count('松'));
    expect(total(loosen), count('鬆'));

    for (final v in verses) {
      final text = v['text'] as String;
      final here = (text.split('松').length - 1) + (text.split('鬆').length - 1);
      expect(here, lessThanOrEqualTo(1),
          reason: '${v['book']} ${v['chapter']}:${v['verse']} holds $here');
    }
  });

  test('the exegesis asset glosses λύω with 鬆開, not the pine', () {
    // The same converter hole one asset over: 梁家鏗's Traditional NT carried a
    // single 松開 in a study note on καταλύω, against five correct 鬆開
    // elsewhere in the same file — so the asset's own convention settles it.
    // Its remaining three 松 are 甘松/甘松香膏, spikenard, and are correct.
    final raw = File('assets/biblexg-v2-tr.json').readAsStringSync();
    expect(raw.contains('松開'), isFalse);
    expect(raw.split('松').length - 1, 3);
    final xg = (json.decode(raw) as List).cast<Map<String, dynamic>>();
    final note = (xg.firstWhere((v) => v['id'] == '47005010')['blockNotes']
        as List)[0] as String;
    expect(note, contains('鬆開、解開、摧毀、結束'));
  });

  test('the Simplified editions are untouched — 松 is right for both there',
      () {
    // Simplified has one glyph for both meanings, so 51 松 / 0 鬆 is correct
    // in the Simplified verse asset and in the tagged Strong's corpus (which
    // is Simplified-only and never offered on the Traditional version).
    final simplified =
        (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
    final plain = simplified.map((v) => v['text'] as String).join();
    expect(plain.split('松').length - 1, 51);
    expect(plain.contains('鬆'), isFalse);
  });
}
