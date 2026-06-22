import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/widgets/version_picker_sheet.dart';

/// 2026-06-22: widget tests for the language-grouped version picker
/// sheet. Verifies it opens on the current version's language, switches
/// language tabs, reports the chosen version, and overflows on no size.
void main() {
  Future<AppSettings> openSheet(
    WidgetTester tester, {
    required String currentVersion,
    required void Function(String) onSelected,
    Size size = const Size(390, 844),
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = AppSettings(); // defaults to zh-Hans locale
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => showVersionPickerSheet(
                  context: ctx,
                  currentVersion: currentVersion,
                  onSelected: onSelected,
                  settings: settings,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return settings;
  }

  testWidgets('opens on the current version language + lists its editions',
      (tester) async {
    await openSheet(tester, currentVersion: 'cuvs-yhwh', onSelected: (_) {});
    expect(find.text('选择圣经版本'), findsOneWidget); // title (zh-Hans)
    expect(find.text('英语'), findsOneWidget); // language tabs present
    expect(find.text('繁体'), findsOneWidget);
    expect(find.text('简体'), findsOneWidget);
    expect(find.text('和合本雅伟版(简体)'), findsOneWidget); // a simplified edition
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching language tab swaps the edition list', (tester) async {
    await openSheet(tester, currentVersion: 'cuvs-yhwh', onSelected: (_) {});
    // English tab → NASB; Traditional tab → a 繁體 edition.
    await tester.tap(find.text('英语'));
    await tester.pumpAndSettle();
    expect(find.text('New American Standard Bible'), findsOneWidget);
    await tester.tap(find.text('繁体'));
    await tester.pumpAndSettle();
    expect(find.text('和合本雅伟版(繁體)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an edition reports it + closes the sheet',
      (tester) async {
    final picked = <String>[];
    await openSheet(tester, currentVersion: 'cuvs-yhwh', onSelected: picked.add);
    await tester.tap(find.text('和合本(简体)')); // cuv
    await tester.pumpAndSettle();
    expect(picked, <String>['cuv']);
    expect(find.text('选择圣经版本'), findsNothing); // sheet dismissed
  });

  testWidgets('re-tapping the current edition closes without re-selecting',
      (tester) async {
    final picked = <String>[];
    await openSheet(tester, currentVersion: 'cuvs-yhwh', onSelected: picked.add);
    await tester.tap(find.text('和合本雅伟版(简体)')); // the current one
    await tester.pumpAndSettle();
    expect(picked, isEmpty); // no redundant switch
    expect(find.text('选择圣经版本'), findsNothing);
  });

  testWidgets('no overflow on an iPad-sized viewport', (tester) async {
    await openSheet(tester,
        currentVersion: 'cuvs-yhwh-tr',
        onSelected: (_) {},
        size: const Size(1180, 820));
    expect(find.text('选择圣经版本'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
