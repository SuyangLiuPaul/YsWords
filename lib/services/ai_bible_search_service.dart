import 'dart:async' show TimeoutException;
import 'dart:convert';

import 'package:http/http.dart' as http;

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
    if (resp.statusCode == 503) {
      // Function deployed but no API key configured — surface that
      // distinct case so the developer's diagnostic catches it.
      return AiBibleSearchResult.unavailable(
          'YsWords search is not configured. Developer needs to set '
          'GEMINI_API_KEY in Netlify env.');
    }
    if (resp.statusCode != 200) {
      return AiBibleSearchResult.unavailable(
          'YsWords search returned ${resp.statusCode}.');
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
