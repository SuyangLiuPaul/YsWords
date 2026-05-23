import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/services/realtime_db_sync_service.dart';

/// Per-profile recent-search history. Surfaced as tappable rows
/// above the search results list when the query box is empty so
/// users can re-run common queries without retyping.
///
/// Capped at [maxItems]; pushing a duplicate moves it to the front.
///
/// 2026-05-24 (v1.2.91): we now also persist a per-query creation
/// timestamp (epoch ms) so the UI can render "5 分钟前 / 5 minutes
/// ago" next to each row, and stay correctly sorted even after
/// cross-device RTDB sync merges the lists. The order in the
/// stored `List<String>` is still authoritative (insert-at-front =
/// most-recent first) — timestamps are a display + sync aid, not
/// the primary order.
class RecentSearchesService {
  static const _baseKey = 'recentSearches';
  // 2026-05-24 (v1.2.91): companion JSON map of query → epoch ms.
  // Lives under its own SharedPreferences key so older clients
  // without sort UI never read it.
  static const _timestampsBaseKey = 'recentSearchTimestamps';
  static const int maxItems = 12;

  /// 2026-05-11 (v1.2.42): mutex for `add` / `remove` / `clear`.
  /// All three do a non-atomic read-modify-write on SharedPreferences
  /// (`getStringList` → mutate → `setStringList`). Without a mutex,
  /// two concurrent calls — common when v1.2.41's live-search
  /// triggers `add(...)` while a user simultaneously taps the "X"
  /// delete on an existing row — can interleave and drop an entry.
  /// All writes funnel through this single-slot serialised queue.
  static Future<void> _writeLock = Future<void>.value();

