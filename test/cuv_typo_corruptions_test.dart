import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sixteen transcription errors in the CUV verse text — a DIFFERENT defect
/// family from the eighteen converter-hole instalments the sibling
/// `traditional_*_glyph_test.dart` files pin.
///
/// Those all fixed damage done by the Simplified→Traditional converter, so the
/// Simplified asset was the witness and only the Traditional one was wrong.
/// These sixteen are wrong in BOTH assets: they predate the conversion. That is
/// why eighteen passes over the same corpus missed them — a converter oracle
/// cannot see a defect the converter did not cause.
///
/// They were found by running the character-inventory diff BACKWARDS.
/// Instalments 2–18 asked which characters the witness uses that we hold zero
/// of. Nobody had asked the reverse. Most of the reverse answer is edition
/// preference (ours keeps the older 和合本 spellings — 豫備, 儆醒, 沈睡, 擡 —
/// where the witness modernises them), but at counts of one and two it
/// surfaced characters that are not a variant of anything: 恉, 犰, 菏, 菇, 饃.
///
/// WHAT THEY ARE, precisely — because the first draft of this file said
/// something stronger and an adversarial check broke it. It claimed our asset
/// alone carried these. It does not: BibleHub's published CUV reproduces
/// thirteen of them verbatim. They are transcription errors in the shared
/// DIGITAL CUV lineage that most Chinese Bible software imported, and we
/// inherited them. They are not readings of the printed 和合本, which is why
/// repairing them restores the CUV rather than emending it.
///
/// The load-bearing evidence is therefore the corpus ratio, not any outside
/// source: our own text already spells every one of these words correctly
/// elsewhere, at 74:1, 1509:2, 14:1, 11:1, 17:1, 9:1, 4:1, 4:2, 2:1. The
/// Traditional witness blob 7a2dc43 agrees at all sixteen, and SeekSparks'
/// `cuvs-plus.json` — a partially repaired branch of the SAME lineage — agrees
/// at thirteen and is still wrong at 雅忆, 馍糊 and 帖士罗 (徒 24:2, though it
/// repaired 24:1). A partially repaired branch is not a clean witness.
///
/// The sharpest single example needs no witness at all: 士 15:16 printed
/// 「我用驢恉骨殺人成堆，用驢腮骨殺了一千人」 — the right word and a non-word
/// for the same jawbone, in the same sentence.
void main() {
  late List<Map<String, dynamic>> tr;
  late List<Map<String, dynamic>> sc;
  late String trBlob;
  late String scBlob;

  List<Map<String, dynamic>> read(String path) =>
      (json.decode(File(path).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  setUpAll(() {
    tr = read('assets/cuvs-yhwh-tr.json');
    sc = read('assets/cuvs-yhwh.json');
    trBlob = tr.map((v) => v['text'] as String).join();
    scBlob = sc.map((v) => v['text'] as String).join();
  });

  String trText(String id) =>
      tr.firstWhere((v) => v['id'] == id)['text'] as String;
  String scText(String id) =>
      sc.firstWhere((v) => v['id'] == id)['text'] as String;

  int count(String blob, String s) => blob.split(s).length - 1;

  String taggedText(String book, String key) {
    final data = json.decode(
      File('assets/tagged/cuvs-yhwh/$book.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    return (data[key] as List).map((t) => t['w'] as String).join();
  }

  // ---------------------------------------------------------------------
  // 1. The corrupt readings are gone from the whole corpus, both scripts.
  // ---------------------------------------------------------------------

  test('no corrupt reading survives anywhere in either script', () {
    const corruptTr = [
      '恉骨', '犰多', '扔菏', '巡菇', '暇疵', '囑吩', '此此如此',
      '已初', '班鳩', '饃糊', '雅憶', '帖士羅', '自已',
    ];
    const corruptSc = [
      '恉骨', '犰多', '扔菏', '巡菇', '暇疵', '嘱吩', '此此如此',
      '已初', '班鸠', '馍糊', '雅忆', '帖士罗', '自已',
    ];
    for (final s in corruptTr) {
      expect(count(trBlob, s), 0, reason: 'Traditional still holds $s');
    }
    for (final s in corruptSc) {
      expect(count(scBlob, s), 0, reason: 'Simplified still holds $s');
    }
  });

  // ---------------------------------------------------------------------
  // 2. Ours was internally inconsistent — the corpus already knew the word.
  //    These ratios are why the fix is a correction and not a preference.
  // ---------------------------------------------------------------------

  test('the words the corpus already spelt correctly are now unanimous', () {
    expect(count(trBlob, '囑咐'), 75); // was 74 against a single 囑吩
    expect(count(trBlob, '自己'), 1511); // was 1509 against two 自已
    expect(count(trBlob, '斑鳩'), 15); // was 14 against a single 班鳩
    expect(count(trBlob, '雅億'), 12); // was 11, and Jael is a person
    expect(count(trBlob, '如此如此'), 18);
    expect(count(trBlob, '瑕疵'), 10);
    expect(count(trBlob, '朵多'), 5); // Dodo, 代上 11:12
    expect(count(trBlob, '腮骨'), 6);
    expect(count(trBlob, '巳初'), 3);
    expect(count(scBlob, '嘱咐'), 75);
    expect(count(scBlob, '自己'), 1511);
    expect(count(scBlob, '斑鸠'), 15);
    expect(count(scBlob, '雅亿'), 12);
  });

  // ---------------------------------------------------------------------
  // 3. The two readings that carry a PERSON's name. These are the reason the
  //    whole family outranked everything else in the queue: a misspelt name
  //    does not look like a defect, it looks like a fact.
  // ---------------------------------------------------------------------

  test('士 4:18 no longer spells Jael two different ways in one verse', () {
    final v = trText('007004018');
    expect(v.contains('雅億用被'), isTrue);
    expect(v.contains('雅憶'), isFalse);
    expect(count(v, '雅億'), 2);
    expect(taggedText('judges', '4:18').contains('雅忆'), isFalse);
  });

  test('代上 11:12 calls Dodo 朵多, as the other four occurrences do', () {
    expect(trText('013011012').contains('亞合人朵多的兒子'), isTrue);
    expect(scText('013011012').contains('亚合人朵多的儿子'), isTrue);
    expect(taggedText('1_chronicles', '11:12').contains('犰多'), isFalse);
  });

  test('徒 24:1 and 24:2 both call Tertullus 帖土羅', () {
    // He appears exactly twice and was misspelt both times. The second
    // occurrence was missed by the first pass of this fix and caught by the
    // test, which is the reason the count is asserted over the whole corpus
    // rather than at the verse.
    expect(count(trBlob, '帖土羅'), 2);
    expect(count(scBlob, '帖土罗'), 2);
    expect(taggedText('acts', '24:1').contains('帖土罗'), isTrue);
    expect(taggedText('acts', '24:2').contains('帖土罗'), isTrue);
  });

  // ---------------------------------------------------------------------
  // 4. The three the repo's own tagged corpus disagreed with. It is NOT an
  //    independent witness — it shares thirteen of these errors and carries
  //    one of its own — but two copies of the same text sitting side by side,
  //    one right and one wrong, is still the cheapest check nobody had run.
  // ---------------------------------------------------------------------

  test('士 15:16 no longer uses the right and wrong word in one sentence', () {
    final v = trText('007015016');
    expect(v.contains('我用驢腮骨殺人成堆'), isTrue);
    expect(v.contains('用驢腮骨殺了一千人'), isTrue);
    expect(v.contains('恉'), isFalse);
    expect(taggedText('judges', '15:16').contains('恉'), isFalse);
  });

  test('士 15:17 and 士 20:6 now agree with the tagged corpus beside them', () {
    expect(trText('007015017').contains('就把那腮骨從手裏拋出去'), isTrue);
    expect(trText('007020006').contains('兇淫醜惡的事'), isTrue);
    expect(scText('007020006').contains('凶淫丑恶的事'), isTrue);
    expect(taggedText('judges', '20:6').contains('凶淫'), isTrue);
  });

  // ---------------------------------------------------------------------
  // 5. The remaining non-words, asserted at their own verse so a future sweep
  //    cannot quietly reintroduce one.
  // ---------------------------------------------------------------------

  test('the tagged corpus no longer reads 告她诉 at 王上 14:5', () {
    // Its own error, not shared with the verse asset beside it, which has
    // always read 告訴她. Found by the adversarial check on this instalment.
    final v = taggedText('1_kings', '14:5');
    expect(v.contains('告她诉'), isFalse);
    expect(v.contains('你当如此如此告诉她'), isTrue);
  });

  test('the remaining non-words read as words', () {
    expect(trText('010014025').endsWith('毫無瑕疵。'), isTrue);
    expect(trText('011002001').contains('就囑咐他兒子所羅門'), isTrue);
    expect(trText('011014005').contains('你當如此如此告訴她'), isTrue);
    expect(trText('019080015').contains('你為自己所堅固的枝子'), isTrue);
    expect(trText('019080017').contains('你為自己所堅固的人子'), isTrue);
    expect(trText('024012014').contains('所承受產業的'), isTrue);
    expect(trText('041015025').contains('是巳初的時候'), isTrue);
    expect(trText('042002024').contains('一對斑鳩'), isTrue);
    expect(trText('046013012').contains('模糊不清'), isTrue);
  });

  // ---------------------------------------------------------------------
  // 6. What was deliberately NOT changed. The reverse diff returns 70
  //    characters and most are the older 和合本 spelling, which is correct and
  //    is what this app ships. Pinning them stops a later instalment from
  //    reading "the witness disagrees" as "we are wrong".
  // ---------------------------------------------------------------------

  test('the older 和合本 spellings the witness disagrees with are untouched',
      () {
    expect(count(trBlob, '豫備'), greaterThan(0)); // witness: 預備
    expect(count(trBlob, '儆醒'), greaterThan(0)); // witness: 警醒
    expect(count(trBlob, '沈'), greaterThan(0)); // witness: 沉
    expect(count(trBlob, '擡'), greaterThan(0)); // witness: 抬
    expect(count(trBlob, '輥'), greaterThan(0)); // witness: 滾
    expect(count(trBlob, '禦'), greaterThan(0)); // witness: 御
    expect(count(trBlob, '號啕'), greaterThan(0)); // witness: 號咷
  });

  test('創 45:10 is left alone — it is the printed CUV, not a transcription '
      'error', () {
    // 「你和你我兒子孫子」 was in the first draft of this fix and was removed:
    // Wikisource's transcription of the printed 1919 和合本 reads 你我 here
    // too, so 你的 would be an emendation of the CUV. The user's call.
    expect(trText('001045010').startsWith('你和你我兒子孫子'), isTrue);
  });

  test('the four the second witness AGREES with us on are untouched', () {
    // cuvs-plus.json reads these exactly as we do, so the single Traditional
    // witness disagreeing is edition drift, not a defect. This is the check
    // that kept the instalment at sixteen instead of twenty-one.
    expect(count(trBlob, '大姆指'), 2); // witness: 大拇指
    expect(count(trBlob, '木丕子'), 1); // witness: 木墩子
    expect(count(trBlob, '挓抄手'), 1); // witness: 挓挲手
    expect(count(trBlob, '以士利亞'), 1); // witness: 以土利亞
  });

  test('於沙希悉 is still wrong, and is pinned so the next pass finds it', () {
    // NOT part of this instalment — it is a converter hole, not a base-text
    // typo, so it belongs with the eighteen `traditional_*_glyph` fixes rather
    // than here. It is pinned because the evidence is unusually clean and
    // should not be lost: our Simplified asset reads 于沙希悉 (代上 3:20,
    // Jushab-hesed) and opencc rewrote the name's 于 to 於 along with all 1,388
    // genuine 於. The Traditional witness holds exactly ONE 于 in 31,102
    // verses, and it is this name.
    expect(count(trBlob, '於沙希悉'), 1);
    expect(count(scBlob, '于沙希悉'), 1);
    expect(count(trBlob, '于'), 0);
  });
}
