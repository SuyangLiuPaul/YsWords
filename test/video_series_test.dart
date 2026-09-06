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

/// Which 在十字架下 episodes have a Mandarin recording YET.
///
/// The user is producing them one at a time and hands over a link when
/// each is done: `01` on 2026-08-25, `02` on 2026-09-01, `03` on
/// 2026-09-02, `04` on 2026-09-03, `05`-`07` on 2026-09-04, and `08`
/// and `09` on 2026-09-05. `08` was REFUSED once before it was filed:
/// its title then carried no 普通话版 marker and matched the Cantonese
/// track's exactly. The title was corrected upstream and it now passes
/// on its own evidence — see `_meta.crossMandarin`. Add an id here only after confirming by YouTube oEmbed
/// that its title carries BOTH the right ordinal and 普通话版 — the
/// church's page layout is one row out for this series, which is the
/// mistake `_meta.pairingEvidence` exists to prevent.
const _crossWithMandarin = {
  '01', '02', '03', '04', '05', '06', '07', '08', '09',
  // Episode 10 (AiiyRGaRJBY) filed 2026-09-05 — the last one. The
  // series is now COMPLETE at 10/10, so the `['en', 'yue']` branch
  // below no longer fires for 在十字架下. It stays because the rule it
  // encodes outlives this series: an episode with no Mandarin take
  // offers no Mandarin button rather than playing the Cantonese one
  // under that label.
  '10',
};

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
    //
    // [_crossWithMandarin] is a deliberate ledger, not a derived value:
    // the point of this test is that adding a Mandarin id is a decision
    // someone made and checked (see `_meta.crossMandarin` — every id is
    // verified by oEmbed before it is filed), so it should cost one
    // explicit line here. Deriving the set from the data would make the
    // test agree with whatever the file happens to say.
    final crossEpisodes = byId('cross').episodes;
    for (final e in crossEpisodes) {
      final expected = _crossWithMandarin.contains(e.id)
          ? ['en', 'yue', 'cmn']
          : ['en', 'yue'];
      expect(e.tracks.map((t) => t.lang), expected,
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

  test('a track marked unavailable is dropped from playableTracks', () {
    // 2026-09-05: onegod/01's English id started returning 403 from
    // oEmbed — "This video is private" in the shipped player. The rule
    // that came out of it: a chip that opens a dead player is the app
    // stating something untrue, so `_languageRow` builds its buttons
    // from `playableTracks`, not `tracks`.
    //
    // 2026-09-06: this test used to assert that state against the LIVE
    // asset — that onegod/01's English track IS unavailable. The church
    // made the video public again the next day and the test failed,
    // which is the right outcome for a bad test and the wrong one for a
    // good one: whether a third party's video is private today is not a
    // property this repo can pin. The RULE is. It is tested on a fixture
    // now, and `node tools/check_video_ids.js` is what watches the live
    // ids — it reports 66/66 playable as of today.
    final ep = VideoEpisode.fromJson({
      'id': '01',
      'number': 1,
      'titles': {'en': 'fixture'},
      'tracks': [
        {
          'lang': 'en',
          'labelKey': 'oneGodLangEn',
          'youtubeId': 'DEADVIDEO01',
          'unavailableSince': '2026-09-05',
        },
        {'lang': 'yue', 'labelKey': 'oneGodLangYue', 'youtubeId': 'LIVEYUE001'},
        {'lang': 'cmn', 'labelKey': 'oneGodLangCmn', 'youtubeId': 'LIVECMN001'},
      ],
    });
    expect(ep.tracks.map((t) => t.youtubeId), contains('DEADVIDEO01'),
        reason: 'the id must stay in the data — deleting it would throw '
            'away the only way to restore the track');
    expect(ep.trackFor('en')!.isUnavailable, isTrue);
    expect(ep.playableTracks.map((t) => t.lang), isNot(contains('en')));
    expect(ep.playableTracks.map((t) => t.lang), containsAll(['yue', 'cmn']));
  });

  test('the live onegod episode carries no unavailable track today', () {
    // The live half, stated as what it is: a snapshot, not a rule. If
    // this fails, a video went private — run `node tools/check_video_ids.js`
    // and mark it, rather than editing the fixture above.
    final ep = byId('onegod').episodes.single;
    expect(ep.tracks.map((t) => t.youtubeId), contains('QmTEkPquvcQ'));
    expect(ep.playableTracks.length, ep.tracks.length,
        reason: 'every onegod track was playable when this was measured');
  });

  test('an English-locale reader is not auto-selected into the dead video',
      () {
    // The sharper half of the 2026-09-05 bug: QmTEkPquvcQ is tracks[0],
    // so before this fix `defaultTrack` and `trackForLocale('en')` both
    // returned it — an English-locale reader landed on a dead player
    // before tapping anything, not just a dead button.
    // 2026-09-06: the English id is public again, so it is once more the
    // correct answer here. What this test now pins is the MECHANISM —
    // an unavailable tracks[0] must not be auto-selected — on a fixture,
    // just above. Kept as a live check that the episode still resolves.
    final ep = byId('onegod').episodes.single;
    expect(ep.defaultTrack?.youtubeId, isNotNull);
    final forEn = ep.trackForLocale('en');
    expect(forEn, isNotNull);
    // With the English track playable again, the first preference IS the
    // answer. The interesting half — that a MARKED tracks[0] is skipped
    // for the next preference rather than merely "not returned" — is
    // asserted on the fixture below, where it cannot be undone by the
    // church changing a video's visibility.
    expect(forEn!.lang, 'en');
  });

  test('a marked tracks[0] is skipped for the NEXT preference, not dropped',
      () {
    // The sharper half of the 2026-09-05 bug, on a fixture: QmTEkPquvcQ
    // was tracks[0], so `defaultTrack` and `trackForLocale('en')` both
    // returned it and an English reader landed on a dead player before
    // tapping anything. preferredTrackLangs for a non-zh locale is
    // ['en', 'cmn', 'yue'], so with 'en' marked the answer must be
    // Mandarin — not null, and not Cantonese.
    final ep = VideoEpisode.fromJson({
      'id': '01',
      'number': 1,
      'titles': {'en': 'fixture'},
      'tracks': [
        {
          'lang': 'en',
          'labelKey': 'oneGodLangEn',
          'youtubeId': 'DEADVIDEO01',
          'unavailableSince': '2026-09-05',
        },
        {'lang': 'yue', 'labelKey': 'oneGodLangYue', 'youtubeId': 'LIVEYUE001'},
        {'lang': 'cmn', 'labelKey': 'oneGodLangCmn', 'youtubeId': 'LIVECMN001'},
      ],
    });
    expect(ep.defaultTrack?.youtubeId, isNot('DEADVIDEO01'));
    expect(ep.trackForLocale('en')?.lang, 'cmn');
  });

  test('every episode keeps at least one playable track', () {
    // The guard for the case none of today's data is in: if every track
    // on an episode were ever marked unavailable at once,
    // VideoEpisode.defaultTrack falls back to tracks.first (see its own
    // doc comment) rather than returning null, so the player always has
    // something to attempt instead of rendering an empty screen with no
    // explanation. This test pins that NO episode currently relies on
    // that fallback — if it starts failing, a real episode has gone
    // fully dark and someone needs to look, not silently degrade.
    for (final s in series) {
      for (final e in s.episodes) {
        expect(e.playableTracks, isNotEmpty,
            reason: '${s.id}/${e.id} has no playable track left');
      }
    }
  });

  test('VideoEpisode.defaultTrack degrades sanely if all tracks are marked',
      () {
    final allDead = VideoEpisode(
      id: 'x',
      number: 1,
      titles: const {'en': 'x'},
      tracks: const [
        VideoTrack(
          lang: 'en',
          labelKey: 'oneGodLangEn',
          youtubeId: 'aaaaaaaaaaa',
          unavailableSince: '2026-09-05',
        ),
      ],
    );
    // No playable track exists at all; the guard returns the marked one
    // rather than null, so the player has something to attempt instead
    // of an unexplained blank screen. This is a fallback of last resort,
    // not a claim that the video plays.
    expect(allDead.defaultTrack?.youtubeId, 'aaaaaaaaaaa');
    expect(allDead.playableTracks, isEmpty);
  });

  test('a compilation marked unavailable is dropped from playableCompilations',
      () {
    // Synthetic — no real compilation carries unavailableSince today (see
    // 'zero compilation ids carry unavailableSince', below). This pins the
    // filter for the day one does.
    final s = VideoSeries(
      id: 'x',
      titles: const {'en': 'x'},
      taglines: const {'en': 'x'},
      creditKey: 'oneGodCredit',
      episodes: const [],
      compilations: const [
        VideoTrack(
          lang: 'en',
          labelKey: 'oneGodLangEn',
          youtubeId: 'aaaaaaaaaaa',
          unavailableSince: '2026-09-06',
        ),
        VideoTrack(
          lang: 'cmn',
          labelKey: 'oneGodLangCmn',
          youtubeId: 'bbbbbbbbbbb',
        ),
      ],
    );
    expect(s.playableCompilations.map((t) => t.lang), ['cmn']);
  });

  test(
      'VideoSeries.playableCompilations hides the row rather than falling '
      'back, unlike VideoEpisode.defaultTrack', () {
    // The whole-series row is optional decoration, not a player that must
    // show something — so when every compilation is marked, the filtered
    // list must be empty (which makes _wholeSeriesRow's isEmpty guard hide
    // the row), not fall back to compilations.first the way
    // VideoEpisode.defaultTrack falls back to tracks.first.
    final allDead = VideoSeries(
      id: 'x',
      titles: const {'en': 'x'},
      taglines: const {'en': 'x'},
      creditKey: 'oneGodCredit',
      episodes: const [],
      compilations: const [
        VideoTrack(
          lang: 'en',
          labelKey: 'oneGodLangEn',
          youtubeId: 'aaaaaaaaaaa',
          unavailableSince: '2026-09-06',
        ),
      ],
    );
    expect(allDead.playableCompilations, isEmpty);
  });

  test('zero compilation ids carry unavailableSince today', () {
    // The gate this item adds has nothing live to filter yet — the only
    // unavailableSince in assets/videos.json is on onegod/01's English
    // track, not a compilation. This pins that fact so it is visible if
    // it ever changes rather than assumed.
    for (final s in series) {
      for (final c in s.compilations) {
        expect(c.isUnavailable, isFalse, reason: '${s.id}/${c.youtubeId}');
      }
    }
  });

  test('cross still offers both compilations today', () {
    final cross = byId('cross');
    expect(cross.compilations.length, 2);
    expect(cross.playableCompilations.map((t) => t.youtubeId).toSet(),
        cross.compilations.map((t) => t.youtubeId).toSet());
  });
}
