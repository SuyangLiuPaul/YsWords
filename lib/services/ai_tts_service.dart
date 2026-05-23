// 2026-05-23 (v1.2.86): high-quality AI TTS via the /api/aiSpeak
// Netlify function (Google Cloud TTS Neural2 / Wavenet voices).
// Replaces the robotic browser `SpeechSynthesis` API for users
// who want a real voice — and brings TTS to native iOS / Android /
// macOS where SpeechSynthesis doesn't exist at all.
//
// The function returns base64-encoded MP3 bytes. AudioPlayer plays
// them via a BytesSource on all platforms (incl. web — audioplayers
// has a working web implementation that pipes the bytes into an
// HTMLAudioElement under the hood).
//
// Chunking: Google Cloud TTS limits a single request to 5000 chars.
// Bible chapters fit; long sermons don't. `synthesizeLong` splits on
// sentence boundaries into ~4500-char chunks, fetches them in
// parallel, then plays them sequentially.

import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

import 'package:yswords/services/api_base.dart';

class AiTtsService {
  AiTtsService._();

  static const String _defaultEndpoint = '/api/aiSpeak';
  static const String endpoint = String.fromEnvironment(
    'AI_SPEAK_URL',
    defaultValue: _defaultEndpoint,
  );

  // Single global player — only one TTS plays at a time. Reused so
  // we don't churn through audio sessions on every play.
  static final AudioPlayer _player = AudioPlayer();
  static bool _stopped = false;
  static String? _currentToken;

