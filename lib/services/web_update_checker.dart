// 2026-08-31: tell a RUNNING web client that the build moved.
//
// From the user: 「有没有办法你帮我把现在所有用户的yahwehword的缓存全部清
// 一下呢，发现很多人之前用过是老版本」. Nobody can clear a browser's cache
// from the outside — but that was never the actual gap. Measured on
// yahwehword.com the same day: the entry files are all served
// `no-store`, the app's own service worker is network-first, and one
// load evicts every stale worker and cache bucket (verified by planting
// `flutter-app-cache` / `flutter-temp-cache` / a junk bucket and
// watching all three disappear after a single reload, while the user's
// `song-media-` downloads were correctly kept).
//
// The self-heal is sound. It just only runs WHEN THE PAGE LOADS. A tab
// left open in the background, or an installed PWA that resumes instead
// of reloading, never loads again — and nothing told it to.
// `update_service.dart` says so in as many words:
//
//     Web returns null: the PWA always serves the latest build on
//     reload, so there is nothing to "update".
//
// True, and beside the point: the client that is already running never
// reloads. This service is the missing half. It polls `version.json`
// (70 bytes) and, when the served version no longer matches the one
// this bundle was compiled as, raises [available] for the banner and —
// under the narrow conditions in [shouldAutoReload] — reloads on its
// own.
//
// It cannot help anyone stuck TODAY: a client on 1.4.11 does not have
// this code. Those people still need one manual reload. There is no way
// around that, and pretending otherwise would be the wrong promise.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'package:yswords/constants/app_version.dart';
import 'package:yswords/services/song_player_service.dart';
import 'package:yswords/utils/page_reload.dart';

class WebUpdateChecker with WidgetsBindingObserver {
  WebUpdateChecker._();
  static final WebUpdateChecker instance = WebUpdateChecker._();

  /// Let boot finish before spending anything on this. Nothing about an
  /// update is urgent in the first seconds of a cold start, and the
  /// boot path is already the most contended moment the app has.
  static const Duration firstCheckDelay = Duration(seconds: 20);

  /// A deploy happens a few times a day at most; 70 bytes every half
  /// hour is far below the noise floor, and a resume triggers an
  /// out-of-band check anyway.
  static const Duration pollInterval = Duration(minutes: 30);

  static const Duration requestTimeout = Duration(seconds: 8);

  /// The version the server is serving, when it differs from the one
  /// this bundle was built as. Null means "we are current, or we don't
  /// know". The banner watches this.
  final ValueNotifier<String?> available = ValueNotifier<String?>(null);

  Timer? _firstCheck;
  Timer? _poll;
  bool _started = false;
  bool _inFlight = false;

  /// Test seam: lets the VM-side tests exercise the whole service
  /// without `kIsWeb`. Never set outside tests.
  @visibleForTesting
  static bool debugPretendWeb = false;

  /// Test seam: the client used to fetch `version.json`.
  @visibleForTesting
  static http.Client Function()? debugClientFactory;

  /// Native builds have a real installer flow (`UpdateService`, GitHub
  /// Releases) and no page to reload, so this is web-only.
  static bool get isSupported => kIsWeb || debugPretendWeb;

