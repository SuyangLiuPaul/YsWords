import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Base class for any service that backs a JSON dataset shipped via
/// the central yswords-data site (https://yswords-data.netlify.app).
///
/// Three-tier fallback strategy, in order:
///   1. SharedPreferences cache (last successful network fetch)
///   2. Bundled snapshot in `assets/`
///   3. Network fetch (always best-effort, never blocks UI)
///
/// Subclasses provide:
///   • [bundledAssetPath]   — `assets/<file>.json`
///   • [remoteUrl]          — full https URL on yswords-data
///   • [cachePrefsKey]      — versioned key (bump to invalidate
///                            old user caches when shape changes)
///   • [parse]              — turns a `Map<String,dynamic>` into the
///                            domain model
///
/// Caller convention:
///   final bundle = await MyService.load();   // never throws —
///                                            // always returns a
///                                            // populated bundle
///   await MyService.refresh();               // best-effort upgrade
abstract class RemoteDataService<T> {
  /// `assets/<name>.json` path passed to `rootBundle.loadString`.
  String get bundledAssetPath;

  /// Full https URL on the central data site. Should be configurable
  /// at build time via `--dart-define=…`.
  String get remoteUrl;

  /// SharedPreferences key holding the last successful network body.
  /// Bump the version suffix (`v1`, `v2`, …) when changing the
  /// schema in a way that old cached payloads can't satisfy.
  String get cachePrefsKey;

  /// SharedPreferences key holding the ISO timestamp of the cached
  /// payload. Used by `cacheAge()`.
  String get cacheTimePrefsKey => '$cachePrefsKey.at';

  /// Parser. Subclasses turn the decoded map into the domain object.
  T parse(Map<String, dynamic> json);

  /// Optional: pull a `DateTime?` "edition" / "generatedAt" out of
  /// the parsed bundle. When non-null, [refresh] uses it to skip
  /// swapping in the network response if it's older than the cached
  /// one.
  DateTime? generatedAt(T bundle) => null;

  /// HTTP timeout. Subclasses can override.
  Duration get timeout => const Duration(seconds: 12);

  T? _cached;
  Future<T>? _inflight;

  /// Returns the freshest available bundle (cached → bundled).
  /// Triggers a background refresh on every call.
  Future<T> load() {
    if (_cached != null) {
      // Best-effort upgrade in the background.
      // ignore: unawaited_futures
      refresh();
      return Future.value(_cached as T);
    }
    return _inflight ??= _firstLoad();
  }

  Future<T> _firstLoad() async {
    try {
      final fromCache = await _loadFromPrefs();
      if (fromCache != null) {
        _cached = fromCache;
        // ignore: unawaited_futures
        refresh();
        return fromCache;
      }
      final raw = await rootBundle.loadString(bundledAssetPath);
      final bundled = parse(jsonDecode(raw) as Map<String, dynamic>);
      _cached = bundled;
      // ignore: unawaited_futures
      refresh();
      return bundled;
    } catch (e) {
      _inflight = null;
      rethrow;
    }
  }

  /// Best-effort network refresh. Updates in-memory + prefs cache on
  /// success, swallows network errors.
  Future<void> refresh() async {
    try {
      final resp =
          await http.get(Uri.parse(remoteUrl)).timeout(timeout);
      if (resp.statusCode != 200) return;
      final body = resp.body;
      final j = jsonDecode(body) as Map<String, dynamic>;
      final fresh = parse(j);

      // If we already have a cached bundle and the network one is
      // strictly older, keep the local one — protects against an
      // upstream rollback or an empty cron run.
      final cur = _cached;
      if (cur != null) {
        final curAt = generatedAt(cur);
        final newAt = generatedAt(fresh);
        if (curAt != null && newAt != null && newAt.isBefore(curAt)) {
          return;
        }
      }

      _cached = fresh;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cachePrefsKey, body);
      await prefs.setString(
        cacheTimePrefsKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {
      // Network down, server slow, malformed JSON — keep what we have.
    }
  }

  Future<T?> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cachePrefsKey);
      if (raw == null || raw.isEmpty) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return parse(j);
    } catch (_) {
      // Corrupt cache — wipe and start over next launch.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(cachePrefsKey);
        await prefs.remove(cacheTimePrefsKey);
      } catch (_) {}
      return null;
    }
  }

  /// Reset everything (test helper / sign-out path).
  Future<void> clearCache() async {
    _cached = null;
    _inflight = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cachePrefsKey);
    await prefs.remove(cacheTimePrefsKey);
  }
}
