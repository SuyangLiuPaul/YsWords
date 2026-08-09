import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_queue.dart';
import 'package:yswords/services/song_audio_handler.dart';

/// What the OS is told it may do with our playback.
///
/// Reported from an iPhone: the lock screen showed ⏪ ⏩ and neither
/// worked. Both causes were in the state we publish, so they belong in
/// a test rather than in a device check someone has to remember.
///
///  * `seekForward` / `seekBackward` were advertised. audio_service
///    maps them to MPRemoteCommandCenter's skip-by-interval commands
///    and only attaches a handler when `fastForwardInterval` /
///    `rewindInterval` are non-zero — which this app never set. iOS
///    drew the buttons and had nothing to call.
///  * previous/next were gated on `hasPrevious` / `hasNext`, so the
///    first track of a queue never offered them — and on **web** that
///    is fatal rather than cosmetic: `audio_service_web` registers its
///    Media Session action handlers *from the controls list*, so a
///    control that never appears is a handler that never exists.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Song song(String id) => Song(
        id: id,
        title: id,
        language: 'zh',
        source: 'cgdc',
        sourceLabel: 'CGDC',
        url: 'https://example.test/$id',
        audioUrl: 'https://example.test/$id.mp3',
        audioTracks: [
          SongTrackInfo(url: 'https://example.test/$id.mp3', kind: 'vocal'),
        ],
        themes: const [],
      );

  Future<PlaybackState> stateFor(WidgetTester tester, int songCount) async {
    // No dispose teardown: audioplayers' dispose() awaits the same
    // start-up future that failed for want of a platform side, and
    // waiting on it wedges the whole test file. The handler owns
    // nothing but that dead engine here.
    final handler = SongAudioHandler();
    await handler.setQueue(
      SongQueue.fromSongs([for (var i = 0; i < songCount; i++) song('s$i')]),
      // autoPlay: false — this is about what we advertise, not about
      // decoding, and there is no audio plugin in a widget test.
      autoPlay: false,
    );
    // The absent audio plugin reports through FlutterError; the engine
    // already turns its own start-up failure into an onError event.
    tester.takeException();
    return handler.playbackState.value;
  }

  testWidgets('a multi-song queue offers skip on the FIRST track',
      (tester) async {
    final state = await stateFor(tester, 4);
    final actions = state.controls.map((c) => c.action).toSet();

    expect(actions, contains(MediaAction.skipToPrevious),
        reason: 'web registers previoustrack only if the control is '
            'published, and the queue starts at index 0');
    expect(actions, contains(MediaAction.skipToNext));
  });

  testWidgets('never advertises skip-by-interval, which has no handler',
      (tester) async {
    final state = await stateFor(tester, 4);
    expect(state.systemActions, isNot(contains(MediaAction.seekForward)));
    expect(state.systemActions, isNot(contains(MediaAction.seekBackward)));
    expect(state.systemActions, contains(MediaAction.seek),
        reason: 'the scrubber does work and should stay');
  });

  testWidgets('a single-song queue offers no skip controls', (tester) async {
    final state = await stateFor(tester, 1);
    final actions = state.controls.map((c) => c.action).toSet();
    expect(actions, isNot(contains(MediaAction.skipToNext)),
        reason: 'there is genuinely nowhere to skip to');
    expect(actions, isNot(contains(MediaAction.skipToPrevious)));
  });
}
