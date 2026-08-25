import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/video_series.dart';

/// The language↔video-id pairing, as YouTube itself reports it.
///
/// **This is the point of the file.** The pairing was first taken from
/// where each embed sits on the church's page relative to its caption,
/// and that reading was wrong for all ten rows — it offered "English"
/// and would have played the Cantonese recording, and offered "part 10
/// Chinese" for the three-hour full-series compilation.
///
/// Every id below was confirmed against `youtube.com/oembed`, whose
/// title states the language outright ("02 Standing at the Cross — …"
/// vs "02 在十字架下：十堂人生課！第二課：…"). Layout is a heuristic; the
/// publisher's own title is not.
const _crossEn = [
  '1OIZE4HnheE',
  'Voc7M_I1YJw',
  'omzJLl83zIo',
  'Xee1AhOkiDY',
  '-JgvZGZ8zmc',
  'kuZ8qcAm7UI',
  'ZzXZmSmMtWs',
  'Slng6u-YMsM',
  '5Z1upfO2Ff0',
  'bIJXg7dew2g',
];
const _crossYue = [
  'h7hE0XB3SWs',
  '4WladhGvkAM',
  'GgUiSRBMgj4',
  'xXC3IYb128Q',
  'zCyNjjWhkMg',
  '483CYa3BjXg',
  'OPzyLFP-TMA',
  'SjQCm4m-rmk',
  'OSKe5G6BW8c',
  'CincIrfTfDs',
];

/// Not episodes, and must never be listed as one: these are the whole
/// series in a single video. Putting either in the episode list makes a
/// 10-part series look like an 11-part one.
const _compilations = ['J8bBBHIuxjI', 'QXU-gazdgN0'];

void main() {
  late List<VideoSeries> series;

  setUpAll(() {
    final raw = File('assets/videos.json').readAsStringSync();
    series = VideoSeries.listFromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  VideoSeries byId(String id) => series.firstWhere((s) => s.id == id);

  test('every track carries a well-formed YouTube id', () {
    final seen = <String>{};
    for (final s in series) {
      for (final e in s.episodes) {
        expect(e.tracks, isNotEmpty, reason: '${s.id}/${e.id} has no tracks');
        for (final t in e.tracks) {
          expect(t.youtubeId, matches(RegExp(r'^[A-Za-z0-9_-]{11}$')),
              reason: '${s.id}/${e.id}/${t.lang}');
          expect(seen.add(t.youtubeId), isTrue,
              reason: '${t.youtubeId} is used twice — a copy-paste in the '
                  'data means two episodes play the same video');
        }
        final langs = e.tracks.map((t) => t.lang).toList();
        expect(langs.toSet().length, langs.length,
            reason: '${s.id}/${e.id} lists a language twice');
      }
    }
  });

  test('Standing at the Cross keeps the oEmbed-verified pairing', () {
    final cross = byId('cross');
    expect(cross.episodes.length, 10);
    for (var i = 0; i < 10; i++) {
      final e = cross.episodes[i];
      expect(e.number, i + 1);
      expect(e.trackFor('en')!.youtubeId, _crossEn[i],
          reason: 'part ${i + 1} English');
      expect(e.trackFor('yue')!.youtubeId, _crossYue[i],
          reason: 'part ${i + 1} Cantonese');
    }
  });

  test('the full-series compilations are not listed as episodes', () {
    final ids = [
      for (final s in series)
        for (final e in s.episodes)
          for (final t in e.tracks) t.youtubeId,
    ];
    for (final c in _compilations) {
      expect(ids, isNot(contains(c)));
    }
  });

  test('a language a series does not have is absent, not substituted', () {
    // 在十字架下 was recorded in English and Cantonese; the Mandarin
    // version is being made now, one episode at a time. The user's rule
    // for the gap has not changed — "如果没有普通话就空着没问题" — so an
    // episode without a Mandarin recording must offer no Mandarin button
    // rather than quietly playing the Cantonese take under that label.
    // As of 2026-08-25 exactly episode 01 has one.
    final crossEpisodes = byId('cross').episodes;
    expect(crossEpisodes.first.id, '01');
    expect(crossEpisodes.first.tracks.map((t) => t.lang),
        ['en', 'yue', 'cmn']);
    for (final e in crossEpisodes.skip(1)) {
      expect(e.trackFor('cmn'), isNull, reason: 'episode ${e.id}');
      expect(e.tracks.map((t) => t.lang), ['en', 'yue'],
          reason: 'episode ${e.id}');
    }
    // 獨一真神 does have all three.
    expect(byId('onegod').episodes.single.tracks.map((t) => t.lang),
        ['en', 'yue', 'cmn']);
  });

  test('no two tracks share a YouTube id', () {
    // 2026-08-25: 獨一真神's English recording had gone (S7VEdxrWcX8,
    // 404 from oEmbed) and nothing could tell — the card rendered, the
    // English button appeared, and tapping it played nothing. Liveness
    // needs the network, so it lives in tools/verify_video_links.py
    // rather than here; what a unit test CAN catch is the repair going
    // wrong, by pasting one video over two slots.
    final ids = [
      for (final s in series)
        for (final e in s.episodes)
          for (final t in e.tracks) t.youtubeId,
    ];
    expect(ids.toSet().length, ids.length,
        reason: 'a duplicated id means two languages play the same file');
    expect(ids, isNot(contains('S7VEdxrWcX8')),
        reason: 'that id is dead; it must not come back in a later edit');
  });

  test('獨一真神 English points at the replacement recording', () {
    final en = byId('onegod').episodes.single.trackFor('en');
    expect(en, isNotNull);
    expect(en!.youtubeId, 'QmTEkPquvcQ');
  });

  test('titles resolve for every locale the app offers', () {
    for (final s in series) {
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expect(s.titleFor(locale), isNotEmpty);
        expect(s.taglineFor(locale), isNotEmpty);
        for (final e in s.episodes) {
          expect(e.titleFor(locale), isNotEmpty,
              reason: '${s.id}/${e.id} has no title in $locale');
        }
      }
      // 2026-08-25: the assertion here used to be the OPPOSITE — that
      // both Chinese locales resolve to one stored string, because a
      // converted glyph would be our word rather than the church's. The
      // user asked for two scripts, and the audit showed the old claim
      // did not hold anyway: the single string was internally mixed
      // (episode 1 said 哪裡 while episode 6 said 黑暗里) and the file had
      // drawn different episodes from different sources.
      //
      // What matters now is that every locale gets its OWN script, so
      // no title may fall back and none may be left with a bare 'zh'.
      expect(s.titles.containsKey('zh'), isFalse,
          reason: '${s.id}: a bare zh serves both locales and is a trap');
      //
      // Note the shape: NOT "every episode has Chinese". The Shema
      // episodes are English-only because the church published them
      // that way, and inventing Chinese titles for them would be the
      // very thing this file refuses to do. The rule is that Chinese,
      // where it exists, exists in both scripts — never in one, and
      // never as a bare 'zh' that silently serves both.
      for (final e in s.episodes) {
        expect(e.titles.containsKey('zh'), isFalse,
            reason: '${s.id}/${e.id}: bare zh');
        expect(e.titles.containsKey('zh-Hans'),
            e.titles.containsKey('zh-Hant'),
            reason: '${s.id}/${e.id}: has one Chinese script but not the '
                'other, so one locale falls back to English');
      }
    }
  });

  test('a one-episode series is a video, not a list of one', () {
    expect(byId('onegod').isSingle, isTrue);
    expect(byId('cross').isSingle, isFalse);
  });
}
