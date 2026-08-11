import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/media_focus.dart';

/// One sound at a time.
///
/// 2026-08-11: "如果视频在播应该歌曲会自动停，vice versa是吧". Before
/// [MediaFocus] the songs player, the sermon player and the two video
/// pages each owned their own output and knew nothing about each other,
/// so a video started over a hymn played on top of it.
void main() {
  setUp(MediaFocus.instance.clearForTest);

  test('claiming pauses every other holder', () async {
    final paused = <String>[];
    final song = Object();
    final video = Object();
    MediaFocus.instance.register(song, () async => paused.add('song'));
    MediaFocus.instance.register(video, () async => paused.add('video'));

    await MediaFocus.instance.claim(video);

    expect(paused, ['song']);
  });

  test('the claimant is never asked to pause itself', () async {
    // The obvious bug in a "pause everything" implementation: the
    // player that is starting pauses itself a beat after it began, and
    // the tap does nothing.
    var pausedSelf = false;
    final song = Object();
    MediaFocus.instance.register(song, () async => pausedSelf = true);

    await MediaFocus.instance.claim(song);

    expect(pausedSelf, isFalse);
  });

  test('a holder that throws does not block the others', () async {
    // A disposed video controller throws on pause. If that propagated,
    // the song that triggered it would never start — a dead player
    // would silence the app.
    final paused = <String>[];
    MediaFocus.instance.register(Object(), () async => throw StateError('x'));
    MediaFocus.instance.register(Object(), () async => paused.add('ok'));

    await MediaFocus.instance.claim(Object());

    expect(paused, ['ok']);
  });

  test('registering the same owner twice replaces, never stacks', () async {
    // A page that rebuilds re-registers. Stacking would pause the same
    // controller once per rebuild.
    var calls = 0;
    final owner = Object();
    MediaFocus.instance.register(owner, () async => calls++);
    MediaFocus.instance.register(owner, () async => calls++);

    expect(MediaFocus.instance.holderCount, 1);
    await MediaFocus.instance.claim(Object());
    expect(calls, 1);
  });

  test('unregistering stops a disposed page being called again', () async {
    var called = false;
    final page = Object();
    MediaFocus.instance.register(page, () async => called = true);
    MediaFocus.instance.unregister(page);

    await MediaFocus.instance.claim(Object());

    expect(called, isFalse);
    expect(MediaFocus.instance.holderCount, 0);
  });
}
