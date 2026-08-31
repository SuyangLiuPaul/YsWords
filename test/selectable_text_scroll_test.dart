// A reader's thumb landing on sermon text used to kill the page.
//
// 2026-08-31. Reported as "为什么有些信息的页面不能往上滑，有些可以" — some
// sermons scroll and some don't. Nothing was different about the
// sermons. What differed was where the thumb landed.
//
// AppScrollBehavior (v1.4.5) sets
// `BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())` on
// EVERY Scrollable in the tree. A SelectableText builds one of its own
// (inside EditableText), and `AlwaysScrollable` made that inner
// scrollable accept a vertical drag even though it has a zero scroll
// extent and nothing to move. It won the gesture arena, and the ListView
// underneath never saw the drag. Land on the title, the meta chips or
// the page margins and the page scrolled; land on a paragraph and it was
// dead — which is exactly what "some pages, not others" feels like.
//
// The fix is `scrollPhysics: kSelectableTextPhysics` at every call site:
// a display-only text widget should not own a scrollable. The other
// candidate — dropping AlwaysScrollableScrollPhysics from
// AppScrollBehavior — also cures the drag, but it takes the deliberate
// short-list rubber-band with it (measured: 120 px of overscroll → 0),
// so the last test here pins that rubber-band as well. Fix one bug,
// don't trade it for another.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/app_scroll_behavior.dart';

/// Marker comment that opts a call site out of [kSelectableTextPhysics]
/// because its inner scrollable is genuinely the scroller.
const String kOptOutMarker = 'SelectableText-owns-its-scroller';

late ScrollController controller;

Widget _page({required ScrollPhysics? textPhysics, int paragraphs = 40}) {
  controller = ScrollController();
  return MaterialApp(
    scrollBehavior: const AppScrollBehavior().copyWith(scrollbars: true),
    home: Scaffold(
      body: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          for (var i = 0; i < paragraphs; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: SelectableText.rich(
                TextSpan(text: 'Paragraph $i. ' * 12),
                scrollPhysics: textPhysics,
              ),
            ),
        ],
      ),
    ),
  );
}

Future<double> _dragOnTheText(WidgetTester tester) async {
  await tester.drag(find.byType(SelectableText).first, const Offset(0, -300));
  await tester.pumpAndSettle();
  return controller.offset;
}

void main() {
  group('a drag that starts on the text', () {
    testWidgets('scrolls the page when the text yields its scrollable',
        (tester) async {
      await tester.pumpWidget(_page(textPhysics: kSelectableTextPhysics));
      expect(await _dragOnTheText(tester), greaterThan(0),
          reason: 'the reader swiped up on a paragraph and nothing moved');
    });

    testWidgets('is swallowed without it — the bug this file exists for',
        (tester) async {
      // Not a wish, a guard: if this ever starts scrolling on its own,
      // Flutter changed and the call-site scan below can be retired.
      await tester.pumpWidget(_page(textPhysics: null));
      expect(await _dragOnTheText(tester), 0.0,
          reason: 'bare SelectableText no longer swallows the drag — '
              're-check whether kSelectableTextPhysics is still needed');
    });
  });

  test('kSelectableTextPhysics refuses the drag outright', () {
    expect(kSelectableTextPhysics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('short lists still rubber-band', (tester) async {
    // AlwaysScrollableScrollPhysics is what makes a one-screen page
    // bounce instead of feeling dead. Removing it would also fix the
    // drag bug, so this test says out loud that it is not the fix.
    await tester.pumpWidget(
        _page(textPhysics: kSelectableTextPhysics, paragraphs: 1));
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(ListView)));
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump();
    final overscroll = controller.offset;
    await gesture.up();
    await tester.pumpAndSettle();
    expect(overscroll, greaterThan(0),
        reason: 'a short page stopped rubber-banding');
  });

  test('every SelectableText in lib/ yields its scrollable', () {
    final offenders = <String>[];
    final optedOut = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match
          in RegExp(r'SelectableText(\.rich)?\s*\(').allMatches(source)) {
        // Doc comments and changelog entries name the widget without
        // building one — `lib/utils/ai_markdown.dart` and
        // `lib/constants/app_version.dart` both do. Skip prose.
        final lineStart = source.lastIndexOf('\n', match.start) + 1;
        final linePrefix = source.substring(lineStart, match.start).trimLeft();
        if (linePrefix.startsWith('//') ||
            linePrefix.startsWith('*') ||
            linePrefix.startsWith('/*')) {
          continue;
        }
        // Walk to the matching close paren so the search stays inside
        // this one call and cannot borrow a sibling's argument.
        var depth = 0;
        var end = match.end - 1;
        for (; end < source.length; end++) {
          final c = source[end];
          if (c == '(') depth++;
          if (c == ')') {
            depth--;
            if (depth == 0) break;
          }
        }
        final call = source.substring(match.start, end + 1);
        final lineNo = '\n'.allMatches(source.substring(0, match.start)).length + 1;
        final where = '${entity.path}:$lineNo';

        // The opt-out marker sits in the comment directly above.
        final before = source.substring(
            match.start < 500 ? 0 : match.start - 500, match.start);
        if (before.contains(kOptOutMarker)) {
          optedOut.add(where);
          continue;
        }
        if (!call.contains('scrollPhysics:')) offenders.add(where);
      }
    }

    expect(offenders, isEmpty,
        reason: 'these SelectableText call sites keep their own scrollable '
            'and will swallow a drag meant for the page under them. Pass '
            '`scrollPhysics: kSelectableTextPhysics`, or — if the inner '
            'scrollable really is the scroller — put the marker comment '
            '"$kOptOutMarker" directly above the call.');

    // Guards the escape hatch itself: an opt-out is a decision, not a
    // way to make this test quiet, so the count is pinned.
    expect(optedOut, hasLength(1),
        reason: 'the set of deliberate scroll-owning SelectableTexts '
            'changed: $optedOut');
  });
}
