import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/video_series.dart';

/// Two requests from 2026-08-23.
///
/// 1. "featured video可以开一个新的吗？神造人的目的" — a new series with a
///    Mandarin and a Cantonese recording and no English one.
/// 2. "featured video里面也要根据用户选择的语言自动改变吧，但是shema不是
///    但是可以shema系列" — open in the reader's language, and give the
///    English-only Shema series a Chinese name since it cannot switch.
void main() {
  final doc = jsonDecode(File('assets/videos.json').readAsStringSync())
      as Map<String, dynamic>;
  final all = VideoSeries.listFromJson(doc);
  VideoSeries byId(String id) => all.firstWhere((s) => s.id == id);

  group('神造人的目的', () {
    test('is a series with one episode', () {
      final s = byId('purpose');
      expect(s.episodes, hasLength(1));
      expect(s.isSingle, isTrue);
      expect(s.titleFor('zh-Hans'), '神造人的目的');
    });

    test('carries exactly the two ids the user sent, on the right languages',
        () {
      // Verified through youtube.com/oembed, which returns the
      // publisher's own title: "神造人的目的 _ 基督門徒福音會 (普通话)"
      // and "神造人的目的(粵語)". Reading the language off the title is
      // the rule this file already follows — a Standing-at-the-Cross
      // table built from page position was wrong for all ten rows.
      final e = byId('purpose').episodes.single;
      expect(e.trackFor('cmn')?.youtubeId, '-Qn_1kTlOgM');
      expect(e.trackFor('yue')?.youtubeId, 'bTWFB2npS88');
    });

    test('offers no English, because none was published', () {
      // Per the user, 2026-08-17: "如果没有普通话就空着没问题没有就空着".
      // An absent recording must be absent, not the other language
      // playing under an English button.
      expect(byId('purpose').episodes.single.trackFor('en'), isNull);
    });
  });

  group('the opening track follows the app language', () {
    test('a Chinese reader does not land on English', () {
      // The defect: _lang was seeded from the first track in the JSON,
      // which is English for every series that has one.
      final e = byId('purpose').episodes.single;
      expect(e.trackForLocale('zh-Hans')?.lang, 'cmn');
      expect(e.trackForLocale('zh-Hant')?.lang, 'yue');
      expect(e.trackForLocale('en')?.lang, isNot('en'),
          reason: 'this series has no English — it must still open');
    });

    test('and an English reader still gets English where it exists', () {
      final e = byId('onegod').episodes.single;
      expect(e.trackForLocale('en')?.lang, 'en');
      expect(e.trackForLocale('zh-Hans')?.lang, 'cmn');
      expect(e.trackForLocale('zh-Hant')?.lang, 'yue');
    });

    test('an English-only series opens rather than showing nothing', () {
      // Every Shema track is English. Falling back is the whole reason
      // English ends every preference list.
      final e = byId('shema-1').episodes.first;
      expect(e.trackForLocale('zh-Hans')?.lang, 'en');
      expect(e.trackForLocale('zh-Hant')?.lang, 'en');
    });

    test('在十字架下 is mid-recording: the finished episodes have Mandarin, '
        'the rest fall to Cantonese', () {
      // The user is recording the 普通话版 one episode at a time and hands
      // over each link as it is done — episode 1 on 2026-08-25, episode 2
      // on 2026-09-01, 3 on 2026-09-02, 4 on 2026-09-03, 5-7 on
      // 2026-09-04, and 8 and 9 on 2026-09-05. Only 10 is still absent.
      // Coverage therefore
      // differs BETWEEN EPISODES OF ONE SERIES — the first case in this
      // file — so a Simplified reader gets Mandarin on the finished ones
      // and Cantonese on the rest, from the same series.
      //
      // The ids are spelled out rather than derived: filing a Mandarin
      // recording under the wrong episode is invisible on screen (a
      // Mandarin button that plays the wrong lesson), and this is where
      // that would be caught.
      const mandarin = {
        '01': 'g-Wk0qbuAkE',
        '02': '3qQu-vA8ZIU',
        '03': '5PVmXtDBsxA',
        '04': 'JcmOX7fjc7Q',
        '05': 'kmFTrLtfISQ',
        '06': 'gUr2d_axXYY',
        '07': 'xmTw9MprLDc',
        '08': 'og1rthWUJ00',
        '09': 'E2Z8Y3EIbeI',
      };
      for (final e in byId('cross').episodes) {
        final id = mandarin[e.id];
        if (id != null) {
          expect(e.trackFor('cmn')?.youtubeId, id, reason: 'episode ${e.id}');
          expect(e.trackForLocale('zh-Hans')?.lang, 'cmn',
              reason: 'episode ${e.id}');
        } else {
          expect(e.trackFor('cmn'), isNull, reason: 'episode ${e.id}');
          expect(e.trackForLocale('zh-Hans')?.lang, 'yue',
              reason: 'episode ${e.id}');
        }
      }
    });

    test('the preference lists are ordered, and English never leads zh', () {
      expect(preferredTrackLangs('zh-Hans').first, 'cmn');
      expect(preferredTrackLangs('zh-Hant').first, 'yue');
      expect(preferredTrackLangs('en').first, 'en');
      for (final l in ['zh-Hans', 'zh-Hant']) {
        expect(preferredTrackLangs(l).last, 'en',
            reason: 'English must remain the last resort, not be dropped');
        expect(preferredTrackLangs(l), hasLength(3),
            reason: 'every spoken language must appear, or a series '
                'becomes unreachable for that locale');
      }
    });
  });

  group('the Shema series reads as Chinese in a Chinese app', () {
    // It cannot switch language — the church published it in English
    // only — so the name is the part that can be localised.
    for (final id in ['shema-1', 'shema-2', 'shema-3', 'shema-4']) {
      test('$id has a name in both scripts', () {
        final s = byId(id);
        for (final locale in ['zh-Hans', 'zh-Hant']) {
          expect(s.titleFor(locale), contains('Shema'));
          expect(s.titleFor(locale), contains('系列'));
          expect(s.taglineFor(locale), isNot(s.taglineFor('en')),
              reason: 'the tagline must be translated too, or the card '
                  'is half Chinese and half English');
        }
        // Simplified and Traditional are written out separately here
        // because these are OUR labels, not the church's copy.
        expect(s.titles.containsKey('zh-Hans'), isTrue);
        expect(s.titles.containsKey('zh-Hant'), isTrue);
      });
    }

    test('but the episode titles stay in the church\'s own words', () {
      final e = byId('shema-1').episodes.first;
      expect(e.titles.keys, ['en'],
          reason: 'translating the church\'s episode titles would be '
              'putting our words in their mouth');
    });
  });

  test('every series names a credit string that actually exists', () {
    // shema-1..4 pointed at 'videoCreditCdc', which was never defined,
    // so the page fell through to a hard-coded English literal.
    final strings = File('lib/constants/ui_strings.dart').readAsStringSync();
    for (final s in all) {
      expect(strings, contains("'${s.creditKey}':"),
          reason: '${s.id} credits "${s.creditKey}", which is not in '
              'ui_strings — the page will show English to everyone');
    }
  });
}
