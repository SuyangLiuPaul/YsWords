import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// URL-routing Stage 3 (`docs/url-routing-plan.md`, §6 batch 1): a sync
/// test for the three places a registered path has to agree with the
/// other two by hand.
///
/// `app_nav.dart`'s doc comment on `_registeredRoutePaths` says outright
/// that it is kept in sync with `main.dart`'s `getPages` table BY HAND.
/// Stage 2 got away with that at 2 entries; Stage 3 takes it to 13, and
/// a path present in `_registeredRoutePaths` but missing from `getPages`
/// doesn't fail a build or an analyzer pass — it throws inside GetX's
/// route resolver at runtime, the first time something pushes it. This
/// test turns that runtime throw into a red test instead, and also
/// checks the third copy of the same fact: the plan doc's own §3 table,
/// which is what a human reads to decide what the path *should* be.
///
/// All three are read as source text (matching
/// `url_routing_plan_table_test.dart`'s existing method) rather than
/// imported, because `main.dart`'s `_registeredGetPages` and
/// `app_nav.dart`'s `_registeredRoutePaths` are both private — the only
/// way to compare them without exporting internals just for a test is
/// to read the files.
void main() {
  test(
    'getPages, _registeredRoutePaths and the plan doc §3 table agree on '
    'every registered path',
    () {
      final mainText = File('lib/main.dart').readAsStringSync();
      final appNavText = File('lib/utils/app_nav.dart').readAsStringSync();
      final planText = File('docs/url-routing-plan.md').readAsStringSync();

      // 1. `main.dart`'s `_registeredGetPages` — class name -> path, in
      // the order the GetPage entries appear.
      final getPageEntry = RegExp(
        r"GetPage\(\s*name:\s*'([^']+)',\s*page:\s*\(\)\s*=>\s*const\s+(\w+)\(\),",
      );
      final getPagesByClass = <String, String>{};
      for (final m in getPageEntry.allMatches(mainText)) {
        getPagesByClass[m.group(2)!] = m.group(1)!;
      }
      expect(
        getPagesByClass,
        isNotEmpty,
        reason: 'no GetPage(name: ..., page: () => const X()) entries '
            'matched in lib/main.dart — the regex or the list\'s '
            'formatting changed and this test needs updating along with '
            'it, not silently passing empty',
      );
      final getPagesPaths = getPagesByClass.values.toSet();

      // 2. `app_nav.dart`'s `_registeredRoutePaths`.
      final registeredSetBlock = RegExp(
        r'_registeredRoutePaths\s*=\s*\{([\s\S]*?)\};',
      ).firstMatch(appNavText);
      expect(
        registeredSetBlock,
        isNotNull,
        reason: '_registeredRoutePaths set literal not found in '
            'lib/utils/app_nav.dart — it may have been renamed',
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

      // Every registered class's getPages path must match its plan-doc
      // proposed path exactly.
      final planMismatches = <String>[];
      for (final entry in getPagesByClass.entries) {
        final planPath = planPathByClass[entry.key];
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
        reason: '_registeredRoutePaths (app_nav.dart) and getPages '
            '(main.dart) have drifted apart. In _registeredRoutePaths '
            'only: ${registeredPaths.difference(getPagesPaths)}. In '
            'getPages only: ${getPagesPaths.difference(registeredPaths)}.',
      );
    },
  );
}
