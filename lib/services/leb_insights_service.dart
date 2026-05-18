import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:yswords/constants/book_names.dart';

/// 2026-05-18 (v1.2.53): cross-version translator-insights overlay.
///
/// LEB ships with 23,632 inline `<note: …>` annotations — the
/// richest translator-note set of any version we bundle (every
/// other version has either zero or a few hundred). Loading these
/// once into a singleton lets every other version's reader pane
/// surface them as a small `(i)` chip next to verses that have an
/// LEB note, with a tap-to-view popup.
///
/// Design points:
///   • Singleton — initialised once via [init], parses LEB JSON and
///     pre-builds a `bookEnglish|chapter|verse` → `List<String>` map.
///     ~30 k verses parsed in ~50 ms on web.
///   • Memory cost is small (only the notes are retained, the
///     verse text itself is GC'd).
///   • Lookups translate the caller's book name through
///     `bookNameToEnglish` first, so reading 创世记 / 創世記 / Genesis
///     all hit the same key.
///   • Two LEB-asset quirks are aliased inside the service:
///     'Mic' ↔ 'Micah', 'Nah' ↔ 'Nahum' — LEB ships with the
///     truncated names. Judges + Obadiah are missing from the
///     LEB asset altogether; lookups for those return empty
///     (callers just don't render the chip).
///   • Returns the **raw** annotation text — caller can choose to
///     prefix with a "From LEB:" label, render Markdown, etc.
class LebInsightsService {
  LebInsightsService._();
  static final LebInsightsService instance = LebInsightsService._();

  final RegExp _noteRegex = RegExp(r'<note:\s*([^>]+)>');

  /// `bookEnglish|chapter|verse` → list of note texts (in order of
  /// appearance within the verse).
  final Map<String, List<String>> _notes = {};

  /// LEB asset uses 'Mic' / 'Nah' for Micah / Nahum. Translate
  /// canonical English (what `bookNameToEnglish` produces) → the
  /// LEB-asset key so lookups still hit. Reverse-aliased on load
  /// so the in-memory map IS keyed by 'Micah' / 'Nahum' and no
  /// per-call mapping is needed.
  static const Map<String, String> _lebBookAlias = {
    'Mic': 'Micah',
    'Nah': 'Nahum',
  };

  bool _initialized = false;
  Future<void>? _initFuture;

  /// Idempotent. Safe to call from anywhere — the second + call
  /// returns the same Future, so concurrent boot paths don't
  /// double-parse.
  Future<void> init() {
    if (_initialized) return Future.value();
    return _initFuture ??= _doInit();
  }

  Future<void> _doInit() async {
    try {
      final raw = await rootBundle.loadString('assets/leb.json');
      final list = jsonDecode(raw);
      if (list is! List) {
        debugPrint('[LebInsights] LEB asset is not a list — bailing');
        _initialized = true;
        return;
      }
      var noteCount = 0;
      for (final entry in list) {
        if (entry is! Map) continue;
        final book = entry['book']?.toString();
        final chapterRaw = entry['chapter'];
        final verseRaw = entry['verse'];
        final text = entry['text']?.toString() ?? '';
        if (book == null || chapterRaw == null || verseRaw == null) continue;

        final chapter = int.tryParse(chapterRaw.toString()) ?? 0;
        final verse = int.tryParse(verseRaw.toString()) ?? 0;
        if (chapter == 0 || verse == 0) continue;

        final notes = _extractNotes(text);
        if (notes.isEmpty) continue;

        // Normalise LEB's truncated book names to canonical
        // English so the in-memory map matches `bookNameToEnglish`
        // output. 'Mic' → 'Micah', 'Nah' → 'Nahum'.
        final canonical = _lebBookAlias[book] ?? book;
        final key = '$canonical|$chapter|$verse';
        (_notes[key] ??= []).addAll(notes);
        noteCount += notes.length;
      }
      _initialized = true;
      debugPrint('[LebInsights] loaded ${_notes.length} annotated verses, '
          '$noteCount total notes');
    } catch (e, st) {
      debugPrint('[LebInsights] init failed: $e\n$st');
      _initialized = true; // don't keep retrying on a broken asset
    }
  }

  List<String> _extractNotes(String text) {
    final out = <String>[];
    for (final m in _noteRegex.allMatches(text)) {
      final body = m.group(1)?.trim();
      if (body != null && body.isNotEmpty) {
        out.add(body);
      }
    }
    return out;
  }

  /// Returns the LEB notes for [book] / [chapter] / [verse]. [book]
  /// may be in any of the locales the app supports — Genesis /
  /// 创世记 / 創世記 all resolve to the same canonical key.
  ///
  /// Returns an empty list when:
  ///   • the service isn't initialised yet (caller should treat
  ///     "no notes" the same way as "not loaded yet" — both render
  ///     the verse without the chip)
  ///   • LEB doesn't have notes for that verse (the common case —
  ///     ~22 / 100 verses have no note)
  ///   • LEB is missing the book (Judges + Obadiah)
  List<String> notesFor(String book, int chapter, int verse) {
    if (!_initialized) return const [];
    final english = bookNameToEnglish[book] ?? book;
    final key = '$english|$chapter|$verse';
    return _notes[key] ?? const [];
  }

  /// True once [init] has finished. Useful for widgets that want
  /// to display "loading…" before the service is ready, though
  /// in practice it's parsed during splash and ready well before
  /// the first chapter renders.
  bool get isReady => _initialized;

  /// Total verses with at least one note. Exposed for diagnostics
  /// (About → diagnostic table) and the unit test.
  int get annotatedVerseCount => _notes.length;
}
