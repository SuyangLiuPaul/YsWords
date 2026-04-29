// Web TTS via the browser's SpeechSynthesis API. The conditional
// import below falls through to the stub on non-web targets so the
// rest of the app stays platform-agnostic.
//
// Why queue-based per-chunk instead of one big utterance? Chrome
// has a long-standing bug where `speechSynthesis.cancel()` is
// unreliable on long utterances (>~200 chars) — the audio keeps
// playing for several seconds after cancel returns. Per-verse
// utterances are short enough that cancel works deterministically,
// AND it gives us a natural per-verse `onAdvance` hook so the UI
// can highlight the verse currently being read aloud.

import 'tts_service_stub.dart'
    if (dart.library.js_interop) 'tts_service_web.dart' as impl;

class TtsService {
  /// Whether TTS is available on this platform/browser.
  static bool get isAvailable => impl.ttsIsAvailable();

  /// Speak a sequence of [chunks] (one per verse) in [locale]. Any
  /// in-flight queue is cancelled first. [onAdvance] is invoked with
  /// the 0-based index BEFORE each chunk starts speaking; [onDone] is
  /// invoked when the last chunk finishes naturally (NOT when stopped).
  static void speakSequence(
    List<String> chunks, {
    String locale = 'en-US',
    void Function(int index)? onAdvance,
    void Function()? onDone,
  }) {
    impl.ttsSpeakSequence(chunks, locale, onAdvance, onDone);
  }

  /// Cancel any in-flight queue. Safe to call when nothing is playing.
  static void stop() => impl.ttsStop();

  /// True when an utterance is currently being spoken OR queued. The
  /// floating-header menu polls this to flip its play/stop icon.
  static bool get speaking => impl.ttsSpeaking();
}
