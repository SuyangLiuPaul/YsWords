import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/widgets/version_picker_sheet.dart';

/// 2026-06-22 v2: widget tests for the language-grouped version popup.
/// The popup is a PopupMenuEntry hosted inside a PopupMenuButton (same
/// placement as the chapter picker's testament-pill pattern — drops
/// directly under the chip; no sliding sheet). These tests open the
/// menu, switch language pills, and verify selection wires through to
/// the PopupMenuButton's `onSelected`.
void main() {
  Future<({AppSettings settings, List<String> picked})> openMenu(
    WidgetTester tester, {
    required String currentVersion,
    Size size = const Size(390, 844),
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = AppSettings(); // defaults to zh-Hans locale
    final picked = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PopupMenuButton<String>(
              key: const Key('chip'),
              padding: EdgeInsets.zero,
              position: PopupMenuPosition.under,
              itemBuilder: (ctx) => [
                LanguageGroupedVersionEntry(
                  currentVersion: currentVersion,
                  settings: settings,
                ),
              ],
              onSelected: picked.add,
              child: const Text('chip'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('chip')));
    await tester.pumpAndSettle();
    return (settings: settings, picked: picked);
  }

  testWidgets('opens on the current version language + lists its editions',
      (tester) async {
    await openMenu(tester, currentVersion: 'cuvs-yhwh');
    // Pills (zh-Hans labels) are present.
    expect(find.text('英语'), findsOneWidget);
    expect(find.text('繁体'), findsOneWidget);
    expect(find.text('简体'), findsOneWidget);
    // Lands on Simplified (current version is cuvs-yhwh).
    expect(find.text('和合本雅伟版(简体)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching language pill swaps the edition list',
      (tester) async {
    await openMenu(tester, currentVersion: 'cuvs-yhwh');
    await tester.tap(find.text('英语'));
    await tester.pumpAndSettle();
    expect(find.text('New American Standard Bible'), findsOneWidget);
    await tester.tap(find.text('繁体'));
    await tester.pumpAndSettle();
    expect(find.text('和合本雅伟版(繁體)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'tapping a different edition reports it via onSelected + closes',
      (tester) async {
    final r = await openMenu(tester, currentVersion: 'cuvs-yhwh');
    await tester.tap(find.text('和合本(简体)')); // cuv
    await tester.pumpAndSettle();
    expect(r.picked, <String>['cuv']);
    expect(find.text('和合本雅伟版(简体)'), findsNothing); // menu dismissed
  });

  testWidgets('tapping the current edition closes without re-selecting',
      (tester) async {
    final r = await openMenu(tester, currentVersion: 'cuvs-yhwh');
    await tester.tap(find.text('和合本雅伟版(简体)')); // the current one
    await tester.pumpAndSettle();
    expect(r.picked, isEmpty);
    expect(find.text('和合本雅伟版(简体)'), findsNothing);
  });

  testWidgets('no overflow on an iPad-sized viewport', (tester) async {
    await openMenu(tester,
        currentVersion: 'cuvs-yhwh-tr', size: const Size(1180, 820));
    expect(find.text('和合本雅伟版(繁體)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
