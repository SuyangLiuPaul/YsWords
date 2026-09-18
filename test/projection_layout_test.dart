import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_words/models/projection_preset.dart';
import 'package:yahwehs_words/models/verse.dart';
import 'package:yahwehs_words/services/projection_broadcast.dart';
import 'package:yahwehs_words/widgets/projection_stage.dart';

/// How the wall is laid out — asked for on 2026-09-13: "middle aligned,
/// verse by verse 还是连在一起, plain txt, include ref, devotional
/// format".
///
/// Four independent choices rather than a list of named formats, so
/// what is pinned here is each choice on its own, the combination that
/// has a name, and the two places a choice has to survive: a saved
/// preset, and the follower window.
void main() {
  const verses = [
    Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'In the beginning.'),
    Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'The earth was void.'),
  ];

  Future<void> wall(
    WidgetTester tester, {
    ProjectionLayout layout = ProjectionLayout.standard,
    List<Verse> shown = verses,
    bool blank = false,
    List<String?>? secondTexts,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ProjectionStage(
        verses: shown,
        reference: 'Genesis 1:1',
        versionCode: 'kjv',
        typeSize: 64,
        blank: blank,
        locale: 'en',
        scheme: projectionDarkScheme(Colors.lightBlue),
        secondOn: secondTexts != null,
        secondTexts: secondTexts,
        secondCode: secondTexts == null ? null : 'cuvs-yhwh',
        layout: layout,
      ),
    ));
    await tester.pump();
  }

  group('the layout the operator sets', () {
    testWidgets('centred by default, from the margin when asked',
        (tester) async {
      await wall(tester);
      expect(
          tester
              .widgetList<Text>(find.byType(Text))
              .any((t) => t.textAlign == TextAlign.center),
          isTrue);

      await wall(tester,
          layout: const ProjectionLayout(align: ProjectionAlign.start));
      final aligns =
          tester.widgetList<Text>(find.byType(Text)).map((t) => t.textAlign);
      // `start`, never `left`: a Hebrew passage starts on the right.
      expect(aligns.contains(TextAlign.left), isFalse);
      expect(aligns.contains(TextAlign.start), isTrue);
    });

    testWidgets('verse by verse is two blocks; run together is one',
        (tester) async {
      await wall(tester);
      expect(
          find.textContaining('In the beginning. 2 The earth was void.',
              findRichText: true),
          findsNothing);

      await wall(tester,
          layout: const ProjectionLayout(flow: ProjectionFlow.continuous));
      // One paragraph, with the numbers inline as a printed Bible sets
      // them — the space goes BEFORE the number, or it closes up
      // against the previous sentence.
      expect(
          find.textContaining('In the beginning. 2 The earth was void.',
              findRichText: true),
          findsOneWidget);
    });

    testWidgets('numbers off gives scripture with nothing in front of it',
        (tester) async {
      await wall(tester);
      expect(find.textContaining('1 In the beginning.', findRichText: true),
          findsOneWidget);

      await wall(tester, layout: const ProjectionLayout(numbers: false));
      expect(find.textContaining('1 In the beginning.', findRichText: true),
          findsNothing);
      expect(find.textContaining('In the beginning.', findRichText: true),
          findsOneWidget);
    });

    testWidgets('a single verse still carries no number, on or off',
        (tester) async {
      for (final on in [true, false]) {
        await wall(tester,
            shown: [verses.first], layout: ProjectionLayout(numbers: on));
        expect(find.textContaining('1 In the beginning.', findRichText: true),
            findsNothing,
            reason: 'numbers: $on — the reference already names it');
      }
    });

    testWidgets('the reference moves, and can come off the wall',
        (tester) async {
      await wall(tester);
      expect(find.textContaining('Genesis 1:1'), findsOneWidget);

      await wall(tester,
          layout: const ProjectionLayout(
              reference: ProjectionReferencePlace.under));
      // One, not two: it moved rather than appearing in both places.
      expect(find.textContaining('Genesis 1:1'), findsOneWidget);

      await wall(tester,
          layout: const ProjectionLayout(
              reference: ProjectionReferencePlace.off));
      expect(find.textContaining('Genesis 1:1'), findsNothing);
      expect(find.textContaining('In the beginning.', findRichText: true),
          findsOneWidget,
          reason: 'taking the address off the wall is not blanking it');
    });

    testWidgets('the devotional combination is what the word means',
        (tester) async {
      await wall(tester, layout: ProjectionLayout.devotional);
      expect(
          find.textContaining('In the beginning. The earth was void.',
              findRichText: true),
          findsOneWidget);
      expect(find.textContaining('1 In the beginning', findRichText: true),
          findsNothing);
      expect(find.textContaining('Genesis 1:1'), findsOneWidget);
      expect(ProjectionLayout.devotional.isDevotional, isTrue);
      expect(ProjectionLayout.standard.isDevotional, isFalse);
    });

    testWidgets('blanking still beats every layout', (tester) async {
      await wall(tester, blank: true, layout: ProjectionLayout.devotional);
      expect(find.textContaining('In the beginning', findRichText: true),
          findsNothing);
      expect(find.textContaining('Genesis'), findsNothing);
    });

    testWidgets('the companion edition follows the same flow', (tester) async {
      await wall(tester,
          secondTexts: const ['起初。', '地是空虚的。'],
          layout: const ProjectionLayout(flow: ProjectionFlow.continuous));
      expect(find.textContaining('起初。 2 地是空虚的。', findRichText: true),
          findsOneWidget,
          reason: 'two editions on one wall, set two different ways, is '
              'two walls');
    });
  });

  group('it survives being saved', () {
    test('a preset carries all four choices', () {
      const preset = ProjectionPreset(
        name: '主日敬拜',
        typeStep: 3,
        secondOn: false,
        secondVersion: '',
        groundName: 'ink',
        alignName: 'start',
        flowName: 'continuous',
        numbers: false,
        referenceName: 'under',
      );
      final back = ProjectionPreset.fromJson(
          jsonDecode(jsonEncode(preset.toJson())) as Map<String, dynamic>);
      expect(back, preset);
    });

    test('a preset saved before this existed means the shipped wall', () {
      final back = ProjectionPreset.fromJson(<String, dynamic>{
        'name': 'old',
        'typeStep': 2,
        'groundName': 'ink',
      })!;
      expect(projectionAlignFromName(back.alignName), ProjectionAlign.centre);
      expect(projectionFlowFromName(back.flowName),
          ProjectionFlow.verseByVerse);
      expect(back.numbers, isTrue);
      expect(projectionReferencePlaceFromName(back.referenceName),
          ProjectionReferencePlace.corner);
    });

    test('a name this build does not know falls back, it does not throw', () {
      expect(projectionAlignFromName('sideways'), ProjectionAlign.centre);
      expect(projectionFlowFromName(null), ProjectionFlow.verseByVerse);
      expect(projectionReferencePlaceFromName('ceiling'),
          ProjectionReferencePlace.corner);
      for (final junk in <Object?>[null, 'devotional', 42]) {
        expect(ProjectionLayout.fromJson(junk), ProjectionLayout.standard,
            reason: '$junk');
      }
    });
  });

  test('the follower is sent the layout, and reads every field', () {
    const f = ProjectionFrame(
      blank: false,
      typeSize: 76,
      reference: '诗篇 23:1',
      tags: ['和合本'],
      verses: [{'label': '1', 'text': '耶和华是我的牧者。'}],
      second: null,
      secondNote: null,
      groundColors: ['#000000'],
      radial: false,
      ink: '#ffffff',
      muted: '#888888',
      layout: ProjectionLayout.devotional,
    );
    expect((jsonDecode(jsonEncode(f.toJson())) as Map)['layout'], {
      'align': 'centre',
      'flow': 'continuous',
      'numbers': false,
      'reference': 'under',
    });
  });
}
