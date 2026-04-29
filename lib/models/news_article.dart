// Models for the migrated DailyNews dataset (`assets/daily_news.json`).
//
// Mirrors the schema in DailyNews's `src/types/news.ts`. We keep the
// shape close to the source so the existing GitHub Actions pipeline
// can keep writing the same JSON without per-app transformation.

class NewsVerse {
  final String reference;
  final String textEn;
  final String textZh;
  final String themeEn;
  final String themeZh;

  NewsVerse({
    required this.reference,
    required this.textEn,
    required this.textZh,
    required this.themeEn,
    required this.themeZh,
  });

  factory NewsVerse.fromJson(Map<String, dynamic> j) => NewsVerse(
        reference: (j['reference'] as String?) ?? '',
        textEn: (j['textEn'] as String?) ?? '',
        textZh: (j['textZh'] as String?) ?? '',
        themeEn: (j['themeEn'] as String?) ?? '',
        themeZh: (j['themeZh'] as String?) ?? '',
      );

  String text(String locale) =>
      locale.startsWith('zh') && textZh.isNotEmpty ? textZh : textEn;

  String theme(String locale) =>
      locale.startsWith('zh') && themeZh.isNotEmpty ? themeZh : themeEn;
}

class NewsArticle {
  /// `world` | `china` | `australia` (kept as String for forward-compat).
  final String section;
  final String id;
  final String source;
  final String sourceUrl;
  final String link;
  final String? image;
  final DateTime? publishedAt;
  final String titleEn;
  final String titleZh;
  final String summaryEn;
  final String summaryZh;
  /// Long-form article text for the in-app detail-page reader. Empty
  /// string when no body was extracted. zh is empty when no
  /// translation was produced (caller falls back to summary.zh).
  final String bodyEn;
  final String bodyZh;
  final String reflectionEn;
  final String reflectionZh;
  final NewsVerse verse;
  final String translationState; // 'localized' | 'fallback'

