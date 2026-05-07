import 'dart:async' show TimeoutException;
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'package:yswords/services/browser_info_stub.dart'
    if (dart.library.js_interop) 'package:yswords/services/browser_info_web.dart';

/// 2026-05-07 (v12 → v14): client wrapper for the
/// `/api/submitFeedback` Netlify Function. POSTs the user's
/// feedback form, returns a structured result the UI can branch on.
///
/// v14: now also bundles client-side diagnostic info (screen size,
/// device pixel ratio, theme, timezone offset, user-local
/// timestamp, browser language, browser user-agent) so the
/// developer has everything needed to reproduce a bug without a
/// follow-up. Server-side adds IP / country / referer from the
/// request headers.
///
/// Failure mode the caller should handle:
///   - `unconfigured == true` (HTTP 503): the function exists but
///     RESEND_API_KEY isn't set in Netlify env. Caller should fall
///     back to mailto: so feedback is never silently lost.
///   - `ok == false` with a non-null `errorMessage`: anything else
///     (network down, Resend rejected, malformed payload).
class FeedbackService {
  static const String _defaultEndpoint = '/api/submitFeedback';

  static const String endpoint = String.fromEnvironment(
    'FEEDBACK_URL',
    defaultValue: _defaultEndpoint,
  );

  /// Submit a feedback payload. [context] is required so we can
  /// pull MediaQuery.size / devicePixelRatio / platformBrightness
  /// for the diagnostic block.
  ///
  /// [authEmail] is the user's Firebase / cloud sign-in email when
  /// signed in (empty for guests). It's always included in the
  /// diagnostic block, regardless of [wantsCopy] -- so the dev
  /// always knows who submitted feedback when the user is signed in.
  ///
  /// [copyEmail] + [wantsCopy] control the optional CC: the server
  /// will attempt to CC the user at [copyEmail] when [wantsCopy] is
  /// true, falling back gracefully if Resend rejects the CC (e.g.
  /// the dev hasn't verified a sending domain yet, in which case
  /// the free-tier sandbox refuses non-owner recipients).
  static Future<FeedbackResult> submit({
    required BuildContext context,
    required String category,
    required String message,
    String? name,
    String? replyTo,
    String? copyEmail,
    bool wantsCopy = false,
    String? authEmail,
    String? appLocale,
    String? bibleVersion,
    String? position,
  }) async {
    // Gather client-side diagnostic info. All of this gets attached
    // to the email body server-side.
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final dpr = mq.devicePixelRatio;
    final isDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    final tzOffset = DateTime.now().timeZoneOffset;
    final tzMin = tzOffset.inMinutes;
    final tzSign = tzMin >= 0 ? '+' : '-';
    final tzHH = (tzMin.abs() ~/ 60).toString().padLeft(2, '0');
    final tzMM = (tzMin.abs() % 60).toString().padLeft(2, '0');
    final tz = '$tzSign$tzHH:$tzMM';

    String two(int n) => n.toString().padLeft(2, '0');
    final localNow = DateTime.now();
    final localStr =
        '${localNow.year}-${two(localNow.month)}-${two(localNow.day)} '
        '${two(localNow.hour)}:${two(localNow.minute)}:${two(localNow.second)}';

    final browser = readBrowserInfo();

    final body = jsonEncode({
      'category': category,
      'message': message,
      if (name != null && name.isNotEmpty) 'name': name,
      if (replyTo != null && replyTo.isNotEmpty) 'replyTo': replyTo,
      // v15: signed-in email + opt-in CC. authEmail is always
      // attached when the user is signed in (so the dev knows who
      // submitted). copyEmail + wantsCopy drive the CC attempt.
      if (authEmail != null && authEmail.isNotEmpty)
        'authEmail': authEmail,
      if (copyEmail != null && copyEmail.isNotEmpty)
        'copyEmail': copyEmail,
      'wantsCopy': wantsCopy,
      if (appLocale != null && appLocale.isNotEmpty) 'locale': appLocale,
      if (bibleVersion != null && bibleVersion.isNotEmpty)
        'version': bibleVersion,
      if (position != null && position.isNotEmpty) 'position': position,
      // Diagnostic block — purely informational, no PII other than
      // what the user typed.
      'screenWidth': size.width.round(),
      'screenHeight': size.height.round(),
      'devicePixelRatio': dpr.toStringAsFixed(2),
      'theme': isDark ? 'dark' : 'light',
      'timezone': tz,
      'clientLocalTime': localStr,
      if (browser.browserLocale.isNotEmpty)
        'browserLocale': browser.browserLocale,
      if (browser.userAgent.isNotEmpty) 'userAgent': browser.userAgent,
    });

    http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      return FeedbackResult.error(
          'Submission timed out. Please try again.');
    } catch (_) {
      return FeedbackResult.error(
          'Could not reach the feedback service.');
    }
    if (resp.statusCode == 200) {
      return FeedbackResult.ok();
    }
    if (resp.statusCode == 503) {
      // Function deployed but no API key; signal "fall back to
      // mailto" to the caller.
      return FeedbackResult.unconfigured();
    }
    if (resp.statusCode == 404) {
      return FeedbackResult.unconfigured();
    }
    String detail = 'HTTP ${resp.statusCode}';
    try {
      final j = jsonDecode(resp.body);
      if (j is Map && j['error'] is String) detail = j['error'] as String;
    } catch (_) {}
    return FeedbackResult.error(detail);
  }
}

class FeedbackResult {
  final bool ok;
  final bool unconfigured;
  final String? errorMessage;

  const FeedbackResult({
    required this.ok,
    required this.unconfigured,
    this.errorMessage,
  });

  factory FeedbackResult.ok() =>
      const FeedbackResult(ok: true, unconfigured: false);
  factory FeedbackResult.unconfigured() => const FeedbackResult(
        ok: false,
        unconfigured: true,
        errorMessage: 'Feedback service not configured.',
      );
  factory FeedbackResult.error(String msg) =>
      FeedbackResult(ok: false, unconfigured: false, errorMessage: msg);
}
