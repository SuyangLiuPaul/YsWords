// Guards the ordering bug fixed 2026-08-07: picking 创世纪 31 from the
// desktop sidebar while reading 创世纪 28 left the reader on 28's text
// under a header that said 31. The picker queued the verse jump BEFORE
// the chapter changed, so the index resolved against the old chapter.
//
// The pure pieces are what a regression would break, so they are what is
// tested: which index a verse maps to inside a chapter, and that a
// missing verse degrades to "no target" rather than to index 0 — which
// would silently send the reader to verse 1 of the wrong place.
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/navigate_to_chapter_verse.dart';

class _V {
  _V(this.chapter, this.verse);
  final int chapter;
  final int verse;
}

void main() {
  group('verseIndexIn', () {
    final chapter = [_V(31, 1), _V(31, 2), _V(31, 3), _V(31, 4)];

    test('verse 1 is index 0, not "no target"', () {
      // The bug's sharpest edge: index 0 is a real destination, so any
      // `if (index)`-style truthiness check reintroduces it.
      expect(verseIndexIn(chapter, 1), 0);
    });

    test('maps a mid-chapter verse to its position', () {
      expect(verseIndexIn(chapter, 3), 2);
    });

    test('a null verse means no specific target', () {
      expect(verseIndexIn(chapter, null), isNull);
    });

    test('a verse the chapter does not have yields null, never 0', () {
      // Partial-canon editions really do omit verses. Falling back to
      // index 0 would look like a successful jump to the wrong verse.
      expect(verseIndexIn(chapter, 99), isNull);
      expect(verseIndexIn(const [], 1), isNull);
    });

    test('index is a position, not a verse number', () {
      // Where a translation omits verse 2, verse 3 sits at index 1.
      final gapped = [_V(31, 1), _V(31, 3), _V(31, 4)];
      expect(verseIndexIn(gapped, 3), 1);
      expect(verseIndexIn(gapped, 2), isNull);
    });
  });
}
