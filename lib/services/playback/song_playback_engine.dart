/// The audio engine behind the Songs player.
///
/// Two implementations, chosen at compile time:
///
///   • `song_playback_engine_native.dart` — audioplayers. Covers iOS,
///     Android, macOS, Windows and Linux, and pairs with audio_service
///     for the lock screen and CarPlay.
///   • `song_playback_engine_web.dart` — a plain `HTMLAudioElement`.
///
/// **Why web does not use audioplayers.** `audioplayers_web` routes
/// every player through the Web Audio API: `recreateNode()` calls
/// `createMediaElementSource(element)` and wires it through gain and
/// panner nodes to the AudioContext destination. Once that happens the
/// element's audio no longer reaches the speakers directly — it is
/// audible only while the AudioContext is running. iOS permits
/// `AudioContext.resume()` only inside a user gesture, and by the time
/// the package reaches that call the activation has been spent on
/// intervening awaits.
///
/// The result, reported three times from a real iPhone: `play()`
/// resolves, `currentTime` advances, the media session shows
/// "playing", and there is no sound. Removing our own awaits was not
/// enough because `AudioPlayer.play()` still awaits `setSource()`
/// before reaching the element, and that is inside the package.
///
/// A bare `<audio>` element has no AudioContext in the path and
/// nothing to suspend. It also needs no `crossOrigin`, because web
/// playback already goes through the same-origin `/song-media/*`
/// proxy — which in turn means the CORS workaround that forced
/// `crossOrigin` in the first place is not needed here either.
library;

/// Re-exported unconditionally so callers can catch it without knowing
/// which engine they hold. Only the web one throws it.
export 'playback_blocked.dart';

export 'song_playback_engine_web.dart'
    if (dart.library.io) 'song_playback_engine_native.dart';
