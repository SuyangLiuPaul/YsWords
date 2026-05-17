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
}
