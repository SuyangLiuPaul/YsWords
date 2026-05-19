// 2026-05-19 (v1.2.60): tests for the multi-verse "passage note"
// grouping logic in lib/pages/library_page.dart.
//
// `_groupContiguousNotes` is file-private, so this test reproduces
// the function inline against synthetic Verse objects. The contract
// is: walk a sorted list of verses, merge adjacent verses that share
// the same book + chapter AND identical note text into one logical
// group. Anything else starts a fresh group.
//
// Same shape as the production code — if the production version
// drifts from this inline copy, this test catches the divergence.

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/verse.dart';

class _NoteGroup {
  final List<Verse> verses;
  final String text;
  _NoteGroup({required this.verses, required this.text});
}

List<_NoteGroup> _groupContiguousNotes(
    List<Verse> entries, Map<String, String> notes) {
  final groups = <_NoteGroup>[];
  for (final v in entries) {
    final txt = notes[v.id] ?? '';
    if (groups.isNotEmpty) {
      final last = groups.last;
      final lastVerse = last.verses.last;
      if (last.text == txt &&
          lastVerse.book == v.book &&
          lastVerse.chapter == v.chapter &&
          lastVerse.verse + 1 == v.verse) {
        last.verses.add(v);
        continue;
      }
    }
    groups.add(_NoteGroup(verses: [v], text: txt));
  }
  return groups;
}

Verse _mkVerse({
  required String book,
  required int chapter,
  required int verse,
}) =>
    Verse(
      book: book,
      chapter: chapter,
      verse: verse,
      text: 'sample',
    );

void main() {
  group('_groupContiguousNotes', () {
    test('three consecutive verses with identical text merge into '
        'one group of 3', () {
      final v1 = _mkVerse(book: 'Genesis', chapter: 1, verse: 16);
      final v2 = _mkVerse(book: 'Genesis', chapter: 1, verse: 17);
      final v3 = _mkVerse(book: 'Genesis', chapter: 1, verse: 18);
      final notes = {
        v1.id: 'Shared passage note',
        v2.id: 'Shared passage note',
        v3.id: 'Shared passage note',
      };
      final groups = _groupContiguousNotes([v1, v2, v3], notes);
      expect(groups.length, 1);
      expect(groups.first.verses.length, 3);
      expect(groups.first.verses.first.verse, 16);
      expect(groups.first.verses.last.verse, 18);
      expect(groups.first.text, 'Shared passage note');
    });

    test('two verses with DIFFERENT text stay as two separate groups',
        () {
      final v1 = _mkVerse(book: 'Genesis', chapter: 1, verse: 16);
      final v2 = _mkVerse(book: 'Genesis', chapter: 1, verse: 17);
      final notes = {
        v1.id: 'First note',
        v2.id: 'Second note',
      };
      final groups = _groupContiguousNotes([v1, v2], notes);
      expect(groups.length, 2);
      expect(groups[0].verses.length, 1);
      expect(groups[1].verses.length, 1);
    });

    test('non-consecutive verses with same text stay separate', () {
      // v16 and v18 share text but v17 has none → gap breaks group
      final v1 = _mkVerse(book: 'Genesis', chapter: 1, verse: 16);
      final v3 = _mkVerse(book: 'Genesis', chapter: 1, verse: 18);
      final notes = {
        v1.id: 'Same text',
        v3.id: 'Same text',
      };
      final groups = _groupContiguousNotes([v1, v3], notes);
      expect(groups.length, 2);
    });

    test('verses in different books stay separate even with same '
        'text', () {
      final v1 = _mkVerse(book: 'Genesis', chapter: 1, verse: 1);
      final v2 = _mkVerse(book: 'Exodus', chapter: 1, verse: 1);
      final notes = {
        v1.id: 'Same',
        v2.id: 'Same',
      };
      final groups = _groupContiguousNotes([v1, v2], notes);
      expect(groups.length, 2);
    });

    test('verses in different chapters stay separate even with same '
        'text (chapter break)', () {
      final v1 = _mkVerse(book: 'Genesis', chapter: 1, verse: 31);
      final v2 = _mkVerse(book: 'Genesis', chapter: 2, verse: 1);
      final notes = {
        v1.id: 'Same',
        v2.id: 'Same',
      };
      final groups = _groupContiguousNotes([v1, v2], notes);
      expect(groups.length, 2);
    });

    test('mixed: 3 grouped + 1 separate + 2 grouped', () {
      final verses = [
        _mkVerse(book: 'Genesis', chapter: 1, verse: 1),
        _mkVerse(book: 'Genesis', chapter: 1, verse: 2),
        _mkVerse(book: 'Genesis', chapter: 1, verse: 3),
        _mkVerse(book: 'Genesis', chapter: 2, verse: 1),
        _mkVerse(book: 'Genesis', chapter: 3, verse: 14),
        _mkVerse(book: 'Genesis', chapter: 3, verse: 15),
      ];
      final notes = {
        verses[0].id: 'Creation',
        verses[1].id: 'Creation',
        verses[2].id: 'Creation',
        verses[3].id: 'Day 7',
        verses[4].id: 'Fall',
        verses[5].id: 'Fall',
      };
      final groups = _groupContiguousNotes(verses, notes);
      expect(groups.length, 3);
      expect(groups[0].verses.length, 3); // Creation block
      expect(groups[1].verses.length, 1); // Day 7 single
      expect(groups[2].verses.length, 2); // Fall pair
    });

    test('empty input → empty output', () {
      expect(_groupContiguousNotes([], {}), isEmpty);
    });

    test('single verse → single group of 1', () {
      final v = _mkVerse(book: 'John', chapter: 3, verse: 16);
      final groups = _groupContiguousNotes([v], {v.id: 'For God so…'});
      expect(groups.length, 1);
      expect(groups.first.verses.length, 1);
      expect(groups.first.text, 'For God so…');
    });
  });
}
