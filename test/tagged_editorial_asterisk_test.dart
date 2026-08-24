import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/tagged_text_service.dart';

/// The word-tap corpus printed an editorial asterisk as scripture.
///
/// `assets/tagged/cuvs-yhwh/` is rendered verbatim by `originals_sheet.dart`
/// in place of the reader's verse, so 哥林多前書 2:8 read
/// 「就不把榮耀的主* 釘在十字架上了」 and 馬太福音 20:33 read
/// 「主* 啊，要我們的眼睛能看見！」 — 124 asterisks across 115 verses, all of
/// them on 主, all of them in the NT. Every one was on screen: `coversVerse`
/// compares ideographs, so the guard that hides a tagged line which has LOST a
/// word cannot see a character that was never in the verse.
///
/// The rule is measured, not chosen — `*` occurs zero times in the 62,204
/// verses of the two reading assets, and at all 115 references the reading
/// verse reads a plain 主.
///
/// **It is a deletion, not a substitution, and that is the difference from
/// `主#`.** `repair_tagged_markup.py` turns `主#` into 主[基督] in 15 verses,
/// but only because the reading asset prints that gloss at those very
/// references. This edition marks a referent with a bracket and uses it
/// freely in the NT — 主[雅伟] in 197 reading verses, [基督] in 15 — and the
/// overlap with these 115 is zero and zero. There is nothing to restore.
///
/// `tools/repair_tagged_editorial_asterisk.py` applies it.
void main() {
  final files = Directory('assets/tagged/cuvs-yhwh')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  List<Map<String, dynamic>> runsOf(String slug, String ref) {
    final file = files.firstWhere((f) => f.path.endsWith('/$slug.json'));
    final decoded = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    return (decoded[ref] as List).cast<Map<String, dynamic>>();
  }

  String verse(String slug, String ref) =>
      runsOf(slug, ref).map((r) => r['w'] as String).join();

  test('no asterisk survives anywhere in the word-tap corpus', () {
    expect(files, hasLength(66));
    final offenders = <String>[];
    for (final file in files) {
      final slug = file.uri.pathSegments.last.replaceAll('.json', '');
      final decoded =
          json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final text =
            (entry.value as List).map((r) => (r as Map)['w'] as String).join();
        if (text.contains('*')) offenders.add('$slug ${entry.key}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'the reading assets use no asterisk in 62,204 verses, so these '
            'are import residue printed as scripture: ${offenders.join(', ')}');
  });

  test('the verses that carried one now read as the edition prints them', () {
    expect(verse('1_corinthians', '2:8'), contains('荣耀的主钉在十字架'));
    expect(verse('matthew', '20:33'), contains('主啊，要我们的眼睛'));
    expect(verse('revelation', '11:8'), contains('他们的主钉十字架之处'));
    // The two where a space stood between 主 and the marker.
    expect(verse('luke', '24:34'), contains('主果然复活'));
    expect(verse('matthew', '9:28'), contains('主啊，我们信'));
  });

  test('the reading assets never used an asterisk in the first place', () {
    for (final name in const ['cuvs-yhwh.json', 'cuvs-yhwh-tr.json']) {
      final rows = (json.decode(File('assets/$name').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      expect(rows, hasLength(31102), reason: name);
      expect(rows.where((r) => (r['text'] as String).contains('*')), isEmpty,
          reason: name);
    }
  });

  test('a split marker keeps its word rather than emptying its run', () {
    // The importer split 19 markers into runs of their own:
    // `{"w":"主","s":"G3588"}, {"w":"* ","s":"G2962"}`. Deleting the marker
    // alone would leave a Strong's number with no text and make κύριος
    // unreachable — tapping 主 would answer G3588, ὁ, the article. So the 主
    // moves into the marker's run. `{"w":"主","s":"G2962","i":["G3588"]}` is
    // not invented: the corpus already uses that exact shape 125 times.
    final john2013 = runsOf('john', '20:13');
    final lord = john2013.firstWhere((r) => r['w'] == '主');
    expect(lord['s'], 'G2962');
    expect((lord['i'] as List).cast<String>(), ['G3588']);
    expect(john2013.where((r) => r['w'] == '主'), hasLength(1));

    // Where the preceding run holds more than 主, only 主 takes κύριος —
    // merging the phrase would have made 有人把 answer κύριος too.
    final john202 = runsOf('john', '20:2');
    expect(john202.map((r) => r['w']), containsAllInOrder(['有人把', '主']));
    expect(john202.firstWhere((r) => r['w'] == '有人把')['s'], 'G3588');
    expect(john202.firstWhere((r) => r['w'] == '主')['s'], 'G2962');
  });

  test('馬太福音 9:28 no longer doubles its 說', () {
    // Deleting the marker left 114 of the 115 reproducing the reader's verse
    // exactly; this one still read 「耶穌說說：」 for 「耶穌說：」 and was left
    // alone deliberately, because a repair pass that quietly also fixed it
    // would have been undeclared work on scripture. It was then repaired as
    // one of seven duplications by `repair_tagged_rendered_duplication.py` —
    // see `tagged_rendered_duplication_test.dart` for the evidence.
    expect(verse('matthew', '9:28'), contains('耶稣说：“你们信'));
    expect(verse('matthew', '9:28'), isNot(contains('说说')));
  });

  test('every repaired verse still covers the verse the reader is on', () {
    final reading = <String, String>{};
    for (final row
        in (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync())
                as List)
            .cast<Map<String, dynamic>>()) {
      reading['${row['book']} ${row['chapter']}:${row['verse']}'] =
          row['text'] as String;
    }
    for (final probe in const [
      ['1_corinthians', '2:8', '哥林多前书'],
      ['john', '20:13', '约翰福音'],
      ['john', '20:2', '约翰福音'],
      ['luke', '24:34', '路加福音'],
      ['acts', '9:5', '使徒行传'],
    ]) {
      final runs = runsOf(probe[0], probe[1])
          .map(TaggedRun.fromJson)
          .toList(growable: false);
      expect(
          TaggedTextService.coversVerse(runs, reading['${probe[2]} ${probe[1]}']!),
          isTrue,
          reason: '${probe[0]} ${probe[1]}');
    }
  });
}
