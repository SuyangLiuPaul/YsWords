import 'dart:async' show TimeoutException;
import 'dart:convert';

import 'package:http/http.dart' as http;

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
    };
    final http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
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
    if (resp.statusCode == 503) {
      try {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        return AiWordResult.unavailable(
            (j['error'] as String?) ?? 'AI explanation is not configured.');
      } catch (_) {
        return AiWordResult.unavailable('AI explanation is not configured.');
      }
    }
    if (resp.statusCode != 200) {
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
