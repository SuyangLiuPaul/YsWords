import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/widgets/version_picker_sheet.dart';

/// 2026-06-22 v3: widget tests for `showLanguageGroupedVersionMenu`.
///
/// v3 is the safe rewrite of v1.3.100's crashing custom PopupMenuEntry —
/// it uses `showMenu` + a regular `PopupMenuItem(enabled: false)`
/// hosting a stateful body, so there's no PopupMenuEntry subclassing
/// (the Safari trigger).
void main() {
  Future<({AppSettings settings, Future<String?> future})> openMenu(
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
    Future<String?>? future;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  future = showLanguageGroupedVersionMenu(
                    context: ctx,
                    position: const RelativeRect.fromLTRB(120, 200, 80, 0),
                    currentVersion: currentVersion,
                    settings: settings,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (settings: settings, future: future!);
  }

  testWidgets('opens on the current version language + lists its editions',
      (tester) async {
    await openMenu(tester, currentVersion: 'cuvs-yhwh');
    // 2026-07-21: language tabs are now self-referential / locale-
    // independent (always 'English' / '繁體中文' / '简体中文',
    // matching Settings' own Interface Language dropdown) instead of
    // being translated into whatever the UI locale happens to be.
    expect(find.text('English'), findsOneWidget);
    expect(find.text('繁體中文'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);
    expect(find.text('和合本雅伟版(简体)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching language pill swaps the edition list',
      (tester) async {
    await openMenu(tester, currentVersion: 'cuvs-yhwh');
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('New American Standard Bible'), findsOneWidget);
    await tester.tap(find.text('繁體中文'));
    await tester.pumpAndSettle();
    expect(find.text('和合本雅伟版(繁體)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a different edition closes + returns its value',
      (tester) async {
    final r = await openMenu(tester, currentVersion: 'cuvs-yhwh');
    await tester.tap(find.text('梁家铿译本(简体)')); // biblexg-v2
    await tester.pumpAndSettle();
    expect(await r.future, 'biblexg-v2');
  });

  testWidgets('tapping the current edition closes with null', (tester) async {
    final r = await openMenu(tester, currentVersion: 'cuvs-yhwh');
    await tester.tap(find.text('和合本雅伟版(简体)'));
    await tester.pumpAndSettle();
    expect(await r.future, isNull);
  });

  testWidgets('no overflow on an iPad-sized viewport', (tester) async {
    await openMenu(tester,
        currentVersion: 'cuvs-yhwh-tr', size: const Size(1180, 820));
    expect(find.text('和合本雅伟版(繁體)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
