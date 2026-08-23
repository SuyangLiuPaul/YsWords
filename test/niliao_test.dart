import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two verses read 意料 where the printed 1919 和合本 reads 逆料 — and one
/// verse reads 銷滅 where a frequency argument would wrongly "correct" it.
///
/// Both belong to a class no audit in this repo can see. `audit_dropped_
/// characters.py` and `audit_tagged_running_text.py` report only text a
/// witness has and we do not, because that is the direction that can mean a
/// LOSS. A SUBSTITUTION of the same length drops nothing, so nothing fires:
/// 「我們不能意料可畏的事」 is grammatical, plausible, and not what the
/// edition says.
///
/// 以賽亞書 64:3 and 使徒行傳 25:18 were settled 4 lines to 1 — the print,
/// both external witnesses, AND our own tagged corpus all read 逆料, so the
/// word-tap sheet has been printing 逆料 over a verse reading 意料. Ten other
/// differences found in the same pass are NOT here: there our reading text and
/// our tagged corpus agree against the print and both witnesses, 2 to 3, and
/// they are queued for the user rather than guessed at.
///
/// 帖撒羅尼迦前書 5:19 is the opposite case and the reason this file also pins
/// a NON-change. 銷滅 occurs in exactly one verse of 31,102 against 43 reading
/// 消滅, and this repo has used "a hapax at a flagged verse is contamination"
/// as an argument elsewhere. Here that argument gives the wrong answer: the
/// print reads 銷滅, our tagged corpus reads 銷滅, and it is the two external
/// witnesses that modernised it.
///
/// `tools/repair_niliao.py` applies the change and refuses on drift.
void main() {
  Map<String, String> load(String path) => {
        for (final v in (json.decode(File(path).readAsStringSync()) as List)
            .cast<Map<String, dynamic>>())
          v['id'] as String: v['text'] as String,
      };

  late Map<String, String> zhHans;
  late Map<String, String> zhHant;

  setUpAll(() {
    zhHans = load('assets/cuvs-yhwh.json');
    zhHant = load('assets/cuvs-yhwh-tr.json');
  });

  test('以賽亞書 64:3 and 使徒行傳 25:18 read 逆料', () {
    expect(zhHant['023064003'], contains('不能逆料可畏的事'));
    expect(zhHans['023064003'], contains('不能逆料可畏的事'));
    expect(zhHant['044025018'], contains('我所逆料的那等惡事'));
    expect(zhHans['044025018'], contains('我所逆料的那等恶事'));
  });

  test('意料 appears nowhere in either edition of the Bible text', () {
    // Counted rather than asserted: before the repair this was 2 and 0, and
    // there is no third verse anywhere in which the two spellings compete.
    // Scoped to scripture on purpose — the sermon transcripts and 梁家鏗's
    // translation use 意料 correctly, so a blanket sweep would damage them.
    for (final edition in {'simplified': zhHans, 'traditional': zhHant}.entries) {
      final wrong = edition.value.entries
          .where((e) => e.value.contains('意料'))
          .map((e) => e.key)
          .toList();
      expect(wrong, isEmpty, reason: '${edition.key} re-modernised 逆料: $wrong');
    }
  });

  test('the running text agrees with the tagged corpus it contradicted', () {
    // The tagged corpus is what settled these, and the sheet renders ITS runs
    // instead of the verse — so if the two drift apart again the app shows one
    // word on the verse and another under the reader's finger.
    for (final source in {
      'assets/tagged/cuvs-yhwh/isaiah.json': '64:3',
      'assets/tagged/cuvs-yhwh/acts.json': '25:18',
    }.entries) {
      final book =
          json.decode(File(source.key).readAsStringSync()) as Map<String, dynamic>;
      final runs = (book[source.value] as List).cast<Map<String, dynamic>>();
      final text = runs.map((r) => r['w'] as String).join();
      expect(text, contains('逆料'), reason: source.key);
    }
  });

  test('帖撒羅尼迦前書 5:19 keeps 銷滅 — a hapax that is CORRECT', () {
    // 1 occurrence against 43 of 消滅, and the print reads 銷滅. Any future
    // sweep that normalises rare spellings towards common ones fails here,
    // which is the entire point of pinning it.
    expect(zhHant['052005019'], '不要銷滅聖靈的感動；');
    expect(zhHans['052005019'], '不要销灭圣灵的感动；');

    final thess = json.decode(
            File('assets/tagged/cuvs-yhwh/1_thessalonians.json').readAsStringSync())
        as Map<String, dynamic>;
    final runs = (thess['5:19'] as List).cast<Map<String, dynamic>>();
    expect(runs.map((r) => r['w'] as String).join(), contains('销灭'));
  });
}
