import 'dart:async' show TimeoutException;
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/api_base.dart';

/// Calls the YsWords Cloud Function that proxies Gemini for AI-
/// powered Bible reference search. Different from `AiSearchService`
/// (which queries the Bible Evidence corpus): this returns raw Bible
/// references like `John 3:16` that the caller resolves against
/// whatever Bible version the user currently has loaded.
///
/// Why a separate service: the prompt + return shape are quite
/// different from evidence search (refs vs evidence-id citations),
/// and forcing them through one service would add a "mode" branch
/// to every call site.
///
/// Endpoint: `/api/aiBibleSearch` (Netlify function in
/// `netlify/functions/aiBibleSearch.mjs`).
class AiBibleSearchService {
  static const String _defaultEndpoint = '/api/aiBibleSearch';

  static const String endpoint = String.fromEnvironment(
    'AI_BIBLE_SEARCH_URL',
    defaultValue: _defaultEndpoint,
  );

  /// Returns up to 10 Bible references that the LLM thinks match the
  /// user's query (which may be a topic, half-remembered phrase,
  /// theme, or paraphrase). Returns
  /// [AiBibleSearchResult.unavailable] when the function is
  /// unreachable / not deployed / errored — callers fall back to the
  /// regular keyword search results without showing a scary error.
  static Future<AiBibleSearchResult> ask({
    required String query,
    required String locale,
    String? userApiKey,
    // 2026-05-10 (v1.2.26): forward the user's chosen AI model
    // tier ('flash-lite' / 'flash' / 'pro') to the function.
    // Server allowlist-clamps invalid values back to default.
    String? aiModel,
  }) async {
    // 2026-05-11 (v1.2.43): lowered from `< 2` to `< 1` so single-
    // character CJK queries (e.g. `爱` / `信`) reach the backend.
    if (query.trim().isEmpty) {
      return AiBibleSearchResult.empty();
    }
    // 2026-06-30 robustness: retry TRANSIENT failures (network, timeout, HTTP
    // 5xx — e.g. Gemini's brief "high demand" 503) up to 3 attempts with short
    // backoff, so a momentary spike self-heals before we give up. Terminal
    // failures (404, 429 quota, other 4xx) return immediately. Same body across
    // attempts.
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
    var transientReason = 'YsWords AI is busy right now. Please try again.';
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
            'YsWords search took too long. Please try again or rephrase.';
        continue; // transient → retry
      } catch (_) {
        transientReason = 'YsWords search is not available right now.';
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
          return AiBibleSearchResult.fromJson(body);
        } catch (_) {
          return AiBibleSearchResult.unavailable(
              'YsWords search returned an unexpected response.');
        }
      }
      if (code == 404) {
        return AiBibleSearchResult.unavailable(
            'YsWords search is not available yet (function not deployed).');
      }
      if (code == 429) {
        return AiBibleSearchResult.unavailable(
          serverError() ??
              uiStrings['aiQuotaExhaustedFallback']?[locale] ??
              'YsWords AI quota for the developer\'s shared key is used '
                  'up for today. Try again tomorrow, or paste your own '
                  'Gemini API key in Settings → AI to use your own quota.',
        );
      }
      // 5xx (incl. transient 503 "high demand") → retry; keep the server's
      // message as the fallback shown if every attempt fails.
      if (code >= 500 && code < 600) {
        transientReason = serverError() ??
            uiStrings['aiNotConfiguredFallback']?[locale] ??
            transientReason;
        continue;
      }
      return AiBibleSearchResult.unavailable(
        serverError() ?? 'YsWords search returned $code.',
      );
    }
    return AiBibleSearchResult.unavailable(transientReason); // retries exhausted
  }
}

/// One Bible reference returned by the AI search. The `book` is the
/// canonical English book name (e.g. "Matthew", "1 Corinthians",
/// "Song of Solomon") regardless of the user's locale — call sites
/// resolve that to the user's current Bible version's localized
/// book name via the existing version-mapper utility.
class AiBibleRef {
  final String book;
  final int chapter;
  final int verseStart;
  final int verseEnd;
  /// One-sentence localized explanation of why this reference matches
  /// the user's query. Already in the user's locale (the prompt asks
  /// the model to write it that way).
  final String reason;

  const AiBibleRef({
    required this.book,
    required this.chapter,
    required this.verseStart,
    required this.verseEnd,
    required this.reason,
  });

  factory AiBibleRef.fromJson(Map<String, dynamic> j) => AiBibleRef(
        book: (j['book'] as String? ?? '').trim(),
        chapter: (j['chapter'] as num? ?? 0).toInt(),
        verseStart: (j['verseStart'] as num? ?? 0).toInt(),
        verseEnd: (j['verseEnd'] as num? ?? 0).toInt(),
        reason: (j['reason'] as String? ?? '').trim(),
      );

  /// "Matthew 5:3-12" / "John 3:16" — used in citation chips.
  String get display => verseStart == verseEnd
      ? '$book $chapter:$verseStart'
      : '$book $chapter:$verseStart-$verseEnd';
}

class AiBibleSearchResult {
  final List<AiBibleRef> refs;
  final int hits;

  /// Non-null when the AI service couldn't answer. Caller surfaces
  /// the reason as a small note + falls back to the regular keyword
  /// search.
  final String? unavailableReason;

  const AiBibleSearchResult({
    required this.refs,
    required this.hits,
    this.unavailableReason,
  });

  factory AiBibleSearchResult.empty() =>
      const AiBibleSearchResult(refs: [], hits: 0);

  factory AiBibleSearchResult.unavailable(String reason) =>
      AiBibleSearchResult(refs: const [], hits: 0, unavailableReason: reason);

  factory AiBibleSearchResult.fromJson(Map<String, dynamic> j) {
    final raw = (j['refs'] as List? ?? const []).cast<dynamic>();
    final refs = raw
        .whereType<Map>()
        .map((m) => AiBibleRef.fromJson(Map<String, dynamic>.from(m)))
        .where((r) => r.book.isNotEmpty && r.chapter > 0 && r.verseStart > 0)
        .toList();
    return AiBibleSearchResult(refs: refs, hits: refs.length);
  }

  bool get unavailable => unavailableReason != null;
  bool get isEmpty => refs.isEmpty;
}
