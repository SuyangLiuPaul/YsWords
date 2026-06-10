import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/reference_parser.dart';

/// 2026-06-11 audit: regression coverage for `parseReference` — the
/// navigation entry point behind verse links in evidence, search,
/// notes and the daily verse. Locks in the fixes from 15289cb
/// (cross-chapter ranges, comma-separated refs, single-chapter books)
/// and 7b869c9 (multi-book `;` chains), which previously had no tests.
void main() {
  group('parseReference — basics', () {
    test('book chapter:verse', () {
      final r = parseReference('John 3:16')!;
      expect(r.englishBook, 'John');
      expect(r.chapter, 3);
      expect(r.verseStart, 16);
      expect(r.verseEnd, 16);
    });

    test('verse range', () {
      final r = parseReference('John 3:16-18')!;
      expect(r.verseStart, 16);
      expect(r.verseEnd, 18);
    });

    test('whole chapter', () {
      final r = parseReference('John 3')!;
      expect(r.chapter, 3);
      expect(r.isWholeChapter, isTrue);
    });

    test('bare book name defaults to chapter 1', () {
      final r = parseReference('Leviticus')!;
      expect(r.englishBook, 'Leviticus');
      expect(r.chapter, 1);
    });

    test('inverted range collapses to the start verse', () {
      final r = parseReference('Genesis 1:5-2')!;
      expect(r.verseStart, 5);
      expect(r.verseEnd, 5);
    });

    test('garbage and empty input return null', () {
      expect(parseReference(''), isNull);
      expect(parseReference('hello world'), isNull);
      // No book — a bare "3:16" is not navigable.
      expect(parseReference('3:16'), isNull);
    });
  });

  group('parseReference — 15289cb regressions', () {
    test('cross-chapter range navigates to the start verse', () {
      final r = parseReference('2 Kings 22:8-23:25')!;
      expect(r.englishBook, '2 Kings');
      expect(r.chapter, 22);
      expect(r.verseStart, 8);
    });

    test('cross-chapter range with en dash (evidence data)', () {
      final r = parseReference('2 Kings 9:2–10:36')!;
      expect(r.englishBook, '2 Kings');
      expect(r.chapter, 9);
      expect(r.verseStart, 2);
    });

    test('comma-separated verse spans navigate to the first span', () {
      final r = parseReference('John 18:31-33, 37-38')!;
      expect(r.englishBook, 'John');
      expect(r.chapter, 18);
      expect(r.verseStart, 31);
      expect(r.verseEnd, 33);
    });

    test('comma-separated chapters navigate to the first chapter', () {
      final r = parseReference('Daniel 2, 7, 8, 11')!;
      expect(r.englishBook, 'Daniel');
      expect(r.chapter, 2);
      expect(r.isWholeChapter, isTrue);
    });

    test('single-chapter book re-interprets chapter as verse', () {
      final r = parseReference('Jude 14-15')!;
      expect(r.englishBook, 'Jude');
      expect(r.chapter, 1);
      expect(r.verseStart, 14);
    });

    test('single-chapter book with a bare number', () {
      final r = parseReference('Jude 14')!;
      expect(r.chapter, 1);
      expect(r.verseStart, 14);
    });

    test('chapter range navigates to the start chapter', () {
      final r = parseReference('Genesis 6-9')!;
      expect(r.englishBook, 'Genesis');
      expect(r.chapter, 6);
      expect(r.isWholeChapter, isTrue);
    });
  });

  group('parseReference — 7b869c9 multi-book chains', () {
    test('semicolon chain navigates to the first reference', () {
      final r =
          parseReference('Isaiah 53; Psalm 22; Micah 5:2; Zechariah 11:12-13')!;
      expect(r.englishBook, 'Isaiah');
      expect(r.chapter, 53);
      expect(r.isWholeChapter, isTrue);
    });
  });

  group('parseReference — Chinese + abbreviations', () {
    test('Chinese single-char abbreviation', () {
      final r = parseReference('约 3:16')!;
      expect(r.englishBook, 'John');
      expect(r.chapter, 3);
      expect(r.verseStart, 16);
    });

    test('tightly-typed Chinese', () {
      final r = parseReference('创1:1')!;
      expect(r.englishBook, 'Genesis');
      expect(r.chapter, 1);
      expect(r.verseStart, 1);
    });

    test('numbered Chinese epistle', () {
      final r = parseReference('1约 1:9')!;
      expect(r.englishBook, '1 John');
      expect(r.verseStart, 9);
    });

    test('English abbreviation with number prefix', () {
      final r = parseReference('1 Cor 13')!;
      expect(r.englishBook, '1 Corinthians');
      expect(r.chapter, 13);
    });

    test('tight English abbreviation', () {
      final r = parseReference('jn3:16')!;
      expect(r.englishBook, 'John');
      expect(r.verseStart, 16);
    });
  });
}
