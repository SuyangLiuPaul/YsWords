import 'dart:math';

import 'package:yswords/models/song.dart';

/// Which rendering of each song a queue should play.
///
/// The catalogue publishes 208 instrumental and 108 accompaniment
/// tracks alongside the sung takes, which makes "play this playlist,
/// but instrumental" a real feature rather than a novelty — it is how
/// you get quiet music for driving or prayer out of the same library.
enum TrackPreference { vocal, instrumental, accompaniment }

/// What to do when a song has no track of the preferred kind.
enum TrackFallback {
  /// Play the sung take instead. Keeps the queue full; you may be
  /// surprised by vocals in the middle of quiet music.
  useVocal,

  /// Leave the song out entirely. This is what makes an
  /// instrumental-only playlist trustworthy in a car.
  skip,
}

enum RepeatMode { off, all, one }

/// One resolved entry: a song plus the exact URL to play for it.
class QueueItem {
  final Song song;
  final String url;

  /// Which kind this URL turned out to be — may differ from the
  /// queue's preference when [TrackFallback.useVocal] applied.
  final String kind;

  const QueueItem({
    required this.song,
    required this.url,
    required this.kind,
  });

  bool get isFallback => kind == 'vocal';
}

/// An ordered, resolved playback queue.
///
/// Immutable value type: shuffling or changing repeat produces a new
/// queue rather than mutating this one, so the player can swap it in a
/// single assignment and every listener sees a consistent snapshot.
class SongQueue {
  /// Playback order. With shuffle on this is the shuffled order, so
  /// "previous" walks back the way you actually came.
  final List<QueueItem> items;

  final int index;
  final bool shuffled;
  final RepeatMode repeat;

  /// Where the queue came from, for the now-playing header
  /// ("2024 Bravery 刚强奋勇" / "收藏" / "全部诗歌").
  final String? sourceLabel;

  const SongQueue({
    required this.items,
    this.index = 0,
    this.shuffled = false,
    this.repeat = RepeatMode.off,
    this.sourceLabel,
  });

  static const empty = SongQueue(items: []);

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get length => items.length;

  QueueItem? get current =>
      (index >= 0 && index < items.length) ? items[index] : null;

  bool get hasNext => repeat != RepeatMode.off || index < items.length - 1;
  bool get hasPrevious => repeat != RepeatMode.off || index > 0;

  /// Resolve [songs] against a track preference into a playable queue.
  ///
  /// Songs with no usable track are dropped: a queue entry that cannot
  /// play is worse than a shorter queue, because it turns into a gap
  /// or an error the driver has to deal with.
  static SongQueue fromSongs(
    Iterable<Song> songs, {
    TrackPreference preference = TrackPreference.vocal,
    TrackFallback fallback = TrackFallback.useVocal,
    String? sourceLabel,
    int startIndex = 0,
    String? startSongId,
    bool shuffled = false,
    RepeatMode repeat = RepeatMode.off,
    Random? random,
  }) {
    final items = <QueueItem>[];
    for (final s in songs) {
      final resolved = resolveTrack(s, preference, fallback);
      if (resolved != null) items.add(resolved);
    }
    // Prefer the song id over a positional index.
    //
    // [startIndex] counts into the RESULT, which has had every song
    // with no playable track dropped — so a caller passing "row 12 of
    // what the user is looking at" lands on the wrong song as soon as
    // anything above it was unplayable, and an instrumental-only
    // playlist can drop most of the list. An id cannot drift.
    var index = startIndex;
    if (startSongId != null) {
      final found = items.indexWhere((i) => i.song.id == startSongId);
      if (found >= 0) index = found;
    }
    var queue = SongQueue(
      items: items,
      index: index.clamp(0, items.isEmpty ? 0 : items.length - 1),
      repeat: repeat,
      sourceLabel: sourceLabel,
    );
    if (shuffled) queue = queue.withShuffle(true, random: random);
    return queue;
  }

  /// Pick the URL for [song] under a preference, or null when it has
  /// nothing playable.
  static QueueItem? resolveTrack(
    Song song,
    TrackPreference preference,
    TrackFallback fallback,
  ) {
    final wanted = switch (preference) {
      TrackPreference.vocal => 'vocal',
      TrackPreference.instrumental => 'instrumental',
      TrackPreference.accompaniment => 'accompaniment',
    };

    // Prefer the richer track list; fall back to the scalar fields for
    // rows synced before audioTracks existed.
    final tracks = song.audioTracks.isNotEmpty
        ? song.audioTracks
        : [
            if (song.audioUrl != null)
              SongTrackInfo(url: song.audioUrl!, kind: 'vocal'),
            if (song.instrumentalUrl != null)
              SongTrackInfo(url: song.instrumentalUrl!, kind: 'instrumental'),
            if (song.accompanimentUrl != null)
              SongTrackInfo(
                  url: song.accompanimentUrl!, kind: 'accompaniment'),
          ];
    if (tracks.isEmpty) return null;

    for (final t in tracks) {
      if (t.kind == wanted) {
        // Among several vocal takes, prefer the song's own language.
        if (wanted == 'vocal') {
          final own = tracks.firstWhere(
            (x) => x.kind == 'vocal' && x.lang == song.language,
            orElse: () => t,
          );
          return QueueItem(song: song, url: own.url, kind: own.kind);
        }
        return QueueItem(song: song, url: t.url, kind: t.kind);
      }
    }

    if (fallback == TrackFallback.skip) return null;

    final vocal = tracks.where((t) => t.kind == 'vocal');
    final chosen = vocal.isNotEmpty ? vocal.first : tracks.first;
    return QueueItem(song: song, url: chosen.url, kind: chosen.kind);
  }

