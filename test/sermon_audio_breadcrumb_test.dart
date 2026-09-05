import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/services/error_reporter.dart';
import 'package:yswords/services/media_focus.dart';
import 'package:yswords/services/sermon_audio_service.dart';

import 'support/fake_song_playback_engine.dart';

/// `docs/autonomous-queue.md:11582`: the AbortError race is NOT settled
/// — two mechanisms are readable in the code and neither has been
/// reproduced. This file does not settle it either. It only builds the
/// instrument the item asks for: a breadcrumb trail that, if the race
/// recurs, tells the two mechanisms apart on sight — two `sermon.play`
/// crumbs close together is a double tap; a `sermon.seek` crumb before
/// the first `sermon.playing` crumb is the resume-seek race.
///
/// These tests pin that the trail records the right EVENTS IN THE
/// RIGHT ORDER for each mechanism's own shape — not that either
/// mechanism is what actually causes the crash on a real WebKit, which
/// nothing here can drive.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ErrorReporter.resetForTest();
    // Each test builds its own SermonAudioService via withEngine(), and
    // its constructor registers with the shared MediaFocus.instance —
    // without this, every prior test's instance stays a holder for the
    // rest of the suite.
    MediaFocus.instance.clearForTest();
  });

  const part = SermonAudioPart(part: 'a', file: 'test.mp3', bytes: 1);

  List<({DateTime timestamp, String action, String? data})> crumbs() =>
      ErrorReporter.breadcrumbsForTest;

  test(
      'a double tap on a not-yet-current sermon shows as two sermon.play '
      'crumbs, both on the "load" branch', () async {
    final engine = FakeSongPlaybackEngine();
    final svc = SermonAudioService.withEngine(engine);
    svc.seedForTest('421', const [part]);

    // Neither await is allowed to land before the second call starts —
    // that gap before `_loading` flips true is mechanism 1 itself.
    unawaited(svc.play('421'));
    unawaited(svc.play('421'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final playCrumbs =
        crumbs().where((b) => b.action == 'sermon.play').toList();
    expect(playCrumbs, hasLength(2),
        reason: 'both taps reached play() before either could have set '
            '_sermonId, so both must be crumbed — a trail that only '
            'showed one would hide the very race it exists to catch');
    for (final c in playCrumbs) {
      expect(c.data, 'id=421 branch=load loading=false',
          reason: 'both taps see the sermon as not-yet-current and '
              '_loading still false, which is what makes this a race '
              'rather than a harmless second tap on an already-loading '
              'sermon');
    }
  });

  test(
      'a second tap on an ALREADY-current sermon is crumbed as branch=toggle, '
      'not branch=load', () async {
    final engine = FakeSongPlaybackEngine();
    final svc = SermonAudioService.withEngine(engine);
    svc.seedForTest('421', const [part]);

    await svc.play('421');
    ErrorReporter.resetForTest();

    unawaited(svc.play('421'));
    await Future<void>.delayed(Duration.zero);

    final playCrumbs =
        crumbs().where((b) => b.action == 'sermon.play').toList();
    expect(playCrumbs, hasLength(1));
    expect(playCrumbs.single.data, contains('branch=toggle'),
        reason: 'the songs path structurally cannot race this way '
            '(queue item\'s own claim) because this branch pauses '
            'synchronously rather than starting a new load — the crumb '
            'must tell the two branches apart, not just log "play"');
  });

  test(
      'a resume seek that fires before the first playing event is '
      'ordered before it in the trail', () async {
    final engine = FakeSongPlaybackEngine();
    final svc = SermonAudioService.withEngine(engine);
    svc.seedForTest('421', const [part]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sermon.audio.pos.421', '0:30');

    await svc.play('421');
    engine.emitDuration(const Duration(seconds: 60));
    // Stream events are delivered on a later microtask, not
    // synchronously with add() — this tick is that delivery, not part
    // of the race being modelled.
    await Future<void>.delayed(Duration.zero);
    // The widget pokes this from a rebuild BEFORE the engine has ever
    // reported playing==true — exactly the WebKit-race shape the item
    // describes (`durationchange` arriving before the play() promise
    // settles).
    svc.applyPendingSeek();
    engine.emitPlaying(true);
    await Future<void>.delayed(Duration.zero);

    final actions = crumbs().map((b) => b.action).toList();
    final seekIdx = actions.indexOf('sermon.seek');
    final playingIdx = actions.indexOf('sermon.playing');
    expect(seekIdx, greaterThanOrEqualTo(0));
    expect(playingIdx, greaterThanOrEqualTo(0));
    expect(seekIdx, lessThan(playingIdx),
        reason: 'this is the exact order the item says would mean the '
            'seek race: applyPendingSeek firing before the first '
            'playing event');
  });

  test(
      'when playing arrives first, the trail orders sermon.playing before '
      'any later sermon.seek', () async {
    final engine = FakeSongPlaybackEngine();
    final svc = SermonAudioService.withEngine(engine);
    svc.seedForTest('421', const [part]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sermon.audio.pos.421', '0:30');

    await svc.play('421');
    engine.emitPlaying(true);
    await Future<void>.delayed(Duration.zero);
    engine.emitDuration(const Duration(seconds: 60));
    await Future<void>.delayed(Duration.zero);
    svc.applyPendingSeek();

    final actions = crumbs().map((b) => b.action).toList();
    final seekIdx = actions.indexOf('sermon.seek');
    final playingIdx = actions.indexOf('sermon.playing');
    expect(seekIdx, greaterThanOrEqualTo(0));
    expect(playingIdx, greaterThanOrEqualTo(0));
    expect(playingIdx, lessThan(seekIdx),
        reason: 'the trail has to be able to show the NON-race shape '
            'too, or an order assertion in the other test would be '
            'meaningless — this proves the ordering reflects the real '
            'call order rather than always coming out the same way');
  });

  test('sermon.playPart carries the part index and whether a resume was '
      'armed', () async {
    final engine = FakeSongPlaybackEngine();
    final svc = SermonAudioService.withEngine(engine);
    svc.seedForTest('421', const [part]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sermon.audio.pos.421', '0:45');

    await svc.play('421');

    final playPart = crumbs().singleWhere((b) => b.action == 'sermon.playPart');
    expect(playPart.data, 'part=0 resumeAt=0:00:45.000000',
        reason: 'the trail must say WHICH part and whether a resume '
            'offset was armed, or a recurrence on part 2 of a 3-part '
            'sermon would be indistinguishable from part 1');
  });

  test('a PlaybackBlockedException from _playPart is crumbed before the '
      'blocked state is set', () async {
    final engine = FakeSongPlaybackEngine()..throwBlockedOnPlay = true;
    final svc = SermonAudioService.withEngine(engine);
    svc.seedForTest('421', const [part]);

    await svc.play('421');

    expect(svc.error, 'blocked');
    final blocked =
        crumbs().where((b) => b.action == 'sermon.blocked').toList();
    expect(blocked, hasLength(1));
    expect(blocked.single.data, 'context=playPart part=0');
  });

  test('a PlaybackBlockedException from the resume branch is crumbed with '
      'context=resume', () async {
    final engine = FakeSongPlaybackEngine();
    final svc = SermonAudioService.withEngine(engine);
    svc.seedForTest('421', const [part]);

    await svc.play('421'); // loads 421; the fake never reports playing==true
    engine.throwBlockedOnResume = true;

    // _playing is still false, so this second tap takes the resume()
    // branch rather than pause().
    await svc.play('421');

    expect(svc.error, 'blocked');
    final blocked =
        crumbs().where((b) => b.action == 'sermon.blocked').toList();
    expect(blocked, hasLength(1));
    expect(blocked.single.data, 'context=resume id=421');
  });
}
