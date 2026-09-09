// 2026-09-09: the in-app install's dialogs, and the doors into them.
//
// `app_update_installer_test.dart` covers what reaches Android. This
// covers what reaches the READER — the progress dialog that must
// survive the Back button and yield to Stop, the second tap that must
// not start a second download, the permission trip that must carry on
// by itself, the paragraph that must not describe a browser trip over
// a button that installs in place, and the dashboard's daily bar that
// must run the same flow as the About page. Each was a review finding
// on 2026-09-09; the group comments say which.
//
// The download is real file IO, so those tests run inside
// `tester.runAsync`, holding the response stream open by hand to keep
// the dialog on screen long enough to look at.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/app_update_installer.dart';
import 'package:yswords/services/update_service.dart';
import 'package:yswords/widgets/update_check_tile.dart';

const _hint = 'Android will ask you to confirm the install.';
const _downloading = 'Downloading update…';
const _failed = "Couldn't download the update";

Uint8List _apkBytes(int length) => Uint8List.fromList(
      <int>[...kZipMagic, ...List<int>.filled(length - kZipMagic.length, 7)],
    );

UpdateInfo _info({String downloadUrl = 'https://example.invalid/app.apk'}) =>
    UpdateInfo(
      updateAvailable: true,
      currentVersion: '1.5.21',
      latestVersion: '1.5.22',
      downloadUrl: downloadUrl,
      releaseUrl: 'https://example.invalid/releases/v1.5.22',
    );

/// A response whose body the test feeds by hand, so the dialog stays up
/// until the test says otherwise.
http.Client _held(StreamController<List<int>> body, {int length = 64}) =>
    MockClient.streaming((request, _) async =>
        http.StreamedResponse(body.stream, 200, contentLength: length));

/// A complete APK, served at once.
http.Client _complete() => MockClient.streaming((request, _) async =>
    http.StreamedResponse(Stream.value(_apkBytes(64)), 200,
        contentLength: 64));

/// What the Android Back button sends. `handlePopRoute` itself is
/// `@protected`; the platform message is the honest way in, and is
/// exactly what the OS does.
Future<void> _pressBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    SystemChannels.navigation.codec
        .encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
}

/// `testWidgets` with the platform override set for the body and
/// restored before the binding checks its invariants — which it does
/// BEFORE `tearDown`, so a reset there would be too late.
void _onPlatform(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  TargetPlatform platform = TargetPlatform.android,
}) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

