import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/widgets/scroll_to_top_on_status_bar_tap.dart';

/// First test for [ScrollToTopOnStatusBarTap] (2026-08-11 widget, never
/// covered — `grep ScrollToTopOnStatusBarTap test/` returned nothing before
/// this file). Exercises the real platform-channel path via
/// [WidgetController.simulateStatusBarTap] rather than reaching into the
/// private `State`, so the test fails if the binding wiring ever breaks,
/// not just the animation math.
void main() {
  Widget wrap(ScrollController controller, {Key? listKey}) {
    return MaterialApp(
      home: ScrollToTopOnStatusBarTap(
        controller: controller,
        child: ListView.builder(
          key: listKey,
          controller: controller,
          itemCount: 100,
          itemBuilder: (context, i) => SizedBox(
            height: 50,
            child: Text('Row $i'),
          ),
        ),
      ),
    );
  }

  testWidgets('a status bar tap scrolls the wrapped list back to zero',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(wrap(controller));

    controller.jumpTo(400);
    expect(controller.offset, 400);

    tester.simulateStatusBarTap();
    // The wrapper animates over 1000ms (matches Scaffold's own values).
    await tester.pumpAndSettle();

    expect(controller.offset, 0);
  });

  testWidgets('a tap on a route that is not current does not scroll it',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(wrap(controller));

    controller.jumpTo(400);

    // Push a second, non-opaque route on top (a dialog/sheet shape, not
    // a full page) — an *opaque* route would also disable the covered
    // route's TickerMode, which would mask this guard: `animateTo`'s
    // Ticker-driven animation is a no-op there regardless of whether
    // `isCurrent` is checked, so that shape doesn't actually exercise
    // the guard. A transparent route above it leaves the ticker
    // enabled, so `isCurrent` is the only thing standing between this
    // tap and scrolling a screen the user cannot see.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, __, ___) =>
          const Scaffold(backgroundColor: Colors.transparent),
    ));
    await tester.pumpAndSettle();

    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();

    expect(controller.offset, 400,
        reason: 'a backgrounded page must not lose the reader\'s place');
  });

  testWidgets(
      'a controller attached to two positions does not throw on tap',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    // Two live scroll views sharing one controller — the same shape the
    // widget's own doc comment calls out ("a page that briefly has two
    // lists alive during a transition"). `positions.length` is 2, so
    // `offset`/`animateTo` would throw if the wrapper did not guard it.
    await tester.pumpWidget(
      MaterialApp(
        home: ScrollToTopOnStatusBarTap(
          controller: controller,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: 50,
                  itemBuilder: (context, i) => SizedBox(
                    height: 50,
                    child: Text('A $i'),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: 50,
                  itemBuilder: (context, i) => SizedBox(
                    height: 50,
                    child: Text('B $i'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(controller.positions.length, 2);

    // The binding catches exceptions from observers and reports them via
    // `FlutterError.reportError` rather than rethrowing synchronously, so
    // `takeException()` — not a `throwsA` on the call itself — is what
    // would actually surface a regression here.
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // ── batch 2: the tab-aware guard ─────────────────────────────────
  //
  // `ModalRoute.isCurrent` cannot see tabs. Inside a `TabBarView` every
  // mounted tab shares ONE route, and a tab that mixes in
  // `AutomaticKeepAliveClientMixin` — which all of `stats_page`'s do —
  // stays mounted for the life of the page once visited. So without a
  // tab check a status-bar tap taken on the visible tab also scrolls the
  // hidden ones, which is the "it lost my place" failure the route check
  // exists to prevent, one level down.
  //
  // Note this shape really does exercise the guard, unlike the opaque-
  // route shape called out above: a `TabBarView` child that is out of
  // view is still inside the same viewport with its ticker enabled, so
  // `animateTo` would genuinely run on it if nothing stopped it.
  group('the tab-aware guard', () {
    Widget tabs(ScrollController a, ScrollController b) {
      return MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              bottom: const TabBar(tabs: [Tab(text: 'A'), Tab(text: 'B')]),
            ),
            body: TabBarView(
              children: [
                _KeepAliveTab(controller: a, tabIndex: 0),
                _KeepAliveTab(controller: b, tabIndex: 1),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('scrolls the visible tab and leaves the hidden one alone',
        (tester) async {
      final a = ScrollController();
      final b = ScrollController();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await tester.pumpWidget(tabs(a, b));

      // Visit tab B so it mounts and keeps itself alive, then come back.
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      b.jumpTo(400);
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      a.jumpTo(400);

      expect(b.hasClients, isTrue,
          reason: 'the hidden tab must still be mounted, or this test '
              'proves nothing');

      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();

      expect(a.offset, 0);
      expect(b.offset, 400,
          reason: 'the tab the reader is not looking at must keep its place');
    });

    testWidgets('follows the reader when the selected tab changes',
        (tester) async {
      final a = ScrollController();
      final b = ScrollController();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await tester.pumpWidget(tabs(a, b));

      a.jumpTo(400);
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      b.jumpTo(400);

      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();

      expect(b.offset, 0);
      expect(a.offset, 400);
    });

    testWidgets('refuses when a tabIndex is given but no controller is above',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ScrollToTopOnStatusBarTap(
            controller: controller,
            tabIndex: 0,
            child: ListView.builder(
              controller: controller,
              itemCount: 100,
              itemBuilder: (context, i) =>
                  SizedBox(height: 50, child: Text('Row $i')),
            ),
          ),
        ),
      );

      controller.jumpTo(400);
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(controller.offset, 400,
          reason: 'a caller passing a tabIndex is declaring it is inside '
              'tabs; with no controller to ask, the safe answer is to '
              'leave the reader alone rather than guess');
    });
  });

  // Page-level wiring. The widget tests above prove the mechanism; these
  // prove the two batch-2 pages actually use it, which is the part that
  // silently regresses when someone refactors a build method.
  group('batch 2 page wiring', () {
    test('search_page wraps its shared result-list controller', () {
      final src = File('lib/pages/search_page.dart').readAsStringSync();
      expect(
        src,
        contains(
            "import 'package:yswords/widgets/scroll_to_top_on_status_bar_tap.dart';"),
      );
      // One wrapper around the whole body — `_scrollController` is shared
      // by four mutually exclusive result lists, so wrapping each list
      // would register four observers for one controller.
      expect(RegExp(r'ScrollToTopOnStatusBarTap\(').allMatches(src).length, 1);
      expect(
        RegExp(r'ScrollToTopOnStatusBarTap\(\s*\n\s*controller: _scrollController,')
            .hasMatch(src),
        isTrue,
        reason: 'the wrapper must drive the page\'s own controller',
      );
    });

    test('stats_page wires the Overview tab with its tab index', () {
      final src = File('lib/pages/stats_page.dart').readAsStringSync();
      expect(
        src,
        contains(
            "import 'package:yswords/widgets/scroll_to_top_on_status_bar_tap.dart';"),
      );
      // `_OriginalsOverviewTab` is child 0 of the page's TabBarView.
      // If the index ever stops matching the position in `children:`,
      // the gesture starts scrolling a tab the reader is not on.
      expect(
        RegExp(r'ScrollToTopOnStatusBarTap\(\s*\n\s*controller: _scrollCtrl,')
            .hasMatch(src),
        isTrue,
      );
      expect(RegExp(r'tabIndex: 0,').hasMatch(src), isTrue);
      final body = src.indexOf('body: TabBarView(');
      final overview = src.indexOf('_OriginalsOverviewTab(', body);
      final lookup = src.indexOf('_StrongsLookupTab(', body);
      final distribution = src.indexOf('_WordDistributionTab(', body);
      expect(overview, greaterThan(0));
      expect(overview, lessThan(lookup));
      expect(lookup, lessThan(distribution),
          reason: 'tabIndex: 0 is only correct while Overview is first');
    });
  });
}

/// A tab that keeps itself alive, exactly as `stats_page`'s three tabs
/// do — that is what leaves a hidden tab's observer registered and makes
/// the guard necessary in the first place.
class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.controller, required this.tabIndex});

  final ScrollController controller;
  final int tabIndex;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScrollToTopOnStatusBarTap(
      controller: widget.controller,
      tabIndex: widget.tabIndex,
      child: ListView.builder(
        controller: widget.controller,
        itemCount: 100,
        itemBuilder: (context, i) => SizedBox(
          height: 50,
          child: Text('Tab ${widget.tabIndex} row $i'),
        ),
      ),
    );
  }
}
