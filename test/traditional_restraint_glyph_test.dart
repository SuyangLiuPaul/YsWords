import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Twentieth instalment of the converter-hole defect, and the first of the
/// one-to-many SPLITS after the exact partitions (隻, 恆, 卜, 淩, 症, 癒) were
/// cleared.
///
/// Simplified merged 製 onto 制, and the map that produced
/// `assets/cuvs-yhwh-tr.json` expanded it back unconditionally: before the
/// repair the file held 157 製 and ZERO 制, so a Traditional Bible printed
/// 加拉太書 5:23 「節製」, 創世紀 4:7 「你卻要製伏它」, 出埃及記 1:11 「轄製」
/// and 彼得前書 2:13 「人的一切製度」. None of those is a word in any script.
///
/// Unlike 恆 or 卜 this is a SPLIT, not a partition — 製 is correct at 67
/// positions (62 製造 + 5 製作) — so the tests below pin both sides. The claim
/// is never "製 is wrong" but "these 90 positions are 制", each decided against
/// the witness (git blob 7a2dc43, 90 制 / 67 製) position by position.
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

  test('the split matches the witness on both sides', () {
    // 90 制 + 67 製 = the 157 the converter wrote as 製. A revert fails here.
    expect(count('制'), 90);
    expect(count('製'), 67);
  });

  test('no restraint reading is left setting 製', () {
    const cues = <String>[
      '轄製', '製伏', '節製', '壓製', '克製', '剋製', '挾製', '製度', '按製子',
      '製服', '抑製', '限製', '控製',
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
        reason: 'Re-run tools/repair_tr_restraint_glyph.py.');
  });

  test('the manufacturing side is untouched — 製 is right at all 67', () {
    // The half a blanket 制 sweep in the other direction would destroy.
    expect(count('製造'), 62);
    expect(count('製作'), 5);
    expect(count('制造'), 0);
    expect(count('制作'), 0);
  });

  test('the verses a reader would notice read correctly', () {
    expect(textOf('加拉太書', '5', '23'), startsWith('溫柔、節制。'));
    expect(textOf('創世紀', '4', '7'), contains('你卻要制伏它'));
    expect(textOf('彼得後書', '1', '6'), contains('加上節制；有了節制'));
    expect(textOf('哥林多前書', '9', '25'), contains('諸事都有節制'));
    expect(textOf('加拉太書', '5', '1'), contains('奴僕的軛挾制'));
    expect(textOf('彼得前書', '2', '13'), contains('人的一切制度'));
    expect(textOf('出埃及記', '1', '11'), contains('派督工的轄制他們'));
    expect(textOf('民數記', '21', '9'), contains('摩西便製造一條銅蛇'));
  });

  test('the positions a 製造/製作 cue rule would still have got right, and '
      'the two it would not', () {
    // 按制子 (rationed measure) is the only reading in the class that is
    // neither a compound a rule would list nor adjacent to one. Both witnesses
    // read 制 here; nothing about it looks like restraint at a glance.
    expect(textOf('以西結書', '4', '11'), contains('喝水也要按制子'));
    expect(textOf('以西結書', '4', '16'), contains('喝水也要按制子'));
  });

  test('the Simplified editions are untouched — 制 is right for both there',
      () {
    // Simplified has one glyph for both senses, so 157 制 / 0 製 is already
    // correct in the Simplified verse asset. This is what would catch a repair
    // that swept the whole repo rather than the Traditional asset.
    final simplified =
        (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
    final plain = simplified.map((v) => v['text'] as String).join();
    expect(plain.split('制').length - 1, 157);
    expect(plain.contains('製'), isFalse);
  });

  test('the Strong\'s lexicon already distinguishes the pair and is not swept',
      () {
    // Its zh-TW fields write 製造/製作/銅製的 against 節制/限制/抑制/轄制, so
    // `assets/strongs/*.json` were NOT produced by the map that broke the verse
    // asset. Pinned so a later lexicon instalment does not assume otherwise.
    final greek = File('assets/strongs/greek.json').readAsStringSync();
    expect(greek.contains('節制'), isTrue);
    expect(greek.contains('節製'), isFalse);
    expect(greek.contains('製造'), isTrue);
  });

  test('the independently translated NT agrees on 節制', () {
    // 梁家鏗's Traditional NT is not a conversion of anything in this repo, so
    // it is a second line: it writes 制 for restraint and 製 for manufacture.
    final raw = File('assets/biblexg-v2-tr.json').readAsStringSync();
    expect(raw.contains('節制'), isTrue);
    expect(raw.contains('節製'), isFalse);
    expect(raw.contains('製作'), isTrue);
  });
}
