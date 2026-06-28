/// 2026-06-15 (v1.3.80): tests for the paragraph-mode reading-bar
/// progress. Locks the contract that the right-edge bar moves SMOOTHLY
/// and PROPORTIONALLY through the chapter in paragraph mode (where each
/// item is a multi-verse group), instead of jumping group-to-group.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/chapter_scroll_progress.dart';

void main() {
  // 2026-06-28 (v1.3.110): the LIVE bar is PIXEL-proportional — it advances
  // evenly with the page length (measured item heights), independent of verse
  // count or paragraph size, in both modes.
  group('pixelScrollFraction', () {
    test('0.0 at the very top', () {
      expect(
        pixelScrollFraction(
            firstIndex: 0,
            firstLeadingEdge: 0.0,
            itemCount: 5,
            itemHeights: {for (var i = 0; i < 5; i++) i: 0.5}),
        0.0,
      );
    });

    test('exactly 1.0 at the chapter bottom', () {
      // 5 items × 0.5 viewport each → total 2.5, maxOffset 1.5. Scrolled so the
      // top three are above the viewport (above = 1.5) = bottom.
      expect(
        pixelScrollFraction(
            firstIndex: 3,
            firstLeadingEdge: 0.0,
            itemCount: 5,
            itemHeights: {for (var i = 0; i < 5; i++) i: 0.5}),
        closeTo(1.0, 1e-9),
      );
    });

    test('uniform items → EVEN, equal progress steps', () {
      final heights = {for (var i = 0; i < 5; i++) i: 0.5};
      double f(int idx) => pixelScrollFraction(
          firstIndex: idx,
          firstLeadingEdge: 0.0,
          itemCount: 5,
          itemHeights: heights);
      // firstIndex 0,1,2,3 → 0, 1/3, 2/3, 1 — equal 1/3 steps.
      expect(f(0), closeTo(0.0, 1e-9));
      expect(f(1), closeTo(1 / 3, 1e-9));
      expect(f(2), closeTo(2 / 3, 1e-9));
      expect(f(3), closeTo(1.0, 1e-9));
    });

    test('smooth WITHIN an item via the leading edge (sub-item pixels)', () {
      final heights = {for (var i = 0; i < 3; i++) i: 1.0}; // each = 1 viewport
      // total 3, maxOffset 2. Half-scrolled through item 0 → above 0.5 → 0.25.
      expect(
        pixelScrollFraction(
            firstIndex: 0,
            firstLeadingEdge: -0.5,
            itemCount: 3,
            itemHeights: heights),
        closeTo(0.25, 1e-9),
      );
    });

    test('content that fits on one screen → 0.0 (nothing to scroll)', () {
      expect(
        pixelScrollFraction(
            firstIndex: 0,
            firstLeadingEdge: 0.0,
            itemCount: 2,
            itemHeights: {0: 0.4, 1: 0.4}),
        0.0,
      );
    });

    test('unmeasured items fall back to the running average', () {
      // Only item 0 measured (1.0); avg = 1.0 → others assumed 1.0 too.
      final f = pixelScrollFraction(
          firstIndex: 1,
          firstLeadingEdge: 0.0,
          itemCount: 4,
          itemHeights: {0: 1.0});
      expect(f, closeTo(1 / 3, 1e-9)); // above 1.0 / maxOffset 3.0
    });

    test('degenerate inputs never throw', () {
      expect(
        pixelScrollFraction(
            firstIndex: 0,
            firstLeadingEdge: 0,
            itemCount: 0,
            itemHeights: const {}),
        0.0,
      );
      expect(
        pixelScrollFraction(
            firstIndex: 99,
            firstLeadingEdge: 0,
            itemCount: 3,
            itemHeights: {0: 1.0, 1: 1.0, 2: 1.0}),
        inInclusiveRange(0.0, 1.0),
      );
    });
  });

  // 2026-06-28 (v1.3.109): the BAR is an even scroll fraction measured in VERSE
  // units (header → verse 0, footer → last verse), so the small header/footer
  // spacers no longer make it lurch at the start/end. 0.0 at the top, exactly
  // 1.0 the instant the chapter bottom is reached.
  //
  // Test layout: a 24-verse verse-by-verse chapter. Items: 0 = header (→ v0),
  // items 1..24 = the 24 verses (item k → verse k-1), item 25 = footer (absent
  // from the map → end). groupCount = 24, totalVerses = 24.
  group('chapterScrollFraction (verse units)', () {
    final itemToVerse = <int, int>{0: 0, for (var k = 1; k <= 24; k++) k: k - 1};
    double frac(double top, double bottom) => chapterScrollFraction(
          topPos: top,
          bottomPos: bottom,
          itemToVerseIndex: itemToVerse,
          groupCount: 24,
          totalVerses: 24,
        );

    test('0.0 at the very top (header + first verses on screen)', () {
      expect(frac(0.0, 4.0), 0.0); // topVerse 0 → above 0
    });

    test('exactly 1.0 when the footer (chapter bottom) is reached', () {
      // bottomPos in the footer (index 25) → bottomVerse == totalVerses.
      expect(frac(19.0, 25.0), 1.0);
    });

    test('reaches 1.0 even though the top-visible verse is ~19/24', () {
      expect(frac(19.5, 25.0), 1.0);
    });

    test('header scroll does NOT jump the bar (stays 0 while header passes)',
        () {
      // Scrolling THROUGH the header (topPos 0→1) keeps topVerse at 0, so the
      // bar must not move yet — this is the "start no longer speeds up" fix.
      expect(frac(0.0, 4.0), 0.0);
      expect(frac(0.5, 4.5), frac(0.0, 4.0));
    });

    test('monotonic + within [0,1] across the whole chapter', () {
      double prev = -1;
      for (var top = 0.0; top <= 24.0; top += 0.5) {
        final bottom = (top + 5).clamp(0.0, 25.0);
        final f = frac(top, bottom);
        expect(f, greaterThanOrEqualTo(prev - 1e-9));
        expect(f, inInclusiveRange(0.0, 1.0));
        prev = f;
      }
    });

    test('empty chapter never throws', () {
      expect(
        chapterScrollFraction(
            topPos: 0,
            bottomPos: 0,
            itemToVerseIndex: const {},
            groupCount: 0,
            totalVerses: 0),
        0.0,
      );
    });
  });

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

  group('paragraphCurrentVerseIndex (the pill number)', () {
    int v(double itemPos) => paragraphCurrentVerseIndex(
          itemPos: itemPos,
          itemToVerseIndex: itemToVerse,
          groupCount: groupCount,
          totalVerses: totalVerses,
        );

    test('shows the group leading verse at a group boundary', () {
      expect(v(1.0), 0); // group 0 → verse index 0 (label "1")
      expect(v(2.0), 8); // group 1 → verse index 8 (label "9")
      expect(v(3.0), 15); // group 2 → verse index 15 (label "16")
    });

    test('ticks up verse-by-verse WHILE scrolling inside a paragraph', () {
      // group 0 spans verse indices 0..8 over itemPos 1.0..2.0.
      expect(v(1.0), 0);
      expect(v(1.25), 2); // ~verse index 2
      expect(v(1.5), 4); // ~verse index 4 — the number moved without a
      // group change, which is the whole point of this fix.
      expect(v(1.875), 7);
    });

    test('never exceeds the last verse index', () {
      expect(v(4.0), totalVerses - 1); // footer → last verse (19)
      expect(v(999.0), totalVerses - 1);
    });

    test('empty chapter returns 0, never negative', () {
      expect(
        paragraphCurrentVerseIndex(
          itemPos: 2.0,
          itemToVerseIndex: const {0: 0},
          groupCount: 0,
          totalVerses: 0,
        ),
        0,
      );
    });
  });

  // v1.3.83: the SAME helpers now drive verse-by-verse mode, where each
  // paragraph group is a single verse. itemToVerseIndex is then
  // {0:0, 1:0, 2:1, 3:2, …} (item g+1 → verse index g).
  group('verse-by-verse mode (one verse per group)', () {
    const vbvMap = <int, int>{0: 0, 1: 0, 2: 1, 3: 2, 4: 3, 5: 4};
    const vbvGroupCount = 5; // 5 verses → 5 one-verse groups
    const vbvTotal = 5;

    double prog(double itemPos) => paragraphScrollProgress(
          itemPos: itemPos,
          itemToVerseIndex: vbvMap,
          groupCount: vbvGroupCount,
          totalVerses: vbvTotal,
        );
    int num(double itemPos) => paragraphCurrentVerseIndex(
          itemPos: itemPos,
          itemToVerseIndex: vbvMap,
          groupCount: vbvGroupCount,
          totalVerses: vbvTotal,
        );

    test('bar moves SMOOTHLY within a single verse (sub-verse)', () {
      expect(prog(1.0), closeTo(0.0, 0.001)); // top of verse 1
      expect(prog(1.5), closeTo(0.1, 0.001)); // half through verse 1
      expect(prog(2.0), closeTo(0.2, 0.001)); // top of verse 2
      expect(prog(6.0), closeTo(1.0, 0.001)); // footer → bottom
    });

    test('number stays on the verse currently at the top', () {
      expect(num(1.0), 0); // verse 1
      expect(num(1.9), 0); // still verse 1 while scrolling through it
      expect(num(2.0), 1); // verse 2
      expect(num(5.5), 4); // verse 5
      expect(num(6.0), 4); // never past the last verse
    });

    test('progress is monotonic across the whole chapter', () {
      double prev = -1;
      for (var x = 0.0; x <= vbvGroupCount + 1; x += 0.11) {
        final cur = prog(x);
        expect(cur, greaterThanOrEqualTo(prev));
        prev = cur;
      }
    });
  });
}
