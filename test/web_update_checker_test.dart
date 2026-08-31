// The rules that decide whether a reader's page reloads under them.
//
// 2026-08-31, from the user: 「发现很多人之前用过是老版本」. The site's
// self-heal (no-store entry files, network-first worker, boot-time sweep
// of stale workers and caches) was verified working on yahwehword.com
// the same day — but it only runs when the page LOADS, and a backgrounded
// tab or a resumed PWA never loads again. WebUpdateChecker is the half
// that tells a running client the build moved.
//
// The auto-reload gate is the part worth pinning hardest: getting it
// wrong means yanking someone out of a sermon or destroying a half-typed
// note, which is far worse than the staleness it fixes.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yswords/constants/app_version.dart';
import 'package:yswords/services/web_update_checker.dart';

void main() {
  final checker = WebUpdateChecker.instance;

  setUp(() {
    WebUpdateChecker.debugPretendWeb = true;
    checker.available.value = null;
  });

  tearDown(() {
    WebUpdateChecker.debugPretendWeb = false;
    WebUpdateChecker.debugClientFactory = null;
    checker.available.value = null;
  });

  group('reading version.json', () {
    test('takes the version out of a real manifest', () {
      expect(
        WebUpdateChecker.versionFrom(
            '{"app_name":"yswords","version":"1.4.176","package_name":"yswords"}'),
        '1.4.176',
      );
    });

    test('a page of HTML is "do not know", never an update', () {
      // netlify.toml rewrites every unknown path to /index.html, so a
      // deploy that lost version.json answers this request with the
      // whole single-page app. Reading that as an update would reload
      // every client on the planet, forever.
      expect(
          WebUpdateChecker.versionFrom('<!DOCTYPE html><html>…</html>'), isNull);
    });

    test('rejects a manifest with no usable version', () {
      expect(WebUpdateChecker.versionFrom('{}'), isNull);
      expect(WebUpdateChecker.versionFrom('{"version":""}'), isNull);
      expect(WebUpdateChecker.versionFrom('{"version":"   "}'), isNull);
      expect(WebUpdateChecker.versionFrom('{"version":123}'), isNull);
      expect(WebUpdateChecker.versionFrom('[1,2,3]'), isNull);
      expect(WebUpdateChecker.versionFrom(''), isNull);
    });
  });

  group('checkNow', () {
    void serve(int status, String body) {
      WebUpdateChecker.debugClientFactory = () =>
          MockClient((_) async => http.Response(body, status,
              headers: {'content-type': 'application/json'}));
    }

    test('the same version raises nothing', () async {
      serve(200, jsonEncode({'version': kAppVersion}));
      await checker.checkNow();
      expect(checker.available.value, isNull);
    });

    test('a different version is surfaced', () async {
      serve(200, jsonEncode({'version': '9.9.9'}));
      await checker.checkNow();
      expect(checker.available.value, '9.9.9');
    });

    test('a version that goes BACK still counts as a move', () async {
      // A rollback is as much a reason to reload as a bump: the point is
      // to run what the server is serving, not to run the highest number
      // anyone has ever seen.
      serve(200, jsonEncode({'version': '0.0.1'}));
      await checker.checkNow();
      expect(checker.available.value, '0.0.1');
    });

    test('a non-200 changes nothing', () async {
      checker.available.value = null;
      serve(404, 'nope');
      await checker.checkNow();
      expect(checker.available.value, isNull);
    });

    test('a network failure is silent, not an error', () async {
      WebUpdateChecker.debugClientFactory =
          () => MockClient((_) async => throw const SocketExceptionish());
      await checker.checkNow();
      expect(checker.available.value, isNull);
    });

    test('a recovered server clears a previously-raised banner', () async {
      serve(200, jsonEncode({'version': '9.9.9'}));
      await checker.checkNow();
      expect(checker.available.value, '9.9.9');
      // The user reloaded in another tab, or the deploy was rolled
      // forward to match. The banner must go away on its own.
      serve(200, jsonEncode({'version': kAppVersion}));
      await checker.checkNow();
      expect(checker.available.value, isNull);
    });

    test('off the web it does nothing at all', () async {
      WebUpdateChecker.debugPretendWeb = false;
      expect(WebUpdateChecker.isSupported, isFalse);
      serve(200, jsonEncode({'version': '9.9.9'}));
      await checker.checkNow();
      expect(checker.available.value, isNull);
    });
  });

  group('the auto-reload gate', () {
    // Every case below is the same call with ONE thing changed, so each
    // test names exactly one reason a reader's page may not vanish.
    bool decide({
      String? availableVersion = '9.9.9',
      bool justResumed = true,
      bool audioPlaying = false,
      bool textFieldFocused = false,
      bool alreadyTriedThisVersion = false,
    }) =>
        WebUpdateChecker.shouldAutoReload(
          availableVersion: availableVersion,
          justResumed: justResumed,
          audioPlaying: audioPlaying,
          textFieldFocused: textFieldFocused,
          alreadyTriedThisVersion: alreadyTriedThisVersion,
        );

    test('reloads when there is an update and nothing is in progress', () {
      expect(decide(), isTrue);
    });

    test('never without an update', () {
      expect(decide(availableVersion: null), isFalse);
    });

    test('never while the page is being looked at', () {
      // The user chose "banner + reload in the background", not "reload
      // whenever". Only a resume may reload.
      expect(decide(justResumed: false), isFalse);
    });

    test('never while a song is playing', () {
      // Reading position survives a reload; audio does not — the element
      // is destroyed and playback stops dead.
      expect(decide(audioPlaying: true), isFalse);
    });

    test('never while someone is typing', () {
      // A half-written note lives in the widget, not in storage.
      expect(decide(textFieldFocused: true), isFalse);
    });

    test('never twice for the same version', () {
      // The loop guard. version.json and main.dart.js are separate files
      // behind a CDN and can disagree for a few minutes after a deploy;
      // without this the app would reload forever and never converge.
      expect(decide(alreadyTriedThisVersion: true), isFalse);
    });
  });

  group('textFieldFocused', () {
    testWidgets('false when nothing is focused', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('x'))));
      expect(WebUpdateChecker.textFieldFocused(), isFalse);
    });

    testWidgets('false when a plain button holds focus', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ElevatedButton(onPressed: () {}, child: const Text('go')),
        ),
      ));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(WebUpdateChecker.textFieldFocused(), isFalse);
    });

    testWidgets('true once a text field has focus', (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: TextField())));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(WebUpdateChecker.textFieldFocused(), isTrue);
    });
  });

  test('maybeAutoReload is inert on native', () {
    // On native `updateReloadAlreadyTried` reports true by design (there
    // is no page to reload and no sessionStorage to latch), so the live
    // wiring cannot be exercised on the VM — the pure gate above is what
    // carries that weight. This asserts only that it stays harmless.
    WebUpdateChecker.debugPretendWeb = false;
    checker.available.value = null;
    expect(() => checker.maybeAutoReload(justResumed: true), returnsNormally);
  });
}

/// A stand-in for a transport failure. `MockClient` needs something to
/// throw and the real `SocketException` is `dart:io`-only, which would
/// break this file's web compile.
class SocketExceptionish implements Exception {
  const SocketExceptionish();
  @override
  String toString() => 'connection failed';
}
