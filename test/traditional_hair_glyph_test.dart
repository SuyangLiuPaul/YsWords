import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Third instalment of the converter-hole defect (see
/// traditional_classifier_test.dart for 隻 and traditional_leftover_glyphs_test
/// .dart for 淨/牆/餘). Simplified 发 collapses two Traditional characters —
/// 發 (issue, send, break out) and 髮 (hair) — and the converter resolved every
/// one of them to 發, so the Bible read 「你們的頭發也都被數過了」 and
/// 「白發是榮耀的冠冕」.
///
/// This one could not be fixed by substitution: 發 is CORRECT 1,287 times here
/// and wrong 88 times. Each of the 88 was decided against the witness edition
/// (git blob `7a2dc43`) rather than against a rule, because the obvious rule is
/// wrong — 詩篇 6:2 「我的骨頭發戰」 and 羅馬書 7:8 「在我裏頭發動」 contain the
/// string 頭發 and are the verb. Both are pinned below, so a future blanket
/// substitution cannot pass.
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

  test('hair is written 髮, in the number the witness has', () {
    expect(count('髮'), 88);
    expect(count('發'), 1287);
  });

  test('no collocation that can only be hair is left reading 發', () {
    // Every one of these is 髮 in any Traditional edition. 頭發 is checked
    // separately below because it has two genuine verb readings.
    const cues = <String>[
      '白發', '鬚發', '剃發', '剪發', '散發', '編發', '毫發', '美發',
      '發綹', '發辮', '發網', '發蒼', '發斑', '毛發', '發頂', '發厚',
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
        reason: 'Re-run tools/repair_tr_hair_glyph.py.');
  });

  test('頭發 survives only where it is the verb', () {
    final offenders = <String>[];
    for (final v in verses) {
      final text = v['text'] as String;
      var i = text.indexOf('頭發');
      while (i >= 0) {
        final window = text.substring((i - 2).clamp(0, text.length), i + 2);
        if (!window.contains('骨頭發') && !window.contains('裏頭發')) {
          offenders.add('${v['book']} ${v['chapter']}:${v['verse']}');
        }
        i = text.indexOf('頭發', i + 1);
      }
    }
    expect(offenders, isEmpty);

    // The two traps, which a cue-driven repair would have broken.
    expect(textOf('詩篇', '6', '2'), contains('我的骨頭發戰'));
    expect(textOf('羅馬書', '7', '8'), contains('在我裏頭發動'));
  });

  test('the verses a reader would notice read correctly', () {
    expect(textOf('馬太福音', '10', '30'), contains('你們的頭髮也都被數過了'));
    expect(textOf('箴言', '16', '31'), contains('白髮是榮耀的冠冕'));
    expect(textOf('士師記', '16', '17'), contains('剃了我的頭髮'));
    expect(textOf('民數記', '6', '5'), contains('髮綹'));
    expect(textOf('雅歌', '4', '1'), contains('你的頭髮如同山羊群'));
    expect(textOf('但以理書', '7', '9'), contains('頭髮如純淨的羊毛'));
    expect(textOf('以賽亞書', '3', '18'), contains('髮網'));
    expect(textOf('士師記', '20', '16'), contains('毫髮不差'));
    expect(textOf('利未記', '13', '45'), contains('蓬頭散髮'));
    expect(textOf('啟示錄', '9', '8'), contains('頭髮像女人的頭髮'));

    // The verb, in verses that sit right next to the hair ones.
    expect(textOf('約翰福音', '4', '35'), contains('發白'));
    expect(textOf('創世紀', '4', '5'), contains('大大的發怒'));
  });
}