  /// Read the list (most-recent first). Empty list when no history.
  static Future<List<String>> list() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
            .getStringList(ProfileService.instance.scopedKey(_baseKey)) ??
        const [];
  }

  /// Read the list paired with their creation timestamps. Returns
  /// (query, DateTime) tuples in most-recent-first order. Any query
  /// without a recorded timestamp (legacy entries created before
  /// v1.2.91, or remote-synced entries from an older client) is
  /// stamped lazily with `now` so the UI never has to handle nulls
  /// — net effect on first read after upgrade: existing queries all
  /// bunch up at "just now" until the user runs them again.
  static Future<List<RecentSearchEntry>> listWithTimestamps() async {
    final prefs = await SharedPreferences.getInstance();
    final qs = prefs
            .getStringList(ProfileService.instance.scopedKey(_baseKey)) ??
        const <String>[];
    if (qs.isEmpty) return const [];
    final raw = prefs.getString(
        ProfileService.instance.scopedKey(_timestampsBaseKey));
    var map = <String, int>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final e in decoded.entries) {
            final v = e.value;
            if (v is num) map[e.key.toString()] = v.toInt();
          }
        }
      } catch (_) {/* corrupt → migrate fresh below */}
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    var migrated = false;
    final out = <RecentSearchEntry>[];
    // Walk most-recent-first so a freshly migrated entry doesn't
    // get the SAME stamp as an older one — pretend each step is a
    // millisecond apart so the canonical order remains stable.
    for (int i = 0; i < qs.length; i++) {
      final q = qs[i];
      var ts = map[q.toLowerCase()];
      if (ts == null) {
        ts = now - i; // newer entries get larger stamps
        map[q.toLowerCase()] = ts;
        migrated = true;
      }
      out.add(RecentSearchEntry(
          query: q, createdAt: DateTime.fromMillisecondsSinceEpoch(ts)));
    }
    // Trim orphans (timestamps for queries no longer in the list).
    final liveKeys = qs.map((q) => q.toLowerCase()).toSet();
    final toDrop = <String>[];
    for (final k in map.keys) {
      if (!liveKeys.contains(k)) toDrop.add(k);
    }
    for (final k in toDrop) {
      map.remove(k);
    }
    if (migrated || toDrop.isNotEmpty) {
      // Fire-and-forget persist of the migrated map. Errors are
      // non-fatal — next read will just re-migrate.
      // ignore: unawaited_futures
      prefs.setString(
          ProfileService.instance.scopedKey(_timestampsBaseKey),
          jsonEncode(map));
    }
    return out;
  }

  /// Push [query] onto the front of the history. No-op for empty
  /// strings; deduplicates case-insensitively. Bumps the timestamp
  /// to the current moment whether the query is brand-new or being
  /// re-run — so "most recent activity" sort works correctly.
  static Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    // Serialise on `_writeLock` so overlapping `add`s don't
    // interleave their read-modify-writes. Each new caller waits
    // for the previous write to complete before reading prefs.
    final prev = _writeLock;
    final completer = Completer<void>();
    _writeLock = completer.future;
    try {
      await prev;
      final prefs = await SharedPreferences.getInstance();
      final key = ProfileService.instance.scopedKey(_baseKey);
      final cur = prefs.getStringList(key) ?? <String>[];
      cur.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
      cur.insert(0, q);
      if (cur.length > maxItems) cur.removeRange(maxItems, cur.length);
      await prefs.setStringList(key, cur);
      // 2026-05-24 (v1.2.91): refresh the per-query timestamp map.
      // Stored as a JSON map for compactness + RTDB-sync friendliness.
      await _updateTimestamps(prefs, (map) {
        map[q.toLowerCase()] = DateTime.now().millisecondsSinceEpoch;
        // Drop any stamps for queries that fell off the maxItems
        // cap above — keeps the map size bounded.
        final liveKeys = cur.map((e) => e.toLowerCase()).toSet();
        map.removeWhere((k, _) => !liveKeys.contains(k));
      });
      RealtimeDbSyncService.instance.requestUpload();
    } finally {
      completer.complete();
    }
  }

  /// Clear all stored queries for the current profile.
  static Future<void> clear() async {
    final prev = _writeLock;
    final completer = Completer<void>();
    _writeLock = completer.future;
    try {
      await prev;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ProfileService.instance.scopedKey(_baseKey));
      await prefs
          .remove(ProfileService.instance.scopedKey(_timestampsBaseKey));
      RealtimeDbSyncService.instance.requestUpload();
    } finally {
      completer.complete();
    }
  }

  /// 2026-05-07: per-item delete — used by the redesigned recent-
  /// searches list where each row has its own × button. No-op when
  /// [query] isn't found. Case-insensitive match (mirrors how add()
  /// dedupes).
  static Future<void> remove(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final prev = _writeLock;
    final completer = Completer<void>();
    _writeLock = completer.future;
    try {
      await prev;
      final prefs = await SharedPreferences.getInstance();
      final key = ProfileService.instance.scopedKey(_baseKey);
      final cur = prefs.getStringList(key);
      if (cur == null || cur.isEmpty) return;
      cur.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
      if (cur.isEmpty) {
        await prefs.remove(key);
        await prefs
            .remove(ProfileService.instance.scopedKey(_timestampsBaseKey));
      } else {
        await prefs.setStringList(key, cur);
        await _updateTimestamps(prefs, (map) {
          map.remove(q.toLowerCase());
        });
      }
      RealtimeDbSyncService.instance.requestUpload();
    } finally {
      completer.complete();
    }
  }

  /// Read-modify-write helper for the timestamp companion map.
  /// Lives under the same profile scope as the main list.
  static Future<void> _updateTimestamps(
      SharedPreferences prefs, void Function(Map<String, int>) mutate) async {
    final key = ProfileService.instance.scopedKey(_timestampsBaseKey);
    final raw = prefs.getString(key);
    final map = <String, int>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final e in decoded.entries) {
            final v = e.value;
            if (v is num) map[e.key.toString()] = v.toInt();
          }
        }
      } catch (_) {/* corrupt → caller's mutate replaces it */}
    }
    mutate(map);
    if (map.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, jsonEncode(map));
    }
  }
}

/// 2026-05-24 (v1.2.91): one row in the recent-searches list with
/// its creation timestamp. The UI uses [createdAt] to render
/// "5 分钟前 / 5 minutes ago" next to each query and to expose a
/// "sort by created date" mode if needed in future. [query] is the
/// raw user-entered text (case preserved as typed).
class RecentSearchEntry {
  final String query;
  final DateTime createdAt;
  const RecentSearchEntry({required this.query, required this.createdAt});
}
