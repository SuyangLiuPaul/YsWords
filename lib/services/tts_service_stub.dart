// Stub implementation for non-web platforms. Mirrors the web
// implementation's signatures so the conditional import in
// `tts_service.dart` is type-correct.

bool ttsIsAvailable() => false;
void ttsSpeak(String text, String locale) {}
void ttsStop() {}
bool ttsSpeaking() => false;
