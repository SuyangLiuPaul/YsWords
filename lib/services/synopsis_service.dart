import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:yswords/utils/reference_parser.dart';

/// One harmony entry from `assets/gospel_synopsis.json`. Each entry
/// maps a single Gospel event to its parallel passage in each Gospel
/// that records it.
class SynopsisEvent {
  final String id;
  final Map<String, String> title; // locale -> localized title
  /// Gospel name ("matthew" / "mark" / "luke" / "john") -> raw
  /// reference string ("Matthew 5:1-12"). Reference parser handles
  /// resolution to canonical English book name when navigating.
  final Map<String, String> refs;

  const SynopsisEvent({
    required this.id,
    required this.title,
    required this.refs,
  });

  String localizedTitle(String locale) =>
      title[locale] ?? title['en'] ?? id;

  /// Returns the parsed [BibleReference] for [gospel] (case-insensitive
  /// "matthew"/"mark"/"luke"/"john"), or null if this event doesn't
  /// cover that Gospel.
  BibleReference? referenceFor(String gospel) {
    final raw = refs[gospel.toLowerCase()];
    if (raw == null) return null;
    // Parser may not handle the multi-segment "Luke 8:16, 11:33" form
    // — split on comma and take the first segment.
    final first = raw.split(',').first.trim();
    return parseReference(first);
  }

  /// Returns the raw reference string for display, e.g. "Mt 5:1-12".
  /// Caller is responsible for any localization of the book name.
  String? rawRef(String gospel) => refs[gospel.toLowerCase()];
}

/// Loads + indexes the bundled Gospel synopsis. Two query shapes are
/// supported:
///   - `byChapter(book, chapter)` — every event whose entry for that
///     Gospel falls inside the given chapter
///   - `byVerse(book, chapter, verse)` — events that include the
///     specific verse (verse range in the harmony entry includes it)
class SynopsisService {
  static List<SynopsisEvent>? _events;
  static Future<void>? _loading;

  /// Map of canonical English Gospel name → ordered list of entries
  /// touching that Gospel. Sorted by chapter+verse for deterministic
  /// rendering.
  static final Map<String, List<_IndexedEntry>> _byGospel = {
    'Matthew': [],
    'Mark': [],
    'Luke': [],
    'John': [],
  };

  static Future<void> _ensureLoaded() async {
    if (_events != null) return;
    _loading ??= _load();
    await _loading;
  }

  static Future<void> _load() async {
    final raw =
        await rootBundle.loadString('assets/gospel_synopsis.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = json['events'] as List;
    final events = <SynopsisEvent>[];
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final ev = SynopsisEvent(
        id: m['id'] as String,
        title: Map<String, String>.from(m['title'] as Map),
        refs: Map<String, String>.from(m['refs'] as Map),
      );
      events.add(ev);
    }
    _events = events;

    // Index. For each Gospel ref, parse it and stash the chapter +
    // verse range so chapter/verse queries are O(1) per event.
    for (final ev in events) {
      ev.refs.forEach((gospel, raw) {
        final canonicalGospel = _gospelKey(gospel);
        if (canonicalGospel == null) return;
        // Take only the first segment if comma-separated.
        final first = raw.split(',').first.trim();
        final parsed = parseReference(first);
        if (parsed == null) return;
        // Whole-chapter entries (no verse part) cover the entire
        // chapter; mark with verse range 1..big.
        final start = parsed.verseStart ?? 1;
        final end = parsed.verseEnd ?? (parsed.verseStart ?? 9999);
        _byGospel[canonicalGospel]!.add(_IndexedEntry(
          chapter: parsed.chapter,
          verseStart: start,
          verseEnd: end,
          event: ev,
        ));
      });
    }
    for (final list in _byGospel.values) {
      list.sort((a, b) {
        if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
        return a.verseStart.compareTo(b.verseStart);
      });
    }
  }

  static String? _gospelKey(String s) {
    final t = s.toLowerCase();
    switch (t) {
      case 'matthew':
      case 'mt':
        return 'Matthew';
      case 'mark':
      case 'mk':
        return 'Mark';
      case 'luke':
      case 'lk':
        return 'Luke';
      case 'john':
      case 'jn':
        return 'John';
    }
    return null;
  }

  /// All events touching [book] [chapter]. Returns empty list when
  /// [book] is not a Gospel or no harmony entries fall in that
  /// chapter.
  static Future<List<SynopsisEvent>> byChapter(
      String book, int chapter) async {
    await _ensureLoaded();
    final key = _gospelKey(book);
    if (key == null) return const [];
    final list = _byGospel[key] ?? const [];
    return list
        .where((e) => e.chapter == chapter)
        .map((e) => e.event)
        .toList();
  }

  /// Events whose entry for [book] covers [verse]. Empty list when
  /// not applicable.
  static Future<List<SynopsisEvent>> byVerse(
      String book, int chapter, int verse) async {
    await _ensureLoaded();
    final key = _gospelKey(book);
    if (key == null) return const [];
    final list = _byGospel[key] ?? const [];
    return list
        .where((e) =>
            e.chapter == chapter &&
            verse >= e.verseStart &&
            verse <= e.verseEnd)
        .map((e) => e.event)
        .toList();
  }

  /// Returns true if [book] is one of the four Gospels — used by the
  /// reading-pane menu to decide whether to show the "Synopsis"
  /// option.
  static bool isGospel(String englishBook) {
    return _gospelKey(englishBook) != null &&
        ['Matthew', 'Mark', 'Luke', 'John'].contains(englishBook);
  }

  /// Total entry count for callers that want to surface coverage.
  static Future<int> count() async {
    await _ensureLoaded();
    return _events?.length ?? 0;
  }
}

class _IndexedEntry {
  final int chapter;
  final int verseStart;
  final int verseEnd;
  final SynopsisEvent event;
  const _IndexedEntry({
    required this.chapter,
    required this.verseStart,
    required this.verseEnd,
    required this.event,
  });
}
