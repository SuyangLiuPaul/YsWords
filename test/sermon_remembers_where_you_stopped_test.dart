/// 2026-09-18 「並且上次聽到哪裡都記錄下來嗎」— the second half of the same
/// request `sermon_is_one_talk_test.dart` answered the first half of.
///
/// The position was persisted ONLY on an explicit pause/stop/seek/
/// seekOverall. A listener who never pauses — closes the tab, swipes
/// the app away, or lets a talk roll from one part into the next and
/// then quits — either resumes at 0:00 (never paused, so
/// `sermon.audio.pos.<id>` was never written) or at a stale place (the
/// last explicit pause, possibly a whole part earlier). `_advancePart`
/// has the same shape of bug at every part boundary: it bumps
/// `_partIndex` and calls `_playPart()` without saving, so a save from
/// BEFORE the boundary keeps naming the part that already finished.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/services/media_focus.dart';
import 'package:yswords/services/sermon_audio_service.dart';

import 'support/fake_song_playback_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // See `sermon_audio_breadcrumb_test.dart`'s identical setUp note:
    // the constructor registers with the shared MediaFocus.instance, so
    // a leftover registration from a previous test's service would
    // stick around otherwise.
    MediaFocus.instance.clearForTest();
  });

  const partA = SermonAudioPart(part: 'a', file: 'a.mp3', bytes: 1);
  const partB = SermonAudioPart(part: 'b', file: 'b.mp3', bytes: 1);

  group('shouldAutosave, the pure throttle decision', () {
    const interval = Duration(seconds: 5);

    test('the first tick of a part always saves — there is nothing yet '
        'to throttle against', () {
      expect(SermonAudioService.shouldAutosave(null, Duration.zero, interval),
          isTrue);
    });

    test('a tick short of the interval does not save again', () {
      expect(
          SermonAudioService.shouldAutosave(
              const Duration(seconds: 10), const Duration(seconds: 14), interval),
          isFalse);
    });

    test('a tick that reaches the interval saves', () {
      expect(
          SermonAudioService.shouldAutosave(
              const Duration(seconds: 10), const Duration(seconds: 15), interval),
          isTrue);
    });

    test('a tick behind the last save (a rewind) saves — it must not be '
        'starved by an interval measured from a position now ahead of '
        'it', () {
      expect(
          SermonAudioService.shouldAutosave(
              const Duration(seconds: 20), const Duration(seconds: 3), interval),
          isTrue);
    });
  });

  group('the write-storm bound', () {
    test('60 one-second ticks over a 5s throttle write at most 13 times, '
        'not 60', () {
      const interval = Duration(seconds: 5);
      Duration? lastSaved;
      var writes = 0;
      for (var s = 1; s <= 60; s++) {
        final tick = Duration(seconds: s);
        if (SermonAudioService.shouldAutosave(lastSaved, tick, interval)) {
          lastSaved = tick;
          writes++;
        }
      }
      // Saves land at 1, 6, 11, … 56 — twelve of them. The bound
      // asserted is looser (≤13) so this does not re-encode the exact
      // schedule, only that a per-tick write storm (60 writes) cannot
      // happen.
      expect(writes, lessThanOrEqualTo(13));
      expect(writes, greaterThan(1),
          reason: 'the throttle must not suppress every write either — '
              'that would silently reintroduce the original bug');
    });
  });

  group('autosave without any pause/stop/seek', () {
    test('the persisted position advances on its own — killing the app '
        'mid-sermon with no pause loses at most one throttle window, not '
        'the whole talk', () async {
      final engine = FakeSongPlaybackEngine();
      final svc = SermonAudioService.withEngine(engine);
      svc.seedForTest('421', const [partA]);

      await svc.play('421');
      engine.emitDuration(const Duration(minutes: 10));
      await Future<void>.delayed(Duration.zero);
      svc.applyPendingSeek();
      engine.emitPlaying(true);
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sermon.audio.pos.421'), isNull,
          reason: 'nothing has played yet');

      engine.emitPosition(const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('sermon.audio.pos.421'), '0:5');

      engine.emitPosition(const Duration(seconds: 11));
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('sermon.audio.pos.421'), '0:11',
          reason: 'no pause, stop or seek happened anywhere in this test '
              '— the save must have come from the position stream alone');
    });

    test('ticks inside the same 5s window do not each write', () async {
      final engine = FakeSongPlaybackEngine();
      final svc = SermonAudioService.withEngine(engine);
      svc.seedForTest('421', const [partA]);

      await svc.play('421');
      engine.emitDuration(const Duration(minutes: 10));
      await Future<void>.delayed(Duration.zero);
      svc.applyPendingSeek();
      engine.emitPlaying(true);
      await Future<void>.delayed(Duration.zero);

      engine.emitPosition(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sermon.audio.pos.421'), '0:2');

      engine.emitPosition(const Duration(seconds: 4));
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('sermon.audio.pos.421'), '0:2',
          reason: 'still inside the 5s window since the last save — this '
              'tick must not have been written');
    });
  });

  group('a load/resume window must not clobber a good saved position', () {
    test('position ticks while _loading is still true are ignored', () async {
      final engine = FakeSongPlaybackEngine();
      final svc = SermonAudioService.withEngine(engine);
      svc.seedForTest('421', const [partA]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sermon.audio.pos.421', '0:45');

      // play() sets _loading = true and does not clear it until the
      // fake reports onPlaying(true) — which this test deliberately
      // never sends yet.
      await svc.play('421');
      expect(svc.isLoading, isTrue);

      engine.emitPosition(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getString('sermon.audio.pos.421'), '0:45',
          reason: 'a stray position event during the load must not '
              'overwrite the good position that _savedPosition already '
              'read at the top of play()');
    });

    test('position ticks while a resume seek is still pending are '
        'ignored, even after _loading has cleared', () async {
      final engine = FakeSongPlaybackEngine();
      final svc = SermonAudioService.withEngine(engine);
      svc.seedForTest('421', const [partA]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sermon.audio.pos.421', '0:45');

      await svc.play('421');
      // _loading clears, but the resume-to-45s seek has not been
      // applied yet — duration is still zero, so `applyPendingSeek`
      // (called by the real UI on every rebuild) would still no-op.
      engine.emitPlaying(true);
      await Future<void>.delayed(Duration.zero);
      expect(svc.isLoading, isFalse);

      engine.emitPosition(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('sermon.audio.pos.421'), '0:45',
          reason: 'the resume seek to 45s has not landed yet — a save '
              'here would persist "0:0" over the position this whole '
              'play() call exists to restore');

      // Now let the seek actually land, the way the real UI would.
      engine.emitDuration(const Duration(minutes: 10));
      await Future<void>.delayed(Duration.zero);
      svc.applyPendingSeek();
      await Future<void>.delayed(Duration.zero);

      engine.emitPosition(const Duration(seconds: 46));
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('sermon.audio.pos.421'), '0:46',
          reason: 'once the pending seek is cleared, autosave must '
              'resume normally');
    });

    test('on an engine whose seek is an async round-trip (native, not '
        'web), a position tick that lands WHILE the seek is still in '
        'flight is ignored too', () async {
      final engine = FakeSongPlaybackEngine();
      final svc = SermonAudioService.withEngine(engine);
      svc.seedForTest('421', const [partA]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sermon.audio.pos.421', '0:45');

      await svc.play('421');
      engine.emitDuration(const Duration(minutes: 10));
      await Future<void>.delayed(Duration.zero);
      engine.emitPlaying(true);
      await Future<void>.delayed(Duration.zero);

      // `applyPendingSeek` nulls `_pendingSeek` synchronously and only
      // THEN awaits `_player.seek(...)` — on the web engine that seek
      // is a synchronous `currentTime =` assignment, so there is no
      // real gap; `holdSeek` models the native engine's plugin
      // round-trip, which does have one.
      engine.holdSeek = true;
      svc.applyPendingSeek();
      await Future<void>.delayed(Duration.zero);

      // The platform has not actually applied the seek yet — this is
      // the stale near-zero tick a real native player can report in
      // that window.
      engine.emitPosition(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('sermon.audio.pos.421'), '0:45',
          reason: '_pendingSeek is already null here, so without a '
              'separate in-flight flag this stale tick would have '
              'overwritten the 45s the whole resume was protecting');

      engine.resolveHeldSeek();
      await Future<void>.delayed(Duration.zero);

      engine.emitPosition(const Duration(seconds: 46));
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('sermon.audio.pos.421'), '0:46',
          reason: 'once the seek itself has actually landed, autosave '
              'must resume normally');
    });

    test('an orphaned seek resolving after a NEWER seek has started must '
        'not clear _seekInFlight out from under the newer one', () async {
      // A refuter caught this: `_seekInFlight` was one shared bool with
      // no per-seek identity. Part a's resume seek is still an
      // outstanding round-trip when the listener jumps to part b —
      // part b's own `_playPart` resets the flag and starts its own
      // seek, so when part a's orphaned seek finally resolves, it must
      // not be the one that clears it.
      //
      // partB is given real bytes (unlike partA/partB elsewhere in this
      // file) so `lengthOf` estimates it at 10 minutes even before it
      // has ever played — `seekOverall` needs that estimate to land the
      // jump 5s into part b rather than clamped to its end.
      const bigPartB =
          SermonAudioPart(part: 'b', file: 'big-b.mp3', bytes: 2400000);
      final engine = FakeSongPlaybackEngine();
      final svc = SermonAudioService.withEngine(engine);
      svc.seedForTest('421', const [partA, bigPartB]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sermon.audio.pos.421', '0:45');

      await svc.play('421');
      engine.emitDuration(const Duration(minutes: 10)); // learns part a's length
      await Future<void>.delayed(Duration.zero);
      engine.emitPlaying(true);
      await Future<void>.delayed(Duration.zero);

      engine.holdSeek = true;
      svc.applyPendingSeek(); // part a's resume seek — held, index 0
      await Future<void>.delayed(Duration.zero);

      // Jump to 10:05 overall — locate() puts that 5s into part b,
      // given part a's learned 10-minute length above.
      await svc.seekOverall(const Duration(minutes: 10, seconds: 5));
      // seekOverall's own explicit save fires unconditionally right
      // after _playPart, independent of any seek landing — that is
      // `_advancePart`'s same "name the new part immediately" pattern,
      // not the bug under test here.
      expect(prefs.getString('sermon.audio.pos.421'), '1:0');

      engine.emitDuration(const Duration(minutes: 10)); // part b's own duration
      await Future<void>.delayed(Duration.zero);
      // Clears `_loading` for part b, so what follows isolates
      // `_seekInFlight` rather than being masked by the loading gate.
      engine.emitPlaying(true);
      await Future<void>.delayed(Duration.zero);
      svc.applyPendingSeek(); // part b's own seek to 5s — held, index 1
      await Future<void>.delayed(Duration.zero);

      // Part a's orphaned seek lands now, after part b's has started.
      engine.resolveHeldSeek(index: 0);
      await Future<void>.delayed(Duration.zero);

      // Part b's own seek has not actually landed yet — a stale tick
      // here must still be suppressed. Without the generation check,
      // part a's completion above would have wrongly cleared the flag
      // and let this write "1:200" over the "1:0" seekOverall already
      // saved.
      engine.emitPosition(const Duration(seconds: 200));
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('sermon.audio.pos.421'), '1:0',
          reason: 'part b\'s real seek has not landed — this tick must '
              'not have been autosaved');

      engine.resolveHeldSeek(index: 1);
      await Future<void>.delayed(Duration.zero);

      engine.emitPosition(const Duration(minutes: 2));
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('sermon.audio.pos.421'), '1:120',
          reason: 'once part b\'s own seek has actually landed, autosave '
              'must resume normally');
    });
  });

  group('_advancePart names the new part immediately', () {
    test('crossing a tape-side boundary persists the NEW part index, not '
        'the finished one', () async {
      final engine = FakeSongPlaybackEngine();
      final svc = SermonAudioService.withEngine(engine);
      svc.seedForTest('421', const [partA, partB]);

      await svc.play('421');
      engine.emitDuration(const Duration(minutes: 10));
      await Future<void>.delayed(Duration.zero);
      svc.applyPendingSeek();
      engine.emitPlaying(true);
      await Future<void>.delayed(Duration.zero);

      engine.emitPosition(const Duration(minutes: 9, seconds: 55));
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sermon.audio.pos.421'), '0:595');

      // Part a ends; the player rolls straight into part b.
      engine.emitComplete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getString('sermon.audio.pos.421'), '1:0',
          reason: 'the saved value must name part 1 (the new part, '
              '0-based) at position 0 — not part 0 at 595s, which does '
              'not exist inside part b and would seek nowhere sane on '
              'the next resume');
      expect(svc.partNumber, 2);
    });

    test('finishing the LAST part clears the saved position rather than '
        'naming a part past the end', () async {
      final engine = FakeSongPlaybackEngine();
      final svc = SermonAudioService.withEngine(engine);
      svc.seedForTest('421', const [partA]);

      await svc.play('421');
      engine.emitDuration(const Duration(minutes: 10));
      await Future<void>.delayed(Duration.zero);
      svc.applyPendingSeek();
      engine.emitPlaying(true);
      await Future<void>.delayed(Duration.zero);

      engine.emitPosition(const Duration(minutes: 9, seconds: 55));
      await Future<void>.delayed(Duration.zero);

      engine.emitComplete();
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sermon.audio.pos.421'), isNull,
          reason: 'single-part sermon finishing must still clear, the '
              'behaviour this fix was told to leave exactly as is');
    });
  });
}
