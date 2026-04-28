import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/news_article.dart';

/// Loads the bilingual DailyNews bundle (~37 stories × 3 sections,
/// migrated from the sunsetting `bible-evidence` sibling project
/// `~/Documents/CodingProject/DailyNews/`).
///
/// Source-of-truth strategy:
///   1. Try to fetch fresh JSON from `_remoteUrl` (DailyNews's deployed
///      Netlify host) in the background and cache to SharedPreferences.
///   2. On startup, prefer the cached copy if it's fresher than the
///      bundled snapshot.
///   3. Fall back to the bundled `assets/daily_news.json` so the app
///      always has *something* to show, even offline.
///
/// The Flutter UI never blocks on network — it shows whatever is in
/// memory immediately, then `refresh()` swaps in fresher data when it
/// arrives.
class DailyNewsService {
  /// Bundled snapshot path.
  static const String _bundledAsset = 'assets/daily_news.json';

  /// Endpoint that the DailyNews GitHub Actions workflow publishes to
  /// after every successful refresh window. We point at the Netlify
  /// `public/` mirror that the action writes — see `HANDOFF.md`'s
  /// "Daily News — refresh pipeline" section for the GH Actions diff
  /// that exposes this file.
  ///
  /// Override at runtime via `--dart-define=DAILY_NEWS_URL=...`.
  static const String _defaultRemote =
      'https://newsbible.netlify.app/data/latest-news.json';

  static const String _remoteUrl = String.fromEnvironment(
    'DAILY_NEWS_URL',
    defaultValue: _defaultRemote,
  );

  static const String _cachePrefsKey = 'dailyNews.cachedJson.v1';
  static const String _cacheTimePrefsKey = 'dailyNews.cachedAt.v1';

  static DailyNewsBundle? _cached;
  static Future<DailyNewsBundle>? _inflight;

  /// Returns the best bundle available right now (cached → bundled).
  /// First call triggers a background `refresh()` so the next call
  /// sees fresher data without the user having to do anything.
  static Future<DailyNewsBundle> load() {
    if (_cached != null) {
      // Fire-and-forget refresh on every load; cheap and keeps the
      // dataset current as the user keeps the app open.
      // ignore: unawaited_futures
      refresh();
      return Future.value(_cached!);
    }
    return _inflight ??= _firstLoad();
  }

  static Future<DailyNewsBundle> _firstLoad() async {
    // 1. Try cached.
    final fromCache = await _loadFromPrefs();
    if (fromCache != null) {
      _cached = fromCache;
      // Background refresh.
      // ignore: unawaited_futures
      refresh();
      return fromCache;
    }
    // 2. Fall back to bundled.
    final raw = await rootBundle.loadString(_bundledAsset);
    final bundled =
        DailyNewsBundle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _cached = bundled;
    // Kick off remote refresh in background.
    // ignore: unawaited_futures
    refresh();
    return bundled;
  }

  /// Forces a network fetch. Updates the in-memory cache and prefs
  /// when fresher data arrives. Swallows network errors silently —
  /// callers should treat this as best-effort.
  static Future<void> refresh() async {
    try {
      final resp = await http
          .get(Uri.parse(_remoteUrl))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return;
      final body = resp.body;
      final j = jsonDecode(body) as Map<String, dynamic>;
      final fresh = DailyNewsBundle.fromJson(j);
      // Only swap if the fetched edition is at least as new as what
      // we already have in memory.
      if (_cached != null &&
          _cached!.generatedAt != null &&
          fresh.generatedAt != null &&
          fresh.generatedAt!.isBefore(_cached!.generatedAt!)) {
        return;
      }
      _cached = fresh;
      // Persist for next launch.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachePrefsKey, body);
      await prefs.setString(
        _cacheTimePrefsKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {
      // Best-effort. Network down, server slow, malformed JSON — all
      // recoverable; we keep showing whatever the UI already has.
    }
  }

  static Future<DailyNewsBundle?> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachePrefsKey);
      if (raw == null || raw.isEmpty) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return DailyNewsBundle.fromJson(j);
    } catch (_) {
      return null;
    }
  }

  /// Headlines for the dashboard "Today's News" card — picks the
  /// freshest article from each section so the user gets a balanced
  /// 3-up snapshot.
  ///
  /// Dedupes across sections: when the same Guardian story appears in
  /// both /world/rss AND /australia-news/rss the upstream pipeline
  /// keeps both copies, but we don't want the dashboard to show the
  /// same headline twice. We pick the freshest unseen story per
  /// section, falling through to deeper items if the first is a dup.
  static List<NewsArticle> dashboardHeadlines(DailyNewsBundle bundle) {
    final out = <NewsArticle>[];
    final seenTitles = <String>{};
    final seenLinks = <String>{};
    for (final s in bundle.sections) {
      for (final a in s.items) {
        final titleKey =
            a.titleEn.trim().toLowerCase();
        final linkKey = a.link.trim();
        if (titleKey.isNotEmpty && seenTitles.contains(titleKey)) continue;
        if (linkKey.isNotEmpty && seenLinks.contains(linkKey)) continue;
        out.add(a);
        if (titleKey.isNotEmpty) seenTitles.add(titleKey);
        if (linkKey.isNotEmpty) seenLinks.add(linkKey);
        break; // one per section
      }
    }
    return out;
  }
}
