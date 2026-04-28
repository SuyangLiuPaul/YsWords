import 'dart:async' show TimeoutException;
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Calls the YsWords Cloud Function that proxies Gemini for AI-powered
/// search over the Bible Evidence dataset.
///
/// The function lives in `functions/index.js` and is deployed to:
///   https://us-central1-ysword.cloudfunctions.net/aiSearch
///
/// We deliberately go through Cloud Functions so the Gemini service
/// account key never ends up in the client bundle (the previous
/// bible-evidence React project leaked 5 keys exactly because Vite
/// inlines `VITE_*` env vars).
class AiSearchService {
  /// Production endpoint. Override with `--dart-define=AI_SEARCH_URL=...`
  /// for emulator / staging.
  static const String _defaultEndpoint =
      'https://us-central1-ysword.cloudfunctions.net/aiSearch';

  static const String endpoint = String.fromEnvironment(
    'AI_SEARCH_URL',
    defaultValue: _defaultEndpoint,
  );

  /// Returns the Gemini-generated answer plus a list of cited evidence
  /// entries. Throws on network / server error.
  static Future<AiSearchResult> ask({
    required String query,
    required String locale,
  }) async {
    if (query.trim().length < 2) {
      return AiSearchResult.empty();
    }
    final http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'query': query, 'locale': locale}),
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      // Friendly message — the dialog renders this verbatim. We avoid
      // leaking the raw `TimeoutException` ToString which says
      // "Timeout after 0:00:25.000000" and confuses non-technical
      // users.
      throw const AiSearchException(
        'The AI search took too long. Please try again or rephrase '
        'your question.',
      );
    } catch (e) {
      // Network unreachable, DNS failure, etc. The Cloud Function
      // is also not deployed yet for some users — surface the
      // underlying message but keep it short.
      throw AiSearchException(
        'Could not reach the AI search service. (${e.runtimeType})',
      );
    }

    if (resp.statusCode != 200) {
      throw AiSearchException(
        'AI search failed (${resp.statusCode}). '
        '${resp.body.length > 160 ? "${resp.body.substring(0, 160)}…" : resp.body}',
      );
    }
    try {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return AiSearchResult.fromJson(body);
    } catch (_) {
      throw const AiSearchException(
        'Got an unexpected response from the AI search service.',
      );
    }
  }
}

/// User-facing exception class. Implementations of `toString()` show
/// the message verbatim (no `Exception:` prefix), so the dialog can
/// render `e.toString()` without extra wrangling.
class AiSearchException implements Exception {
  final String message;
  const AiSearchException(this.message);
  @override
  String toString() => message;
}

class AiSearchResult {
  final String answer;
  final List<AiCitation> citations;
  final int hits;

  AiSearchResult({
    required this.answer,
    required this.citations,
    required this.hits,
  });

  factory AiSearchResult.empty() =>
      AiSearchResult(answer: '', citations: const [], hits: 0);

  factory AiSearchResult.fromJson(Map<String, dynamic> j) {
    final raw = (j['citations'] as List?) ?? const [];
    return AiSearchResult(
      answer: (j['answer'] as String?) ?? '',
      citations: raw
          .whereType<Map<String, dynamic>>()
          .map(AiCitation.fromJson)
          .toList(),
      hits: (j['hits'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isEmpty => answer.isEmpty && citations.isEmpty;
}

class AiCitation {
  final String id;
  final String title;
  final String scriptureReference;

  AiCitation({
    required this.id,
    required this.title,
    required this.scriptureReference,
  });

  factory AiCitation.fromJson(Map<String, dynamic> j) => AiCitation(
        id: (j['id'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        scriptureReference: (j['scriptureReference'] as String?) ?? '',
      );
}
