/// The platform refused to *start* playback, as opposed to failing to
/// play a particular file.
///
/// Only web raises this today. Browsers reject `HTMLMediaElement.play()`
/// with `NotAllowedError` when the call did not come from a user
/// gesture — which on iOS is also what happens if the gesture was spent
/// by an intervening `await`.
///
/// It has its own type because the two failures need opposite handling.
/// A dead URL should be dropped so the queue moves on; a refused start
/// means *nothing* will play until the user taps, so dropping and
/// advancing would blacklist the whole playlist one track at a time and
/// leave the listener with silence and an empty queue.
class PlaybackBlockedException implements Exception {
  final String detail;
  const PlaybackBlockedException(this.detail);

  @override
  String toString() => 'PlaybackBlockedException($detail)';
}
