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

  // 2026-08-01: pill-highlight mode for the note editor's inline
  // TextEditingController override — onRefTap omitted (no tap
  // recognizer, since a TapGestureRecognizer inside an editable
  // field's own text-selection gesture area is the kind of thing
  // that's easy to get subtly wrong) and refBackgroundColor supplied
  // for a solid-background "pill" look instead of the underlined-link
  // style.
  group('buildNoteSpans — pill-highlight mode (no onRefTap)', () {
    test('matched ref gets background + color styling, no recognizer',
        () {
      final spans = buildNoteSpans(
        noteText: 'See [John 3:16] for the gospel.',
        baseStyle: const TextStyle(fontSize: 14),
        refColor: const Color(0xFF3730A3),
        refBackgroundColor: const Color(0x593730A3),
      );
      // plain prefix, ref, plain suffix — same 3-span shape as the
      // tappable-link mode.
      expect(spans.length, 3);
      final refSpan = spans[1] as TextSpan;
      expect(refSpan.text, '[John 3:16]');
      expect(refSpan.style?.backgroundColor, const Color(0x593730A3));
      expect(refSpan.style?.color, const Color(0xFF3730A3));
      // No underline in pill mode — that's the tappable-link mode's
      // affordance, and would be misleading here since tapping this
      // span just places the text cursor.
      expect(refSpan.style?.decoration, isNot(TextDecoration.underline));
      // The whole point: nothing to accidentally fight the
      // TextField's own tap-to-place-cursor gesture.
      expect(refSpan.recognizer, isNull);
    });

    test('plain-text-only note is unaffected by pill mode', () {
      final spans = buildNoteSpans(
        noteText: 'Just a note about prayer.',
        baseStyle: const TextStyle(),
        refColor: const Color(0xFF000000),
        refBackgroundColor: const Color(0x59000000),
      );
      expect(spans.length, 1);
      expect((spans.first as TextSpan).style?.backgroundColor, isNull);
    });

    test('default (no refBackgroundColor) keeps the original '
        'underlined-link style — existing callers unaffected', () {
      final spans = buildNoteSpans(
        noteText: '[John 3:16]',
        baseStyle: const TextStyle(),
        refColor: const Color(0xFF000000),
        onRefTap: (_) {},
      );
      final refSpan = spans.first as TextSpan;
      expect(refSpan.style?.decoration, TextDecoration.underline);
      expect(refSpan.style?.backgroundColor, isNull);
      expect(refSpan.recognizer, isNotNull);
    });
  });

  // 2026-08-02: field report — "如果中文英文插入这个不是跟着变的"
  // (typing Chinese/English, the highlight doesn't keep up). The note
  // editor's ref-highlighting controller used to bail out to a
  // completely PLAIN render for the entire note text whenever any IME
  // composing session was active anywhere in it, so every already-
  // inserted [Book Ch:V] pill would flicker away on every pinyin
  // keystroke. spliceComposingUnderline lets the composing region get
  // its underline WITHOUT discarding the rest of the text's styling.
  group('spliceComposingUnderline', () {
    List<TextSpan> pillSpans(String text) => buildNoteSpans(
          noteText: text,
          baseStyle: const TextStyle(fontSize: 14),
          refColor: const Color(0xFF3730A3),
          refBackgroundColor: const Color(0x593730A3),
        ).cast<TextSpan>();

    test('composing region inside plain text splits into 3 parts, '
        'middle part gets underline', () {
      final spans = pillSpans('Just a note about prayer.');
      // "note" starts at index 7, ends at 11.
      final result = spliceComposingUnderline(
        spans,
        const TextRange(start: 7, end: 11),
      );
      final joined = result.whereType<TextSpan>().map((s) => s.text).join();
      expect(joined, 'Just a note about prayer.',
          reason: 'splicing must not lose or duplicate any text');
      final composingSpan = result.whereType<TextSpan>().firstWhere(
            (s) => s.text == 'note',
          );
      expect(composingSpan.style?.decoration, TextDecoration.underline);
    });

    test('composing region overlapping a ref pill keeps the pill '
        'background AND adds the underline', () {
      final spans = pillSpans('See [John 3:16] now.');
      // "[John 3:16]" occupies indices 4..15. Compose over "3:16"
      // (indices 10..14), well inside the pill span.
      final result = spliceComposingUnderline(
        spans,
        const TextRange(start: 10, end: 14),
      );
      final joined = result.whereType<TextSpan>().map((s) => s.text).join();
      expect(joined, 'See [John 3:16] now.');
      final composingSpan =
          result.whereType<TextSpan>().firstWhere((s) => s.text == '3:16');
      expect(composingSpan.style?.decoration, TextDecoration.underline,
          reason: 'composing region must show the IME underline');
      expect(composingSpan.style?.backgroundColor, const Color(0x593730A3),
          reason: 'the ref pill background must survive composing, not '
              'be discarded like the old full-text bailout did');
    });

    test('composing region spanning a span boundary splits both '
        'sides correctly', () {
      final spans = pillSpans('[Gen 1:1] hello');
      // "[Gen 1:1]" is indices 0..9; " hello" starts at 9. Compose
      // over indices 7..12 — crosses from inside the pill into the
      // plain suffix.
      final result = spliceComposingUnderline(
        spans,
        const TextRange(start: 7, end: 12),
      );
      final joined = result.whereType<TextSpan>().map((s) => s.text).join();
      expect(joined, '[Gen 1:1] hello',
          reason: 'no characters lost across the span boundary');
    });

    test('composing region with no overlap leaves spans untouched', () {
      final spans = pillSpans('[Gen 1:1] hello');
      final result = spliceComposingUnderline(
        spans,
        const TextRange(start: 100, end: 105),
      );
      expect(result, spans);
    });
  });

  // 2026-08-02: field report — "你看下面是列王纪上但是文字是1King".
  // A manually-typed English abbreviation stayed English in the note
  // body forever, even though the read-only chip strip already
  // localized it. normalizeNoteReferenceBookNames rewrites the BOOK
  // NAME (only) of every valid reference to whatever the caller's
  // localizer returns, called once at Save time.
  group('normalizeNoteReferenceBookNames', () {
    test('rewrites an English abbreviation to the localized name', () {
      final result = normalizeNoteReferenceBookNames(
        'See [1 Kings 17:21] please.',
        (canonical) => canonical == '1 Kings' ? '列王纪上' : canonical,
      );
      expect(result, 'See [列王纪上 17:21] please.');
    });

    test('leaves surrounding text and verse digits untouched', () {
      final result = normalizeNoteReferenceBookNames(
        '奴隶\n[2 Kings 4:34] 神迹',
        (canonical) => canonical == '2 Kings' ? '列王纪下' : canonical,
      );
      expect(result, '奴隶\n[列王纪下 4:34] 神迹');
    });

    test('multiple references in one note all get rewritten', () {
      final result = normalizeNoteReferenceBookNames(
        '[1 Kings 17:21] and [2 Kings 4:34]',
        (canonical) {
          if (canonical == '1 Kings') return '列王纪上';
          if (canonical == '2 Kings') return '列王纪下';
          return canonical;
        },
      );
      expect(result, '[列王纪上 17:21] and [列王纪下 4:34]');
    });

    test('already-localized references pass through unchanged '
        '(idempotent)', () {
      final result = normalizeNoteReferenceBookNames(
        '[列王纪上 17:21]',
        (canonical) => canonical == '1 Kings' ? '列王纪上' : canonical,
      );
      expect(result, '[列王纪上 17:21]');
    });

    test('invalid / malformed bracket text is left verbatim', () {
      const text = '[Not A Real Book 1:1] and plain text';
      final result = normalizeNoteReferenceBookNames(text, (c) => c);
      expect(result, text);
    });

    test('compact multi-verse specs (ranges, commas) survive '
        'the rewrite intact', () {
      final result = normalizeNoteReferenceBookNames(
        '[Gen 1:2-3,5,9-10]',
        (canonical) => canonical == 'Genesis' ? '创世记' : canonical,
      );
      expect(result, '[创世记 1:2-3,5,9-10]');
    });

    test('empty note returns empty', () {
      expect(normalizeNoteReferenceBookNames('', (c) => c), '');
    });
  });
}
