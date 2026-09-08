import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/services/tagged_text_service.dart';

/// Four verses printed a WORD on the word-tap sheet that this edition does not
/// print, and three of them survived a repair pass that removed seven
/// duplications sitting beside them.
///
///     士師記 15:2   …還美麗嗎？我請求你可以娶來代替她吧！
///     士師記 15:5   …並葡萄園橄欖園盡都燒了。
///     士師記 15:18  …施行這麼大的拯救，現在豈可任我渴死…
///     撒母耳記下 21:2 …卻為以色列人和猶大人大發熱心…
///
/// They were held because `coversVerse` passes them (it is a subsequence test
/// and cannot see added text) and because three of them render something the
/// Hebrew really has — 我請求 = H4994 נָא, 葡萄園 = H3754 כֶּרֶם,
/// 現在 = H6258 עַתָּה. The argument was that deleting them would cost the app
/// its account of the Hebrew.
///
/// **It does not, and that is what unblocked the item.** The Hebrew on this
/// sheet comes from `assets/originals/`, read by `OriginalsService.forVerse`
/// and rendered as the word-chip row under the verse — a different asset with
/// a different provenance from `assets/tagged/`. All four words are there with
/// their own chip and lexicon entry, before and after. The first test below is
/// the one that matters: it asserts the Hebrew is still on screen.
///
/// Four witness lines read the short form: both frozen reading assets, blob
/// `7a2dc43` (the plain 和合本 Traditional, an independent digital line), and
/// the printed 1919 as read by `tools/audit_tagged_rendered_extras.py`.
///
/// `tools/repair_tagged_supplied_words.py` applies it.
///
/// **2026-09-09: the publisher put all four words back, and two of the four
/// witness lines changed sides.** `sync_cuv_yhwh_to_publisher.py` brought the
/// reading assets up to the publisher's current text, and the current text
/// prints 我請求, 葡萄園, 現在 and 大發熱心 — the long readings, the ones the
/// tagged import had all along. So the two frozen reading assets no longer
/// corroborate the deletion; blob `7a2dc43` and the printed 1919 still do, and
/// the publisher's own database row is now the long form for all four
/// (checked directly, not inferred from the sync).
///
/// Nothing here is edited in response. The tagged corpus is left as the
/// 2026-09-03 pass made it, the assertions below still hold over it, and the
/// LAST test is inverted rather than deleted: those four verses now read SHORT
/// against the reader's verse, so `coversVerse` refuses them and the sheet
/// falls back to plain text. That is the guard doing its job — a reader is
/// shown their own verse rather than a line missing a word — and it is
/// asserted here, with the proof that the one missing word is the ONLY
/// difference, so this cannot quietly become a lost clause.
///
/// The one thing that would settle it is a decision, not a test: either the
/// corpus takes the four words back (the reading text is now the publisher's
/// current text and the tagged import agrees with it), or the four verses stay
/// on the plain line. Until then the state is written down here.
void main() {
  Map<String, dynamic> tagged(String slug) => json.decode(
        File('assets/tagged/cuvs-yhwh/$slug.json').readAsStringSync(),
      ) as Map<String, dynamic>;

  List<Map<String, dynamic>> runs(String slug, String ref) =>
      (tagged(slug)[ref] as List).cast<Map<String, dynamic>>();

  String line(String slug, String ref) =>
      runs(slug, ref).map((r) => r['w'] as String).join();

  List<Map<String, dynamic>> originals(String slug, String ref) =>
      ((json.decode(File('assets/originals/$slug.json').readAsStringSync())
              as Map<String, dynamic>)[ref] as List)
          .cast<Map<String, dynamic>>();

  final reading = <String, String>{};
  for (final row
      in (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>()) {
    reading[row['id'] as String] = row['text'] as String;
  }

  test('the deletion cost the sheet no Hebrew word', () {
    // The whole reason the four were held. Each word chip is built from
    // `assets/originals/`, not from the tagged corpus, so every number the
    // deleted text carried is still on screen under the verse.
    expect(originals('judges', '15:2').map((w) => w['s']), contains('H4994'));
    expect(originals('judges', '15:5').map((w) => w['s']), contains('H3754'));
    expect(originals('judges', '15:18').map((w) => w['s']), contains('H6258'));
    expect(
        originals('2_samuel', '21:2').map((w) => w['s']), contains('H7065'));
  });

  test('none of the four supplied words is on the line any more', () {
    expect(line('judges', '15:2'), contains('还美丽吗？你可以娶来代替她吧！'));
    expect(line('judges', '15:2'), isNot(contains('我请求')));
    expect(line('judges', '15:5'), contains('未割的禾稼，并橄榄园尽都烧了'));
    expect(line('judges', '15:5'), isNot(contains('葡萄园')));
    expect(line('judges', '15:18'), contains('这么大的拯救，岂可任我渴死'));
    expect(line('judges', '15:18'), isNot(contains('现在')));
    expect(line('2_samuel', '21:2'), contains('和犹大人发热心'));
    expect(line('2_samuel', '21:2'), isNot(contains('大发热心')));
  });

  test('the two whole-run deletions folded their number, not dropped it', () {
    // A run with a number and no word is a zero-width tap target — a lexicon
    // entry for a word that is not on the line. The corpus's better-attested
    // convention for a word this translation does not render is the FOLLOWING
    // run's `i` (1,455 runs carry one that way against 11 the other), which is
    // what the 列王紀上 19:18 repair chose for the same reason.
    final olives =
        runs('judges', '15:5').firstWhere((r) => r['w'] == '橄榄园');
    expect(olives['s'], 'H2132');
    expect(olives['i'], contains('H3754'));
    expect(runs('judges', '15:5').any((r) => r['w'] == '葡萄园'), isFalse);

    final thirst =
        runs('judges', '15:18').firstWhere((r) => r['w'] == '岂可任我渴');
    expect(thirst['s'], 'H6772');
    expect(thirst['i'], contains('H6258'));
    expect(runs('judges', '15:18').any((r) => r['w'] == '现在'), isFalse);
  });

  test('the two in-run trims kept their word and their number', () {
    final na = runs('judges', '15:2').firstWhere((r) => r['s'] == 'H4994');
    expect(na['w'], '吗？你');
    final zeal =
        runs('2_samuel', '21:2').firstWhere((r) => r['s'] == 'H7065');
    expect(zeal['w'], '发热心，');
    expect(zeal['g'], <String>['H8763']);
  });

  test('the repair emptied no run', () {
    // Pinned at 12 by `tagged_stray_brackets_test.dart`; a deletion pass is
    // exactly the thing that could move it.
    var empty = 0;
    for (final file in Directory('assets/tagged/cuvs-yhwh')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))) {
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

  test('the publisher put the four words back, so all four now fall back to '
      'the plain line — and the word is the only difference', () {
    // Was: "all four still reach the word-tap sheet, and now read exactly".
    // That held while the reading assets read short. They do not any more:
    // the publisher's current text prints all four words, so each of these
    // four tagged lines is now one word SHORT of the reader's verse instead
    // of one word long.
    //
    // Both halves below matter and they say different things.
    //
    //   `coversVerse` is false   — the sheet does not print a line that is
    //       missing a word of the reader's verse. It falls back to plain
    //       text, exactly as it does for any untagged verse. Asserted so
    //       that nobody reads the four green tests above and concludes the
    //       sheet is still showing a tagged line here.
    //   the word is the ONLY difference   — the reader's verse with that one
    //       word taken out IS the tagged line, ideograph for ideograph. This
    //       is what keeps the state above from drifting into a lost clause
    //       while still looking like the same known case.
    String ideographs(String s) => String.fromCharCodes(
        s.codeUnits.where((u) => u >= 0x3400 && u <= 0x9fff));
    // slug|ref : (verse id, the reader's phrase, the corpus's phrase)
    const cases = <String, List<String>>{
      'judges|15:2': ['007015002', '吗我请求你', '吗你'],
      'judges|15:5': ['007015005', '并葡萄园橄榄园', '并橄榄园'],
      'judges|15:18': ['007015018', '拯救现在岂可', '拯救岂可'],
      '2_samuel|21:2': ['010021002', '大发热心', '发热心'],
    };
    for (final entry in cases.entries) {
      final parts = entry.key.split('|');
      final shown = sanitizeForSearch(reading[entry.value[0]]!);
      final taggedRuns = (tagged(parts[0])[parts[1]] as List)
          .map((r) => TaggedRun.fromJson(r as Map<String, dynamic>))
          .toList(growable: false);
      expect(TaggedTextService.coversVerse(taggedRuns, shown), isFalse,
          reason: '${entry.key}: the corpus does not carry the word the '
              'publisher restored, so the guard must hide the tagged line '
              'rather than print a verse with a word missing');
      expect(ideographs(shown), contains(entry.value[1]),
          reason: '${entry.key}: the reader\'s verse should carry the '
              'restored word');
      expect(
          ideographs(taggedRuns.map((r) => r.text).join()),
          ideographs(shown).replaceFirst(entry.value[1], entry.value[2]),
          reason: '${entry.key}: the tagged line must be the reader\'s verse '
              'with exactly that one word missing and nothing else');
    }
  });
}
