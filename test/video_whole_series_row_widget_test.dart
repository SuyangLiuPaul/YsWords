import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/video_series.dart';
import 'package:yswords/pages/videos_page.dart';
import 'package:yswords/providers/main_provider.dart';

/// Widget-layer coverage for `_wholeSeriesRow` (`videos_page.dart`),
/// the "watch the whole series" row that sits below a series' episode
/// list. `video_series_test.dart` already pins the MODEL half —
/// `VideoSeries.playableCompilations` drops a track marked
/// `unavailableSince` and, unlike `VideoEpisode.defaultTrack`, never
/// falls back to `compilations.first` — but nothing rendered the
/// consumer of that getter before this file: `test/` had no widget test
/// for `videos_page.dart` at all (confirmed by grepping `test/` for
/// `VideoSeriesPage` and `VideosPage` — the only hits were the
/// URL-routing dispatch tests, which stub past the page's own body).
///
/// The detail worth pinning is not just "no button for a dead
/// compilation" (the model test already implies that) but that the row
/// disappears as a WHOLE, heading included — `_wholeSeriesRow` returns
/// `SizedBox.shrink()` only when `compilations.isEmpty`, so a version of
/// the guard that filtered the button list but left the heading behind
/// would print "Watch the whole series" over nothing to press, which
/// reads as a loading failure rather than "there is nothing here."
///
/// Episode tracks below use `lang: 'yue'` / `labelKey: 'oneGodLangYue'`
/// (廣東話) deliberately, distinct from the compilation labels used
/// here (`oneGodLangEn` 英语, `oneGodLangCmn` 普通话) — so a button
/// asserted absent/present for a compilation can't be satisfied by a
/// same-language chip in the unrelated episode-language row above it.
void main() {
  Widget wrap(VideoSeries series) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettings>(create: (_) => AppSettings()),
          ChangeNotifierProvider<MainProvider>(create: (_) => MainProvider()),
        ],
        child: MaterialApp(home: VideoSeriesPage(series: series)),
      );

  // `VideoSeriesPage`'s body is a plain (non-builder) `ListView`, whose
  // sliver machinery only materialises children near the viewport —
  // same trap `illustration_rights_test.dart` documents for
  // `AboutPage`. `_wholeSeriesRow` sits below the player, the language
  // row and both episode tiles, well past a default test surface, so
  // every `find` below would report "0 widgets" regardless of whether
  // the row rendered unless the surface is tall enough for the whole
  // page to fit without scrolling.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  VideoSeries seriesWith(List<VideoTrack> compilations) => VideoSeries(
        id: 'fixture',
        titles: const {'en': 'Fixture Series'},
        taglines: const {'en': 'A Fixture'},
        creditKey: 'oneGodCredit',
        compilations: compilations,
        episodes: [
          VideoEpisode(
            id: '01',
            number: 1,
            titles: const {'en': 'Part 1'},
            tracks: const [
              VideoTrack(
                lang: 'yue',
                labelKey: 'oneGodLangYue',
                youtubeId: 'aaaaaaaaaaa',
              ),
            ],
          ),
          VideoEpisode(
            id: '02',
            number: 2,
            titles: const {'en': 'Part 2'},
            tracks: const [
              VideoTrack(
                lang: 'yue',
                labelKey: 'oneGodLangYue',
                youtubeId: 'bbbbbbbbbbb',
              ),
            ],
          ),
        ],
      );

  // AppSettings() defaults to 'zh-Hans' synchronously (see the same note
  // in url_routing_stage4_batch2_test.dart), which is the locale these
  // pages actually render with in a freshly-pumped test.
  const heading = '完整版（十集合一）'; // uiStrings['videoWholeSeries']['zh-Hans']
  const englishLabel = '英语'; // uiStrings['oneGodLangEn']['zh-Hans']
  const mandarinLabel = '普通话'; // uiStrings['oneGodLangCmn']['zh-Hans']

  testWidgets(
    'a series whose compilations are ALL unavailable renders no whole-'
    'series row at all — heading included, not just the buttons',
    (tester) async {
      final series = seriesWith(const [
        VideoTrack(
          lang: 'en',
          labelKey: 'oneGodLangEn',
          youtubeId: 'ccccccccccc',
          unavailableSince: '2026-09-06',
        ),
        VideoTrack(
          lang: 'cmn',
          labelKey: 'oneGodLangCmn',
          youtubeId: 'ddddddddddd',
          unavailableSince: '2026-09-06',
        ),
      ]);
      useTallSurface(tester);
      await tester.pumpWidget(wrap(series));
      await tester.pumpAndSettle();

      expect(find.text(heading), findsNothing,
          reason: 'the heading must not be left orphaned above an empty '
              'button row');
      expect(find.text(englishLabel), findsNothing);
      expect(find.text(mandarinLabel), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    },
  );

  testWidgets(
    'a partially-marked series renders exactly the playable '
    "compilations' buttons, and no button for the marked one",
    (tester) async {
      final series = seriesWith(const [
        VideoTrack(
          lang: 'en',
          labelKey: 'oneGodLangEn',
          youtubeId: 'ccccccccccc',
          unavailableSince: '2026-09-06',
        ),
        VideoTrack(
          lang: 'cmn',
          labelKey: 'oneGodLangCmn',
          youtubeId: 'ddddddddddd',
        ),
      ]);
      useTallSurface(tester);
      await tester.pumpWidget(wrap(series));
      await tester.pumpAndSettle();

      expect(find.text(heading), findsOneWidget);
      expect(find.text(mandarinLabel), findsOneWidget);
      expect(find.text(englishLabel), findsNothing,
          reason: 'the marked English compilation must not get a button');
      expect(find.byType(OutlinedButton), findsOneWidget,
          reason: 'exactly one playable compilation should render');
    },
  );
}
