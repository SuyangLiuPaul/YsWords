// The clipboard format for a LIST of verses drawn from different books
// — cross-references today, and whatever panel wants it next.
//
// Extracted from the cross-references sheet on 2026-09-05 rather than
// left inline: the sheet body is a private State class, so nothing
// outside that library can reach it, and the part with real decisions
// in it is the format, not the button.
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/ref_list_copy.dart';

void main() {
  test('one [ref] text line per row, joined by newlines', () {
    expect(
      formatRefListForCopy(const [
        (label: 'John 3:16', rawText: 'For God so loved the world'),
        (label: 'Romans 5:8', rawText: 'But God shows his love'),
      ]),
      '[John 3:16] For God so loved the world\n'
      '[Romans 5:8] But God shows his love',
    );
  });

  test('an empty list copies nothing at all', () {
    // Not "\n", not " " — the sheet hides the button in this state, and
    // if that guard ever slips the clipboard should still be empty
    // rather than carrying invisible whitespace.
    expect(formatRefListForCopy(const []), '');
  });

  group('a row with no verse text still copies its reference', () {
    // The text is absent because that book is not in the loaded verse
    // index, which is ordinary. Dropping the row would silently shorten
    // the list — a reference alone is still worth pasting.
    test('null text', () {
      expect(formatRefListForCopy(const [(label: 'Obadiah 1:3', rawText: null)]),
          '[Obadiah 1:3]');
    });

    test('blank text leaves no trailing space', () {
      for (final blank in const ['', '   ', '\n', ' \n ']) {
        expect(formatRefListForCopy([(label: 'Jude 1:1', rawText: blank)]),
            '[Jude 1:1]',
            reason: 'blank text ${blank.codeUnits} produced a dangling space');
      }
    });
  });

  test('an internal poetry line break becomes a space, not a new line', () {
    // This is the whole reason the formatter sanitises the RAW text
    // itself instead of taking the on-screen preview: since v1.2.57 a
    // single verse can carry real \n breaks (LJK2 OT-quote verses), and
    // the preview beside these rows is built with sanitizeForSearch,
    // which KEEPS them. One row must stay one line.
    final out = formatRefListForCopy(const [
      (label: 'Isaiah 53:5', rawText: 'first line\nsecond line'),
    ]);
    expect(out, '[Isaiah 53:5] first line second line');
    expect('\n'.allMatches(out), isEmpty,
        reason: 'a single row must never span two clipboard lines');
  });

  test('row order is preserved exactly as given', () {
    final out = formatRefListForCopy(const [
      (label: 'Revelation 1:8', rawText: 'a'),
      (label: 'Genesis 1:1', rawText: 'b'),
      (label: 'Psalm 23:1', rawText: 'c'),
    ]);
    expect(out.split('\n').map((l) => l.split(']').first),
        ['[Revelation 1:8', '[Genesis 1:1', '[Psalm 23:1'],
        reason: 'the list is shown in curated order, not canonical order, '
            'and the clipboard must match what was on screen');
  });
}
