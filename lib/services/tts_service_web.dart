// Web implementation of TTS using the browser's SpeechSynthesis API.
// Queue-based: each verse becomes its own short utterance. This
// works around Chrome's well-known bug where `cancel()` doesn't
// reliably stop long (>~200 char) utterances mid-stream — short
// per-verse utterances cancel deterministically, and the queue is
// invalidated by bumping a version counter so any in-flight `onend`
// handlers from a previous run become no-ops.

import 'dart:js_interop';

@JS('window.speechSynthesis')
external _SpeechSynthesis get _speechSynthesis;

@JS()
@staticInterop
class _SpeechSynthesis {}

extension on _SpeechSynthesis {
  external void cancel();
  external void pause();
  external void resume();
  external void speak(_Utterance utterance);
}

@JS('SpeechSynthesisUtterance')
@staticInterop
class _Utterance {
  external factory _Utterance(String text);
}

extension on _Utterance {
  external set lang(String value);
  external set rate(double value);
  external set pitch(double value);
  external set onend(JSFunction handler);
  external set onerror(JSFunction handler);
}

bool ttsIsAvailable() {
  try {
    // ignore: unnecessary_null_comparison
    return (_speechSynthesis as JSObject?) != null;
  } catch (_) {
    return false;
  }
}

// Version counter — incremented every time `ttsStop` is called or a
// new sequence begins. The pending utterance's `onend` closure
// captures the version it was scheduled under and bails if it no
// longer matches; that way a slow-to-fire `onend` from a cancelled
// queue can't accidentally restart the sequence.
int _version = 0;

// Whether a sequence is currently active. The browser's own
// `speaking` flag has a quirk: between cancel and the next speak,
// or while the queue is mid-advance, it can read false even though
// we logically still have a queue. Tracking it ourselves makes the
// UI flag reliable.
bool _active = false;

void ttsSpeakSequence(
  List<String> chunks,
  String locale,
  void Function(int)? onAdvance,
  void Function()? onDone,
) {
  if (!ttsIsAvailable()) return;
  // Cancel any in-flight queue and bump version.
  _speechSynthesis.cancel();
  final myVersion = ++_version;
  _active = true;

  void speakAt(int index) {
    if (myVersion != _version) return;
    if (index >= chunks.length) {
      _active = false;
      onDone?.call();
      return;
    }
    onAdvance?.call(index);
    final u = _Utterance(chunks[index]);
    u.lang = locale;
    u.rate = 0.95;
    u.pitch = 1.0;
    u.onend = (() {
      if (myVersion != _version) return;
      // Schedule the next utterance in a microtask so the browser
      // has a chance to drain the previous one cleanly.
      Future.microtask(() => speakAt(index + 1));
    }).toJS;
    u.onerror = (() {
      if (myVersion != _version) return;
      // Skip the failing chunk and keep going — usually a phoneme
      // the synthesizer can't render.
      Future.microtask(() => speakAt(index + 1));
    }).toJS;
    _speechSynthesis.speak(u);
  }

  // Some browsers (notably mobile Safari) need a short tick between
  // `cancel()` and `speak()` or the new utterance is silently
  // dropped. 50 ms is enough; imperceptible to the user.
  Future.delayed(const Duration(milliseconds: 50), () {
    if (myVersion != _version) return;
    speakAt(0);
  });
}

void ttsStop() {
  _version++;
  _active = false;
  if (!ttsIsAvailable()) return;
  try {
    // Belt-and-suspenders: pause first, then cancel. Pause halts
    // the audible output immediately on Chrome even when the
    // engine's internal queue still has items pending; cancel then
    // empties the queue. Without the pause, very long utterances
    // can keep playing for 1–2 s after cancel returns.
    _speechSynthesis.pause();
  } catch (_) {}
  try {
    _speechSynthesis.cancel();
  } catch (_) {}
  // Resume so a future `speak` after stop isn't blocked by a stuck
  // pause state. Calling resume on an empty queue is a no-op.
  try {
    _speechSynthesis.resume();
  } catch (_) {}
}

bool ttsSpeaking() {
  if (!ttsIsAvailable()) return false;
  // Trust the local flag — it's updated on speak/stop and on
  // sequence completion, whereas the browser's own `speaking`
  // flips between chunks.
  return _active;
}
