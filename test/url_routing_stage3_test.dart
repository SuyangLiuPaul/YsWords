import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:yswords/utils/app_nav.dart';

/// URL-routing Stage 3 (`docs/url-routing-plan.md`, §6 batch 1
/// remainder): what's VM-testable about the 11 pages added on top of
/// Stage 2's `/about` and `/highlights` — `FeedbackPage`, `VideosPage`,
/// `SongsPage`, `StatsPage`, `SongDownloadsPage`, `SongPlaylistsPage`,
/// `ProfilesPage`, `FamilyTreePage`, `BibleTimelinePage`, `SermonsPage`,
/// `MisconceptionsPage`.
///
/// Each test's stub `GetPage` shows text distinct from the widget passed
/// to `pushPage`, so a pass here proves the push actually went through
/// `Get.toNamed` — reading `app_nav.dart`'s real (unmocked)
/// `_registeredRoutePaths` — and rendered the REGISTERED page, not
/// `app_nav.dart`'s `Get.to` fallback, which would render whatever
/// widget was passed to `pushPage` instead and ignore `getPages`
/// entirely. `Get.currentRoute` alone can't tell the two apart: the
/// fallback also accepts an explicit `routeName` and reports it
/// unchanged, so asserting only the route string passes even when the
/// dispatch took the wrong branch — confirmed by deliberately emptying
/// `_registeredRoutePaths` down to Stage 2's 2 entries while building
/// this test and finding a route-string-only version still green.
///
/// The mechanism itself (URL actually written to the browser address
/// bar, popstate on Back, boot-hash dispatch) is `dart:js_interop`-gated
/// in `url_sync_service_web.dart` and unreachable here — verified
/// separately against a real web build; see this stage's queue entry.
class _Registered extends StatelessWidget {
  const _Registered(this.label);
  final String label;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('REGISTERED: $label')));
}

class _PassedIn extends StatelessWidget {
  const _PassedIn(this.label);
  final String label;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('PASSED-IN: $label')));
}

GetPage _stubPage(String name, String label) => GetPage(
      name: name,
      page: () => _Registered(label),
    );

/// Every path this stage registers.
const _stage3Paths = [
  '/feedback',
  '/videos',
  '/songs',
  '/stats',
  '/songs/downloads',
  '/songs/playlists',
  '/profiles',
  '/family-tree',
  '/timeline',
  '/sermons',
  '/misconceptions',
];

Future<void> _pumpRoot(WidgetTester tester) async {
  await tester.pumpWidget(
    GetMaterialApp(
      getPages: [
        for (final path in _stage3Paths) _stubPage(path, path),
      ],
      home: const Scaffold(body: Center(child: Text('ROOT'))),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final path in _stage3Paths) {
    testWidgets(
      "pushPage(.., routeName: '$path') renders the REGISTERED getPages "
      'entry (proves Get.toNamed dispatch, not the Get.to fallback), '
      'and Back returns to the previous page',
      (tester) async {
        await _pumpRoot(tester);

        pushPage(_PassedIn(path), routeName: path);
        await tester.pumpAndSettle();

        expect(find.text('REGISTERED: $path'), findsOneWidget);
        expect(find.text('PASSED-IN: $path'), findsNothing);
        expect(Get.currentRoute, path);

        Get.back();
        await tester.pumpAndSettle();
        expect(find.text('ROOT'), findsOneWidget);
        expect(find.text('REGISTERED: $path'), findsNothing);
      },
    );
  }

  testWidgets(
    "'/songs/downloads' resolves to its own registered entry, not "
    "'/songs' — prefix-sharing risk named in this stage's queue entry",
    (tester) async {
      await _pumpRoot(tester);

      pushPage(const _PassedIn('/songs/downloads'),
          routeName: '/songs/downloads');
      await tester.pumpAndSettle();

      expect(find.text('REGISTERED: /songs/downloads'), findsOneWidget);
      expect(find.text('REGISTERED: /songs'), findsNothing);
      expect(Get.currentRoute, '/songs/downloads');
    },
  );

  testWidgets(
    "'/songs/playlists' resolves to its own registered entry, not '/songs'",
    (tester) async {
      await _pumpRoot(tester);

      pushPage(const _PassedIn('/songs/playlists'),
          routeName: '/songs/playlists');
      await tester.pumpAndSettle();

      expect(find.text('REGISTERED: /songs/playlists'), findsOneWidget);
      expect(find.text('REGISTERED: /songs'), findsNothing);
      expect(Get.currentRoute, '/songs/playlists');
    },
  );

  testWidgets(
    "'/songs' itself still resolves to its own entry once the nested "
    'downloads/playlists paths are also registered',
    (tester) async {
      await _pumpRoot(tester);

      pushPage(const _PassedIn('/songs'), routeName: '/songs');
      await tester.pumpAndSettle();

      expect(find.text('REGISTERED: /songs'), findsOneWidget);
      expect(Get.currentRoute, '/songs');
    },
  );
}
