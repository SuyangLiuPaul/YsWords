/// The church's video teachings: `series[] → episodes[] → tracks[]`.
///
/// A track is one language's recording of the SAME teaching, which is
/// why it sits under an episode rather than beside it — switching
/// language mid-watch is a language switch, not a different video.
///
/// Two series must be able to differ in language coverage: 在十字架下 is
/// English + Cantonese, 獨一真神 has Mandarin as well. So the language
/// buttons are built from the episode's own tracks and never from a
/// fixed list.
class VideoTrack {
  /// 'en' | 'yue' (Cantonese) | 'cmn' (Mandarin).
  ///
  /// ISO 639-3 rather than the app's usual 'zh': Cantonese and Mandarin
  /// are both Chinese, and telling them apart is the whole point.
  final String lang;

  /// Key into `uiStrings` for the button label.
  final String labelKey;

  final String youtubeId;

  const VideoTrack({
    required this.lang,
    required this.labelKey,
    required this.youtubeId,
  });

  factory VideoTrack.fromJson(Map<String, dynamic> j) => VideoTrack(
        lang: j['lang'] as String,
        labelKey: j['labelKey'] as String? ?? 'oneGodLangEn',
        youtubeId: j['youtubeId'] as String,
      );

  String get watchUrl => 'https://www.youtube.com/watch?v=$youtubeId';

  String get thumbnailUrl => 'https://i.ytimg.com/vi/$youtubeId/hqdefault.jpg';
}

/// Titles carry one Chinese entry, not two.
///
/// The text is the church's own wording, copied verbatim. Producing a
/// Traditional variant would mean converting someone else's copy glyph
/// by glyph, and a converted glyph is our word rather than theirs.
String _localized(Map<String, String> m, String locale) =>
    m[locale] ??
    (locale.startsWith('zh') ? m['zh'] : null) ??
    m['en'] ??
    (m.isEmpty ? '' : m.values.first);

class VideoEpisode {
  final String id;
  final int number;
  final Map<String, String> titles;
  final List<VideoTrack> tracks;

  const VideoEpisode({
    required this.id,
    required this.number,
    required this.titles,
    required this.tracks,
  });

  factory VideoEpisode.fromJson(Map<String, dynamic> j) => VideoEpisode(
        id: j['id'] as String,
        number: (j['number'] as num?)?.toInt() ?? 0,
        titles: {
          for (final e in (j['titles'] as Map? ?? {}).entries)
            e.key as String: e.value as String,
        },
        tracks: [
          for (final t in (j['tracks'] as List? ?? []))
            VideoTrack.fromJson(t as Map<String, dynamic>),
        ],
      );

  String titleFor(String locale) => _localized(titles, locale);

  /// The track in [lang], or null. Returning null rather than the first
  /// track is deliberate: a series that has no Mandarin must show no
  /// Mandarin, not quietly play the Cantonese take under that label.
  VideoTrack? trackFor(String lang) {
    for (final t in tracks) {
      if (t.lang == lang) return t;
    }
    return null;
  }

  VideoTrack? get defaultTrack => tracks.isEmpty ? null : tracks.first;
}

class VideoSeries {
  final String id;
  final Map<String, String> titles;

  /// The second line — "A 10-Part Journey" / 人生十堂课. Separate from
  /// the title because this series has four name lines and they are not
  /// interchangeable.
  final Map<String, String> taglines;

  final String creditKey;
  final List<VideoEpisode> episodes;

  const VideoSeries({
    required this.id,
    required this.titles,
    required this.taglines,
    required this.creditKey,
    required this.episodes,
  });

  factory VideoSeries.fromJson(Map<String, dynamic> j) => VideoSeries(
        id: j['id'] as String,
        titles: {
          for (final e in (j['titles'] as Map? ?? {}).entries)
            e.key as String: e.value as String,
        },
        taglines: {
          for (final e in (j['taglines'] as Map? ?? {}).entries)
            e.key as String: e.value as String,
        },
        creditKey: j['creditKey'] as String? ?? 'oneGodCredit',
        episodes: [
          for (final e in (j['episodes'] as List? ?? []))
            VideoEpisode.fromJson(e as Map<String, dynamic>),
        ],
      );

  String titleFor(String locale) => _localized(titles, locale);

  String taglineFor(String locale) => _localized(taglines, locale);

  /// A one-episode series is a video, and should be opened as one
  /// rather than rendering a list with a single row in it.
  bool get isSingle => episodes.length == 1;

  static List<VideoSeries> listFromJson(Map<String, dynamic> doc) => [
        for (final s in (doc['series'] as List? ?? []))
          VideoSeries.fromJson(s as Map<String, dynamic>),
      ];
}
