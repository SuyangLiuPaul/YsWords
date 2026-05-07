import 'dart:async' show TimeoutException;
import 'dart:convert';

import 'package:http/http.dart' as http;

/// 2026-05-07 (v12): client wrapper for the `/api/submitFeedback`
/// Netlify Function. POSTs the user's feedback form, returns a
/// structured result the UI can branch on.
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

  /// Submit a feedback payload. Returns a [FeedbackResult] indicating
  /// whether to show the success state, fall back to mailto, or show
  /// an error message.
  static Future<FeedbackResult> submit({
    required String category,
    required String message,
    String? name,
    String? replyTo,
    String? locale,
    String? version,
    String? position,
  }) async {
    final body = jsonEncode({
      'category': category,
      'message': message,
      if (name != null && name.isNotEmpty) 'name': name,
      if (replyTo != null && replyTo.isNotEmpty) 'replyTo': replyTo,
      if (locale != null && locale.isNotEmpty) 'locale': locale,
      if (version != null && version.isNotEmpty) 'version': version,
      if (position != null && position.isNotEmpty) 'position': position,
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
