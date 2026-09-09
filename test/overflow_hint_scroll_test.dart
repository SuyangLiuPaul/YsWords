// The selection bar's action row scrolls, and now it says so.
//
// Each test is a mutation guard: drop the right hint and "fits" still
// passes but "overflows" fails; drop the left hint and "scrolled to the
// end" fails; make the chevron decorative and "tapping scrolls" fails.

import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/widgets/overflow_hint_scroll.dart';

final tapped = <int>[];

Widget _host({required double viewport, required int items}) {
  tapped.clear();
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: viewport,
          height: 48,
          child: LayoutBuilder(
            builder: (_, c) => OverflowHintScroll(
              fadeColor: Colors.white,
              minWidth: c.maxWidth,
              moreLabel: 'More',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < items; i++)
                    GestureDetector(
                      onTap: () => tapped.add(i),
                      child: SizedBox(width: 48, height: 48, child: Text('$i')),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  final right = find.byIcon(Icons.chevron_right_rounded);
  final left = find.byIcon(Icons.chevron_left_rounded);

  testWidgets('when everything fits, no hint is drawn', (tester) async {
    await tester.pumpWidget(_host(viewport: 300, items: 3));
    await tester.pumpAndSettle();
    expect(right, findsNothing);
    expect(left, findsNothing);
  });

  testWidgets('when the row overflows, the right edge says so',
      (tester) async {
    await tester.pumpWidget(_host(viewport: 200, items: 10));
    await tester.pumpAndSettle();
    expect(right, findsOneWidget);
    expect(left, findsNothing);
  });

  testWidgets('scrolled to the end, the hint moves to the left edge',
      (tester) async {
    await tester.pumpWidget(_host(viewport: 200, items: 10));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SingleChildScrollView), const Offset(-2000, 0));
    await tester.pumpAndSettle();
    expect(right, findsNothing);
    expect(left, findsOneWidget);
  });

  testWidgets('tapping the chevron scrolls — it is a button, not a decal',
      (tester) async {
    await tester.pumpWidget(_host(viewport: 200, items: 10));
    await tester.pumpAndSettle();
    final scrollable = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView));
    expect(scrollable.controller!.offset, 0);
    await tester.tap(right);
    await tester.pumpAndSettle();
    expect(scrollable.controller!.offset, greaterThan(100));
    // Halfway along, both edges have more.
    expect(left, findsOneWidget);
  });

  testWidgets('a swipe that starts ON the chevron still scrolls the row',
      (tester) async {
    // Review 2026-09-09: the first version stacked an opaque tap target
    // over the scroll view, so grabbing the cut-off icon did nothing.
    await tester.pumpWidget(_host(viewport: 200, items: 10));
    await tester.pumpAndSettle();
    final scrollable = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView));
    await tester.drag(right, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(scrollable.controller!.offset, greaterThan(100));
  });

  testWidgets('the fade does not steal a tap from the icon under it',
      (tester) async {
    // hintWidth 32, chevron 24: x in [168,176) of a 200-wide viewport is
    // fade-only. Item 3 spans [144,192) — a tap at 172 must reach it.
    await tester.pumpWidget(_host(viewport: 200, items: 10));
    await tester.pumpAndSettle();
    final origin = tester.getTopLeft(find.byType(OverflowHintScroll));
    await tester.tapAt(origin + const Offset(172, 24));
    await tester.pumpAndSettle();
    expect(tapped, [3]);
  });

  testWidgets('a few hidden pixels earn no hint', (tester) async {
    // 4 × 52 = 208 in a 200 viewport: 8 px hidden, under the threshold.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            height: 48,
            child: OverflowHintScroll(
              fadeColor: Colors.white,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 4; i++) const SizedBox(width: 52, height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(right, findsNothing);
    expect(kOverflowHintThreshold, greaterThan(8));
  });

  testWidgets('the chevron carries the accessibility label', (tester) async {
    await tester.pumpWidget(_host(viewport: 200, items: 10));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('More'), findsOneWidget);
  });

  test('both selection bars route their action row through the hint',
      () {
    // Wiring guard: a future refactor that reverts to a bare
    // SingleChildScrollView would pass every widget test above and
    // silently lose the hint where it matters.
    final src = _read('lib/widgets/bible_reading_pane.dart');
    final bar = src.substring(src.indexOf('class _SelectionActionBar'));
    final ourBar = bar.substring(0, bar.indexOf('\nclass '));
    expect(ourBar, contains('OverflowHintScroll('));
    expect(ourBar, contains('children: actionButtons'));
    expect(ourBar, isNot(contains('SingleChildScrollView(')),
        reason: 'the action row must not bypass the hint');
  });
  testWidgets(
      'the two chevrons are announced differently, because they do '
      'opposite things', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: OverflowHintScroll(
              fadeColor: const Color(0xFFFFFFFF),
              minWidth: 200,
              moreLabel: 'More',
              backLabel: 'Previous actions',
              child: Row(
                children: [
                  for (var i = 0; i < 8; i++)
                    const SizedBox(width: 60, height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Only the forward chevron is showing at rest.
    expect(find.bySemanticsLabel('More'), findsOneWidget);
    expect(find.bySemanticsLabel('Previous actions'), findsNothing);

    await tester.drag(find.byType(SingleChildScrollView), const Offset(-120, 0));
    await tester.pumpAndSettle();

    // Scrolled in: now both are reachable, and a screen reader can tell
    // them apart. Before this, both said "More" and the back chevron
    // announced itself as the way to see more.
    expect(find.bySemanticsLabel('Previous actions'), findsOneWidget,
        reason: 'the back chevron must not borrow the forward label');
  });

}

String _read(String path) => io.File(path).readAsStringSync();
