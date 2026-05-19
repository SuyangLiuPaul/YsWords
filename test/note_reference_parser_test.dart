// 2026-05-19 (v1.2.59): tests for the note-reference parser. Covers
// English + CJK book names, verse ranges, partial / malformed
// inputs, multi-reference notes, and the "fallback to plain text
// when the book isn't canonical" guarantee.
//
// Tap firing: each TextSpan's recognizer is a TapGestureRecognizer
// whose `onTap` field is publicly settable + gettable. We invoke
// it directly (`recognizer.onTap?.call()`) instead of pumping a
// gesture, so the tests stay focused on parsing behaviour rather
// than gesture-pipeline plumbing.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/note_reference_parser.dart';

List<NoteReferenceMatch> _fireAllRefs(String noteText) {
  final caught = <NoteReferenceMatch>[];
  final spans = buildNoteSpans(
    noteText: noteText,
    baseStyle: const TextStyle(),
    refColor: const Color(0xFF000000),
    onRefTap: caught.add,
  );
  for (final span in spans) {
    if (span is! TextSpan) continue;
    final r = span.recognizer;
    if (r is TapGestureRecognizer) {
      r.onTap?.call();
    }
  }
  return caught;
}

void main() {
  group('buildNoteSpans — English references', () {
    test('plain text only → single TextSpan, no recognizers', () {
      final refs = _fireAllRefs('Just a note about prayer.');
      expect(refs, isEmpty);
    });

    test('single English reference fires onRefTap with parsed data',
        () {
      final refs = _fireAllRefs('See [John 3:16] for the gospel.');
      expect(refs.length, 1);
      expect(refs.first.englishBook, 'John');
      expect(refs.first.chapter, 3);
      expect(refs.first.verseStart, 16);
      expect(refs.first.verseEnd, isNull);
    });

    test('span structure: plain prefix + tappable ref + plain suffix',
        () {
      final spans = buildNoteSpans(
        noteText: 'See [John 3:16] for the gospel.',
        baseStyle: const TextStyle(),
        refColor: const Color(0xFF000000),
        onRefTap: (_) {},
      );
      expect(spans.length, 3);
      expect((spans[0] as TextSpan).text, 'See ');
      expect((spans[0] as TextSpan).recognizer, isNull);
      expect((spans[1] as TextSpan).text, '[John 3:16]');
      expect((spans[1] as TextSpan).recognizer, isA<TapGestureRecognizer>());
      expect((spans[1] as TextSpan).style?.decoration,
          TextDecoration.underline);
      expect((spans[2] as TextSpan).text, ' for the gospel.');
    });

    test('verse range with ASCII hyphen [Matt 5:1-12] resolves', () {
      final refs = _fireAllRefs('Beatitudes [Matt 5:1-12].');
      expect(refs.length, 1);
      expect(refs.first.englishBook, 'Matthew');
      expect(refs.first.chapter, 5);
      expect(refs.first.verseStart, 1);
      expect(refs.first.verseEnd, 12);
    });

    test('verse range with em-dash [Matt 5:1–12] resolves', () {
      final refs = _fireAllRefs('[Matt 5:1–12]');
      expect(refs.length, 1);
      expect(refs.first.verseStart, 1);
      expect(refs.first.verseEnd, 12);
    });

    test('multi-word book [1 Corinthians 13:4] resolves', () {
      final refs = _fireAllRefs('Love chapter: [1 Corinthians 13:4]');
      expect(refs.length, 1);
      expect(refs.first.englishBook, '1 Corinthians');
      expect(refs.first.chapter, 13);
      expect(refs.first.verseStart, 4);
    });
  });

  group('buildNoteSpans — CJK references', () {
    test('Simplified Chinese book name resolves to canonical', () {
      final refs = _fireAllRefs('[约翰福音 3:16]');
      expect(refs.length, 1);
      expect(refs.first.englishBook, 'John');
      expect(refs.first.chapter, 3);
      expect(refs.first.verseStart, 16);
    });

    test('Traditional Chinese book name resolves to canonical', () {
      final refs = _fireAllRefs('[約翰福音 3:16]');
      expect(refs.length, 1);
      expect(refs.first.englishBook, 'John');
    });

    test('Full-width colon [约翰福音 3：16] matches', () {
      final refs = _fireAllRefs('[约翰福音 3：16]');
      expect(refs.length, 1);
      expect(refs.first.englishBook, 'John');
      expect(refs.first.verseStart, 16);
    });
  });

  group('buildNoteSpans — falls back to plain text safely', () {
    test('unknown book name → ref-shaped text kept as plain '
        '(no crash, no tap)', () {
      final refs = _fireAllRefs('[FooBook 1:1] is not real');
      expect(refs, isEmpty);
    });

    test('partial reference [John 3] (no verse) → plain text', () {
      final refs = _fireAllRefs('[John 3] context only');
      expect(refs, isEmpty);
    });

    test('empty note → no refs, no crash', () {
      final refs = _fireAllRefs('');
      expect(refs, isEmpty);
    });

    test('whitespace-only inside brackets → plain text', () {
      final refs = _fireAllRefs('[ ] empty marker');
      expect(refs, isEmpty);
    });
  });

  group('buildNoteSpans — multi-reference notes', () {
    test('two references in one note both become tappable', () {
      final refs = _fireAllRefs(
          'Compare [John 3:16] with [Romans 5:8] for the cross theme.');
      expect(refs.length, 2);
      expect(refs[0].englishBook, 'John');
      expect(refs[0].verseStart, 16);
      expect(refs[1].englishBook, 'Romans');
      expect(refs[1].verseStart, 8);
    });

    test('three references — order preserved', () {
      final refs = _fireAllRefs(
          'See [Genesis 1:1], [John 1:1], and [Revelation 22:13] — bookends.');
      expect(refs.length, 3);
      expect(refs.map((r) => r.englishBook).toList(),
          ['Genesis', 'John', 'Revelation']);
    });

    test('mixed valid + invalid refs: only valid ones become tappable',
        () {
      final refs = _fireAllRefs(
          '[John 3:16] is real, [FooBook 1:1] is not.');
      expect(refs.length, 1);
      expect(refs.first.englishBook, 'John');
    });
  });

  group('formatReferenceForInsertion', () {
    test('produces the canonical bracket form', () {
      expect(
        formatReferenceForInsertion(
            englishBook: 'John', chapter: 3, verse: 16),
        '[John 3:16]',
      );
      expect(
        formatReferenceForInsertion(
            englishBook: '1 Corinthians', chapter: 13, verse: 4),
        '[1 Corinthians 13:4]',
      );
      expect(
        formatReferenceForInsertion(
            englishBook: 'Genesis', chapter: 1, verse: 1),
        '[Genesis 1:1]',
      );
    });
  });

  // 2026-05-19 (v1.2.61): compact reference formatter — the new
  // multi-select picker uses this to convert {2, 5, 7, 9, 10}
  // into "[Book Ch:2,5,7,9-10]".
  group('formatCompactReference', () {
    test('single verse → single number', () {
      expect(
        formatCompactReference(
            englishBook: 'John', chapter: 3, verses: [16]),
        '[John 3:16]',
      );
    });

    test('contiguous range collapses to hyphenated form', () {
      expect(
        formatCompactReference(
            englishBook: 'Genesis', chapter: 1, verses: [2, 3, 4, 5]),
        '[Genesis 1:2-5]',
      );
    });

    test('two non-adjacent verses → comma-separated', () {
      expect(
        formatCompactReference(
            englishBook: 'Genesis', chapter: 1, verses: [2, 5]),
        '[Genesis 1:2,5]',
      );
    });

    test('mixed: singles + ranges in canonical compact form', () {
      expect(
        formatCompactReference(
            englishBook: 'Genesis',
            chapter: 1,
            verses: [2, 3, 5, 7, 9, 10]),
        '[Genesis 1:2-3,5,7,9-10]',
      );
    });

    test('input is sorted + deduplicated', () {
      expect(
        formatCompactReference(
            englishBook: 'Matt', chapter: 5, verses: [5, 3, 1, 5, 1, 4]),
        '[Matt 5:1,3-5]',
      );
    });

    test('empty verses list → empty string (caller should treat as '
        '"no insertion")', () {
      expect(
        formatCompactReference(
            englishBook: 'John', chapter: 3, verses: []),
        '',
      );
    });

    test('invalid chapter / book → empty string', () {
      expect(
        formatCompactReference(
            englishBook: 'John', chapter: 0, verses: [1]),
        '',
      );
      expect(
        formatCompactReference(
            englishBook: '', chapter: 1, verses: [1]),
        '',
      );
    });

    test('non-positive verse numbers are filtered out', () {
      expect(
        formatCompactReference(
            englishBook: 'John', chapter: 1, verses: [0, -1, 5]),
        '[John 1:5]',
      );
    });

    test('round-trip: compact format parses back to the same '
        'verse list', () {
      final compact = formatCompactReference(
          englishBook: 'Genesis',
          chapter: 1,
          verses: [2, 3, 5, 7, 9, 10]);
      // Parse it through buildNoteSpans + collect via _fireAllRefs
      final refs = _fireAllRefs(compact);
      expect(refs.length, 1);
      expect(refs.first.englishBook, 'Genesis');
      expect(refs.first.chapter, 1);
      expect(refs.first.verses, [2, 3, 5, 7, 9, 10]);
    });
  });

  // 2026-05-19 (v1.2.61): complex compact references in the parser.
  // The regex was extended to match `1:2,5,7,9-10` style specs.
  group('buildNoteSpans — complex compact references', () {
    test('comma-separated verses [Gen 1:2,5,7]', () {
      final refs = _fireAllRefs('See [Gen 1:2,5,7]');
      expect(refs.length, 1);
      expect(refs.first.englishBook, 'Genesis');
      expect(refs.first.chapter, 1);
      expect(refs.first.verses, [2, 5, 7]);
      // Contiguous? No — verseEnd stays null
      expect(refs.first.verseEnd, isNull);
      expect(refs.first.verseStart, 2);
    });

    test('mixed singles + ranges [Gen 1:2-3,5,9-10]', () {
      final refs = _fireAllRefs('Read [Gen 1:2-3,5,9-10]');
      expect(refs.length, 1);
      expect(refs.first.verses, [2, 3, 5, 9, 10]);
    });

    test('pure range still works [Gen 1:2-5]', () {
      final refs = _fireAllRefs('[Gen 1:2-5]');
      expect(refs.length, 1);
      expect(refs.first.verses, [2, 3, 4, 5]);
      // Contiguous range → verseEnd is set for v1.2.59 callers
      expect(refs.first.verseEnd, 5);
    });

    test('CJK comma `[Gen 1:2，5，7]` matches', () {
      final refs = _fireAllRefs('[Gen 1:2，5，7]');
      expect(refs.length, 1);
      expect(refs.first.verses, [2, 5, 7]);
    });

    test('malformed: inverted range [Gen 1:5-2] → falls through as '
        'plain text', () {
      final refs = _fireAllRefs('[Gen 1:5-2]');
      expect(refs, isEmpty);
    });
  });
}
