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

import 'dart:async';
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
  String? packageId;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    dir = await Directory.systemTemp.createTemp('update_test');
    calls = <MethodCall>[];
    permitted = true;
    // The build the release APK is actually for. Overridden per test to
    // stand in for the `cn` flavour, which runs as
    // `com.example.yswords.cn` and must never be handed this APK.
    packageId = AppUpdateInstaller.kReleasePackage;
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
            // The platform side answers when the reader comes BACK from
            // the settings screen, with the switch's state at that
            // moment — see MainActivity.answerPendingPermission.
            permitted = true;
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

  // 2026-09-09 (review finding 1): the reader's Stop button. Until this
  // the progress dialog had no button at all, so the only way out was
  // Android's Back — which hid the dialog and left the download running.
  group('cancelling', () {
    test('mid-download stops the read, discards the partial file and is '
        'its own outcome — not a failure the UI would apologise for',
        () async {
      final body = StreamController<List<int>>();
      final token = UpdateCancelToken();
      final client = MockClient.streaming((request, _) async =>
          http.StreamedResponse(body.stream, 200, contentLength: 4096));
      final seen = <double?>[];
      final pending = AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: client,
        cancelToken: token,
        onProgress: seen.add,
      );
      // Half the file arrives, then the reader presses Stop. The stream
      // is deliberately never closed: a cancel that only took effect at
      // the next chunk would hang here, which is exactly the bug.
      body.add(_apkBytes(2048));
      while (seen.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      token.cancel();
      final outcome = await pending.timeout(const Duration(seconds: 5));
      expect(outcome, UpdateInstallOutcome.cancelled);
      expect(downloaded().existsSync(), isFalse);
      expect(calls.any((c) => c.method == 'install'), isFalse);
      await body.close();
    });

    test('before the connect answers returns at once, not after the '
        'connect timeout', () async {
      final never = Completer<http.StreamedResponse>();
      final token = UpdateCancelToken();
      final client = MockClient.streaming((request, _) => never.future);
      final pending = AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: client,
        cancelToken: token,
        connectTimeout: const Duration(hours: 1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      token.cancel();
      expect(
        await pending.timeout(const Duration(seconds: 5)),
        UpdateInstallOutcome.cancelled,
      );
    });

    test('a token cancelled before the call downloads nothing', () async {
      final token = UpdateCancelToken()..cancel();
      final outcome = await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_apkBytes()),
        cancelToken: token,
      );
      expect(outcome, UpdateInstallOutcome.cancelled);
      expect(calls.any((c) => c.method == 'updateDir'), isFalse);
    });
  });

  // 2026-09-09 (review finding 3): a network that stops without saying
  // so used to freeze the progress dialog forever. `checkForUpdate` has
  // had a 10-second timeout since v1.3.88; the DOWNLOAD had none.
  group('a connection that stalls', () {
    test('after some bytes is given up at the idle timeout, and the '
        'partial file with it', () async {
      final body = StreamController<List<int>>();
      final client = MockClient.streaming((request, _) async =>
          http.StreamedResponse(body.stream, 200, contentLength: 4096));
      final pending = AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: client,
        idleTimeout: const Duration(milliseconds: 50),
      );
      body.add(_apkBytes(2048));
      // The rest never comes.
      final outcome = await pending.timeout(const Duration(seconds: 5));
      expect(outcome, UpdateInstallOutcome.downloadFailed);
      expect(downloaded().existsSync(), isFalse);
      await body.close();
    });

    test('before the headers is given up at the connect timeout', () async {
      final never = Completer<http.StreamedResponse>();
      final client = MockClient.streaming((request, _) => never.future);
      final outcome = await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: client,
        connectTimeout: const Duration(milliseconds: 50),
      ).timeout(const Duration(seconds: 5));
      expect(outcome, UpdateInstallOutcome.downloadFailed);
      expect(downloaded().existsSync(), isFalse);
    });

    test('the shipped defaults are finite, so a real device cannot hang '
        'on a dialog with one button', () {
      expect(AppUpdateInstaller.defaultIdleTimeout,
          lessThanOrEqualTo(const Duration(minutes: 1)));
      expect(AppUpdateInstaller.defaultConnectTimeout,
          lessThanOrEqualTo(const Duration(minutes: 1)));
    });
  });

  // 2026-09-09 (review finding 4): the trip to settings now reports how
  // it ENDED, so the caller can carry on without another tap on a button
  // that is no longer on screen.
  group('requestPermission', () {
    test('returns what the platform side saw on the way back', () async {
      permitted = false;
      expect(await AppUpdateInstaller.requestPermission(), isTrue);
      expect(await AppUpdateInstaller.canInstall(), isTrue);
    });

    test('is false off Android rather than a silent no-op', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await AppUpdateInstaller.requestPermission(), isFalse);
      expect(calls, isEmpty);
    });
  });

  // 2026-09-09 (remediation, review finding 1): the reply that never
  // arrives. This is the Mi Pad case and it is not theoretical — the
  // header of MainActivity.kt was written about that device. The reader
  // is in Settings; Android destroys the Activity behind them under
  // memory pressure; a NEW MainActivity is created but the Flutter
  // engine is NOT (AudioServiceActivity hands back the cached one), so
  // the Dart future is still waiting on a reply the dead instance was
  // going to send. The Kotlin half now answers anyway — from a static
  // field, on resume — and THIS half is the belt: nothing in the app is
  // allowed to await a trip out of the process without a bound.
  group('a permission reply that never comes', () {
    test('resolves to "not granted" instead of waiting forever, because a '
        'future that never completes leaves the whole updater latched '
        'off for the life of the process', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('yswords/apk_installer'),
        (call) async {
          calls.add(call);
          if (call.method == 'requestPermission') {
            // Parked in an instance field of an Activity that no longer
            // exists. Answered by nobody, ever.
            return Completer<bool>().future;
          }
          return null;
        },
      );
      final granted = await AppUpdateInstaller.requestPermission(
        timeout: const Duration(milliseconds: 50),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail('requestPermission never completed — the '
            'orphaned Result is exactly the bug'),
      );
      expect(granted, isFalse,
          reason: 'a trip whose answer is unknown leaves the reader where '
              'they were; it must not be read as "they granted it"');
      expect(calls.single.method, 'requestPermission');
    });

    test('the shipped timeout is finite, so a real device cannot hang — '
        'the same promise the download already makes', () {
      expect(AppUpdateInstaller.defaultPermissionTimeout,
          lessThanOrEqualTo(const Duration(minutes: 10)));
      expect(AppUpdateInstaller.defaultPermissionTimeout,
          greaterThan(AppUpdateInstaller.defaultConnectTimeout),
          reason: 'at the far end of this one is a person reading a '
              'settings screen, not a socket');
    });
  });

  // 2026-09-09 (remediation): which app the release APK actually is.
  group('the flavour on the other side of the button', () {
    test('a `.cn` build is not handed the international APK — a different '
        'applicationId is a second app on the home screen, not an update',
        () async {
      packageId = '${AppUpdateInstaller.kReleasePackage}.cn';
      final outcome = await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_apkBytes()),
      );
      expect(outcome, UpdateInstallOutcome.unsupported);
      expect(calls.any((c) => c.method == 'updateDir'), isFalse,
          reason: 'and not one byte of a 90 MB file is fetched first');
      expect(downloaded().existsSync(), isFalse);
      expect(await AppUpdateInstaller.isReleasePackage(), isFalse);
    });

    test('the intl build is', () async {
      expect(await AppUpdateInstaller.isReleasePackage(), isTrue);
      expect(
        await AppUpdateInstaller.downloadAndInstall(
          'https://example.invalid/app.apk',
          client: _serving(_apkBytes()),
        ),
        UpdateInstallOutcome.launched,
      );
    });

    test('a platform that will not say which app this is answers "don\'t"',
        () async {
      packageId = null;
      expect(await AppUpdateInstaller.isReleasePackage(), isFalse);
    });

    test('off Android the question is not even asked', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await AppUpdateInstaller.isReleasePackage(), isFalse);
      expect(calls, isEmpty);
    });
  });

  _theOtherSideOfTheChannel();
}

