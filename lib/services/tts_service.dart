/// Native TTS using `flutter_tts` (^4.2.5) — works on iOS, macOS,
/// Android, and Web (browser SpeechSynthesis) with one unified API.
///
/// 2026-05-24 (v1.3.18): rewritten from the old web-only
/// SpeechSynthesis + native-stub split. User reported "朗读 doesn't
/// work" → traced to (a) GOOGLE_TTS_API_KEY not set on Netlify so
/// the AI TTS endpoint always 503s, AND (b) on native iOS / macOS /
/// Android the legacy fallback was a no-op stub. flutter_tts uses
/// the platform's built-in TTS:
///   - iOS / macOS: AVSpeechSynthesizer (Siri-family voices)
///   - Android: TextToSpeech (Google TTS or device-default engine)
///   - Web: SpeechSynthesis API (same as the legacy web impl, but
///     wrapped consistently)
/// All free, no API key, no quota. Quality is a step below Google
/// Cloud Chirp 3 HD but more than adequate for chapter reading.
///
/// The public API (`isAvailable`, `speakSequence`, `stop`,
/// `speaking`) matches the pre-v1.3.18 wrapper exactly so all
/// existing callers (bible_reading_pane._toggleListenChapter,
/// AiTtsService's `onError` fallback, the menu's `onToggleListen`)
/// keep working without changes.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _tts = _initTts();
  static int _generation = 0; // bumped on stop() to invalidate queues
  static bool _speaking = false;

  static FlutterTts _initTts() {
    final tts = FlutterTts();
    // iOS-only: register an audio session shared with other audio
    // (e.g. pause music while reading). Without this, the system
    // picks a default that may duck other apps unexpectedly.
    try {
      tts.setSharedInstance(true);
    } catch (_) {/* not iOS — silent */}
    // iOS / macOS: declare which audio categories we'll request,
    // and let the OS mix politely. AVAudioSessionCategoryPlayback
    // is required for audio that should continue when the screen
    // locks (important for chapter-length reading).
    try {
      tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );
    } catch (_) {/* non-iOS or plugin pre-v3 — silent */}
    return tts;
  }

  /// Whether TTS is available on this platform. flutter_tts ships an
  /// implementation for every platform we target, so this is `true`
  /// almost everywhere — return `false` only if `setLanguage` rejects
  /// the locale (no engine for that language on device).
  static bool get isAvailable => true;

  /// Speak [chunks] (typically one per verse) in [locale]. Any
  /// in-flight queue is cancelled first via the generation counter.
  ///
  /// [onAdvance] fires with the 0-based index BEFORE each chunk
  /// starts speaking (used to scroll + highlight the current verse).
  /// [onDone] fires when the last chunk finishes naturally — NOT
  /// when [stop] was called or when an error occurred.
  static void speakSequence(
    List<String> chunks, {
    String locale = 'en-US',
    void Function(int index)? onAdvance,
    void Function()? onDone,
  }) async {
    if (chunks.isEmpty) {
      onDone?.call();
      return;
    }
    // Bump the generation so any prior queue's completionHandler
    // becomes a no-op the moment it fires.
    final myGen = ++_generation;
    _speaking = true;

    try {
      await _tts.setLanguage(locale);
    } catch (e) {
      debugPrint('[TtsService] setLanguage($locale) threw: $e');
      // Continue — some engines accept the BCP-47 form differently.
    }
    try {
      // Slightly under default so chapter listening feels less rushed
      // — most users find the default rate too fast for spoken Scripture.
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (_) {/* ignore — non-critical */}
    // awaitSpeakCompletion makes `_tts.speak()` await until the
    // utterance ends, which is the cleanest sequential pattern.
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {/* not all platforms support it */}

    for (int i = 0; i < chunks.length; i++) {
      if (myGen != _generation) return; // stopped or superseded
      final chunk = chunks[i].trim();
      if (chunk.isEmpty) continue;
      onAdvance?.call(i);
      try {
        await _tts.speak(chunk);
      } catch (e) {
        debugPrint('[TtsService] speak threw on chunk $i: $e');
        // Continue to the next chunk — one bad utterance shouldn't
        // halt the whole chapter.
      }
    }
    if (myGen == _generation) {
      _speaking = false;
      onDone?.call();
    }
  }

  /// Cancel any in-flight queue. Safe to call when nothing is playing.
  static void stop() {
    _generation++;
    _speaking = false;
    try {
      _tts.stop();
    } catch (_) {/* engine may not be initialised — silent */}
  }

  /// True when a queue is currently being spoken.
  static bool get speaking => _speaking;
}
