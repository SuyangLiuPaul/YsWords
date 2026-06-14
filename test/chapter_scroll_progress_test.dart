/// 2026-06-15 (v1.3.80): tests for the paragraph-mode reading-bar
/// progress. Locks the contract that the right-edge bar moves SMOOTHLY
/// and PROPORTIONALLY through the chapter in paragraph mode (where each
/// item is a multi-verse group), instead of jumping group-to-group.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/chapter_scroll_progress.dart';

void main() {
  // A chapter of 20 verses grouped into 3 paragraphs:
  //   group 0 → verses 0..7  (item 1, leading verse 0)
  //   group 1 → verses 8..14 (item 2, leading verse 8)
  //   group 2 → verses 15..19 (item 3, leading verse 15)
  // Layout: item 0 = header (verse 0), items 1..3 = groups,
  //         item 4 = footer (absent → end of chapter).
  const itemToVerse = <int, int>{0: 0, 1: 0, 2: 8, 3: 15};
  const groupCount = 3;
  const totalVerses = 20;

  double p(double itemPos) => paragraphScrollProgress(
        itemPos: itemPos,
        itemToVerseIndex: itemToVerse,
        groupCount: groupCount,
        totalVerses: totalVerses,
      );

  group('paragraphScrollProgress', () {
    test('top of chapter is 0', () {
      expect(p(0.0), 0.0);
      expect(p(1.0), 0.0); // start of group 0 == verse 0
    });

    test('moves WITHIN a paragraph group (not just at boundaries)', () {
      // Half-way through group 0 (verses 0..8 span) → verse ~4 / 20.
      final halfway = p(1.5);
      expect(halfway, greaterThan(0.0));
      expect(halfway, lessThan(p(2.0)));
      // verse 4 / 20 = 0.2
      expect(halfway, closeTo(0.2, 0.001));
    });

    test('is monotonic as you scroll down', () {
      double prev = -1;
      for (var x = 0.0; x <= groupCount + 1; x += 0.13) {
        final cur = p(x);
        expect(cur, greaterThanOrEqualTo(prev),
            reason: 'progress must never go backwards (itemPos=$x)');
        prev = cur;
      }
    });

    test('group boundaries land on the right verse fraction', () {
      expect(p(2.0), closeTo(8 / 20, 0.001)); // start of group 1
      expect(p(3.0), closeTo(15 / 20, 0.001)); // start of group 2
    });

    test('last group interpolates all the way to the bottom (footer)', () {
      // group 2 spans verses 15..20 (footer → totalVerses=20).
      expect(p(3.0), closeTo(15 / 20, 0.001));
      expect(p(3.5), closeTo(17.5 / 20, 0.001));
      expect(p(4.0), 1.0);
    });

    test('clamps out-of-range input', () {
      expect(p(-5.0), 0.0);
      expect(p(999.0), 1.0);
    });

    test('empty chapter is 0, never NaN', () {
      expect(
        paragraphScrollProgress(
          itemPos: 2.0,
          itemToVerseIndex: const {0: 0},
          groupCount: 0,
          totalVerses: 0,
        ),
        0.0,
      );
    });
  });
}
