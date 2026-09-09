// 2026-09-09: installing the update from inside the app.
//
// From the owner: 「sword没有按键直接更新的」 — and before that, the
// question behind it: 「pianowithrosa 都是可以在 APP 里面就更新完但是
// words sword 要跳出去，可以只在 app 里面吗」.
//
// **The honest answer, by platform, because it is not the same
// answer.** A website updates itself because it is fetched every time
// it is opened; that is why 雅伟的话 and pianowithrosa feel seamless,
// and it is not something a native build can copy. So:
//
//   * **Android** — yes, and this file is it. The APK is downloaded
//     here and handed to the system installer. Android still shows its
//     own "install an update to this app?" screen and always will:
//     that dialog is the OS's security boundary, not a step this code
//     forgot to skip. What goes away is everything around it — the
//     browser, the Downloads folder, the file manager.
//   * **iOS** — no, and no amount of work changes it. An app cannot
//     install an app. Without the App Store or TestFlight the only
//     route is the web app, which is what the release page says.
//   * **Windows / macOS / Linux** — the download can happen here, but
//     replacing a running application is the platform's business and
//     the reader's. They keep the browser route.
//   * **Web** — nothing to install. A reload IS the update.
//
// So [isSupported] is Android alone, and every other platform keeps the
// link it already had rather than being shown a button that would have
// to apologise.

import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;
import 'package:http/http.dart' as http;

/// The four bytes every APK (and every other zip) starts with.
///
/// Checked before the file is offered to the installer because the
/// failure it catches is silent and confusing: a captive-portal login
/// page, a GitHub outage page or an HTML redirect all arrive with a
/// 200 and a plausible length, and Android's response to being handed
/// one is "There was a problem parsing the package" — which reads to
/// the reader as *this app's update is broken*, not *your hotel wifi
/// interfered*.
const List<int> kZipMagic = <int>[0x50, 0x4B, 0x03, 0x04];

/// What happened to an attempt to install.
enum UpdateInstallOutcome {
  /// Android's installer was launched. Whether the reader went through
  /// with it is not knowable from here — the installer is a separate
  /// task and reports nothing back. The app finds out the way anyone
  /// else would: by being restarted as the new version.
  launched,

  /// The reader has not allowed this app to install packages. The UI
  /// sends them to the OS switch rather than reporting a failure.
  permissionNeeded,

  /// The download did not finish, or finished as something that is not
  /// an APK.
  downloadFailed,

  /// The reader pressed Stop. Nothing to report: they know.
  ///
  /// 2026-09-09 (review finding 1): its own outcome rather than a
  /// flavour of [downloadFailed], because the UI's answer to a failure
  /// is a dialog offering the browser, and somebody who just said
  /// "stop" should not be asked a second question.
  cancelled,

  /// The platform cannot do this at all. Never returned on Android.
  unsupported,
}

/// A handle the UI holds to stop a download it started.
///
/// 2026-09-09 (review finding 1): before this the progress dialog had
/// no button at all, so the only way out of it was the Android Back
/// button — which closed the dialog and left the download running
/// unseen, and a second "立即更新" then opened a second write stream on
/// the same `update.apk`. The token is checked between chunks, and
/// [whenCancelled] is raced against the connect and the read so a
/// stalled connection cannot delay the reader's Stop by the length of
/// a timeout.
class UpdateCancelToken {
  final Completer<void> _done = Completer<void>();

  bool get isCancelled => _done.isCompleted;

  /// Completes when [cancel] is called; never completes otherwise.
  Future<void> get whenCancelled => _done.future;

  void cancel() {
    if (!_done.isCompleted) _done.complete();
  }
}

class AppUpdateInstaller {
  AppUpdateInstaller._();

  static const MethodChannel _channel = MethodChannel('yswords/apk_installer');

  /// How long a download may go without a single byte before it is
  /// given up.
  ///
  /// 2026-09-09 (review finding 3): a connection that dies after the
  /// headers — a lift, a tunnel, a wifi hand-off — used to freeze the
  /// progress dialog forever, and the dialog had nothing on it to
  /// press. Thirty seconds is long enough for a slow link to breathe
  /// and short enough that the "didn't download" dialog arrives while
  /// the reader is still looking at the screen.
  static const Duration defaultIdleTimeout = Duration(seconds: 30);

  /// How long to wait for the response headers. Same reasoning; this
  /// is the half that catches a server which accepts the socket and
  /// then says nothing. (`UpdateService.checkForUpdate` already had
  /// its own 10-second timeout — the version check was never the half
  /// that hung.)
  static const Duration defaultConnectTimeout = Duration(seconds: 30);

