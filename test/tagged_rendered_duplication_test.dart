import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/services/tagged_text_service.dart';

/// Seven verses printed a character of scripture twice on the word-tap sheet.
///
/// `originals_sheet.dart` renders `assets/tagged/cuvs-yhwh/` **verbatim in
/// place of** the reader's verse whenever `coversVerse` passes, and
/// `coversVerse` only asks whether the reader's ideographs survive as a
/// SUBSEQUENCE of the tagged line. A tagged line that has GAINED a character
/// therefore passes it and is printed: 馬太福音 9:28 showed 「耶穌說說：」 over
/// a verse reading 「耶穌說：」, 撒母耳記上 20:37 showed 「箭箭不是在你前頭嗎」,
/// 列王紀下 10:5 showed 「我們我們是你的僕人」.
///
/// The class was found by asking a question the existing audits do not ask.
/// `audit_tagged_running_text.py` strips notes from both sides and reports
/// where OUR text lost a character; its table dismisses exactly these seven as
/// "an artifact on the tagged side — ours is right, do not repair towards the
/// tagged copy". That is true of the reading text and says nothing about what
/// the sheet prints. `audit_tagged_rendered_extras.py` asks instead which
/// verses PASS the guard while reading long: 113 of 31,102, of which 89 are
/// note formatting, 17 are apparatus or supplied readings, and these 7 are
/// characters no edition has. The four supplied readings were repaired on
/// 2026-09-03 (`tagged_supplied_word_deletions_test.dart`), which is why the figures
/// pinned below are 102 and 13 rather than 113 and 17.
///
/// That census is measured RAW against RAW. Production is not:
/// `originals_sheet` passes `sanitizeForSearch(vo.verse.text)`, so the
/// reader's `<note: …>` is gone while the tagged line still inlines it as
/// `〔…〕`, and on that input the class is 1,149 — dominated by the asymmetry
/// rather than by scripture. The raw census is a strict subset of it, so a
/// defect found in it is a defect on screen; the test below pins the
/// production number directly.
///
/// Only duplications were repaired in this pass, because deleting is the safe
/// direction only when the added text is impossible. The four verses where the
/// tagged import supplied a whole WORD were left alone and queued — 士師記
/// 15:5's 葡萄園 renders כֶּרֶם, which that verse's Hebrew really has — and
/// went on their own evidence four months later, once it was established that
/// `assets/originals/` carries that Hebrew independently of this corpus. See
/// `tagged_supplied_word_deletions_test.dart`.
///
/// `tools/repair_tagged_rendered_duplication.py` applies it.
void main() {
  final files = Directory('assets/tagged/cuvs-yhwh')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  Map<String, List<TaggedRun>> load(String slug) {
    final file = files.firstWhere((f) => f.path.endsWith('/$slug.json'));
    final decoded = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    return decoded.map((ref, runs) => MapEntry(
          ref,
          (runs as List)
              .map((r) => TaggedRun.fromJson(r as Map<String, dynamic>))
              .toList(growable: false),
        ));
  }

  List<Map<String, dynamic>> rawRuns(String slug, String ref) =>
      ((json.decode(files
                  .firstWhere((f) => f.path.endsWith('/$slug.json'))
                  .readAsStringSync()) as Map<String, dynamic>)[ref] as List)
          .cast<Map<String, dynamic>>();

  String verse(String slug, String ref) =>
      load(slug)[ref]!.map((r) => r.text).join();

  final reading = <String, String>{};
  for (final row
      in (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>()) {
    reading['${row['book']} ${row['chapter']}:${row['verse']}'] =
        row['text'] as String;
  }

  test('none of the seven still doubles a character', () {
    expect(verse('leviticus', '5:7'), contains('他的力量若不够'));
    expect(verse('1_samuel', '20:37'), contains('说：“箭不是在你前头吗'));
    expect(verse('1_kings', '19:18'), contains('屈膝的，未曾与巴力亲嘴'));
    expect(verse('2_kings', '10:5'), contains('说：“我们是你的仆人'));
    expect(verse('job', '31:36'), contains('愿那敌我者所写的状词'));
    expect(verse('ezekiel', '36:1'), contains('你要对以色列山发预言'));
    expect(verse('matthew', '9:28'), contains('耶稣说：“你们信我能作这事吗'));
  });

  test('no verse in the corpus prints more ideographs than the reader\'s verse',
      () {
    // The guard cannot express this: `coversVerse` is a subsequence test, so
    // it passes a line that has gained a character. This is the other half.
    const books = <String>[
      'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy', 'joshua',
      'judges', 'ruth', '1_samuel', '2_samuel', '1_kings', '2_kings',
      '1_chronicles', '2_chronicles', 'ezra', 'nehemiah', 'esther', 'job',
      'psalms', 'proverbs', 'ecclesiastes', 'song_of_solomon', 'isaiah',
      'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea', 'joel', 'amos',
      'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah', 'haggai',
      'zechariah', 'malachi', 'matthew', 'mark', 'luke', 'john', 'acts',
      'romans', '1_corinthians', '2_corinthians', 'galatians', 'ephesians',
      'philippians', 'colossians', '1_thessalonians', '2_thessalonians',
      '1_timothy', '2_timothy', 'titus', 'philemon', 'hebrews', 'james',
      '1_peter', '2_peter', '1_john', '2_john', '3_john', 'jude', 'revelation',
    ];
    final ours = <String, String>{};
    for (final row
        in (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync())
                as List)
            .cast<Map<String, dynamic>>()) {
      ours[row['id'] as String] = row['text'] as String;
    }
    String ideographs(String s) => String.fromCharCodes(
        s.codeUnits.where((u) => u >= 0x3400 && u <= 0x9fff));
    final noteOurs = RegExp(r'<note:[^>]*>');
    final noteTagged = RegExp(r'〔[^〕]*〕|（[^）]*）');

    var long = 0;
    final onScripture = <String>[];
    for (var n = 0; n < books.length; n++) {
      final decoded = json.decode(files
          .firstWhere((f) => f.path.endsWith('/${books[n]}.json'))
          .readAsStringSync()) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final parts = entry.key.split(':');
        final id = '${(n + 1).toString().padLeft(3, '0')}'
            '${parts[0].padLeft(3, '0')}${parts[1].padLeft(3, '0')}';
        final ourText = ours[id];
        if (ourText == null) continue;
        final line =
            (entry.value as List).map((r) => (r as Map)['w'] as String).join();
        if (ideographs(line) == ideographs(ourText)) continue;
        if (!TaggedTextService.coversVerse(
            load(books[n])[entry.key]!, ourText)) {
          continue;
        }
        long++;
        if (ideographs(line.replaceAll(noteTagged, '')) !=
            ideographs(ourText.replaceAll(noteOurs, ''))) {
          onScripture.add('${books[n]} ${entry.key}');
        }
      }
    }
    // 113 before the duplication repair, 106 after, 102 once the four supplied
    // words went too: a repaired verse matches the reader's verse exactly and
    // drops out of the count entirely.
    expect(long, 102);
    // The 13 that remain are apparatus and note wording — enumerated in
    // `audit_tagged_rendered_extras.py`. Neither the seven duplications nor
    // the four supplied words is here any more, and nothing new may appear
    // without a decision.
    expect(onScripture, hasLength(13));
    expect(
        onScripture,
        isNot(anyElement(isIn(<String>[
          'leviticus 5:7',
          '1_samuel 20:37',
          '1_kings 19:18',
          '2_kings 10:5',
          'job 31:36',
          'ezekiel 36:1',
          'matthew 9:28',
        ]))));

    // And the same census on the input production actually uses. It is much
    // larger because `sanitizeForSearch` strips the reader's `<note: …>`
    // while the tagged line keeps the note inlined as `〔…〕`, so most of the
    // difference is that asymmetry rather than scripture. Pinned so the
    // number cannot drift unnoticed; the raw census above is the triaged one.
    var production = 0;
    var fallback = 0;
    for (var n = 0; n < books.length; n++) {
      final tagged = load(books[n]);
      for (final entry in tagged.entries) {
        final parts = entry.key.split(':');
        final id = '${(n + 1).toString().padLeft(3, '0')}'
            '${parts[0].padLeft(3, '0')}${parts[1].padLeft(3, '0')}';
        final ourText = ours[id];
        if (ourText == null) continue;
        final shown = sanitizeForSearch(ourText);
        if (!TaggedTextService.coversVerse(entry.value, shown)) {
          fallback++;
          continue;
        }
        final line = entry.value.map((r) => r.text).join();
        if (ideographs(line) != ideographs(shown)) production++;
      }
    }
    expect(fallback, 223);
    expect(production, 1149);
  });

  test('馬太福音 9:28 keeps the αὐτοῖς the deleted run would have thrown away',
      () {
    // The two runs both carried G3004 (λέγω) — one word split in two, not two
    // words — so they are merged rather than one deleted. The first held
    // i:["G846"], αὐτοῖς, which καὶ λέγει αὐτοῖς ὁ Ἰησοῦς really has.
    final run = rawRuns('matthew', '9:28').firstWhere((r) => r['w'] == '说：“');
    expect(run['s'], 'G3004');
    expect(run['i'], <String>['G846']);
  });

  test('列王紀上 19:18 keeps the second אֲשֶׁר as an untranslated word', () {
    // The verse has two אֲשֶׁר. This translation renders the first 是 and the
    // second not at all, so the run that held 未 had no word to hold. Its
    // number is folded into the following run's `i`. That is the
    // better-attested of the corpus's TWO conventions for an unrendered word,
    // not the only one: 1,455 runs carry H834 in `i`, while 11 keep a number
    // on a run with an empty `w`. The `i` form was chosen because the empty
    // form would have made a 13th zero-width tap target — a lexicon entry
    // opening for a word that is not on the line.
    final runs = rawRuns('1_kings', '19:18');
    expect(runs.where((r) => r['w'] == '未'), isEmpty);
    expect(runs.firstWhere((r) => r['w'] == '是')['s'], 'H834');
    final second = runs.lastWhere((r) => r['w'] == '未曾');
    expect(second['s'], 'H3808');
    expect(second['i'], contains('H834'));
  });

  test('以西結書 36:1 drops the repeat the corpus does not use', () {
    // 以西結書 33:10 and 33:12 set the same construction as 「啊！你」/H859
    // followed by 「要对」/H413, so the second run is the corpus's shape and
    // the repeat belonged to the first.
    final runs = rawRuns('ezekiel', '36:1');
    expect(runs.firstWhere((r) => r['s'] == 'H859')['w'], '啊！你');
    expect(runs.any((r) => r['w'] == '要对' && r['s'] == 'H413'), isTrue);
    for (final ref in <String>['33:10', '33:12']) {
      final other = rawRuns('ezekiel', ref);
      expect(other.any((r) => r['w'] == '啊！你' && r['s'] == 'H859'), isTrue,
          reason: '以西結書 $ref is the evidence for 36:1');
      expect(other.any((r) => r['w'] == '要对' && r['s'] == 'H413'), isTrue);
    }
  });

  test('the repair emptied no run', () {
    // A deletion pass can leave a run holding a number and no word, which
    // `_taggedVerseLine` skips but which is still a lexicon entry for a word
    // that is not on the line. The count is pinned at 12 by
    // `tagged_stray_brackets_test.dart`; this repair must not move it.
    var empty = 0;
    for (final file in files) {
      final decoded =
          json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        for (final run in (entry.value as List).cast<Map>()) {
          if ((run['w'] as String).isEmpty) empty++;
        }
      }
    }
    expect(empty, 12);
  });

  test('all seven still cover the verse the reader is on', () {
    const pairs = <String, String>{
      'leviticus|5:7': '利未记 5:7',
      '1_samuel|20:37': '撒母耳记上 20:37',
      '1_kings|19:18': '列王纪上 19:18',
      '2_kings|10:5': '列王纪下 10:5',
      'job|31:36': '约伯记 31:36',
      'ezekiel|36:1': '以西结书 36:1',
      'matthew|9:28': '马太福音 9:28',
    };
    for (final entry in pairs.entries) {
      final parts = entry.key.split('|');
      expect(
          TaggedTextService.coversVerse(
              load(parts[0])[parts[1]]!, reading[entry.value]!),
          isTrue,
          reason: '${entry.value} must still reach the word-tap sheet');
    }
  });
}
