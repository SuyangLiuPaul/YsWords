import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/sermon_detail_page.dart';
import 'package:yswords/services/sermon_service.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/route_paths.dart';

/// URL-routing Stage 4 (`docs/url-routing-plan.md`, §6 batch 2): the
/// first parameterized route, `/sermons/:id`. Stages 2–3 only ever
/// checked literal-path membership; this stage's whole point is that a
/// CONCRETE path (`/sermons/004`) has to match a TEMPLATE
/// (`/sermons/:id`), which a plain `Set.contains()` can never do — see
/// `lib/utils/route_paths.dart`'s doc comment for why.
void main() {
  group('matchesRegisteredRoute', () {
    test('a concrete param path matches its template', () {
      expect(matchesRegisteredRoute('/sermons/004', {'/sermons/:id'}),
          isTrue);
      expect(
          matchesRegisteredRoute('/sermons/EC010', {'/sermons/:id'}), isTrue);
    });

    test('literal templates still match exactly, as before Stage 4', () {
      expect(matchesRegisteredRoute('/about', {'/about'}), isTrue);
      expect(matchesRegisteredRoute('/about', {'/highlights'}), isFalse);
    });

    // Regression guard for the exact bug this stage's mechanism gap
    // section names: a plain `.contains()` check can never recognise a
    // concrete path against a template, which is why every call site
    // had to move off `Set<String>.contains()` onto this function.
    test('a template does NOT match via plain Set.contains', () {
      const templates = {'/sermons/:id'};
      expect(templates.contains('/sermons/004'), isFalse);
      expect(matchesRegisteredRoute('/sermons/004', templates), isTrue);
    });

    test('segment counts must agree — no partial or prefix match', () {
      const templates = {'/sermons/:id'};
      expect(matchesRegisteredRoute('/sermons', templates), isFalse);
      expect(matchesRegisteredRoute('/sermons/004/extra', templates), isFalse);
    });

    test('an unrelated concrete path matches nothing', () {
      expect(matchesRegisteredRoute('/videos/004', {'/sermons/:id'}), isFalse);
    });

    test('kRegisteredRoutePaths (the real, default template set) includes '
        "'/sermons/:id'", () {
      expect(kRegisteredRoutePaths, contains('/sermons/:id'));
      expect(matchesRegisteredRoute('/sermons/004'), isTrue);
    });
  });

  group('pushPage dispatch for a parameterized routeName', () {
    // Same stub shape as url_routing_stage2_test.dart /
    // url_routing_stage3_test.dart: a `_Registered` stub proves the push
    // went through `Get.toNamed` (and hit the GetPage GetX matched by
    // its OWN route-tree logic against the `/sermons/:id` template) —
    // not `app_nav.dart`'s `Get.to` fallback, which would render
    // whatever widget was passed to `pushPage` and ignore `getPages`
    // entirely.
    testWidgets(
      "pushPage(.., routeName: '/sermons/004') dispatches through "
      'Get.toNamed and GetX resolves it against the /sermons/:id template',
      (tester) async {
        await tester.pumpWidget(
          GetMaterialApp(
            getPages: [
              GetPage(
                name: '/sermons/:id',
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
            routeName: '/sermons/004');
        await tester.pumpAndSettle();

        expect(find.text('REGISTERED: 004'), findsOneWidget);
        expect(find.text('PASSED-IN'), findsNothing);
        expect(Get.currentRoute, '/sermons/004');

        Get.back();
        await tester.pumpAndSettle();
        expect(find.text('ROOT'), findsOneWidget);
      },
    );
  });

  group('SermonByIdPage (the /sermons/:id cold-load resolver)', () {
    Widget wrap(Widget child) => ChangeNotifierProvider<AppSettings>(
          create: (_) => AppSettings(),
          child: MaterialApp(home: child),
        );

    testWidgets('a real id resolves to the matching SermonDetailPage',
        (tester) async {
      // '004' is a real, permanent id — asserted elsewhere
      // (prerender_sermons_test.dart) to always be present with all
      // three languages, so this isn't relying on incidental corpus
      // state.
      //
      // `_resolve()`'s `rootBundle.loadString` is real async IO, which
      // the fake clock `pumpAndSettle` drives never advances — same
      // trap `cahaya_songs_enabled_test.dart` documents. Warm
      // SermonService's memoised `_index` via `runAsync` before
      // `pumpWidget` so `_resolve()` hits the cache instead.
      await tester.runAsync(SermonService.instance.loadIndex);
      await tester.pumpWidget(wrap(const SermonByIdPage(id: '004')));
      await tester.pumpAndSettle();

      final page =
          tester.widget<SermonDetailPage>(find.byType(SermonDetailPage));
      expect(page.sermon.id, '004');
      // highlight must stay unset for a cold load — docs/url-routing-
      // plan.md:140 decided it's a search-result artifact, not page
      // identity, so it's deliberately absent from the URL.
      expect(page.highlight, isNull);
    });

    testWidgets(
      'an id not in the index shows the not-found state, not a crash or '
      'a silent redirect',
      (tester) async {
        await tester.runAsync(SermonService.instance.loadIndex);
        await tester.pumpWidget(wrap(const SermonByIdPage(id: 'zzz-no-such')));
        await tester.pumpAndSettle();

        expect(find.byType(SermonDetailPage), findsNothing);
        // Default AppSettings locale is 'zh-Hans' (app_settings.dart).
        expect(find.text('未找到该讲道。'), findsOneWidget);
      },
    );
  });
}
