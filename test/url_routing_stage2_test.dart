import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:yswords/utils/app_nav.dart';

/// URL-routing Stage 2 (docs/url-routing-plan.md): what's VM-testable
/// about the mechanism piece — `pushPage` dispatching a registered page
/// through GetX's named-route path (`Get.toNamed`) instead of the
/// anonymous `Get.to` every other page still uses.
///
/// `app_nav.dart`'s `_registeredRoutePaths` matches on the explicit
/// `routeName` string the CALLER passes, not on the page class at all.
/// The first version of this matched `page.runtimeType.toString()`
/// instead — broken in exactly the build this app ships, because
/// `flutter build web --release` minifies class names, so a real
/// `AboutPage` instance's `runtimeType.toString()` is not the string
/// `"AboutPage"` at runtime (confirmed against the built
/// `main.dart.js`: the literal `AboutPage` appeared nowhere except as
/// this map's own key). These stubs exercise the corrected,
/// minification-proof mechanism directly, without the real pages'
/// provider dependencies — matching `app_nav_route_name_test.dart`'s
/// existing style of testing the mechanism with stubs.
///
/// `url_sync_service_web.dart`'s half of this stage (skipping the
/// Bible-position rewrite, popping the Flutter route on browser Back,
/// the boot-hash dispatch) is `dart:js_interop`-gated and unreachable
/// here — verified separately against a real web build (see this
/// stage's queue entry for what that verification found).
class _AboutStub extends StatelessWidget {
  const _AboutStub();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('ABOUT STUB')));
}

class _HighlightsStub extends StatelessWidget {
  const _HighlightsStub();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('HIGHLIGHTS STUB')));
}

/// An ordinary page pushed with NO explicit routeName — stands in for
/// the ~72 other `pushPage` call sites this stage must leave untouched.
class _UnregisteredPage extends StatelessWidget {
  const _UnregisteredPage();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('UNREGISTERED')));
}

GetPage _stubPage(String name, Widget Function() builder) => GetPage(
      name: name,
      page: builder,
    );

Future<void> _pumpRoot(WidgetTester tester) async {
  await tester.pumpWidget(
    GetMaterialApp(
      getPages: [
        _stubPage('/about', () => const _AboutStub()),
        _stubPage('/highlights', () => const _HighlightsStub()),
      ],
      home: const Scaffold(body: Center(child: Text('ROOT'))),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    "pushPage(.., routeName: '/about') dispatches through Get.toNamed",
    (tester) async {
      await _pumpRoot(tester);

      pushPage(const _AboutStub(), routeName: '/about');
      await tester.pumpAndSettle();

      expect(find.text('ABOUT STUB'), findsOneWidget);
      // The load-bearing assertion: a named dispatch lands on the
      // registered path itself. Reverting the `_registeredRoutePaths`
      // check in app_nav.dart's pushPage turns this red — the old
      // `Get.to` path names the route '/_AboutStub', not '/about'.
      expect(Get.currentRoute, '/about');
    },
  );

  testWidgets(
    "pushPage(.., routeName: '/highlights') dispatches through Get.toNamed",
    (tester) async {
      await _pumpRoot(tester);

      pushPage(const _HighlightsStub(), routeName: '/highlights');
      await tester.pumpAndSettle();

      expect(find.text('HIGHLIGHTS STUB'), findsOneWidget);
      expect(Get.currentRoute, '/highlights');
    },
  );

  testWidgets(
    'a page pushed with no routeName is untouched — old anonymous Get.to path',
    (tester) async {
      await _pumpRoot(tester);

      pushPage(const _UnregisteredPage());
      await tester.pumpAndSettle();

      expect(find.text('UNREGISTERED'), findsOneWidget);
      // Old naming scheme preserved for every page this stage did not
      // convert — the ~72 other pushPage call sites per §2.
      expect(Get.currentRoute, '/_UnregisteredPage');
    },
  );

  testWidgets(
    'an unregistered explicit routeName still goes through the old Get.to path',
    (tester) async {
      await _pumpRoot(tester);

      pushPage(const _UnregisteredPage(), routeName: '/custom-name');
      await tester.pumpAndSettle();

      expect(find.text('UNREGISTERED'), findsOneWidget);
      expect(Get.currentRoute, '/custom-name');
    },
  );

  testWidgets(
    'Back from a registered page returns to the previous page, not a duplicate',
    (tester) async {
      await _pumpRoot(tester);

      pushPage(const _AboutStub(), routeName: '/about');
      await tester.pumpAndSettle();
      expect(find.text('ABOUT STUB'), findsOneWidget);

      Get.back();
      await tester.pumpAndSettle();

      expect(find.text('ROOT'), findsOneWidget);
      expect(find.text('ABOUT STUB'), findsNothing);
    },
  );
}
