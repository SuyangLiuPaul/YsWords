// Web TTS via the browser's SpeechSynthesis API. The conditional
// import below falls through to the stub on non-web targets so the
// rest of the app stays platform-agnostic.
//
// Why not flutter_tts? It pulls in mobile-platform plugins we don't
// use (iOS/Android/macOS), and Flutter web's WASM build chokes on
// some of its plugin manifests. Web Speech is a 30-line wrapper.

import 'tts_service_stub.dart'
    if (dart.library.js_interop) 'tts_service_web.dart' as impl;

/// Minimal text-to-speech wrapper. On web uses
/// `window.speechSynthesis`; on other platforms is a no-op that
/// reports unsupported. UI checks [isAvailable] before showing the
/// "Read aloud" affordance so unsupported platforms hide it
/// entirely.
class TtsService {
  /// Whether TTS is available on this platform.
  static bool get isAvailable => impl.ttsIsAvailable();

  /// Speak [text] in [locale] (e.g. 'en-US', 'zh-CN'). Cancels any
  /// ongoing utterance first. Locale-mismatched text is rendered with
  /// the browser's default voice — the synthesizer typically still
  /// produces intelligible output, just with the wrong accent.
  static void speak(String text, {String locale = 'en-US'}) {
    impl.ttsSpeak(text, locale);
  }

  static void stop() => impl.ttsStop();

  /// True when an utterance is currently being spoken. Polled by the
  /// UI after `speak`/`stop` to update the play/stop icon.
  static bool get speaking => impl.ttsSpeaking();
}
