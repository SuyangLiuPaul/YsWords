import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two verses printed a word twice. 傳道書 7:1 read
/// 「名譽強如美好**的的**膏油」 and 歷代志上 15:3 read
/// 「大衛招聚以色列**眾人眾人**到耶路撒冷」 — in both the Simplified and the
/// Traditional file, with nothing to mark it.
///
/// They read as ordinary Chinese at a glance, which is why nothing in this
/// repo had ever caught them: every structural check asks whether a verse
/// exists, not whether it says a word twice.
///
/// **The two were found by different checks, and neither could see the
/// other's verse — that is the part worth keeping.**
///
/// 傳道書 7:1 came from `tools/audit_inserted_characters.py`, the first check
/// here that looks for text we ADD rather than lose.
///
/// 歷代志上 15:3 is invisible to that audit, because it only fires when BOTH
/// external witnesses disagree with us and witness A reads 眾人眾人 as well —
/// we share an ancestor with it. It was caught by a third witness internal to
/// this repo: `assets/tagged/cuvs-yhwh/1_chronicles.json` holds one run
/// {"w": "以色列众人", "s": "H3605"}, and the Hebrew ויקהל דויד את־כל־ישראל
/// says "all Israel" once.
///
/// `tools/repair_duplicated_particle.py` applies it. Both readings below fail
/// on the pre-fix data.
void main() {
  const simplified = 'assets/cuvs-yhwh.json';
  const traditional = 'assets/cuvs-yhwh-tr.json';
  const tagged = 'assets/tagged/cuvs-yhwh/ecclesiastes.json';

  Map<String, String> load(String path) => {
        for (final v in (json.decode(File(path).readAsStringSync()) as List)
            .cast<Map<String, dynamic>>())
          v['id'] as String: v['text'] as String,
      };

  late Map<String, String> zhHans;
  late Map<String, String> zhHant;

  setUpAll(() {
    zhHans = load(simplified);
    zhHant = load(traditional);
  });

  test('傳道書 7:1 writes the particle once', () {
    expect(zhHans['021007001'], '名誉强如美好的膏油；人死的日子胜过人生的日子。');
    expect(zhHant['021007001'], '名譽強如美好的膏油；人死的日子勝過人生的日子。');
  });

  test('歷代志上 15:3 gathers all Israel once', () {
    expect(zhHans['013015003'], contains('招聚以色列众人到耶路撒冷'));
    expect(zhHant['013015003'], contains('招聚以色列眾人到耶路撒冷'));
    expect(zhHans['013015003'], isNot(contains('众人众人')));
    expect(zhHant['013015003'], isNot(contains('眾人眾人')));
  });

  test('the word-tap corpus reads the same as the running text', () {
    // The tagged corpus renders its own copy of the verse on the word-tap
    // sheet, so a repair applied only to the running text would leave 的的 on
    // screen there. Concatenating the runs must reproduce the verse exactly.
    final book = json.decode(File(tagged).readAsStringSync()) as Map<String, dynamic>;
    final runs = (book['7:1'] as List).cast<Map<String, dynamic>>();
    expect(runs.map((r) => r['w']).join(), zhHans['021007001']);
  });

  test('the particle stayed with 美好的, and the Strong\'s numbers survived', () {
    // Which run loses the 的 is house style, and the aggregate does not settle
    // it: the corpus puts 的 at the head of the next run 20,060 times and at
    // the tail of the previous one 11,649, and 以賽亞書 runs the other way.
    // The token does settle it — of the 14 places the corpus splits a run at
    // 美好, 12 keep 美好的 together, including 傳道書 4:9 in this same book on
    // the same lemma H2896.
    final book = json.decode(File(tagged).readAsStringSync()) as Map<String, dynamic>;
    final runs = (book['7:1'] as List).cast<Map<String, dynamic>>();
    final good = runs.firstWhere((r) => r['w'] == '美好的');
    final oil = runs.firstWhere((r) => r['w'] == '膏油；');
    expect(good['s'], 'H2896');
    expect(oil['s'], 'H8081');
  });

  test('no verse repeats a whole word, and no particle is doubled', () {
    // The corpus was measured rather than spot-checked, in both shapes the
    // two defects took.
    //
    // A doubled grammatical particle has no reading at all in Chinese, so any
    // hit is a defect — before the repair there was exactly one, 的的.
    //
    // A doubled multi-character word usually IS a reading: 48 distinct
    // sequences repeat legitimately across the two editions, either
    // distributive (一個一個, 一排一排, 兩個兩個) or emphatic verb doubling
    // (如此如此, 察看察看, 毀壞毀壞). They are listed below because each was
    // read, so that a new one — which is what 眾人眾人 was — fails here
    // instead of reaching a reader.
    final offenders = <String>[];
    for (final edition in [zhHans, zhHant]) {
      edition.forEach((id, text) {
        final bare = text.replaceAll(RegExp(r'<note:[^>]*>'), '');
        for (final m in RegExp(r'([的了地得着著])\1').allMatches(bare)) {
          offenders.add('$id doubles the particle ${m.group(1)}');
        }
        for (final m in RegExp(r'([一-鿿]{2,4})\1').allMatches(bare)) {
          if (!_reduplication.contains(m.group(1))) {
            offenders.add('$id repeats ${m.group(1)}');
          }
        }
      });
    }
    expect(offenders, isEmpty,
        reason: 'a word is printed twice in scripture:\n${offenders.join('\n')}');
  });
}

/// Every multi-character sequence the CUV genuinely repeats, in both editions.
/// Distributive counting, or emphatic doubling of a verb.
const _reduplication = <String>{
  '如此',
  '一个', '一個', '一对', '一對', '一群', '一排', '一班', '一家', '一间', '一間',
  '一块', '一塊', '一帮', '一幫', '两个', '兩個',
  '歇息', '察看', '去吧', '修筑', '修築', '审问', '審問', '羞辱', '恩惠',
  '辨别', '辨別', '戏耍', '戲耍', '查点', '查點', '某处', '某處',
  '窥探', '窺探', '数算', '數算', '经过', '經過', '毁坏', '毀壞',
  '伤害', '傷害', '惩治', '懲治', '许多', '許多',
};
