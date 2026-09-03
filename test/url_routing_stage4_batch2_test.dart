import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/evidence_detail_page.dart';
import 'package:yswords/pages/map_viewer_page.dart';
import 'package:yswords/pages/videos_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/bible_evidence_service.dart';
import 'package:yswords/services/map_service.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/route_paths.dart';

/// URL-routing Stage 4, batch 2 (`docs/url-routing-plan.md`, §6): the
/// two parameterized routes `/strongs/:number` and
/// `/songs/playlists/:id`. Unlike `/sermons/:id` (Stage 4's first
/// pass), neither needed a separate id→object *resolver widget* at the
/// `GetPage` level — `StrongsEntryPage` and `SongPlaylistDetailPage`
/// already take the raw id and already resolve and render their own
/// loading/not-found state — so this stage is purely the
/// `getPages`/`kRegisteredRoutePaths`/call-site wiring. (Resolution
/// itself isn't uniformly synchronous: `SongPlaylistService` loads
/// from SharedPreferences asynchronously, so that page distinguishes
/// "still loading" from "loaded and gone" internally rather than via a
/// wrapper — see `song_playlist_detail_page.dart`.) This file exercises
/// the routing wiring the same way `url_routing_stage4_test.dart`
/// exercised `/sermons/:id`: the matcher recognises a concrete path
/// against each template, and `pushPage` dispatches through
/// `Get.toNamed` (hitting the registered `GetPage`) rather than the
/// anonymous `Get.to` fallback that would ignore `getPages` entirely.
void main() {
  // Each `testWidgets` below that pumps its own `GetMaterialApp` leaves
  // routes on GetX's global navigator stack — `Get` is a process-wide
  // singleton, and pumping a fresh `GetMaterialApp` does not clear it.
  // The shipped app only ever mounts one, so this never bites in
  // production, but three such tests in one file bite each other: the
  // third test below first saw the SECOND test's leftover
  // '/songs/playlists/pl_123' route and page (stale text
  // 'REGISTERED: pl_123' instead of its own 'DETAIL: pl_123') before
  // this tearDown was added.
  tearDown(Get.reset);

  group('matchesRegisteredRoute recognises the two new templates', () {
    test('/strongs/:number matches a concrete Strong\'s number', () {
      expect(matchesRegisteredRoute('/strongs/G25', {'/strongs/:number'}),
          isTrue);
      expect(matchesRegisteredRoute('/strongs/H430', {'/strongs/:number'}),
          isTrue);
      // No partial/prefix match, same rule Stage 4 established for
      // /sermons/:id.
      expect(matchesRegisteredRoute('/strongs', {'/strongs/:number'}),
          isFalse);
      expect(
          matchesRegisteredRoute(
              '/strongs/G25/extra', {'/strongs/:number'}),
          isFalse);
    });

    test('/songs/playlists/:id matches a concrete playlist id without '
        'colliding with the literal /songs/playlists ancestor', () {
      expect(
          matchesRegisteredRoute(
              '/songs/playlists/pl_123', {'/songs/playlists/:id'}),
          isTrue);
      // The literal ancestor route has 2 segments, the template has 3 —
      // segment-count matching (route_paths.dart's own rule) keeps them
      // from being confused for each other.
      expect(
          matchesRegisteredRoute(
              '/songs/playlists', {'/songs/playlists/:id'}),
          isFalse);
    });

    test('kRegisteredRoutePaths (the real, default template set) '
        'includes both new paths', () {
      expect(kRegisteredRoutePaths, contains('/strongs/:number'));
      expect(kRegisteredRoutePaths, contains('/songs/playlists/:id'));
      expect(matchesRegisteredRoute('/strongs/G25'), isTrue);
      expect(matchesRegisteredRoute('/songs/playlists/pl_123'), isTrue);
    });
  });

  group('pushPage dispatch for both parameterized routeNames', () {
    // Same stub shape as url_routing_stage4_test.dart's /sermons/:id
    // dispatch test: a page registered under the TEMPLATE proves the
    // push went through Get.toNamed (and GetX's own route-tree match),
    // not app_nav.dart's Get.to fallback, which would render whatever
    // widget was passed to pushPage and never consult getPages at all.
    testWidgets(
      "pushPage(.., routeName: '/strongs/G25') dispatches through "
      'Get.toNamed and GetX resolves it against /strongs/:number',
      (tester) async {
        await tester.pumpWidget(
          GetMaterialApp(
            getPages: [
              GetPage(
                name: '/strongs/:number',
                page: () => Scaffold(
                  body: Center(
                    child: Text('REGISTERED: ${Get.parameters['number']}'),
                  ),
                ),
              ),
            ],
            home: const Scaffold(body: Center(child: Text('ROOT'))),
          ),
        );
        await tester.pumpAndSettle();

        pushPage(const Scaffold(body: Center(child: Text('PASSED-IN'))),
            routeName: '/strongs/G25');
        await tester.pumpAndSettle();

        expect(find.text('REGISTERED: G25'), findsOneWidget);
        expect(find.text('PASSED-IN'), findsNothing);
        expect(Get.currentRoute, '/strongs/G25');

        Get.back();
        await tester.pumpAndSettle();
        expect(find.text('ROOT'), findsOneWidget);
      },
    );

    testWidgets(
      "pushPage(.., routeName: '/songs/playlists/pl_123') dispatches "
      'through Get.toNamed and GetX resolves it against '
      '/songs/playlists/:id',
      (tester) async {
        await tester.pumpWidget(
          GetMaterialApp(
            getPages: [
              GetPage(
                name: '/songs/playlists/:id',
                page: () => Scaffold(
                  body: Center(
                    child: Text('REGISTERED: ${Get.parameters['id']}'),
                  ),
                ),
              ),
            ],
            home: const Scaffold(body: Center(child: Text('ROOT'))),
          ),
        );
        await tester.pumpAndSettle();

        pushPage(const Scaffold(body: Center(child: Text('PASSED-IN'))),
            routeName: '/songs/playlists/pl_123');
        await tester.pumpAndSettle();

        expect(find.text('REGISTERED: pl_123'), findsOneWidget);
        expect(find.text('PASSED-IN'), findsNothing);
        expect(Get.currentRoute, '/songs/playlists/pl_123');

        Get.back();
        await tester.pumpAndSettle();
        expect(find.text('ROOT'), findsOneWidget);
      },
    );

    testWidgets(
      'the literal /songs/playlists route and the /songs/playlists/:id '
      'template, registered together, each resolve to the right page — '
      'matchesRegisteredRoute keeps them apart by segment count '
      '(above), but GetX\'s own ParseRouteTree is a separate resolver '
      'and is the one that actually runs a real push',
      (tester) async {
        await tester.pumpWidget(
          GetMaterialApp(
            getPages: [
              GetPage(
                name: '/songs/playlists',
                page: () =>
                    const Scaffold(body: Center(child: Text('LIST PAGE'))),
              ),
              GetPage(
                name: '/songs/playlists/:id',
                page: () => Scaffold(
                  body: Center(
                    child: Text('DETAIL: ${Get.parameters['id']}'),
                  ),
                ),
              ),
            ],
            home: const Scaffold(body: Center(child: Text('ROOT'))),
          ),
        );
        await tester.pumpAndSettle();

        pushPage(const Scaffold(body: Center(child: Text('PASSED-IN'))),
            routeName: '/songs/playlists');
        await tester.pumpAndSettle();
        expect(find.text('LIST PAGE'), findsOneWidget);
        expect(Get.currentRoute, '/songs/playlists');
        Get.back();
        await tester.pumpAndSettle();

        pushPage(const Scaffold(body: Center(child: Text('PASSED-IN'))),
            routeName: '/songs/playlists/pl_123');
        await tester.pumpAndSettle();
        expect(find.text('DETAIL: pl_123'), findsOneWidget);
        expect(Get.currentRoute, '/songs/playlists/pl_123');
        Get.back();
        await tester.pumpAndSettle();
        expect(find.text('ROOT'), findsOneWidget);
      },
    );
  });

  // Batch 2 continued (docs/url-routing-plan.md §6): /videos/:id,
  // /evidence/:id and /maps/:id. Unlike the two routes above, all three
  // pages take a fully-built model object rather than a raw id, so each
  // gets an id -> object resolver wrapper (VideoSeriesByIdPage,
  // EvidenceByIdPage, MapByIdPage) — same shape as /sermons/:id's
  // SermonByIdPage in url_routing_stage4_test.dart.
  group('matchesRegisteredRoute recognises the three batch-2-continued '
      'templates', () {
    test('/videos/:id, /evidence/:id and /maps/:id each match a concrete '
        'id and reject a bare/extra-segment path', () {
      for (final template in [
        '/videos/:id',
        '/evidence/:id',
        '/maps/:id',
      ]) {
        final base = template.substring(0, template.lastIndexOf('/'));
        expect(matchesRegisteredRoute('$base/abc123', {template}), isTrue);
        expect(matchesRegisteredRoute(base, {template}), isFalse);
        expect(
            matchesRegisteredRoute('$base/abc123/extra', {template}),
            isFalse);
      }
    });

    test('kRegisteredRoutePaths (the real, default template set) includes '
        'all three', () {
      expect(kRegisteredRoutePaths, contains('/videos/:id'));
      expect(kRegisteredRoutePaths, contains('/evidence/:id'));
      expect(kRegisteredRoutePaths, contains('/maps/:id'));
      expect(matchesRegisteredRoute('/videos/cross'), isTrue);
      expect(matchesRegisteredRoute('/evidence/dead_sea_scrolls'), isTrue);
      expect(matchesRegisteredRoute('/maps/ancient_near_east'), isTrue);
    });
  });

  group('pushPage dispatch for the three batch-2-continued routeNames', () {
    for (final case_ in [
      ('/videos/cross', 'cross'),
      ('/evidence/dead_sea_scrolls', 'dead_sea_scrolls'),
      ('/maps/ancient_near_east', 'ancient_near_east'),
    ]) {
      final (routeName, id) = case_;
      final template =
          '${routeName.substring(0, routeName.lastIndexOf('/'))}/:id';
      testWidgets(
        "pushPage(.., routeName: '$routeName') dispatches through "
        'Get.toNamed and GetX resolves it against $template',
        (tester) async {
          await tester.pumpWidget(
            GetMaterialApp(
              getPages: [
                GetPage(
                  name: template,
                  page: () => Scaffold(
                    body: Center(
                      child: Text('REGISTERED: ${Get.parameters['id']}'),
                    ),
                  ),
                ),
              ],
              home: const Scaffold(body: Center(child: Text('ROOT'))),
            ),
          );
          await tester.pumpAndSettle();

          pushPage(const Scaffold(body: Center(child: Text('PASSED-IN'))),
              routeName: routeName);
          await tester.pumpAndSettle();

          expect(find.text('REGISTERED: $id'), findsOneWidget);
          expect(find.text('PASSED-IN'), findsNothing);
          expect(Get.currentRoute, routeName);

          Get.back();
          await tester.pumpAndSettle();
          expect(find.text('ROOT'), findsOneWidget);
        },
      );
    }
  });

  group('VideoSeriesByIdPage (the /videos/:id cold-load resolver)', () {
    Widget wrap(Widget child) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AppSettings>(create: (_) => AppSettings()),
            ChangeNotifierProvider<MainProvider>(create: (_) => MainProvider()),
          ],
          child: MaterialApp(home: child),
        );

    testWidgets('a real id resolves to the matching VideoSeriesPage',
        (tester) async {
      // 'cross' (在十字架下) is a real, permanent series id. Warm
      // loadVideoSeries() via runAsync first — same trap
      // url_routing_stage4_test.dart documents for SermonByIdPage:
      // pumpAndSettle's fake clock never advances real async IO.
      await tester.runAsync(loadVideoSeries);
      await tester.pumpWidget(wrap(const VideoSeriesByIdPage(id: 'cross')));
      await tester.pumpAndSettle();

      final page =
          tester.widget<VideoSeriesPage>(find.byType(VideoSeriesPage));
      expect(page.series.id, 'cross');
    });

    testWidgets(
      'an id with no match shows the not-found state, not a crash or a '
      'silent redirect',
      (tester) async {
        await tester.runAsync(loadVideoSeries);
        await tester.pumpWidget(
            wrap(const VideoSeriesByIdPage(id: 'zzz-no-such')));
        await tester.pumpAndSettle();

        expect(find.byType(VideoSeriesPage), findsNothing);
        // Default AppSettings locale is 'zh-Hans' (app_settings.dart).
        expect(find.text('未找到该视频系列。'), findsOneWidget);
      },
    );
  });

  group('EvidenceByIdPage (the /evidence/:id cold-load resolver)', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    Widget wrap(Widget child) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AppSettings>(create: (_) => AppSettings()),
            ChangeNotifierProvider<MainProvider>(create: (_) => MainProvider()),
          ],
          child: MaterialApp(home: child),
        );

    testWidgets('a real id resolves to the matching EvidenceDetailPage',
        (tester) async {
      // 'dead_sea_scrolls' is a real, permanent entry id in the bundled
      // assets/bible_evidence.json.
      await tester.runAsync(BibleEvidenceService.all);
      await tester.pumpWidget(
          wrap(const EvidenceByIdPage(id: 'dead_sea_scrolls')));
      await tester.pumpAndSettle();

      final page =
          tester.widget<EvidenceDetailPage>(find.byType(EvidenceDetailPage));
      expect(page.evidence.id, 'dead_sea_scrolls');
    });

    testWidgets(
      'an id with no match shows the not-found state, not a crash or a '
      'silent redirect',
      (tester) async {
        await tester.runAsync(BibleEvidenceService.all);
        await tester.pumpWidget(
            wrap(const EvidenceByIdPage(id: 'zzz-no-such')));
        await tester.pumpAndSettle();

        expect(find.byType(EvidenceDetailPage), findsNothing);
        expect(find.text('未找到该条证据。'), findsOneWidget);
      },
    );
  });

  group('MapByIdPage (the /maps/:id cold-load resolver)', () {
    Widget wrap(Widget child) => ChangeNotifierProvider<AppSettings>(
          create: (_) => AppSettings(),
          child: MaterialApp(home: child),
        );

    testWidgets('a real id resolves to the matching MapViewerPage, with '
        'relatedMaps left empty', (tester) async {
      // 'ancient_near_east' is a real, permanent id in the bundled
      // assets/maps_index.json.
      await tester.runAsync(MapService.loadMaps);
      await tester.pumpWidget(
          wrap(const MapByIdPage(id: 'ancient_near_east')));
      await tester.pumpAndSettle();

      final page = tester.widget<MapViewerPage>(find.byType(MapViewerPage));
      expect(page.map.id, 'ancient_near_east');
      // A cold load has no chapter/book context to build a curated
      // list from — see map_viewer_page.dart's MapByIdPage doc comment
      // for why an empty list degrades cleanly rather than crashing or
      // leaving the related strip empty forever.
      expect(page.relatedMaps, isEmpty);
    });

    testWidgets(
      'an id with no match shows the not-found state, not a crash or a '
      'silent redirect',
      (tester) async {
        await tester.runAsync(MapService.loadMaps);
        await tester.pumpWidget(wrap(const MapByIdPage(id: 'zzz-no-such')));
        await tester.pumpAndSettle();

        expect(find.byType(MapViewerPage), findsNothing);
        expect(find.text('未找到该地图。'), findsOneWidget);
      },
    );
  });
}
