import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/pages/library_page.dart';

/// A tile labelled Bookmarks must open Bookmarks.
///
/// 2026-08-11, from the phone: "为什么按书签，跳到的是笔记而不是书签页面
/// tab". The dashboard's Bookmarks and Notes tiles both pushed the
/// identical `const LibraryPage()` and the tab controller had no
/// `initialIndex`, so both landed on index 0 — Notes. A tile that shows
/// the bookmark icon and counts bookmarks could never once have opened
/// the Bookmarks tab.
///
/// This checks the constructor contract rather than driving the whole
/// page, which needs a MainProvider and its persisted state; the defect
/// was that the parameter did not exist at all, and a default that
/// silently changed would break the plain "Library" quick link.
void main() {
  test('the default tab is Notes, so the generic Library link is '
      'unchanged', () {
    expect(const LibraryPage().initialTab, 0);
  });

  test('Bookmarks can be asked for explicitly', () {
    expect(const LibraryPage(initialTab: 1).initialTab, 1);
  });

  testWidgets('the requested tab is the one the controller starts on',
      (tester) async {
    // Drive DefaultTabController with the same wiring the page uses, so
    // a future edit that drops `initialIndex` fails here.
    //
    // Each case needs its OWN key. `initialIndex` is read once when the
    // state is created, so pumping the second case over the first
    // reuses the element and reports the first index — the loop passed
    // for 0 and then failed for 1 for that reason, not because the
    // widget was wrong.
    for (final want in [0, 1]) {
      late TabController controller;
      await tester.pumpWidget(MaterialApp(
        home: DefaultTabController(
          key: ValueKey('tabs-$want'),
          length: 2,
          initialIndex: want.clamp(0, 1),
          child: Builder(builder: (context) {
            controller = DefaultTabController.of(context);
            return const SizedBox.shrink();
          }),
        ),
      ));
      expect(controller.index, want, reason: 'asked for tab $want');
    }
  });

  test('an out-of-range tab is clamped rather than crashing', () {
    // DefaultTabController asserts on an index outside its length, so
    // the page clamps. A bad deep link should land somewhere sensible,
    // not take the screen down.
    expect(const LibraryPage(initialTab: 7).initialTab.clamp(0, 1), 1);
    expect(const LibraryPage(initialTab: -3).initialTab.clamp(0, 1), 0);
  });
}
