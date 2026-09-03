import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/route_paths.dart';

/// The acceptance test for the queue item this whole work exists for:
///
/// > Reported 2026-08-17 by a reader of the CN site: while reading
/// > sermon #019「你们是世上的光」the address bar still read
/// > `.../#/micah/2:1?v=cuvs-yhwh`, so forwarding that link sends
/// > someone to Micah 2:1. Also: browser forward/back behaves wrongly.
///
/// Every earlier stage's tests check the *routing wiring* — that
/// `pushPage` dispatches through `Get.toNamed` and that GetX resolves
/// the template. None of them check the thing the reader actually
/// complained about, which is the string in the address bar. This file
/// does, and it does it without a browser.
///
/// **How this reaches the real address bar, and why it is not a
/// re-implementation.** On Flutter web the URL is written by the
/// engine, in response to the framework sending `routeInformationUpdated`
/// on the `flutter/navigation` platform channel. Nothing in app code
/// writes it. A widget test can mock that exact channel and read the
/// `uri` the framework reports — the same value the engine would put in
/// the address bar — so "what would the URL say" is answerable in the VM
/// harness. The reverse direction is symmetrical: the engine tells the
/// framework about a browser Back with `popRoute` and about a browser
/// Forward (or any history entry the user lands on) with
/// `pushRouteInformation`. Feeding those in is the closest thing to
/// pressing the browser's own buttons that exists off-web, and it is
/// what the back/forward group below does.
///
/// What this file cannot reach is `url_sync_service_web.dart` itself:
/// it is `dart:js_interop`-gated and does not compile into the VM
/// harness. Its half of the fix — "do not rewrite the hash back to the
/// Bible position while a registered route is on top" — is covered two
/// ways instead: the predicate that guard consults is exercised
/// directly, and the guard's presence in that file is asserted against
/// its source, so the predicate assertion cannot pass while the shipped
/// code stops consulting it.
void main() {
  // Get is a process-wide singleton and a pumped GetMaterialApp does not
  // clear its stack — see url_routing_stage4_batch2_test.dart's note.
  tearDown(Get.reset);

  /// The address bar, as the engine would see it: every `uri` the
  /// framework reports on the navigation channel, in order.
  List<String> watchAddressBar(WidgetTester tester) {
    final bar = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        if (call.method == 'routeInformationUpdated') {
          bar.add((call.arguments as Map)['uri'] as String);
        }
        return null;
      },
    );
    return bar;
  }

  /// A message from the engine to the framework — what the browser's own
  /// Back and Forward buttons produce on Flutter web.
  Future<void> fromEngine(WidgetTester tester, MethodCall call) =>
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(call),
        (_) {},
      );

  Future<void> browserBack(WidgetTester tester) =>
      fromEngine(tester, const MethodCall('popRoute'));

  Future<void> browserForwardTo(WidgetTester tester, String path) => fromEngine(
      tester,
      MethodCall('pushRouteInformation',
          <String, dynamic>{'location': path, 'state': null}));

  /// The app shell, with one stub GetPage per template the app really
  /// registers. Stubs rather than the real pages (which need providers,
  /// bundled assets and network stubs of their own) — what is under test
  /// here is which route the app lands on and what the address bar says,
  /// not what each page renders. Built FROM [kRegisteredRoutePaths] so a
  /// route added later is covered without editing this file.
  Widget app() => GetMaterialApp(
        getPages: [
          for (final template in kRegisteredRoutePaths)
            GetPage(
              name: template,
              page: () => Scaffold(body: Center(child: Text('PAGE $template'))),
            ),
        ],
        home: const Scaffold(body: Center(child: Text('DASHBOARD'))),
      );

  group('the reported bug: the address bar names the sermon', () {
    testWidgets(
      'opening sermon 019 from the reader puts /sermons/019 in the '
      'address bar — not the Bible reference that was there before',
      (tester) async {
        final bar = watchAddressBar(tester);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();

        // The reader was at Micah 2:1 — that is the URL the bug report
        // quoted, and the one the old code left in place.
        expect(bar.last, '/');

        // Exactly what sermons_page.dart / dashboard_page.dart /
        // bible_reading_pane.dart do when a sermon row is tapped.
        pushPage(const Scaffold(body: Center(child: Text('PASSED-IN'))),
            routeName: '/sermons/019');
        await tester.pumpAndSettle();

        // The URL the reader would copy out of the address bar.
        expect(bar.last, '/sermons/019',
            reason: 'the address bar must name the sermon being read');
        expect(bar.last, isNot(contains('micah')));

        // And it got there through the registered route, not through
        // app_nav.dart's Get.to fallback. This matters for the address
        // bar specifically: the fallback names the route
        // `/${page.runtimeType}`, and `flutter build web --release`
        // minifies class names, so the fallback's URL is unshareable
        // gibberish even when a URL appears at all.
        expect(find.text('PAGE /sermons/:id'), findsOneWidget);
        expect(find.text('PASSED-IN'), findsNothing);
      },
    );

    test(
      'the Bible-position writer is switched off while a sermon is on '
      'top — the mechanism that stopped Micah 2:1 coming back',
      () {
        // `_writeStateToUrl` and `onRouteChanged` in
        // url_sync_service_web.dart both early-return when this is true
        // of the route on top of the stack. That is the whole fix for
        // "the address bar still read /micah/2:1": before it, the 350 ms
        // post-push correction rewrote the hash to whatever
        // MainProvider's book/chapter/verse said, unconditionally.
        expect(matchesRegisteredRoute('/sermons/019'), isTrue);

        // Red-before, in the same assertion style: against the template
        // set as it stood through Stage 3 — literal paths only, no
        // `/sermons/:id` — the very same concrete path is NOT
        // recognised, the guard does not fire, and the Bible writer
        // owns the address bar. That is the bug, reproduced.
        const asOfStage3 = {
          '/about', '/highlights', '/feedback', '/videos', '/songs',
          '/stats', '/songs/downloads', '/songs/playlists', '/profiles',
          '/family-tree', '/timeline', '/sermons', '/misconceptions',
        };
        expect(matchesRegisteredRoute('/sermons/019', asOfStage3), isFalse);

        // The Bible reader itself must stay in the old world: no
        // registered route matches a Bible path, so the frozen grammar
        // keeps writing the URL exactly as it always did (§1).
        expect(matchesRegisteredRoute('/micah/2:1'), isFalse);
      },
    );

    test(
      'the guard the assertion above stands for is really in the shipped '
      'web writer — not just in this test',
      () {
        // url_sync_service_web.dart cannot be imported here (js_interop),
        // so its half is checked as source, the same method
        // url_routing_stage3_sync_test.dart uses for main.dart's private
        // route table. Without this, the predicate test above would keep
        // passing after someone deleted the guard it describes.
        final src =
            File('lib/services/url_sync_service_web.dart').readAsStringSync();
        final writer = src.substring(src.indexOf('void _writeStateToUrl()'));
        final guardEnd = writer.indexOf('final mp = _mp;');
        expect(guardEnd, greaterThan(-1),
            reason: '_writeStateToUrl was restructured; re-check that the '
                'registered-route guard still runs BEFORE it reads '
                'MainProvider and writes a Bible hash');
        final guard = writer.substring(0, guardEnd);
        expect(guard, contains('matchesRegisteredRoute(_currentRouteName!'),
            reason: '_writeStateToUrl no longer suppresses the Bible-position '
                'write while a registered route is on top — this is the '
                'exact regression that put /micah/2:1 in the address bar '
                'while a sermon was open');
        expect(guard, contains('return;'));
      },
    );
  });

  group('browser Back and Forward — the other half of the report', () {
    testWidgets(
      'Back from a sermon returns to where the reader came from, and the '
      'address bar goes back with it',
      (tester) async {
        final bar = watchAddressBar(tester);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();

        pushPage(const Scaffold(), routeName: '/sermons/019');
        await tester.pumpAndSettle();
        expect(find.text('PAGE /sermons/:id'), findsOneWidget);
        expect(bar.last, '/sermons/019');

        // The browser's real Back button, as the engine delivers it —
        // not Get.back(). The original bug was precisely that this
        // arrived somewhere that did not pop the Flutter stack.
        await browserBack(tester);
        await tester.pumpAndSettle();

        expect(find.text('DASHBOARD'), findsOneWidget,
            reason: 'Back must return to the page the reader came from');
        expect(find.text('PAGE /sermons/:id'), findsNothing);
        expect(bar.last, '/');
      },
    );

    testWidgets(
      'Forward after that Back returns to the sermon, address bar included',
      (tester) async {
        final bar = watchAddressBar(tester);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();

        pushPage(const Scaffold(), routeName: '/sermons/019');
        await tester.pumpAndSettle();
        await browserBack(tester);
        await tester.pumpAndSettle();
        expect(find.text('DASHBOARD'), findsOneWidget);

        // Browser Forward: the engine hands the framework the history
        // entry it moved to.
        await browserForwardTo(tester, '/sermons/019');
        await tester.pumpAndSettle();

        expect(find.text('PAGE /sermons/:id'), findsOneWidget,
            reason: 'Forward must return to the page Back left');
        expect(bar.last, '/sermons/019');
      },
    );

    testWidgets(
      'a two-deep push unwinds one page per Back, in order',
      (tester) async {
        final bar = watchAddressBar(tester);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();

        pushPage(const Scaffold(), routeName: '/sermons');
        await tester.pumpAndSettle();
        pushPage(const Scaffold(), routeName: '/sermons/019');
        await tester.pumpAndSettle();
        expect(bar.last, '/sermons/019');

        await browserBack(tester);
        await tester.pumpAndSettle();
        expect(find.text('PAGE /sermons'), findsOneWidget,
            reason: 'the first Back returns to the sermon LIST, not to the '
                'dashboard and not to a Bible passage');
        expect(bar.last, '/sermons');

        await browserBack(tester);
        await tester.pumpAndSettle();
        expect(find.text('DASHBOARD'), findsOneWidget);
        expect(bar.last, '/');
      },
    );
  });

  group('a shared link restores state on a cold load', () {
    // The app's real boot path, in the order main.dart/
    // url_sync_service_web.dart run it: captureBootHash ->
    // hashToRoutePath -> matchesRegisteredRoute -> _bootRouteCallback ->
    // _RootRouterState's `Get.toNamed(routeName)`. Steps 2 and 3 are now
    // pure and live in route_paths.dart, so the whole chain is
    // reproducible here except the js_interop hash read itself.
    test('the boot hash of a shared sermon link resolves to its route', () {
      final path = hashToRoutePath('#/sermons/019');
      expect(path, '/sermons/019');
      expect(matchesRegisteredRoute(path!), isTrue,
          reason: 'a cold load of this link must take the registered-route '
              'boot path, not the Bible-grammar one, which would silently '
              'no-op on it');
    });

    test('a Bible link still takes the Bible boot path, untouched', () {
      // The exact URL from the bug report. §1 freezes this grammar; a
      // registered route must never swallow it.
      final path = hashToRoutePath('#/micah/2:1?v=cuvs-yhwh');
      expect(path, '/micah/2:1?v=cuvs-yhwh');
      expect(matchesRegisteredRoute(path!), isFalse);

      // And the root hash still means "no route, show the dashboard".
      expect(hashToRoutePath('#/'), isNull);
      expect(hashToRoutePath('#'), isNull);
      expect(hashToRoutePath(''), isNull);
    });

    testWidgets(
      'cold-loading a shared sermon link lands on the sermon, and Back '
      'from there does not strand the reader',
      (tester) async {
        final bar = watchAddressBar(tester);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();

        // What _RootRouterState.initState's boot-route callback does
        // with the path the two pure steps above produced.
        final booted = hashToRoutePath('#/sermons/019')!;
        Get.toNamed(booted);
        await tester.pumpAndSettle();

        expect(find.text('PAGE /sermons/:id'), findsOneWidget);
        expect(bar.last, '/sermons/019');

        await browserBack(tester);
        await tester.pumpAndSettle();
        expect(find.text('DASHBOARD'), findsOneWidget,
            reason: 'Back from a cold-loaded deep link lands on the app '
                'root — one sensible place, per the acceptance bar Stage 3 '
                'set for the same behaviour on /songs/downloads');
      },
    );
  });
}
