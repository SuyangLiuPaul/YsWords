import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/services/profile_service.dart';

/// Per-profile recent-search history. Surfaced as tappable chips
/// above the search results list when the query box is empty so
/// users can re-run common queries without retyping.
///
/// Capped at [maxItems]; pushing a duplicate moves it to the front.
class RecentSearchesService {
  static const _baseKey = 'recentSearches';
  static const int maxItems = 12;

  /// Read the list (most-recent first). Empty list when no history.
  static Future<List<String>> list() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
            .getStringList(ProfileService.instance.scopedKey(_baseKey)) ??
        const [];
  }

  /// Push [query] onto the front of the history. No-op for empty
  /// strings; deduplicates case-insensitively.
  static Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = ProfileService.instance.scopedKey(_baseKey);
    final cur = prefs.getStringList(key) ?? <String>[];
    cur.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    cur.insert(0, q);
    if (cur.length > maxItems) cur.removeRange(maxItems, cur.length);
    await prefs.setStringList(key, cur);
  }

  /// Clear all stored queries for the current profile.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ProfileService.instance.scopedKey(_baseKey));
  }

  /// 2026-05-07: per-item delete — used by the redesigned recent-
  /// searches list where each row has its own × button. No-op when
  /// [query] isn't found. Case-insensitive match (mirrors how add()
  /// dedupes).
  static Future<void> remove(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = ProfileService.instance.scopedKey(_baseKey);
    final cur = prefs.getStringList(key);
    if (cur == null || cur.isEmpty) return;
    cur.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    if (cur.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setStringList(key, cur);
    }
  }
}
