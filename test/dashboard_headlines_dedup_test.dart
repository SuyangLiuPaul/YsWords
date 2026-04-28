// Verifies the dashboard "Today's Headlines" picker dedupes
// cross-listed Guardian stories that show up under both /world/rss
// AND /australia-news/rss.

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/news_article.dart';
import 'package:yswords/services/daily_news_service.dart';

NewsArticle _a(String section, String id, String title, {String? link}) {
  return NewsArticle.fromJson({
    'id': id,
    'section': section,
    'source': 'The Guardian $section',
    'sourceUrl': '',
    'link': link ?? 'https://example.com/$id',
    'image': null,
    'publishedAt': '2026-04-28T00:00:00Z',
    'title': {'en': title, 'zh': title},
    'summary': {'en': '', 'zh': ''},
    'reflection': {'en': '', 'zh': ''},
    'verse': {
      'reference': 'Genesis 1:1',
      'textEn': '',
      'textZh': '',
      'themeEn': '',
      'themeZh': '',
    },
    'translationState': 'fallback',
  });
}

DailyNewsBundle _bundle(Map<String, List<NewsArticle>> sections) {
  return DailyNewsBundle.fromJson({
    'editionDate': '2026-04-28',
    'generatedAt': '2026-04-28T00:00:00Z',
    'sections': {
      for (final entry in sections.entries)
        entry.key: {
          'id': entry.key,
          'title': {'en': entry.key, 'zh': entry.key},
          'items': [
            for (final a in entry.value)
              {
                'id': a.id,
                'section': a.section,
                'source': a.source,
                'sourceUrl': a.sourceUrl,
                'link': a.link,
                'image': a.image,
                'publishedAt': a.publishedAt?.toIso8601String(),
                'title': {'en': a.titleEn, 'zh': a.titleZh},
                'summary': {'en': a.summaryEn, 'zh': a.summaryZh},
                'reflection': {
                  'en': a.reflectionEn,
                  'zh': a.reflectionZh,
                },
                'verse': {
                  'reference': a.verse.reference,
                  'textEn': a.verse.textEn,
                  'textZh': a.verse.textZh,
                  'themeEn': a.verse.themeEn,
                  'themeZh': a.verse.themeZh,
                },
                'translationState': a.translationState,
              },
          ],
        },
    },
  });
}

void main() {
  test('picks one fresh story per section', () {
    final b = _bundle({
      'world': [
        _a('world', 'w1', 'World story 1'),
        _a('world', 'w2', 'World story 2'),
      ],
      'china': [_a('china', 'c1', 'China story 1')],
      'australia': [_a('australia', 'a1', 'Aus story 1')],
    });
    final picks = DailyNewsService.dashboardHeadlines(b);
    expect(picks.map((a) => a.id), ['w1', 'c1', 'a1']);
  });

  test('skips a duplicate cross-listed story (same title) in a '
      'later section, keeps the first occurrence', () {
    // The Guardian's "Australia news live" appears in BOTH world
    // and australia feeds — we only want it once on the dashboard.
    final dup = 'Australia news live: gas levy';
    final b = _bundle({
      'world': [_a('world', 'w-dup', dup)],
      'china': [_a('china', 'c1', 'China story')],
      'australia': [
        _a('australia', 'a-dup', dup),
        _a('australia', 'a-real', 'Real Australia story'),
      ],
    });
    final picks = DailyNewsService.dashboardHeadlines(b);
    expect(picks.map((a) => a.id), ['w-dup', 'c1', 'a-real']);
  });

  test('skips a duplicate by link when titles differ slightly', () {
    final sameLink = 'https://www.theguardian.com/x/article-42';
    final b = _bundle({
      'world': [_a('world', 'w', 'Title A', link: sameLink)],
      'china': [_a('china', 'c', 'Different headline')],
      'australia': [
        _a('australia', 'a-link', 'Title B', link: sameLink),
        _a('australia', 'a-real', 'Real Aus story'),
      ],
    });
    final picks = DailyNewsService.dashboardHeadlines(b);
    expect(picks.map((a) => a.id), ['w', 'c', 'a-real']);
  });

  test('handles a section with no items by skipping it', () {
    final b = _bundle({
      'world': [_a('world', 'w', 'W')],
      'china': [],
      'australia': [_a('australia', 'a', 'A')],
    });
    final picks = DailyNewsService.dashboardHeadlines(b);
    expect(picks.map((a) => a.id), ['w', 'a']);
  });
}
