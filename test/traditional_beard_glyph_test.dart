import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fourth instalment of the converter-hole defect (see
/// traditional_classifier_test.dart for 隻, traditional_leftover_glyphs_test.dart
/// for 淨/牆/餘 and traditional_hair_glyph_test.dart for 髮). The converter that
/// produced `assets/cuvs-yhwh-tr.json` never once wrote 鬍, 鬚 or 採, so the
/// beard was spelt 胡須 all through 利未記 13-14, 撒母耳記下 10 and 以賽亞書 50
/// — 胡 is 胡亂/胡言 and a surname, 須 is 必須, and neither is hair.
///
/// 采→採 is a clean partition, but 胡 and 須 are not: 7 胡 (基列胡瑣, 伊胡得,
/// 胡巴, 胡言亂語) and 86 須 (必須, 須要) are correct and must not move. Both
/// sides are pinned below, so neither a blanket substitution nor a revert can
/// pass. 撒母耳記上 21:13 carries one of each in the same verse.
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

  test('the beard is written 鬍鬚, in the numbers the witness has', () {
    expect(count('鬍'), 21);
    expect(count('胡'), 7);
    expect(count('鬚'), 20);
    expect(count('須'), 86);
    expect(count('採'), 3);
    expect(count('采'), 0);
  });

  test('no collocation that can only be a beard is left half-converted', () {
    const cues = <String>[
      '胡須', '鬍須', '胡鬚', '胡子', '剃胡', '拔胡', '刮胡', '剪胡',
      '髮和胡', '鬚和胡', '須髮',
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
        reason: 'Re-run tools/repair_tr_beard_glyph.py.');
  });

  test('every surviving 須 is the modal, never hair', () {
    final offenders = <String>[];
    for (final v in verses) {
      final text = v['text'] as String;
      var i = text.indexOf('須');
      while (i >= 0) {
        final before = i == 0 ? '' : text[i - 1];
        final after = i + 1 < text.length ? text[i + 1] : '';
        if (before != '必' && after != '要' && !'聽側宰攔放'.contains(after)) {
          offenders.add('${v['book']} ${v['chapter']}:${v['verse']} — '
              '${text.substring((i - 3).clamp(0, text.length), i + 3)}');
        }
        i = text.indexOf('須', i + 1);
      }
    }
    expect(offenders, isEmpty);
  });

  test('the 7 genuine 胡 are untouched', () {
    expect(textOf('民數記', '22', '39'), contains('基列胡瑣'));
    expect(textOf('約書亞記', '19', '45'), contains('伊胡得'));
    expect(textOf('歷代志上', '24', '13'), contains('第十三是胡巴'));
    expect(textOf('撒母耳記上', '18', '10'), contains('在家中胡言亂語'));
    expect(textOf('路加福音', '24', '11'), contains('使徒以為是胡言'));
    expect(textOf('使徒行傳', '17', '18'), contains('這胡言亂語的'));

    // One verse, both readings — the reason this could not be decided a verse
    // at a time.
    final samuel = textOf('撒母耳記上', '21', '13');
    expect(samuel, contains('門扇上胡寫亂畫'));
    expect(samuel, contains('唾沫流在鬍子上'));
  });

  test('the verses a reader would notice read correctly', () {
    expect(textOf('利未記', '13', '29'), contains('男人鬍鬚上有災病'));
    expect(textOf('利未記', '14', '9'), contains('頭髮與鬍鬚'));
    expect(textOf('利未記', '19', '27'), contains('鬍鬚的周圍也不可'));
    expect(textOf('利未記', '21', '5'), contains('不可剃除鬍鬚的周圍'));
    expect(textOf('撒母耳記下', '10', '4'), contains('臣僕的鬍鬚剃去一半'));
    expect(textOf('撒母耳記下', '20', '9'), contains('抓住亞瑪撒的鬍子'));
    expect(textOf('以斯拉記', '9', '3'), contains('拔了頭髮和鬍鬚'));
    expect(textOf('詩篇', '133', '2'), contains('流到鬍鬚'));
    expect(textOf('以賽亞書', '50', '6'), contains('人拔我腮頰的鬍鬚'));
    expect(textOf('以西結書', '5', '1'), contains('用天平將鬚髮平分'));
    expect(textOf('利未記', '13', '33'), contains('剃去鬚髮'));

    expect(textOf('約伯記', '30', '4'), contains('草叢之中採鹹草'));
    expect(textOf('雅歌', '5', '1'), contains('採了我的沒藥'));
    expect(textOf('雅歌', '6', '2'), contains('採百合花'));

    // The modal, untouched.
    expect(textOf('約翰福音', '3', '7'), contains('你們必須重生'));
  });
}
