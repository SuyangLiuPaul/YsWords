// The changelog the app ships, and the shape the page renders it in.
//
// Generated at release time by `tools/build_changelog.py` from the
// `release: vX.Y.Z` commits — see that file for why the notes come
// from commit subjects, why the GitHub Release bodies are useless for
// this (all 270 of them are the same Linux build boilerplate), and why
// the window is 120 versions.
//
// **Grouped by day, not listed by version, and that is the whole
// design.** This app shipped 29 versions in three days; a list of
// version numbers is the noise, not the notes. Seventeen date headings
// carry a month of history that a hundred and fifteen rows could not.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One released version and what changed in it.
class ChangelogEntry {
  final String version;

  /// `YYYY-MM-DD`, as the release commit was dated.
  final String date;

  /// Commit subjects, newest first, already filtered of bookkeeping.
  /// Never empty — a version with nothing to say is dropped by the
  /// generator rather than shipped as a blank row.
  final List<String> notes;

  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.notes,
  });
}

/// Every version released on one day, newest version first.
class ChangelogDay {
  final String date;
  final List<ChangelogEntry> versions;

  const ChangelogDay({required this.date, required this.versions});

  /// How many individual changes landed that day — the number worth
  /// putting on the heading, because "12 changes" is information and
  /// "7 versions" is an implementation detail of how often we deploy.
  int get noteCount =>
      versions.fold(0, (sum, v) => sum + v.notes.length);
}

class ChangelogService {
  ChangelogService._();

  static const String assetPath = 'assets/changelog.json';

  static List<ChangelogDay>? _cache;

  /// Load and group the changelog. Cached — the asset never changes
  /// within a run, and the page can be opened repeatedly.
  ///
  /// Returns an empty list rather than throwing if the asset is
  /// missing or malformed: a changelog is not worth a crash, and the
  /// page has an empty state that points at GitHub.
  static Future<List<ChangelogDay>> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final entries = (decoded['entries'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .map((e) => ChangelogEntry(
                version: e['version'] as String,
                date: e['date'] as String,
                notes: (e['notes'] as List<dynamic>).cast<String>(),
              ))
          .where((e) => e.notes.isNotEmpty)
          .toList();
      return _cache = groupByDay(entries);
    } catch (_) {
      return _cache = const <ChangelogDay>[];
    }
  }

  /// Group consecutive entries sharing a date.
  ///
  /// Consecutive rather than by map key, deliberately: the generator
  /// emits versions in release order, and preserving that order is
  /// what keeps 1.6.270 above 1.6.269 inside a day. A `Map` keyed by
  /// date would give the same grouping and lose the ordering inside
  /// it on any platform where map iteration is not insertion-ordered.
  static List<ChangelogDay> groupByDay(List<ChangelogEntry> entries) {
    final days = <ChangelogDay>[];
    for (final entry in entries) {
      if (days.isNotEmpty && days.last.date == entry.date) {
        days.last.versions.add(entry);
      } else {
        days.add(ChangelogDay(date: entry.date, versions: [entry]));
      }
    }
    return days;
  }

  /// Test seam: forget the cached parse.
  static void resetForTest() => _cache = null;
}