  /// Synthesize [text] and return the raw MP3 bytes. Caller decides
  /// when/how to play; useful for caching or pre-buffering.
  static Future<TtsResult> synthesize({
    required String text,
    required String locale,
    String gender = 'female',
    String tier = 'neural',
    double speakingRate = 1.0,
    String? userApiKey,
  }) async {
    if (text.trim().isEmpty) {
      return TtsResult.unavailable('Empty text.');
    }
    if (text.length > 5000) {
      return TtsResult.unavailable(
        'Text exceeds 5000 chars. Use synthesizeLong to auto-chunk.',
      );
    }
    final body = <String, dynamic>{
      'text': text,
      'locale': locale,
      'gender': gender,
      'tier': tier,
      'speakingRate': speakingRate,
      if (userApiKey != null && userApiKey.isNotEmpty)
        'userApiKey': userApiKey,
    };
    try {
      final resp = await http
          .post(
            Uri.parse(resolveApiUrl(endpoint)),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 35));
      if (resp.statusCode == 503) {
        return TtsResult.unavailable(
          'AI TTS is not configured yet on the server.',
        );
      }
      if (resp.statusCode != 200) {
        try {
          final j = jsonDecode(resp.body) as Map<String, dynamic>;
          final err = (j['error'] as String?)?.trim();
          if (err != null && err.isNotEmpty) return TtsResult.unavailable(err);
        } catch (_) {}
        return TtsResult.unavailable(
          'TTS server returned HTTP ${resp.statusCode}.',
        );
      }
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final b64 = (j['audio'] as String?) ?? '';
      if (b64.isEmpty) return TtsResult.unavailable('Empty audio response.');
      return TtsResult.ok(base64Decode(b64));
    } on TimeoutException {
      return TtsResult.unavailable('TTS took too long.');
    } catch (e) {
      return TtsResult.unavailable('TTS request failed: $e');
    }
  }

  /// Play [text] aloud. Auto-chunks if [text] exceeds the 5000-char
  /// limit. Stops any in-flight playback first.
  ///
  /// Returns when playback completes naturally OR when [stop] is called.
  static Future<void> speak({
    required String text,
    required String locale,
    String gender = 'female',
    String tier = 'neural',
    double speakingRate = 1.0,
    String? userApiKey,
    void Function(int chunkIndex, int chunkCount)? onChunkStart,
    void Function(String error)? onError,
  }) async {
    await stop();
    final token = DateTime.now().microsecondsSinceEpoch.toString();
    _currentToken = token;
    _stopped = false;

    final chunks = _chunkText(text, 4500);
    for (var i = 0; i < chunks.length; i++) {
      if (_stopped || _currentToken != token) return;
      onChunkStart?.call(i, chunks.length);
      final result = await synthesize(
        text: chunks[i],
        locale: locale,
        gender: gender,
        tier: tier,
        speakingRate: speakingRate,
        userApiKey: userApiKey,
      );
      if (_stopped || _currentToken != token) return;
      if (result.unavailable) {
        onError?.call(result.unavailableReason ?? 'TTS unavailable');
        return;
      }
      try {
        await _player.play(BytesSource(result.bytes!, mimeType: 'audio/mpeg'));
        // Wait for completion before next chunk.
        await _player.onPlayerComplete.first;
      } catch (e) {
        onError?.call('Audio playback failed: $e');
        return;
      }
    }
  }

  /// Speak a SEQUENCE of pre-chunked strings (e.g. one per verse in a
  /// Bible chapter). Each chunk is synthesized + played in turn, and
  /// [onAdvance] fires with the 0-based index BEFORE each chunk plays
  /// so the UI can highlight the verse currently being read. Mirrors
  /// the legacy `TtsService.speakSequence` shape so the bible_reading_pane
  /// can swap implementations with minimal churn.
  static Future<void> speakSequence(
    List<String> chunks, {
    required String locale,
    String gender = 'female',
    String tier = 'neural',
    double speakingRate = 1.0,
    String? userApiKey,
    void Function(int index)? onAdvance,
    void Function()? onDone,
    void Function(String error)? onError,
  }) async {
    await stop();
    final token = DateTime.now().microsecondsSinceEpoch.toString();
    _currentToken = token;
    _stopped = false;
    for (var i = 0; i < chunks.length; i++) {
      if (_stopped || _currentToken != token) return;
      final chunk = chunks[i].trim();
      if (chunk.isEmpty) continue;
      onAdvance?.call(i);
      final result = await synthesize(
        text: chunk,
        locale: locale,
        gender: gender,
        tier: tier,
        speakingRate: speakingRate,
        userApiKey: userApiKey,
      );
      if (_stopped || _currentToken != token) return;
      if (result.unavailable) {
        onError?.call(result.unavailableReason ?? 'TTS unavailable');
        return;
      }
      try {
        await _player.play(BytesSource(result.bytes!, mimeType: 'audio/mpeg'));
        await _player.onPlayerComplete.first;
      } catch (e) {
        onError?.call('Audio playback failed: $e');
        return;
      }
    }
    if (_currentToken == token && !_stopped) onDone?.call();
  }

  /// Stop any in-flight playback. Safe to call when nothing is playing.
  static Future<void> stop() async {
    _stopped = true;
    _currentToken = null;
    try { await _player.stop(); } catch (_) {}
  }

  /// True when audio is currently playing.
  static bool get speaking => _player.state == PlayerState.playing;

  /// Split [text] into chunks of at most [maxChars], preferring
  /// sentence boundaries (period / question mark / exclamation
  /// followed by whitespace; Chinese full-width period 。). When
  /// a single sentence exceeds the limit, falls back to comma /
  /// space boundaries.
  static List<String> _chunkText(String text, int maxChars) {
    if (text.length <= maxChars) return [text];
    final sentences = _splitSentences(text);
    final chunks = <String>[];
    final buffer = StringBuffer();
    for (final s in sentences) {
      if (buffer.length + s.length + 1 > maxChars) {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString().trim());
          buffer.clear();
        }
        // If the sentence itself is too long, hard-break it.
        if (s.length > maxChars) {
          for (var i = 0; i < s.length; i += maxChars) {
            chunks.add(s.substring(i, (i + maxChars).clamp(0, s.length)));
          }
          continue;
        }
      }
      buffer.write(s);
      buffer.write(' ');
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString().trim());
    return chunks;
  }

  static List<String> _splitSentences(String text) {
    // English: . ! ? followed by whitespace.
    // Chinese: 。 ! ? ;
    // Keeps the terminator with the preceding sentence.
    final out = <String>[];
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      buffer.write(c);
      final isTerminator = c == '.' || c == '!' || c == '?' ||
          c == '。' || c == '!' || c == '?' || c == ';' || c == ';';
      if (isTerminator) {
        // Look ahead for whitespace or end of string.
        if (i + 1 >= text.length || _isWhitespace(text[i + 1])) {
          out.add(buffer.toString());
          buffer.clear();
        }
      }
    }
    if (buffer.isNotEmpty) out.add(buffer.toString());
    return out;
  }

  static bool _isWhitespace(String c) =>
      c == ' ' || c == '\n' || c == '\r' || c == '\t' || c == '　';
}

class TtsResult {
  final Uint8List? bytes;
  final String? unavailableReason;

  TtsResult._({this.bytes, this.unavailableReason});

  factory TtsResult.ok(Uint8List bytes) => TtsResult._(bytes: bytes);
  factory TtsResult.unavailable(String reason) =>
      TtsResult._(unavailableReason: reason);

  bool get unavailable => unavailableReason != null;
}
