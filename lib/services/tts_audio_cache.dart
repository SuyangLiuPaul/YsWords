// 2026-05-23 (v1.2.87): on-disk cache for AI TTS MP3 bytes.
//
// Why: each /api/aiSpeak call costs money + adds a 1-3 s round-trip
// before audio starts. Caching the result locally means a second
// playback of the same verse (or chapter, or sermon paragraph) is
// instant AND free.
//
// Cache key: SHA-1 of `<text>|<locale>|<gender>|<tier>`. Anything
// that changes the synthesized audio (different translation, voice
// switch, locale change) gets a different key automatically.
//
// Eviction: LRU by mtime. Capped at 500 MB. Each access touches the
// file's mtime so frequently-played verses stay forever and rarely-
// played ones drop out.
//
// On web: path_provider returns IndexedDB-backed paths; this still
// works but is subject to browser quota. Mobile/desktop use real
// filesystem.

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class TtsAudioCache {
  TtsAudioCache._();

  /// Soft cap. When the cache directory exceeds this size we drop the
  /// oldest files until we're back under. 500 MB ≈ 1000 chapters at
  /// the typical Neural2 MP3 size (~500 KB/chapter).
  static const int _maxBytes = 500 * 1024 * 1024;

  /// In-memory shortcut so two simultaneous plays of the same text
  /// don't both decode the file off disk.
  static final Map<String, Uint8List> _memCache = {};
  static const int _memCacheMax = 32;

  /// Build the cache key from the synthesis parameters.
  static String _key({
    required String text,
    required String locale,
    required String gender,
    required String tier,
  }) {
    final payload = '$text|$locale|$gender|$tier';
    return sha1.convert(utf8Bytes(payload)).toString();
  }

  /// utf8.encode without importing dart:convert (kept the import set
  /// lean). Equivalent to `utf8.encode(s)`.
  static List<int> utf8Bytes(String s) {
    final out = <int>[];
    for (final code in s.runes) {
      if (code < 0x80) {
        out.add(code);
      } else if (code < 0x800) {
        out.add(0xC0 | (code >> 6));
        out.add(0x80 | (code & 0x3F));
      } else if (code < 0x10000) {
        out.add(0xE0 | (code >> 12));
        out.add(0x80 | ((code >> 6) & 0x3F));
        out.add(0x80 | (code & 0x3F));
      } else {
        out.add(0xF0 | (code >> 18));
        out.add(0x80 | ((code >> 12) & 0x3F));
        out.add(0x80 | ((code >> 6) & 0x3F));
        out.add(0x80 | (code & 0x3F));
      }
    }
    return out;
  }

  /// Returns the cached audio for these synthesis params, or null
  /// when not cached.
  static Future<Uint8List?> get({
    required String text,
    required String locale,
    required String gender,
    required String tier,
  }) async {
    final key = _key(text: text, locale: locale, gender: gender, tier: tier);
    if (_memCache.containsKey(key)) return _memCache[key];
    final dir = await _cacheDir();
    if (dir == null) return null;
    final f = File('${dir.path}/$key.mp3');
    if (!await f.exists()) return null;
    try {
      final bytes = await f.readAsBytes();
      _memCachePut(key, bytes);
      // Touch mtime for LRU.
      if (!kIsWeb) {
        try {
          await f.setLastModified(DateTime.now());
        } catch (_) {/* not critical */}
      }
      return bytes;
    } catch (e) {
      return null;
    }
  }

  /// Write the audio to cache. Best-effort — silently ignores I/O
  /// errors (we shouldn't break playback because the cache is full).
  static Future<void> put({
    required String text,
    required String locale,
    required String gender,
    required String tier,
    required Uint8List bytes,
  }) async {
    final key = _key(text: text, locale: locale, gender: gender, tier: tier);
    _memCachePut(key, bytes);
    final dir = await _cacheDir();
    if (dir == null) return;
    final f = File('${dir.path}/$key.mp3');
    try {
      await f.writeAsBytes(bytes, flush: true);
    } catch (_) {/* ignore */}
    // Lazy eviction — only check size occasionally so writes stay
    // fast. 1-in-32 chance per put.
    if (DateTime.now().microsecondsSinceEpoch % 32 == 0) {
      unawaited(_evictIfNeeded());
    }
  }

  static void _memCachePut(String key, Uint8List bytes) {
    if (_memCache.length >= _memCacheMax) {
      // Drop the first inserted (LinkedHashMap default order).
      _memCache.remove(_memCache.keys.first);
    }
    _memCache[key] = bytes;
  }

  static Future<Directory?> _cacheDir() async {
    try {
      final base = await getApplicationCacheDirectory();
      final dir = Directory('${base.path}/tts_audio');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (_) {
      // path_provider can fail on some web configurations; fall
      // through to mem-cache only.
      return null;
    }
  }

  static Future<void> _evictIfNeeded() async {
    final dir = await _cacheDir();
    if (dir == null) return;
    try {
      final entries = await dir.list().toList();
      var total = 0;
      final files = <_CacheEntry>[];
      for (final e in entries) {
        if (e is File) {
          final stat = await e.stat();
          total += stat.size;
          files.add(_CacheEntry(e, stat.modified, stat.size));
        }
      }
      if (total <= _maxBytes) return;
      files.sort((a, b) => a.mtime.compareTo(b.mtime));
      var i = 0;
      while (total > _maxBytes && i < files.length) {
        try {
          await files[i].file.delete();
          total -= files[i].size;
        } catch (_) {/* ignore */}
        i++;
      }
    } catch (_) {/* ignore */}
  }

  /// Total bytes currently held on disk. Used by the Settings UI to
  /// show the cache footprint.
  static Future<int> diskBytes() async {
    final dir = await _cacheDir();
    if (dir == null) return 0;
    var total = 0;
    try {
      await for (final e in dir.list()) {
        if (e is File) total += (await e.stat()).size;
      }
    } catch (_) {}
    return total;
  }

  /// Nuke every cached audio file. Settings → 'Clear audio cache'.
  static Future<void> clearAll() async {
    _memCache.clear();
    final dir = await _cacheDir();
    if (dir == null) return;
    try {
      await for (final e in dir.list()) {
        if (e is File) {
          try { await e.delete(); } catch (_) {}
        }
      }
    } catch (_) {}
  }
}

class _CacheEntry {
  final File file;
  final DateTime mtime;
  final int size;
  _CacheEntry(this.file, this.mtime, this.size);
}
