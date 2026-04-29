// Stub implementation for non-web platforms. Mirrors the web
// implementation's signatures so the conditional import in
// `tts_service.dart` is type-correct.

bool ttsIsAvailable() => false;
void ttsSpeakSequence(
  List<String> chunks,
  String locale,
  void Function(int)? onAdvance,
  void Function()? onDone,
) {}
void ttsStop() {}
bool ttsSpeaking() => false;
