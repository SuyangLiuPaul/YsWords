import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/tagged_text_service.dart';

/// The word-tap corpus printed `主*` as scripture, and the fix deleted it.
/// **The deletion was wrong.** This file records both, because the wrong
/// reasoning is the more useful half.
///
/// What was true: `assets/tagged/cuvs-yhwh/` is rendered verbatim by
/// `originals_sheet.dart` in place of the reader's verse, so 哥林多前書 2:8
/// read 「就不把榮耀的主* 釘在十字架上了」 — 124 asterisks across 115 verses,
/// every one on screen, because `coversVerse` compares ideographs and cannot
/// see a character that was never in the verse. A reader should not be shown
/// a bare asterisk.
///
/// What was wrong: the conclusion that there was **nothing to restore**. The
/// 2026-08-24 argument ran —
///
///   *"This edition marks a referent with a bracket and uses it freely in the
///   NT — 主[雅偉] in 197 reading verses, [基督] in 15 — and the overlap with
///   these 115 is zero and zero. All 115 being NT kills the reading that the
///   asterisk is a divine-name convention rather than supporting it."*
///
/// Both halves fail on one fact from the user, 2026-09-02: the edition marks
/// 主 **three** ways — `主[雅偉]` Yahweh, `主#` 基督, `主*` 耶穌. Zero overlap
/// with the other two is what a THIRD marker looks like, not what noise looks
/// like; and NT-only is exactly the distribution 耶穌 must have. The evidence
/// was read as refuting the convention when it was the convention's
/// signature.
///
/// The reading assets could not settle it either, because the same asterisk
/// had already been deleted from them — 121 occurrences on 2025-05-17 under
/// the title "remove 主*", two more on 2026-08-10. "The reading verse reads a
/// plain 主 at all 115" was true, and it was true because of an earlier
/// deletion, not because the publisher printed a plain 主.
///
/// 123 of the 124 are back, written `主[耶稣]` to match the precedent that
/// turned `主#` into `主[基督]`, by `tools/restore_cuv_jesus_marker.py`.
///
/// The 124th is 使徒行傳 9:29, and it is skipped on purpose: the corpus marks
/// it and the reading assets never have, in any version back through 2025, so
/// the two imports disagree at source rather than one of them having lost it.
/// Restoring it would print 耶稣 on screen in a verse whose scripture does not
/// contain the word — and `tagged_rendered_duplication_test.dart` caught
/// exactly that when the first pass restored all 124. Worth asking the
/// publisher; not worth guessing.
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

  test('no bare asterisk reaches a reader', () {
    // Still the original requirement, and still right: whatever the marker
    // MEANS, an unexplained `*` in the middle of a verse is not readable.
    // It is now carried as a bracket, which this app already renders as an
    // editorial gloss.
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
        reason: 'the marker belongs in brackets, not as a raw asterisk: '
            '${offenders.join(', ')}');
  });

  test('the verses that carried one now name their referent', () {
    expect(verse('1_corinthians', '2:8'), contains('荣耀的主[耶稣]钉在十字架'));
    expect(verse('matthew', '20:33'), contains('主[耶稣]啊，要我们的眼睛'));
    expect(verse('revelation', '11:8'), contains('他们的主[耶稣]钉十字架之处'));
    // The two where a space stood between 主 and the marker, which is why a
    // pattern anchored on `主*` alone missed them on the first pass.
    expect(verse('luke', '24:34'), contains('主[耶稣]果然复活'));
    expect(verse('matthew', '9:28'), contains('主[耶稣]啊，我们信'));
  });

  test('the tagged corpus and the reading assets agree on the marker', () {
    // The old version of this test asserted the reading assets "never used an
    // asterisk in the first place". They did; it had been deleted. What must
    // hold is that the two sides carry the SAME notation, since the word-tap
    // sheet prints the tagged line in place of the reading verse.
    for (final name in const ['cuvs-yhwh.json', 'cuvs-yhwh-tr.json']) {
      final rows = (json.decode(File('assets/$name').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      expect(rows, hasLength(31102), reason: name);
      expect(rows.where((r) => (r['text'] as String).contains('*')), isEmpty,
          reason: '$name should carry the bracket, not the raw asterisk');
      final marker = name.endsWith('-tr.json') ? '主[耶穌]' : '主[耶稣]';
      expect(rows.where((r) => (r['text'] as String).contains(marker)),
          hasLength(114),
          reason: '$name lost the restored marker');
    }
  });

  test('a split marker keeps its word rather than emptying its run', () {
    // Unchanged and still load-bearing. The importer split 19 markers into
    // runs of their own: `{"w":"主","s":"G3588"}, {"w":"* ","s":"G2962"}`.
    // Leaving the Strong's number with no text would make κύριος unreachable
    // — tapping 主 would answer G3588, ὁ, the article. So 主 lives in the
    // marker's run, and the restored bracket goes with it.
    final john2013 = runsOf('john', '20:13');
    final lord = john2013.firstWhere((r) => r['w'] == '主[耶稣]');
    expect(lord['s'], 'G2962');
    expect((lord['i'] as List).cast<String>(), ['G3588']);
    expect(john2013.where((r) => (r['w'] as String).contains('主')),
        hasLength(1));

    // Where the preceding run holds more than 主, only 主 takes κύριος —
    // merging the phrase would have made 有人把 answer κύριος too.
    final john202 = runsOf('john', '20:2');
    expect(john202.map((r) => r['w']),
        containsAllInOrder(['有人把', '主[耶稣]']));
    expect(john202.firstWhere((r) => r['w'] == '有人把')['s'], 'G3588');
    expect(john202.firstWhere((r) => r['w'] == '主[耶稣]')['s'], 'G2962');
  });

  test('馬太福音 9:28 no longer doubles its 說', () {
    // A separate defect that shared this verse: the tagged line read
    // 「耶穌說說：」 for 「耶穌說：」. Repaired by
    // `repair_tagged_rendered_duplication.py`; pinned here so a later sweep
    // over this verse cannot quietly undo it.
    expect(verse('matthew', '9:28'), contains('耶稣说：“你们信'));
    expect(verse('matthew', '9:28'), isNot(contains('说说')));
  });

  test('every restored verse still covers the verse the reader is on', () {
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
