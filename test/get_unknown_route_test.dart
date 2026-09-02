import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `GetMaterialApp` must configure `unknownRoute` for as long as it
/// configures `getPages`. This is a source-level guard because both live
/// in one private widget tree in `main.dart` that no test can build.
///
/// The bug it pins, twice over:
///
/// v1.3.111 fixed "Null check operator used on a null value" by adding
/// `onUnknownRoute` — correct at the time, when the app set only `home:`
/// and an unmatched route fell through to Flutter's
/// `_WidgetsAppState._onUnknownRoute`.
///
/// The URL-routing work then added `getPages`, which wires GetX into
/// `onGenerateRoute`. From that point an unmatched *named* route is
/// decided by GetX first, in `PageRedirect.getPageToRoute`
/// (get-4.7.2, route_middleware.dart:199):
///
/// ```dart
/// while (needRecheck()) {}
/// final r = (isUnknown ? unknownRoute : route)!;
/// ```
///
/// `needRecheck` sets `isUnknown = true` as soon as
/// `Get.routeTree.matchRoute(name)` finds nothing, and with no
/// `unknownRoute` that `!` throws — before Flutter's handler is
/// consulted. The same crash came back on v1.4.191/193/195, and the
/// v1.3.111 guard was still sitting there looking like it covered it.
///
/// So the invariant is not "have a fallback" — it is **have the
/// fallback in the layer that decides**. Adding `getPages` moved the
/// decision; nothing failed to tell us.
void main() {
  final main = File('lib/main.dart').readAsStringSync();

  test('getPages without unknownRoute is the v1.4.191 crash', () {
    final hasGetPages = RegExp(r'getPages:\s*\w').hasMatch(main);
    if (!hasGetPages) return; // GetX no longer owns route generation.
    expect(main, contains('unknownRoute:'),
        reason: 'getPages is set, so GetX generates routes and its '
            'PageRedirect throws on an unmatched name before '
            'onUnknownRoute is reached. Give GetMaterialApp an '
            'unknownRoute.');
  });

  test('both guards are present — they cover different layers', () {
    // Deleting either one because "the other one handles it" is the
    // mistake this file exists to prevent. onUnknownRoute still covers
    // routes GetX does not generate.
    expect(main, contains('onUnknownRoute:'));
    expect(main, contains('unknownRoute:'));
  });

  test('the unknown route renders the app root, not a dead end', () {
    // A fallback that throws, or that shows a bare error page a reader
    // cannot navigate out of, is not much better than the crash.
    final i = main.indexOf('unknownRoute:');
    expect(i, greaterThan(-1));
    final block = main.substring(i, i + 400);
    expect(block, contains('_RootRouter'),
        reason: 'the unknown route should land the reader on the app '
            'root, the same destination onUnknownRoute uses');
  });
}
