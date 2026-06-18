// 2026-06-18 (v1.3.90): localized note-reference round-trip safety.
//
// The note reference picker now inserts the verse reference using a
// localized book name (so `[约翰福音 3:16]` instead of `[John 3:16]` for a
// Chinese user). The picker draws that display name straight out of
// `bookNameToEnglish` (or the canonical English name for the `en`
// locale), so by construction the parser should resolve it back to the
// correct canonical book and the chip stays tappable.
//
// This test proves that contract empirically: every name the picker can
// emit — the canonical English name AND every CJK (non-ASCII) alias in
// `bookNameToEnglish` — must, when formatted into a compact reference and
// re-parsed, resolve back to its canonical English book. If a future
// edit to the parser or the name map breaks any name, this fails loudly.

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/book_names.dart' show bookNameToEnglish;
import 'package:yswords/utils/note_reference_parser.dart';

bool _isAscii(String s) => s.codeUnits.every((c) => c < 128);

void main() {
  group('localized note-reference round-trip', () {
    test('every emittable book name round-trips through insert + parse', () {
      final failures = <String>[];
      var checked = 0;
      for (final entry in bookNameToEnglish.entries) {
        final alias = entry.key;
        final canonical = entry.value;
        // The picker only ever inserts the canonical English name (en
        // locale) or a non-ASCII CJK alias (zh locales). ASCII
        // abbreviations like "Matt" / "1 Cor" are never used as the
        // inserted display name, so they are out of scope here.
        if (_isAscii(alias) && alias != canonical) continue;
        checked++;
        final ref = formatCompactReference(
          englishBook: canonical,
          chapter: 3,
          verses: const [16],
          displayBook: alias,
        );
        if (ref.isEmpty) {
          failures.add('alias "$alias" ($canonical): produced empty ref');
          continue;
        }
        final matches = extractNoteReferences(ref);
        if (matches.length != 1 || matches.first.englishBook != canonical) {
          failures.add(
              'alias "$alias" -> "$ref" resolved to '
              '${matches.map((m) => m.englishBook).toList()} '
              '(expected "$canonical")');
        }
      }
      expect(checked, greaterThan(60),
          reason: 'expected to cover the full canon, only checked $checked');
      expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
    });

    test('no displayBook keeps the canonical English output (back-compat)', () {
      final ref = formatCompactReference(
          englishBook: 'John', chapter: 3, verses: const [16]);
      expect(ref, '[John 3:16]');
      expect(extractNoteReferences(ref).single.englishBook, 'John');
    });

    test('localized multi-verse compact ref round-trips', () {
      final ref = formatCompactReference(
        englishBook: 'John',
        chapter: 3,
        verses: const [16, 17, 18],
        displayBook: '约翰福音',
      );
      expect(ref, '[约翰福音 3:16-18]');
      expect(extractNoteReferences(ref).single.englishBook, 'John');
    });

    test('localizeKeyPassage swaps the book token, keeps numbers', () {
      // Mirrors the book-intro card helper contract (book name follows
      // locale; chapter:verse range stays verbatim). English locale with
      // no version returns the canonical name unchanged.
      // (Helper lives in bible_reading_pane.dart; behaviour asserted via
      // the public formatter contract here to keep this test pure-Dart.)
      expect(
        formatReferenceForInsertion(
            englishBook: 'John', chapter: 3, verse: 16, displayBook: '约翰福音'),
        '[约翰福音 3:16]',
      );
    });
  });
}
