import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Nineteenth instalment of the converter-hole defect (see
/// traditional_classifier_test.dart for 隻 and the sibling files for 淨/牆/餘,
/// 髮, 穀, 鬆, 干/乾, 卜, 恆, 凌, 症, 癒, 崙, 咸, 鹼 and 姪): the personal name
/// Jushab-hesed at 代上 3:20, which our Traditional Bible spelt 於沙希悉 where
/// every published Traditional 和合本 spells it 于沙希悉.
///
/// One substitution, and the second instalment to reach a proper NAME.
///
/// THE MECHANISM. Simplified merged the preposition 於 into 于, so the step
/// that produced this asset had to expand one Simplified character into two
/// Traditional ones. It did so with a blanket per-character map — our
/// Simplified holds 1,388 于 and 0 於, our Traditional held 1,388 於 and 0 于 —
/// which is unconditional, and therefore blind to the single position in
/// 31,102 verses where the syllable is a name and not a function word. Right
/// 1,387 times, wrong once.
///
/// WHAT THIS TEST MUST NOT BE READ AS CLAIMING, because an adversarial check
/// broke a stronger draft of it:
///
///   * It is NOT opencc that did this. `tools/fix_traditional_conversion.py`
///     already established these assets were made by a naive map: opencc
///     disagrees with them in roughly half of all verses and gets 船隻 right
///     where this corpus got it wrong. opencc reproducing the error on the
///     name is a demonstration that naive expansion fails here, not evidence
///     of provenance. The 1,388/1,388 identity is the evidence.
///   * The Simplified sources are logically NULL on 于-versus-於 — Simplified
///     cannot distinguish them. What the tagged corpus settles is the thing
///     that actually matters: the token is tagged H3142, יוּשַׁב חֶסֶד, so it is
///     a NAME and not a clause containing a preposition.
///   * The two Traditional witnesses are ONE textual family, not two
///     independent lines: both set the 新標點 name separator 于沙‧希悉, which
///     ours does not. The honest claim is "no published Traditional CUV
///     available here spells it 於", not "two unrelated editions agree".
///
/// That is still decisive, because 於 in modern Traditional is essentially
/// only the preposition — 於沙希悉 spells a man's name with a grammatical
/// particle. This is the distinction that keeps 蹟/跡 and 鍊/鏈 deliberately
/// unswept in traditional_tail_glyphs_test.dart: there, our spelling is one a
/// published edition legitimately sets. Here it is not.
void main() {
  late List<Map<String, dynamic>> verses;
  late String corpus;
  late String simplified;

  setUpAll(() {
    verses =
        (json.decode(File('assets/cuvs-yhwh-tr.json').readAsStringSync())
                as List)
            .cast<Map<String, dynamic>>();
    corpus = verses.map((v) => v['text'] as String).join();
    simplified =
        ((json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List)
                .cast<Map<String, dynamic>>())
            .map((v) => v['text'] as String)
            .join();
  });

  String textOf(String id) =>
      verses.firstWhere((v) => v['id'] == id)['text'] as String;

  int count(String haystack, String needle) =>
      haystack.split(needle).length - 1;

  test('代上 3:20 names Jushab-hesed 于沙希悉', () {
    expect(textOf('013003020'),
        '米書蘭的兒子是哈舒巴、阿黑、比利家、哈撒底、于沙希悉，共五人。');
  });

  test('the corpus holds exactly one 于, and it is the name', () {
    // Fails on the pre-fix data, which held zero. The count is pinned at one
    // rather than "at least one" so that a later sweep cannot quietly turn
    // prepositions into 于 on the strength of this instalment.
    expect(count(corpus, '于'), 1);
    expect(count(corpus, '於沙希悉'), 0);
    final withYu = verses.where((v) => (v['text'] as String).contains('于'));
    expect(withYu.map((v) => v['id']), ['013003020']);
  });

  test('the blanket 1:1 expansion that caused this is still visible', () {
    // The Simplified twin has 1,388 于 and no 於 at all; the Traditional side
    // now has 1,387 於 plus the one restored 于. If these ever stop summing,
    // something has re-run a wholesale conversion over the repaired asset.
    expect(count(simplified, '于'), 1388);
    expect(count(simplified, '於'), 0);
    expect(count(corpus, '於') + count(corpus, '于'), 1388);
  });

  test('尼 1:2 is an edition difference and stays as it is', () {
    // The only other verse whose 于/於 sequence differs from the witness blob.
    // Ours reads 關於 twice where the witness's clause omits the phrase
    // entirely — a wording difference, not a character choice, and our own
    // Simplified twin reads 关于 in both places. Pinned so a future 于 sweep
    // does not mistake it for a second instance of this defect.
    expect(textOf('016001002'), contains('關於那些被擄歸回'));
    expect(textOf('016001002'), contains('和關於耶路撒冷的光景'));
  });

  test('the Strong\'s tag that makes this a name is still there', () {
    final tagged =
        File('assets/tagged/cuvs-yhwh/1_chronicles.json').readAsStringSync();
    // Simplified corpus, so it reads 于 correctly; what it contributes is the
    // tag. H3142 is יוּשַׁב חֶסֶד — a person, not a preposition.
    expect(tagged, contains('"于沙希悉，"'));
    final entry = json.decode(
        File('assets/strongs/hebrew.json').readAsStringSync())['H3142'];
    expect(entry['gloss'], contains('Jushab-Chesed'));
  });
}
