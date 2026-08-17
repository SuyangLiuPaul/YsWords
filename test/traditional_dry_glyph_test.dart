import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ninth instalment of the converter-hole defect (see
/// traditional_classifier_test.dart for 隻, traditional_leftover_glyphs_test
/// .dart for 淨/牆/餘, traditional_hair_glyph_test.dart for 髮,
/// traditional_beard_glyph_test.dart for 鬍/鬚/採, traditional_flour_glyph_test
/// .dart for 麵, traditional_jar_glyph_test.dart for 罈,
/// traditional_grain_glyph_test.dart for 穀 and
/// traditional_loosen_glyph_test.dart for 鬆).
///
/// Simplified 干 collapses THREE Traditional characters — 干 (to offend, to
/// concern, and a name syllable), 乾 (dry) and 幹 (trunk, ability) — and the
/// converter had only two branches: it wrote 319 幹 and 22 乾 and never once
/// wrote 干. So 「我就幹淨」, 「海就成了幹地」, 「我的精力枯幹」, 「幹犯雅偉」 and
/// 「迦米的兒子亞幹」 all printed a tree trunk.
///
/// Both directions are pinned. A revert fails the first four tests; a blanket
/// 幹→乾 or 幹→干 substitution fails 'the trunk, the shaft and the ability
/// still read 幹'.
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

  test('the three forms stand in the numbers the witness has', () {
    // Witness 7a2dc43 (the plain 和合本 Traditional dropped at v1.4.5) holds
    // 111 + 221 + 9; the pre-fix file held 0 + 22 + 319. The totals agreeing
    // at 341 is an accident — the two edition differences cancel — so it is
    // pinned as a conservation check, not offered as corroboration.
    expect(count('干'), 111);
    expect(count('乾'), 221);
    expect(count('幹'), 9);
    expect(count('干') + count('乾') + count('幹'), 341);
  });

  test('nothing that can only be dryness is left setting 幹', () {
    const cues = <String>[
      '枯幹', '幹淨', '幹涸', '幹渴', '幹地', '幹草', '幹糧', '幹燥',
      '幹癟', '幹瘦', '幹裂', '幹焦', '幹熱', '幹柴', '幹餅', '幹竭',
      '擦幹', '喝幹', '燒幹', '葡萄幹',
    ];
    final offenders = <String>[];
    for (final v in verses) {
      final text = v['text'] as String;
      for (final cue in cues) {
        if (!text.contains(cue)) continue;
        offenders.add('${v['book']} ${v['chapter']}:${v['verse']} — $cue');
      }
    }
    expect(offenders, isEmpty, reason: 'Re-run tools/repair_tr_dry_glyph.py.');
  });

  test('nothing that can only be offence or a name is left setting 幹', () {
    const cues = <String>[
      '幹犯', '何幹', '無幹', '相幹', '幹戈', '若幹', '幹預', '幹休',
      '亞幹', '幹寧', '米母幹', '亞多尼幹', '亞斯利幹', '幹大基',
    ];
    final offenders = <String>[];
    for (final v in verses) {
      final text = v['text'] as String;
      for (final cue in cues) {
        if (!text.contains(cue)) continue;
        offenders.add('${v['book']} ${v['chapter']}:${v['verse']} — $cue');
      }
    }
    expect(offenders, isEmpty, reason: 'Re-run tools/repair_tr_dry_glyph.py.');
  });

  test('the verses a reader would notice read correctly', () {
    expect(textOf('詩篇', '51', '7'), contains('潔淨我，我就乾淨'));
    expect(textOf('出埃及記', '14', '21'), contains('海就成了乾地'));
    expect(textOf('詩篇', '22', '15'), contains('我的精力枯乾'));
    expect(textOf('以西結書', '37', '4'), contains('枯乾的骸骨啊'));
    expect(textOf('馬太福音', '12', '10'), contains('枯乾了一隻手'));
    expect(textOf('約翰福音', '13', '10'), contains('全身就乾淨了'));
    expect(textOf('民數記', '5', '6'), contains('以至干犯雅偉'));
    expect(textOf('約書亞記', '7', '1'), contains('迦米的兒子亞干'));
    expect(textOf('約書亞記', '15', '34'), contains('隱干寧'));
  });

  test('the trunk, the shaft and the ability still read 幹', () {
    // The nine positions the witness keeps. A blanket substitution in either
    // direction breaks all of them, which is the whole point of pinning them:
    // 幹 is a real Traditional character and is correct here.
    expect(textOf('出埃及記', '25', '31'), contains('燈臺的座和幹與杯'));
    expect(textOf('出埃及記', '37', '17'), contains('這燈臺的座和幹'));
    expect(textOf('約伯記', '14', '8'), contains('幹也死在土中'));
    expect(textOf('馬太福音', '25', '15'), contains('按著各人的才幹'));
    expect(count('枝幹'), 5);
  });

  test('the two verses that hold more than one reading are split correctly',
      () {
    // These are the offsetting-pair traps: a false convert at one position
    // plus a miss at the other would balance the per-verse count and pass a
    // count-only check. The repair compares the ordered SEQUENCE against the
    // witness, not the count, which is what makes them impossible.
    expect(textOf('以西結書', '19', '12'),
        contains('東風吹乾其上的果子，堅固的枝幹折斷枯乾'));
    expect(textOf('使徒行傳', '18', '6'),
        contains('與我無干<note: 原文是我卻乾淨>'));
  });

  test('Candace is spelled 干大基, on evidence other than the witness', () {
    // The one position the witness cannot settle: it transliterates the whole
    // clause differently (衣索匹亞女王甘大基). Settled by the 新譯本 Traditional
    // (git blob 57c4686) and by 梁家鏗's independent Traditional NT, which both
    // write 干大基 — as does our own Simplified asset.
    expect(textOf('使徒行傳', '8', '27'), contains('埃提阿伯女王干大基'));
    expect(File('assets/biblexg-v2-tr.json').readAsStringSync(),
        contains('干大基'));
  });

  test('the 梁家鏗 Traditional NT has no such hole', () {
    // Counted over the raw file, notes included, so a later import cannot
    // reintroduce it unnoticed. Its 幹 are the colloquial verb, 由樹幹底部 and
    // 才幹 at 林前 12:28; its 干 are 相干, 干大基 and 干犯.
    final raw = File('assets/biblexg-v2-tr.json').readAsStringSync();
    int n(String s) => raw.split(s).length - 1;
    expect(n('幹'), 33);
    expect(n('乾'), 22);
    expect(n('干'), 3);
  });

  test('the Simplified editions are untouched — 干 is right for all three', () {
    final simplified =
        (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
    final plain = simplified.map((v) => v['text'] as String).join();
    expect(plain.split('干').length - 1, 341);
    expect(plain.contains('幹'), isFalse);
    expect(plain.contains('乾'), isFalse);
  });
}
