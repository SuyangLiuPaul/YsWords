// The Home hero drops a fact rather than cutting one.
//
// 2026-09-15, from a phone screenshot: 「出埃及记 18 · 和合本雅伟版(…」.
// 「如果没位置显示就不用…怎么做好」.
//
// What is asserted here is the DECISION, not the pixels: given a width,
// which complete line does the widget choose? That is the thing the
// screenshot was complaining about, and it is the thing a font change,
// a text-scale change or a longer book name can silently break.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/widgets/fitted_line.dart';

const _style = TextStyle(fontSize: 14);

String _pick(List<String> candidates, double width) => fittingCandidate(
      candidates,
      maxWidth: width,
      style: _style,
      scaler: TextScaler.noScaling,
    );

void main() {
  // The real line from the report, in the order the dashboard builds it.
  final exodus = <String>[
    '出埃及记 18  ·  和合本雅伟版(简体)',
    '出埃及记 18  ·  雅伟版(简)',
    '出 18  ·  雅伟版(简)',
    '出埃及记 18',
    '出 18',
  ];

  test('a wide card shows the whole thing', () {
    expect(_pick(exodus, 2000), exodus.first);
  });

  test('the ellipsis width from the screenshot now drops the edition '
      'instead of cutting it', () {
    // The hero's text column on that phone is roughly 240 logical px:
    // a 412 px screen, less the card padding, the icon, the gap and
    // the chevron. The old code ellipsised here.
    final chosen = _pick(exodus, 240);
    expect(chosen, isNot(contains('…')));
    expect(exodus, contains(chosen),
        reason: 'the widget must show one of the lines it was given, '
            'whole — a line it assembled itself is a line nobody '
            'reviewed');
    expect(chosen, contains('18'),
        reason: 'the chapter is the one thing the card exists to say');
  });

  test('every step down is shorter than the one above it', () {
    // Candidates out of order would make measurement meaningless: the
    // widget takes the FIRST that fits, so a longer line below a
    // shorter one can never be reached.
    var previous = double.infinity;
    for (final candidate in exodus) {
      final painter = TextPainter(
        text: TextSpan(text: candidate, style: _style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      expect(painter.width, lessThan(previous),
          reason: '"$candidate" is not narrower than the candidate above '
              'it, so it is unreachable');
      previous = painter.width;
      painter.dispose();
    }
  });

  test('an impossible width still returns a real line, not an empty one',
      () {
    expect(_pick(exodus, 1), exodus.last);
  });

  testWidgets('the rendered hero line carries no ellipsis at phone width',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 240,
            child: FittedLine(candidates: exodus, style: _style),
          ),
        ),
      ),
    ));
    final text = tester.widget<Text>(find.byType(Text));
    expect(exodus, contains(text.data));
    // `didExceedMaxLines` is the renderer's own verdict on whether it
    // had to cut — the assertion the screenshot was really about.
    final paragraph = tester.renderObject<RenderParagraph>(find.byType(Text));
    expect(paragraph.didExceedMaxLines, isFalse);
  });
}
