import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/now_playing_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/song_player_service.dart';
import 'package:yswords/services/song_service.dart';
import 'package:yswords/utils/route_paths.dart' show songShareUrl;
import 'package:yswords/widgets/song_actions.dart';

/// Share has to be on the screen you are ON when you decide to share.
///
/// The link itself shipped on 2026-09-07 and was verified in a browser,
/// but the button that produced it existed in exactly one place — the
/// songs list's detail sheet. The user found that out from the player:
/// "还是不能share", sent from Now Playing with the feature already
/// released. A link nobody can reach is not a shipped feature, and
/// `song_share_link_test.dart` could not have caught it because every
/// one of its assertions is about the string, not about who can get it.
///
/// So this file tests the other half: the button is reachable, and what
/// it puts on the clipboard is the link.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('Now Playing can share the song that is playing',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
    // Wide enough that the app bar draws every action rather than
    // folding the tail of them into an overflow menu — a share button
    // that only exists behind an overflow menu is a different (and
    // worse) answer to the report than the one being tested here.
    tester.view.physicalSize = const Size(900, 844);
    addTearDown(tester.view.reset);

    // What the platform was handed, so the assertion is about the
    // clipboard's contents and not about the call having happened.
    String? clipped;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipped = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });

    final catalogue = (await tester.runAsync(SongService.load))!;
    // The head of the queue must be a song that HAS words. Not every
    // row does — `fetch_setapak` ships none, by licence — and with a
    // null `lyrics` the "does not carry the lyrics" assertion below
    // would hold no matter what the button did. Requiring words is what
    // makes that last line a real assertion rather than a vacuous one.
    final playable = catalogue
        .where((s) => s.hasPlayableAudio && (s.lyrics?.trim().length ?? 0) > 40)
        .take(4)
        .toList();
    expect(playable.length, 4, reason: 'need a queue of songs with words');
    final playing = playable.first;
    final lyrics = playing.lyrics!.trim();

    final player = SongPlayerService.instance;
    await tester.runAsync(() => player.playQueue(playable, label: 'test'));
    // audioplayers reaches for platform channels that do not exist in a
    // widget test and reports its own start-up failure through
    // FlutterError. Drain it; nothing here decodes audio.
    tester.takeException();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: NowPlayingPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final button = find.byType(SongShareButton);
    expect(button, findsOneWidget,
        reason: 'the player is where you are when you decide to pass a '
            'song on; this is the button that was missing');

    await tester.tap(button);
    // Pumped rather than settled: the player screen never reaches a
    // quiescent frame (the toast the copy fallback raises runs its own
    // animation, and the scrubber keeps ticking), so pumpAndSettle
    // times out here on a page that is working perfectly.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // No native share sheet on the VM target (share_service_stub), so
    // shareOrCopy falls through to the clipboard — which is what makes
    // the payload readable here at all.
    expect(clipped, isNotNull,
        reason: 'tapping share must produce something to paste');

    // ONE link, and nothing on either side of it. Asked for directly —
    // "我们只要一个link按完那个share后" — after a shared `title\nlink`
    // pair arrived somewhere as a plain origin and booted the app to
    // the Bible reader instead of the song. Equality rather than
    // `contains`, because `contains` is what would still pass if a
    // title line, a hashtag or an app-store plug were prepended later,
    // and prepending text is exactly the defect.
    expect(clipped, songShareUrl(playing.id));
    expect(clipped!.trim().split(RegExp(r'\s')), hasLength(1),
        reason: 'whitespace splits the payload into things a chat app '
            'has to guess between; one URL leaves nothing to guess');
    expect(clipped, contains('song=${Uri.encodeComponent(playing.id)}'),
        reason: 'the shareable thing is a link that opens the song');
    expect(clipped, isNot(contains(lyrics)),
        reason: 'the lyrics have their own button on the one screen '
            'that draws them');
  });

  test('every screen that shows one song offers to share it', () {
    // A source-level sweep, because the bug was never in one screen's
    // logic — it was a button that existed in one file out of four.
    // The video and score pages need pdfrx and video_player to pump, so
    // reading them is what is available; the widget test above is the
    // one that proves the button actually renders and works.
    for (final path in const [
      'lib/pages/songs_page.dart', // the detail sheet
      'lib/pages/now_playing_page.dart', // the player
      'lib/pages/song_score_page.dart', // the sheet music
      'lib/pages/song_video_page.dart', // the music video
    ]) {
      expect(File(path).readAsStringSync(), contains('SongShareButton('),
          reason: '$path shows a single song and cannot share it');
    }
  });

  test('there is exactly one share button, not four that can drift', () {
    // The inline IconButton in songs_page is what made the player's
    // absence possible: a share that is a widget gets added to a new
    // screen in one line, while a share that is nine inline lines gets
    // forgotten. If a second definition appears, this says so.
    final defs = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('class SongShareButton'))
        .map((f) => f.path)
        .toList();
    expect(defs, ['lib/widgets/song_actions.dart']);
  });
}
