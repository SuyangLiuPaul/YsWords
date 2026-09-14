// The wall fills its width, and the reference never sits on the words.
//
// 2026-09-15, from a phone screenshot of the Preview box in Settings:
// 「预览为什么这样很难看」. The passage was a column of single characters
// about a finger wide down the middle of the box, with the reference
// printed across it.
//
// TWO DEFECTS, both of them the wall's and not the preview's — the
// preview is just the first place small enough to show them.
//
//   1. The block was drawn at the operator's chosen size and then
//      shrunk to fit with `BoxFit.scaleDown`. Pinning the child to the
//      usable width was supposed to make the horizontal scale exactly
//      1, so that only height could drive the fit. It does fix the
//      LAYOUT width — but `scaleDown` is uniform, so the moment height
//      binds, the rendered block narrows by the same factor as it
//      shortens. A passage that needs to be half as tall comes out half
//      as WIDE, and the other half of the wall is empty.
//
//      The fix is the one a printer would use: keep the measure, change
//      the type. The size is solved so the passage fits the height when
//      set across the full width.
//
//   2. The corner reference was a `Positioned` inside the margin, at a
//      size with a 26 px floor. On a wall whose margin is 118 px that
//      is comfortably inside it; on a preview box whose margin is 21 px
//      it is not, and the reference printed straight through the last
//      lines of the verse. The reference is now a row of the same
//      column, so the room it takes is room the passage was never
//      offered.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/widgets/projection_stage.dart';

/// Two verses of Chinese — enough that 76 px type cannot fit a small
/// box, which is the condition both defects need.
const _verses = <Verse>[
  Verse(
      book: '出埃及记',
      chapter: 19,
      verse: 1,
      text: '以色列人出埃及地以后，满了三个月的那一天，就来到西乃的旷野。'),
  Verse(
      book: '出埃及记',
      chapter: 19,
      verse: 2,
      text: '他们离了利非订，来到西乃的旷野，就在那里的山下安营。'),
];

Widget _stage({
  required ProjectionReferencePlace reference,
  double typeSize = 76,
}) =>
    MaterialApp(
      home: Scaffold(
        body: ProjectionStage(
          verses: _verses,
          reference: '出埃及记 19:1–2',
          versionCode: 'cuvs-yhwh',
          typeSize: typeSize,
          blank: false,
          locale: 'zh-Hans',
          scheme: projectionDarkScheme(Colors.lightBlue),
          secondOn: false,
          secondTexts: null,
          secondCode: null,
          secondLoading: false,
          layout: ProjectionLayout(reference: reference),
        ),
      ),
    );

/// Give the test surface the size of the screen being modelled. A
/// `SizedBox(width: 1920)` inside the default 800x600 surface is an
/// 800 px wall wearing a label that says 1920, which is exactly the
/// confusion this file exists to settle.
Future<void> _on(WidgetTester tester, Size size, Widget app) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
}

/// The rectangle the first verse's paragraph actually occupies on
/// screen — after every scale, offset and centring between it and the
/// stage's own box.
Rect _painted(WidgetTester tester, String text) {
  // `textContaining`, not `text`: with two verses up each line carries
  // its number, so the paragraph's concatenated data is 「1 以色列人…」.
  final box = tester.renderObject<RenderBox>(find.textContaining(text));
  final origin = box.localToGlobal(Offset.zero);
  return origin & box.size;
}

void main() {
  // The Settings preview: a 16:9 box about a third of a phone wide.
  const previewBox = Size(343, 193);
  // A 1080p wall, for the comparison that makes the point.
  const wall = Size(1920, 1080);

  testWidgets('the passage uses the width it is given, not a ribbon down '
      'the middle', (tester) async {
    await _on(tester, previewBox,
        _stage(reference: ProjectionReferencePlace.corner));

    final painted = _painted(tester, _verses.first.text);
    // The stage concedes 7% of the width on each side and nothing else.
    // Anything much narrower than the rest is the uniform-scale bug
    // coming back: the block would be complete and legible and still
    // wrong, because it would be using a fifth of the wall.
    final usable = previewBox.width * (1 - kProjectionSideMargin * 2);
    expect(painted.width, greaterThan(usable * 0.9),
        reason: 'the passage is ${painted.width.toStringAsFixed(0)} px '
            'across a ${usable.toStringAsFixed(0)} px measure — it was '
            'scaled down uniformly instead of being set smaller');
  });

  testWidgets('the corner reference does not print over the last line',
      (tester) async {
    await _on(tester, previewBox,
        _stage(reference: ProjectionReferencePlace.corner));

    final last = _painted(tester, _verses.last.text);
    final ref = _painted(tester, '出埃及记 19:1–2 · ');
    expect(ref.top, greaterThanOrEqualTo(last.bottom),
        reason: 'the reference starts at y=${ref.top.toStringAsFixed(0)} '
            'while the passage still runs to '
            '${last.bottom.toStringAsFixed(0)} — the room reads one on '
            'top of the other');
  });

  testWidgets('nothing is drawn outside the box', (tester) async {
    await _on(tester, previewBox,
        _stage(reference: ProjectionReferencePlace.corner));
    final stage = _painted(tester, _verses.first.text);
    expect(stage.top, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull,
        reason: 'an overflow on the wall is a verse the room cannot read');
  });

  testWidgets('a wall big enough gets the size the operator chose',
      (tester) async {
    // The solve is a CEILING, not a rule: where the passage fits at the
    // chosen size, that is the size.
    await _on(
        tester, wall, _stage(reference: ProjectionReferencePlace.corner));
    final drawn = tester
        .widget<Text>(find.textContaining(_verses.first.text))
        .style!
        .fontSize!;
    expect(drawn, 76);
  });

  testWidgets('the preview shows the wall — same proportions, both boxes '
      'being 16:9', (tester) async {
    // The point of a preview, and the thing that was wrong with this
    // one. The two boxes differ by 5.6x, so the passage has to occupy
    // the same SHARE of each. It only can if the type size is quoted
    // against the box it is drawn in — 76 px in a 343 px preview is not
    // a small wall, it is a wall five times closer.
    double share(Size size) =>
        _painted(tester, _verses.first.text).height / size.height;

    await _on(tester, wall, _stage(reference: ProjectionReferencePlace.off));
    final onWall = share(wall);

    await _on(
      tester,
      previewBox,
      _stage(
        reference: ProjectionReferencePlace.off,
        typeSize: projectionPreviewTypeSize(previewBox.width, 76),
      ),
    );
    final inPreview = share(previewBox);

    expect((inPreview - onWall).abs(), lessThan(0.08),
        reason: 'the passage fills ${(onWall * 100).round()}% of the wall '
            'and ${(inPreview * 100).round()}% of the preview — the '
            'preview is not showing what the operator will get');
  });
}
