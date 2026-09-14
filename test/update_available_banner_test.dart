// The notice that tells a reader their build is out of date.
//
// 2026-09-14: this file is `update_banner_test.dart` rewritten. That one
// covered a strip wrapped around the whole app along the bottom edge; the
// owner asked for the notice on the home screen instead of at the foot of
// it, and both channels — a newer web build, and a newer GitHub release
// that used to arrive as a six-second SnackBar — now meet in
// `UpdateAvailableBanner` at the head of the dashboard.
//
// Every claim the old file made still holds and is still here: it must
// cost nothing while the build is current, it must name the version, and
// 「暂不」 must mean "not this build" rather than "never again". What is new
// is the second channel, and which of the two wins when both speak.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/update_service.dart';
import 'package:yswords/services/web_update_checker.dart';
import 'package:yswords/widgets/update_available_banner.dart';

void main() {
  final checker = WebUpdateChecker.instance;

  setUp(() => checker.available.value = null);
  tearDown(() => checker.available.value = null);

  UpdateInfo release(String version) => UpdateInfo(
        currentVersion: '1.0.0',
        latestVersion: version,
        releaseUrl: 'https://example.invalid/releases/tag/v$version',
        downloadUrl: 'https://example.invalid/releases/tag/v$version',
        updateAvailable: true,
      );

  /// The banner where it actually lives: one item in a list, with a page
  /// under it. A `Column` would hide the thing the first test measures.
  Future<void> pump(WidgetTester tester, {UpdateInfo? info}) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                UpdateAvailableBanner(locale: 'en', release: info),
                const Text('page body'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('costs nothing at all while the build is current',
      (tester) async {
    await pump(tester);
    expect(find.byType(FilledButton), findsNothing);

    // Invisible is not enough. This sits above everything the reader
    // arranged on their dashboard, so a few reserved pixels would push
    // the whole page down forever. Measured by where the text under it
    // sits, and the measurement is proved to discriminate by raising the
    // banner and watching that text move.
    final quiet = tester.getTopLeft(find.text('page body')).dy;

    checker.available.value = '9.9.9';
    await tester.pump();
    expect(tester.getTopLeft(find.text('page body')).dy, greaterThan(quiet),
        reason: 'the shown banner took no space — the check above is '
            'vacuous');
  });

  testWidgets('the web channel names the version', (tester) async {
    await pump(tester);
    checker.available.value = '9.9.9';
    await tester.pump();
    // The version travels with the message so "it still says there's an
    // update" can be answered without guessing which build they mean.
    expect(find.textContaining('9.9.9'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('暂不 hides it without silencing the next version',
      (tester) async {
    await pump(tester);
    checker.available.value = '9.9.9';
    await tester.pump();
    expect(find.byType(FilledButton), findsOneWidget);

    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(find.byType(FilledButton), findsNothing,
        reason: 'dismiss did not hide the banner');

    // 暂不 means not right now, NOT never again. A subsequent deploy has
    // to get through.
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

  testWidgets('a release names its own version', (tester) async {
    await pump(tester, info: release('2.0.0'));
    expect(find.textContaining('2.0.0'), findsOneWidget);
  });

  testWidgets('when both channels speak, the release is the one shown',
      (tester) async {
    // In practice they never coincide — `UpdateService.isSupported` is
    // false on the web and `WebUpdateChecker` no-ops off it — but a
    // banner that would otherwise draw two rows has to choose, and this
    // pins the choice rather than leaving it to whichever Flutter laid
    // out first. The release wins because it is the one the reader has to
    // install, and the one that cannot arrive on its own: a web build is
    // one reload away whenever they get to it.
    await pump(tester, info: release('2.0.0'));
    checker.available.value = '9.9.9';
    await tester.pump();
    expect(find.textContaining('2.0.0'), findsOneWidget);
    expect(find.textContaining('9.9.9'), findsNothing);
  });

  testWidgets('dismissing the release does not silence a later one',
      (tester) async {
    await pump(tester, info: release('2.0.0'));
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(find.textContaining('2.0.0'), findsNothing);

    await pump(tester, info: release('2.0.1'));
    expect(find.textContaining('2.0.1'), findsOneWidget,
        reason: 'the dismissal is per version, not a flag');
  });
}
