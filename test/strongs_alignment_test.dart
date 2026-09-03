import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The word-tap sheet can name the wrong original word while looking right.
///
/// Tapping Chinese text in `assets/tagged/cuvs-yhwh/` shows whatever
/// `originals_sheet.dart` finds for that run's `s`. A run can carry a
/// perfectly real Strong's number and still be false, because the number
/// names a DIFFERENT word of the verse from the one the Chinese renders:
/// 民數記 11:8 tags 百姓, "the people", with H8081 — שֶׁמֶן, *oil* — and
/// 使徒行傳 12:24 tags 神 with G3588, the definite article.
///
/// `audit_strongs_tagging.py` is blind to almost all of it, because it asks
/// whether a number is missing from the verse's original and here it is
/// usually present. `tools/audit_strongs_alignment.py` asks the reader's
/// question instead, and this test pins its census.
///
/// **Three repair passes have run.**
/// `tools/repair_strongs_alignment_core.py` (2026-08-24) took six of the core,
/// which is why the examples above are already fixed: 百姓 now answers H5971 and
/// 使徒行傳 12:24's 神 now answers G2316. `tools/repair_strongs_spans.py`
/// (2026-08-24) then took 39 of the 53 `spans-the-word` runs, and a round three
/// on 2026-09-03 took 3 more that the first span pass had held. The same day
/// the core tool took a seventh run, 民數記 23:11's 巴勒. The census has gone
/// 71/53/7/15 -> 65/53/7/9 -> 26/14/3/9 -> 23/11/3/9 -> **22/11/2/9**.
///
/// **Round three is the only pass here where "the reader only gains" is true,
/// and it is true because it was recomputed rather than hoped.** 王上 1:35's
/// 和犹大, 民 19:18's 和一切 and 猶大書 1:25's 永永远远。 each displaced a number
/// that a SIBLING RUN OF THE SAME VERSE still shows — H5921 on 我的位上，, H5921
/// on three 上 runs, G3956 on 从万古 — so unlike the 39 they cost no coverage
/// anywhere. Corpus-wide the pass made three numbers newly reachable (H3063,
/// H3605, G165, each in its own verse) and made none unreachable. The three had
/// been held on the reasoning that bare 和 carries H5921 in 61 runs corpus-wide;
/// that is frequency of a DIFFERENT string than the one judged (61 of 1,240,
/// 4.9%), which is the frequency-of-the-wrong-pair argument this file exists to
/// refuse. What settled them is the corpus's tagging of the IDENTICAL string —
/// 和犹大 H3063 54/55, 和一切 H3605 44/45, 永永远远 G165 20/21 — plus the fact
/// that the `i` each carried was false: it asserted that 犹大 does not render
/// יְהוּדָה, that 一切 does not render כֹּל, that 永远 does not render αἰών.
///
/// **The premise is `s`, never `i`, and getting that wrong made the count six
/// times too small.** A first version counted a run's `i` as coverage, so a
/// verse whose θεός sat in some run's `i` looked fine. It is not fine:
/// `tagged_text_service.dart` parses `i` into `TaggedRun.implied` and no
/// widget reads it, so a number that appears only there is invisible to every
/// reader. On the corrected premise the census went 11 -> 71.
///
/// **The total was never a mistake count, and it is not the size of the class
/// either.** It decomposes, and the three kinds want different fixes:
///
///  * 11 are `spans-the-word` — the right number is already in that same run's
///    own `i`. The importer covered the word and put `s` on a particle or
///    prefix inside the span. **These 11 are the residue of 53**, and they are
///    the ones the span repair refused, because the structural shape of the
///    class is not sufficient: where the Chinese spells BOTH words the `s` is
///    partial rather than false, and promoting the head would trade one
///    partial answer for another while asserting "this text does not render
///    it" about a character that plainly does. 王下 3:27's 的長子 spells בֵּן
///    in 子 and בְּכוֹר in 長; 創 33:17's 名叫 spells קָרָא in 叫, and its `g`
///    code H8804 is that verb's Qal perfect. `tools/repair_strongs_spans.py`
///    carries the reason for each in its `HELD` table.
///  * 2 display a number that is not in the verse's original at all. This was
///    7; four of those went because they were also spans and the span repair
///    dropped their displaced number instead of demoting it, precisely because
///    `i` claims the original HAS a number and there it did not. The fifth was
///    民數記 23:11, repaired 2026-09-03 — see below.
///  * 9 point elsewhere in the verse — the residue of the core after the six
///    repairs. Four are defensible readings where a Chinese function word maps
///    to a closed class (出 16:23, 何 12:8, 士 9:48's 所/我所, 民 33:39's 歲),
///    撒上 13:6 is a plain false positive, and four are open questions with two
///    positions on record in `docs/autonomous-queue.md`.
///
/// **Do not rebuild the frequency argument that nearly justified the repair.**
/// The draft reasoning was that each repaired pair (run text, number) occurred
/// EXACTLY ONCE corpus-wide while the proposed number carried the same text
/// hundreds of times — so a singleton looked like a slip. `singleton pairs are
/// not evidence` below measures that property at **335 runs** (371 before any
/// repair, 367 after the core's six, 340 after the span pass, 336 after round
/// three, and 335 once 民 23:11's 巴勒 stopped being one), and 約伯記 3:2
/// is one of them and is correct: its lone run 说： is tagged H6030 עָנָה,
/// *answered*, because the Hebrew is וַיַּעַן אִיּוֹב וַיֹּאמַר and this
/// translation collapses the pair. Rarity finds rare readings, not wrong ones.
///
/// 340 -> 336 is four, from three repaired runs, and the fourth is the
/// interesting one: 民 19:18's 众人 is correctly H5315 נֶפֶשׁ for
/// הַנְּפָשׁוֹת, and sat in this pool only because no run of that verse showed
/// H3605. Repairing 和一切 supplied it, so a false positive went quiet without
/// anything being decided about 众人 at all.
///
/// It is a FLOOR because the detector only admits a run text that occurs at
/// least 20 times with one number covering 95% of them; anything rarer cannot
/// be told from polysemy, and 耶利米書 35:18's 他的一切 is a known miss. It
/// also does not flag a verse where the true word is absent from the original,
/// which is why the six 神 = G3588 runs at 提後 1:9, 弗 3:20, 羅 16:25,
/// 羅 4:24, 來 1:7 and 徒 7:44 stay out: θεός is not in the Greek there and the
/// article is substantival (Ὁ ποιῶν, Τῷ δυναμένῳ), so 神 renders the phrase.
///
/// These numbers are a ratchet. They may go DOWN as the class is repaired; if
/// one goes UP, an import has introduced new misalignment and the enumeration
/// in the tool is the place to look.
void main() {
  final notCjk = RegExp(r'[^一-鿿]');

  Map<String, dynamic> readJson(String path) =>
      json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

  final books = Directory('assets/tagged/cuvs-yhwh')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .map((f) => f.path.split('/').last.replaceAll('.json', ''))
      .toList()
    ..sort();

  final tagged = {for (final b in books) b: readJson('assets/tagged/cuvs-yhwh/$b.json')};

  /// (run text, 'H' or 'G') -> the number covering >= 95% of its occurrences,
  /// for texts that occur >= 20 times and are not always tagged the same way.
  final counts = <String, Map<String, int>>{};
  for (final verses in tagged.values) {
    for (final runs in verses.values) {
      for (final run in (runs as List).cast<Map<String, dynamic>>()) {
        final text = ((run['w'] ?? '') as String).replaceAll(notCjk, '');
        final number = (run['s'] ?? '') as String;
        if (text.isEmpty || number.isEmpty || number == 'H0') continue;
        final key = '$text ${number[0]}';
        (counts[key] ??= <String, int>{}).update(number, (v) => v + 1,
            ifAbsent: () => 1);
      }
    }
  }
  final dominant = <String, String>{};
  counts.forEach((key, byNumber) {
    if (byNumber.length < 2) return;
    final total = byNumber.values.reduce((a, b) => a + b);
    if (total < 20) return;
    final best = byNumber.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (best.value / total >= 0.95) dominant[key] = best.key;
  });

  final base = readJson('assets/originals_versification.json');
  final merged =
      readJson('assets/originals_versification_merged.json')['cuvs-yhwh']
          as Map<String, dynamic>;

  final hits = <Map<String, Object>>[];
  for (final book in books) {
    final originalsFile = File('assets/originals/$book.json');
    if (!originalsFile.existsSync()) continue;
    final originals = readJson('assets/originals/$book.json');
    (tagged[book]!).forEach((ref, runsRaw) {
      final runs = (runsRaw as List).cast<Map<String, dynamic>>();
      final refs = ((merged[book] as Map<String, dynamic>?)?[ref] ??
              (base[book] as Map<String, dynamic>?)?[ref] ??
              [ref]) as List;
      final present = <String>{};
      for (final originalRef in refs) {
        for (final word in (originals[originalRef] as List? ?? const [])) {
          present.add(((word as Map<String, dynamic>)['s'] ?? '') as String);
        }
      }
      if (present.isEmpty) return;
      final shown = <String>{
        for (final r in runs)
          if (((r['s'] ?? '') as String).isNotEmpty) r['s'] as String
      };
      for (final run in runs) {
        final text = ((run['w'] ?? '') as String).replaceAll(notCjk, '');
        final number = (run['s'] ?? '') as String;
        if (text.isEmpty || number.isEmpty) continue;
        final expected = dominant['$text ${number[0]}'];
        if (expected == null || expected == number) continue;
        if (!present.contains(expected) || shown.contains(expected)) continue;
        final implied = ((run['i'] as List?) ?? const []).cast<String>();
        hits.add({
          'where': '$book $ref',
          'text': text,
          'spans': implied.contains(expected),
          'absent': !present.contains(number),
        });
      }
    });
  }

  test('the word-tap sheet names the wrong original word in 22 runs', () {
    expect(books, hasLength(66));
    expect(dominant, hasLength(256),
        reason: 'the run texts frequent and consistent enough to give ground '
            'truth; if this moves the census below is not comparable. It has '
            'gone 271 -> 270 -> 259 -> 260 -> 257 -> 256. Every step down was a '
            'repair leaving a run text no longer disagreeing with itself, '
            'which retires it as a ground-truth candidate; the step UP is the '
            '2026-09-02 restoration of 主* as 主[耶稣], which gave 124 runs a '
            'new text and made one more of them frequent and consistent '
            'enough to qualify. The 260 -> 257 is round three: 和犹大 is now '
            'H3063 in 55 of 55, 和一切 H3605 in 45 of 45 and 永永远远 G165 in '
            '21 of 21 Greek runs, so all three groups are unanimous and drop '
            'out. A text that is unanimous can produce no hits, so nothing is '
            'hidden by leaving');
    expect(hits, hasLength(22));
  });

  test('the census decomposes 11 / 2 / 9 after the span repair', () {
    expect(hits.where((h) => h['spans'] == true), hasLength(11));
    expect(hits.where((h) => h['absent'] == true), hasLength(2));
    expect(
        hits.where((h) => h['spans'] == false && h['absent'] == false),
        hasLength(9));
  });

  /// Each of these answered a different word of its own verse. The number
  /// written is the one whose lemma the Chinese chunk literally translates,
  /// and in every case it is an adjacent token of the same verse.
  test('the eight repaired runs answer the word their Chinese renders', () {
    String tagOf(String book, String ref, String text) {
      final runs = (tagged[book]![ref] as List).cast<Map<String, dynamic>>();
      final match = runs.where((r) => r['w'] == text);
      if (match.length != 1) {
        throw StateError('$book $ref has ${match.length} runs "$text"');
      }
      return (match.first['s'] ?? '') as String;
    }

    // 百姓 is הָעָם, not שֶׁמֶן — the verse's only "oil" is its last word.
    expect(tagOf('numbers', '11:8', '百姓'), 'H5971');
    // 一切 is כֹּל; H853 is the object marker, which renders as nothing.
    expect(tagOf('jeremiah', '47:4', '一切'), 'H3605');
    // 神 is θεός; G3754 is ὅτι, opening the clause after it.
    expect(tagOf('1_corinthians', '1:14', '神，'), 'G2316');
    // ὁ λόγος τοῦ θεοῦ / παρατίθεμαι ὑμᾶς τῷ θεῷ: the run had the article.
    expect(tagOf('acts', '12:24', '神'), 'G2316');
    expect(tagOf('acts', '20:32', '神'), 'G2316');
    // 邱壇 is בָּמָה and 帳幕 is מִשְׁכָּן; the two numbers were swapped.
    expect(tagOf('1_chronicles', '16:39', '邱坛、'), 'H1116');

    // The seventh, 2026-09-03, and the only one whose displaced number was not
    // in its own verse at all. 巴勒 is Balak, H1111; it had answered H319
    // אַחֲרִית, "latter end", which is the LAST WORD OF 23:10 — the importer
    // let the previous verse's final number fall into this verse's first run.
    expect(tagOf('numbers', '23:11', '巴勒'), 'H1111');
    // Nothing was displaced: H319 is still reachable in 23:10, where the run
    // 我愿如义人之终而终。 renders וּתְהִי אַחֲרִיתִי כָּמֹהוּ and is right.
    expect(tagOf('numbers', '23:10', '我愿如义人之终而终。'), 'H319');
    // And the repair invented nothing — H319 really is absent from 23:11.
    final numbers23 = readJson('assets/originals/numbers.json');
    final hebrew = <String>{
      for (final w in (numbers23['23:11'] as List))
        ((w as Map<String, dynamic>)['s'] ?? '') as String
    };
    expect(hebrew, isNot(contains('H319')));
    expect(hebrew, contains('H1111'));

    // The eighth, 2026-09-03, and the first this audit CANNOT see. 耶 38:16's
    // 寻索 ("seek out") answered H834 אֲשֶׁר, *which*, where the Hebrew is
    // אֲשֶׁר מְבַקְשִׁים. 寻索 is H1245 in 16 of its 17 Hebrew occurrences and
    // its one Greek occurrence is G2212 ζητέω, the same sense — but 17 is
    // below the >= 20 bar, so no dominant number is admitted and no hit is
    // raised. It came from another agent's pass over word-less runs.
    expect(tagOf('jeremiah', '38:16', '寻索'), 'H1245');
    // Nothing displaced: the verse has two אֲשֶׁר and 我指着那 still shows it.
    expect(tagOf('jeremiah', '38:16', '我指着那'), 'H834');
    // 以西結書 35:14 came over with it and is NOT repaired: 如此说： answers
    // H559 אָמַר, which 说 does render, so it is partial and not false — and
    // 如此说 is tagged H3541 nowhere in the corpus, so there is nothing to
    // promote it to on evidence.
    expect(tagOf('ezekiel', '35:14', '如此说：'), 'H559');
  });

  /// **A number can be untappable in a second way, and the census does not
  /// count it.** `shown` above takes a run's `s` whether or not the run has
  /// any characters to tap, so a number parked on a run with empty `w` looks
  /// reachable and is not — the same mistake as counting `i`, one level
  /// further in. 耶利米書 38:16 was exactly that: H1245 sat on a word-less run
  /// while the text that renders it, 寻索, answered אֲשֶׁר.
  ///
  /// This pins the size so the next pass need not rediscover it. The word-less
  /// runs themselves belong to another pass; nothing here asserts they are
  /// wrong, only that the census cannot see through them.
  test('word-less runs hide numbers from the census — 23 verses', () {
    var wordless = 0;
    var wordlessTagged = 0;
    final affected = <String>{};
    for (final book in books) {
      final originalsFile = File('assets/originals/$book.json');
      final originals =
          originalsFile.existsSync() ? readJson('assets/originals/$book.json') : null;
      (tagged[book]!).forEach((ref, runsRaw) {
        final runs = (runsRaw as List).cast<Map<String, dynamic>>();
        for (final run in runs) {
          if (((run['w'] ?? '') as String).replaceAll(notCjk, '').isEmpty) {
            wordless++;
            if (((run['s'] ?? '') as String).isNotEmpty) wordlessTagged++;
          }
        }
        if (originals == null) return;
        final refs = ((merged[book] as Map<String, dynamic>?)?[ref] ??
                (base[book] as Map<String, dynamic>?)?[ref] ??
                [ref]) as List;
        final present = <String>{};
        for (final originalRef in refs) {
          for (final word in (originals[originalRef] as List? ?? const [])) {
            final n = ((word as Map<String, dynamic>)['s'] ?? '') as String;
            if (n.isNotEmpty) present.add(n);
          }
        }
        if (present.isEmpty) return;
        final tappable = <String>{
          for (final r in runs)
            if (((r['s'] ?? '') as String).isNotEmpty &&
                ((r['w'] ?? '') as String).replaceAll(notCjk, '').isNotEmpty)
              r['s'] as String
        };
        final all = <String>{
          for (final r in runs)
            if (((r['s'] ?? '') as String).isNotEmpty) r['s'] as String
        };
        if (all.difference(tappable).intersection(present).isNotEmpty) {
          affected.add('$book $ref');
        }
      });
    }
    expect(wordless, 312);
    expect(wordlessTagged, 36);
    expect(affected, hasLength(23),
        reason: 'verses where a number present in the original is some run\'s '
            '`s` ONLY on a run with no tappable text. The census above is a '
            'floor by this much, on top of the >= 20-occurrence floor. This '
            'was 24 when first measured on 2026-09-03 and the repair of '
            '耶利米書 38:16 in the same pass closed one of them: H1245 had '
            'been reachable only on that verse\'s word-less run, and putting '
            'it on 寻索 — the text that renders it — made it tappable. The '
            'other 23 are untriaged, and 以西結書 35:14 is one of them');
    // 以西結書 35:14 is still in the set: H3541 כֹּה remains on a word-less
    // run there, and that is a coverage gap left standing on purpose, because
    // 如此说： answers H559 which 说 genuinely renders.
    expect(affected, contains('ezekiel 35:14'));
    // 耶利米書 38:16 is the one that left.
    expect(affected, isNot(contains('jeremiah 38:16')));
  });

  test('the residue of the core is still flagged, so the tool still bites', () {
    Map<String, Object> hit(String where, String text) => hits.firstWhere(
        (h) => h['where'] == where && h['text'] == text,
        orElse: () => throw StateError('$where $text is no longer flagged; if '
            'it was repaired, drop it here and lower the counts above'));

    // Held with two positions on record — a sweep must not resolve these
    // quietly in either direction. See docs/autonomous-queue.md.
    expect(hit('2_chronicles 4:3', '海')['spans'], isFalse);
    expect(hit('philippians 1:29', '基督')['spans'], isFalse);
    expect(hit('1_john 5:3', '神')['spans'], isFalse);
    expect(hit('jeremiah 33:1', '耶利米')['spans'], isFalse);
    // A plain false positive: 撒上 13:6 opens וְאִישׁ יִשְׂרָאֵל, so 百姓 is
    // H376 and must stay H376.
    expect(hit('1_samuel 13:6', '百姓')['spans'], isFalse);

    // The two survivors of the `absent` bucket, left standing 2026-09-03 with
    // a measured reason each. Neither is a sweep candidate.
    //
    // 利未記 4:17 血 shows H853, and `audit_strongs_tagging.py` ALREADY
    // dismisses it — H853's lexicon headword אֵת is printed verbatim in the
    // verse (token 10, which `assets/originals` tags H854, the twin spelling),
    // so it lands in that audit's "headword printed in the verse" bucket, the
    // Strong's-convention class it says fixing would make the app less
    // accurate. That dismissal is sound for ITS question and does not settle
    // this one, but three readings are defensible and none is clearly right:
    // promote H1818 (the verse's one דָּם is already covered by 血中's `i`),
    // correct H853 to the H854 the originals actually carry, or mark the run
    // supplied — the Hebrew וְהִזָּה has no explicit object and CUV supplies
    // 血. The third is the `H0` question, which is not this pass's to answer.
    expect(hit('leviticus 4:17', '血')['absent'], isTrue);
    //
    // 詩篇 119:126 這是雅伟 shows H3069 where the verse has H3068. Recorded as
    // "trivial — the two YHWH pointings", and it is, but the reason not to
    // touch it is that it is NOT a one-off: 61 runs corpus-wide are tagged
    // H3069 in verses whose original has H3068 and no H3069, and H3069 is a
    // number both datasets use in earnest (306 tokens in `assets/originals`,
    // and 272 H3069 runs sit in verses that really do have it). So this is a
    // systematic disagreement about where the אֲדֹנָי pointing applies, and
    // repairing the single instance the audit happens to see would make the
    // corpus less consistent, not more. A publisher question, not a repair.
    expect(hit('psalms 119:126', '这是雅伟')['absent'], isTrue);
    // The `spans` bucket still bites too, on the 14 the span repair refused.
    // 誡 carries H1697 in both its other corpus occurrences (申 4:13, 10:4,
    // where 十誡 = הַדְּבָרִים), so 誡命 does render דִּבְרֵי and the current
    // number is partial, not false.
    expect(hit('ezra 7:11', '诫命')['spans'], isTrue);
  });

  /// The span repair promoted the head out of `i` into `s` in 39 runs, so the
  /// tap now answers the word the Chinese renders. Each expectation below
  /// fails on pre-repair data.
  test('the repaired spans answer the word their Chinese renders', () {
    String tagOf(String book, String ref, String text) {
      final runs = (tagged[book]![ref] as List).cast<Map<String, dynamic>>();
      final match = runs.where((r) => r['w'] == text);
      if (match.length != 1) {
        throw StateError('$book $ref has ${match.length} runs "$text"');
      }
      return (match.first['s'] ?? '') as String;
    }

    List<String> impliedOf(String book, String ref, String text) {
      final runs = (tagged[book]![ref] as List).cast<Map<String, dynamic>>();
      final match = runs.firstWhere((r) => r['w'] == text);
      return ((match['i'] as List?) ?? const []).cast<String>();
    }

    // 神 answered ὁ, *the*, and θεός was no run's `s` in either verse.
    expect(tagOf('john', '3:5', '神'), 'G2316');
    expect(tagOf('matthew', '22:37', '神。'), 'G2316');
    // בְּנֵי־יִשְׂרָאֵל contracted to the bare nation name: the run showed בֵּן.
    expect(tagOf('exodus', '4:29', '以色列'), 'H3478');
    // וּמִן־בְּנֵי: the run showed מִן, *from*, which no character spells.
    expect(tagOf('1_chronicles', '27:3', '的子孙，'), 'H1121');
    // שָׁלֹשׁ וְעֶשְׂרִים: Chinese reverses the order, so 二十 is עֶשְׂרִים and
    // שָׁלֹשׁ belongs to 三 in the next run.
    expect(tagOf('jeremiah', '52:30', '二十'), 'H6242');

    // Where the displaced number is NOT in the verse's original it is dropped
    // rather than demoted, because `i` asserts the original has it. 以賽亞書
    // 17:3 contains no מִן and 馬太福音 6:8 no θεός.
    expect(tagOf('isaiah', '17:3', '以法莲'), 'H669');
    expect(impliedOf('isaiah', '17:3', '以法莲'), isEmpty);
    expect(tagOf('matthew', '6:8', '父'), 'G3962');
    expect(impliedOf('matthew', '6:8', '父'), isNot(contains('G2316')));

    // Elsewhere the particle is demoted, not deleted: the run keeps every
    // number the importer gave it and only which one is primary changes.
    expect(impliedOf('exodus', '4:29', '以色列'), contains('H1121'));

    // And the held 11 are untouched, because their Chinese spells both words.
    expect(tagOf('2_kings', '3:27', '的长子，'), 'H1121');
    expect(tagOf('genesis', '33:17', '名叫'), 'H7121');

    // Round three. 犹大 spells יְהוּדָה, 一切 spells כֹּל and 永远 spells αἰών,
    // so the `i` these three carried was a false claim about their own text.
    expect(tagOf('1_kings', '1:35', '和犹大'), 'H3063');
    expect(tagOf('numbers', '19:18', '和一切'), 'H3605');
    expect(tagOf('jude', '1:25', '永永远远。'), 'G165');
    // The displaced particle is demoted, never dropped: all three verses do
    // contain it, and a sibling run still shows it.
    expect(impliedOf('1_kings', '1:35', '和犹大'), contains('H5921'));
    expect(impliedOf('numbers', '19:18', '和一切'), contains('H5921'));
    expect(impliedOf('jude', '1:25', '永永远远。'), contains('G3956'));
    expect(tagOf('1_kings', '1:35', '我的位上，'), 'H5921');
    expect(tagOf('numbers', '19:18', '帐棚上，'), 'H5921');
    expect(tagOf('jude', '1:25', '从万古'), 'G3956');
    // 王上 1:35 had been settled the other way by the same pass: 以色列 there
    // covers עַל־יִשְׂרָאֵל and already carries H5921 in `i`. Holding 和犹大
    // for the opposite reason made one verse contradict itself.
    expect(tagOf('1_kings', '1:35', '以色列'), 'H3478');
    expect(impliedOf('1_kings', '1:35', '以色列'), contains('H5921'));
  });

  /// What the span repair GAVE UP, recomputed rather than asserted.
  ///
  /// Promoting `s` to the word the Chinese renders displaces whatever `s` held
  /// before. `i` is inert — no widget reads it — so once the displaced number
  /// is no run's `s` anywhere in the verse, no tap can reach it. A draft of
  /// `tools/repair_strongs_spans.py` called that cost-free and got 約翰福音
  /// 3:5 backwards: both 神 and 的国。 showed G3588 there beforehand, so ὁ was
  /// reachable twice while θεός and βασιλεία were reachable nowhere. The trade
  /// is worth making; it is still a trade, and these figures are the size of
  /// it.
  test('the span repair left 30 displaced numbers unreachable', () {
    // (book, ref, run text, the number the run showed before the repair).
    const displaced = <List<String>>[
      ['ephesians', '2:15', '律法', 'G3588'],
      ['ephesians', '2:18', '父', 'G3588'],
      ['john', '1:32', '圣灵，', 'G3588'],
      ['john', '3:5', '的国。', 'G3588'],
      ['john', '3:5', '神', 'G3588'],
      ['luke', '11:2', '名', 'G3588'],
      ['luke', '11:39', '法利赛人', 'G3588'],
      ['mark', '15:10', '祭司长', 'G3588'],
      ['matthew', '22:37', '神。', 'G3588'],
      ['philippians', '3:3', '的灵', 'G3588'],
      ['deuteronomy', '31:2', '约但河。’', 'H853'],
      ['deuteronomy', '5:3', '约', 'H853'],
      ['genesis', '19:15', '女儿', 'H853'],
      ['1_chronicles', '24:3', '的子孙', 'H4480'],
      ['1_chronicles', '27:3', '的子孙，', 'H4480'],
      ['isaiah', '17:3', '以法莲', 'H4480'],
      ['isaiah', '17:3', '大马色', 'H4480'],
      ['isaiah', '2:3', '锡安；', 'H4480'],
      ['1_kings', '1:35', '以色列', 'H5921'],
      ['deuteronomy', '33:8', '水', 'H5921'],
      ['numbers', '7:89', '柜', 'H5921'],
      ['1_kings', '15:6', '日子', 'H3605'],
      ['2_chronicles', '11:13', '祭司', 'H3605'],
      ['deuteronomy', '12:1', '的日子，', 'H3605'],
      ['genesis', '10:21', '子孙', 'H3605'],
      ['exodus', '4:29', '以色列', 'H1121'],
      ['jeremiah', '27:3', '亚扪', 'H1121'],
      ['numbers', '8:9', '以色列', 'H1121'],
      ['joshua', '21:26', '子孙', 'H4940'],
      ['matthew', '6:8', '父', 'G2316'],
      ['acts', '2:29', '“弟兄们！', 'G435'],
      ['acts', '2:37', '弟兄们，', 'G435'],
      ['deuteronomy', '17:11', '你的律法，', 'H6310'],
      ['ecclesiastes', '6:12', '日子，', 'H4557'],
      ['ezekiel', '38:14', '之日，', 'H1931'],
      ['joshua', '8:29', '晚上。', 'H6256'],
      ['zechariah', '14:7', '晚上', 'H6256'],
      ['jeremiah', '52:30', '二十', 'H7969'],
      // Round three, 2026-09-03. All three land in `survived`, which is the
      // whole point of admitting them: the displaced number is still shown by
      // a sibling run of the same verse, so these three promotions cost the
      // reader nothing. That is the claim 約翰福音 3:5 disproved for the other
      // 39, and it is checked here rather than asserted in prose.
      ['1_kings', '1:35', '和犹大', 'H5921'],
      ['numbers', '19:18', '和一切', 'H5921'],
      ['jude', '1:25', '永永远远。', 'G3956'],
    ];

    final unreachable = <String>{};
    final survived = <String>{};
    var runsInLosingVerses = 0;
    var runsWhoseNumberSurvived = 0;
    for (final row in displaced) {
      final book = row[0], ref = row[1], text = row[2], number = row[3];
      final runs =
          (tagged[book]![ref] as List).cast<Map<String, dynamic>>();
      // The promotion must have happened: no run of this text still shows it.
      // 歷代志上 24:3 carries 的子孙 twice, so this row covers two runs.
      final matches = runs.where((r) => r['w'] == text).toList();
      expect(matches, isNotEmpty, reason: '$book $ref has no run "$text"');
      for (final run in matches) {
        expect(run['s'], isNot(number),
            reason: '$book $ref $text still shows the displaced $number');
      }
      final shown = <String>{
        for (final r in runs)
          if (((r['s'] ?? '') as String).isNotEmpty) r['s'] as String
      };
      if (shown.contains(number)) {
        survived.add('$book $ref $number');
        runsWhoseNumberSurvived += matches.length;
      } else {
        unreachable.add('$book $ref $number');
        runsInLosingVerses += matches.length;
      }
    }

    expect(displaced, hasLength(41),
        reason: '41 rows covering 42 runs — 歷代志上 24:3 carries 的子孙 twice');
    // 30 (verse, number) pairs, spread over 33 of the 39 runs, because
    // 歷代志上 24:3, 以賽亞書 17:3 and 約翰福音 3:5 each spend two runs on one
    // loss. Mixing those two counts is what made a draft say "30 of 39".
    expect(unreachable, hasLength(30));
    expect(runsInLosingVerses, 33);
    // The other 9 runs displaced a number that a sibling run still shows —
    // 民數記 7:89's 的施恩座以上 keeps H5921, 腓立比書 3:3's 真受割禮的 keeps
    // G3588 — so those verses lost no coverage at all.
    //
    // 9 runs but only 8 (verse, number) pairs, and the gap is the same
    // runs-vs-pairs trap that the 30/33 above documents, now on the winning
    // side: 王上 1:35 spends TWO runs — 以色列 from the first span pass and
    // 和犹大 from round three — on the single surviving H5921 of 我的位上，.
    expect(survived, hasLength(8));
    expect(runsWhoseNumberSurvived, 9);
    expect(survived, contains('philippians 3:3 G3588'));
    expect(survived, contains('numbers 7:89 H5921'));
    // Round three's three are all here, and that is why they were admitted
    // where the other 11 of the 14 held rows still are not.
    expect(survived, contains('1_kings 1:35 H5921'));
    expect(survived, contains('numbers 19:18 H5921'));
    expect(survived, contains('jude 1:25 G3956'));
    // 太 6:8 is the one removal that is a correction, not a loss: the verse's
    // Greek is ὁ πατὴρ ὑμῶν and contains no θεός, so the tap had been
    // answering 父 with a word that is not in the verse.
    expect(unreachable, contains('matthew 6:8 G2316'));
    final matthew = readJson('assets/originals/matthew.json');
    final greek = <String>{
      for (final w in (matthew['6:8'] as List))
        ((w as Map<String, dynamic>)['s'] ?? '') as String
    };
    expect(greek, isNot(contains('G2316')));
    expect(greek, contains('G3962'));
  });

  /// The argument that nearly justified the repair, kept as a failing test of
  /// itself. "This (run text, number) pair occurs exactly once in 31,102
  /// verses, while the number I want to write carries the same text hundreds
  /// of times" sounds decisive and is worth nothing: hundreds of runs have
  /// that property and 約伯記 3:2 has it and is right.
  test('singleton pairs are not evidence — 335 runs have that property', () {
    final pairs = <String, int>{};
    final byLanguage = <String, Map<String, int>>{};
    for (final verses in tagged.values) {
      for (final runs in verses.values) {
        for (final run in (runs as List).cast<Map<String, dynamic>>()) {
          final text = ((run['w'] ?? '') as String).replaceAll(notCjk, '');
          final number = (run['s'] ?? '') as String;
          if (text.isEmpty || number.isEmpty || number == 'H0') continue;
          pairs.update('$text $number', (v) => v + 1, ifAbsent: () => 1);
          (byLanguage['$text ${number[0]}'] ??= <String, int>{})
              .update(number, (v) => v + 1, ifAbsent: () => 1);
        }
      }
    }

    var singletons = 0;
    for (final book in books) {
      if (!File('assets/originals/$book.json').existsSync()) continue;
      final originals = readJson('assets/originals/$book.json');
      (tagged[book]!).forEach((ref, runsRaw) {
        final runs = (runsRaw as List).cast<Map<String, dynamic>>();
        final refs = ((merged[book] as Map<String, dynamic>?)?[ref] ??
                (base[book] as Map<String, dynamic>?)?[ref] ??
                [ref]) as List;
        final present = <String>{};
        for (final originalRef in refs) {
          for (final word in (originals[originalRef] as List? ?? const [])) {
            present.add(((word as Map<String, dynamic>)['s'] ?? '') as String);
          }
        }
        if (present.isEmpty) return;
        final shown = <String>{
          for (final r in runs)
            if (((r['s'] ?? '') as String).isNotEmpty) r['s'] as String
        };
        for (final run in runs) {
          final text = ((run['w'] ?? '') as String).replaceAll(notCjk, '');
          final number = (run['s'] ?? '') as String;
          if (text.isEmpty || number.isEmpty || number == 'H0') continue;
          if (pairs['$text $number'] != 1) continue;
          final counts = byLanguage['$text ${number[0]}']!;
          final best =
              counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
          if (best.key == number || best.value < 20) continue;
          if (present.contains(best.key) && !shown.contains(best.key)) {
            singletons++;
          }
        }
      });
    }
    // 371 before any repair. The core's six took out four — the other two,
    // 使徒行傳 12:24 and 20:32 where 神 answered G3588, were never in this pool
    // at all, since 神 = G3588 occurs ten times, so the frequency argument did
    // not even cover the whole list it was advanced to justify. The span
    // repair's 39 runs then took out 27 more, and round three's 3 runs took
    // out 4 — the extra being 民 19:18's 众人, which is correct and left the
    // pool only because repairing a sibling run supplied the H3605 whose
    // absence had flagged it. That the pool shrinks as real defects are fixed
    // is not evidence for the argument: 336 remain, and the one checked below
    // is still right.
    expect(singletons, 335);

    // 約伯記 3:2 is one of the 371 and is correct: וַיַּעַן אִיּוֹב וַיֹּאמַר,
    // one Chinese verb for two Hebrew ones, tagged with the first.
    final job = (tagged['job']!['3:2'] as List).cast<Map<String, dynamic>>();
    expect(job, hasLength(1));
    expect(job.first['s'], 'H6030');
    expect((job.first['i'] as List).cast<String>(), contains('H559'));
  });

  /// **How much this pin costs, measured 2026-09-03 rather than guessed.**
  /// Over the 31,086 verses with an original to compare, 23,028 contain at
  /// least one number that is in the original and is no run's `s`. In 21,390
  /// of them — 69% of the whole corpus — at least one such number is sitting
  /// in some run's `i` and would become reachable the moment a widget read
  /// it: 39,868 (verse, number) pairs, led by H853 אֵת (5,923), G3588 ὁ
  /// (5,342), H413 אֶל (1,640) and G2532 καί (1,611). A further 14,439 pairs
  /// are not in any `i` and surfacing it would not help them.
  ///
  /// That reframes the span repair's price. The 30 numbers it left
  /// unreachable are 0.075% of a backlog of the same kind that the corpus
  /// already carried everywhere — so "the reader only gains" was false, but
  /// "the repair caused this condition" would be false too. The condition is
  /// the norm and the repair added 30 to it.
  ///
  /// Whether to surface `implied` as a secondary line is NOT a loop
  /// iteration's call, which is why this stays a pin and not a change:
  /// `TaggedRun.implied` is already parsed and carried, and its own doc
  /// comment says "Worth showing as secondary, never as the word's own
  /// identity", so the data model anticipated the display. But turning it on
  /// changes what a reader sees on 21,390 verses at once, and it would
  /// invalidate the premise of this entire census — every count above is
  /// computed on `s` alone. Ask before doing it.
  test('`i` is inert, which is why the census counts `s` alone', () {
    final source =
        File('lib/services/tagged_text_service.dart').readAsStringSync();
    expect(source.contains("j['i']"), isTrue,
        reason: 'the field is still parsed into TaggedRun.implied');
    final widgets = Directory('lib/widgets')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final widget in widgets) {
      expect(widget.readAsStringSync().contains('implied'), isFalse,
          reason: '${widget.path} reads `implied`. If a widget ever displays '
              'it, the premise of this whole census changes: a number sitting '
              'in `i` would then be reachable and the count is too high.');
    }
  });
}
