// The operator's own type settings for the wall.
//
// 2026-09-15. 「projector mode 可以有设置 下面类似于Genesis 2:17 这些的字体
// 大小 还有中文英文的相应的字体吗？」
//
// Two things the wall did not have. The reference was
// `typeSize × 0.26`, floored at 26 px, with no way to touch it; and the
// type was whatever the engine chose, with only a CJK fallback pinned,
// so a wall carrying a Chinese edition with an English one under it set
// both in the same face.
//
// The font is chosen by the LANGUAGE OF THE EDITION rather than by
// scanning the characters, which is the decision most worth pinning: a
// Chinese edition quoting a Greek word is still Chinese scripture, and
// an English one carrying 雅伟 in a note is still English.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_words/models/verse.dart';
import 'package:yahwehs_words/widgets/projection_stage.dart';

const _zh = Verse(
    book: '罗马书', chapter: 8, verse: 1, text: '现在那些在基督耶稣里的人就不被定罪了。');

Future<void> _wall(
  WidgetTester tester, {
  int referenceStep = 0,
  String fontZh = '',
  String fontEn = '',
  bool secondOn = false,
  double typeSize = 64,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: ProjectionStage(
      verses: const [_zh],
      reference: '罗马书 8:1',
      versionCode: 'cuvs-yhwh',
      typeSize: typeSize,
      blank: false,
      locale: 'zh-Hans',
      scheme: projectionDarkScheme(Colors.lightBlue),
      secondOn: secondOn,
      secondTexts: secondOn ? const ['There is now no condemnation.'] : null,
      secondCode: secondOn ? 'kjv' : null,
      secondLoading: false,
      layout: const ProjectionLayout(),
      referenceStep: referenceStep,
      fontZh: fontZh,
      fontEn: fontEn,
    ),
  ));
  await tester.pump();
}

/// The size a piece of text was actually painted at.
double _sizeOf(WidgetTester tester, String contains) => tester
    .widget<Text>(find.textContaining(contains))
    .style!
    .fontSize!;

String? _familyOf(WidgetTester tester, String contains) =>
    tester.widget<Text>(find.textContaining(contains)).style!.fontFamily;

void main() {
  group('the reference size', () {
    testWidgets('auto is the ratio, floored — what the wall always did',
        (tester) async {
      await _wall(tester, typeSize: 64);
      // 64 × 0.26 = 16.6, under the 26 px floor, so the floor governs.
      expect(_sizeOf(tester, '罗马书 8:1'), kProjectionReferenceFloor);

      await _wall(tester, typeSize: 184);
      // 184 × 0.26 = 47.8, over the floor, so the ratio governs.
      expect(_sizeOf(tester, '罗马书 8:1'),
          closeTo(184 * kProjectionReferenceScale, 0.01));
    });

    testWidgets('a pinned size is the size, whatever the passage is doing',
        (tester) async {
      // The point of the setting: a small screen at the front of a big
      // hall needs the address bigger than the ratio would ever make it.
      final pinned = kProjectionReferenceSteps.indexOf(52);
      expect(pinned, greaterThan(0), reason: '52 px left the ladder');
      await _wall(tester, referenceStep: pinned, typeSize: 40);
      expect(_sizeOf(tester, '罗马书 8:1'), 52);
    });

    test('a stored index beyond the ladder does not strand the wall', () {
      // Clamped at the READ, so shortening the ladder cannot leave an
      // operator with a reference that throws mid-service.
      expect(projectionReferenceSizeFor(64, 999),
          kProjectionReferenceSteps.last);
      expect(projectionReferenceSizeFor(64, -3), kProjectionReferenceFloor);
    });

    test('auto is first, and is therefore the default', () {
      expect(kProjectionReferenceSteps.first, isNull);
      expect(projectionReferenceSizeFor(64, 0), kProjectionReferenceFloor);
    });
  });

  group('the faces', () {
    testWidgets('unset leaves the engine exactly where it was',
        (tester) async {
      await _wall(tester);
      expect(_familyOf(tester, '现在那些在基督耶稣里'), isNull);
    });

    testWidgets('the Chinese face goes on the Chinese edition and the '
        'English face on the English one', (tester) async {
      await _wall(tester,
          fontZh: 'Noto Serif SC', fontEn: 'EB Garamond', secondOn: true);
      expect(_familyOf(tester, '现在那些在基督耶稣里'), 'Noto Serif SC');
      expect(_familyOf(tester, 'There is now no condemnation'), 'EB Garamond');
    });

    testWidgets('a Chinese wall with no English face set leaves the '
        'companion alone', (tester) async {
      await _wall(tester, fontZh: 'Noto Serif SC', secondOn: true);
      expect(_familyOf(tester, '现在那些在基督耶稣里'), 'Noto Serif SC');
      expect(_familyOf(tester, 'There is now no condemnation'), isNull,
          reason: 'setting one face must not silently set the other');
    });
  });

  group('an empty key means the reader\'s own font, not the engine default',
      () {
    test('projectionFamilyFor', () {
      expect(projectionFamilyFor('', 'Literata'), 'Literata',
          reason: '「跟随阅读字体」 is the reader\'s family, and the wall has '
              'to be told what that is — it cannot read the setting');
      expect(projectionFamilyFor('system', 'Literata'),
          isNot('Literata'),
          reason: 'a pinned key wins over the reader\'s');
    });
  });
}
