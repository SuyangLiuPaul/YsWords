import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/library_page.dart';
import 'package:yswords/pages/settings_page.dart';
import 'package:yswords/pages/song_score_page.dart';
import 'package:yswords/pages/song_video_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/song_service.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/route_paths.dart';

/// URL-routing Stage 5 (`docs/url-routing-plan.md` §6): the rest of the
/// conversion — batch 3 (multi-param / enum pages), batch 4 (the two
/// raw-`Navigator.push` sites) and batch 5 (confirming the three pages
/// the plan deliberately leaves unrouted are still reachable).
///
/// Batches 1 and 2 are covered by `url_routing_stage2/3/4*_test.dart`;
/// the reported bug itself by `url_routing_address_bar_test.dart`.
void main() {
  // Get is a process-wide singleton; a pumped GetMaterialApp does not
  // clear its stack between tests.
  tearDown(Get.reset);

  /// One stub GetPage per registered template, so a push proves it went
  /// through `Get.toNamed` and GetX's own route tree — the `Get.to`
  /// fallback would render the widget passed to `pushPage` and never
  /// consult `getPages` at all. Built from the real
  /// [kRegisteredRoutePaths] rather than a hand-listed subset.
  Widget app() => GetMaterialApp(
        getPages: [
          for (final template in kRegisteredRoutePaths)
            GetPage(
              name: template,
              page: () => Scaffold(
                body: Center(
                  child: Text('PAGE $template ${Get.parameters}'),
                ),
              ),
            ),
        ],
        home: const Scaffold(body: Center(child: Text('ROOT'))),
      );

  // ── Batch 3: /settings, /library, /evidence ────────────────────────

  group('batch 3 — SettingsPage', () {
    test('every SettingsSection has a slug, and every slug round-trips', () {
      for (final section in SettingsSection.values) {
        final slug = kSettingsSectionSlugs[section];
        expect(slug, isNotNull,
            reason: '$section has no URL slug — a new enum value was added '
                'without one, so /settings/<it> is unreachable');
        expect(settingsSectionForSlug(slug), section);
      }
      expect(kSettingsSectionSlugs.values.toSet().length,
          SettingsSection.values.length,
          reason: 'two sections share a slug');
    });

    test('an unknown or absent section degrades to plain Settings, not to '
        'a not-found page', () {
      expect(settingsSectionForSlug('no-such-section'), isNull);
      expect(settingsSectionForSlug(''), isNull);
      expect(settingsSectionForSlug(null), isNull);
    });

    test('the slugs are literals, not Enum.name', () {
      // `dashboardLayout` reads badly in a URL, and more importantly a
      // reflected `.name` is a class member — the kind of thing
      // `flutter build web --release` minifies, which is the trap Stage
      // 2 already paid for once (see app_nav.dart).
      expect(kSettingsSectionSlugs[SettingsSection.dashboardLayout],
          'dashboard');
      final src = File('lib/pages/settings_page.dart').readAsStringSync();
      final table = src.substring(src.indexOf('kSettingsSectionSlugs'));
      expect(table.substring(0, table.indexOf('};')), isNot(contains('.name')));
    });

    testWidgets('both /settings and /settings/:section resolve, each to its '
        'own registered entry', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      pushPage(const Scaffold(body: Text('PASSED-IN')),
          routeName: '/settings');
      await tester.pumpAndSettle();
      expect(find.textContaining('PAGE /settings {'), findsOneWidget);
      expect(find.text('PASSED-IN'), findsNothing);
      Get.back();
      await tester.pumpAndSettle();

      pushPage(const Scaffold(body: Text('PASSED-IN')),
          routeName: '/settings/ai');
      await tester.pumpAndSettle();
      expect(find.text('PAGE /settings/:section {section: ai}'),
          findsOneWidget);
      Get.back();
      await tester.pumpAndSettle();
      expect(find.text('ROOT'), findsOneWidget);
    });
  });

  group('batch 3 — LibraryPage', () {
    test('the tab slugs map by MEANING, not by the order the plan listed '
        'them in', () {
      // 0 is Notes and 1 is Bookmarks (LibraryPage.initialTab's own doc
      // comment, and both dashboard count tiles). The plan's §3 cell
      // wrote them "bookmarks|notes", which is the other order — taking
      // that as the mapping would reproduce the 2026-08-11 report
      // "按书签，跳到的是笔记" through a URL instead of a tile.
      expect(libraryTabForSlug('notes'), 0);
      expect(libraryTabForSlug('bookmarks'), 1);
      expect(libraryTabSlug(0), 'notes');
      expect(libraryTabSlug(1), 'bookmarks');
    });

    test('an unknown tab degrades to the default rather than failing', () {
      expect(libraryTabForSlug('no-such-tab'), isNull);
      expect(libraryTabForSlug(null), isNull);
    });

    testWidgets('/library/bookmarks really opens the Bookmarks tab in the '
        'real page, not just in the slug table', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MainProvider()),
            ChangeNotifierProvider(create: (_) => AppSettings()),
          ],
          child: MaterialApp(
            home: LibraryPage(initialTab: libraryTabForSlug('bookmarks') ?? 0),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final controller = tester
          .widget<DefaultTabController>(find.byType(DefaultTabController));
      expect(controller.initialIndex, 1);
    });

    testWidgets('both /library and /library/:tab resolve to their own '
        'registered entries', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      pushPage(const Scaffold(body: Text('PASSED-IN')), routeName: '/library');
      await tester.pumpAndSettle();
      expect(find.textContaining('PAGE /library {'), findsOneWidget);
      Get.back();
      await tester.pumpAndSettle();

      pushPage(const Scaffold(body: Text('PASSED-IN')),
          routeName: '/library/bookmarks');
      await tester.pumpAndSettle();
      expect(find.text('PAGE /library/:tab {tab: bookmarks}'), findsOneWidget);
    });
  });

  group('batch 3 — EvidencePage and its query-string filters', () {
    test('evidencePath builds the bare path when unfiltered, and encodes '
        'a book name with a space', () {
      expect(evidencePath(), '/evidence');
      expect(evidencePath(book: null, chapter: null), '/evidence');
      expect(evidencePath(book: 'John', chapter: 3),
          '/evidence?book=John&chapter=3');
      expect(evidencePath(chapter: 3), '/evidence?chapter=3');
      // `1 Samuel`, `Song of Songs` — canonical English names carry
      // spaces, and a raw space in a URL is not a URL.
      expect(evidencePath(book: '1 Samuel', chapter: 17),
          '/evidence?book=1+Samuel&chapter=17');
    });

    test('a query string does not stop a path recognising its own '
        'registered route', () {
      // The route on top of the stack is reported to
      // url_sync_service_web.dart as GetX wrote it — query and all
      // (verified against `route.settings.name` in a widget test). If
      // this returned false, the Bible-position writer would clobber the
      // address bar the moment a filtered Evidence page opened, which is
      // this whole item's bug wearing a different hat.
      expect(matchesRegisteredRoute('/evidence?book=John&chapter=3'), isTrue);
      expect(matchesRegisteredRoute('/evidence'), isTrue);
      // The query must not smuggle a path past segment matching either.
      expect(matchesRegisteredRoute('/nope?book=John'), isFalse);
      // ... and /evidence/:id (3 segments) stays distinct from
      // /evidence (2), exactly as /songs/playlists did in batch 2.
      expect(matchesRegisteredRoute('/evidence/dead_sea_scrolls'), isTrue);
    });

    testWidgets('GetX turns the query into Get.parameters on a named push',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      pushPage(const Scaffold(body: Text('PASSED-IN')),
          routeName: evidencePath(book: 'John', chapter: 3));
      await tester.pumpAndSettle();

      expect(find.text('PAGE /evidence {book: John, chapter: 3}'),
          findsOneWidget);
      expect(find.text('PASSED-IN'), findsNothing);
      expect(Get.currentRoute, '/evidence?book=John&chapter=3');
    });

    test('main.dart feeds those parameters into the real EvidencePage', () {
      // The GetPage builders are private to main.dart, so the wiring is
      // checked as source — same method url_routing_stage3_sync_test.dart
      // uses for the route table itself. Without this the widget test
      // above would prove only that GetX parses a query, not that the
      // app does anything with it.
      final src = File('lib/main.dart').readAsStringSync();
      final entry = src.substring(src.indexOf("name: '/evidence',"));
      final builder = entry.substring(0, entry.indexOf('transition:'));
      expect(builder, contains("filterBook: Get.parameters['book']"));
      expect(builder,
          contains("filterChapter: int.tryParse(Get.parameters['chapter']"));
    });
  });

  // ── Batch 4: the two pages that never used pushPage at all ─────────

  group('batch 4 — the raw-Navigator.push sites', () {
    test('neither song page pushes a raw MaterialPageRoute any more', () {
      // This is the batch's entire point (docs/url-routing-plan.md §2:
      // "a real gap the \'pushPage is the only way pages are pushed\'
      // assumption would have missed"). A raw MaterialPageRoute has no
      // route name, so no router could ever have given these an address.
      for (final path in [
        'lib/pages/song_score_page.dart',
        'lib/pages/song_video_page.dart',
      ]) {
        final src = File(path).readAsStringSync();
        // Comments stripped: both files now EXPLAIN, in prose, what they
        // used to do, and a naive scan reads that explanation as the
        // thing itself.
        final code = src
            .split('\n')
            .map((l) {
              final c = l.indexOf('//');
              return c < 0 ? l : l.substring(0, c);
            })
            .join('\n');
        expect(code, isNot(contains('MaterialPageRoute')), reason: path);
        expect(code, isNot(contains('Navigator.of(context).push')),
            reason: path);
        expect(code, contains('pushPage<void>'), reason: path);
        expect(code, contains('songSubPagePath'), reason: path);
      }
    });

    test('songSubPagePath encodes the colon every song id carries', () {
      // Ids are `<source>:<slug>` — `cdc:d0180`, `fydt:122368`.
      expect(songSubPagePath('cdc:d0180', 'score'),
          '/songs/cdc%3Ad0180/score');
      expect(songSubPagePath('fydt:122368', 'video'),
          '/songs/fydt%3A122368/video');
    });

    test('both templates match their concrete paths and do not collide '
        'with the /songs routes already registered', () {
      expect(matchesRegisteredRoute('/songs/cdc%3Ad0180/score'), isTrue);
      expect(matchesRegisteredRoute('/songs/cdc%3Ad0180/video'), isTrue);
      // 4 segments each — the same shape as /songs/playlists/:id, which
      // is why this is worth an explicit assertion rather than trust.
      expect(
          matchesRegisteredRoute(
              '/songs/playlists/pl_1', {'/songs/:songId/score'}),
          isFalse);
      expect(
          matchesRegisteredRoute(
              '/songs/cdc%3Ad0180/score', {'/songs/playlists/:id'}),
          isFalse);
      // No bare or over-long form.
      expect(matchesRegisteredRoute('/songs/cdc%3Ad0180'), isFalse);
      expect(matchesRegisteredRoute('/songs/a/score/extra'), isFalse);
    });

    testWidgets('GetX resolves both, and hands the page a DECODED song id',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      for (final leaf in ['score', 'video']) {
        pushPage(const Scaffold(body: Text('PASSED-IN')),
            routeName: songSubPagePath('cdc:d0180', leaf));
        await tester.pumpAndSettle();
        // The colon comes back, so SongService.byId('cdc:d0180') can
        // find the row — a percent-encoded id would match nothing.
        expect(find.text('PAGE /songs/:songId/$leaf {songId: cdc:d0180}'),
            findsOneWidget);
        expect(find.text('PASSED-IN'), findsNothing);
        Get.back();
        await tester.pumpAndSettle();
      }
      expect(find.text('ROOT'), findsOneWidget);
    });

    testWidgets(
      "GetX's own route tree keeps /songs/playlists/:id and "
      '/songs/:songId/score apart, with every template registered at once',
      (tester) async {
        // Both are 4-segment templates under /songs and they were
        // introduced two batches apart, so nothing before this stage
        // ever exercised them side by side. route_paths.dart's matcher
        // separating them (asserted above) is not the same guarantee:
        // GetX's ParseRouteTree is a different resolver and it is the
        // one that runs on a real push.
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();

        pushPage(const Scaffold(), routeName: '/songs/playlists/pl_1');
        await tester.pumpAndSettle();
        expect(find.text('PAGE /songs/playlists/:id {id: pl_1}'),
            findsOneWidget);
        Get.back();
        await tester.pumpAndSettle();

        pushPage(const Scaffold(), routeName: '/songs/playlists');
        await tester.pumpAndSettle();
        expect(find.textContaining('PAGE /songs/playlists {'), findsOneWidget);
        Get.back();
        await tester.pumpAndSettle();

        pushPage(const Scaffold(), routeName: '/songs/downloads');
        await tester.pumpAndSettle();
        expect(find.textContaining('PAGE /songs/downloads {'), findsOneWidget);
      },
    );
  });

  group('batch 4 — the cold-load resolvers', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    Widget wrap(Widget child) => ChangeNotifierProvider<AppSettings>(
          create: (_) => AppSettings(),
          child: MaterialApp(home: child),
        );

    /// A real id out of the bundled `assets/songs.json`, read at test
    /// time rather than hard-coded: the catalogue is regenerated
    /// upstream daily and pinning one id here would make this test fail
    /// for a reason that has nothing to do with routing.
    Future<String> anySongId(WidgetTester tester) async {
      late final String id;
      await tester.runAsync(() async {
        final songs = await SongService.load();
        expect(songs, isNotEmpty,
            reason: 'assets/songs.json is empty or failed to parse');
        id = songs.first.id;
      });
      return id;
    }

    testWidgets('SongScoreByIdPage resolves a real id to SongScorePage',
        (tester) async {
      final id = await anySongId(tester);
      await tester.pumpWidget(wrap(SongScoreByIdPage(id: id)));
      await tester.pumpAndSettle();

      final page = tester.widget<SongScorePage>(find.byType(SongScorePage));
      expect(page.song.id, id);
    });

    testWidgets('SongVideoByIdPage resolves a real id to SongVideoPage',
        (tester) async {
      final id = await anySongId(tester);
      await tester.pumpWidget(wrap(SongVideoByIdPage(id: id)));
      // Fixed frames, not pumpAndSettle: once resolved, SongVideoPage's
      // initState opens a VideoPlayerController against the network, and
      // the frame loop never goes quiet. What is under test is the
      // resolution step, which lands well inside these.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      final page = tester.widget<SongVideoPage>(find.byType(SongVideoPage));
      expect(page.song.id, id);
    });

    testWidgets('an unknown song id shows the not-found state on both, '
        'never a crash or a silent redirect', (tester) async {
      await tester.runAsync(SongService.load);

      await tester.pumpWidget(wrap(const SongScoreByIdPage(id: 'zzz:no-such')));
      await tester.pumpAndSettle();
      expect(find.byType(SongScorePage), findsNothing);
      // Default AppSettings locale is 'zh-Hans' (app_settings.dart).
      expect(find.text('未找到该首诗歌。'), findsOneWidget);

      await tester.pumpWidget(wrap(const SongVideoByIdPage(id: 'zzz:no-such')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SongVideoPage), findsNothing);
      expect(find.text('未找到该首诗歌。'), findsOneWidget);
    });
  });

  // ── Batch 5: the pages that stay unrouted, by design ───────────────

  group('batch 5 — deliberately unrouted pages stay unrouted AND reachable',
      () {
    // docs/url-routing-plan.md §3/§6: `ProfileEditPage` edits "the
    // current profile" from provider state and has no id to put in a
    // URL; `NowPlayingPage` reads live playback, so a cold load has
    // nothing to restore; `BooksPage`'s split-view push carries a live
    // MainProvider instance that cannot serialize. The reasons are
    // load-bearing — this group asserts the decision held, not that it
    // was reversed.
    const unrouted = ['ProfileEditPage', 'NowPlayingPage', 'BooksPage'];

    test('none of the three has a registered path, under any spelling', () {
      for (final name in unrouted) {
        expect(matchesRegisteredRoute('/$name'), isFalse, reason: name);
        for (final path in kRegisteredRoutePaths) {
          expect(path.toLowerCase(), isNot(contains(name.toLowerCase())),
              reason: '$name acquired a route; the plan says it has no '
                  'durable id to put in one');
        }
      }
    });

    test('the plan doc still records them as not addressable', () {
      final plan = File('docs/url-routing-plan.md').readAsStringSync();
      for (final name in unrouted) {
        final row = RegExp('^\\|\\s*`$name`\\s*\\|\\s*(.*?)\\s*\\|',
                multiLine: true)
            .firstMatch(plan);
        expect(row, isNotNull, reason: '$name lost its §3 row');
        expect(row!.group(1), '—',
            reason: '$name gained a proposed path in the plan doc without '
                'the "no durable id" reasoning being revisited');
      }
    });

    testWidgets('an unrouted page is still pushable and Back still returns '
        'to its parent', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      // The parent list (Profiles IS routed) …
      pushPage(const Scaffold(body: Text('PASSED-IN')), routeName: '/profiles');
      await tester.pumpAndSettle();
      expect(find.textContaining('PAGE /profiles'), findsOneWidget);

      // … then the unrouted child, exactly as ProfilesPage pushes it:
      // no registered routeName, so app_nav.dart's `Get.to` fallback
      // takes it and the address bar is left alone.
      pushPage(const Scaffold(body: Text('PROFILE EDIT')));
      await tester.pumpAndSettle();
      expect(find.text('PROFILE EDIT'), findsOneWidget);

      Get.back();
      await tester.pumpAndSettle();
      expect(find.textContaining('PAGE /profiles'), findsOneWidget,
          reason: 'Back from an unrouted child must return to the parent '
              'list it was pushed from — the plan calls this out as the '
              'thing to confirm did not break when the pages around it '
              'gained routes');
    });
  });

  // ── The inventory is now complete ──────────────────────────────────

  test('every page the plan proposes a path for now has one registered', () {
    // Closes the loop on §3: the plan named a `/path` for a set of
    // classes, and after this stage every one of them is registered
    // except the two §6 batch 6 explicitly defers. If someone adds a
    // §3 row with a path and no route, this fails.
    final plan = File('docs/url-routing-plan.md').readAsStringSync();
    final rows = RegExp(r'^\|\s*`([A-Za-z_][A-Za-z0-9_]*)`\s*\|\s*(.*?)\s*\|',
        multiLine: true);

    // Deferred by §6 item 6 until the widget accepts its filter as a
    // param; converting the base page first would ship a URL that looks
    // parameterized and silently drops the filter on reload.
    const deferred = {'SearchPage', 'BibleTriviaPage'};
    // Covered by the frozen Bible grammar (§1), not by getPages.
    const frozen = {'DashboardPage', 'HomePage'};

    final missing = <String>[];
    for (final m in rows.allMatches(plan)) {
      final cls = m.group(1)!;
      if (deferred.contains(cls) || frozen.contains(cls)) continue;
      final paths = RegExp('`([^`]+)`')
          .allMatches(m.group(2)!)
          .map((p) => p.group(1)!)
          .toList();
      if (paths.isEmpty) continue; // the "—" rows, checked above
      for (final p in paths) {
        if (!kRegisteredRoutePaths.contains(p)) missing.add('$cls -> $p');
      }
    }
    expect(missing, isEmpty,
        reason: 'the plan proposes these paths but nothing registers them:\n'
            '${missing.join('\n')}');
  });
}