  /// How long the trip to the OS switch may take before it is answered
  /// "not granted" here regardless of what the platform side says.
  ///
  /// 2026-09-09 (remediation, review finding 1): [requestPermission]
  /// awaits a round trip that leaves this process entirely — the reader
  /// is in Settings, and Android is free to destroy the Activity that
  /// asked while they are there. `MainActivity` now survives that (the
  /// pending reply is static and is answered from `onResume`, not only
  /// from `onActivityResult`), but "the platform side always replies"
  /// is not a promise Dart should stake a permanently-dead button on:
  /// a reply that never arrives used to leave `updateInstallInProgress`
  /// latched true, which silently disabled 「立即更新」 on BOTH surfaces
  /// for the life of the process, with no way back short of killing the
  /// app.
  ///
  /// Three minutes rather than the download's thirty seconds, and the
  /// difference is the point: at the other end of this wait is a person
  /// reading a settings screen, not a socket. Long enough that nobody
  /// who is actually doing it is cut off; finite, so nothing can hang.
  /// A timeout resolves to false — the reader is left exactly where
  /// they were, and 「立即更新」 still works on the next tap.
  static const Duration defaultPermissionTimeout = Duration(minutes: 3);

  /// The applicationId of the build the release APK actually carries.
  ///
  /// 2026-09-09 (remediation): `release-android.yml` builds `--flavor
  /// intl` and attaches that one APK, whose id is the `defaultConfig`
  /// one below. The `cn` flavour adds `applicationIdSuffix = ".cn"`, so
  /// to a `.cn` build the release asset is not an update at all —
  /// Android treats a different applicationId as a different app and
  /// would install a SECOND copy beside the one whose 「立即更新」 the
  /// reader just pressed. [UpdateInfo.hasApk] cannot see this: the
  /// asset IS an APK, just not this app's.
  static const String kReleasePackage = 'com.example.yswords';

