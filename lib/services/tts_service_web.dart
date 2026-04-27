// Web implementation of TTS using the browser's SpeechSynthesis API.
// See `tts_service.dart` for the public surface; this file is only
// loaded on the web target via conditional import.

import 'dart:js_interop';

@JS('window.speechSynthesis')
external _SpeechSynthesis get _speechSynthesis;

@JS()
@staticInterop
class _SpeechSynthesis {}

extension on _SpeechSynthesis {
  external void cancel();
  external void speak(_SpeechSynthesisUtterance utterance);
  external bool get speaking;
}

@JS('SpeechSynthesisUtterance')
@staticInterop
class _SpeechSynthesisUtterance {
  external factory _SpeechSynthesisUtterance(String text);
}

extension on _SpeechSynthesisUtterance {
  external set lang(String value);
  external set rate(double value);
  external set pitch(double value);
}

bool ttsIsAvailable() {
  // Some browsers (older Safari mobile) leave window.speechSynthesis
  // undefined. The js_interop call returns null in that case; we
  // catch it and report unavailable so the UI hides the affordance.
  try {
    return (_speechSynthesis as JSObject?) != null;
  } catch (_) {
    return false;
  }
}

void ttsSpeak(String text, String locale) {
  if (!ttsIsAvailable()) return;
  // Cancel any in-flight utterance — chained speaks otherwise queue
  // and the user has to wait through stale text.
  _speechSynthesis.cancel();
  final utterance = _SpeechSynthesisUtterance(text);
  utterance.lang = locale;
  // 0.95 is slower than browser default 1.0 — Bible reading
  // benefits from a touch more deliberation.
  utterance.rate = 0.95;
  utterance.pitch = 1.0;
  _speechSynthesis.speak(utterance);
}

void ttsStop() {
  if (!ttsIsAvailable()) return;
  _speechSynthesis.cancel();
}

bool ttsSpeaking() {
  if (!ttsIsAvailable()) return false;
  try {
    return _speechSynthesis.speaking;
  } catch (_) {
    return false;
  }
}