  NewsArticle({
    required this.section,
    required this.id,
    required this.source,
    required this.sourceUrl,
    required this.link,
    required this.image,
    required this.publishedAt,
    required this.titleEn,
    required this.titleZh,
    required this.summaryEn,
    required this.summaryZh,
    required this.bodyEn,
    required this.bodyZh,
    required this.reflectionEn,
    required this.reflectionZh,
    required this.verse,
    required this.translationState,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> j) {
    final title = (j['title'] as Map?)?.cast<String, dynamic>() ?? const {};
    final summary = (j['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
    final body = (j['body'] as Map?)?.cast<String, dynamic>() ?? const {};
    final reflection =
        (j['reflection'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pub = j['publishedAt'] as String?;
    final en = (title['en'] as String?) ?? '';
    return NewsArticle(
      section: (j['section'] as String?) ?? 'world',
      id: (j['id'] as String?) ?? '',
      source: (j['source'] as String?) ?? '',
      sourceUrl: (j['sourceUrl'] as String?) ?? '',
      link: (j['link'] as String?) ?? '',
      image: j['image'] as String?,
      publishedAt: pub != null ? DateTime.tryParse(pub) : null,
      titleEn: en,
      titleZh: (title['zh'] as String?) ?? en,
      summaryEn: (summary['en'] as String?) ?? '',
      summaryZh:
          (summary['zh'] as String?) ?? (summary['en'] as String?) ?? '',
      bodyEn: (body['en'] as String?) ?? '',
      bodyZh: (body['zh'] as String?) ?? '',
      reflectionEn: (reflection['en'] as String?) ?? '',
      reflectionZh:
          (reflection['zh'] as String?) ?? (reflection['en'] as String?) ?? '',
      verse: NewsVerse.fromJson(
          (j['verse'] as Map?)?.cast<String, dynamic>() ?? const {}),
      translationState:
          (j['translationState'] as String?) ?? 'fallback',
    );
  }

  String title(String locale) =>
      locale.startsWith('zh') && titleZh.isNotEmpty ? titleZh : titleEn;

  String summary(String locale) =>
      locale.startsWith('zh') && summaryZh.isNotEmpty ? summaryZh : summaryEn;

  /// Long-form body in the requested locale. Falls back to whichever
  /// side is populated; returns empty string when nothing exists so
  /// the detail page can hide the section cleanly.
  String body(String locale) {
    final wantZh = locale.startsWith('zh');
    if (wantZh && bodyZh.isNotEmpty) return bodyZh;
    if (!wantZh && bodyEn.isNotEmpty) return bodyEn;
    // Fallback: whichever side has content.
    if (bodyZh.isNotEmpty) return bodyZh;
    return bodyEn;
  }

  String reflection(String locale) =>
      locale.startsWith('zh') && reflectionZh.isNotEmpty
          ? reflectionZh
          : reflectionEn;
}

class NewsSection {
  final String id;
  final String titleEn;
  final String titleZh;
  final String strapEn;
  final String strapZh;
  final List<String> sourceNotes;
  final List<NewsArticle> items;

  NewsSection({
    required this.id,
    required this.titleEn,
    required this.titleZh,
    required this.strapEn,
    required this.strapZh,
    required this.sourceNotes,
    required this.items,
  });

  factory NewsSection.fromJson(Map<String, dynamic> j) {
    final title = (j['title'] as Map?)?.cast<String, dynamic>() ?? const {};
    final strap = (j['strap'] as Map?)?.cast<String, dynamic>() ?? const {};
    final items = (j['items'] as List?) ?? const [];
    return NewsSection(
      id: (j['id'] as String?) ?? '',
      titleEn: (title['en'] as String?) ?? '',
      titleZh: (title['zh'] as String?) ?? (title['en'] as String?) ?? '',
      strapEn: (strap['en'] as String?) ?? '',
      strapZh: (strap['zh'] as String?) ?? (strap['en'] as String?) ?? '',
      sourceNotes:
          ((j['sourceNotes'] as List?) ?? const []).cast<String>(),
      items: items
          .whereType<Map<String, dynamic>>()
          .map(NewsArticle.fromJson)
          .toList(),
    );
  }

  String title(String locale) =>
      locale.startsWith('zh') && titleZh.isNotEmpty ? titleZh : titleEn;
}

class DailyNewsBundle {
  final DateTime? generatedAt;
  final String editionDate;
  final List<NewsSection> sections;

  DailyNewsBundle({
    required this.generatedAt,
    required this.editionDate,
    required this.sections,
  });

  factory DailyNewsBundle.fromJson(Map<String, dynamic> j) {
    final gen = j['generatedAt'] as String?;
    final secs =
        (j['sections'] as Map?)?.cast<String, dynamic>() ?? const {};
    // Stable order: world / china / australia (matches Astro source).
    const order = ['world', 'china', 'australia'];
    final list = <NewsSection>[];
    for (final id in order) {
      final raw = secs[id];
      if (raw is Map<String, dynamic>) {
        list.add(NewsSection.fromJson(raw));
      } else if (raw is Map) {
        list.add(NewsSection.fromJson(raw.cast<String, dynamic>()));
      }
    }
    // Append any unknown sections at the end.
    for (final entry in secs.entries) {
      if (order.contains(entry.key)) continue;
      final raw = entry.value;
      if (raw is Map) {
        list.add(NewsSection.fromJson(raw.cast<String, dynamic>()));
      }
    }
    return DailyNewsBundle(
      generatedAt: gen != null ? DateTime.tryParse(gen) : null,
      editionDate: (j['editionDate'] as String?) ?? '',
      sections: list,
    );
  }

  /// Flat list of every story across sections, preserving section
  /// order then per-section order.
  List<NewsArticle> get allArticles =>
      [for (final s in sections) ...s.items];
}
