import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/passage_filter.dart';
import 'package:yswords/utils/reference_parser.dart';

/// 2026-08-23, from the user, in two messages:
///
///   "I filtered John 17 … I am wondering if it is possible to have
///    yellow highlight whenever John 17 appears inside that specific
///    sermon."
///   "Right now, you only have the chapter. Wonder whether it is
///    possible to have also the verses also."
///
/// Two halves of one idea. [PassageFilter.matchesRefKey] decides which
/// sermons the list shows; [PassageFilter.covers] decides which
/// references inside a sermon get marked. They must agree, or a sermon
/// appears in a filtered list with nothing highlighted in it.
void main() {
  BibleReference ref(String book, int ch,
          {int? v, int? end, List<int> verses = const []}) =>
      BibleReference(
        englishBook: book,
        chapter: ch,
        verseStart: v,
        verseEnd: end,
        verses: verses,
      );

  group('which sermons the list shows', () {
    test('a book filter takes every chapter of that book', () {
      const f = PassageFilter('John');
      expect(f.matchesRefKey('John 17'), isTrue);
      expect(f.matchesRefKey('John 3:16'), isTrue);
      expect(f.matchesRefKey('Mark 3:16'), isFalse);
    });

    test('a chapter filter takes that chapter only', () {
      const f = PassageFilter('John', chapter: 17);
      expect(f.matchesRefKey('John 17'), isTrue);
      expect(f.matchesRefKey('John 17:3'), isTrue);
      expect(f.matchesRefKey('John 3'), isFalse);
      expect(f.matchesRefKey('John 1:17'), isFalse,
          reason: 'the 17 here is a verse, not the chapter');
    });

    test('a verse filter still takes whole-chapter citations', () {
      // The deliberate part. Someone who preached through all of John
      // 17 preached verse 3; dropping that sermon from a "John 17:3"
      // filter would lose the best match in the corpus to a technicality.
      const f = PassageFilter('John', chapter: 17, verse: 3);
      expect(f.matchesRefKey('John 17'), isTrue);
      expect(f.matchesRefKey('John 17:3'), isTrue);
      expect(f.matchesRefKey('John 17:20'), isFalse);
    });

    test('books whose names prefix another are not confused', () {
      const f = PassageFilter('John', chapter: 1);
      expect(f.matchesRefKey('1 John 1'), isFalse);
      expect(f.matchesRefKey('John 1'), isTrue);
    });
  });

  group('what gets highlighted inside the sermon', () {
    test('an exact reference', () {
      const f = PassageFilter('John', chapter: 17, verse: 3);
      expect(f.covers(ref('John', 17, v: 3)), isTrue);
      expect(f.covers(ref('John', 17, v: 4)), isFalse);
      expect(f.covers(ref('Mark', 17, v: 3)), isFalse);
    });

    test('a range that contains the verse', () {
      // The body writes "John 17:20-23" as one reference where the
      // index stored four separate keys, so covers() has to see ranges
      // that matchesRefKey never meets.
      const f = PassageFilter('John', chapter: 17, verse: 22);
      expect(f.covers(ref('John', 17, v: 20, end: 23)), isTrue);
      expect(f.covers(ref('John', 17, v: 1, end: 5)), isFalse);
    });

    test('a non-contiguous verse list', () {
      const f = PassageFilter('John', chapter: 17, verse: 8);
      expect(f.covers(ref('John', 17, verses: [3, 8, 19])), isTrue);
      expect(f.covers(ref('John', 17, verses: [3, 19])), isFalse);
    });

    test('a whole-chapter mention, matching the list behaviour', () {
      const f = PassageFilter('John', chapter: 17, verse: 3);
      expect(f.covers(ref('John', 17)), isTrue);
    });

    test('a chapter filter marks every verse of that chapter', () {
      const f = PassageFilter('John', chapter: 17);
      expect(f.covers(ref('John', 17, v: 21)), isTrue);
      expect(f.covers(ref('John', 17)), isTrue);
      expect(f.covers(ref('John', 16, v: 21)), isFalse);
    });
  });

  group('against the real refs index', () {
    late final Map<String, dynamic> refs = jsonDecode(
        File('assets/sermons/refs.json').readAsStringSync())
      as Map<String, dynamic>;
    late final byVerse = (refs['byVerse'] as Map).cast<String, dynamic>();
    late final bySermon = (refs['bySermon'] as Map).cast<String, dynamic>();

    List<String> matching(PassageFilter f) => [
          for (final e in bySermon.entries)
            if ((e.value as List).any((r) => f.matchesRefKey(r as String)))
              e.key,
        ];

    test('John 17 still finds the sermons the user saw', () {
      // The screenshot said "10 sermons across 7 topics". This is the
      // regression guard on folding two filter fields into one value.
      expect(matching(const PassageFilter('John', chapter: 17)),
          hasLength(10));
    });

    test('narrowing to a verse never widens the result', () {
      final chapter =
          matching(const PassageFilter('John', chapter: 17)).toSet();
      for (final v in [3, 8, 19, 20, 22, 23]) {
        final verse =
            matching(PassageFilter('John', chapter: 17, verse: v)).toSet();
        expect(verse.difference(chapter), isEmpty,
            reason: 'John 17:$v matched a sermon that John 17 did not');
        expect(verse, isNotEmpty,
            reason: 'John 17:$v is a key in the index, so something '
                'must match it');
      }
    });

    test('every index key parses back into the filter that made it', () {
      // If a key cannot be matched by a filter built from its own book,
      // chapter and verse, some book name or separator is being handled
      // inconsistently between writing the index and reading it.
      var checked = 0;
      for (final key in byVerse.keys) {
        final space = key.lastIndexOf(' ');
        if (space == -1) continue;
        final book = key.substring(0, space);
        final tail = key.substring(space + 1);
        final colon = tail.indexOf(':');
        final ch = int.tryParse(
            colon == -1 ? tail : tail.substring(0, colon));
        if (ch == null) continue;
        final v =
            colon == -1 ? null : int.tryParse(tail.substring(colon + 1));
        expect(PassageFilter(book, chapter: ch, verse: v).matchesRefKey(key),
            isTrue,
            reason: 'the filter for "$key" does not match "$key"');
        checked++;
      }
      expect(checked, greaterThan(1000),
          reason: 'the index should have well over a thousand keys');
    });
  });
}
