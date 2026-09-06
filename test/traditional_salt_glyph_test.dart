import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Seventeenth instalment of the converter-hole defect (see
/// traditional_classifier_test.dart for 隻 and the sibling files for 淨/牆/餘,
/// 髮, 穀, 鬆, 干/乾, 卜, 恆, 凌, 症, 癒 and 崙), and by far the smallest —
/// ONE character, in ONE verse. It is here because of what the character is:
///
///   約書亞記 10:3 「…去見希伯崙王何鹹、耶末王毗蘭…」
///
/// Hoham, king of Hebron, printed as "salty". Simplified merges 鹹 (salty)
/// onto 咸, which in Traditional is a separate live character meaning
/// "all / universally" (咸信, 咸豐), and opencc runs that merge backwards
/// unconditionally: `echo 何咸 咸信 | opencc -c s2t` → 何鹹 咸信. Its phrase
/// table happens to know 咸信 and does not know the name, so it salted a
/// Canaanite king.
///
/// TWO THINGS MAKE THIS ONE DIFFERENT FROM ITS PREDECESSORS, AND BOTH ARE
/// PINNED BELOW.
///
/// First, it is a SPLIT, not a partition. Every sweeping instalment before it
/// rested on ours holding zero of the Traditional form across 31,102 verses,
/// which leaves no editorial hypothesis standing. Not so here: six of our
/// seven 鹹 are genuine salt — 採鹹草, 使鹹地, 叫它再鹹呢 ×3, 鹹水 — and a
/// sweep would have destroyed them. The repair was decided at one position,
/// and the six salts are asserted explicitly.
///
/// Second, the Simplified source CANNOT confirm it. The 崙 instalment leaned
/// hardest on exactly that check, because Simplified distinguishes 仑 from 伦
/// and so carries the answer inside the repo forever. 咸 is the opposite case:
/// the merge is on the Simplified side, so `assets/cuvs-yhwh.json` reads 咸 at
/// all seven positions and cannot tell them apart. The evidence is external —
/// git blob 7a2dc43 (the 和合本 Traditional dropped at v1.4.5) and a published
/// 新標點和合本 (ebible `cmn-cu89t`) both read 1 咸 / 6 鹹 with the 咸 at
/// 書 10:3. The last test here pins the Simplified distribution anyway, so
/// that the reason the internal check is unavailable stays documented in code.
void main() {
  late List<Map<String, dynamic>> verses;
  late String blob;

  setUpAll(() {
    verses =
        (json.decode(File('assets/cuvs-yhwh-tr.json').readAsStringSync())
                as List)
            .cast<Map<String, dynamic>>();
    blob = verses.map((v) => v['text'] as String).join();
  });

  String textOf(String book, String chapter, String verse) => verses
      .firstWhere((v) =>
          v['book'] == book &&
          '${v['chapter']}' == chapter &&
          '${v['verse']}' == verse)['text'] as String;

  int count(String s) => blob.split(s).length - 1;

  test('the corpus holds one 咸 and six 鹹, matching both Traditional witnesses',
      () {
    expect(count('咸'), 1);
    expect(count('鹹'), 6);
  });

  test('Hoham is a name, not a flavour', () {
    expect(textOf('約書亞記', '10', '3'), contains('希伯崙王何咸'));
    expect(textOf('約書亞記', '10', '3').contains('鹹'), isFalse);
  });

  test('all six genuine salts survive — this class does NOT move whole', () {
    // The nearest false positives this repair had. A sweep of 鹹 → 咸 would
    // have read "salt that lost its saltiness" as "salt that lost its
    // universality" in three Gospels.
    expect(textOf('約伯記', '30', '4'), contains('在草叢之中採鹹草'));
    expect(textOf('約伯記', '39', '6'), contains('使鹹地當它的居所'));
    expect(textOf('馬太福音', '5', '13'), contains('怎能叫它再鹹呢'));
    expect(textOf('馬可福音', '9', '50'), contains('叫它再鹹呢'));
    expect(textOf('路加福音', '14', '34'), contains('叫它再鹹呢'));
    expect(textOf('雅各書', '3', '12'), contains('鹹水裏也不能發出甜水來'));
  });

  test("the Strong's lexicon was already right on BOTH readings", () {
    // A different pipeline produced the lexicon and it got this pair correct,
    // which is why it is untouched here. H3458 is the reason that matters: a
    // sweep of the lexicon in either direction would have broken 咸信
    // ("generally believed"), where 咸 is a real Traditional word and has
    // nothing to do with salt or with a name.
    final lex = json
        .decode(File('assets/strongs/hebrew.json').readAsStringSync())
            as Map<String, dynamic>;
    final greek = json
        .decode(File('assets/strongs/greek.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(lex['H3458']['glossZhTw'] as String, contains('咸信是阿拉伯人的祖先'));
    expect(lex['H4420']['glossZhTw'] as String, contains('鹹性'));
    expect(greek['G252']['glossZhTw'] as String, contains('鹹的'));
    // Hoham's own entry names him only in Hebrew and by reference, so there
    // was no second spelling of the name to keep in step.
    expect(lex['H1944']['gloss'] as String, contains('Hoham'));
    expect(lex['H1944']['glossZhTw'] as String, contains('希伯崙王'));
  });

  test('the sermon that greps as 何鹹 is a false positive and stays put', () {
    // assets/sermons/zh-TW/018.txt used to match 何鹹 on a naive grep — it
    // was 「不再有任何鹹味」, 任何 + 鹹味, in a sermon on Matthew 5:13.
    //
    // **That exact sentence is gone as of 2026-09-06 and the guard it stood
    // for is not.** 018 is one of 51 machine-translated Chinese bodies the
    // merge replaced with the fuyindiantai library's human text
    // (`scripts/merge_sermon_library.py`), and the human text puts the same
    // teaching in different words. So there is no 何鹹 anywhere in the
    // corpus now — asserted, so that a reappearing one is noticed — and the
    // real point, that nobody sweeps 鹹 → 咸 across a preacher's words, is
    // pinned on the readings 018 actually has today.
    final sermon = File('assets/sermons/zh-TW/018.txt').readAsStringSync();
    for (final reading in const [
      '怎能叫它再鹹呢', '門徒不可失掉鹹味', '鹽不鹹：有名無實',
      '千萬別失掉鹹味',
    ]) {
      expect(sermon, contains(reading), reason: reading);
    }
    expect(sermon.contains('咸'), isFalse);

    var salted = 0;
    var mainland = 0;
    var falsePositives = 0;
    for (final f in Directory('assets/sermons/zh-TW').listSync()) {
      if (f is! File || !f.path.endsWith('.txt')) continue;
      final s = f.readAsStringSync();
      salted += s.split('鹹').length - 1;
      mainland += s.split('咸').length - 1;
      falsePositives += s.split('何鹹').length - 1;
    }
    expect(salted, 29);
    expect(mainland, 0);
    expect(falsePositives, 0,
        reason: 'the 任何鹹味 false positive left with 018\'s old body; if '
            'one comes back, read it before any sweep touches it');
  });

  test('the Simplified source merges the pair, so it cannot arbitrate', () {
    // Not a check of the fix — a check on the REASON the usual internal check
    // is missing. Simplified writes 咸 for both the name and the salt, so all
    // seven positions look identical there. If this ever fails, Simplified has
    // gained a distinction it does not have, and the fix above should be
    // re-derived from the Simplified twin instead of from an external witness.
    final simplified =
        (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
    final source = simplified.map((v) => v['text'] as String).join();
    expect('咸'.allMatches(source).length, 7);
    expect(source.contains('鹹'), isFalse);
    final joshua = simplified
        .firstWhere((v) => v['id'] == '006010003')['text'] as String;
    expect(joshua, contains('希伯仑王何咸'));
  });
}