/// Pump frames (and let real IO breathe) until [ready] is true.
Future<void> _until(
  WidgetTester tester,
  bool Function() ready, {
  String what = 'condition',
}) async {
  for (var i = 0; i < 200; i++) {
    if (ready()) return;
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('timed out waiting for $what');
}

void main() {
  late Directory dir;
  late List<MethodCall> calls;
  late bool permitted;
  late String? packageId;
  late bool permissionNeverAnswers;
  late BuildContext host;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    updateInstallInProgress.value = false;
    dir = await Directory.systemTemp.createTemp('update_tile_test');
    calls = <MethodCall>[];
    permitted = true;
    packageId = AppUpdateInstaller.kReleasePackage;
    permissionNeverAnswers = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('yswords/apk_installer'),
      (call) async {
        calls.add(call);
        switch (call.method) {
          case 'canInstall':
            return permitted;
          case 'updateDir':
            return dir.path;
          case 'install':
            return true;
          case 'packageName':
            return packageId;
          case 'requestPermission':
            if (permissionNeverAnswers) {
              // The Activity that parked this reply was destroyed while
              // the reader was in Settings. Nobody will ever answer it.
              return Completer<bool>().future;
            }
            // The reader turned the switch on and came back.
            permitted = true;
            return true;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    updateInstallInProgress.value = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('yswords/apk_installer'), null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File downloaded() => File('${dir.path}/update.apk');
  int count(String method) => calls.where((c) => c.method == method).length;

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (ctx) {
          host = ctx;
          return const SizedBox.shrink();
        }),
      ),
    ));
  }

  group('the progress dialog (findings 1, 2 and 6)', () {
    _onPlatform(
        'survives the Back button, ignores a second Update now, shows the '
        'hint beside the percentage, and stops when told to', (tester) async {
      await pumpHost(tester);
      await tester.runAsync(() async {
        final body = StreamController<List<int>>();
        final client = _held(body);
        final info = _info();
        final pending =
            installUpdateInApp(host, info, locale: 'en', client: client);
        await _until(
            tester, () => find.text(_downloading).evaluate().isNotEmpty,
            what: 'progress dialog');

        // Half the file: a known length, so the bar has a percentage —
        // which is the case in which the hint used to vanish.
        body.add(_apkBytes(32));
        await _until(tester, () => find.text('50%').evaluate().isNotEmpty,
            what: '50%');
        expect(find.text(_hint), findsOneWidget,
            reason: 'GitHub always sends a Content-Length, so a hint '
                'shown only without one is shown to nobody');

        // Android Back: the dialog must stay, because the download does.
        await _pressBack(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(_downloading), findsOneWidget,
            reason: 'Back used to dismiss the dialog and leave the '
                'download running unseen');

        // A second "Update now" while this one runs is a no-op — not a
        // second dialog, and not a second write stream on update.apk.
        unawaited(installUpdateInApp(host, info, locale: 'en', client: client));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(_downloading), findsOneWidget);
        expect(count('updateDir'), 1);

        // Stop: the dialog closes, the partial file goes, and nobody is
        // told the download "failed".
        await tester.tap(find.text('Stop download'));
        await _until(tester, () => find.text(_downloading).evaluate().isEmpty,
            what: 'dialog to close');
        await pending.timeout(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(_failed), findsNothing);
        expect(downloaded().existsSync(), isFalse);
        expect(count('install'), 0);
        expect(updateInstallInProgress.value, isFalse);
        await body.close();
      });
    });
  });

  group('the permission trip (finding 4)', () {
    _onPlatform(
        'carries on by itself when the reader comes back with the switch '
        'on — there is no Update button on the screen they return to',
        (tester) async {
      permitted = false;
      await pumpHost(tester);
      await tester.runAsync(() async {
        final pending = installUpdateInApp(host, _info(),
            locale: 'en', client: _complete());
        await _until(
            tester,
            () => find.text('Allow installing updates').evaluate().isNotEmpty,
            what: 'permission dialog');
        expect(find.textContaining('continues when you come back'),
            findsOneWidget,
            reason: 'the copy must not ask for a press of a button that '
                'is not there');
        expect(count('install'), 0);

        await tester.tap(find.text('Open settings'));
        await _until(tester, () => count('install') == 1,
            what: 'the install intent after returning from settings');
        expect(count('requestPermission'), 1);
        await pending.timeout(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(_downloading), findsNothing);
        expect(find.text(_failed), findsNothing);
      });
    });

    // 2026-09-09 (remediation, review finding 1). The failure this pins
    // is not a hang the reader watches — it is a hang they never see,
    // followed by a button that silently stops working forever.
    _onPlatform(
        'a reply that never comes does not latch 「立即更新」 off for the '
        'life of the process', (tester) async {
      permitted = false;
      permissionNeverAnswers = true;
      await pumpHost(tester);
      await tester.runAsync(() async {
        final info = _info();
        final pending = installUpdateInApp(host, info,
            locale: 'en',
            client: _complete(),
            permissionTimeout: const Duration(milliseconds: 50));
        await _until(
            tester,
            () => find.text('Allow installing updates').evaluate().isNotEmpty,
            what: 'permission dialog');
        await tester.tap(find.text('Open settings'));

        // The reader is now in Settings and Android has destroyed the
        // Activity that parked the reply. Before the fix this future
        // never completed and the latch below stayed true.
        await pending.timeout(
          const Duration(seconds: 5),
          onTimeout: () => fail('installUpdateInApp never returned — the '
              'orphaned MethodChannel.Result'),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(updateInstallInProgress.value, isFalse,
            reason: 'a latch nothing can clear disables the button on '
                'BOTH surfaces, with no dialog, no snackbar and no way '
                'back short of killing the app');

        // And the proof that it is only a latch: the very next tap
        // works. (Permission is granted this time, as it would be for a
        // reader who did turn the switch on.)
        permissionNeverAnswers = false;
        permitted = true;
        await installUpdateInApp(host, info, locale: 'en', client: _complete())
            .timeout(const Duration(seconds: 5));
        expect(count('install'), 1,
            reason: 'the second attempt must actually run, not return at '
                'the re-entrancy guard');
      });
    });

    _onPlatform('a reader who declines is not told the update failed',
        (tester) async {
      permitted = false;
      await pumpHost(tester);
      await tester.runAsync(() async {
        final pending = installUpdateInApp(host, _info(),
            locale: 'en', client: _complete());
        await _until(
            tester,
            () => find.text('Allow installing updates').evaluate().isNotEmpty,
            what: 'permission dialog');
        await tester.tap(find.text('Cancel'));
        await pending.timeout(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 400));
        expect(count('requestPermission'), 0);
        expect(find.text(_failed), findsNothing,
            reason: 'a switch nobody has turned on yet is the ordinary '
                'first run, not a failure of this app');
      });
    });
  });

  group('the "Update available" dialog (finding 5)', () {
    _onPlatform(
        'offers Update now with the Android body when the release has an APK',
        (tester) async {
      await pumpHost(tester);
      await showUpdateAvailableDialog(host, _info(), locale: 'en');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Update now'), findsOneWidget);
      expect(find.textContaining('downloads and installs it here'),
          findsOneWidget);
      expect(find.textContaining('desktop unzips'), findsNothing,
          reason: 'a phone is not told about desktops and iOS above a '
              'button that installs in place');
    });

    _onPlatform('offers only the browser when the release has no APK yet',
        (tester) async {
      await pumpHost(tester);
      await showUpdateAvailableDialog(
        host,
        _info(downloadUrl: 'https://example.invalid/releases/v1.5.22'),
        locale: 'en',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Update now'), findsNothing,
          reason: 'release-android.yml attaches the APK minutes after the '
              'release exists; the button would have downloaded an HTML '
              'page and reported "didn\'t download"');
      expect(find.text('Open in browser'), findsNothing,
          reason: '"Open in browser" is the name of a SECOND choice, and '
              'in this window it is the only button on the dialog — and '
              'the dashboard called the identical state "Download"');
      expect(find.text('Download'), findsOneWidget);
      expect(find.textContaining('desktop unzips'), findsOneWidget);
    });

    // 2026-09-09 (remediation): the two doors must not disagree about
    // the same release on the same device.
    _onPlatform('labels its browser button the same as the dashboard bar '
        'labels its action, in every state', (tester) async {
      await pumpHost(tester);
      for (final info in [
        _info(),
        _info(downloadUrl: 'https://example.invalid/releases/v1.5.22'),
      ]) {
        final bar = await buildUpdateAvailableBar(host, info, locale: 'en');
        await showUpdateAvailableDialog(host, info, locale: 'en');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final inApp = find.text('Update now').evaluate().isNotEmpty;
        expect(bar.action?.label, inApp ? 'Update now' : 'Download',
            reason: info.downloadUrl);
        expect(find.text(inApp ? 'Open in browser' : 'Download'),
            findsOneWidget,
            reason: info.downloadUrl);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }
    });

    _onPlatform('a .cn build is offered the browser, not a button that '
        'would install a second app beside this one', (tester) async {
      packageId = 'com.example.yswords.cn';
      await pumpHost(tester);
      await showUpdateAvailableDialog(host, _info(), locale: 'en');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Update now'), findsNothing,
          reason: 'release-android.yml only ever attaches the intl APK, '
              'whose applicationId is not this build\'s — Android would '
              'install it alongside rather than over');
      expect(find.text('Download'), findsOneWidget);
      final bar = await buildUpdateAvailableBar(host, _info(), locale: 'en');
      expect(bar.action?.label, 'Download');
    });

    _onPlatform('never offers Update now off Android, APK or not',
        platform: TargetPlatform.iOS, (tester) async {
      await pumpHost(tester);
      await showUpdateAvailableDialog(host, _info(), locale: 'en');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Update now'), findsNothing);
      expect(find.text('Download'), findsOneWidget);
      expect(find.textContaining('desktop unzips'), findsOneWidget);
    });
  });

  group('the dashboard\'s daily bar (finding 7)', () {
    _onPlatform('its action on Android with an APK is the in-app install',
        (tester) async {
      await pumpHost(tester);
      final bar = await buildUpdateAvailableBar(host, _info(), locale: 'en');
      expect(bar.action?.label, 'Update now',
          reason: 'the bar used to hand the URL to the browser, so the '
              'one surface nearly every reader meets was the one still '
              'asking them to go and find a file');
    });

    _onPlatform('with no APK it falls back to the browser rather than '
        'downloading a web page', (tester) async {
      await pumpHost(tester);
      final bar = await buildUpdateAvailableBar(
        host,
        _info(downloadUrl: 'https://example.invalid/releases/v1.5.22'),
        locale: 'en',
      );
      expect(bar.action?.label, 'Download');
    });

    _onPlatform('off Android it is the browser too',
        platform: TargetPlatform.iOS, (tester) async {
      await pumpHost(tester);
      final bar = await buildUpdateAvailableBar(host, _info(), locale: 'en');
      expect(bar.action?.label, 'Download');
    });

    _onPlatform('tapping it runs the same flow as the About page',
        (tester) async {
      await pumpHost(tester);
      final body = StreamController<List<int>>();
      await tester.runAsync(() async {
        ScaffoldMessenger.of(host).showSnackBar(
          await buildUpdateAvailableBar(host, _info(),
              locale: 'en', client: _held(body)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Version v1.5.22 is available'), findsOneWidget);

        await tester.tap(find.text('Update now'));
        await _until(
            tester, () => find.text(_downloading).evaluate().isNotEmpty,
            what: 'progress dialog from the bar');
        expect(count('updateDir'), 1);

        await tester.tap(find.text('Stop download'));
        await _until(tester, () => find.text(_downloading).evaluate().isEmpty,
            what: 'dialog to close');
        await _until(tester, () => !updateInstallInProgress.value,
            what: 'the flow to finish');
        await body.close();
      });
      ScaffoldMessenger.of(host).removeCurrentSnackBar();
      await tester.pumpAndSettle();
    });

    test('the dashboard actually calls it — the fix is the wiring, not the '
        'function', () {
      final source = File('lib/pages/dashboard_page.dart').readAsStringSync();
      expect(source.contains('buildUpdateAvailableBar('), isTrue,
          reason: 'the daily bar must be built beside the About dialog, '
              'or the two doors drift apart again');
      expect(source.contains('LinkOpener.open(info.downloadUrl)'), isFalse,
          reason: 'the old browser-only action must be gone, not merely '
              'shadowed by a new one');
    });
  });

  // 2026-09-09 (remediation, review finding 2): the entry point was the
  // one context use in the file that was not `mounted`-guarded, and the
  // dashboard bar is the caller that can reach it defunct — a
  // SnackBarAction lives on the app-level ScaffoldMessenger and outlives
  // the route that built it.
  group('a button pressed after its page is gone', () {
    _onPlatform('does nothing, rather than throwing inside an unawaited '
        'future', (tester) async {
      await pumpHost(tester);
      final gone = host;
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      expect(gone.mounted, isFalse, reason: 'the premise of the test');
      await installUpdateInApp(gone, _info(),
          locale: 'en', client: _complete());
      expect(count('updateDir'), 0);
      expect(updateInstallInProgress.value, isFalse);
    });
  });

  group('the strings (finding 8, and the new keys)', () {
    test('the zh-Hant permission copy names the switch as Android’s zh-TW '
        'build names it', () {
      final body = uiStrings['updatePermissionBody']!['zh-Hant']!;
      expect(body, contains('安裝不明應用程式'));
      expect(body, isNot(contains('未知應用')),
          reason: '「安裝未知應用」 is the Simplified wording with the '
              'characters swapped; a Traditional reader would hunt the '
              'settings screen for it and never find a match');
    });

    test('the permission copy no longer asks for a button that is not on '
        'screen', () {
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        final body = uiStrings['updatePermissionBody']![locale]!;
        expect(body, isNot(contains('再按一次')), reason: locale);
        expect(body, isNot(contains('press Update')), reason: locale);
      }
    });

    test('Stop has its own key rather than borrowing 取消', () {
      expect(uiStrings['updateCancelDownload'], isNotNull);
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expect(uiStrings['updateCancelDownload']![locale],
            isNot(uiStrings['cancel']![locale]),
            reason: '$locale: stopping a running download is not '
                'declining an offer');
      }
    });

    test('every new key has all three locales, filled in', () {
      for (final key in [
        'updateAvailableBodyAndroid',
        'updateCancelDownload',
        'updateDownloadingHint',
        'updatePermissionBody',
      ]) {
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(uiStrings[key]?[locale], isNotNull, reason: '$key/$locale');
          expect(uiStrings[key]![locale]!.trim(), isNotEmpty,
              reason: '$key/$locale');
        }
      }
    });

    test('the Android body keeps both placeholders, in all three locales',
        () {
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        final body = uiStrings['updateAvailableBodyAndroid']![locale]!;
        expect(body, contains('{new}'), reason: locale);
        expect(body, contains('{cur}'), reason: locale);
      }
    });

    // 2026-09-09 (remediation, reviewer 2's finding 2): the localisation
    // stopped one key short of the title beside it.
    test('the permission dialog speaks ONE zh-Hant, not two — 本應用程式 in '
        'the body and 本應用 in the title above it is one AlertDialog with '
        'two words for the same thing', () {
      final title = uiStrings['updatePermissionTitle']!['zh-Hant']!;
      final body = uiStrings['updatePermissionBody']!['zh-Hant']!;
      for (final entry in {'title': title, 'body': body}.entries) {
        expect(entry.value, contains('本應用程式'), reason: entry.key);
        expect(RegExp('本應用(?!程式)').hasMatch(entry.value), isFalse,
            reason: '${entry.key}: 「本應用」 is the Simplified 「本应用」 with '
                'the characters swapped, not Taiwan/HK vocabulary');
      }
    });

    test('and the flow spells the release word one way, in the bar and in '
        'both dialog bodies a reader sees one after the other', () {
      for (final key in [
        'updateAvailableBar',
        'updateAvailableBody',
        'updateAvailableBodyAndroid',
      ]) {
        final value = uiStrings[key]!['zh-Hant']!;
        expect(value, contains('已發佈'), reason: key);
        expect(value, isNot(contains('已發布')), reason: key);
      }
    });

    test('zh-Hant says 點擊, as the other thirty values in the file do', () {
      expect(uiStrings['updateAvailableBodyAndroid']!['zh-Hant']!,
          contains('點擊「立即更新」'),
          reason: 'bare 點 is the Simplified register');
    });

    // 2026-09-09 (remediation, reviewer 2's finding 1): ui_strings.dart
    // states its own append-only rule three times, and says why —
    // several sessions edit this file at once and a key dropped into the
    // middle of an 8,000-line map is a merge conflict with no readable
    // diff. These two keys first landed at lines 4120 and 4205.
    test('the two NEW keys were appended at the end, not interleaved four '
        'thousand lines up', () {
      final source =
          File('lib/constants/ui_strings.dart').readAsStringSync();
      // The last update string added under the convention, in the
      // 2026-09-08 "Daily update check" block. Anything appended after
      // this patch must sit below it.
      final anchor = source.indexOf("'updateAvailableBar':");
      expect(anchor, greaterThan(-1));
      for (final key in [
        "'updateAvailableBodyAndroid':",
        "'updateCancelDownload':",
      ]) {
        expect(source.indexOf(key), greaterThan(anchor), reason: key);
      }
      // Contiguous, as the convention's own word says: one block, not
      // two keys scattered below the line.
      final a = source.indexOf("'updateAvailableBodyAndroid':");
      final b = source.indexOf("'updateCancelDownload':");
      expect((a - b).abs(), lessThan(1200),
          reason: 'appended as ONE block, per the rule the three blocks '
              'above it state');
    });

    test('the EDIT stays where the key already lived — an edit in place is '
        'a diff a reviewer can read', () {
      final source =
          File('lib/constants/ui_strings.dart').readAsStringSync();
      expect(source.indexOf("'updatePermissionBody':"),
          lessThan(source.indexOf("'updateAvailableBar':")),
          reason: 'the append-only rule is about INSERTS; moving an '
              'edited key would be the reordering it exists to prevent');
    });
  });
}
