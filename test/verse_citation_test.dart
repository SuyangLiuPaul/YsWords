import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/utils/verse_citation.dart';

/// 路加福音 23:34 is the only split verse in the app. Copying the whole
/// of it in 灵修 mode used to produce:
///
///     (路加福音 23:34a, 34)
///
/// — reported by the user, 2026-09-02. The data behind it is correct
/// and matches the publisher; the citation was not.
Verse v(int n, {String? label, int sub = 0}) => Verse(
      book: '路加福音',
      chapter: 23,
      verse: n,
      verseLabel: label,
      subVerseOrder: sub,
      text: '',
    );

void main() {
  group('formatVerseRangeLabels', () {
    test('an ordinary selection collapses to a range', () {
      expect(formatVerseRangeLabels([v(3), v(4), v(5)]), '3–5');
      expect(formatVerseRangeLabels([v(3), v(5)]), '3, 5');
      expect(formatVerseRangeLabels([v(7)]), '7');
    });

    test('the WHOLE of a split verse is cited by its number', () {
      // The reported bug: this returned '34a, 34'.
      final both = [v(34, label: '34a', sub: 0), v(34, label: '34', sub: 1)];
      expect(formatVerseRangeLabels(both), '34');
    });

    test('a fragment keeps its letter — that is what a letter is for', () {
      expect(formatVerseRangeLabels([v(34, label: '34a')]), '34a');
    });

    test('a range spanning the split verse still reads as a range', () {
      expect(
        formatVerseRangeLabels([
          v(33),
          v(34, label: '34a', sub: 0),
          v(34, label: '34', sub: 1),
          v(35),
        ]),
        '33–35',
      );
    });

    test('a fragment inside a wider selection does not collapse it', () {
      expect(
        formatVerseRangeLabels([v(33), v(34, label: '34a'), v(35)]),
        '33, 34a, 35',
      );
    });

    test('empty in, empty out', () {
      expect(formatVerseRangeLabels([]), '');
    });
  });

  test('a merged verse keeps its own label', () {
    // The OTHER label shape, and the more common one by far: 21 verses
    // per edition are printed merged, carrying `verse: 20` with
    // `verseLabel: '20-21'`. They are single entries, not split ones,
    // so they take the lone-member branch and print themselves.
    final merged = Verse(
        book: '以弗所书', chapter: 2, verse: 20, verseLabel: '20-21', text: '');
    expect(formatVerseRangeLabels([merged]), '20-21');
    expect(formatVerseRangeLabels([v(19), merged]), '19, 20-21');
  });

  test('the two label shapes in the shipped data are what we think', () {
    // If a SECOND split verse ever lands, the grouping rule
    // ("more than one part present means the whole verse") has to be
    // re-checked against it rather than assumed to generalise.
    final lettered = RegExp(r'[a-dA-D]$');
    for (final f in ['assets/biblexg-v2.json', 'assets/biblexg-v2-tr.json']) {
      final rows = json.decode(File(f).readAsStringSync()) as List;
      final letters = <String>{};
      var ranges = 0;
      for (final r in rows.cast<Map<String, dynamic>>()) {
        final label = r['verseLabel'] as String?;
        if (label == null || label == '${r['verse']}') continue;
        if (lettered.hasMatch(label)) {
          letters.add('${r['book']} ${r['chapter']}:$label');
        } else {
          ranges++;
        }
      }
      expect(letters, hasLength(1), reason: '$f — expected only 路加 23:34a');
      expect(letters.single, endsWith('23:34a'), reason: f);
      expect(ranges, 21, reason: '$f — merged-verse labels');
    }
  });
}
