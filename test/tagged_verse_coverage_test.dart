import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/book_names.dart';
import 'package:yswords/constants/text_patterns.dart';
import 'package:yswords/services/tagged_text_service.dart';

/// The Originals sheet prints the tagged runs **instead of** the verse,
/// so anything the tagged import lost is missing from a panel that
/// looks like it is quoting the reader's verse in full. On 約伯記 10:20
/// that was a whole clause: the reading asset folds 10:21 into 10:20
/// and marks 10:21 「见上节」, the tagged asset keeps the two apart, and
/// the sheet showed 「我的日子不是甚少吗？求你停手宽容我，」 and stopped.
///
/// A DATA test as well as a unit test. `assets/tagged/cuvs-yhwh/` is a
/// separate import of the same translation, not a tagging of our own
/// reading asset, so the two can drift apart again on any re-import —
/// and nothing else in the suite would notice, because both files are
/// individually well formed. The corpus sweep pins the size of the
/// disagreement so that silent growth turns the suite red.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the tagged line is rendered only when it loses nothing', () {
    test('a lost clause is caught', () {
      // 約伯記 10:20, as the two assets actually hold it.
      const runs = [
        TaggedRun(text: '我的日子', strongs: 'H3117'),
        TaggedRun(text: '不是', strongs: 'H3808'),
        TaggedRun(text: '甚少', strongs: 'H4592'),
        TaggedRun(text: '么？求你停', strongs: 'H2308'),
        TaggedRun(text: '手宽容我，', strongs: 'H7896'),
      ];
      expect(
        TaggedTextService.coversVerse(runs,
            '我的日子不是甚少吗？求你停手宽容我，叫我在往而不返之先─'
            '就是往黑暗和死荫之地以先─可以稍得畅快。'),
        isFalse,
      );
    });

    test('punctuation and quotation marks are not scripture', () {
      const runs = [
        TaggedRun(text: '“起初，', strongs: 'H7225'),
        TaggedRun(text: '神', strongs: 'H430'),
        TaggedRun(text: '创造', strongs: 'H1254'),
        TaggedRun(text: '天', strongs: 'H8064'),
        TaggedRun(text: '地。”', strongs: 'H776'),
      ];
      expect(TaggedTextService.coversVerse(runs, '起初，神创造天地。'), isTrue);
    });

    test('text the tagged import ADDS is no reason to hide the gesture', () {
      // The tagged import prints the edition's 〔…〕 note inline where
      // the reading asset keeps it behind the footnote icon. The verse
      // is still whole, so the reader loses nothing by tapping.
      const runs = [
        TaggedRun(text: '私生子', strongs: 'H4464'),
        TaggedRun(text: '〔或译："外族人"〕必住在', strongs: 'H3427'),
        TaggedRun(text: '亚实突，', strongs: 'H795'),
      ];
      expect(
        TaggedTextService.coversVerse(runs, '私生子（或译：外族人）必住在亚实突，'),
        isTrue,
      );
    });

    test('a single swapped character still counts as a loss', () {
      // 他/它, 吗/么 — the two imports disagree about the character, and
      // the sheet must not quote the reader a word their version does
      // not print.
      const runs = [TaggedRun(text: '它与持守它的作生命树', strongs: 'H6086')];
      expect(
        TaggedTextService.coversVerse(runs, '她与持守她的作生命树'),
        isFalse,
      );
    });

    test('an empty verse cannot lose anything', () {
      expect(TaggedTextService.coversVerse(const [], ''), isTrue);
    });
  });

  test('the corpus disagreement does not grow', () {
    // Re-measured 2026-08-24: 223 of the 31,102 verses that reach the
    // sheet (0.72%) fall back to the plain line, and nothing is dropped
    // before this check any more — the last two verses carrying importer
    // markup were settled, so `compared` is now the whole corpus. The
    // figure is pinned rather than asserted at zero because these are
    // two honest imports of the same translation and the wording
    // variants (姊姊/姐姐, 她/它) are not ours to decide — but a
    // re-import that starts dropping clauses must not slip past.
    //
    // The ratchet only ever tightens. It stood at 236 while the real
    // number had already fallen to 223, so it would not have caught
    // thirteen verses of regression.
    const known = 223;

    final reading = <String, Map<String, String>>{};
    final rows =
        json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List;
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final english = bookNameToEnglish[row['book'] as String];
      expect(english, isNotNull,
          reason: 'unmapped book name ${row['book']} in the reading asset');
      final slug = english!.toLowerCase().replaceAll(' ', '_');
      reading.putIfAbsent(slug, () => {})[
          '${row['chapter']}:${row['verse']}'] = row['text'] as String;
    }

    var compared = 0;
    final uncovered = <String>[];
    for (final file in Directory('assets/tagged/cuvs-yhwh')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))) {
      final slug = file.uri.pathSegments.last.replaceAll('.json', '');
      final book = reading[slug];
      expect(book, isNotNull, reason: 'no reading book matches $slug');
      final decoded =
          json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final verseText = book![entry.key];
        if (verseText == null) continue;
        final raw = entry.value as List;
        // Dropped at load time, so it never reaches the sheet.
        if (TaggedTextService.carriesImporterMarkup(raw)) continue;
        compared++;
        final runs = TaggedTextService.reuniteGlossRuns(raw
            .map((r) => TaggedRun.fromJson(r as Map<String, dynamic>))
            .toList(growable: false));
        if (!TaggedTextService.coversVerse(runs, sanitizeForSearch(verseText))) {
          uncovered.add('$slug ${entry.key}');
        }
      }
    }

    expect(compared, greaterThan(30000),
        reason: 'the sweep must actually open the corpus');
    expect(uncovered, contains('job 10:20'),
        reason: 'the verse this check was written for');
    expect(uncovered.length, lessThanOrEqualTo(known),
        reason: 'the tagged import lost text in ${uncovered.length} verses, '
            'up from $known — a re-import has dropped scripture the '
            'reader\'s verse has: ${uncovered.take(20).join(', ')}');
  });
}
