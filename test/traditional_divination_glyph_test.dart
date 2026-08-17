import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Eleventh instalment of the converter-hole defect (see
/// traditional_classifier_test.dart for 隻, traditional_leftover_glyphs_test
/// .dart for 淨/牆/餘, traditional_hair_glyph_test.dart for 髮,
/// traditional_beard_glyph_test.dart for 鬍/鬚/採, traditional_flour_glyph_test
/// .dart for 麵, traditional_jar_glyph_test.dart for 罈,
/// traditional_grain_glyph_test.dart for 穀, traditional_loosen_glyph_test.dart
/// for 鬆 and traditional_dry_glyph_test.dart for 干/乾). Simplified 卜 stands
/// for two Traditional characters — 卜 (divination, and the names built on it)
/// and 蔔, which occurs only in 蘿蔔, a radish — and the converter resolved
/// every one of the 42 to the radish. So 「占蔔的、觀兆的」, 「謊詐的占蔔」 and
/// the rulers of Ekron's god 巴力西蔔 all printed a root vegetable.
///
/// This class is a partition rather than a split: before the repair ours held
/// 42 蔔 and ZERO 卜, and the independently imported witness (git blob
/// 7a2dc43) holds 42 卜 and ZERO 蔔, agreeing verse for verse. Both directions
/// are pinned below — a revert fails the first three tests, and the last test
/// is what would catch a repair that ran the class the wrong way round.
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

  test('divination is written 卜, and the radish is absent entirely', () {
    expect(count('卜'), 42);
    expect(count('蔔'), 0);
  });

  test('no reading is left setting 蔔', () {
    const cues = <String>['占蔔', '蔔士', '別西蔔', '巴力西蔔', '巴蔔', '押蔔'];
    final offenders = <String>[];
    for (final v in verses) {
      final text = v['text'] as String;
      for (final cue in cues) {
        if (!text.contains(cue)) continue;
        offenders.add('${v['book']} ${v['chapter']}:${v['verse']} — $cue');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Re-run tools/repair_tr_divination_glyph.py.');
  });

  test('the verses a reader would notice read correctly', () {
    // KJV: "whereby indeed he divineth", "divination", "an observer of times",
    // "the diviners", "Baalzebub the god of Ekron", "Beelzebub".
    expect(textOf('創世紀', '44', '5'), contains('豈不是他占卜用的嗎'));
    expect(textOf('申命記', '18', '10'), contains('占卜的、觀兆的'));
    expect(textOf('以西結書', '13', '6'), contains('是謊詐的占卜'));
    expect(textOf('彌迦書', '3', '11'), contains('先知為銀錢行占卜'));
    expect(textOf('列王紀下', '1', '2'), contains('以革倫的神巴力西卜'));
    expect(textOf('馬太福音', '12', '24'), contains('鬼王別西卜'));
    // 蔔士 opened the clause, and the name transliterations are the positions a
    // divination-only rule would have missed.
    expect(textOf('撒迦利亞書', '10', '2'), contains('卜士所見的是虛假'));
    expect(textOf('以斯拉記', '2', '51'), contains('巴卜的子孫'));
    expect(textOf('尼希米記', '3', '16'), contains('押卜的兒子尼希米'));
  });

  test('占 was not dragged along — 佔/占 is a separate, still-open class', () {
    // 占 is correct in 占卜, so this instalment had to run before 佔/占 and had
    // to leave 占 alone. The witness has 30 佔 where ours writes 占; that is
    // the next instalment, not this one.
    expect(count('占'), 56);
    expect(count('佔'), 0);
  });

  test('the Simplified editions are untouched — 卜 is right for both there',
      () {
    // Simplified has one glyph for both meanings, so 42 卜 / 0 蔔 is already
    // correct in the Simplified verse asset and in the tagged Strong's corpus
    // (which is Simplified-only and never offered on the Traditional version).
    final simplified =
        (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
    final plain = simplified.map((v) => v['text'] as String).join();
    expect(plain.split('卜').length - 1, 42);
    expect(plain.contains('蔔'), isFalse);
  });

  test('the seven correct 蔔 in the sermon corpus are left alone', () {
    // "No 蔔 belongs in scripture" is true; "no 蔔 belongs in this repo" is
    // not. These are 蘿蔔 / 胡蘿蔔 — a radish in a preacher's illustration —
    // and a blanket 蔔→卜 sweep would print 蘿卜. That corpus came from a
    // phrase-aware converter without this defect, so it must not be swept.
    var radishes = 0;
    for (final f in Directory('assets/sermons/zh-TW').listSync()) {
      if (f is! File) continue;
      radishes += f.readAsStringSync().split('蘿蔔').length - 1;
    }
    expect(radishes, 7);
  });

  test('the independently translated NT agrees on 別西卜 and 占卜', () {
    // 梁家鏗's Traditional NT is not a conversion of anything in this repo, so
    // it is a second source for the eight Beelzebub positions and for 占卜
    // itself (使徒行傳 16:16 「有預卜吉凶之術…靠她占卜預言發了大財」).
    final raw = File('assets/biblexg-v2-tr.json').readAsStringSync();
    expect(raw.contains('蔔'), isFalse);
    expect(raw.split('別西卜').length - 1, 8);
    expect(raw.contains('占卜'), isTrue);
  });
}
