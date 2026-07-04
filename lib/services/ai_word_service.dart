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
    /// v1.3.68 — optional free-text question about the passage from the
    /// reading-pane AI panel's "ask a question" box. When non-empty the
    /// server answers THIS question (grounded in the passage) instead of
    /// the default whole-passage explanation. Empty / null ⇒ unchanged
    /// default-explanation behaviour.
    String? userQuestion,
    /// v1.3.73 — compact transcript of earlier turns in the study-panel
    /// conversation (the client assembles "Q: … / A: …"), so follow-up
    /// questions stay coherent. Server clamps + sanitises it.
    String? history,
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
      if (userQuestion != null && userQuestion.trim().isNotEmpty)
        'userQuestion': userQuestion.trim(),
      if (history != null && history.trim().isNotEmpty)
        'history': history.trim(),
    };
    return _send(body);
  }

  /// Shared POST + error/parse used by both [explain] and [explainVerse].
  /// Never throws — failures map to [AiWordResult.unavailable] with a
  /// human-readable reason.
  ///
  /// 2026-06-30 robustness: retries TRANSIENT failures — network error,
  /// timeout, and HTTP 5xx (e.g. Gemini's brief "high demand" 503) — up to 3
  /// attempts with short backoff, so a momentary spike self-heals before the
  /// user ever sees an error. Terminal failures (429 quota, 401/403 auth, 404
  /// not-deployed, empty 200) return immediately — an instant retry won't help.
  static Future<AiWordResult> _send(Map<String, dynamic> body) async {
    const backoffs = <Duration>[
      Duration.zero,
      Duration(milliseconds: 700),
      Duration(milliseconds: 1800),
    ];
    var transientReason = 'AI is busy right now. Please try again in a moment.';
    for (var attempt = 0; attempt < backoffs.length; attempt++) {
      if (backoffs[attempt] > Duration.zero) {
        await Future<void>.delayed(backoffs[attempt]);
      }
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
        transientReason = 'The AI took too long. Please try again.';
        continue; // transient → retry
      } catch (_) {
        transientReason = 'AI is not available right now (network issue).';
        continue; // transient → retry
      }
      final code = resp.statusCode;
      if (code == 200) {
        try {
          final j = jsonDecode(resp.body) as Map<String, dynamic>;
          final exp = (j['explanation'] as String?)?.trim() ?? '';
          if (exp.isNotEmpty) return AiWordResult.ok(exp);
          return AiWordResult.unavailable('AI returned an empty response.');
        } catch (_) {
          return AiWordResult.unavailable(
              'AI explanation returned an unexpected response.');
        }
      }
      // Non-200: prefer the function's own `error` reason when present.
      String reason;
      if (code == 404) {
        reason = 'AI explanation is not available yet (function not deployed).';
      } else {
        reason = 'AI explanation returned an error ($code).';
        try {
          final j = jsonDecode(resp.body) as Map<String, dynamic>;
          final r = (j['error'] as String?)?.trim();
          if (r != null && r.isNotEmpty) reason = r;
        } catch (_) {/* keep generic */}
      }
      // 5xx = transient upstream → retry; 429/auth/404/other-4xx are terminal.
      if (code >= 500 && code < 600) {
        transientReason = 'AI is busy right now. Please try again in a moment.';
        continue;
      }
      return AiWordResult.unavailable(reason);
    }
    return AiWordResult.unavailable(transientReason); // retries exhausted
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
