import 'dart:async' show TimeoutException;
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:yswords/services/api_base.dart';

/// Asks the YsWords Cloud Function to explain a Hebrew/Greek word
/// in the context of a specific verse. Sister of [AiSearchService] —
/// uses the same Netlify Function pipeline + Gemini API key.
///
/// Endpoint: `/api/aiExplainWord` (Netlify rewrites to
/// `/.netlify/functions/aiExplainWord`).
class AiWordService {
  static const String _defaultEndpoint = '/api/aiExplainWord';
  static const String endpoint = String.fromEnvironment(
    'AI_EXPLAIN_WORD_URL',
    defaultValue: _defaultEndpoint,
  );

  /// Returns a 80-180 word plain-prose explanation of the original-
  /// language word as used in the cited verse, in the user's locale.
  /// Returns [AiWordResult.unavailable] when the function isn't
  /// reachable / not deployed / errored — callers can render the
  /// reason as a SnackBar without the underlying network details
  /// leaking through.
  /// [length] is one of `default` / `concise` / `longer` and [scope]
  /// is one of `verse` / `chapter` / `book` / `wholeBible` /
  /// `otherChapters`. Defaults match round-53 behaviour: a focused
  /// 150-260 word explanation grounded in the cited verse.
  static Future<AiWordResult> explain({
    required String strongs,
    required String lemma,
    String? translit,
    String? gloss,
    required String englishBook,
    required int chapter,
    required int verse,
    String? verseText,
    required String locale,
    String length = 'default',
    String scope = 'verse',
    /// User-supplied Gemini API key (BYOK). When non-empty, the
    /// Netlify function uses this key instead of the developer's,
    /// so the user's own AI Studio quota is consumed rather than
    /// the shared one. Caller (OriginalsSheet) reads this from
    /// `AppSettings.geminiApiKey`.
    String? userApiKey,
    /// v1.2.26 — Gemini model tier picked from Settings → AI.
    String? aiModel,
  }) async {
    final body = <String, dynamic>{
      'strongs': strongs,
      'lemma': lemma,
      if (translit != null && translit.isNotEmpty) 'translit': translit,
      if (gloss != null && gloss.isNotEmpty) 'gloss': gloss,
      'book': englishBook,
      'chapter': chapter,
      'verse': verse,
      if (verseText != null && verseText.isNotEmpty) 'verseText': verseText,
      'locale': locale,
      'length': length,
      'scope': scope,
      if (userApiKey != null && userApiKey.isNotEmpty)
        'userApiKey': userApiKey,
      if (aiModel != null && aiModel.isNotEmpty) 'aiModel': aiModel,
    };
    return _send(body);
  }

  /// v1.3.x: plain-language explanation of a whole verse (or short
  /// verse range) for an ordinary reader — triggered from the reading
  /// pane's selection-bar "AI explain" action. Posts to the same
  /// `/api/aiExplainWord` endpoint with `task: 'versePlain'`, which
  /// selects the verse-explanation prompt server-side. Answers in the
  /// user's [locale].
  static Future<AiWordResult> explainVerse({
    required String englishBook,
    required int chapter,
    required int verseStart,
    int? verseEnd,
    String? verseText,
    required String locale,
    String length = 'default',
    String? userApiKey,
    String? aiModel,
  }) async {
    final body = <String, dynamic>{
      'task': 'versePlain',
      'book': englishBook,
      'chapter': chapter,
      'verse': verseStart,
      if (verseEnd != null && verseEnd > verseStart) 'verseEnd': verseEnd,
      if (verseText != null && verseText.isNotEmpty) 'verseText': verseText,
      'locale': locale,
      'length': length,
      if (userApiKey != null && userApiKey.isNotEmpty)
        'userApiKey': userApiKey,
      if (aiModel != null && aiModel.isNotEmpty) 'aiModel': aiModel,
    };
    return _send(body);
  }

  /// Shared POST + error/parse used by both [explain] and
  /// [explainVerse]. Never throws — failures map to
  /// [AiWordResult.unavailable] with a human-readable reason.
  static Future<AiWordResult> _send(Map<String, dynamic> body) async {
    final http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse(resolveApiUrl(endpoint)),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      return AiWordResult.unavailable(
        'The AI explanation took too long. Please try again.',
      );
    } catch (_) {
      return AiWordResult.unavailable(
        'AI explanation is not available right now.',
      );
    }
    if (resp.statusCode == 404) {
      return AiWordResult.unavailable(
        'AI explanation is not available yet (function not deployed).',
      );
    }
    // Surface the function's `error` field directly when it provided
    // one (covers 429 quota, 503 not-configured, 401/403 bad key).
    if (resp.statusCode != 200) {
      try {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        final reason = (j['error'] as String?)?.trim();
        if (reason != null && reason.isNotEmpty) {
          return AiWordResult.unavailable(reason);
        }
      } catch (_) {/* fall through to generic message */}
      return AiWordResult.unavailable(
        'AI explanation returned an error (${resp.statusCode}).',
      );
    }
    try {
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final exp = (j['explanation'] as String?)?.trim() ?? '';
      if (exp.isEmpty) {
        return AiWordResult.unavailable('AI returned an empty response.');
      }
      return AiWordResult.ok(exp);
    } catch (_) {
      return AiWordResult.unavailable(
        'AI explanation returned an unexpected response.',
      );
    }
  }
}

class AiWordResult {
  final String explanation;
  final String? unavailableReason;

  const AiWordResult._({
    required this.explanation,
    this.unavailableReason,
  });

  factory AiWordResult.ok(String text) =>
      AiWordResult._(explanation: text);
  factory AiWordResult.unavailable(String reason) =>
      AiWordResult._(explanation: '', unavailableReason: reason);

  bool get unavailable => unavailableReason != null;
}