  /// Android only. See the file header for why every other platform
  /// keeps the browser route rather than getting a button.
  ///
  /// `defaultTargetPlatform` rather than `Platform.isAndroid`, and the
  /// `kIsWeb` line above it is what makes that safe: a mobile browser
  /// reports `TargetPlatform.android` too, so the order here is the
  /// whole correctness argument and not a style choice. The reason to
  /// prefer it is that it can be overridden in a test, and everything
  /// this class does is behind this gate — with `Platform.isAndroid`
  /// the download's truncation and content checks could only ever be
  /// exercised on a device, which is to say never.
  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// Whether the reader has already allowed this app to install
  /// packages. False is not an error — it is the ordinary first-time
  /// state, and the caller's job is to offer [requestPermission].
  static Future<bool> canInstall() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Send the reader to the OS switch for this app, and report whether
  /// they came back with it on.
  ///
  /// 2026-09-09 (review finding 4): the platform side now answers only
  /// once the settings screen has closed (`onActivityResult`), so the
  /// value here is "granted NOW", after the reader's trip — not "the
  /// screen opened", which is all the old `void` could have meant. A
  /// false is either a reader who declined or a ROM without the
  /// screen, and both leave them exactly where they were.
  /// 2026-09-09 (remediation, finding 1): and it always answers. See
  /// [defaultPermissionTimeout] for why a round trip that goes through
  /// a settings screen and an Activity Android may destroy underneath
  /// it must not be awaited without a bound.
  static Future<bool> requestPermission({
    Duration timeout = defaultPermissionTimeout,
  }) async {
    if (!isSupported) return false;
    try {
      final granted = await _channel
          .invokeMethod<bool>('requestPermission')
          .timeout(timeout, onTimeout: () => false);
      return granted ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// The applicationId this build is running as, or null when the
  /// platform cannot say.
  ///
  /// Not cached: it is one channel hop, asked at most twice per update
  /// check, and a cache would need a test-only reset hook to stay
  /// honest across the suite.
  static Future<String?> packageName() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('packageName');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Whether the APK on the release page is an update to THIS build
  /// rather than a different app that happens to be an APK.
  ///
  /// See [kReleasePackage]. False on a `.cn` build, and false whenever
  /// the platform side will not say — an unanswerable question about
  /// which app is about to be installed is answered "don't".
  static Future<bool> isReleasePackage() async {
    if (!isSupported) return false;
    return await packageName() == kReleasePackage;
  }

  /// Download [url] into the app's cache and hand it to the installer.
  ///
  /// [onProgress] is called with a 0..1 fraction, or with null while
  /// the server has not said how big the file is — a progress bar that
  /// invents a denominator is worse than one that admits it is
  /// indeterminate, because the reader plans around it.
  ///
  /// The download is streamed rather than buffered. A release APK is
  /// ~90 MB and this runs on a mid-range tablet; `http.get` would hold
  /// the whole thing in memory before a single byte reached disk.
  ///
  /// [cancelToken] lets the UI stop it (finding 1); [idleTimeout] and
  /// [connectTimeout] stop it when the network does not (finding 3).
  /// Both timeouts come back as [UpdateInstallOutcome.downloadFailed] —
  /// the reader sees the same "didn't download" dialog, with the
  /// browser offered as the way out.
  static Future<UpdateInstallOutcome> downloadAndInstall(
    String url, {
    void Function(double? fraction)? onProgress,
    http.Client? client,
    UpdateCancelToken? cancelToken,
    Duration idleTimeout = defaultIdleTimeout,
    Duration connectTimeout = defaultConnectTimeout,
  }) async {
    if (!isSupported) return UpdateInstallOutcome.unsupported;
    // The second half of the platform gate (remediation): a `.cn` build
    // must never hand itself the international APK. The UI already
    // hides the button, and this is the layer that does not depend on
    // the UI having remembered to — nothing is downloaded before the
    // question is answered.
    if (!await isReleasePackage()) return UpdateInstallOutcome.unsupported;
    if (!await canInstall()) return UpdateInstallOutcome.permissionNeeded;
    if (cancelToken?.isCancelled ?? false) {
      return UpdateInstallOutcome.cancelled;
    }

    final String dir;
    try {
      dir = await _channel.invokeMethod<String>('updateDir') ?? '';
    } catch (_) {
      return UpdateInstallOutcome.downloadFailed;
    }
    if (dir.isEmpty) return UpdateInstallOutcome.downloadFailed;

    final owned = client == null;
    final http$ = client ?? http.Client();
    File? file;
    try {
      // Raced against the token so a Stop pressed while the server is
      // still thinking comes back at once, rather than when the connect
      // timeout eventually fires.
      final response = await _unlessCancelled(
        http$
            .send(http.Request('GET', Uri.parse(url)))
            .timeout(connectTimeout),
        cancelToken,
      );
      if (response == null) return UpdateInstallOutcome.cancelled;
      if (response.statusCode != 200) {
        return UpdateInstallOutcome.downloadFailed;
      }
      final total = response.contentLength;

      // One fixed name, overwritten every time. Keeping a file per
      // version would leave a cache full of 90 MB installers that
      // nothing ever deletes — and the only copy that matters is the
      // one being installed right now.
      file = File('$dir/update.apk');
      final sink = file.openWrite();
      var received = 0;
      var head = <int>[];
      try {
        // A subscription rather than `await for`, because a Stop has to
        // be able to interrupt the READING — `await for` can only look
        // at the token once the next chunk has arrived, and the chunk
        // that never arrives is the case Stop exists for. The same
        // shape gives `.timeout` somewhere to land (finding 3).
        final done = Completer<void>();
        final sub = response.stream.timeout(idleTimeout).listen(
          (chunk) {
            sink.add(chunk);
            received += chunk.length;
            if (head.length < kZipMagic.length) {
              head = [...head, ...chunk].take(kZipMagic.length).toList();
            }
            onProgress
                ?.call(total == null || total == 0 ? null : received / total);
          },
          onError: (Object e, StackTrace st) {
            if (!done.isCompleted) done.completeError(e, st);
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );
        unawaited(cancelToken?.whenCancelled.then((_) {
          sub.cancel();
          if (!done.isCompleted) done.complete();
        }));
        await done.future;
      } finally {
        await sink.close();
      }
      if (cancelToken?.isCancelled ?? false) {
        await _discard(file);
        return UpdateInstallOutcome.cancelled;
      }

      // Both halves matter and they catch different lies. A truncated
      // download has the right magic and the wrong length; a login
      // page has a plausible length and the wrong magic.
      if (total != null && total > 0 && received != total) {
        await _discard(file);
        return UpdateInstallOutcome.downloadFailed;
      }
      if (head.length < kZipMagic.length ||
          !_startsWithZipMagic(head)) {
        await _discard(file);
        return UpdateInstallOutcome.downloadFailed;
      }

      await _channel.invokeMethod<bool>('install', {'path': file.path});
      return UpdateInstallOutcome.launched;
    } catch (_) {
      if (file != null) await _discard(file);
      return UpdateInstallOutcome.downloadFailed;
    } finally {
      if (owned) http$.close();
    }
  }

  /// [future]'s value, or null the moment [token] is cancelled first.
  /// `Future.any` listens to both, so a late error from the abandoned
  /// future is not an unhandled one.
  static Future<T?> _unlessCancelled<T>(
    Future<T> future,
    UpdateCancelToken? token,
  ) {
    if (token == null) return future;
    return Future.any<T?>([future, token.whenCancelled.then((_) => null)]);
  }

  static bool _startsWithZipMagic(List<int> head) {
    for (var i = 0; i < kZipMagic.length; i++) {
      if (head[i] != kZipMagic[i]) return false;
    }
    return true;
  }

  /// Remove a download that is not going to be installed, so a failed
  /// attempt does not leave most of an APK in the cache.
  static Future<void> _discard(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // The cache is the OS's to reclaim; a file we could not remove
      // is not a reason to fail the caller differently.
    }
  }
}
