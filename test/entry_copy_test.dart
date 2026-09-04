// The shared clipboard shape for content entries — timeline events,
// evidence items, videos, sermons, songs.
//
// One formatter serves all of them (2026-09-05), so these tests are
// what stop the pages drifting apart: a user who copies from two of
// them notices when one uses commas and the other semicolons.
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/entry_copy.dart';

void main() {
  group('formatEntryForCopy', () {
    test('heading, body, refs, url — in that order, one per line', () {
      expect(
        formatEntryForCopy(
          heading: '2166 BC — Abraham born',
          body: 'Called out of Ur.',
          refs: const ['Genesis 11:26', 'Genesis 12:1'],
          url: 'https://example.org/x',
        ),
        '2166 BC — Abraham born\n'
        'Called out of Ur.\n'
        'Genesis 11:26; Genesis 12:1\n'
        'https://example.org/x',
      );
    });

    test('missing parts vanish instead of leaving blank lines', () {
      final out = formatEntryForCopy(heading: 'Title', url: 'https://u');
      expect(out, 'Title\nhttps://u');
      expect(out.contains('\n\n'), isFalse,
          reason: 'an absent body must not leave an empty line behind');
    });

    test('whitespace-only parts count as missing', () {
      expect(formatEntryForCopy(heading: '  ', body: '\n', url: ' '), '');
    });

    test('an entry with nothing in it copies nothing', () {
      // The caller should not offer the button in this state; if that
      // slips, an empty string is quieter than a run of newlines.
      expect(formatEntryForCopy(), '');
    });

    test('blank references are dropped, not joined as empty gaps', () {
      expect(
        formatEntryForCopy(refs: const ['Acts 2:1', '', '   ', 'Acts 2:4']),
        'Acts 2:1; Acts 2:4',
      );
    });

    test('references share one line', () {
      // Deliberate: refs are short, they read as one thought, and one
      // per line makes a three-reference event look longer than its
      // own description.
      final out = formatEntryForCopy(
          body: 'b', refs: const ['A 1:1', 'B 2:2', 'C 3:3']);
      expect(out.split('\n').length, 2);
    });
  });

  group('formatEntriesForCopy', () {
    test('entries are separated by one blank line', () {
      expect(formatEntriesForCopy(const ['one', 'two']), 'one\n\ntwo');
    });

    test('empty entries are dropped, leaving no gaps', () {
      expect(formatEntriesForCopy(const ['one', '', '  ', 'two']),
          'one\n\ntwo');
    });

    test('an all-empty list copies nothing', () {
      expect(formatEntriesForCopy(const ['', '   ']), '');
      expect(formatEntriesForCopy(const []), '');
    });
  });
}
