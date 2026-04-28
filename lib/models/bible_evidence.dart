import 'package:flutter/material.dart';

/// One row in the Biblical Evidence Archive.
///
/// Loaded from `assets/bible_evidence.json` which was migrated from
/// the standalone bible-evidence.netlify.app project (Vite/React/TS).
/// Translations for [title], [summary], [description] and
/// [scripturalCorrelation] are inlined per entry as
/// `{en, zh-Hans, zh-Hant}` maps so the archive works fully offline.
class BibleEvidence {
  final String id;
  /// One of: 'Archaeology', 'Manuscripts', 'Science', 'History'.
  final String category;
  /// Books referenced — usually one or two ("1 Kings", "2 Kings"),
  /// occasionally "Multiple Books" for archive-wide finds like the
  /// Dead Sea Scrolls.
  final List<String> bibleBooks;
  /// Era as a free-text phrase ("9th Century BCE", "1st Century CE").
  final String timeline;
  final String discoveryDate;
  final String location;
  /// Anchor scripture reference for cross-linking into the reader.
  /// Format: "Book Chapter:Verse" or "Book Chapter:Start-End".
  final String scriptureReference;
  /// Public-domain or CC-licensed image URLs (typically Wikimedia
  /// Commons). May be empty when no good image is available.
  final List<String> images;
  /// Citation strings, 3-10 per entry.
  final List<String> academicSources;
  /// 'Definitive' | 'Strong' | 'Circumstantial'.
  final String confidenceLevel;
  /// Single-character emoji used as a visual icon when [images] is
  /// empty or fails to load.
  final String icon;

  final Map<String, String> title;
  final Map<String, String> summary;
  final Map<String, String> description;
  final Map<String, String> scripturalCorrelation;

  const BibleEvidence({
    required this.id,
    required this.category,
    required this.bibleBooks,
    required this.timeline,
    required this.discoveryDate,
    required this.location,
    required this.scriptureReference,
    required this.images,
    required this.academicSources,
    required this.confidenceLevel,
    required this.icon,
    required this.title,
    required this.summary,
    required this.description,
    required this.scripturalCorrelation,
  });

  String localizedTitle(String locale) =>
      title[locale] ?? title['en'] ?? id;
  String localizedSummary(String locale) =>
      summary[locale] ?? summary['en'] ?? '';
  String localizedDescription(String locale) =>
      description[locale] ?? description['en'] ?? '';
  String localizedCorrelation(String locale) =>
      scripturalCorrelation[locale] ?? scripturalCorrelation['en'] ?? '';

  /// Color used for the confidence badge. Mirrors the colors the
  /// React project uses (parchment / sapphire / gold theme),
  /// adjusted for Material 3 surfaces.
  Color confidenceColor(ColorScheme scheme) {
    switch (confidenceLevel) {
      case 'Definitive':
        return const Color(0xFF2E7D32); // green
      case 'Strong':
        return scheme.primary;
      case 'Circumstantial':
      default:
        return const Color(0xFFEF6C00); // orange
    }
  }

  factory BibleEvidence.fromJson(Map<String, dynamic> j) {
    // Some entries in the upstream dataset (e.g. "hazor_destruction")
    // store long-form `description` and `scripturalCorrelation` as
    // an *array of paragraphs* per locale rather than a single
    // string. Older versions of this code cast to `String?` and
    // returned the raw `[a, b, c]` toString — bracketed list visible
    // to users. Now we flatten paragraphs to a double-newline
    // joined string so the detail page renders properly.
    String flatten(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      if (v is List) return v.map((e) => e.toString()).join('\n\n');
      return v.toString();
    }

    Map<String, String> tm(dynamic v) {
      if (v is Map) {
        return v.map((k, val) => MapEntry(k.toString(), flatten(val)));
      }
      return {};
    }

    List<String> ls(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return BibleEvidence(
      id: j['id'] as String? ?? '',
      category: j['category'] as String? ?? '',
      bibleBooks: ls(j['bibleBooks']),
      timeline: j['timeline'] as String? ?? '',
      discoveryDate: j['discoveryDate'] as String? ?? '',
      location: j['location'] as String? ?? '',
      scriptureReference: j['scriptureReference'] as String? ?? '',
      images: ls(j['images']),
      academicSources: ls(j['academicSources']),
      confidenceLevel: j['confidenceLevel'] as String? ?? 'Strong',
      icon: j['icon'] as String? ?? '📜',
      title: tm(j['title']),
      summary: tm(j['summary']),
      description: tm(j['description']),
      scripturalCorrelation: tm(j['scripturalCorrelation']),
    );
  }
}
