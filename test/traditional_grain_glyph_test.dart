import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Seventh instalment of the converter-hole defect (see
/// traditional_classifier_test.dart for 隻, traditional_leftover_glyphs_test
/// .dart for 淨/牆/餘, traditional_hair_glyph_test.dart for 髮,
/// traditional_beard_glyph_test.dart for 鬍/鬚/採, traditional_flour_glyph_test
/// .dart for 麵 and traditional_jar_glyph_test.dart for 罈). Simplified 谷
/// collapses two Traditional characters — 谷 (a valley) and 穀 (grain) — and the
/// converter resolved every one of them to the valley, so the harvest read as
/// terrain: 「牛在場上踹谷的時候」, 「地生五谷是出於自然的」.
///
/// Like 髮, 麵 and 罈, and unlike 淨/牆/餘, this could not be fixed by
/// substitution: 谷 is CORRECT 176 times here and wrong 68 times. Both
/// directions are pinned below — a blanket substitution fails the third test, a
/// revert fails the first two and the fourth.
///
/// The fifth test guards a different defect found by the same arithmetic:
/// 以賽亞書 36:17 read 「五殼」 (husk) in both editions, an e-text corruption
/// older than this repo, against the parallel 列王紀下 18:32 and KJV "a land of
/// corn and wine".
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

  test('grain is written 穀, in the number the witness has', () {
    expect(count('穀'), 68);
    expect(count('谷'), 177);
  });

  test('no reading that can only be grain is left setting 谷', () {
    const cues = <String>[
      '五谷',
      '谷種',
      '谷場',
      '谷堆',
      '谷穗',
      '谷實',
      '踹谷',
      '百谷',
      '炒谷',
      '烘的谷',
      '別樣的谷',
      '篩谷',
      '谷、新酒',
      '谷新酒',
      '谷豐登',
      '谷健壯',
      '谷既熟',
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
        reason: 'Re-run tools/repair_tr_grain_glyph.py.');
  });

  test('valleys and the names built on 谷 still read 谷', () {
    // A blanket 谷→穀 substitution would break every one of these. The last
    // three are the trap: they carry no valley in their English at all — 亞谷
    // is Akkub, 谷歌大 is Gudgodah, 哈巴谷 is Habakkuk.
    expect(textOf('約書亞記', '15', '8'), contains('欣嫩子谷'));
    expect(textOf('撒母耳記上', '17', '2'), contains('以拉谷'));
    expect(textOf('詩篇', '23', '4'), contains('死蔭的幽谷'));
    expect(textOf('約書亞記', '7', '24'), contains('亞割谷'));
    expect(textOf('尼希米記', '11', '19'), contains('亞谷'));
    expect(textOf('申命記', '10', '7'), contains('谷歌大'));
    expect(textOf('哈巴谷書', '1', '1'), contains('哈巴谷'));
  });

  test('the verses a reader would notice read correctly', () {
    // KJV: "plenty of corn and wine", "treadeth out the corn", "an homer of
    // seed", "the earth bringeth forth fruit of herself".
    expect(textOf('創世紀', '27', '28'), contains('並許多五穀新酒'));
    expect(textOf('申命記', '25', '4'), contains('牛在場上踹穀的時候'));
    expect(textOf('哥林多前書', '9', '9'), contains('牛在場上踹穀的時候'));
    expect(textOf('以賽亞書', '5', '10'), contains('一賀梅珥穀種只結一伊法'));
    expect(textOf('何西阿書', '9', '1'), contains('在各穀場上'));
    expect(textOf('馬可福音', '4', '28'), contains('地生五穀是出於自然的'));
    // The one verse in the corpus holding both readings: a valley that grows a
    // harvest. Per-verse counts alone cannot tell a false convert here from a
    // missed one, so it is pinned in full.
    expect(textOf('詩篇', '65', '13'), contains('谷中也長滿了五穀'));
  });

  test('以賽亞書 36:17 promises grain, not husks, in both editions', () {
    expect(blob.contains('殼'), isFalse);
    expect(textOf('以賽亞書', '36', '17'), contains('有五穀和新酒之地'));
    final simplified =
        (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
    final verse = simplified.firstWhere((v) => v['id'] == '023036017');
    expect(verse['text'] as String, contains('有五谷和新酒之地'));
    expect(simplified.any((v) => (v['text'] as String).contains('壳')), isFalse);

    // The Originals sheet prints the tagged runs INSTEAD of the verse, so the
    // husk had to be repaired there too. The run is tagged H1715 (דָּגָן,
    // "properly, increase, i.e. grain"), which is the tagging saying so itself.
    final tagged = json.decode(
        File('assets/tagged/cuvs-yhwh/isaiah.json').readAsStringSync()) as Map;
    final runs = (tagged['36:17'] as List).cast<Map<String, dynamic>>();
    final line = runs.map((r) => r['w'] as String).join();
    expect(line, contains('就是有五谷'));
    expect(runs.firstWhere((r) => (r['w'] as String).contains('五谷'))['s'],
        'H1715');
  });
}
