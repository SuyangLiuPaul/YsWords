/// One entry in the church-songs directory.
///
/// 2026-08-09 (v2): the original directory was **link-out only** — it
/// stored a title and a URL, and tapping a row opened the church's own
/// site. `audioUrl`/`pdfUrl` were populated but deliberately unused,
/// with the note that the listing could "flip to inline playback
/// if/when the church authorises redistribution".
///
/// That authorisation has been given: all three catalogues are
/// published by our own church's pastors, who approved in-app use. So
/// this version carries the full media set and the app plays it
/// directly — audio inline, video and SoundCloud handed to the
/// platform.
///
/// Sources (see `_meta.sources` in `assets/songs.json`):
///   • `fydt`    — 福音电台, fydt.org (Chinese)
///   • `cahaya`  — Cahaya Pengharapan, cahayapengharapan.org (Indonesian)
///   • `cdc`     — Christian Disciples Church (English + Chinese)
///   • `cgdc`    — cgdc.hk, Hong Kong (Chinese)
///   • `setapak` — setapakcdc.com, Kuala Lumpur (2 songs, 2026-09-03)
///   • `ydh`     — yahwehdehua.net, 雅伟的话 (5 songs, 2026-09-03)
///
/// `ydh` is the ministry whose Bible text this app already bundles.
/// Its five songs are the church's OWN compositions, published with
/// full lyrics on its Good Friday / Easter series page — so unlike
/// `setapak` they carry `lyrics`, and they are the only rows outside
/// `fydt` that do. They are YouTube-only otherwise: no audio file, no
/// score, no code, no album.
///
/// `setapak` is the odd one out and is meant to be: both its
/// songs are members' own YouTube uploads with no audio file, no
/// score, no code and no album, and neither is the church's own
/// composition. It was added at the user's explicit direction over a
/// recommendation against it. The shape is not new — 20 `cahaya` rows
/// are the same YouTube-only shape — so nothing here special-cases it.
///
/// fuyindiantai.org is *not* a fourth source: it is fydt.org's former
/// domain, its songs are already here under `fydt`, and its DNS no
/// longer resolves. See the note in `assets/songs.json` `_meta.notes`.
/// One audio rendering of a song.
///
/// Sources publish more than a single file per song and not always the
/// same set: fydt has vocal / instrumental / accompaniment mixes, while
/// CDC adds per-language sung takes (`D0375_English.mp3` +
/// `D0375_Chinese.mp3`). Modelling them as a list keeps both uniform
/// and stops a new arrangement from needing a new field.
class SongTrackInfo {
  final String url;

  /// 'vocal' | 'instrumental' | 'accompaniment'.
  final String kind;

  /// 'zh' | 'en' | 'id', but only when the source publishes the same
  /// song sung in more than one language. Null for mixes and for
  /// single-language songs.
  final String? lang;

  const SongTrackInfo({
    required this.url,
    required this.kind,
    this.lang,
  });

  factory SongTrackInfo.fromJson(Map<String, dynamic> j) => SongTrackInfo(
        url: j['url'] as String,
        kind: j['kind'] as String? ?? 'vocal',
        lang: (j['lang'] as String?)?.trim().isEmpty ?? true
            ? null
            : j['lang'] as String,
      );

  bool get isVocal => kind == 'vocal';
}

class Song {
  /// Stable identifier — `<source>:<slug>`. fydt uses the WordPress
  /// post id (`fydt:122368`), CDC its catalogue code (`cdc:d0180`),
  /// Cahaya a title slug (`cahaya:allah-kehidupanku`).
  final String id;

  /// Display title in the song's primary language.
  final String title;

  /// 'zh' | 'en' | 'id'. Determines which language chip the entry
  /// shows up under.
  final String language;

  /// 'fydt' | 'cahaya' | 'cdc' | 'cgdc' | 'setapak' | 'ydh'. Which
  /// church site publishes it. Every value must have an entry in
  /// [songSourceLabels] and in `songSourceIcons`; both are enforced by
  /// tests rather than by convention.
  final String source;

  /// Display name for the source ('福音电台 FYDT', …). Shown on the
  /// source chip and on each row, so a song is never presented
  /// without saying where it came from.
  final String sourceLabel;

  /// Catalogue code where the source publishes one — CDC uses
  /// `D0180`, fydt uses `S04_021`. Cahaya publishes none.
  final String? code;