  void start() {
    if (!isSupported || _started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _firstCheck = Timer(firstCheckDelay, () {
      checkNow();
      _poll = Timer.periodic(pollInterval, (_) => checkNow());
    });
  }

  @visibleForTesting
  void stop() {
    _firstCheck?.cancel();
    _poll?.cancel();
    _firstCheck = null;
    _poll = null;
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Coming back to the foreground is both the most likely moment for
    // the build to have moved since we last looked, and the only moment
    // an automatic reload is defensible — see shouldAutoReload.
    checkNow().then((_) => maybeAutoReload(justResumed: true));
  }

  /// Ask the server what it is serving. Never throws: a failed check is
  /// indistinguishable from "no update" and must not surface anywhere.
  Future<void> checkNow() async {
    if (!isSupported || _inFlight) return;
    _inFlight = true;
    final client = (debugClientFactory ?? http.Client.new)();
    try {
      final res = await client
          .get(
            // Anchored at the origin root, not resolved relatively:
            // `version.json` is only ever published at `/`, and the app
            // routes through the URL fragment (`#/genesis/1:1?v=nasb`),
            // so a relative resolve would be at the mercy of whatever
            // the fragment left behind.
            Uri.base.replace(path: '/version.json', query: '', fragment: ''),
            // version.json is already `max-age=0, must-revalidate`, so
            // this is belt-and-braces against an intermediary that
            // decides otherwise. A stale answer here is worse than no
            // answer: it would either hide a real update or, if it
            // reported a version nobody is serving, drive the reload
            // the latch exists to stop.
            headers: const {'Cache-Control': 'no-cache'},
          )
          .timeout(requestTimeout);
      if (res.statusCode != 200) return;
      final served = versionFrom(res.body);
      if (served == null) return;
      available.value = served == kAppVersion ? null : served;
    } catch (_) {
      // Offline, timed out, SPA catch-all returned HTML, whatever.
      // Silence is correct — this feature is not worth one visible
      // error.
    } finally {
      _inFlight = false;
      client.close();
    }
  }

  /// Pull the `version` field out of a `version.json` body.
  ///
  /// Returns null for anything that isn't a JSON object with a
  /// non-empty string `version`. The SPA catch-all rewrites unknown
  /// paths to index.html, so a misconfigured deploy answers this
  /// request with a page of HTML — which must read as "don't know", not
  /// as an update.
  @visibleForTesting
  static String? versionFrom(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final v = decoded['version'];
      if (v is! String || v.trim().isEmpty) return null;
      return v.trim();
    } catch (_) {
      return null;
    }
  }

  /// Whether the app may reload itself without being asked.
  ///
  /// Pure on purpose: these are the rules that decide whether someone
  /// loses what they were doing, so they are testable on their own,
  /// without a browser, a timer or a running app.
  ///
  /// Reading position survives a reload — the current book/chapter and
  /// each sermon's scroll offset are both persisted — so reading is not
  /// on this list. What does NOT survive is audio (the element is
  /// destroyed) and half-typed text (a note in progress is in the
  /// widget, not in storage). Those two are the whole gate, plus the
  /// loop latch.
  static bool shouldAutoReload({
    required String? availableVersion,
    required bool justResumed,
    required bool audioPlaying,
    required bool textFieldFocused,
    required bool alreadyTriedThisVersion,
  }) {
    if (availableVersion == null) return false;
    // Only on resume. Reloading a page someone is actively looking at
    // is the behaviour the user explicitly did not want.
    if (!justResumed) return false;
    if (audioPlaying) return false;
    if (textFieldFocused) return false;
    if (alreadyTriedThisVersion) return false;
    return true;
  }

  /// True when the focused node lives inside an [EditableText] — i.e.
  /// the user is part-way through typing something.
  @visibleForTesting
  static bool textFieldFocused() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.findAncestorStateOfType<EditableTextState>() != null;
  }

  /// Apply [shouldAutoReload] to the live app and act on it.
  @visibleForTesting
  void maybeAutoReload({required bool justResumed}) {
    final target = available.value;
    if (target == null) return;
    if (!shouldAutoReload(
      availableVersion: target,
      justResumed: justResumed,
      audioPlaying: SongPlayerService.instance.isPlaying,
      textFieldFocused: textFieldFocused(),
      alreadyTriedThisVersion: updateReloadAlreadyTried(target),
    )) {
      return;
    }
    markUpdateReloadTried(target);
    reloadPage();
  }

  /// The banner's button. Always allowed — the user asked for it, so
  /// none of the gate applies, but the latch is still stamped so a
  /// manual reload that fails to change anything does not leave an
  /// automatic one queued behind it.
  void reloadNow() {
    final target = available.value;
    if (target != null) markUpdateReloadTried(target);
    reloadPage();
  }
}
