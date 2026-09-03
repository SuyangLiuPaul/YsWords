import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/sermon_audio_service.dart';
import 'package:yswords/widgets/sermon_audio_bar.dart';

/// The bar is docked on the sermon page, so it is built for *every*
/// sermon — including any that has no audio. Rendering nothing in that
/// case is the whole contract: a docked disabled transport would eat
/// screen height on a reading page and promise something it cannot do.
void main() {
  Future<void> pump(WidgetTester tester, String sermonId) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettings>(
        create: (_) => AppSettings(),
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: SermonAudioBar(sermonId: sermonId),
            body: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a sermon with no audio renders nothing', (tester) async {
    await pump(tester, 'no-such-sermon-id');
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    // Not merely invisible — it must take no space on the page.
    final size = tester.getSize(find.byType(SermonAudioBar));
    expect(size.height, 0);
  });

  testWidgets('the bar does not throw before the index loads',
      (tester) async {
    // load() is async and the first frame happens before it resolves;
    // hasAudio must tolerate a null index rather than blowing up the
    // whole sermon page on the way in.
    await pump(tester, '002');
    expect(tester.takeException(), isNull);
  });

  // 2026-09-04 (from a crash report — iPhone, /sermons/421,
  // `PlaybackBlockedException(AbortError: The operation was aborted.)`):
  // `SermonAudioService._playPart` and the resume branch of `play()`
  // used to let a `PlaybackBlockedException` from the browser refusing
  // to start playback propagate uncaught — `_loading` stuck true
  // forever with the Listen button disabled, and the exception reached
  // the app's Zone-level crash reporter as an unhandled error instead
  // of a reader-visible message. `song_audio_handler.dart` already
  // catches the identical exception for songs; these two tests pin the
  // sermon path's now-matching behaviour: the 'blocked' error string
  // gets the "tap again" copy, not the generic failure message, and
  // the button re-enables so the tap the message asks for can land.
  //
  // The real throw site is web-only (`song_playback_engine_web.dart`;
  // `flutter test`'s VM runtime resolves the native engine instead,
  // which never throws this exception — see `song_playback_engine_
  // native.dart`), so `setBlockedForTest` drives the state a caught
  // exception would have produced, rather than a real play() call.
  group('the blocked-playback state (2026-09-04, /sermons/421)', () {
    testWidgets('shows the shared "tap again" copy, not the generic '
        'failure message', (tester) async {
      SermonAudioService.instance.setBlockedForTest('421');
      await pump(tester, '421');

      // Locale-agnostic on purpose: `AppSettings()` defaults to
      // zh-Hans here (its own default, not English), so this checks
      // "one of the localized songsPlaybackBlocked strings is on
      // screen and none of sermonAudioError's are" rather than
      // assuming which language rendered.
      final blockedShown = uiStrings['songsPlaybackBlocked']!
          .values
          .where((s) => find.text(s).evaluate().isNotEmpty);
      expect(blockedShown, hasLength(1),
          reason: 'exactly one localized "tap play again" string should '
              'be on screen');
      for (final generic in uiStrings['sermonAudioError']!.values) {
        expect(find.text(generic), findsNothing,
            reason: '"blocked" must not fall through to the generic '
                'failure message — the track is fine, the browser just '
                'needs another tap');
      }
    });

    testWidgets('re-enables the Listen button so the tap can land',
        (tester) async {
      SermonAudioService.instance.setBlockedForTest('421');
      await pump(tester, '421');

      final button =
          tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.play_circle_fill_rounded));
      expect(button.onPressed, isNotNull,
          reason: '_loading must be false again, or a blocked play can '
              'never be retried — the whole point of the "tap play '
              'again" message');
    });
  });

  test('the service reports every sermon as playable', () async {
    // Guards the wiring end-to-end: the index parses, the base URL is
    // set, and hasAudio is true — the three things that have to hold
    // for a play button to appear at all.
    await SermonAudioService.instance.load();
    expect(SermonAudioService.instance.playableSermonCount, 289);
    expect(SermonAudioService.instance.hasAudio('002'), isTrue);
    expect(SermonAudioService.instance.hasAudio('nope'), isFalse);
  }, skip: 'needs rootBundle; covered by sermon_audio_index_test.dart');
}
