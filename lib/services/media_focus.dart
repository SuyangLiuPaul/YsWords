import 'package:flutter/foundation.dart';

/// One sound at a time.
///
/// 2026-08-11, asked for by the user: "如果视频在播应该歌曲会自动停，
/// vice versa是吧". They are right, and it was not true — the songs
/// player, the sermon player and the two video pages each owned their
/// own output and knew nothing about the others. Starting the 獨一真神
/// video while a hymn was playing gave you both at once, and on a phone
/// the lock screen showed whichever had registered last while the other
/// kept playing underneath it.
///
/// The rule is deliberately "pause", not "stop": someone who starts a
/// video half way through a hymn should find the hymn where they left
/// it, not back at zero.
///
/// Everything here is synchronous bookkeeping over async callbacks, so
/// a player whose `pause` throws (a disposed controller, a web element
/// that has gone away) cannot take down the player that is starting.
class MediaFocus {
  MediaFocus._();

  static final MediaFocus instance = MediaFocus._();

  final Map<Object, Future<void> Function()> _holders = {};

  /// Register [owner]'s pause callback.
  ///
  /// Keyed on the owner object, so registering twice is harmless and a
  /// page that rebuilds does not stack up callbacks.
  void register(Object owner, Future<void> Function() pause) {
    _holders[owner] = pause;
  }

  /// Drop [owner] — call from `dispose`, or the focus holds a callback
  /// into a disposed controller for the rest of the session.
  void unregister(Object owner) {
    _holders.remove(owner);
  }

  /// [owner] is about to make sound. Pause everyone else.
  ///
  /// Awaited by callers that can afford to, but never awaited *before*
  /// a `play()` that needs to stay inside a user gesture — see
  /// `song_playback_engine_web.dart` for why that matters on iOS.
  Future<void> claim(Object owner) async {
    for (final entry in _holders.entries) {
      if (identical(entry.key, owner)) continue;
      try {
        await entry.value();
      } catch (e) {
        // A dead holder must not block the one that is starting.
        debugPrint('[MediaFocus] ${entry.key.runtimeType} pause failed: $e');
      }
    }
  }

  @visibleForTesting
  int get holderCount => _holders.length;

  @visibleForTesting
  void clearForTest() => _holders.clear();
}
