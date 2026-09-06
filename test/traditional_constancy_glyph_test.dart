import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Twelfth instalment of the converter-hole defect (see
/// traditional_classifier_test.dart for 隻, traditional_leftover_glyphs_test
/// .dart for 淨/牆/餘, traditional_hair_glyph_test.dart for 髮,
/// traditional_beard_glyph_test.dart for 鬍/鬚/採, traditional_flour_glyph_test
/// .dart for 麵, traditional_jar_glyph_test.dart for 罈,
/// traditional_grain_glyph_test.dart for 穀, traditional_loosen_glyph_test.dart
/// for 鬆, traditional_dry_glyph_test.dart for 干/乾 and
/// traditional_divination_glyph_test.dart for 卜). The converter never once
/// wrote 恆, so a Traditional Bible spelt Bethlehem 伯利恒 in all 54 places —
/// 彌迦書 5:2, 路加福音 2:4 and every nativity reference — and set 恒心 / 恒久 /
/// 恒切 everywhere else.
///
/// Like 卜 this is a partition rather than a split: before the repair ours held
/// 79 恒 and ZERO 恆, and the independently imported witness (git blob 7a2dc43)
/// holds 79 恆 and ZERO 恒, agreeing verse for verse on all 31,102. So unlike
/// 發/髮 or 谷/穀 there is no correct-in-our-form side to protect. Both
/// directions are pinned below — a revert fails the first three tests, and the
/// Simplified test is what would catch a repair that swept the whole repo.
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

  test('constancy is written 恆, and the mainland form is absent entirely', () {
    expect(count('恆'), 79);
    expect(count('恒'), 0);
  });

  test('no reading is left setting 恒', () {
    // 利恒 rather than 伯利恒 so that 雅叔比利恒 is covered too; with 伯利恒
    // the sweep silently reached 78 of 79.
    const cues = <String>[
      '利恒', '恒心', '恒久', '恒切', '恒常', '恒忍', '恒守', '恒一',
    ];
    final offenders = <String>[];
    for (final v in verses) {
      final text = v['text'] as String;
      for (final cue in cues) {
        if (!text.contains(cue)) continue;
        offenders.add('${v['book']} ${v['chapter']}:${v['verse']} — $cue');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Re-run tools/repair_tr_constancy_glyph.py.');
  });

  test('the verses a reader would notice read correctly', () {
    expect(textOf('彌迦書', '5', '2'), contains('伯利恆、以法他啊'));
    expect(textOf('路加福音', '2', '4'), contains('大衛的城，名叫伯利恆'));
    expect(textOf('馬太福音', '2', '1'), contains('猶太的伯利恆'));
    expect(textOf('路得記', '1', '22'), contains('到伯利恆'));
    expect(textOf('箴言', '11', '19'), startsWith('恆心為義的'));
    expect(textOf('使徒行傳', '1', '14'), contains('恆切禱告'));
    expect(textOf('哥林多前書', '13', '4'), contains('愛是恆久忍耐'));
    expect(textOf('羅馬書', '12', '12'), contains('禱告要恆切'));
  });

  test('the positions a Bethlehem-only rule would have missed', () {
    // 歷代志上 4:22 is a different name — Jashubi-lehem — so 伯利恒 does not
    // match it; 詩篇 89:36 has the character standing alone, with no
    // collocation at all. Both move because the class is a partition, which is
    // why this instalment needed no cue to decide anything.
    expect(textOf('歷代志上', '4', '22'), contains('雅叔比利恆'));
    expect(textOf('詩篇', '89', '36'), contains('如日之恆一般'));
  });

  test('the Simplified editions are untouched — 恒 is right for both there',
      () {
    // Simplified has one glyph for both, so 79 恒 / 0 恆 is already correct in
    // the Simplified verse asset and in the tagged Strong's corpus (which is
    // Simplified-only and never offered on the Traditional version).
    final simplified =
        (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
    final plain = simplified.map((v) => v['text'] as String).join();
    expect(plain.split('恒').length - 1, 79);
    expect(plain.contains('恆'), isFalse);
  });

  test('the sermon corpus is not swept — it never had this hole', () {
    // Produced by a different, phrase-aware converter, so none of the tools in
    // tools/ applies to it. It held 276 恆 against 2 恒, and this test pinned
    // that 276/2 so that fixing the two would have to be a deliberate act
    // rather than a side effect of some later sweep.
    //
    // UPDATED 2026-09-03, which is what "deliberate" looks like. The two —
    // 156.txt 「背景中恒常存在的」 and 327.txt 「永恒生命」 — were repaired by
    // tools/repair_tw_sermon_spot_glyphs.py, with the corpus's own 276:2 as
    // the whole of the evidence (there is no witness edition for sermon text).
    // 278 / 0 now. The pin stays, in the same spirit: the corpus is still not
    // swept, and 恒 reappearing means an unreviewed import, not a fix.
    var traditional = 0;
    var mainland = 0;
    for (final f in Directory('assets/sermons/zh-TW').listSync()) {
      if (f is! File) continue;
      final s = f.readAsStringSync();
      traditional += s.split('恆').length - 1;
      mainland += s.split('恒').length - 1;
    }
    // 278 → 436 with the merge of 2026-09-06. The zero side is the one
    // that carries the claim and it did NOT move: the six 恒 the merge
    // brought in were all 永恒生命 and were repaired by
    // `tools/repair_tw_sermon_merged_glyphs.py` against this very ratio,
    // one anchored sweep of 永恒生命 → 永恆生命 across 018, 065, 135,
    // fy-mt85, fy-nm00 and fy-nm16. The corpus is still not swept.
    // 436 → 438 on 2026-09-06 with the 15 transcribed sermons. Both new
    // 恆 were read — fy-cm03's 「光明與我永恆在」 in a sung line and
    // fy-ws04's 「所謂的永恆的盼望」 — and the zero side, which is the one
    // that carries the claim, did not move.
    expect(traditional, 438);
    expect(mainland, 0);
  });

  test('the independently translated NT agrees on 伯利恆', () {
    // 梁家鏗's Traditional NT is not a conversion of anything in this repo, so
    // it is a second source: 32 恆, none of them 恒.
    final raw = File('assets/biblexg-v2-tr.json').readAsStringSync();
    expect(raw.contains('恒'), isFalse);
    expect(raw.split('恆').length - 1, 32);
  });
}
