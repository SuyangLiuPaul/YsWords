import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fifteenth instalment of the converter-hole defect (see
/// traditional_classifier_test.dart for 隻 and the sibling files for 淨/牆/餘,
/// 髮, 鬍/鬚/採, 麵, 罈, 穀, 鬆, 干/乾, 卜, 恆, 凌 and 症). The converter never
/// once wrote 癒, so every healing in the Traditional Bible was spelt 痊愈 —
/// 約翰福音 5:6 「你要痊愈嗎？」, 馬可福音 5:34 「你的災病痊愈了」.
///
/// This one differs from its predecessors in two ways worth keeping.
///
/// First, the queue's inventory diff — characters the witness uses that our
/// asset holds ZERO of — did not find it. We hold 35 愈, so the pair never
/// appeared in the table. The hole is in the other direction: we hold zero 癒.
/// A merged Simplified pair only surfaces in an inventory diff when the
/// surviving form is the one we lack.
///
/// Second, the source form is a live Traditional character. 愈 is correct in
/// 愈來愈, 愈加, 愈發 and 每況愈下, so "the witness holds none of it" was not
/// sufficient on its own — a single comparative among the 35 would have made
/// this a split. All 35 are preceded by 痊 and the corpus has no comparative
/// reading at all, which is what the first two tests below pin.
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

  test('healing is written 癒, and the merged form is absent entirely', () {
    expect(count('癒'), 35);
    expect(count('愈'), 0);
  });

  test('no reading is left setting 痊愈', () {
    final offenders = <String>[];
    for (final v in verses) {
      if ((v['text'] as String).contains('痊愈')) {
        offenders.add('${v['book']} ${v['chapter']}:${v['verse']}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Re-run tools/repair_tr_recovery_glyph.py.');
  });

  test('the verses a reader would notice read correctly', () {
    expect(textOf('約翰福音', '5', '6'), contains('你要痊癒嗎'));
    expect(textOf('約翰福音', '5', '9'), contains('那人立刻痊癒'));
    expect(textOf('馬可福音', '5', '34'), contains('你的災病痊癒了'));
    expect(textOf('馬太福音', '9', '22'), contains('女人就痊癒了'));
    expect(textOf('利未記', '15', '13'), contains('患漏症的人痊癒了'));
    expect(textOf('耶利米書', '17', '14'), contains('我便痊癒'));
    expect(textOf('使徒行傳', '4', '10'), contains('得痊癒'));
  });

  test('愈 is not simply wrong — the comparative is its live reading', () {
    // The claim is about this corpus, not about the language. Had scripture
    // said 愈來愈 anywhere, the class would not move whole and a blind replace
    // would have printed 愈來癒. The repair tool refuses on any of these.
    for (final reading in ['愈來愈', '愈加', '愈發', '每況愈下']) {
      expect(blob.contains(reading), isFalse, reason: reading);
    }
    // And every position that did move was the healing, never the comparative.
    for (final v in verses) {
      final text = v['text'] as String;
      for (var i = 0; i < text.length; i++) {
        if (text[i] != '癒') continue;
        expect(i > 0 && text[i - 1] == '痊', isTrue,
            reason: '${v['book']} ${v['chapter']}:${v['verse']}');
      }
    }
  });

  test('the sermon corpus is not swept — it never had this hole', () {
    // Produced by a different, phrase-aware converter: it writes 痊癒/治癒/癒合
    // correctly, and its only 愈 is 每況愈下, which must survive. This test
    // exists so that a repo-wide sweep is a deliberate act, not a side effect.
    var comparative = 0;
    var healing = 0;
    for (final f in Directory('assets/sermons/zh-TW').listSync()) {
      if (f is! File) continue;
      final s = f.readAsStringSync();
      comparative += s.split('愈').length - 1;
      healing += s.split('癒').length - 1;
    }
    // 1 → 26 with the merge of 2026-09-06 (125 sermons in from the
    // fuyindiantai staging library, 51 bodies replaced). Every one of the
    // 25 new 愈 was read and every one is the comparative: 每況愈下 ×11
    // (and one deliberate inversion of it, 「每況愈上」), 愈來愈, 愈演愈烈
    // ×3, 愈發 ×5, 愈是, 愈顯, 「我愈默想就愈躊躇」. None is healing —
    // 癒 rose to 30 alongside it and carries 痊癒 / 治癒 / 癒合 as before,
    // so the two senses are still distinguished rather than merged.
    expect(comparative, 26);
    expect(healing, 30);
    expect(File('assets/sermons/zh-TW/CP18.txt').readAsStringSync(),
        contains('每況愈下'));
  });

  test('misconceptions keeps its Traditional comparative', () {
    // 強者愈強、弱者愈弱 is correct zh-Hant and sits in a shipped asset. Pinned
    // because it is the nearest thing in the repo to a false positive.
    expect(File('assets/misconceptions.json').readAsStringSync(),
        contains('強者愈強'));
  });

  test('the Simplified edition still writes the merged form', () {
    // Mainland standard merged 癒 onto 愈, so the Simplified asset is correct
    // as it stands and nothing outside the Traditional verse asset moved.
    final simplified =
        (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
    final plain = simplified.map((v) => v['text'] as String).join();
    expect(plain.split('痊愈').length - 1, 35);
    expect(plain.contains('癒'), isFalse);
  });

  test('梁家鏗\'s independent Traditional NT agrees on 痊癒', () {
    // A separately produced translation, not a conversion of ours. It writes
    // 痊癒 in all 26 of its healings. Its remaining 治愈/愈合 are its own
    // wording and are queued separately rather than normalised here.
    final s = File('assets/biblexg-v2-tr.json').readAsStringSync();
    expect(s.contains('痊愈'), isFalse);
    expect(s.split('痊癒').length - 1, greaterThan(0));
  });
}
