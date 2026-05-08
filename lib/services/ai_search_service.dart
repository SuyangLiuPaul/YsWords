import 'dart:async' show TimeoutException;
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:yswords/constants/ui_strings.dart';

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
///
/// Status of the function (2026-04-28): scaffolded but **not deployed**
/// — needs `firebase login` + `firebase deploy --only functions` from
/// the repo owner. Until then `ask()` returns `AiSearchResult.empty()
/// .markUnavailable()` so callers can fall back to local search
/// without surfacing a confusing error to non-technical users.
class AiSearchService {
  /// Production endpoint. Same-origin call to the Netlify Function
  /// at `/api/aiSearch` (Netlify rewrites this to `/.netlify/
  /// functions/aiSearch`). Same-origin means no CORS preflight.
  ///
  /// Override at build time via `--dart-define=AI_SEARCH_URL=...`
  /// for emulator / staging — e.g. point at
  /// `http://localhost:8888/.netlify/functions/aiSearch` when running
  /// `netlify dev` locally.
  ///
  /// The legacy URL `https://us-central1-ysword.cloudfunctions.net/aiSearch`
  /// was retired in round 52 — Cloud Functions required the Blaze
  /// (pay-as-you-go) Firebase plan, which we opted not to enable.
  static const String _defaultEndpoint = '/api/aiSearch';

  static const String endpoint = String.fromEnvironment(
    'AI_SEARCH_URL',
    defaultValue: _defaultEndpoint,
  );

  /// Returns the Gemini-generated answer plus a list of cited evidence
  /// entries. Returns `AiSearchResult.unavailable(reason)` when the
  /// Cloud Function is unreachable / not deployed / errored — callers
  /// inspect `result.unavailable` and decide whether to fall back to
  /// local keyword search.
  ///
  /// The reason string is human-readable and meant for direct rendering
  /// (no internal class names, no minified runtime types).
  static Future<AiSearchResult> ask({
    required String query,
    required String locale,
    /// User-supplied Gemini API key (BYOK). When non-empty, the
    /// Netlify function uses this key instead of the developer's
    /// shared key. See AiWordService.explain for the rationale.
    String? userApiKey,
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
            body: jsonEncode({
              'query': query,
              'locale': locale,
              if (userApiKey != null && userApiKey.isNotEmpty)
                'userApiKey': userApiKey,
            }),
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      return AiSearchResult.unavailable(
        'The AI search took too long. Please try again or rephrase '
        'your question.',
      );
    } catch (_) {
      // Network unreachable, DNS failure, CORS preflight reject, or
      // the function isn't deployed yet (the most common case). We
      // deliberately do NOT include `e.runtimeType` here — in
      // release builds it produces minified names like "td" that
      // mean nothing to users.
      return AiSearchResult.unavailable(
        'YsWords search is not available right now. Showing keyword '
        'matches instead.',
      );
    }

    if (resp.statusCode == 404) {
      // Function isn't deployed at this URL yet.
      return AiSearchResult.unavailable(
        'YsWords search is not available yet. Showing keyword matches '
        'instead.',
      );
    }
    // 2026-05-08 (v1.1.8): surface the server's actual error body
    // when present so users see "quota exhausted, try again later"
    // (HTTP 429 from the function) instead of a generic
    // "returned an error". Previous text "Showing keyword matches
    // instead" stays as a fallback when no server-side detail is
    // available.
    String? serverError() {
      try {
        final j = jsonDecode(resp.body);
        if (j is Map && j['error'] is String) return j['error'] as String;
      } catch (_) {}
      return null;
    }
    // 2026-05-08 (v1.1.11 polish): localize the 429 / 503 fallback
    // strings. Server `error` body is still preferred (backend
    // already produces it in the user's locale); these only surface
    // when the function returns a code without a parseable body.
    if (resp.statusCode == 429) {
      return AiSearchResult.unavailable(
        serverError() ??
            uiStrings['aiQuotaExhaustedFallback']?[locale] ??
            'YsWords AI quota for the developer\'s shared key is used '
                'up for today. Try again tomorrow, or paste your own '
                'Gemini API key in Settings → AI.',
      );
    }
    if (resp.statusCode == 503) {
      return AiSearchResult.unavailable(
        serverError() ??
            uiStrings['aiNotConfiguredFallback']?[locale] ??
            'YsWords AI is not configured. The developer needs to set '
                'GEMINI_API_KEY in Netlify env.',
      );
    }
    if (resp.statusCode != 200) {
      return AiSearchResult.unavailable(
        serverError() ??
            'YsWords search returned an error (${resp.statusCode}). '
                'Showing keyword matches instead.',
      );
    }
    try {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return AiSearchResult.fromJson(body);
    } catch (_) {
      return AiSearchResult.unavailable(
        'YsWords search returned an unexpected response. Showing '
        'keyword matches instead.',
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

  /// Non-null when the AI service couldn't answer (404, timeout,
  /// network blip). The dialog uses this to switch to local keyword
  /// search and shows the reason string as a contextual note.
  final String? unavailableReason;

  AiSearchResult({
    required this.answer,
    required this.citations,
    required this.hits,
    this.unavailableReason,
  });

  factory AiSearchResult.empty() =>
      AiSearchResult(answer: '', citations: const [], hits: 0);

  factory AiSearchResult.unavailable(String reason) => AiSearchResult(
        answer: '',
        citations: const [],
        hits: 0,
        unavailableReason: reason,
      );

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
  bool get unavailable => unavailableReason != null;
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
