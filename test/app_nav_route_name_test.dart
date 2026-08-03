import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:yswords/utils/app_nav.dart';

/// Regression guard for the v1.4.3 "dead taps" bug.
///
/// `pushPage` funnels every navigation through one helper whose page
/// parameter is typed `Widget`. GetX derives an anonymous route's name
/// from the BUILDER CLOSURE's runtimeType (`routeName ??=
/// "/${page.runtimeType}"`) and then silently no-ops when
/// `preventDuplicates && routeName == currentRoute`.
///
/// So if the helper lets `routeName` stay null, every call site produces
/// the SAME name (`/Widget`) — the first push works, and every push after
/// it is dropped on the floor. That shipped as v1.4.3 and made Settings,
/// Library, the book picker and most overflow-menu items dead taps.
///
/// These tests assert real navigation, not the naming mechanism, so they
/// stay valid even if GetX changes how it derives names internally.
class _PageA extends StatelessWidget {
  const _PageA();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('PAGE A')));
}

class _PageB extends StatelessWidget {
  const _PageB();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('PAGE B')));
}

void main() {
  testWidgets(
    'consecutive pushPage calls to different pages all navigate',
    (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(body: Center(child: Text('ROOT'))),
        ),
      );
      await tester.pumpAndSettle();

      // First push — worked even with the bug present.
      pushPage(const _PageA());
      await tester.pumpAndSettle();
      expect(find.text('PAGE A'), findsOneWidget);

      // Second push to a DIFFERENT page — this is the one the bug ate,
      // because both pages resolved to the same `/Widget` route name.
      pushPage(const _PageB());
      await tester.pumpAndSettle();
      expect(
        find.text('PAGE B'),
        findsOneWidget,
        reason: 'pushPage must not collapse distinct pages onto one route '
            'name — GetX preventDuplicates would silently drop the push',
      );
    },
  );

  testWidgets(
    'pushPage still de-dupes a repeat push of the SAME page',
    (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(body: Center(child: Text('ROOT'))),
        ),
      );
      await tester.pumpAndSettle();

      pushPage(const _PageA());
      await tester.pumpAndSettle();

      // Re-pushing the page we're already on should be suppressed, so
      // popping once must land back on ROOT rather than a second _PageA.
      pushPage(const _PageA());
      await tester.pumpAndSettle();

      Get.back();
      await tester.pumpAndSettle();
      expect(find.text('ROOT'), findsOneWidget);
    },
  );
}
