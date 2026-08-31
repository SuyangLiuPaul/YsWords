// The strip that tells a running tab its build is out of date.
//
// Wrapped around the whole app in main.dart, so the thing worth pinning
// is that it costs NOTHING until the server actually moves — an
// always-app-wide widget that renders a stray gap, or an old version
// number, is a bug on every screen at once.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/web_update_checker.dart';
import 'package:yswords/widgets/update_banner.dart';

void main() {
  final checker = WebUpdateChecker.instance;

  setUp(() => checker.available.value = null);
  tearDown(() => checker.available.value = null);

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          home: const Scaffold(body: Center(child: Text('page body'))),
          builder: (context, child) => UpdateBanner(child: child!),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders nothing, and costs no height, while current',
      (tester) async {
    await pump(tester);
    expect(find.byType(FilledButton), findsNothing);

    // Invisible is not enough: this widget wraps every screen in the
    // app, so if it reserved even a few pixels it would shorten every
    // page forever. Measure the page itself, and prove the measurement
    // discriminates by raising the strip and watching the page shrink.
    final heightWhenCurrent = tester.getSize(find.byType(Scaffold)).height;
    final full = tester.getSize(find.byType(UpdateBanner)).height;
    expect(heightWhenCurrent, full,
        reason: 'the hidden strip is taking space from every page');

    checker.available.value = '9.9.9';
    await tester.pump();
    expect(tester.getSize(find.byType(Scaffold)).height,
        lessThan(heightWhenCurrent),
        reason: 'the shown strip took no space — the check above is vacuous');
  });

  testWidgets('appears, naming the version, when the server moves',
      (tester) async {
    await pump(tester);
    checker.available.value = '9.9.9';
    await tester.pump();
    // The version travels with the message so "it still says there's an
    // update" can be answered without guessing which build they mean.
    expect(find.textContaining('9.9.9'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('"Later" hides it without silencing the next version',
      (tester) async {
    await pump(tester);
    checker.available.value = '9.9.9';
    await tester.pump();
    expect(find.byType(FilledButton), findsOneWidget);

    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(find.byType(FilledButton), findsNothing,
        reason: 'dismiss did not hide the strip');

    // "Later" means not right now, NOT never again. A subsequent deploy
    // has to get through.
    checker.available.value = '9.9.10';
    await tester.pump();
    expect(find.textContaining('9.9.10'), findsOneWidget,
        reason: 'dismissing one version silenced every later one');
  });

  testWidgets('goes away on its own if the server comes back into line',
      (tester) async {
    await pump(tester);
    checker.available.value = '9.9.9';
    await tester.pump();
    expect(find.byType(FilledButton), findsOneWidget);
    checker.available.value = null;
    await tester.pump();
    expect(find.byType(FilledButton), findsNothing);
  });
}
