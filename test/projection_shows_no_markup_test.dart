// The room reads scripture, not the file the scripture is stored in.
//
// 2026-09-15, photographed off a phone with the markup circled: the
// projector preview put
//
//     …挣脱了罪和死的规律。<note:2节注："生命之灵的规律"中的"灵"字译自
//     τὸ πνεῦμα。和合本加插了"圣"字来指圣灵…>
//
// on the wall, at wall size, where a congregation would have read it.
//
// Every other surface in the app goes through one of the sanitisers in
// `text_patterns.dart` — the reader splits the markup into styled spans,
// copy uses `sanitizeForCopy`, search uses `sanitizeForSearch`, the
// popup its own. The projector was written later and went straight to
// `verse.text`, and nothing noticed because the fixtures every existing
// projector test uses are clean strings.
//
// So the fixtures here are deliberately dirty, and they carry every
// kind of markup the corpus actually ships, not just the one that was
// photographed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_words/models/verse.dart';
import 'package:yahwehs_words/widgets/projection_stage.dart';

/// One verse of each shape the assets contain.
const _dirty = <Verse>[
  Verse(
    book: '罗马书',
    chapter: 8,
    verse: 2,
    text: '因为生命之灵的规律在基督耶稣里使你获得释放，挣脱了罪和死的规律。'
        '<note:2节注："生命之灵的规律"中的"灵"字译自 τὸ πνεῦμα。>',
  ),
  Verse(
    book: '罗马书',
    chapter: 8,
    verse: 3,
    text: '因为人肉体软弱的缘故，律法是无能为力，{然而律法所做不到的}，'
        '神却做到了。¶',
  ),
];

Future<void> _wall(
  WidgetTester tester, {
  List<String?>? secondTexts,
  ProjectionFlow flow = ProjectionFlow.verseByVerse,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: ProjectionStage(
      verses: _dirty,
      reference: '罗马书 8:2–3',
      versionCode: 'cuvs-yhwh',
      typeSize: 64,
      blank: false,
      locale: 'zh-Hans',
      scheme: projectionDarkScheme(Colors.lightBlue),
      secondOn: secondTexts != null,
      secondTexts: secondTexts,
      secondCode: secondTexts == null ? null : 'kjv',
      secondLoading: false,
      layout: ProjectionLayout(flow: flow),
    ),
  ));
  await tester.pump();
}

/// Everything the wall is currently painting, as one string.
String _onTheWall(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join('\n');

/// The sequences that are apparatus rather than scripture. A verse that
/// legitimately contains any of these does not exist in the corpus.
const _markup = <String>['<note:', '¶', '{', '}'];

void main() {
  testWidgets('verse by verse: nothing on the wall is markup',
      (tester) async {
    await _wall(tester);
    final wall = _onTheWall(tester);
    for (final m in _markup) {
      expect(wall, isNot(contains(m)),
          reason: 'the wall is showing "$m" to the room');
    }
  });

  testWidgets('run together: nothing on the wall is markup', (tester) async {
    // The other flow builds its spans by a different path, so it gets
    // its own assertion rather than being assumed to follow.
    await _wall(tester, flow: ProjectionFlow.continuous);
    final wall = _onTheWall(tester);
    for (final m in _markup) {
      expect(wall, isNot(contains(m)), reason: 'run-together shows "$m"');
    }
  });

  testWidgets('the companion edition is cleaned too', (tester) async {
    await _wall(tester, secondTexts: [
      'For the law of the Spirit of life. <note:on πνεῦμα>',
      'What the law could not do.',
    ]);
    final wall = _onTheWall(tester);
    expect(wall, isNot(contains('<note:')),
        reason: 'the second edition went to the wall unsanitised');
    expect(wall, contains('For the law of the Spirit of life'),
        reason: 'cleaning must not take the verse with it');
  });

  testWidgets('the words themselves survive', (tester) async {
    // The other half of the contract. A sanitiser that emptied the wall
    // would pass every assertion above.
    await _wall(tester);
    final wall = _onTheWall(tester);
    expect(wall, contains('挣脱了罪和死的规律'));
    expect(wall, contains('然而律法所做不到的'),
        reason: 'the braces are markup; the phrase inside them is the '
            'verse, and dropping it is the v1.2.56 bug over again');
  });
}
