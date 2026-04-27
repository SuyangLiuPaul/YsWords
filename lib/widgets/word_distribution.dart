import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/utils/version_mapper.dart'
    show localeAwareBookName;

/// EaglesView-style "Word Study" distribution panel. Given a per-book
/// count map for a single Strong's number, renders horizontal bar groups
/// showing how the word is distributed across the canon — by section
/// (Pentateuch, Pauline, Johannine, etc.) and by the top books.
///
/// Pure presentational widget — accepts the data via [byBook] (canonical
/// English book names → absolute counts).
class WordDistribution extends StatelessWidget {
  final Map<String, int> byBook;
  final String locale;
  final String? currentVersion;

  const WordDistribution({
    super.key,
    required this.byBook,
    required this.locale,
    this.currentVersion,
  });

  // Canonical OT/NT section groupings. Ordered for display.
  static const _otSections = <String, List<String>>{
    'pentateuch': ['Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy'],
    'historical': [
      'Joshua', 'Judges', 'Ruth',
      '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
      '1 Chronicles', '2 Chronicles',
      'Ezra', 'Nehemiah', 'Esther',
    ],
    'wisdom': [
      'Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon',
    ],
    'majorProphets': [
      'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel',
    ],
    'minorProphets': [
      'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah',
      'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
    ],
  };

  static const _ntSections = <String, List<String>>{
    'gospels': ['Matthew', 'Mark', 'Luke', 'John'],
    'acts': ['Acts'],
    'pauline': [
      'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
      'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
      '1 Timothy', '2 Timothy', 'Titus', 'Philemon',
    ],
    // Johannine groups John's gospel + epistles + Revelation, matching
    // EaglesView's "John T" column.
    'johannine': ['1 John', '2 John', '3 John', 'Revelation'],
    'otherApostolic': [
      'Hebrews', 'James', '1 Peter', '2 Peter', 'Jude',
    ],
  };

  static const _sectionLabels = <String, Map<String, String>>{
    'pentateuch': {'en': 'Pentateuch', 'zh-Hans': '律法书', 'zh-Hant': '律法書'},
    'historical': {'en': 'Historical', 'zh-Hans': '历史书', 'zh-Hant': '歷史書'},
    'wisdom':     {'en': 'Wisdom & Poetry', 'zh-Hans': '智慧书', 'zh-Hant': '智慧書'},
    'majorProphets': {'en': 'Major Prophets', 'zh-Hans': '大先知书', 'zh-Hant': '大先知書'},
    'minorProphets': {'en': 'Minor Prophets', 'zh-Hans': '小先知书', 'zh-Hant': '小先知書'},
    'gospels':    {'en': 'Gospels', 'zh-Hans': '福音书', 'zh-Hant': '福音書'},
    'acts':       {'en': 'Acts', 'zh-Hans': '使徒行传', 'zh-Hant': '使徒行傳'},
    'pauline':    {'en': 'Pauline Epistles', 'zh-Hans': '保罗书信', 'zh-Hant': '保羅書信'},
    'johannine':  {'en': 'Johannine', 'zh-Hans': '约翰著作', 'zh-Hant': '約翰著作'},
    'otherApostolic': {'en': 'Other Apostolic', 'zh-Hans': '一般书信', 'zh-Hant': '一般書信'},
  };

  String _label(String key) {
    final m = _sectionLabels[key];
    if (m == null) return key;
    return m[locale] ?? m['en'] ?? key;
  }

  int _sumSection(List<String> books) {
    int total = 0;
    for (final b in books) {
      total += byBook[b] ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (byBook.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    // Compute section counts — only show sections with at least 1 hit.
    final otSections = <MapEntry<String, int>>[];
    int otTotal = 0;
    for (final entry in _otSections.entries) {
      final n = _sumSection(entry.value);
      if (n > 0) otSections.add(MapEntry(entry.key, n));
      otTotal += n;
    }
    final ntSections = <MapEntry<String, int>>[];
    int ntTotal = 0;
    for (final entry in _ntSections.entries) {
      final n = _sumSection(entry.value);
      if (n > 0) ntSections.add(MapEntry(entry.key, n));
      ntTotal += n;
    }

    final hasOT = otTotal > 0;
    final hasNT = ntTotal > 0;
    if (!hasOT && !hasNT) return const SizedBox.shrink();

    // Use the larger total as the bar scale denominator so OT and NT
    // bars are visually comparable when the word spans both testaments.
    final scaleMax = (otTotal > ntTotal ? otTotal : ntTotal).toDouble();

    // Top-N books across the canon for the bottom mini-table.
    final topBooks = byBook.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topN = topBooks.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              uiStrings['wordDistribution']?[locale] ?? 'Distribution',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (hasOT) ...[
          _testamentLabel(
            uiStrings['oldTestament']?[locale] ?? 'Old Testament',
            otTotal,
            scheme,
          ),
          const SizedBox(height: 6),
          for (final s in otSections)
            _bar(s.key, s.value, scaleMax, scheme, isOT: true),
        ],
        if (hasOT && hasNT) const SizedBox(height: 10),
        if (hasNT) ...[
          _testamentLabel(
            uiStrings['newTestament']?[locale] ?? 'New Testament',
            ntTotal,
            scheme,
          ),
          const SizedBox(height: 6),
          for (final s in ntSections)
            _bar(s.key, s.value, scaleMax, scheme, isOT: false),
        ],
        if (topN.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            uiStrings['topBooks']?[locale] ?? 'Top books',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final b in topN)
                _bookChip(b.key, b.value, scheme),
            ],
          ),
        ],
      ],
    );
  }

  Widget _testamentLabel(String label, int count, ColorScheme scheme) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '· $count',
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _bar(
    String sectionKey,
    int value,
    double scaleMax,
    ColorScheme scheme, {
    required bool isOT,
  }) {
    final fraction = scaleMax > 0 ? (value / scaleMax).clamp(0.0, 1.0) : 0.0;
    final fillColor = isOT
        ? scheme.tertiary.withValues(alpha: 0.55)
        : scheme.primary.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              _label(sectionKey),
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              value.toString(),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookChip(String englishBook, int count, ColorScheme scheme) {
    final localBook = localeAwareBookName(englishBook, locale, currentVersion);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            localBook,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
