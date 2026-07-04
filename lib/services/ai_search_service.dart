import 'dart:async' show TimeoutException;
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/api_base.dart';

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
/// Status (2026-05-10, v1.2.31): the backend is **deployed** as a
/// Netlify Function at `/api/aiSearch` (`netlify/functions/aiSearch.mjs`).
/// The original "scaffolded but not deployed" branch shipped with
/// the v1.0.0 line predates the Cloud-Functions → Netlify-Functions
/// migration in round 52. `ask()` calls the live endpoint and only
/// returns `AiSearchResult.empty().markUnavailable()` on a 4xx/5xx /
/// network failure / not-configured response, in which case the
/// caller (search/evidence pages) falls back to local keyword search
/// with an inline notice + a "Set up your own Gemini key" CTA
/// pointing at the BYOK card in Settings (v1.1.10 +).
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
    /// v1.2.26 — picks the Gemini model tier on the server.
    String? aiModel,
  }) async {
    // v1.2.43: lowered from `< 2` to allow 1-char CJK queries.
    if (query.trim().isEmpty) {
      return AiSearchResult.empty();
    }
    // 2026-06-30 robustness: retry TRANSIENT failures (network, timeout, HTTP
    // 5xx — e.g. Gemini's brief "high demand" 503) up to 3 attempts with short
    // backoff, so a momentary spike self-heals before we downgrade to keyword
    // search. Terminal failures (404 not-deployed, 429 quota, other 4xx) return
    // immediately. Same body across attempts.
    final reqBody = jsonEncode({
      'query': query,
      'locale': locale,
      if (userApiKey != null && userApiKey.isNotEmpty) 'userApiKey': userApiKey,
      if (aiModel != null && aiModel.isNotEmpty) 'aiModel': aiModel,
    });
    const backoffs = <Duration>[
      Duration.zero,
      Duration(milliseconds: 700),
      Duration(milliseconds: 1800),
    ];
    var transientReason =
        'YsWords AI is busy right now. Showing keyword matches — tap Ask to '
        'try again.';
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
              body: reqBody,
            )
            .timeout(const Duration(seconds: 60));
      } on TimeoutException {
        transientReason =
            'The AI search took too long. Please try again or rephrase '
            'your question.';
        continue; // transient → retry
      } catch (_) {
        // Network / DNS / CORS / not-deployed. No runtimeType — release
        // builds minify it to meaningless names.
        transientReason =
            'YsWords search is not available right now. Showing keyword '
            'matches instead.';
        continue; // transient → retry
      }
      final code = resp.statusCode;
      String? serverError() {
        try {
          final j = jsonDecode(resp.body);
          if (j is Map && j['error'] is String) return j['error'] as String;
        } catch (_) {}
        return null;
      }
      if (code == 200) {
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
      if (code == 404) {
        return AiSearchResult.unavailable(
          'YsWords search is not available yet. Showing keyword matches '
          'instead.',
        );
      }
      if (code == 429) {
        return AiSearchResult.unavailable(
          serverError() ??
              uiStrings['aiQuotaExhaustedFallback']?[locale] ??
              'YsWords AI quota for the developer\'s shared key is used '
                  'up for today. Try again tomorrow, or paste your own '
                  'Gemini API key in Settings → AI.',
        );
      }
      // 5xx (incl. the transient 503 "high demand") → retry; keep the
      // server's message as the fallback shown if every attempt fails.
      if (code >= 500 && code < 600) {
        transientReason = serverError() ?? transientReason;
        continue;
      }
      // Other terminal non-2xx.
      return AiSearchResult.unavailable(
        serverError() ??
            'YsWords search returned an error ($code). Showing keyword '
                'matches instead.',
      );
    }
    return AiSearchResult.unavailable(transientReason); // retries exhausted
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
