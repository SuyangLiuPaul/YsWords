/// One episode of 獨一真神 / "Who is the only true God?" — the same
/// teaching recorded three times, once per language.
///
/// 2026-08-11, at the user's request: "一神是广东话，onegod 是英语，另一个
/// 是普通话，内容是一样". So this is deliberately NOT modelled as three
/// separate items in a list. It is one episode with three tracks, which
/// is what makes switching language mid-watch — and keeping your
/// position when you do — a natural thing to build rather than a hack.
class OneGodTrack {
  /// 'en' | 'yue' (Cantonese) | 'cmn' (Mandarin).
  ///
  /// ISO 639-3 rather than the app's usual 'zh': Cantonese and Mandarin
  /// are both Chinese and the whole point here is that they are
  /// different recordings. 'zh' could not tell them apart.
  final String lang;

  /// Key into `uiStrings` for the button label, so the language names
  /// are localised like everything else.
  final String labelKey;

  /// Path under the media host, e.g. `/onegod/01/en.mp4`. Joined with
  /// the base at read time so re-hosting is a one-value change.
  final String path;

  final int? durationSec;

  const OneGodTrack({
    required this.lang,
    required this.labelKey,
    required this.path,
    this.durationSec,
  });

  factory OneGodTrack.fromJson(Map<String, dynamic> j) => OneGodTrack(
        lang: j['lang'] as String,
        labelKey: j['labelKey'] as String? ?? 'oneGodLangEn',
        path: j['path'] as String,
        durationSec: (j['durationSec'] as num?)?.toInt(),
      );
}

class OneGodEpisode {
  final String id;
  final int number;

  /// Localised titles, keyed the way `uiStrings` is ('en', 'zh-Hans',
  /// 'zh-Hant').
  final Map<String, String> titles;

  final List<OneGodTrack> tracks;

  /// The teaching's text, by locale key, one entry per paragraph.
  ///
  /// **This is a transcript, not subtitles, and the difference is not
  /// cosmetic.** The document the church supplied carries no timings of
  /// any kind — the only time-shaped strings in all 15,729 characters
  /// are scripture references like "John 5:44". So nothing here can be
  /// synchronised to the video, and the UI must not imply that it is.
  /// Real subtitles need a `.srt`/`.vtt` from the church, or forced
  /// alignment, and would need one per language rather than this single
  /// Chinese script.
  final Map<String, List<String>> transcript;

  const OneGodEpisode({
    required this.id,
    required this.number,
    required this.titles,
    required this.tracks,
    required this.transcript,
  });

  factory OneGodEpisode.fromJson(Map<String, dynamic> j) => OneGodEpisode(
        id: j['id'] as String,
        number: (j['number'] as num?)?.toInt() ?? 0,
        titles: {
          for (final e in (j['titles'] as Map? ?? {}).entries)
            e.key as String: e.value as String,
        },
        tracks: [
          for (final t in (j['tracks'] as List? ?? []))
            OneGodTrack.fromJson(t as Map<String, dynamic>),
        ],
        transcript: {
          for (final e in (j['transcript'] as Map? ?? {}).entries)
            e.key as String: [
              for (final p in (e.value as List? ?? [])) p as String,
            ],
        },
      );

  /// Title in [locale], falling back through Traditional → English →
  /// whatever exists, so a missing translation never renders blank.
  String titleFor(String locale) =>
      titles[locale] ??
      titles['zh-Hant'] ??
      titles['en'] ??
      (titles.isEmpty ? '' : titles.values.first);

  /// The transcript for [locale]. Only the Chinese script exists today;
  /// returning empty (rather than the Chinese text) for English is
  /// deliberate — showing a Chinese transcript under an English video
  /// would look like a bug, and is one.
  List<String> transcriptFor(String locale) =>
      transcript[locale] ?? transcript['zh-Hant'] ?? const [];

  bool get hasTranscript => transcript.values.any((v) => v.isNotEmpty);

  OneGodTrack? trackFor(String lang) {
    for (final t in tracks) {
      if (t.lang == lang) return t;
    }
    return tracks.isEmpty ? null : tracks.first;
  }
}
