// The operator's own picture on the wall, under a scrim that is not
// theirs to turn off.
//
// 2026-09-15. 「projector可以选择image background吗在setting设置」.
//
// The scrim is the part worth pinning. A verse on a wall has exactly
// one job, and a photograph has no obligation to be dark where the
// words fall. An operator able to lower the scrim would lower it over
// the wrong photograph eventually — in front of a room, with no way to
// tell until the words had gone. So it is a constant, and these tests
// assert that it is always there and always between the picture and the
// type.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/models/verse.dart';
import 'package:yswords/widgets/projection_stage.dart';

const _verse = Verse(
    book: '罗马书', chapter: 8, verse: 1, text: '现在那些在基督耶稣里的人就不被定罪了。');

/// A 1×1 transparent PNG — enough to be a real `ImageProvider` without
/// putting a fixture file in the repo.
final _png = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Future<void> _wall(
  WidgetTester tester, {
  required ProjectionGround ground,
  ImageProvider? backdrop,
  bool blank = false,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: ProjectionStage(
      verses: const [_verse],
      reference: '罗马书 8:1',
      versionCode: 'cuvs-yhwh',
      typeSize: 64,
      blank: blank,
      locale: 'zh-Hans',
      scheme: projectionDarkScheme(Colors.lightBlue),
      ground: ground,
      secondOn: false,
      secondTexts: null,
      secondCode: null,
      secondLoading: false,
      layout: const ProjectionLayout(),
      backdrop: backdrop,
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('with a picture, the wall paints it', (tester) async {
    await _wall(tester,
        ground: ProjectionGround.photo, backdrop: MemoryImage(_png));
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('and always under the scrim', (tester) async {
    await _wall(tester,
        ground: ProjectionGround.photo, backdrop: MemoryImage(_png));
    final scrim = tester.widgetList<ColoredBox>(find.byType(ColoredBox)).where(
        (b) => b.color.a > 0.3 && b.color.a < 1.0);
    expect(scrim, isNotEmpty, reason: 'nothing is dimming the picture');
    expect(scrim.first.color.a, closeTo(kProjectionPhotoScrim, 0.001));
  });

  testWidgets('the picture is behind the scrim, and the scrim behind the '
      'words', (tester) async {
    // Order is the whole reason the scrim works. Asserted as a property
    // of the painted tree rather than trusted to the source.
    await _wall(tester,
        ground: ProjectionGround.photo, backdrop: MemoryImage(_png));
    final stack = tester.widget<Stack>(find.byType(Stack).first);
    final kinds = stack.children.map((w) => w.runtimeType.toString()).toList();
    final image = kinds.indexWhere((k) => k.contains('Image'));
    final scrim = kinds.indexWhere((k) => k.contains('ColoredBox'));
    expect(image, greaterThanOrEqualTo(0));
    expect(scrim, greaterThan(image),
        reason: 'the scrim is under the picture, so it dims nothing');
    expect(kinds.length, greaterThan(scrim + 1),
        reason: 'the passage is not above the scrim, so it is dimmed too');
  });

  testWidgets('no picture chosen is the default wall, not a blank one',
      (tester) async {
    // The rule an operator who clears their photo depends on.
    await _wall(tester, ground: ProjectionGround.photo);
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('现在那些在基督耶稣里'), findsOneWidget,
        reason: 'the passage went missing with the picture');
  });

  testWidgets('a picture does not leak onto the other grounds',
      (tester) async {
    for (final g in ProjectionGround.values) {
      if (g == ProjectionGround.photo) continue;
      await _wall(tester, ground: g, backdrop: MemoryImage(_png));
      expect(find.byType(Image), findsNothing,
          reason: '${g.name} painted the photo backdrop');
    }
  });

  testWidgets('blanking still blanks', (tester) async {
    // The stage's own rule 2: pressing B changes exactly one thing —
    // whether there is text. A photo ground blanks to the photo.
    await _wall(tester,
        ground: ProjectionGround.photo,
        backdrop: MemoryImage(_png),
        blank: true);
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('现在那些在基督耶稣里'), findsNothing);
    expect(find.textContaining('罗马书 8:1'), findsNothing,
        reason: 'a blank wall that still names a verse tells the room '
            'where the sermon is while the preacher is somewhere else');
  });

  test('every ground is still dark, the photo one included', () {
    // `projectionGroundColors` exists so the luminance rule is a
    // property of the SET. The photo ground has to answer it too: its
    // base is what shows with no picture, and behind one that does not
    // reach the edge.
    const scheme = ColorScheme.dark();
    for (final g in ProjectionGround.values) {
      for (final c in projectionGroundColors(g, scheme)) {
        expect(c.computeLuminance(), lessThan(0.25),
            reason: '${g.name} puts ${c.toString()} on the wall');
      }
    }
  });
}
