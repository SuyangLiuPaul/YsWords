import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Thirteenth instalment of the converter-hole defect (see
/// traditional_classifier_test.dart for 隻, traditional_leftover_glyphs_test
/// .dart for 淨/牆/餘, traditional_hair_glyph_test.dart for 髮,
/// traditional_beard_glyph_test.dart for 鬍/鬚/採, traditional_flour_glyph_test
/// .dart for 麵, traditional_jar_glyph_test.dart for 罈,
/// traditional_grain_glyph_test.dart for 穀, traditional_loosen_glyph_test.dart
/// for 鬆, traditional_dry_glyph_test.dart for 干/乾,
/// traditional_divination_glyph_test.dart for 卜 and
/// traditional_constancy_glyph_test.dart for 恆). The converter never once
/// wrote 凌, so every 凌辱 in the Traditional Bible was spelt 淩辱 — 士師記
/// 19:25, 撒母耳記上 31:4, 路加福音 6:28 — along with 欺淩 and the 淩遲 of
/// 但以理書 2:5.
///
/// Like 卜 and 恆 this is a partition rather than a split: before the repair
/// ours held 37 淩 and ZERO 凌, and the independently imported witness (git blob
/// 7a2dc43) holds 37 凌 and ZERO 淩, agreeing verse for verse on all 31,102. The
/// sharpest evidence that it is a defect rather than a preference is the
/// Simplified side, pinned below — 凌 is the correct form in BOTH scripts, so
/// the converter mangled a character that needed no conversion at all.
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

  test('insult is written 凌, and the variant form is absent entirely', () {
    expect(count('凌'), 37);
    expect(count('淩'), 0);
  });

  test('no reading is left setting 淩', () {
    const cues = <String>['淩辱', '欺淩', '淩遲'];
    final offenders = <String>[];
    for (final v in verses) {
      final text = v['text'] as String;
      for (final cue in cues) {
        if (!text.contains(cue)) continue;
        offenders.add('${v['book']} ${v['chapter']}:${v['verse']} — $cue');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Re-run tools/repair_tr_insult_glyph.py.');
  });

  test('the verses a reader would notice read correctly', () {
    expect(textOf('士師記', '19', '25'), contains('終夜凌辱她'));
    expect(textOf('撒母耳記上', '31', '4'), contains('凌辱我'));
    expect(textOf('路加福音', '6', '28'), contains('凌辱你們的'));
    expect(textOf('詩篇', '44', '15'), contains('我的凌辱終日在我面前'));
    expect(textOf('尼希米記', '2', '17'), contains('免得再受凌辱'));
    expect(textOf('希伯來書', '11', '26'), contains('基督受的凌辱'));
  });

  test('the two readings a 凌辱-only rule would have missed', () {
    // 欺凌 and 凌遲 do not contain 凌辱, so a cue-driven repair would have left
    // five verses behind. They move because the class is a partition, which is
    // why this instalment needed no cue to decide anything.
    expect(textOf('歷代志下', '28', '20'), contains('反倒欺凌他'));
    expect(textOf('箴言', '26', '18'), contains('欺凌鄰舍'));
    expect(textOf('但以理書', '2', '5'), contains('必被凌遲'));
    expect(textOf('但以理書', '3', '29'), contains('必被凌遲'));
  });

  test('the Simplified edition already wrote 凌 — the same character', () {
    // Unlike the rest of this class, Simplified and Traditional agree here:
    // 凌 is standard in both. So the Simplified asset is not the pre-conversion
    // form of a variant, it is the same character our Traditional edition
    // should have kept, and its 37 line up with ours.
    final simplified =
        (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
    final plain = simplified.map((v) => v['text'] as String).join();
    expect(plain.split('凌').length - 1, 37);
    expect(plain.contains('淩'), isFalse);
  });

  test('the sermon corpus is not swept — it never had this hole', () {
    // Produced by a different, phrase-aware converter: 23 凌 and no 淩 at all,
    // so none of the tools in tools/ applies to it. This test exists so that a
    // repo-wide sweep is a deliberate act rather than a side effect.
    var correct = 0;
    var variant = 0;
    for (final f in Directory('assets/sermons/zh-TW').listSync()) {
      if (f is! File) continue;
      final s = f.readAsStringSync();
      correct += s.split('凌').length - 1;
      variant += s.split('淩').length - 1;
    }
    // 2026-09-05: sermons 100, 369 and 370 had shipped a separate,
    // TRUNCATED Traditional translation (100: 6 331 characters against a
    // Simplified 18 304) and were rebuilt the way the other 286 were —
    // `opencc -c s2t` over the Simplified body. That is ~38 000 characters
    // of corpus that did not exist when this number was last measured, so
    // the total moved. Every new occurrence was read before the number was
    // changed; the one new 凌 is 370’s 凌晨五點, and 淩 is still 0.
    // 2026-09-06: 24 → 42 when 125 sermons were merged in from the
    // fuyindiantai staging library and 51 bodies were replaced. Every new
    // occurrence was read — 凌辱 ×3 (「凌辱他們」, the wicked tenants),
    // 倍受凌辱, 恃強凌弱, 凌駕 ×2, 盛氣凌人, 凌晨 ×2 and the like — and
    // 淩 is still 0, which is the half that carries the claim.
    expect(correct, 42);
    expect(variant, 0);
  });

  test('the independently translated NT agrees', () {
    // 梁家鏗's Traditional NT is not a conversion of anything in this repo, so
    // it is a second source: 10 凌 in the verse text (欺凌 ×2, 凌辱 ×7, 凌駕),
    // none of them 淩. The file holds 15 in total — the other five are 凌晨 in
    // the translator's notes on the Roman watches, which is the same character
    // in a reading scripture does not use here.
    final rows = (json.decode(File('assets/biblexg-v2-tr.json')
        .readAsStringSync()) as List).cast<Map<String, dynamic>>();
    final text = rows.map((v) => v['text'] as String).join();
    expect(text.split('凌').length - 1, 10);
    expect(File('assets/biblexg-v2-tr.json').readAsStringSync().contains('淩'),
        isFalse);
  });
}
