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
  /// we deliberately don't fabricate verse links.
  final String? verse;

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
    );
  }
}
