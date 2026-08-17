import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fourteenth instalment of the converter-hole defect (see
/// traditional_classifier_test.dart for 隻, traditional_leftover_glyphs_test
/// .dart for 淨/牆/餘, traditional_hair_glyph_test.dart for 髮,
/// traditional_beard_glyph_test.dart for 鬍/鬚/採, traditional_flour_glyph_test
/// .dart for 麵, traditional_jar_glyph_test.dart for 罈,
/// traditional_grain_glyph_test.dart for 穀, traditional_loosen_glyph_test.dart
/// for 鬆, traditional_dry_glyph_test.dart for 干/乾,
/// traditional_divination_glyph_test.dart for 卜,
/// traditional_constancy_glyph_test.dart for 恆 and
/// traditional_insult_glyph_test.dart for 凌). The converter never once wrote
/// 症, so the whole of 利未記 15 — the chapter on 漏症 — was spelt 漏癥, and
/// 馬太福音 4:23 had Jesus healing 各樣的病癥.
///
/// Like 卜, 恆 and 凌 this is a partition rather than a split: before the repair
/// ours held 26 癥 and ZERO 症, and the independently imported witness (git blob
/// 7a2dc43) holds 26 症 and ZERO 癥, agreeing verse for verse on all 31,102.
/// 症 and 癥 are two different words sharing one Simplified form — 症 is the
/// illness, 癥 is an abdominal mass and survives in modern Traditional
/// essentially only in 癥結, which scripture never says.
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

  test('an illness is written 症, and the other word is absent entirely', () {
    expect(count('症'), 26);
    expect(count('癥'), 0);
  });

  test('no reading is left setting 癥', () {
    const cues = <String>['漏癥', '病癥', '火癥', '熱癥'];
    final offenders = <String>[];
    for (final v in verses) {
      final text = v['text'] as String;
      for (final cue in cues) {
        if (!text.contains(cue)) continue;
        offenders.add('${v['book']} ${v['chapter']}:${v['verse']} — $cue');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Re-run tools/repair_tr_ailment_glyph.py.');
  });

  test('the verses a reader would notice read correctly', () {
    expect(textOf('利未記', '15', '2'), contains('人若身患漏症'));
    expect(textOf('利未記', '15', '13'), contains('患漏症的人'));
    expect(textOf('利未記', '15', '25'), contains('有了漏症'));
    expect(textOf('民數記', '5', '2'), contains('患漏症的'));
    expect(textOf('馬太福音', '4', '23'), contains('醫治百姓各樣的病症'));
    expect(textOf('馬太福音', '10', '1'), contains('醫治各樣的病症'));
  });

  test('the three readings a 漏症-only rule would have missed', () {
    // 病症, 火症 and 熱症 do not contain 漏症, so a cue-driven repair would have
    // left six verses behind. They move because the class is a partition,
    // which is why this instalment needed no cue to decide anything.
    expect(textOf('申命記', '7', '15'), contains('一切的病症離開你'));
    expect(textOf('申命記', '28', '22'), contains('火症'));
    expect(textOf('哈巴谷書', '3', '5'), contains('有熱症發出'));
  });

  test('癥 is not simply wrong — 癥結 is its one live reading', () {
    // The claim is about this corpus, not about the language. 癥 is correct in
    // 癥結 and the sermon corpus uses it that way, so the repair had to be
    // scoped to the verse asset. If scripture ever gained a 癥結 the tool would
    // refuse rather than overwrite it.
    expect(blob.contains('癥結'), isFalse);
    final sermon =
        File('assets/sermons/zh-TW/105.txt').readAsStringSync();
    expect(sermon, contains('癥結'));
  });

  test('the sermon corpus is not swept — it never had this hole', () {
    // Produced by a different, phrase-aware converter, and here it holds the
    // one 癥 in the repo that must survive. This test exists so that a
    // repo-wide sweep is a deliberate act rather than a side effect.
    var illness = 0;
    var mass = 0;
    for (final f in Directory('assets/sermons/zh-TW').listSync()) {
      if (f is! File) continue;
      final s = f.readAsStringSync();
      illness += s.split('症').length - 1;
      mass += s.split('癥').length - 1;
    }
    expect(mass, 1);
    expect(illness, greaterThan(0));
  });

  test('the Simplified edition and the tagged corpus already agreed', () {
    // Both write the single correct Simplified form 症 in the same 26 places,
    // so nothing outside the Traditional verse asset needed touching.
    final simplified =
        (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
    final plain = simplified.map((v) => v['text'] as String).join();
    expect(plain.split('症').length - 1, 26);
    expect(plain.contains('癥'), isFalse);
  });
}
