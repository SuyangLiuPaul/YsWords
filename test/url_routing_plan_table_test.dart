import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `docs/url-routing-plan.md` §3 is a table of every page class this
/// codebase reaches by an in-app push, built by reading the code on
/// 2026-09-01 (see the plan's §2 for the count). This test re-derives
/// the same inventory from source and fails the moment a class is
/// pushed that the table doesn't list — so a page added next month
/// can't silently sit outside the URL scheme the plan defines.
///
/// It does not check that the plan's proposed path is implemented (it
/// isn't yet — Stage 1 is paper only) or that the table entry says
/// anything sensible, only that the class is *named* there.
void main() {
  test('every pushed page class appears in the routing plan\'s table',
      () {
    final planPath = 'docs/url-routing-plan.md';
    final planFile = File(planPath);
    if (!planFile.existsSync()) {
      fail('$planPath is missing — Stage 1 of the URL-routing item '
          'has not shipped, or was moved');
    }
    final planText = planFile.readAsStringSync();
    final tableRow = RegExp(r'^\|\s*`([A-Za-z_][A-Za-z0-9_]*)`\s*\|',
        multiLine: true);
    final planClasses = {
      for (final m in tableRow.allMatches(planText)) m.group(1)!,
    };
    expect(planClasses, isNotEmpty,
        reason: 'no `ClassName` table rows found in $planPath — the '
            'table format changed and this test\'s regex needs updating '
            'along with it, not silently passing empty');

    final libDir = Directory('lib');
    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    // Same resolution rule as the plan's §2 method: a `pushPage(`
    // call, or a `MaterialPageRoute` (the codebase's two raw
    // `Navigator.of(context).push`/`pushReplacement` sites, plus
    // `onUnknownRoute`), each followed (after an optional `const`) by
    // the pushed widget's constructor name. `showDialog` /
    // `showModalBottomSheet` builders are deliberately NOT scanned —
    // the plan's §2 excludes them as transient overlays, not pages.
    final pushPageCall = RegExp(r'pushPage\(\s*');
    final materialPageRoute = RegExp(r'MaterialPageRoute[\w<>?]*\(');
    final routeBuilder = RegExp(r'builder:\s*\([\w,\s]*\)\s*=>\s*');
    final widgetName = RegExp(r'^(?:const\s+)?([A-Z][A-Za-z0-9_]*)\s*\(');

    final pushedClasses = <String, String>{}; // class -> one file it's in

    void collect(String text, RegExp callSite, String path) {
      for (final m in callSite.allMatches(text)) {
        final rest = text.substring(m.end, (m.end + 80).clamp(0, text.length));
        final cm = widgetName.firstMatch(rest.trimLeft());
        if (cm == null) continue;
        pushedClasses.putIfAbsent(cm.group(1)!, () => path);
      }
    }

    for (final f in dartFiles) {
      // The `pushPage` helper's own definition isn't a call site.
      if (f.path.endsWith('app_nav.dart')) continue;
      final text = f.readAsStringSync();
      collect(text, pushPageCall, f.path);
      for (final m in materialPageRoute.allMatches(text)) {
        final window =
            text.substring(m.end, (m.end + 200).clamp(0, text.length));
        final bm = routeBuilder.firstMatch(window);
        if (bm == null) continue;
        final rest = window.substring(bm.end);
        final cm = widgetName.firstMatch(rest.trimLeft());
        if (cm == null) continue;
        pushedClasses.putIfAbsent(cm.group(1)!, () => f.path);
      }
    }

    // `_RootRouter` builds `HomePage`/`DashboardPage` directly by flag,
    // not via a push — the plan's §2 covers both as root-shell states
    // already in the frozen grammar, so seed them in rather than
    // require main.dart's ternary to match the same call-site shape.
    pushedClasses.putIfAbsent('DashboardPage', () => 'lib/main.dart');
    pushedClasses.putIfAbsent('HomePage', () => 'lib/main.dart');

    final undocumented = pushedClasses.keys
        .where((c) => !planClasses.contains(c))
        .toList()
      ..sort();

    expect(
      undocumented,
      isEmpty,
      reason: 'these page classes are pushed in lib/ but have no row in '
          '$planPath §3: '
          '${undocumented.map((c) => '$c (${pushedClasses[c]})').join(', ')}'
          ' — add a row (even "not addressable, opens the parent" is a '
          'valid verdict) so the destination inventory stays complete.',
    );
  });
}