  /// The song's own page on the source site. Still offered as
  /// "open original" even when we can play the media inline.
  final String url;

  /// Songbook or release this belongs to, where the source groups its
  /// songs that way — cgdc.hk publishes one Easter-camp songbook a
  /// year ("2024 Bravery 刚强奋勇"). Null for flat catalogues.
  final String? album;

  /// Performer credit, as published. fydt writes these as
  /// `'歌手 / 词曲作者'`; the raw string is kept verbatim rather than
  /// split, because the separator is not used consistently upstream.
  final String? artist;
  final String? composer;
  final String? lyricist;

  /// Track length in seconds, when published.
  final int? durationSec;

  /// Direct mp3 of the sung version — the one the play button uses.
  final String? audioUrl;

  /// Instrumental (伴奏) and accompaniment/minus-one (伴唱) mixes.
  /// Both sources publish these for much of their catalogue; they
  /// surface as extra play buttons rather than separate rows.
  final String? instrumentalUrl;
  final String? accompanimentUrl;

  /// Every audio rendering, including the per-language sung takes that
  /// [audioUrl] alone cannot express. The three fields above are
  /// conveniences drawn from this list.
  final List<SongTrackInfo> audioTracks;

  /// Direct mp4 music video (fydt publishes MVs on its own CDN).
  final String? videoUrl;

  /// YouTube video id — Cahaya's video catalogue. Opened externally
  /// rather than embedded: an inline player would need a WebView on
  /// five of the six platforms this app ships to.
  final String? youtubeId;

  /// SoundCloud track id — Cahaya's audio catalogue. SoundCloud does
  /// not expose stream URLs without a registered client id (and
  /// registration has been closed for years), so these open in the
  /// SoundCloud player rather than playing inline.
  final String? soundcloudTrackId;

  /// Sheet-music PDF ('lembar lagu' / 乐谱).
  final String? scoreUrl;

  /// Cover art, where published (fydt only today).
  final String? artworkUrl;

  /// Full lyrics as plain text with `\n` breaks. fydt publishes these
  /// for its whole catalogue; CDC and Cahaya put theirs in the PDF, so
  /// most non-fydt rows have none.
  final String? lyrics;

  /// Theme tags. fydt rows carry the site's real `song_category`
  /// terms; CDC and Cahaya rows are classified from the title, so
  /// treat those as best-effort.
  final List<String> themes;

  /// Bible reference, when the source publishes one or the title
  /// makes it unambiguous. Never fabricated.
  final String? verse;

  /// When this entry first appeared in a sync, and when it last
  /// actually changed. Drive the two "recently …" sorts.
  final String? firstSeenAt;
  final String? updatedAt;

  const Song({
    required this.id,
    required this.title,
    required this.language,
    required this.source,
    required this.sourceLabel,
    this.code,
    required this.url,
    this.album,
    this.artist,
    this.composer,
    this.lyricist,
    this.durationSec,
    this.audioUrl,
    this.instrumentalUrl,
    this.accompanimentUrl,
    this.audioTracks = const [],
    this.videoUrl,
    this.youtubeId,
    this.soundcloudTrackId,
    this.scoreUrl,
    this.artworkUrl,
    this.lyrics,
    required this.themes,
    this.verse,
    this.firstSeenAt,
    this.updatedAt,
  });

