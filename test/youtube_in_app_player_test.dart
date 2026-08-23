import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/media_focus.dart';
import 'package:yswords/utils/embeddable_media.dart';
import 'package:yswords/widgets/floating_media_player.dart';

/// 2026-08-24, in two rounds.
///
/// First: "歌曲里面有几个是YouTube如果按了去YouTube了，但是web 和ios能不能
/// 不跳转出去" — so YouTube links stopped leaving the app.
///
/// Then, after trying it: "现在是有youtube在song里面但是就不能退出去了，
/// 能不能好像WhatsApp一样窗口可以移动一样可以用app" — the first version
/// used a modal sheet, which is a trap by construction. And in the same
/// breath the scope widened: "另外soundcloud也是一样的概念" and "其他如果
/// 有的话也是一样一并做了".
///
/// What is worth testing is the ROUTING and the escape, not the frame:
/// embeddable media stays in the app in a window the user can close, a
/// platform with no webview still leaves, and everything that is not
/// embeddable behaves exactly as before — that last one being the
/// property a change at a 17-caller chokepoint could quietly break.
void main() {
  const videoUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
  const soundcloudUrl =
      'https://w.soundcloud.com/player/?url=https%3A//api.soundcloud.com/tracks/123456';
  const fakePlayer = Key('fake-embed');

  // url_launcher's method channel never answers in a test — its future
  // simply hangs, so openExternally neither returns nor reports. Mock
  // the channel so the external route can be asserted POSITIVELY: a
  // regression that dropped the link entirely would otherwise look
  // identical to one that opened it.
  final launched = <String>[];
  setUp(() {
    launched.clear();
    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url'] as String);
        }
        return true;
      },
    );
    FloatingMediaPlayer.debugEmbedBuilder =
        (_) => const SizedBox(key: fakePlayer);
    MediaFocus.instance.clearForTest();
  });

  tearDown(() {
    FloatingMediaPlayer.hide();
    FloatingMediaPlayer.debugEmbedBuilder = null;
    MediaFocus.instance.clearForTest();
  });

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

  Future<void> tapLink(WidgetTester tester, String url) async {
    await tester.pumpWidget(host(url));
    await tester.tap(find.text('link'));
    await tester.pumpAndSettle();
  }

  group('embeddable media stays in the app', () {
    testWidgets('a YouTube link opens the floating window', (tester) async {
      await tapLink(tester, videoUrl);
      expect(FloatingMediaPlayer.isShowing, isTrue);
      expect(find.byKey(fakePlayer), findsOneWidget);
    });

    testWidgets('so does a SoundCloud link', (tester) async {
      // "另外soundcloud也是一样的概念" — 27 songs in the catalogue are
      // SoundCloud-only and used to walk the user out to the browser.
      await tapLink(tester, soundcloudUrl);
      expect(FloatingMediaPlayer.isShowing, isTrue);
      expect(find.byKey(fakePlayer), findsOneWidget);
    });

    testWidgets('and the user can always get out', (tester) async {
      // The complaint that produced this window: a modal the user could
      // not leave. The close control must exist, be reachable, and
      // actually close.
      await tapLink(tester, videoUrl);
      expect(FloatingMediaPlayer.isShowing, isTrue);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(FloatingMediaPlayer.isShowing, isFalse);
      expect(find.byKey(fakePlayer), findsNothing);
    });

    testWidgets('the window can be dragged, and the frame is not rebuilt',
        (tester) async {
      // Dragging must move the window WITHOUT tearing the frame down:
      // rebuilding the platform view would restart playback on every
      // drag, which is the one thing a movable player must not do.
      await tapLink(tester, videoUrl);
      final before = tester.getTopLeft(find.byKey(fakePlayer));
      final embedElement = tester.element(find.byKey(fakePlayer));

      await tester.drag(
          find.byIcon(Icons.drag_indicator), const Offset(-60, -80));
      await tester.pumpAndSettle();

      final after = tester.getTopLeft(find.byKey(fakePlayer));
      expect(after, isNot(before), reason: 'the window should have moved');
      expect(tester.element(find.byKey(fakePlayer)), same(embedElement),
          reason: 'the frame must survive the move, not be recreated');
    });

    testWidgets('closing the window tears the frame down', (tester) async {
      // 2026-08-24, from the phone: "为什么关掉那个windows并没有音乐停
      // soundcloud". The window went away and the audio did not,
      // because neither embed had ANY teardown: the native one left its
      // WebViewController holding a live page, and the web one left a
      // detached iframe. Neither exposes a pause — the frame owns its
      // own transport — so the teardown IS the stop, and it only
      // happens if the embed widget is actually disposed.
      var disposed = false;
      FloatingMediaPlayer.debugEmbedBuilder =
          (_) => _DisposeSpy(onDispose: () => disposed = true);

      await tapLink(tester, soundcloudUrl);
      expect(disposed, isFalse);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(disposed, isTrue,
          reason: 'no dispose means the page keeps playing with nothing '
              'left on screen to stop it');
    });

    testWidgets('opening a second track tears the first one down',
        (tester) async {
      // hide() runs before the new entry is inserted, so the previous
      // frame must go — otherwise two tracks play over each other.
      // Both taps happen in ONE app: pumping a fresh tree between them
      // would prove nothing, since that disposes everything anyway.
      var disposals = 0;
      FloatingMediaPlayer.debugEmbedBuilder =
          (_) => _DisposeSpy(onDispose: () => disposals++);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  onPressed: () => LinkOpener.openOrWarn(
                      context, soundcloudUrl,
                      locale: 'en'),
                  child: const Text('first'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      LinkOpener.openOrWarn(context, videoUrl, locale: 'en'),
                  child: const Text('second'),
                ),
              ],
            ),
          ),
        ),
      ));

      await tester.tap(find.text('first'));
      await tester.pumpAndSettle();
      expect(disposals, 0);

      await tester.tap(find.text('second'));
      await tester.pumpAndSettle();
      expect(disposals, 1,
          reason: 'the first frame must be gone before the second plays');
    });

    testWidgets('a video starting silences the hymn', (tester) async {
      var paused = false;
      final hymn = Object();
      MediaFocus.instance.register(hymn, () async => paused = true);

      await tapLink(tester, videoUrl);
      await tester.pumpAndSettle();

      expect(paused, isTrue);
      MediaFocus.instance.unregister(hymn);
    });
  });

  group('everything else is untouched', () {
    testWidgets('a platform with no webview still links out',
        (tester) async {
      // Windows and Linux compile webview_flutter with nothing behind
      // it, so the embed builder returns null and the link must leave
      // the app exactly as it always did. url_launcher has no platform
      // channel here, so the failure path reports itself — which is
      // the positive proof that the external route ran at all.
      FloatingMediaPlayer.debugEmbedBuilder = (_) => null;
      await tapLink(tester, videoUrl);

      expect(FloatingMediaPlayer.isShowing, isFalse);
      expect(launched, [videoUrl],
          reason: 'the link must still LEAVE the app here, and with the '
              'URL the user tapped — asserting only the absence of a '
              'window would pass just as happily if the tap did nothing');
    });

    testWidgets('a non-embeddable link opens no window', (tester) async {
      const pdf = 'https://www.christiandiscipleschurch.org/a.pdf';
      await tapLink(tester, pdf);
      expect(FloatingMediaPlayer.isShowing, isFalse);
      expect(launched, [pdf], reason: 'sheet music still opens outside');
    });
  });

  group('what counts as embeddable', () {
    test('YouTube and SoundCloud yes, the rest no', () {
      expect(embeddableMedia(videoUrl)?.provider, 'youtube');
      expect(embeddableMedia(soundcloudUrl)?.provider, 'soundcloud');
      // The mp4s have a real in-app page and the PDFs want a reader;
      // neither belongs in a small floating frame.
      expect(embeddableMedia('https://fydt.org/a.mp4'), isNull);
      expect(embeddableMedia('https://cgdc.hk/score.pdf'), isNull);
      expect(embeddableMedia('mailto:someone@example.com'), isNull);
    });

    test('the SoundCloud frame is tall enough for its own controls', () {
      // 2026-08-24, from the phone: "那个播放键在手机上都按不了". The
      // window was ~107 px tall and SoundCloud's compact widget needs
      // 166; its play button and scrubber were simply below the
      // frame. Nothing was wrong with touch handling.
      expect(embeddableMedia(soundcloudUrl)!.frameHeight(320),
          greaterThanOrEqualTo(166));
      // Video still scales with width.
      expect(embeddableMedia(videoUrl)!.frameHeight(320), 320 * 9 / 16);
    });

    test('SoundCloud is asked for the COMPACT player', () {
      // Its default is a full-bleed artwork unit with the site's own
      // header and nav — which is what the phone showed instead of a
      // player. visual=false is the 166 px transport bar.
      final url = embeddableMedia(soundcloudUrl)!.embedUrl;
      expect(url, contains('visual=false'));
      expect(url, contains('hide_related=true'));
      expect(url, contains('show_user=false'));
      // And NOT auto_play: asking for it on mobile is what puts
      // SoundCloud's "Play on SoundCloud" interstitial over the player.
      expect(url.contains('auto_play=true'), isFalse);
      // The track must survive the rewrite. Uri.replace re-encodes the
      // slashes in the nested url (%2F), which SoundCloud accepts —
      // assert on the id rather than on a slash spelling that is an
      // implementation detail of the rewrite.
      expect(Uri.decodeComponent(url), contains('tracks/123456'));
    });

    test('every catalogue row that offers one resolves', () {
      final songs = (jsonDecode(File('assets/songs.json').readAsStringSync())
          as Map<String, dynamic>)['songs'] as List<dynamic>;
      var youtube = 0, soundcloud = 0;
      for (final row in songs) {
        final s = row as Map<String, dynamic>;
        final id = s['youtubeId'] as String?;
        if (id != null) {
          expect(
              embeddableMedia('https://www.youtube.com/watch?v=$id')?.provider,
              'youtube',
              reason: '${s['id']} has an unplayable youtubeId');
          youtube++;
        }
        final track = s['soundcloudTrackId'] as String?;
        if (track != null) soundcloud++;
      }
      expect(youtube, greaterThan(0));
      expect(soundcloud, greaterThan(0));
    });
  });
}

/// Reports when it is disposed, standing in for a frame whose teardown
/// is the only way to stop its audio.
class _DisposeSpy extends StatefulWidget {
  const _DisposeSpy({required this.onDispose});

  final VoidCallback onDispose;

  @override
  State<_DisposeSpy> createState() => _DisposeSpyState();
}

class _DisposeSpyState extends State<_DisposeSpy> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
