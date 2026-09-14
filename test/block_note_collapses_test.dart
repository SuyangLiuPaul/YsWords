// A 梁家鏗 block note opens on a tap, and starts closed.
//
// 2026-09-14, reported from a phone on SeekSparks' 羅馬書 8:
// 「sword这个部分没有collapse」, and the same widget with the same
// always-open behaviour ships here — 梁家鏗's apparatus is the same
// apparatus. Fixed in both on the same day rather than leaving one of
// two forked apps carrying it. That chapter carries two of these cards, one of which is a
// bare list of forty-odd cross references, and with both of them open by
// default the scripture they annotate is off the bottom of the screen.
//
// The inline `<note: …>` markers had been given open-in-place the same
// week; these had not, because they are a different widget with a
// different call site. This test is what stops the two from drifting
// apart again — it asserts the shape of the closed state, not just that
// some text is somewhere.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/widgets/block_note_card.dart';

const _note = '26-27节注：“灵也在我们的软弱中帮助我们……但灵亲自替我们代求'
    '……明了灵强烈的诉求”。其中“灵”皆译自 τὸ πνεῦμα，原文并无“圣”字，'
    '和合本加插了“圣”字来指圣灵。';

Widget _host(AppSettings settings) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: BlockNoteCard(note: _note, settings: settings),
        ),
      ),
    );

void main() {
  late AppSettings settings;

  setUp(() => settings = AppSettings());

  testWidgets('starts closed, showing one ellipsized line', (tester) async {
    await tester.pumpWidget(_host(settings));

    // A closed card must not be rendering the note as a selectable
    // paragraph — that is the always-open state this test exists to
    // refuse, and it would pass a naive "the text is present" check.
    expect(find.byType(SelectableText), findsNothing);

    final text = tester.widget<Text>(find.byType(Text).first);
    expect(text.maxLines, 1, reason: 'the closed card must be one line');
    expect(text.overflow, TextOverflow.ellipsis);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsNothing);
  });

  testWidgets('opens on a tap and the note becomes selectable',
      (tester) async {
    await tester.pumpWidget(_host(settings));
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    final selectable =
        tester.widget<SelectableText>(find.byType(SelectableText));
    expect(selectable.data, _note.trim(),
        reason: 'the whole note is there, and copyable — which is why it '
            'is a SelectableText and not a Text');
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('closes again, so it is a toggle and not a one-way reveal',
      (tester) async {
    await tester.pumpWidget(_host(settings));
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pumpAndSettle();

    expect(find.byType(SelectableText), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('the closed card is shorter than the open one, on a phone',
      (tester) async {
    // The measurement, because "maxLines: 1" is a property and this is
    // the consequence the reader actually gets. Without it a future
    // refactor could keep the property and still lay the note out full
    // height inside something that clips.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_host(settings));
    final closed = tester.getSize(find.byType(BlockNoteCard)).height;
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    final open = tester.getSize(find.byType(BlockNoteCard)).height;

    expect(open, greaterThan(closed * 2),
        reason: 'closed $closed px, open $open px — if these are close, '
            'the note was never actually collapsed');
  });

  testWidgets('the selectable body yields its scrollable to the page',
      (tester) async {
    // The other half of the same report: 「下滑不了」. A SelectableText
    // under AppScrollBehavior swallows a vertical drag unless it is
    // given NeverScrollableScrollPhysics. See
    // test/selectable_text_scroll_test.dart for the mechanism.
    await tester.pumpWidget(_host(settings));
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    final selectable =
        tester.widget<SelectableText>(find.byType(SelectableText));
    expect(selectable.scrollPhysics, isA<NeverScrollableScrollPhysics>());
  });
}
