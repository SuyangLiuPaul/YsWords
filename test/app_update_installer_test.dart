// The in-app updater's download, which is the half that can lie.
//
// Handing the file to Android is one `startActivity` and cannot be
// tested off a device. Everything BEFORE that can, and is where the
// failures live: a captive-portal login page and a real APK both
// arrive with a 200, and a truncated download and a complete one look
// identical to a progress bar. Android's response to being given
// either is "There was a problem parsing the package", which the
// reader reads as *this app is broken*.
//
// `AppUpdateInstaller.isSupported` reads `defaultTargetPlatform`
// precisely so this file can exist; see the comment on it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;

import 'package:yswords/services/app_update_installer.dart';

/// A real APK's first bytes, followed by filler. Only the magic is
/// checked, so nothing here has to be a valid archive.
Uint8List _apkBytes([int length = 64]) => Uint8List.fromList(
      <int>[...kZipMagic, ...List<int>.filled(length - kZipMagic.length, 7)],
    );

/// What a hotel wifi hands back instead of the file.
final Uint8List _loginPage =
    Uint8List.fromList(utf8.encode('<html><body>Sign in</body></html>'));

/// Serves [body], declaring [declaredLength] bytes.
///
/// **Streaming, and that is the whole reason this helper exists.**
/// `http.Response.bytes` computes its own `contentLength` from the
/// body it was given and ignores a `content-length` header set beside
/// it — so a mock built that way can never produce the case this file
/// most needs, a server that promises more than it delivers. Two tests
/// silently passed against nothing before this was noticed.
///
/// `declaredLength` is a sentinel-free `Object?`: omit it for the
/// truth, pass `null` for a server that declares no length at all.
http.Client _serving(
  Uint8List body, {
  Object? declaredLength = _truth,
  int status = 200,
}) =>
    MockClient.streaming((request, _) async => http.StreamedResponse(
          Stream<List<int>>.value(body),
          status,
          contentLength: identical(declaredLength, _truth)
              ? body.length
              : declaredLength as int?,
        ));

/// Marks "no argument passed", so `declaredLength: null` can mean a
/// server that sent no `Content-Length` rather than a default.
const Object _truth = Object();

void main() {
  _doors();
  late Directory dir;
  late List<MethodCall> calls;
  bool permitted = true;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    dir = await Directory.systemTemp.createTemp('update_test');
    calls = <MethodCall>[];
    permitted = true;
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
        }
        return null;
      },
    );
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('yswords/apk_installer'), null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File downloaded() => File('${dir.path}/update.apk');

  group('what reaches the installer', () {
    test('a complete APK is written and handed over', () async {
      final outcome = await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_apkBytes()),
      );
      expect(outcome, UpdateInstallOutcome.launched);
      expect(downloaded().existsSync(), isTrue);
      final install = calls.firstWhere((c) => c.method == 'install');
      expect((install.arguments as Map)['path'], downloaded().path);
    });

    test(
        'a login page with a 200 and an honest length is refused — this is '
        'the captive-portal case, and Android would call it a corrupt package',
        () async {
      final outcome = await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_loginPage),
      );
      expect(outcome, UpdateInstallOutcome.downloadFailed);
      expect(calls.any((c) => c.method == 'install'), isFalse);
    });

    test('a truncated download is refused even though it starts like an APK',
        () async {
      final outcome = await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_apkBytes(), declaredLength: 4096),
      );
      expect(outcome, UpdateInstallOutcome.downloadFailed);
      expect(calls.any((c) => c.method == 'install'), isFalse);
    });

    test('a refused download leaves nothing behind — a cache holding most of '
        'a 90 MB APK is the reason to check', () async {
      await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_loginPage),
      );
      expect(downloaded().existsSync(), isFalse);
    });

    test('a 404 never becomes a file', () async {
      final outcome = await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_apkBytes(), status: 404),
      );
      expect(outcome, UpdateInstallOutcome.downloadFailed);
      expect(downloaded().existsSync(), isFalse);
    });
  });

  group('the permission the reader has not given yet', () {
    test('is reported as its own outcome, not as a failure — it is the '
        'ordinary first run and the UI sends them to the OS switch',
        () async {
      permitted = false;
      final outcome = await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_apkBytes()),
      );
      expect(outcome, UpdateInstallOutcome.permissionNeeded);
      // And nothing was downloaded: asking first is the point.
      expect(calls.any((c) => c.method == 'updateDir'), isFalse);
      expect(downloaded().existsSync(), isFalse);
    });
  });

  group('which platforms get a button at all', () {
    test('iOS does not — an app cannot install an app, and a button that '
        'said otherwise would have to apologise', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(AppUpdateInstaller.isSupported, isFalse);
      expect(
        await AppUpdateInstaller.downloadAndInstall('https://example.invalid/a'),
        UpdateInstallOutcome.unsupported,
      );
    });

    test('the desktops do not — replacing a running application is the '
        'platform’s business', () async {
      for (final p in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = p;
        expect(AppUpdateInstaller.isSupported, isFalse, reason: '$p');
      }
    });

    test('Android does', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AppUpdateInstaller.isSupported, isTrue);
    });
  });

  group('progress', () {
    test('reports a fraction when the server declared a length', () async {
      final seen = <double?>[];
      await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_apkBytes(128)),
        onProgress: seen.add,
      );
      expect(seen, isNotEmpty);
      expect(seen.last, 1.0);
      expect(seen.every((f) => f != null && f >= 0 && f <= 1), isTrue);
    });

    test('reports null rather than inventing a denominator when it did not',
        () async {
      final seen = <double?>[];
      await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_apkBytes(), declaredLength: null),
        onProgress: seen.add,
      );
      expect(seen, isNotEmpty);
      expect(seen.every((f) => f == null), isTrue,
          reason: 'a bar that guesses is worse than one that admits it');
    });
  });
}

// ---------------------------------------------------------------------
// Where the reader can find the controls.
//
// The owner reported 「word也没有选项每天check更新的」 while the switch
// was already written, mounted, and working — in the About page, which
// is not where Sword keeps it and not where they looked. A widget that
// exists and cannot be found is indistinguishable from one that does
// not exist, so what is pinned here is the DOOR, not the switch.

void _doors() {
  group('the reader can reach the update controls', () {
    final settings = File('lib/pages/settings_page.dart').readAsStringSync();
    final about = File('lib/pages/about_page.dart').readAsStringSync();

    test('Settings mounts them, which is where Sword keeps them and where '
        'the owner went looking', () {
      expect(settings.contains('UpdateCheckTile('), isTrue);
      expect(settings.contains('AutoUpdateCheckToggle('), isTrue);
    });

    test('About keeps them too — it is beside the version number, which is '
        'the other place the question gets asked', () {
      expect(about.contains('UpdateCheckTile('), isTrue);
      expect(about.contains('AutoUpdateCheckToggle('), isTrue);
    });

    test('both are behind the platform gate, so the web is not shown a '
        'daily switch over a build the server decides', () {
      expect(settings.contains('UpdateService.isSupported'), isTrue);
    });
  });
}
