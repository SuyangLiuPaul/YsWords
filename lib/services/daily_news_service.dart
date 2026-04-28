import 'package:yswords/models/news_article.dart';
import 'package:yswords/services/remote_data_service.dart';

/// Loads the bilingual DailyNews bundle.
///
/// Source: yswords-data central data repo
/// (`https://yswords-data.netlify.app/data/daily_news.json`). The
/// pipeline used to live in a separate DailyNews repo; the cron now
/// runs in `yswords-data` and writes the canonical JSON there. See
/// HANDOFF.md → "Central data source".
///
/// Override at build time:
///   `--dart-define=DAILY_NEWS_URL=https://example/data/daily_news.json`
class _DailyNewsServiceImpl extends RemoteDataService<DailyNewsBundle> {
  static const String _defaultRemote =
      'https://yswords-data.netlify.app/data/daily_news.json';

  static const String _envUrl = String.fromEnvironment(
    'DAILY_NEWS_URL',
    defaultValue: _defaultRemote,
  );

  @override
  String get bundledAssetPath => 'assets/daily_news.json';

  @override
  String get remoteUrl => _envUrl;

  @override
  String get cachePrefsKey => 'dailyNews.cachedJson.v2';

  @override
  DailyNewsBundle parse(Map<String, dynamic> json) =>
      DailyNewsBundle.fromJson(json);

  @override
  DateTime? generatedAt(DailyNewsBundle bundle) => bundle.generatedAt;
}

/// Public façade — keeps the existing call sites
/// (`DailyNewsService.load()` / `refresh()` / `dashboardHeadlines()`)
/// stable so callers don't change.
class DailyNewsService {
  static final _DailyNewsServiceImpl _impl = _DailyNewsServiceImpl();

  static Future<DailyNewsBundle> load() => _impl.load();
  static Future<void> refresh() => _impl.refresh();
  static Future<void> clearCache() => _impl.clearCache();

  /// Headlines for the dashboard "Today's News" card — picks the
  /// freshest unseen story per section so the user gets a balanced
  /// 3-up snapshot. Dedupes across sections by case-folded title +
  /// link so cross-listed Guardian stories don't appear twice.
  static List<NewsArticle> dashboardHeadlines(DailyNewsBundle bundle) {
    final out = <NewsArticle>[];
    final seenTitles = <String>{};
    final seenLinks = <String>{};
    for (final s in bundle.sections) {
      for (final a in s.items) {
        final titleKey = a.titleEn.trim().toLowerCase();
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
