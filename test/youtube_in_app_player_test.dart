import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/media_focus.dart';
import 'package:yswords/services/song_service.dart';
import 'package:yswords/utils/youtube_url.dart';
import 'package:yswords/widgets/youtube_player_sheet.dart';

/// 2026-08-24: "歌曲里面有几个是YouTube如果按了去YouTube了，但是web 和ios
/// 能不能不跳转出去，好像WhatsApp那样YouTube对话框在播放音乐，其实整个app
/// 都要这样".
///
/// The fix hangs off [LinkOpener.openOrWarn], so what is worth testing
/// is the routing, not the player: a YouTube link stays in the app, a
/// platform with no webview still leaves, and everything that is not
/// YouTube behaves exactly as it did — that last one being the property
/// a change at a 17-caller chokepoint could quietly break.
///
/// The real embed cannot run here. A widget test runs on the host VM,
/// where the io variant reports macOS as embeddable and then throws on
/// mount for want of a registered webview platform, so
/// [debugYoutubeEmbedBuilder] stands in for it — which also lets the
/// Windows/Linux "no player here" branch be exercised on a Mac.
void main() {
  const videoUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
  const fakePlayer = Key('fake-youtube-player');

  setUp(() {
    debugYoutubeEmbedBuilder = (_) => const SizedBox(key: fakePlayer);
    MediaFocus.instance.clearForTest();
  });

  tearDown(() {
    debugYoutubeEmbedBuilder = null;
    MediaFocus.instance.clearForTest();
  });

  /// A page with one button, so the tap goes through the same call the
  /// Songs chips and every other link in the app go through.
  Widget host(String url) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () =>
                    LinkOpener.openOrWarn(context, url, locale: 'en'),
                child: const Text('link'),
              ),
            ),
          ),
        ),
      );

  testWidgets('a YouTube link plays in a sheet instead of leaving',
      (tester) async {
    await tester.pumpWidget(host(videoUrl));
    await tester.tap(find.text('link'));
    await tester.pumpAndSettle();

    expect(find.byKey(fakePlayer), findsOneWidget);
    // The two affordances the sheet owes the user: a way out of it, and
    // a way to the real thing.
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Watch on YouTube'), findsOneWidget);
    // 16:9, so a phone in portrait gets a player and not a letterbox.
    expect(
      tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
      16 / 9,
    );
  });

  testWidgets('closing the sheet takes the player with it', (tester) async {
    // Disposing the embed is what stops the sound — there is no pause to
    // call, which is the same asymmetry the sheet documents to
    // MediaFocus.
    await tester.pumpWidget(host(videoUrl));
    await tester.tap(find.text('link'));
    await tester.pumpAndSettle();
    expect(find.byKey(fakePlayer), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byKey(fakePlayer), findsNothing);
  });

  testWidgets('a video starting silences the hymn', (tester) async {
    // "如果视频在播应该歌曲会自动停" (2026-08-11) has to keep holding for
    // a video that starts from a link, not just one started on the
    // videos page.
    var songPaused = false;
    final song = Object();
    MediaFocus.instance.register(song, () async => songPaused = true);

    await tester.pumpWidget(host(videoUrl));
    await tester.tap(find.text('link'));
    await tester.pumpAndSettle();

    expect(songPaused, isTrue);
  });

  testWidgets('a platform with no webview still links out', (tester) async {
    // Windows and Linux: `webview_flutter` compiles there and has no
    // implementation, so [youtubeEmbed] returns null and the link must
    // take the old path rather than open an empty black box.
    debugYoutubeEmbedBuilder = (_) => null;

    await tester.pumpWidget(host(videoUrl));
    await tester.tap(find.text('link'));
    await tester.pumpAndSettle();

    expect(find.byKey(fakePlayer), findsNothing);
    expect(find.text('Watch on YouTube'), findsNothing);
  });

  testWidgets('a non-YouTube link is untouched by any of this',
      (tester) async {
    // SoundCloud is the other external player in Songs, and it must go
    // on leaving the app exactly as it did before the chokepoint learned
    // about YouTube.
    await tester.pumpWidget(host(
        'https://w.soundcloud.com/player/?url=https%3A//api.soundcloud.com/tracks/1'));
    await tester.tap(find.text('link'));
    await tester.pumpAndSettle();

    expect(find.byKey(fakePlayer), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });

  test('every YouTube row in the catalogue resolves to a playable id',
      () async {
    // A data check, not a code check, in the shape the Cahaya test uses:
    // the 20 Cahaya rows whose only audio is on YouTube are exactly the
    // ones the user was tapping ("歌曲里面有几个是YouTube"), and they
    // reach the player through the URL `Song.youtubeUrl` builds. A
    // future sync landing an id of the wrong shape would not fail any
    // widget test — the row would just go quietly back to jumping out.
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final songs = await SongService.load();
    final youtubeRows = songs.where((s) => s.youtubeUrl != null).toList();
    expect(youtubeRows, isNotEmpty);
    for (final song in youtubeRows) {
      expect(youtubeVideoId(song.youtubeUrl!), isNotNull,
          reason: '${song.id} would still leave the app');
    }

    // The rows with nowhere else to go — no stream, no SoundCloud — are
    // the ones this change is actually for.
    final youtubeOnly = youtubeRows
        .where((s) => !s.hasPlayableAudio && s.soundcloudUrl == null)
        .toList();
    expect(youtubeOnly, isNotEmpty,
        reason: 'the YouTube-only rows are why the player exists');
  });

  // 2026-08-24: added after review reproduced a RenderFlex overflow at
  // every common phone-landscape size. The suite was green only because
  // the default 800x600 test surface happens to be the one shape where
  // the fixed content fits, and the repo's responsive suite is
  // portrait-only — so nothing covered the orientation people actually
  // watch video in.
  group('landscape', () {
    for (final size in const [
      Size(844, 390), // iPhone 14/15
      Size(667, 375), // iPhone SE
      Size(915, 412), // common Android
    ]) {
      testWidgets('no overflow, escape hatch on screen at '
          '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        addTearDown(tester.view.reset);
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = size;

        await tester.pumpWidget(host(videoUrl));
        await tester.tap(find.text('link'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'the player must fit the viewport, not overflow it');

        final hatch = find.textContaining('YouTube').last;
        final box = tester.getRect(hatch);
        expect(box.bottom, lessThanOrEqualTo(size.height),
            reason: 'the "Watch on YouTube" escape hatch was entirely '
                'below the fold at this size before the height bound');
      });
    }
  });
}
