import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the sermon-body paragraph typography, which has now been tuned
/// twice against two OPPOSITE complaints from the same reader — and the
/// second fix is only correct as long as it does not undo the first.
///
/// v1.4.x answered a wall-of-text complaint with three levers: a line
/// measure (`fontSize * 34`, 30 for CJK), a 1.75 line height, and 22pt
/// between paragraphs.
///
/// 2026-08-11 the same reader on the result: "每个段落一个block也不好
/// experience". Nothing here draws a card or a border, so "block" is how
/// the page READS — and the cause was the third lever alone. 22pt of air
/// against a 35pt line box (the default 20pt font × 1.75) is nearly two
/// thirds of a line between paragraphs and only a fifth of one inside
/// them, so space was doing all the signalling and every paragraph break
/// landed as a full stop.
///
///     line height          1.75          → 1.75   (deliberately unchanged)
///     gap between paras    22.0 pt fixed → fontSize * 0.3
///                                          (6.0 pt at the default 20pt)
///     first-line indent    none          → 2 em, every paragraph
///
/// `_SermonBody` is private to its page and the page needs the sermon
/// service, the settings provider and a loaded body before it will paint
/// a paragraph, so these read the source. That is enough for what is
/// actually at risk: the numbers, and someone "simplifying" the second
/// fix into a revert of the first.
void main() {
  final src = File('lib/pages/sermon_detail_page.dart').readAsStringSync();

  group('the wall-of-text fix survives', () {
    test('the line measure is still 34 em (30 for CJK)', () {
      expect(src, contains('final measure = fontSize * (isCjk ? 30 : 34);'));
    });

    test('the line height is still 1.75', () {
      // The blockiness was the gap, not the leading. Dropping this back
      // toward 1.2 would re-open the complaint this number answered.
      expect(src, contains('height: 1.75,'));
    });
  });

  group('continuous prose', () {
    test('the 22pt paragraph gap is gone', () {
      expect(src.contains('EdgeInsets.only(bottom: 22)'), isFalse,
          reason: 'the fixed 22pt gap is what read as separate blocks');
    });

    test('the gap is 0.3 em — 6pt at the default 20pt font', () {
      expect(src, contains('final paragraphGap = fontSize * 0.3;'));
      expect(src, contains('padding: EdgeInsets.only(bottom: paragraphGap),'));
      // Stated as the reader meets it: 6pt of air against a 35pt line
      // box, so the space between paragraphs is now well under the space
      // inside them and the eye keeps going.
      expect(20.0 * 0.3, 6.0);
      expect(20.0 * 1.75, 35.0);
      expect(20.0 * 0.3 < 20.0 * 1.75, isTrue,
          reason: 'a paragraph break must cost less than a line break, or '
              'the paragraphs read as tiles again');
    });

    test('every paragraph opens with a 2 em first-line indent', () {
      // U+3000 IDEOGRAPHIC SPACE is exactly one em and is what Chinese
      // typesetting already uses for this; U+2003 EM SPACE is the Latin
      // equivalent. Two of each = 2 em.
      expect(
        src,
        contains(r"final indent = isCjk ? '\u3000\u3000' : '\u2003\u2003';"),
      );
      // Prepended as a plain TextSpan, not a WidgetSpan: the body is a
      // SelectableText and a placeholder span copies to the clipboard as
      // U+FFFC. A space copies as a space.
      expect(src, contains('TextSpan(text: indent),'));
      expect(RegExp(r'WidgetSpan\(').hasMatch(src), isFalse,
          reason: 'a WidgetSpan indent would put U+FFFC in copied sermon '
              'text');
    });
  });

  test('nothing re-paragraphs the sermon', () {
    // The standing rule: inserting or removing breaks in another man's
    // preaching is an expressive decision he did not make. Only
    // typography moves. The body is still split on the blank lines the
    // transcript already has, and on nothing else.
    expect(src, contains(r"body.split(RegExp(r'\n\s*\n'))"));
    expect(src.contains('sentenceSplit'), isFalse);
  });
}
