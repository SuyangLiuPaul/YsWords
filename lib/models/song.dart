/// One entry in the church-songs directory. Round 56: link-out only —
/// the app stores title + URL + auto-derived metadata, but no audio,
/// lyrics or PDF. Tapping a song opens the original site
/// (fydt.org / christiandiscipleschurch.org) where the church
/// publishes its own content under its own license. See
/// `assets/songs.json` for the data file.
class Song {
  /// Stable identifier — `<source>:<slug>` (e.g. `cdc:d0180`,
  /// `fydt:song_aidaodi`). Used for hash-set membership and as the
  /// React-style key when rendering the list.
  final String id;

  /// Display title in the song's primary language.
  final String title;

  /// 'zh' | 'en' | 'th'. Determines which filter chip the entry
  /// shows up under.
  final String language;

  /// 'fydt' | 'cdc'. Which church site hosts the song.
  final String source;

  /// Localized site name for the source ('福音电台' /
  /// 'Christian Disciples Church').
  final String sourceLabel;

  /// Catalogue code, when the source publishes one (CDC uses
  /// `D0180`, `E0049`, …; fydt doesn't surface codes consistently).
  final String? code;

  /// Direct URL to the song's own page on the source site.
  /// Tapping the entry opens this URL — that's where the audio,
  /// lyrics, and PDF live.
  final String url;

  /// Theme tags auto-derived from title keywords. Best-effort;
  /// covers ~67% of the corpus. Same vocabulary as fydt.org's own
  /// `song_category` taxonomy plus a few extras.
  final List<String> themes;

  /// Bible reference, only when the title makes the association
  /// unambiguous (e.g. "诗篇 23" → "Psalms 23"). Null otherwise —
  /// we deliberately don't fabricate verse links. The sync script
  /// also populates this when the per-song page exposes a verse
  /// citation in HTML.
  final String? verse;

  /// Direct mp3 URL on the source site, when known. CDC URLs are
  /// derived deterministically from `code`; fydt URLs come from the
  /// sync script's per-page scrape. The app today still uses
  /// link-out (opens [url]) — these are pre-populated so the
  /// listing can flip to inline playback if/when the church
  /// authorises redistribution.
  final String? audioUrl;

  /// Direct PDF URL on the source site, when known. Same caveats
  /// as [audioUrl].
  final String? pdfUrl;

  /// ISO-8601 UTC timestamp recording when this entry first showed
  /// up in the sync. Stable across cron runs — only set when the
  /// entry is new. Drives the "Recently added" sort.
  final String? firstSeenAt;

  /// ISO-8601 UTC timestamp recording the most recent run that
  /// actually changed something on this entry (title fix, new
  /// audio URL, freshly populated verse, …). Drives the
  /// "Recently updated" sort. Equals [firstSeenAt] for entries
  /// that haven't been touched since they were first imported.
  final String? updatedAt;

  const Song({
    required this.id,
    required this.title,
    required this.language,
    required this.source,
    required this.sourceLabel,
    this.code,
    required this.url,
    required this.themes,
    this.verse,
    this.audioUrl,
    this.pdfUrl,
    this.firstSeenAt,
    this.updatedAt,
  });

