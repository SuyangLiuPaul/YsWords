/// One row in the Bible timeline. Loaded from
/// `assets/bible_timeline.json`.
class TimelineEvent {
  /// Stable id (kebab/snake-case).
  final String id;

  /// Signed integer year. Negative = BC, positive = AD.
  final int year;

  /// Era key — matches the family-tree era palette
  /// (`antediluvian`, `patriarchs`, `mosaic`, `conquest`,
  /// `monarchy`, `exile`, `intertestamental`, `nt`).
  final String era;

  /// Localized titles + 1-sentence descriptions.
  final String titleEn;
  final String titleZhHans;
  final String titleZhHant;
  final String descEn;
  final String descZhHans;
  final String descZhHant;

  /// Bible verse references (canonical English form). Tap → jump
  /// to verse via the existing `prepareJumpToVerse` plumbing.
  final List<String> refs;

  /// Optional cross-links to family-tree person ids — tappable
  /// chips on the event card that jump to the family tree page
  /// with that person highlighted.
  final List<String> personIds;

  const TimelineEvent({
    required this.id,
    required this.year,
    required this.era,
    required this.titleEn,
    required this.titleZhHans,
    required this.titleZhHant,
    required this.descEn,
    required this.descZhHans,
    required this.descZhHant,
    required this.refs,
    required this.personIds,
  });

  String localizedTitle(String locale) {
    if (locale == 'zh-Hant' && titleZhHant.isNotEmpty) return titleZhHant;
    if (locale.startsWith('zh') && titleZhHans.isNotEmpty) return titleZhHans;
    return titleEn;
  }

  String localizedDesc(String locale) {
    if (locale == 'zh-Hant' && descZhHant.isNotEmpty) return descZhHant;
    if (locale.startsWith('zh') && descZhHans.isNotEmpty) return descZhHans;
    return descEn;
  }

  /// Render the year as locale-aware "公元前 1010 年" / "1010 BC"
  /// / "公元 30 年" / "AD 30".
  String displayYear(String locale) {
    final isZh = locale.startsWith('zh');
    if (year < 0) {
      if (isZh) return '公元前 ${-year} 年';
      return '${-year} BC';
    }
    if (year == 0) {
      if (isZh) return '公元元年';
      return 'AD 1';
    }
    if (isZh) return '公元 $year 年';
    return 'AD $year';
  }

  factory TimelineEvent.fromJson(Map<String, dynamic> j) {
    return TimelineEvent(
      id: j['id'] as String,
      year: (j['year'] as num).toInt(),
      era: j['era'] as String? ?? 'unknown',
      titleEn: j['titleEn'] as String? ?? '',
      titleZhHans: j['titleZhHans'] as String? ?? '',
      titleZhHant: j['titleZhHant'] as String? ?? '',
      descEn: j['descEn'] as String? ?? '',
      descZhHans: j['descZhHans'] as String? ?? '',
      descZhHant: j['descZhHant'] as String? ?? '',
      refs: (j['refs'] as List?)?.cast<String>() ?? const [],
      personIds: (j['personIds'] as List?)?.cast<String>() ?? const [],
    );
  }
}
