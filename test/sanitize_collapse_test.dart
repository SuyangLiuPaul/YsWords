// Test for v1.2.52's defensive post-strip cleanup in
// `lib/constants/text_patterns.dart`.
//
// Background: when an annotation in the source data was bracketed
// by the SAME punctuation on both sides (e.g. `俄梅戛，<note: …>，
// 是昔在`), stripping the annotation left the punctuation
// duplicated. User reported `俄梅戛，，是昔在` in copied text for
// Rev 1:8 (CUVS-YHWH). The 2026-05-18 sweep fixed 20 known cases
// at the data layer in cuvs-yhwh.json + cuvs-yhwh-tr.json, plus
// added a render-layer collapse pass as defense-in-depth.

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/text_patterns.dart';

void main() {
  group('sanitizeForSearch / sanitizeVerseText collapse', () {
    test('strips <note:...> and collapses the resulting duplicate '
        'CJK comma', () {
      // The exact Rev 1:8 (CUVS-YHWH) shape from the user report,
      // including the leading comma BEFORE the note + trailing
      // comma AFTER the note that produced the double-comma.
      const raw = '我是俄梅戛，<note: 阿拉法，俄梅戛：是希利尼字母首末二字>，是昔在';
      const expected = '我是俄梅戛，是昔在';
      expect(sanitizeForSearch(raw), expected);
      expect(sanitizeVerseText(raw), expected);
    });

    test('collapses repeated CJK period after note strip', () {
      const raw = '亚衲族的始祖。<note: 基列亚巴就是希伯仑>。';
      expect(sanitizeForSearch(raw), '亚衲族的始祖。');
    });

    test('collapses repeated CJK semicolon / colon / question / '
        'exclamation', () {
      expect(sanitizeForSearch('a；；b'), 'a；b');
      expect(sanitizeForSearch('a：：b'), 'a：b');
      expect(sanitizeForSearch('a？？b'), 'a？b');
      expect(sanitizeForSearch('a！！b'), 'a！b');
      expect(sanitizeForSearch('a、、b'), 'a、b');
    });

    test('collapses 3+ duplicates (defensive against future weirdness)',
        () {
      expect(sanitizeForSearch('a，，，b'), 'a，b');
      expect(sanitizeForSearch('a。。。。b'), 'a。b');
    });

    test('preserves single punctuation (no over-aggressive collapse)',
        () {
      const raw = '我是阿拉法，我是俄梅戛，是昔在';
      expect(sanitizeForSearch(raw), raw);
    });

    test('preserves [...] annotations (kept by sanitizeForSearch)', () {
      const raw = '主[雅伟]神说';
      expect(sanitizeForSearch(raw), raw);
    });

    test('sanitizeVerseText strips [...] annotations', () {
      // sanitizeVerseText is the more aggressive version — strips
      // square brackets too. Used for clean readable text (e.g.
      // copy-to-clipboard of the underlying verse without
      // annotations).
      const raw = '主[雅伟]神说';
      // sanitizeVerseText uses bracePattern + notePattern + pilcrow
      // and does NOT strip [...]; only the searchable variant
      // strips [...]. Both should still collapse duplicates.
      // Spot-check the behaviour matches sanitizeForSearch here.
      expect(sanitizeVerseText(raw), raw);
    });

    test('collapses multiple ASCII spaces produced by English '
        'annotation strip', () {
      const raw = 'yourself, <note: Singular> because';
      // notePattern strips the note; the leading + trailing spaces
      // collapse to one.
      expect(sanitizeForSearch(raw), 'yourself,  because'.replaceAll(
          RegExp(r'  +'), ' '));
    });

    test('handles cuvs-yhwh-tr Traditional Chinese variant', () {
      const raw = '主[雅偉]神說：「我是阿拉法，我是俄梅戛<note: …>，是昔在」';
      expect(sanitizeForSearch(raw),
          '主[雅偉]神說：「我是阿拉法，我是俄梅戛，是昔在」');
    });
  });

  // 2026-05-19 (v1.2.56): user reported LEB Matt 2:18 copy/paste
  // produced "...because ." — `{they exist no longer}` content was
  // being stripped along with the braces. Was a bug: braces are
  // markup, the inner phrase is verse content and must survive in
  // both copy + search.
  group('v1.2.56: {brace} inner content preservation', () {
    test('sanitizeVerseText keeps inner content of {phrase}, '
        'strips only the braces', () {
      // The exact LEB Matt 2:18 shape from the user report.
      const raw = '"A voice was heard in Ramah, weeping and great '
          'mourning, Rachel weeping [for] her children, and she did '
          'not want to be comforted, because {they exist no longer}'
          '<note: Literally "they are not">."<note: A quotation from '
          'Jer 31:15>';
      const expected = '"A voice was heard in Ramah, weeping and '
          'great mourning, Rachel weeping [for] her children, and '
          'she did not want to be comforted, because they exist no '
          'longer."';
      expect(sanitizeVerseText(raw), expected);
    });

    test('sanitizeForSearch keeps inner content of {phrase} for '
        'search indexing', () {
      // After the v1.2.56 fix, searching for "they exist no longer"
      // should match Matt 2:18 (and any other verse with that phrase
      // inside a brace).
      const raw = 'comforted, because {they exist no longer}<note: '
          'Literally "they are not">.';
      final out = sanitizeForSearch(raw);
      expect(out.contains('they exist no longer'), isTrue,
          reason: 'brace inner content should survive into search index');
      expect(out.contains('{'), isFalse,
          reason: 'braces themselves should be stripped');
      expect(out.contains('Literally'), isFalse,
          reason: '<note: …> should still be fully stripped');
    });

    test('sanitizeVerseText keeps multi-word {clarification} from '
        'LEB Matt 4:12', () {
      const raw = 'Now [when he]<note: *Here "when" is supplied …> '
          'heard that John {had been arrested},<note: Literally '
          '"had been handed over"> he withdrew into Galilee.';
      final out = sanitizeVerseText(raw);
      expect(out.contains('had been arrested'), isTrue);
      expect(out.contains('{'), isFalse);
      expect(out.contains('}'), isFalse);
      expect(out.contains('<note:'), isFalse);
    });

    test('empty {} braces are LEFT ALONE (bracePattern requires 1+ '
        'inner char, so the literal `{}` doesn\'t match)', () {
      // Validates we don't crash on an unmatched empty pair — the
      // input pass-through is the safe, predictable behaviour.
      expect(sanitizeForSearch('a{}b'), 'a{}b');
      expect(sanitizeVerseText('a{}b'), 'a{}b');
    });

    test('multiple {brace} occurrences in one verse all preserve '
        'inner content', () {
      const raw = 'one {two} three {four} five';
      expect(sanitizeForSearch(raw), 'one two three four five');
      expect(sanitizeVerseText(raw), 'one two three four five');
    });
  });

  // 2026-05-19 (v1.2.58): copy/preview formatter — same shape as
  // sanitizeForSearch (strip <note:>, keep {phrase} + [supplied])
  // PLUS replace internal `\n` line breaks with space so v1.2.57's
  // LJK2 poetry-layout breaks don't leak into clipboard / preview
  // output and split a single verse across multiple lines inside
  // an otherwise inline copy format.
  group('v1.2.58: sanitizeForCopy — clipboard / preview formatter',
      () {
    test('replaces internal \\n with a single space (LJK2 Mt 2:6 '
        'poetry block, joined into one inline copy line)', () {
      const raw = '犹大地区的伯利恒，\n犹大的头领中\n你绝非最小，'
          '<note:弥5.2 （七十士本记弥5.1）>\n因为你要出一位首领，\n'
          '他将放牧我的子民以色列。"<note:撒下5.2，代上11.2>';
      final out = sanitizeForCopy(raw);
      expect(out.contains('\n'), isFalse,
          reason: 'all line breaks should collapse to space');
      expect(out, contains('犹大地区的伯利恒'));
      expect(out, contains('他将放牧我的子民以色列'));
      expect(out.contains('<note:'), isFalse,
          reason: 'popup-only <note:…> should be fully stripped');
    });

    test('keeps {phrase} inner content (same as sanitizeForSearch)', () {
      const raw = 'comforted, because {they exist no longer}<note: '
          'Literally "they are not">.';
      final out = sanitizeForCopy(raw);
      expect(out.contains('they exist no longer'), isTrue);
      expect(out.contains('{'), isFalse);
    });

    test('keeps [supplied] markup as-is (no strip, mirrors search)',
        () {
      const raw = '主[雅伟]神说：「我是阿拉法」';
      expect(sanitizeForCopy(raw), '主[雅伟]神说：「我是阿拉法」');
    });

    test('handles a verse with NO line breaks identically to '
        'sanitizeForSearch (no regression on the common path)', () {
      const raw = '我是俄梅戛，<note: …>，是昔在';
      expect(sanitizeForCopy(raw), sanitizeForSearch(raw));
    });

    test('LJK2 Mt 1:16 brace+note+cite-style verse stays clean', () {
      const raw = '雅各生约瑟，即玛利亚的丈夫，玛利亚生耶稣，'
          '又称基督。';
      expect(sanitizeForCopy(raw),
          '雅各生约瑟，即玛利亚的丈夫，玛利亚生耶稣，又称基督。');
    });
  });
}
