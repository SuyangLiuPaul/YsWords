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
}