  factory Song.fromJson(Map<String, dynamic> j) {
    return Song(
      id: j['id'] as String,
      title: j['title'] as String,
      language: j['language'] as String? ?? 'en',
      source: j['source'] as String,
      sourceLabel: j['sourceLabel'] as String? ?? '',
      code: j['code'] as String?,
      url: j['url'] as String,
      themes: ((j['themes'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      verse: j['verse'] as String?,
      audioUrl: j['audioUrl'] as String?,
      pdfUrl: j['pdfUrl'] as String?,
      firstSeenAt: j['firstSeenAt'] as String?,
      updatedAt: j['updatedAt'] as String?,
    );
  }

  /// Parse the `verse` field into an English book name (used for
  /// the sermon-style book filter). Returns null if no parseable
  /// reference is present.
  String? get verseBook {
    final v = verse;
    if (v == null || v.trim().isEmpty) return null;
    // Match "Psalms 23", "Genesis 1:1", "1 Corinthians 13:1-13"
    final m = RegExp(r'^([1-3]?\s*[A-Za-z]+(?:\s+[A-Za-z]+)*)')
        .firstMatch(v.trim());
    return m?.group(1)?.trim();
  }
}

/// Localised theme tag labels. Keys are the canonical Chinese tag
/// stored in songs.json (`敬拜`, `救恩`, etc.); values are the
/// per-locale display labels. Falls back to the raw key if a locale
/// is missing. The keys mirror fydt.org's own song_category
/// taxonomy plus a few inferred categories used by the title-keyword
/// classifier.
const Map<String, Map<String, String>> songThemeLabels = {
  '敬拜': {'en': 'Worship', 'zh-Hans': '敬拜', 'zh-Hant': '敬拜'},
  '赞美': {'en': 'Praise', 'zh-Hans': '赞美', 'zh-Hant': '讚美'},
  '救恩': {'en': 'Salvation', 'zh-Hans': '救恩', 'zh-Hant': '救恩'},
  '圣灵': {'en': 'Holy Spirit', 'zh-Hans': '圣灵', 'zh-Hant': '聖靈'},
  '委身': {'en': 'Commitment', 'zh-Hans': '委身', 'zh-Hant': '委身'},
  '顺服': {'en': 'Obedience', 'zh-Hans': '顺服', 'zh-Hant': '順服'},
  '得胜': {'en': 'Victory', 'zh-Hans': '得胜', 'zh-Hant': '得勝'},
  '重生': {'en': 'New Life', 'zh-Hans': '重生', 'zh-Hant': '重生'},
  '圣洁': {'en': 'Holiness', 'zh-Hans': '圣洁', 'zh-Hant': '聖潔'},
  '平安': {'en': 'Peace', 'zh-Hans': '平安', 'zh-Hant': '平安'},
  '感恩': {'en': 'Thanksgiving', 'zh-Hans': '感恩', 'zh-Hant': '感恩'},
  '警醒': {'en': 'Watchful', 'zh-Hans': '警醒', 'zh-Hant': '警醒'},
  '信心': {'en': 'Faith', 'zh-Hans': '信心', 'zh-Hant': '信心'},
  '爱': {'en': 'Love', 'zh-Hans': '爱', 'zh-Hant': '愛'},
  '仰望': {'en': 'Hope', 'zh-Hans': '仰望', 'zh-Hant': '仰望'},
  '门徒': {'en': 'Discipleship', 'zh-Hans': '门徒', 'zh-Hant': '門徒'},
  '祷告': {'en': 'Prayer', 'zh-Hans': '祷告', 'zh-Hant': '禱告'},
  '真理': {'en': 'Truth', 'zh-Hans': '真理', 'zh-Hant': '真理'},
  '心': {'en': 'Heart', 'zh-Hans': '心', 'zh-Hant': '心'},
  '神的名': {'en': 'God\'s Name', 'zh-Hans': '神的名', 'zh-Hant': '神的名'},
  '教会': {'en': 'Church', 'zh-Hans': '教会', 'zh-Hant': '教會'},
  '见证': {'en': 'Witness', 'zh-Hans': '见证', 'zh-Hant': '見證'},
  '生命': {'en': 'Life', 'zh-Hans': '生命', 'zh-Hant': '生命'},
  '诗篇': {'en': 'Psalm Setting', 'zh-Hans': '诗篇', 'zh-Hant': '詩篇'},
  '儿童': {'en': 'Children', 'zh-Hans': '儿童', 'zh-Hant': '兒童'},
};

String localizedSongTheme(String themeKey, String locale) {
  final m = songThemeLabels[themeKey];
  if (m == null) return themeKey;
  return m[locale] ?? m['en'] ?? themeKey;
}
