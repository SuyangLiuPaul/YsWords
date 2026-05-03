/// One sermon record from `assets/sermons/index.json`.
///
/// Bodies live as separate text files keyed by [id] under
/// `assets/sermons/<lang>/<id>.txt` and are lazy-loaded by
/// `SermonService.loadBody` — keeping the index small (~200 KB) and
/// the per-sermon body fetch a one-off cost only when the user opens
/// a sermon.
class Sermon {
  /// Canonical sermon id from the source index — e.g. "004", "EC010",
  /// "397-1". Stable across re-ingestions and used as the asset
  /// filename stem.
  final String id;

  /// Topic series heading, e.g. "Baptism", "The Beatitudes".
  /// Drives the topic-grouped list view.
  final String topic;

  /// Disk-folder name for the topic in the source corpus. We keep it
  /// only for debugging — the app uses [topic] for display.
  final String topicSlug;

  /// "1979-04-08" or "yyyy-mmdd" when the original recording was
  /// undated. UI renders the placeholder differently.
  final String date;

  /// "A/B", "A/B/C", or empty when single-part. Surfaces in the UI as
  /// a small chip so the user knows multi-part sermons have been
  /// concatenated.
  final String parts;

  /// Free-form passage hint from the index ("Luke 4:5-13", "1Cor 6:17",
  /// "Mt 11:30-12.1-8"). Empty when the index didn't ship a passage —
  /// many topical sermons have no single passage.
  final String passage;

  /// Short English title from the SERMON_INDEX.md row. Used as the
  /// fallback when no per-language title was extractable from the
  /// body H1.
  final String title;

  /// Per-language titles extracted from each body file's first
  /// markdown-H1 line. Keys are body-language codes: `'en'`,
  /// `'zh-CN'`, `'zh-TW'`. Missing keys mean we couldn't extract one
  /// — caller should fall back to [title].
  final Map<String, String> titles;

  final bool hasEn;
  final bool hasZhCn;
  final bool hasZhTw;

  const Sermon({
    required this.id,
    required this.topic,
    required this.topicSlug,
    required this.date,
    required this.parts,
    required this.passage,
    required this.title,
    required this.titles,
    required this.hasEn,
    required this.hasZhCn,
    required this.hasZhTw,
  });

  factory Sermon.fromJson(Map<String, dynamic> j) {
    final raw = j['titles'] as Map<String, dynamic>? ?? const {};
    final titles = <String, String>{
      for (final e in raw.entries) e.key: e.value.toString(),
    };
    return Sermon(
      id: j['id'] as String,
      topic: j['topic'] as String,
      topicSlug: j['topicSlug'] as String,
      date: j['date'] as String,
      parts: j['parts'] as String? ?? '',
      passage: j['passage'] as String? ?? '',
      title: j['title'] as String,
      titles: titles,
      hasEn: j['hasEn'] as bool? ?? false,
      hasZhCn: j['hasZhCn'] as bool? ?? false,
      hasZhTw: j['hasZhTw'] as bool? ?? false,
    );
  }

  /// Best title to display given the user's app locale, falling back
  /// across languages so we always return something non-empty.
  /// `appLocale` is the AppSettings.locale value: `'en'`, `'zh-Hans'`,
  /// `'zh-Hant'`.
  String localizedTitle(String appLocale) {
    final preferred = appLocale == 'zh-Hant'
        ? 'zh-TW'
        : appLocale == 'zh-Hans'
            ? 'zh-CN'
            : 'en';
    final fallbacks = <String>[
      preferred,
      if (preferred != 'zh-CN') 'zh-CN',
      if (preferred != 'zh-TW') 'zh-TW',
      if (preferred != 'en') 'en',
    ];
    for (final lang in fallbacks) {
      final t = titles[lang];
      if (t != null && t.trim().isNotEmpty) return t.trim();
    }
    return title.isNotEmpty ? title : '#$id';
  }

  /// True when the sermon has at least one body file in some language.
  /// (Always true post-ingest; we filter empties out at write time.)
  bool get hasAnyBody => hasEn || hasZhCn || hasZhTw;

  /// Pretty date for the UI: "1979-04-08" → "8 Apr 1979"; placeholder
  /// "yyyy-mmdd" → "—".
  String get displayDate {
    if (date == 'yyyy-mmdd' || date.isEmpty) return '—';
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(date);
    if (m == null) return date;
    final y = m.group(1)!;
    final mo = int.tryParse(m.group(2)!) ?? 0;
    final d = int.tryParse(m.group(3)!) ?? 0;
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    if (mo < 1 || mo > 12 || d < 1) return date;
    return '$d ${months[mo - 1]} $y';
  }
}
