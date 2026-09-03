import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:yswords/utils/app_nav.dart';

/// Regression test for "Back leaves the app" (2026-09-03), and for the
/// claim in `docs/url-routing-plan.md` §5 point 5 that turned out false.
///
/// **The false claim.** §5 point 5 said "each `pushPage` navigation still
/// creates a browser history entry". It was argued from reading
/// `_writeStateToUrl`, and the browser disagreed: driving a real release
/// web build in headless Chrome with `History.prototype.pushState` /
/// `replaceState` wrapped, opening a sermon printed
///
///     + 8010ms  replaceState /#/sermons/004
///
/// — a REPLACE. Three history entries before opening the sermon, three
/// after.
///
/// **Why.** Flutter's root `Navigator` is built with
/// `reportsRouteUpdateToEngine: true` (`WidgetsApp`), and its `initState`
/// therefore calls `SystemNavigator.selectSingleEntryHistory()`. In that
/// mode the web engine keeps exactly one entry of its own on top of the
/// page's origin entry, and every `routeInformationUpdated` REPLACES it
/// (`SingleEntryBrowserHistory.setRouteName` → `_setupFlutterEntry(replace:
/// true)`). No in-app navigation can add a browser entry while the app
/// uses `home:` rather than the Router API. The first test below asserts
/// that mode selection on the channel, so the doc's claim cannot be
/// re-asserted without this failing.
///
/// **The defect that followed from misreading it.** Because the engine
/// owns the single entry, it also owns the Back gesture: its popstate
/// handler re-pushes its entry and sends the framework a `popRoute`,
/// which `WidgetsApp.didPopRoute` turns into `navigator.maybePop()` — one
/// pop. `url_sync_service_web.dart` had its own `popstate` listener that
/// popped a SECOND time via `setPopRouteCallback`, on the belief that the
/// Navigator "never hears about" popstate. Measured, one Back produced:
///
///     [PROBE] didPop popped=/sermons/004 -> now=/sermons     <- the engine
///     [PROBE] popstate current=/sermons leavingRegistered=true
///     [PROBE] popRouteCallback canPop=true                   <- ours
///     [PROBE] didPop popped=/sermons -> now=/
///
/// so Back skipped `/#/sermons` and landed on the Dashboard.
///
/// **What is NOT fixed, and cannot be here.** Forward stays unreachable.
/// The engine re-pushes its entry on every popstate, which truncates the
/// forward list by construction; real per-page browser entries (and
/// therefore a working Forward) need `GetMaterialApp.router` and the
/// multi-entry history that comes with it. That migration is not this
/// change. The end-to-end proof for Back lives in
/// `tools/web_verify_headless.mjs history`, because the popstate listener
/// under test is web-only and cannot be imported by `flutter test` at
/// all (`dart:js_interop`).
void main() {
  tearDown(Get.reset);

  Widget app() => GetMaterialApp(
        getPages: [
          GetPage(
              name: '/sermons',
              page: () => const Scaffold(body: Center(child: Text('LIST')))),
          GetPage(
              name: '/sermons/:id',
              page: () => const Scaffold(body: Center(child: Text('DETAIL')))),
        ],
        home: const Scaffold(body: Center(child: Text('ROOT'))),
      );

  testWidgets('the root Navigator selects SINGLE-entry browser history, so '
      'an in-app push REPLACES the browser entry rather than adding one',
      (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.navigation, null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(
      calls.map((c) => c.method),
      contains('selectSingleEntryHistory'),
      reason: 'docs/url-routing-plan.md §5 point 5 claimed every pushPage '
          'adds a browser history entry. It cannot while the app is in '
          'single-entry mode — the engine keeps ONE entry and replaces it. '
          'If this ever stops being selected (a move to '
          'GetMaterialApp.router), the doc has to be rewritten and so does '
          'the Back handling below.',
    );
    expect(calls.map((c) => c.method), isNot(contains('selectMultiEntryHistory')));

    calls.clear();
    pushPage(const Scaffold(body: Text('IGNORED')), routeName: '/sermons');
    await tester.pumpAndSettle();

    expect(find.text('LIST'), findsOneWidget);
    expect(
      calls.where((c) => c.method == 'routeInformationUpdated'),
      isNotEmpty,
      reason: 'the push has to reach the engine at all — it is what writes '
          'the address bar. In single-entry mode that write is a '
          'replaceState, which is exactly why Back cannot return here.',
    );
  });

  testWidgets('one browser Back pops exactly ONE route', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    pushPage(const Scaffold(body: Text('IGNORED')), routeName: '/sermons');
    await tester.pumpAndSettle();
    pushPage(const Scaffold(body: Text('IGNORED')), routeName: '/sermons/004');
    await tester.pumpAndSettle();
    expect(find.text('DETAIL'), findsOneWidget);

    // This is the Back BUTTON, as the web engine delivers it: a
    // `popRoute` platform message, handled by `WidgetsApp.didPopRoute`.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('LIST'), findsOneWidget,
        reason: 'Back must return to the page underneath');
    expect(find.text('ROOT'), findsNothing,
        reason: 'Back unwound TWO pages — this is the reported defect: a '
            'reader who presses Back once loses their place and lands on '
            'the Dashboard');
  });

  test('nothing registers a SECOND pop on browser Back', () {
    // A source-shape check, in the same spirit as
    // `url_routing_plan_table_test.dart`'s parse of the plan document.
    // The behaviour it guards is web-only, so no widget test can reach
    // it; what CAN be checked off-web is that the second pop has not
    // been reintroduced.
    final web =
        File('lib/services/url_sync_service_web.dart').readAsStringSync();
    expect(web, isNot(contains('_popRouteCallback?.call()')),
        reason: 'the popstate listener is popping the Navigator again — the '
            'engine has already done that by the time it runs');
    expect(web, isNot(contains('void setPopRouteCallback')));

    final facade = File('lib/services/url_sync_service.dart').readAsStringSync();
    expect(facade, isNot(contains('static void setPopRouteCallback')));

    final main = File('lib/main.dart').readAsStringSync();
    expect(main, isNot(contains('UrlSyncService.setPopRouteCallback')));
  });
}
