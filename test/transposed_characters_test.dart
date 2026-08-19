import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Nine verses printed the right characters in the wrong order.
///
/// 箴言 22:11 read 「因他嘴的恩言，王必與他為上友」 — 為上友 is not a word,
/// and the 上 it is holding belongs one clause earlier, in 嘴上的恩言.
/// 尼希米記 8:4 read 「木臺上。站瑪他提雅…和瑪西雅在他的右邊」, a verb
/// stranded in front of a list of names while the same verse gets the
/// identical clause right eight names later: 「和米書蘭站在他的左邊」.
/// 使徒行傳 26:16 read 「特意向你我顯現」 — 向你我 occurs in exactly one
/// verse of 31,102, and its only natural reading is "to you and me", which
/// is false: Jesus is speaking to Paul alone.
///
/// These survived `audit_dropped_characters.py` by construction: that check
/// compares the multiset of ideographs against two independent witnesses, and
/// a transposition leaves it untouched. Nothing is missing; it is in the
/// wrong place.
///
/// Each reading was settled on four independent lines before anything was
/// written, because reordering scripture is as dangerous as inserting it:
/// a separate Simplified import, a separately imported Traditional 和合本
/// (git blob `7a2dc43`), the Wikisource transcription of the printed 1919
/// text, and evidence internal to this repo. The third decided two that the
/// others could not: 26 of the 42 tagged runs carrying ἔμπροσθεν spelt it
/// 面前 and only two spelt it 前面, so frequency argued for leaving 馬太福音
/// 6:2 alone — and the print reads 「不可在你前面吹號」.
///
/// `tools/repair_transposed_characters.py` applies it, with a guard that
/// every edit is a permutation — a reordering that gains or loses a
/// character is a different defect and must not ride along.
void main() {
  const simplified = 'assets/cuvs-yhwh.json';
  const traditional = 'assets/cuvs-yhwh-tr.json';

  /// id → (Simplified, Traditional). Every one fails on the pre-repair data.
  const reordered = <String, List<String>>{
    '001009011': ['毁坏地了', '毀壞地了'],
    '016008004': ['和玛西雅站在他的右边', '和瑪西雅站在他的右邊'],
    '020022011': ['因他嘴上的恩言，王必与他为友', '因他嘴上的恩言，王必與他為友'],
    '031001005': ['摘葡萄的若来到你那里', '摘葡萄的若來到你那裏'],
    '040006002': ['不可在你前面吹号', '不可在你前面吹號'],
    '040025020': ['那另外的五千来', '那另外的五千來'],
    '044024016': ['我因此自己勉励', '我因此自己勉勵'],
    '044026016': ['站着，我特意向你显现', '站著，我特意向你顯現'],
    '045004023': ['算为他义”的这句话', '算為他義」的這句話'],
  };

  /// The readings that were there before, spelled out so that a re-import
  /// putting any of them back turns the suite red rather than shipping.
  const scrambled = <String, List<String>>{
    '001009011': ['毁坏了地', '毀壞了地'],
    '016008004': ['木台上。站玛他提雅', '木臺上。站瑪他提雅'],
    '020022011': ['为上友', '為上友'],
    '031001005': ['若到来你那里', '若到來你那裏'],
    '040006002': ['不可在你面前吹号', '不可在你面前吹號'],
    '040025020': ['那另外五千的来', '那另外五千的來'],
    '044024016': ['因此我自己勉励', '因此我自己勉勵'],
    '044026016': ['向你我显现', '向你我顯現'],
    '045004023': ['算为他的义”这句话', '算為他的義」這句話'],
  };

  /// 耶利米書 7:14 was on the same list of candidates and came off it: ours
  /// reads 稱我為名下 where BOTH witnesses read 稱為我名下, and the printed
  /// 1919 sides with ours. Two witnesses agreeing is not proof when they
  /// share an ancestor — the lesson 創世記 39:22 and 41:30 already taught
  /// this repo. Pinned so a later pass does not "fix" it.
  const keepAsIs = <String, List<String>>{
    '024007014': ['称我为名下', '稱我為名下'],
  };

  Map<String, String> load(String path) => {
        for (final row
            in (json.decode(File(path).readAsStringSync()) as List)
                .cast<Map<String, dynamic>>())
          row['id'] as String: row['text'] as String,
      };

  test('the nine verses read in the order the CUV prints them', () {
    final s = load(simplified);
    final t = load(traditional);
    reordered.forEach((id, forms) {
      expect(s[id], isNotNull, reason: '$id missing from the Simplified file');
      expect(s[id], contains(forms[0]), reason: '$id Simplified');
      expect(t[id], contains(forms[1]), reason: '$id Traditional');
    });
    scrambled.forEach((id, forms) {
      expect(s[id], isNot(contains(forms[0])), reason: '$id Simplified');
      expect(t[id], isNot(contains(forms[1])), reason: '$id Traditional');
    });
    keepAsIs.forEach((id, forms) {
      expect(s[id], contains(forms[0]), reason: '$id must NOT be "fixed"');
      expect(t[id], contains(forms[1]), reason: '$id must NOT be "fixed"');
    });
  });

  test('reordering moved characters and did not add or lose any', () {
    // The property that separates this repair from the dropped-character one:
    // the Simplified and Traditional files must still hold the same NUMBER of
    // characters per verse as each other, and every touched verse must be a
    // permutation of what the witnesses read. Length is the cheap half of
    // that and the half a bad edit breaks first.
    final s = load(simplified);
    final t = load(traditional);
    for (final id in reordered.keys) {
      expect(s[id]!.length, t[id]!.length,
          reason: '$id: the two scripts disagree on length, so one of them '
              'gained or lost a character during the reorder');
    }
  });

  test('the word-tap corpus was reordered with the reading text', () {
    // The Originals sheet prints the tagged runs INSTEAD of the verse, so a
    // repair that stops at the reading asset leaves 為上友 on screen behind a
    // tap. 尼希米記 8:4 is absent on purpose: the tagged import already had
    // 站 in the right place, which is part of how we know the reading asset
    // was the file that was wrong.
    const inTagged = <String, List<String>>{
      'genesis': ['9:11', '毁坏地了'],
      'proverbs': ['22:11', '因他嘴上的恩言，王必与他为友'],
      'obadiah': ['1:5', '若来到'],
      'matthew': ['6:2', '不可在你前面吹号'],
      'acts': ['24:16', '我因此自己'],
      'romans': ['4:23', '义”的这'],
      // 使徒行傳 26:16 is keyed separately below, because its run split is
      // the thing worth pinning and the joined text alone would not show it.
    };
    inTagged.forEach((slug, spec) {
      final book = json.decode(
              File('assets/tagged/cuvs-yhwh/$slug.json').readAsStringSync())
          as Map<String, dynamic>;
      final runs = book[spec[0]] as List;
      final joined =
          runs.map((r) => (r as Map<String, dynamic>)['w'] as String).join();
      expect(joined, contains(spec[1]), reason: '$slug ${spec[0]}');
    });

    // 馬太福音 25:20 was scrambled a THIRD way here — 「那另外五的千」 —
    // while the reading asset read 五千的 and our own Traditional file
    // already read 的五千. Three of our files, one clause, three orders.
    final matthew = json.decode(
            File('assets/tagged/cuvs-yhwh/matthew.json').readAsStringSync())
        as Map<String, dynamic>;
    final joined = (matthew['25:20'] as List)
        .map((r) => (r as Map<String, dynamic>)['w'] as String)
        .join();
    expect(joined, contains('那另外的五千'));
    expect(joined, isNot(contains('五的千')));

    // 使徒行傳 24:16 needed a run split, not a rewrite: once 因此 sits
    // between them, αὐτός is rendered by a discontinuous 我…自己, and both
    // halves carry G846. Tagging 我 as G1722 instead would answer "in this"
    // to a reader who taps the pronoun.
    final acts = json.decode(
            File('assets/tagged/cuvs-yhwh/acts.json').readAsStringSync())
        as Map<String, dynamic>;
    final runs = (acts['24:16'] as List).cast<Map<String, dynamic>>();
    final pronoun = runs.firstWhere((r) => r['w'] == '我');
    expect(pronoun['s'], 'G846');
    expect(runs.firstWhere((r) => r['w'] == '因此')['s'], 'G1722');

    // 使徒行傳 26:16 needed the same split for the opposite reason: 我 and
    // 顯現 render ὤφθην, ONE Greek word that carries its subject in the
    // inflection, so there is no pronoun in the Greek for 我 to be given.
    // It keeps the verb's G3700 rather than picking up a number from its
    // new neighbours — tagging it G1519 as SeekSparks' independent aligner
    // does would count εἰς twice, since 特意 already carries it as implied.
    final acts2616 = (acts['26:16'] as List).cast<Map<String, dynamic>>();
    final words = acts2616.map((r) => r['w'] as String).toList();
    expect(words.join(), contains('我特意向你显现'));
    expect(words.join(), isNot(contains('向你我显现')));
    final me = acts2616[words.indexOf('我')];
    expect(me['s'], 'G3700');
    expect(acts2616[words.indexOf('特意')]['i'], ['G1519']);
  });

  test('reordering a run kept its parsing data', () {
    // A run carries more than a Strong's number: `g` is the morphology code
    // and `i` the original word the CUV renders with no Chinese word of its
    // own. The first draft of this repair rebuilt the runs from text and
    // Strong's alone, and four verses came out with the right characters and
    // the parsing silently gone — 創世記 9:11 lost the infinitive-construct
    // code off its verb, 馬太福音 25:20 lost τάλαντον, 使徒行傳 24:16 lost
    // τούτῳ. Nothing on screen would have shown it.
    Map<String, dynamic> run(String slug, String ref, String word) {
      final book = json.decode(
              File('assets/tagged/cuvs-yhwh/$slug.json').readAsStringSync())
          as Map<String, dynamic>;
      return (book[ref] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((r) => r['w'] == word);
    }

    expect(run('genesis', '9:11', '毁坏')['g'], ['H8763']);
    expect(run('obadiah', '1:5', '来到')['g'], ['H8804']);
    expect(run('acts', '24:16', '因此')['i'], ['G5129']);

    // 馬太福音 25:20 has THREE runs reading 五千, so the one this repair
    // touched has to be found by position — the run right after 那另外的.
    final matthew = json.decode(
            File('assets/tagged/cuvs-yhwh/matthew.json').readAsStringSync())
        as Map<String, dynamic>;
    final runs2520 = (matthew['25:20'] as List).cast<Map<String, dynamic>>();
    final other = runs2520.indexWhere((r) => r['w'] == '那另外的');
    expect(other, isNot(-1));
    expect(runs2520[other + 1]['w'], '五千');
    expect(runs2520[other + 1]['i'], ['G5007']);
    // …and the split did not COPY it: 我 and 自己 share one Greek word, so
    // only their Strong's number may be shared.
    expect(run('acts', '24:16', '我').keys.toSet(), {'w', 's'});
    expect(run('acts', '24:16', '自己').keys.toSet(), {'w', 's'});

    // 使徒行傳 26:16 split a run that DID carry parsing data — g:["G5681"],
    // the aorist passive of ὤφθην. Copying it to both halves would state
    // the Greek has the verb twice, so it stays on the verb and the pronoun
    // comes out bare. This is the only reason the repair tool grew a BARE
    // marker; a plain split of this run is still rejected.
    final acts2616 = json.decode(
            File('assets/tagged/cuvs-yhwh/acts.json').readAsStringSync())
        as Map<String, dynamic>;
    final split = (acts2616['26:16'] as List).cast<Map<String, dynamic>>();
    expect(split.firstWhere((r) => r['w'] == '我').keys.toSet(), {'w', 's'});
    expect(split.firstWhere((r) => r['w'] == '显现，')['g'], ['G5681']);
  });
}