  /// Whether any song in this queue publishes [preference]'s mix.
  ///
  /// Only 108 of the 609 songs in the catalogue have an accompaniment
  /// and 208 an instrumental, and both live on two of the four sources
  /// — so a queue filtered to CGDC or Cahaya has neither. Offering the
  /// chip anyway makes it a control that does nothing when tapped.
  bool hasMix(TrackPreference preference) => items.any((i) =>
      resolveTrack(i.song, preference, TrackFallback.skip) != null);

  SongQueue copyWith({
    List<QueueItem>? items,
    int? index,
    bool? shuffled,
    RepeatMode? repeat,
    String? sourceLabel,
  }) =>
      SongQueue(
        items: items ?? this.items,
        index: index ?? this.index,
        shuffled: shuffled ?? this.shuffled,
        repeat: repeat ?? this.repeat,
        sourceLabel: sourceLabel ?? this.sourceLabel,
      );

  /// The same songs, re-resolved to a different mix.
  ///
  /// Pure on purpose. The handler used to build this inline, which put
  /// the only test of "switching to accompaniment keeps you on the same
  /// song and never reverts to singing" behind an audio plugin — and in
  /// a test environment that plugin's start-up future never settles, so
  /// the test wedged rather than failed. The rule being enforced is
  /// about the queue, not about decoding, so it lives here.
  ///
  /// Keeps the playing song selected, keeps the running order (this
  /// must never reshuffle as a side effect), and returns an EMPTY queue
  /// when nothing survives [fallback] — the caller decides whether that
  /// means "leave it alone and say so" or something else.
  ///
  /// When the song being listened to has no track of the wanted mix,
  /// [TrackFallback.skip] drops it, and the listener has to land
  /// somewhere. That somewhere is the next surviving song **forward**
  /// from where they were, which is what skipping means. It used to be
  /// track one: the index was left to default, so asking for
  /// accompaniment on song 300 of the catalogue restarted the queue at
  /// the beginning.
  SongQueue withPreference(
    TrackPreference preference,
    TrackFallback fallback,
  ) {
    if (items.isEmpty) return this;
    final rebuilt = SongQueue.fromSongs(
      items.map((i) => i.song),
      preference: preference,
      fallback: fallback,
      shuffled: false,
      repeat: repeat,
      sourceLabel: sourceLabel,
    );
    if (rebuilt.isEmpty) return rebuilt;
    // Counted by position rather than looked up by id: the current song
    // may not be in the rebuilt queue at all, and counting works the
    // same whether it survived or not — the survivors before it are
    // exactly the ones that come before its replacement.
    final survivorsBefore = items
        .take(index)
        .where((i) => resolveTrack(i.song, preference, fallback) != null)
        .length;
    return rebuilt.copyWith(
      index: survivorsBefore.clamp(0, rebuilt.length - 1),
      shuffled: shuffled,
    );
  }

  /// Put [item] into the queue at [at], keeping the current track
  /// selected.
  ///
  /// Inserting at or before the playing position pushes it down by one,
  /// so the listener stays on the same song — which is the whole point
  /// of "play next": it must not interrupt what is playing.
  SongQueue insertAt(int at, QueueItem item) {
    final target = at.clamp(0, items.length);
    final next = [...items]..insert(target, item);
    return copyWith(
      items: next,
      index: target <= index ? index + 1 : index,
    );
  }

  /// Turn shuffle on or off, keeping the currently-playing item
  /// selected.
  ///
  /// Shuffling REORDERS the list once and keeps that order, rather than
  /// picking a random track on every advance. That is what makes
  /// "previous" meaningful — with per-advance randomness, going back
  /// lands somewhere you have never been, which reads as a bug.
  SongQueue withShuffle(bool on, {Random? random}) {
    if (items.isEmpty) return copyWith(shuffled: on);
    final playing = current;

    if (!on) {
      // Restore catalogue order. Sorting by the song id is stable and
      // needs no separate "original order" copy to fall out of sync.
      final restored = [...items]
        ..sort((a, b) => a.song.id.compareTo(b.song.id));
      final at = playing == null
          ? 0
          : restored.indexWhere((i) => i.song.id == playing.song.id);
      return copyWith(
          items: restored, index: at < 0 ? 0 : at, shuffled: false);
    }

    final rest = [...items];
    rest.shuffle(random ?? Random());
    // Put whatever is playing at the front so shuffling never cuts off
    // the current track.
    if (playing != null) {
      rest.removeWhere((i) => i.song.id == playing.song.id);
      rest.insert(0, playing);
    }
    return copyWith(items: rest, index: 0, shuffled: true);
  }

  /// Index of the next item, or null at the end with repeat off.
  int? nextIndex() {
    if (items.isEmpty) return null;
    if (repeat == RepeatMode.one) return index;
    if (index < items.length - 1) return index + 1;
    return repeat == RepeatMode.all ? 0 : null;
  }

  /// Index of the previous item, or null at the start with repeat off.
  int? previousIndex() {
    if (items.isEmpty) return null;
    if (repeat == RepeatMode.one) return index;
    if (index > 0) return index - 1;
    return repeat == RepeatMode.all ? items.length - 1 : null;
  }

  /// Drop the item at [at] — used when a URL turns out to be dead, so
  /// the queue does not keep offering something that cannot play.
  SongQueue removeAt(int at) {
    if (at < 0 || at >= items.length) return this;
    final rest = [...items]..removeAt(at);
    final newIndex = at < index ? index - 1 : index;
    return copyWith(
      items: rest,
      index: rest.isEmpty ? 0 : newIndex.clamp(0, rest.length - 1),
    );
  }
}