  factory Song.fromJson(Map<String, dynamic> j) {
    String? str(String key) {
      final v = j[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return Song(
      id: j['id'] as String,
      title: j['title'] as String,
      language: str('language') ?? 'en',
      source: j['source'] as String,
      sourceLabel: str('sourceLabel') ?? '',
      code: str('code'),
      url: j['url'] as String,
      album: str('album'),
      artist: str('artist'),
      composer: str('composer'),
      lyricist: str('lyricist'),
      durationSec: (j['durationSec'] as num?)?.toInt(),
      audioUrl: str('audioUrl'),
      instrumentalUrl: str('instrumentalUrl'),
      accompanimentUrl: str('accompanimentUrl'),
      audioTracks: ((j['audioTracks'] as List?) ?? const [])
          .map((e) =>
              SongTrackInfo.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      videoUrl: str('videoUrl'),
      youtubeId: str('youtubeId'),
      soundcloudTrackId: str('soundcloudTrackId'),
      scoreUrl: str('scoreUrl'),
      artworkUrl: str('artworkUrl'),
      lyrics: str('lyrics'),
      themes: ((j['themes'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      verse: str('verse'),
      firstSeenAt: str('firstSeenAt'),
      updatedAt: str('updatedAt'),
    );
  }

  /// True when there is a direct mp3 this app can stream itself.
  /// SoundCloud-only rows are false — they open externally.
  ///
  /// Falls back to the track list so a song published ONLY as an
  /// instrumental still plays. CDC has one (D0500, "Here I Am, As I
  /// Wake" — instrumental + minus-one, no sung take); treating it as
  /// having no audio would hide a file that is right there.
  bool get hasPlayableAudio => audioUrl != null || audioTracks.isNotEmpty;

  /// Any audio at all, streamable or not. Drives the "has audio"
  /// filter, which users read as "can I listen to this".
  bool get hasAudio => hasPlayableAudio || soundcloudTrackId != null;

  /// Free-text match over the fields a user would plausibly type.
  ///
  /// Lives on the model so the Songs list and the Downloads page cannot
  /// drift apart about what "search" means. The same query selecting
  /// different songs on the two pages would read as the Downloads page
  /// having lost something the directory can still find.
  ///
  /// [q] must already be trimmed and lower-cased by the caller — it is
  /// called once per song per keystroke, and re-normalising the needle
  /// inside the loop is work proportional to the catalogue for no
  /// reason. An empty query matches everything.
  bool matchesQuery(String q) {
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        (code?.toLowerCase().contains(q) ?? false) ||
        (verse?.toLowerCase().contains(q) ?? false) ||
        (artist?.toLowerCase().contains(q) ?? false) ||
        themes.any((t) => t.toLowerCase().contains(q));
  }

  /// The sung takes, in the order the source published them.
  List<SongTrackInfo> get vocalTracks =>
      audioTracks.where((t) => t.isVocal).toList();

  /// True when the same song is published sung in more than one
  /// language — 12 of the CDC entries are.
  bool get hasMultipleLanguages =>
      vocalTracks.map((t) => t.lang).whereType<String>().toSet().length > 1;

  /// Any video — a direct mp4 MV or a YouTube id.
  bool get hasVideo => videoUrl != null || youtubeId != null;

  /// Alternative mixes available beyond the main vocal track.
  bool get hasAlternateMixes =>
      instrumentalUrl != null || accompanimentUrl != null;

  /// External player URL for SoundCloud rows.
  ///
  /// The id is scraped out of an `api.soundcloud.com/tracks/<id>` embed,
  /// and that address used to be handed to the browser as-is — but it is
  /// an API endpoint, not a page: it answers **401 with JSON** to an
  /// unauthenticated request, which is every request we make. Checked
  /// live against all 27 ids in the catalogue: 27 of 27 gave 401.
  ///
  /// The widget player takes the same id and resolves it to the real
  /// track — 27 of 27 gave 200 `text/html` carrying the canonical
  /// `soundcloud.com/<user>/<slug>` for the right song. That canonical
  /// is not derivable from the id without asking SoundCloud, so it is
  /// not guessed at here.
  String? get soundcloudUrl => soundcloudTrackId == null
      ? null
      : 'https://w.soundcloud.com/player/?url='
          'https%3A//api.soundcloud.com/tracks/$soundcloudTrackId';

  /// Watch URL for YouTube rows.
  String? get youtubeUrl =>
      youtubeId == null ? null : 'https://www.youtube.com/watch?v=$youtubeId';

  /// 'm:ss', or null when the source publishes no length.
  String? get durationLabel {
    final d = durationSec;
    if (d == null || d <= 0) return null;
    final m = d ~/ 60;
    final s = (d % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// The credit line shown under the title. Prefers the performer,
  /// falls back to composer, and drops the duplicated half of fydt's
  /// `'X / X'` convention so a self-performed song reads as one name.
  String? get creditLine {
    final raw = artist ?? composer ?? lyricist;
    if (raw == null) return null;
    final parts = raw
        .split('/')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    final seen = <String>{};
    final unique = parts.where(seen.add).toList();
    return unique.join(' · ');
  }

  /// Parse [verse] into an English book name for the book filter.
  /// Returns null when there is no parseable reference.
  String? get verseBook {
    final v = verse;
    if (v == null || v.trim().isEmpty) return null;
    final m = RegExp(r'^([1-3]?\s*[A-Za-z]+(?:\s+[A-Za-z]+)*)')
        .firstMatch(v.trim());
    return m?.group(1)?.trim();
  }
}

/// Localised source labels. The JSON ships one label per source (the
/// church's own name for itself); these give the English and
/// Traditional-Chinese renderings for the filter chips.
const Map<String, Map<String, String>> songSourceLabels = {
  'fydt': {
    'en': 'FYDT Gospel Radio',
    'zh-Hans': '福音电台',
    'zh-Hant': '福音電台',
  },
  'cahaya': {
    'en': 'Cahaya Pengharapan',
    'zh-Hans': '印尼 Cahaya Pengharapan',
    'zh-Hant': '印尼 Cahaya Pengharapan',
  },
  'cdc': {
    'en': 'Christian Disciples Church',
    'zh-Hans': '基督门徒福音会',
    'zh-Hant': '基督門徒福音會',
  },
  // cgdc.hk is the Hong Kong church — a DIFFERENT site from
  // christiandiscipleschurch.org above, despite the similar name. It
  // publishes the yearly MK Easter-camp songbooks.
  'cgdc': {
    'en': 'CGDC Hong Kong',
    'zh-Hans': '基督门徒福音会（香港）',
    'zh-Hant': '基督門徒福音會（香港）',
  },
  // Third church of the same denomination, third similar name — the
  // Kuala Lumpur congregation at setapakcdc.com. The labels
  // disambiguate by CITY for exactly that reason: "Christian Disciples
  // Church", "CGDC Hong Kong" and "Setapak CDC" sit next to each other
  // in the source filter, and a reader has no other way to tell them
  // apart. Two songs, both YouTube-only.
  'setapak': {
    'en': 'Setapak CDC, Kuala Lumpur',
    'zh-Hans': '基督门徒福音会（吉隆坡）',
    'zh-Hant': '基督門徒福音會（吉隆坡）',
  },
  // yahwehdehua.net — the ministry this app already credits for the
  // CUVS-YHWH text on the About page, under the same name it uses
  // there. Nothing to disambiguate against: it is not one of the
  // 基督门徒福音会 congregations.
  'ydh': {
    'en': 'Yahweh De Hua Ministry',
    'zh-Hans': '雅伟的话',
    'zh-Hant': '雅偉的話',
  },
};

String localizedSongSource(String source, String locale) {
  final m = songSourceLabels[source];
  if (m == null) return source;
  return m[locale] ?? m['en'] ?? source;
}

/// Localised language-chip labels.
const Map<String, Map<String, String>> songLanguageLabels = {
  'zh': {'en': 'Chinese', 'zh-Hans': '中文', 'zh-Hant': '中文'},
  'en': {'en': 'English', 'zh-Hans': '英文', 'zh-Hant': '英文'},
  'id': {'en': 'Indonesian', 'zh-Hans': '印尼文', 'zh-Hant': '印尼文'},
};

String localizedSongLanguage(String language, String locale) {
  final m = songLanguageLabels[language];
  if (m == null) return language.toUpperCase();
  return m[locale] ?? m['en'] ?? language;
}

/// Localised theme tag labels. Keys are the canonical Chinese tag
/// stored in songs.json (`敬拜`, `救恩`, …) — these mirror fydt.org's
/// own `song_category` taxonomy, which is also applied to the CDC and
/// Cahaya rows by the sync script's title classifier.
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
  '爱人': {'en': 'Love One Another', 'zh-Hans': '爱人', 'zh-Hant': '愛人'},
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
  // Style categories fydt keeps alongside the thematic ones.
  '现场': {'en': 'Live', 'zh-Hans': '现场', 'zh-Hant': '現場'},
  '安静': {'en': 'Quiet', 'zh-Hans': '安静', 'zh-Hant': '安靜'},
  '活泼': {'en': 'Upbeat', 'zh-Hans': '活泼', 'zh-Hant': '活潑'},
  '中国民谣风': {
    'en': 'Chinese Folk',
    'zh-Hans': '中国民谣风',
    'zh-Hant': '中國民謠風',
  },
};

String localizedSongTheme(String themeKey, String locale) {
  final m = songThemeLabels[themeKey];
  if (m == null) return themeKey;
  return m[locale] ?? m['en'] ?? themeKey;
}
