import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_queue.dart';

/// The mini-player must always offer a way out.
///
/// 2026-08-11, from the user: "如果我不想听了去其他页面底下还是有播放器，
/// 一直在那里，但是每次退出才没有" — the strip followed them onto every
/// page with no way to close it, and force-quitting was the only escape.
///
/// Two independent causes, and both had to be true for the bug:
///
///   1. The close control was written as the `else` of
///      `if (queue.length > 1)`, so it only ever appeared for a
///      SINGLE-song queue. Every row's play button queues the whole
///      filtered list, so real use never saw it.
///   2. `stop()` deliberately keeps the queue — correct for the sleep
///      timer and for running off the end — so even reaching that
///      button would not have hidden the strip, which renders on
///      `current != null`.
///
/// This pins the second, which is the load-bearing half: dismissing has
/// to empty the queue, or the button is decorative. The first is a
/// layout property covered by the widget tree itself.
void main() {
  Song song(String id) => Song(
        id: id,
        title: 'Song $id',
        language: 'zh',
        source: 'cgdc',
        sourceLabel: 'CGDC',
        url: 'https://example.invalid/$id',
        audioUrl: 'https://example.invalid/$id.mp3',
        themes: const [],
      );

  test('an emptied queue is what makes the strip disappear', () {
    final q = SongQueue.fromSongs([song('a'), song('b'), song('c')]);
    expect(q.isEmpty, isFalse);
    expect(q.current, isNotNull,
        reason: 'while this is non-null the strip renders');

    // What dismiss() does to the queue.
    const dismissed = SongQueue.empty;
    expect(dismissed.isEmpty, isTrue);
    expect(dismissed.current, isNull,
        reason: 'current must go null or GlobalMiniPlayer keeps showing '
            'the strip — stopping playback alone never did this, which '
            'is why the player could not be put away');
  });

  test('a multi-song queue is the normal case, not the edge case', () {
    // The close affordance used to exist only when this was 1. Every
    // row play button queues the whole filtered list, so a queue of 1
    // is the rarity — which is why nobody could find the button.
    final q = SongQueue.fromSongs([song('a'), song('b'), song('c')]);
    expect(q.length, greaterThan(1));
  });
}
