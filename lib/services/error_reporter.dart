/// Best-effort crash reporter for YsWords.
///
/// Captures uncaught Flutter / async errors on every platform we
/// ship (web / iOS / macOS / Android) and POSTs a JSON blob to
/// `/api/errorReport` — which forwards via Resend to the developer
/// inbox (`lsy95112@gmail.com`).
///
/// 2026-05-24 (v1.3.21): added in response to the priorities.md
/// item #2 — "Today, a crash on yswords.netlify.app is invisible
/// to the developer." A user-facing crash now generates a single
/// email with stack, app version, platform, locale, route,
/// last ~10 breadcrumbs, and basic device info.
///
/// Hook points:
///   - `FlutterError.onError` (sync widget / framework errors)
///   - `PlatformDispatcher.instance.onError` (uncaught async)
///   - `runZonedGuarded` wrapping `main()` (zone-level fallback)
///   - `BreadcrumbObserver` `NavigatorObserver` (auto-records every
///     push/pop so the email shows the navigation trail)
///
/// Privacy: NEVER sends user content (verses they highlighted,
/// notes they wrote, AI prompts they typed). The payload is
/// limited to:
///   * the error string + stack trace (Dart-side only — no
///     server-side memory or PII)
///   * static metadata (version, platform, locale, route name)
///   * breadcrumbs are action-type only ("nav: HomePage", "verse
///     tapped") not content
///   * device info is screen size + OS version + user agent —
///     same data every web request already exposes
///
/// Always fire-and-forget — the reporter never throws into the
/// caller, never blocks the UI, and silently no-ops if the
/// network is down.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:yswords/constants/app_version.dart';
// Conditional import: dart:io on native, stub on web.
import 'package:yswords/services/error_reporter_platform_io.dart'
    if (dart.library.js_interop) 'package:yswords/services/error_reporter_platform_web.dart'
    as platform;

class ErrorReporter {
  static const String _endpointDefault = '/api/errorReport';

  /// Lazy session id — generated on first init. Stays the same for
  /// the whole app lifecycle so the server can group repeat errors
  /// from one user session even before they reload.
  static String? _sessionId;

  /// In-memory ring buffer of the last ~10 user actions. Trimmed on
  /// every push past the cap. Cleared between hot-restarts.
  static final List<_Breadcrumb> _breadcrumbs = [];
  static const int _maxBreadcrumbs = 10;

  static String _appLocale = 'en';
  static String _currentRoute = '';

  /// Initialise the reporter. Call ONCE from `main()` after
  /// `WidgetsFlutterBinding.ensureInitialized()` and BEFORE
  /// `runApp(...)`. Idempotent (subsequent calls are no-ops).
  static bool _initialised = false;
  static void init({String? endpointOverride}) {
    if (_initialised) return;
    _initialised = true;
    _sessionId = _generateSessionId();
    if (endpointOverride != null) _endpoint = endpointOverride;

    // Sync Flutter framework errors (widget build, layout, paint).
    // Keep the default behaviour (print + assert in debug, dump in
    // release) by calling `FlutterError.presentError` first.
    final priorOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      try {
        if (priorOnError != null) {
          priorOnError(details);
        } else {
          FlutterError.presentError(details);
        }
      } catch (_) {/* never bubble */}
      _send(
        error: details.exceptionAsString(),
        stack: details.stack?.toString() ?? '',
        source: 'FlutterError',
        library: details.library,
      );
    };

