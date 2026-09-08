import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/utils/strongs_inline.dart';

/// The two rules behind the numbers in the Exegesis sheet's tagged line.
///
/// They are pure functions in `utils/` precisely so they can be pinned
/// here rather than read off a screenshot — the widget that uses them
/// renders one `Text.rich`, where an ordering mistake is a thing you
/// squint at rather than a thing that fails.
void main() {
  group('inlineStrongsNumbers', () {
    test('implied numbers print BEFORE the word\'s own', () {
      // Not a style choice. `天<WH853x><WH8064>` and
      // `以撒<WG3588x><WG2464>` both put the unrendered word ahead of
      // the one on screen, because that is the order the Hebrew and the
      // Greek are in — אֵת before שָׁמַיִם, τόν before Ἰσαάκ. Printing
      // them the other way round would align the line with our parse
      // instead of with the original.
      expect(
        inlineStrongsNumbers(strongs: 'H8064', implied: const ['H853']),
        const [
          StrongsNumberToken('(H853)', StrongsNumberKind.implied),
          StrongsNumberToken('H8064', StrongsNumberKind.lexical),
        ],
      );
    });

    test('grammar codes come last, and are their own kind', () {
      expect(
        inlineStrongsNumbers(strongs: 'H1254', grammar: const ['H8804']),
        const [
          StrongsNumberToken('H1254', StrongsNumberKind.lexical),
          StrongsNumberToken('H8804', StrongsNumberKind.grammar),
        ],
      );
    });

    test('an untagged run prints nothing', () {
      expect(inlineStrongsNumbers(strongs: ''), isEmpty);
    });

    test('an empty string in a list is not printed as ()', () {
      expect(
        inlineStrongsNumbers(
            strongs: 'H430', grammar: const [''], implied: const ['']),
        const [StrongsNumberToken('H430', StrongsNumberKind.lexical)],
      );
    });
  });

  group('splitTrailingCjkPunctuation', () {
    test('the comma the source baked onto the word comes off', () {
      // Genesis 1:1 is `{"w":"起初，","s":"H7225"}`. H7225 is רֵאשִׁית,
      // "beginning"; the CUV's comma has no Hebrew behind it, so a
      // number printed after it reads as though it tagged the comma.
      expect(splitTrailingCjkPunctuation('起初，'), ('起初', '，'));
    });

    test('several closers in a row all come off', () {
      expect(splitTrailingCjkPunctuation('天地。」'), ('天地', '。」'));
    });

    test('an opener is never mistaken for a closer', () {
      // The set is deliberately the CJK "cannot start a line" marks. A
      // rule that also matched openers would cut 「水要 into 「水要 + 「.
      expect(splitTrailingCjkPunctuation('「水要'), ('「水要', ''));
    });

    test('mid-word punctuation is untouched — only the maximal trailing '
        'run is taken', () {
      expect(splitTrailingCjkPunctuation('亚大、洗拉'), ('亚大、洗拉', ''));
    });

    test('English punctuation is deliberately left on the word', () {
      // A citation mark after a comma is ordinary English typesetting,
      // so "correct by the same logic as Chinese" is not "wrong the same
      // way". 25,606 BSB runs end in an ASCII mark and none of them are
      // split.
      expect(splitTrailingCjkPunctuation('the earth,'), ('the earth,', ''));
    });

    test('a run that is nothing but punctuation splits to empty', () {
      expect(splitTrailingCjkPunctuation('。'), ('', '。'));
    });
  });
}
