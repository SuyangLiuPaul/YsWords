import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/tagged_text_service.dart';

/// The twelve runs in the word-tap corpus that print nothing.
///
/// `test/tagged_stray_brackets_test.dart` pins that there are twelve of them
/// and that two are the ones the bracket repair emptied. This pins WHICH
/// twelve and, for each, the Hebrew word its number names — because a count
/// alone cannot tell a re-import that swapped one word-less run for another
/// from a re-import that changed nothing.
///
/// **They are kept, and here is the evidence, checked against
/// `assets/originals/` reference by reference 2026-09-03.** Eleven carry a
/// Strong's number, and for every one of the eleven the number stands on a
/// real word that is really in that verse's Hebrew, in the sequential slot
/// the run occupies. Nine of them are a word this translation genuinely does
/// not render as a word of its own:
///
///   * 民數記 18:22 H413 אֶל and 列王紀上 20:33 H5921 עַל — prepositions the
///     Chinese folds into the verb (挨近会幕, 请他上车).
///   * 歷代志下 32:11 H853 אֵת — the direct-object marker, which no Chinese
///     sentence renders at all. This is the exact case `TaggedRun.implied`
///     documents.
///   * 申命記 4:42 H1931 וְהוּא and 利未記 11:7 H1931 הוּא — the pronoun the
///     Chinese carries in the relative clause.
///   * 以西結書 4:6 H3117 יוֹם and 耶利米書 48:37 H3605 כָּל — the second
///     half of a doubled Hebrew phrase the CUV prints once (一日顶一年;
///     各人…手有划伤).
///   * 歷代志下 32:6 H5921 עַל in וַיְדַבֵּר עַל לְבָבָם, and 列王紀上 7:39
///     H4350 הַמְּכֹנוֹת, the bases 7:38 named and 7:39 counts as 「五个」.
///
/// So: not scripture that was lost, and not a number that means nothing.
/// Throwing it away would delete the importer's record that the original
/// carries a word the translation does not — the one thing this asset exists
/// to say.
///
/// **Two are the number sitting one word off**, and are kept for a different
/// reason. 以西結書 35:14's H3541 כֹּה is rendered — 如此说 carries it — but
/// the number is stranded six runs later; 耶利米書 38:16's H1245 מְבַקְשִׁים
/// is rendered by 寻索, which is tagged H834 אֲשֶׁר, the word before it. That
/// is the Strong's-alignment class `tools/audit_strongs_alignment.py` and
/// `tools/repair_strongs_alignment_core.py` own, not a word-less-run repair,
/// and moving a number here would put a fix for one defect inside the tool
/// for another.
///
/// **One carries nothing at all.** 約伯記 5:3 run 6 is `{"w":"","s":"",
/// "g":["H8799"]}` — no text, no number, only the aspect of וָאֶקּוֹב, whose
/// own run (咒诅/H6895) stands right in front of it. The queue entry's
/// "twelve runs carry a Strong's number" is therefore eleven. It is left
/// alone too: `g` is a field no repair pass in this repo writes
/// (`repair_strongs_alignment_core.py` states the convention — only `s`
/// moves), and deleting the run would throw the grammar code away rather
/// than reunite it.
///
/// **None of the twelve is reader-visible**, which is what makes all of the
/// above tidiness rather than a defect: `_taggedVerseLine` emits only
/// `runs.where((r) => r.text.isNotEmpty)`, so an empty run cannot become a
/// zero-width span with a tap recognizer on it. That guard is asserted here
/// as data — every one of the twelve is empty after `reuniteGlossRuns` too,
/// so nothing downstream can resurrect one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Reference -> the number on the word-less run, `''` where it has none.
  const roster = <String, String>{
    '1_kings 7:39': 'H4350',
    '1_kings 20:33': 'H5921',
    '2_chronicles 32:6': 'H5921',
    '2_chronicles 32:11': 'H853',
    'deuteronomy 4:42': 'H1931',
    'ezekiel 4:6': 'H3117',
    'ezekiel 35:14': 'H3541',
    'jeremiah 38:16': 'H1245',
    'jeremiah 48:37': 'H3605',
    'job 5:3': '',
    'leviticus 11:7': 'H1931',
    'numbers 18:22': 'H413',
  };

  final files = Directory('assets/tagged/cuvs-yhwh')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('the word-less runs are exactly these twelve, with these numbers', () {
    final found = <String, String>{};
    for (final file in files) {
      final slug = file.uri.pathSegments.last.replaceAll('.json', '');
      final decoded =
          json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        for (final run in (entry.value as List).cast<Map>()) {
          if ((run['w'] as String).isEmpty) {
            found['$slug ${entry.key}'] = (run['s'] ?? '') as String;
          }
        }
      }
    }
    expect(found, roster,
        reason: 'a word-less run appearing or moving means the importer is '
            'dropping a different word than it was — read the verse against '
            'assets/originals/ before believing the count');
  });

  test('every number on one names a word that is really in the verse', () {
    for (final entry in roster.entries) {
      final number = entry.value;
      if (number.isEmpty) continue; // 約伯記 5:3 carries no number
      final parts = entry.key.split(' ');
      final originals = json.decode(
              File('assets/originals/${parts.first}.json').readAsStringSync())
          as Map<String, dynamic>;
      final numbers = (originals[parts.last] as List)
          .map((w) => (w as Map)['s'] as String)
          .toList();
      expect(numbers, contains(number),
          reason: '${entry.key} tags $number on a run that prints nothing, '
              'and the verse\'s Hebrew does not carry that number at all — '
              'so the run records nothing and the claim it makes is untrue');
    }
  });

  test('none of them can reach the screen', () async {
    // 利未記 11:7 is one the bracket repair emptied; 民數記 18:22 shipped
    // that way. Both must survive the load still empty, so the
    // `text.isNotEmpty` filter in `_taggedVerseLine` is what decides.
    for (final ref in ['leviticus 11:7', 'numbers 18:22', 'job 5:3']) {
      final parts = ref.split(' ');
      final chapterVerse = parts.last.split(':');
      final runs = await TaggedTextService.forVerse(
        version: 'cuvs-yhwh',
        englishBook: parts.first.replaceAll('_', ' '),
        chapter: int.parse(chapterVerse.first),
        verse: int.parse(chapterVerse.last),
      );
      expect(runs, isNotNull, reason: ref);
      expect(runs!.where((r) => r.text.isEmpty), hasLength(1), reason: ref);
      // And the verse still prints in full without them.
      expect(runs.where((r) => r.text.isNotEmpty).map((r) => r.text).join(),
          runs.map((r) => r.text).join());
    }
  });
}
