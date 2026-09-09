// 2026-09-09: whether the newest release is something this app can
// install, or only something it can link to.
//
// `release-android.yml` builds the APK in a job of its own and attaches
// it to the release in a later step, so for the minutes in between the
// latest release exists with no `.apk` asset at all — and
// `UpdateService.checkForUpdate` falls back to the release's HTML page
// as the download URL, which is right for a browser and useless to an
// installer. Handing that page to `AppUpdateInstaller` downloads a web
// page and reports 「更新没下载成功」, which reads as *this app's updater
// is broken* rather than *the build is still running*.
//
// `UpdateInfo.hasApk` is the one place that question is answered, and
// `canInstallInApp` in `update_check_tile.dart` is the only reader of
// it. These tests pin the answer; `update_check_tile_test.dart` pins
// what the two surfaces do with it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/services/update_service.dart';

UpdateInfo _info(String downloadUrl) => UpdateInfo(
      updateAvailable: true,
      currentVersion: '1.5.21',
      latestVersion: '1.5.22',
      downloadUrl: downloadUrl,
      releaseUrl: 'https://github.com/SuyangLiuPaul/YsWords/releases/latest',
    );

void main() {
  group('UpdateInfo.hasApk', () {
    test('a real release asset is installable', () {
      expect(
        _info('https://github.com/SuyangLiuPaul/YsWords/releases/download/'
                'v1.5.22/YsWords-Android-v1.5.22.apk')
            .hasApk,
        isTrue,
      );
    });

    test("the release's own page is not — this is the window while the "
        'Android job is still running', () {
      expect(
        _info('https://github.com/SuyangLiuPaul/YsWords/releases/tag/v1.5.22')
            .hasApk,
        isFalse,
      );
      expect(
        _info('https://github.com/SuyangLiuPaul/YsWords/releases/latest')
            .hasApk,
        isFalse,
      );
    });

    test('a query string cannot smuggle the extension past it', () {
      expect(_info('https://example.invalid/release?file=app.apk').hasApk,
          isFalse,
          reason: 'the PATH decides; a name in the query is a page that '
              'merely mentions an APK');
      expect(_info('https://example.invalid/app.apk?token=abc').hasApk, isTrue,
          reason: 'a signed asset URL is still an asset');
    });

    test('the extension is matched case-insensitively', () {
      expect(_info('https://example.invalid/YsWords-Android.APK').hasApk,
          isTrue);
    });

    test('nothing at all is not an APK', () {
      expect(_info('').hasApk, isFalse);
    });
  });

  // 2026-09-09 (remediation, reviewer 2's finding 3). In a repo this
  // strict about dated, reasoned headers, a header describing a route
  // the app stopped taking on its main platform is worse than no header
  // — it is the first thing the next reader believes.
  group("the file's own header", () {
    final source = File('lib/services/update_service.dart').readAsStringSync();
    final header = source.substring(0, source.indexOf("import 'dart:convert'"));

    test('no longer says the browser is what happens next', () {
      expect(header.contains('opens that URL via `LinkOpener`'), isFalse,
          reason: 'that sentence was written when every platform went out '
              'to the browser; Android stopped on 2026-09-09 and this '
              'patch removed the last LinkOpener-primary path on it');
    });

    test('names the route that replaced it, and the gate on it', () {
      expect(header.contains('AppUpdateInstaller'), isTrue);
      expect(header.contains('hasApk'), isTrue,
          reason: 'the in-app route is conditional, and the condition is '
              'declared 25 lines below this header');
    });
  });
}
