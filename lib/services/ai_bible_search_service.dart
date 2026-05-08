import 'dart:async' show TimeoutException;
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:yswords/constants/ui_strings.dart';

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
  }) async {
    if (query.trim().length < 2) {
      return AiBibleSearchResult.empty();
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
      return AiBibleSearchResult.unavailable(
          'YsWords search took too long. Please try again or rephrase.');
    } catch (_) {
      return AiBibleSearchResult.unavailable(
          'YsWords search is not available right now.');
    }
    if (resp.statusCode == 404) {
      return AiBibleSearchResult.unavailable(
          'YsWords search is not available yet (function not deployed).');
    }
    // 2026-05-08 (v1.1.8): split the previously-conflated 503 path
    // into two distinct cases so the user sees the actual cause:
    //   • 503 = function deployed but no API key in Netlify env
    //     (real "developer needs to configure")
    //   • 429 = quota for the developer's shared key is used up
    //     for the day. User-actionable: wait, or paste their own
    //     Gemini API key in Settings → AI to use their own quota.
    // Prefer the server's own `error` message body when present so
    // we keep useful detail (which Gemini sub-status etc.).
    String? serverError() {
      try {
        final j = jsonDecode(resp.body);
        if (j is Map && j['error'] is String) return j['error'] as String;
      } catch (_) {}
      return null;
    }
    // 2026-05-08 (v1.1.11 polish): localize the fallback strings via
    // uiStrings + the request `locale`. The server's `error` body is
    // still preferred because the backend already produces it in the
    // same locale; these strings only surface on the rare path where
    // the function returns a status code without a usable body.
    if (resp.statusCode == 503) {
      return AiBibleSearchResult.unavailable(
        serverError() ??
            uiStrings['aiNotConfiguredFallback']?[locale] ??
            'YsWords AI is not configured. The developer needs to set '
                'GEMINI_API_KEY in Netlify env.',
      );
    }
    if (resp.statusCode == 429) {
      return AiBibleSearchResult.unavailable(
        serverError() ??
            uiStrings['aiQuotaExhaustedFallback']?[locale] ??
            'YsWords AI quota for the developer\'s shared key is used '
                'up for today. Try again tomorrow, or paste your own '
                'Gemini API key in Settings → AI to use your own quota.',
      );
    }
    if (resp.statusCode != 200) {
      return AiBibleSearchResult.unavailable(
        serverError() ?? 'YsWords search returned ${resp.statusCode}.',
      );
    }
    try {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return AiBibleSearchResult.fromJson(body);
    } catch (_) {
      return AiBibleSearchResult.unavailable(
          'YsWords search returned an unexpected response.');
    }
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
