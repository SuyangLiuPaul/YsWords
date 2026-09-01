import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// URL-routing Stage 3 (`docs/url-routing-plan.md`, §6 batch 1): a sync
/// test for the three places a registered path has to agree with the
/// other two by hand.
///
/// Through Stage 3 that was `app_nav.dart`'s own `_registeredRoutePaths`
/// set, kept in sync with `main.dart`'s `getPages` table BY HAND. Stage
/// 4 (`docs/url-routing-plan.md` §6 batch 2) moved that set out to
/// `lib/utils/route_paths.dart`'s `kRegisteredRoutePaths` — the single
/// source of truth both `app_nav.dart`'s dispatch and
/// `url_sync_service_web.dart`'s boot/popstate/write checks now import
/// — so this test reads it from there instead. The underlying risk
/// this test guards against is unchanged: a path present in
/// `kRegisteredRoutePaths` but missing from `getPages` doesn't fail a
/// build or an analyzer pass — it throws inside GetX's route resolver
/// at runtime, the first time something pushes it. This test turns
/// that runtime throw into a red test instead, and also checks the
/// third copy of the same fact: the plan doc's own §3 table, which is
/// what a human reads to decide what the path *should* be.
///
/// All three are read as source text (matching
/// `url_routing_plan_table_test.dart`'s existing method) rather than
/// imported, because `main.dart`'s `_registeredGetPages` is private —
/// the only way to compare it without exporting internals just for a
/// test is to read the file.
void main() {
  test(
    'getPages, kRegisteredRoutePaths and the plan doc §3 table agree on '
    'every registered path',
    () {
      final mainText = File('lib/main.dart').readAsStringSync();
      final routePathsText =
          File('lib/utils/route_paths.dart').readAsStringSync();
      final appNavText = File('lib/utils/app_nav.dart').readAsStringSync();
      final urlSyncText =
          File('lib/services/url_sync_service_web.dart').readAsStringSync();
      final planText = File('docs/url-routing-plan.md').readAsStringSync();

      // 0. Both dispatch sites actually route through the shared
      // matcher rather than a reverted local `.contains()` — the drift
      // this whole file exists to prevent could otherwise sneak back
      // in without touching either set below.
      expect(appNavText, contains('matchesRegisteredRoute'),
          reason: 'app_nav.dart\'s pushPage no longer dispatches through '
              'route_paths.dart\'s shared matcher');
      expect(urlSyncText, contains('matchesRegisteredRoute'),
          reason: 'url_sync_service_web.dart no longer dispatches through '
              'route_paths.dart\'s shared matcher');

      // 1. `main.dart`'s `_registeredGetPages` — class name -> path, in
      // the order the GetPage entries appear. Stage 4 added a
      // parameterized entry (`SermonByIdPage(id: Get.parameters['id'] ??
      // '')`), so the class name only needs an opening paren after it,
      // not the exact zero-arg `const X()` every earlier entry used.
      final getPageEntry = RegExp(
        r"GetPage\(\s*name:\s*'([^']+)',\s*page:\s*\(\)\s*=>\s*(?:const\s+)?(\w+)\(",
      );
      final getPagesByClass = <String, String>{};
      for (final m in getPageEntry.allMatches(mainText)) {
        getPagesByClass[m.group(2)!] = m.group(1)!;
      }
      expect(
        getPagesByClass,
        isNotEmpty,
        reason: 'no GetPage(name: ..., page: () => X(...)) entries '
            'matched in lib/main.dart — the regex or the list\'s '
            'formatting changed and this test needs updating along with '
            'it, not silently passing empty',
      );
      final getPagesPaths = getPagesByClass.values.toSet();

      // 2. `route_paths.dart`'s `kRegisteredRoutePaths`.
      final registeredSetBlock = RegExp(
        r'kRegisteredRoutePaths\s*=\s*\{([\s\S]*?)\};',
      ).firstMatch(routePathsText);
      expect(
        registeredSetBlock,
        isNotNull,
        reason: 'kRegisteredRoutePaths set literal not found in '
            'lib/utils/route_paths.dart — it may have been renamed',
      );
      final registeredPaths = RegExp(r"'([^']+)'")
          .allMatches(registeredSetBlock!.group(1)!)
          .map((m) => m.group(1)!)
          .toSet();

      // 3. The plan doc's §3 table: class -> proposed path, for just
      // the classes `getPages` actually registers. Other rows (Bible
      // reader, dialog-only pages, batch-2+ detail pages) are
      // deliberately out of scope for this comparison.
      final tableRow = RegExp(
        r'^\|\s*`([A-Za-z_][A-Za-z0-9_]*)`\s*\|\s*(.*?)\s*\|',
        multiLine: true,
      );
      final planPathByClass = <String, String>{};
      for (final m in tableRow.allMatches(planText)) {
        final pathCell = m.group(2)!;
        final pathMatch = RegExp('`([^`]+)`').firstMatch(pathCell);
        if (pathMatch == null) continue; // "—" (not addressable) rows
        planPathByClass[m.group(1)!] = pathMatch.group(1)!;
      }

      // URL-routing Stage 4: `SermonByIdPage` is registered in getPages
      // under its own class (the async id-lookup resolver — see its doc
      // comment in sermon_detail_page.dart), but the plan doc's §3 table
      // names the page it resolves TO, `SermonDetailPage`, because that
      // row is about page identity, not the resolver mechanism. Same
      // path, different class name by design — map it before comparing.
      const resolverAliases = {'SermonByIdPage': 'SermonDetailPage'};

      // Every registered class's getPages path must match its plan-doc
      // proposed path exactly.
      final planMismatches = <String>[];
      for (final entry in getPagesByClass.entries) {
        final planClass = resolverAliases[entry.key] ?? entry.key;
        final planPath = planPathByClass[planClass];
        if (planPath == null) {
          planMismatches
              .add('${entry.key}: registered as ${entry.value} but has no §3 '
                  'table row with a `/path`');
        } else if (planPath != entry.value) {
          planMismatches
              .add('${entry.key}: getPages says ${entry.value}, plan doc §3 '
                  'says $planPath');
        }
      }
      expect(
        planMismatches,
        isEmpty,
        reason: 'getPages/plan doc disagreement:\n'
            '${planMismatches.join('\n')}',
      );

      // The three path sets themselves must be identical — a path in
      // one but not another is exactly the drift `app_nav.dart`'s
      // comment warns is unsafe to leave unhand-synced.
      expect(
        registeredPaths,
        getPagesPaths,
        reason: 'kRegisteredRoutePaths (route_paths.dart) and getPages '
            '(main.dart) have drifted apart. In kRegisteredRoutePaths '
            'only: ${registeredPaths.difference(getPagesPaths)}. In '
            'getPages only: ${getPagesPaths.difference(registeredPaths)}.',
      );
    },
  );
}