    // Uncaught async errors that bubble past every zone boundary.
    // Returning `true` here marks the error as handled so the
    // platform doesn't separately re-throw it.
    PlatformDispatcher.instance.onError = (error, stack) {
      _send(
        error: error.toString(),
        stack: stack.toString(),
        source: 'PlatformDispatcher',
      );
      return true;
    };
  }

  static String _endpoint = _endpointDefault;

  /// Update the user's UI locale. Called from `_AppState` whenever
  /// AppSettings.locale changes. Reflected in subsequent reports
  /// so we know which language string was on screen when the
  /// error fired.
  static void setLocale(String locale) {
    _appLocale = locale;
  }

  /// Push a breadcrumb. Capped at _maxBreadcrumbs.
  ///
  /// Use for high-signal events (route navigation, AI request
  /// kickoff, version switch). Avoid spammy events (every scroll
  /// tick) — those drown the actually-useful trail.
  static void breadcrumb(String action, {String? data}) {
    _breadcrumbs.add(_Breadcrumb(
      timestamp: DateTime.now().toUtc(),
      action: action,
      data: data,
    ));
    if (_breadcrumbs.length > _maxBreadcrumbs) {
      _breadcrumbs.removeAt(0);
    }
  }

  /// Update the current top route. The `BreadcrumbObserver`
  /// `NavigatorObserver` calls this from `didPush`/`didPop` so the
  /// reporter always knows where the user IS, not where they were
  /// 5 navigations ago.
  static void setCurrentRoute(String? routeName) {
    _currentRoute = routeName ?? '';
  }

  /// Manual report site. Use inside `try/catch` blocks where a
  /// non-fatal error is meaningful but the surrounding code can
  /// recover. Example: AI request retry exhausted, JSON parse of
  /// a malformed asset.
  static void report(
    Object error,
    StackTrace stack, {
    String source = 'manual',
    String? extra,
  }) {
    _send(
      error: error.toString(),
      stack: stack.toString(),
      source: source,
      library: extra,
    );
  }

  /// Internal send. Wraps every step in try/catch so the reporter
  /// itself never raises.
  static Future<void> _send({
    required String error,
    required String stack,
    required String source,
    String? library,
  }) async {
    if (!_initialised) return;
    // v1.3.x: drop known-benign noise so the inbox stays signal.
    if (_isIgnorableNoise(error, stack)) return;
    // Best-effort: cap payload sizes; never send absurd inputs.
    final payload = <String, dynamic>{
      'error': _trim(error, 2000),
      'stack': _trim(stack, 8000),
      'source': _trim(source, 64),
      if (library != null) 'library': _trim(library, 128),
      'version': kAppVersion,
      'platform': platform.platformName,
      'locale': _appLocale,
      'route': _trim(_currentRoute, 256),
      'sessionId': _sessionId ?? '',
      'breadcrumbs': _breadcrumbs
          .map((b) => {
                't': b.timestamp.toIso8601String(),
                'action': _trim(b.action, 80),
                if (b.data != null) 'data': _trim(b.data!, 200),
              })
          .toList(),
      'device': platform.collectDeviceInfo(),
    };

    // Fire-and-forget. Wrap in unawaited Future + try/catch so a
    // failed POST (offline, CORS, network) never throws back into
    // the error path that triggered the report.
    unawaited(_postSafely(payload));
  }

  /// True for errors that are well-understood, non-actionable noise —
  /// the app keeps working and there's nothing to fix. Filtered out
  /// before a report is sent so the monitoring inbox stays signal.
  ///
  /// Currently: CanvasKit's WebGL context-creation failures on iOS
  /// Chrome (CriOS) / locked-down WebViews — e.g.
  /// `Error: getParameter is not a function` thrown from
  /// `canvaskit.js … MakeWebGLContext`. When WebGL is unavailable
  /// CanvasKit falls back to CPU rendering and the app renders fine;
  /// the throw is caught by our Zone/PlatformDispatcher handler and is
  /// not something we can act on. (v1.3.49 web reports.)
  ///
  /// Also: `google_fonts` runtime font fetches from
  /// fonts.gstatic.com. `font_catalog.dart`'s `resolveFontFamily` /
  /// `previewTextStyle` already catch the synchronous call and fall
  /// back to a system font, so the UI never breaks — but the actual
  /// HTTP fetch happens in an unawaited Future deep inside the
  /// package (`loadFontIfNecessary`, no `.catchError` attached), so a
  /// network failure there is unhandled and reaches this reporter
  /// regardless. Reported from a Huawei ELS-AN00 (zh-Hans) — devices
  /// without Google connectivity will hit this on every cold font
  /// load and there's nothing actionable on our end. (v1.3.114.)
  static bool _isIgnorableNoise(String error, String stack) {
    final haystack = '$error\n$stack';
    const benign = <String>[
      'getParameter is not a function',
      'MakeWebGLContext',
      'Failed to create WebGL context',
      'Failed to load font with url',
      '_httpFetchFontAndSaveToDevice',
    ];
    for (final p in benign) {
      if (haystack.contains(p)) return true;
    }
    return false;
  }

  static Future<void> _postSafely(Map<String, dynamic> payload) async {
    try {
      // Use the absolute endpoint on native (no document.location);
      // relative on web works because the function lives on the
      // same origin.
      final url = _resolveUrl();
      await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {/* silent — reporter must never throw */}
  }

  static String _resolveUrl() {
    if (_endpoint.startsWith('http')) return _endpoint;
    // Native: prefix with the prod host. (Dev/qat native builds
    // are rare; the daily-fire reinstall job builds against the
    // committed main, which uses prod-deployed JSON anyway.)
    if (platform.platformName != 'web') {
      return 'https://yswords.netlify.app$_endpoint';
    }
    return _endpoint;
  }

  static String _trim(String s, int max) =>
      s.length > max ? s.substring(0, max) : s;

  // ── Test surface ────────────────────────────────────────────────
  // 2026-05-24 (v1.3.23): minimal accessors so unit tests can verify
  // the breadcrumb-buffer cap, route tracking, locale tracking, and
  // payload-cap behavior without scraping a private static directly.
  // None of these are called from production code.

  /// @visibleForTesting — read-only snapshot of the breadcrumb ring.
  static List<({DateTime timestamp, String action, String? data})>
      get breadcrumbsForTest => _breadcrumbs
          .map((b) =>
              (timestamp: b.timestamp, action: b.action, data: b.data))
          .toList(growable: false);

  /// @visibleForTesting — current pinned route.
  static String get currentRouteForTest => _currentRoute;

  /// @visibleForTesting — pinned locale.
  static String get appLocaleForTest => _appLocale;

  /// @visibleForTesting — reset all in-memory state so a test can
  /// start from a clean slate. Does NOT touch the FlutterError /
  /// PlatformDispatcher hooks (those are global; tests don't install
  /// them).
  static void resetForTest() {
    _breadcrumbs.clear();
    _appLocale = 'en';
    _currentRoute = '';
    _sessionId = null;
    _initialised = true; // skip the init() guard so breadcrumb() works
  }

  /// @visibleForTesting — `_trim` exposed so tests can verify the
  /// payload-cap edge cases.
  static String trimForTest(String s, int max) => _trim(s, max);

  /// @visibleForTesting — the benign-noise predicate, so tests can
  /// verify which reports are dropped before send.
  static bool isIgnorableNoiseForTest(String error, String stack) =>
      _isIgnorableNoise(error, stack);

  static String _generateSessionId() {
    final now = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    // ~36 bits of entropy is plenty for in-flight dedup; not security-grade.
    final rand =
        DateTime.now().microsecondsSinceEpoch.toRadixString(36).substring(0, 6);
    return '$now-$rand';
  }
}

class _Breadcrumb {
  final DateTime timestamp;
  final String action;
  final String? data;
  _Breadcrumb({required this.timestamp, required this.action, this.data});
}