// ---------------------------------------------------------------------
// 2026-09-09 (review finding 4): the Kotlin half of the same promise.
//
// Everything above mocks the channel, so it proves what Dart does with
// an answer and nothing at all about when that answer is sent. The
// whole fix is the WHEN: `startActivity` + `result.success(true)` also
// satisfies every test above, and is exactly the bug — it says "granted"
// the instant the settings screen opens, so the resume in
// `update_check_tile.dart` fires while the reader is still looking at
// the switch. There is no emulator in this suite, so what is pinned is
// the shape of the handler.

void _theOtherSideOfTheChannel() {
  group('the Android side of the permission trip', () {
    final kotlin = File('android/app/src/main/kotlin/com/example/yswords/'
            'MainActivity.kt')
        .readAsStringSync();

    test('asks for a RESULT rather than firing and forgetting', () {
      expect(kotlin.contains('startActivityForResult('), isTrue);
      expect(kotlin.contains('override fun onActivityResult('), isTrue);
    });

    test('answers by re-reading the switch, not by trusting a result code',
        () {
      final at = kotlin.indexOf('private fun answerPendingPermission()');
      expect(at, greaterThan(-1),
          reason: 'the answer has to be one function two callers can '
              'reach, or the resume path below cannot exist');
      final body = _kotlinFun(kotlin, 'private fun answerPendingPermission()');
      expect(body.contains('canRequestPackageInstalls()'), isTrue,
          reason: "the settings screen's own result code is CANCELED "
              'whether or not the switch was touched, so the switch '
              'itself is the only honest answer');
      expect(body.contains('result?.success('), isTrue);
      expect(_kotlinFun(kotlin, 'override fun onActivityResult(')
          .contains('answerPendingPermission()'), isTrue);
    });

    // 2026-09-09 (remediation, finding 1). The two assertions below are
    // the whole fix for the orphaned reply, and each fails on the code
    // that shipped in this patch's first draft.
    test('the parked reply outlives the Activity that parked it', () {
      expect(
        RegExp(r'^    private var pendingPermissionResult', multiLine: true)
            .hasMatch(kotlin),
        isFalse,
        reason: 'an INSTANCE field dies with the Activity, and the '
            'Flutter engine does not: AudioServiceActivity hands the '
            'cached engine back to the new instance, whose own field is '
            'null, so `?.success(...)` replies to nobody and the Dart '
            'future waits for the life of the process',
      );
      final companion = _kotlinBlock(kotlin, 'companion object {');
      expect(companion.contains('pendingPermissionResult'), isTrue,
          reason: 'it belongs to the engine\'s lifetime, not the '
              "Activity's");
      expect(companion.contains('permissionRequestOutstanding'), isTrue,
          reason: 'and so does the flag that lets a recreated instance '
              'know there is something to answer');
    });

    test('and is answered on resume, because the instance the reader comes '
        'back to is not the one that asked', () {
      expect(kotlin.contains('override fun onResume()'), isTrue,
          reason: 'a recreated MainActivity never receives the result of '
              'an activity it did not start — onActivityResult alone '
              'cannot close this');
      expect(_kotlinFun(kotlin, 'override fun onResume()')
          .contains('answerPendingPermission()'), isTrue);
    });

    test('can say which app is asking, so the `.cn` flavour is not offered '
        'the international APK', () {
      expect(kotlin.contains('"packageName" -> result.success(packageName)'),
          isTrue);
    });

    test('the requestPermission branch no longer replies on its own', () {
      final at = kotlin.indexOf('"requestPermission" ->');
      expect(at, greaterThan(-1));
      final branch = kotlin.substring(at, kotlin.indexOf('"updateDir" ->', at));
      expect(branch.contains('startActivity('), isFalse,
          reason: 'the fire-and-forget call must be gone, not merely '
              'joined by a second one — note startActivityForResult does '
              'not match this');
      expect(branch.contains('pendingPermissionResult = result'), isTrue,
          reason: 'the caller has to be kept waiting somewhere');
      // The API-26-and-up arm, which is the one with a screen to open.
      // (Below 26 the permission is granted at install time, and an
      // immediate `success(true)` there is the truth.)
      final opening = branch.substring(
          branch.indexOf('try {'), branch.indexOf('} catch'));
      expect(opening.contains('result.success('), isFalse,
          reason: 'a reply sent beside the startActivity means "the '
              'screen opened", and Dart would read it as "they granted '
              "it\" and carry on installing over the reader's shoulder");
    });
  });
}

/// The body of a Kotlin declaration, from its signature to the `}` at
/// the declaration's own indentation. Crude on purpose: these tests pin
/// the SHAPE of a file no emulator in this suite can run.
String _kotlinFun(String source, String signature) {
  final at = source.indexOf(signature);
  if (at < 0) return '';
  final end = source.indexOf('\n    }', at);
  return end < 0 ? source.substring(at) : source.substring(at, end);
}

/// The same, for a block opened at class-body indentation.
String _kotlinBlock(String source, String opener) {
  final at = source.indexOf(opener);
  if (at < 0) return '';
  final end = source.indexOf('\n    }', at);
  return end < 0 ? source.substring(at) : source.substring(at, end);
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
