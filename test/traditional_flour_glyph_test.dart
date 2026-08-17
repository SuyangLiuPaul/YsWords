import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fifth instalment of the converter-hole defect (see
/// traditional_classifier_test.dart for 隻, traditional_leftover_glyphs_test
/// .dart for 淨/牆/餘, traditional_hair_glyph_test.dart for 髮 and
/// traditional_beard_glyph_test.dart for 鬍/鬚/採). Simplified 面 collapses two
/// Traditional characters — 面 (face, surface, side) and 麵 (flour, dough) — and
/// the converter resolved every one of them to 面, so the grain offering read
/// 「一伊法細面」, an ephah of *face*.
///
/// Like 髮 and unlike 淨/牆/餘 this could not be fixed by substitution: 面 is
/// CORRECT 2,077 times here and wrong 107 times. Each of the 107 was decided
/// against the witness edition (git blob `7a2dc43`) rather than against a rule,
/// so both directions are pinned below — a blanket substitution fails the
/// second test, a revert fails the first and third.
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

  test('flour is written 麵, in the number the witness has', () {
    expect(count('麵'), 107);
    expect(count('面'), 2077);
  });

  test('no collocation that can only be flour is left reading 面', () {
    const cues = <String>[
      '細面', '麥面', '磨面', '粗面', '新面', '面酵', '面餅', '面伊法',
      '摶面', '面摶', '把面', '面撒', '點面來', '剩下的面', '壇內的面',
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
        reason: 'Re-run tools/repair_tr_flour_glyph.py.');
  });

  test('face, surface and side still read 面', () {
    // A blanket 面→麵 substitution would break every one of these.
    expect(textOf('創世紀', '1', '2'), contains('淵面黑暗；神的靈運行在水面上'));
    expect(textOf('出埃及記', '33', '20'), contains('你不能看見我的面'));
    expect(textOf('民數記', '6', '25'), contains('願雅偉使他的臉光照你'));
    expect(textOf('詩篇', '27', '8'), contains('你們當尋求我的面'));
    expect(textOf('馬太福音', '17', '2'), contains('臉面明亮如日頭'));
    expect(count('面前'), greaterThan(500));
  });

  test('the verses a reader would notice read correctly', () {
    expect(textOf('利未記', '2', '1'), contains('要用細麵澆上油'));
    expect(textOf('利未記', '24', '5'), contains('每餅用麵伊法十分之二'));
    expect(textOf('民數記', '7', '13'), contains('調油的細麵作素祭'));
    expect(textOf('創世紀', '18', '6'), contains('三細亞細麵'));
    expect(textOf('出埃及記', '8', '3'), contains('摶麵盆'));
    expect(textOf('申命記', '28', '5'), contains('你的筐子和你的摶麵盆都必蒙福'));
    expect(textOf('列王紀上', '17', '12'), contains('壇內只有一把麵'));
    expect(textOf('列王紀上', '4', '22'), contains('細麵三十歌珥，粗麵六十歌珥'));
    expect(textOf('以賽亞書', '47', '2'), contains('要用磨磨麵'));
    expect(textOf('馬太福音', '13', '33'), contains('天國好像麵酵'));
    expect(textOf('加拉太書', '5', '9'), contains('一點麵酵能使全團都發起來'));
    expect(textOf('羅馬書', '11', '16'), contains('所獻的新麵若是聖潔'));
  });
}
