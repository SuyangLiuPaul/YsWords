import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-06-12 (v1.3.63): pure throttle decision for
/// [RemoteDataService.refresh]. Returns true when a background refresh
/// should be SKIPPED — i.e. the last successful network refresh
/// ([cacheTimeIso], an ISO-8601 UTC string) is newer than
/// [minInterval] ago relative to [nowUtc]. A null/unparseable
/// timestamp or a non-positive interval never throttles (always
/// allow the refresh). Exposed for testing.
bool shouldThrottleRefresh(
  String? cacheTimeIso,
  Duration minInterval,
  DateTime nowUtc,
) {
  if (minInterval <= Duration.zero) return false;
  if (cacheTimeIso == null || cacheTimeIso.isEmpty) return false;
  final at = DateTime.tryParse(cacheTimeIso);
  if (at == null) return false;
  return nowUtc.difference(at.toUtc()) < minInterval;
}

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

  /// 2026-06-12 (v1.3.63 perf): minimum wall-clock gap between the
  /// background network refreshes that [load] fires on every call.
  /// Default `Duration.zero` = refresh on every load — correct for
  /// data that changes often (e.g. the hourly news feed). Services
  /// backing a rarely-changing archive override this so a returning
  /// user doesn't re-download the whole dataset on every cold start
  /// just to surface one card. The bundled/cached copy still loads
  /// instantly; only the redundant cross-origin GET is skipped. An
  /// explicit `refresh(force: true)` (pull-to-refresh) always hits the
  /// network regardless.
  Duration get minRefreshInterval => Duration.zero;

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
  /// success, swallows network errors. Throttled by
  /// [minRefreshInterval] unless [force] is set (explicit user
  /// pull-to-refresh).
  Future<void> refresh({bool force = false}) async {
    try {
      // Throttle: if we refreshed from the network within
      // minRefreshInterval, skip the round trip. The cache timestamp
      // is only written on a successful network refresh, so the very
      // first load (no timestamp yet) always fetches once.
      if (!force && minRefreshInterval > Duration.zero) {
        final prefs = await SharedPreferences.getInstance();
        final atStr = prefs.getString(cacheTimePrefsKey);
        if (shouldThrottleRefresh(
            atStr, minRefreshInterval, DateTime.now().toUtc())) {
          return;
        }
      }
      final resp =
          await http.get(Uri.parse(remoteUrl)).timeout(timeout);
      if (resp.statusCode != 200) return;
      final body = resp.body;
      final j = jsonDecode(body) as Map<String, dynamic>;
      final fresh = parse(j);

      // 2026-06-12 (v1.3.64): stamp "last successful network check" NOW,
      // before the staleness guard below. cacheTimePrefsKey drives the
      // refresh throttle (= "did we check recently?"), which is a
      // different question from "did the body change?". The bundled
      // asset can ship NEWER than the deployed dataset (built after the
      // last yswords-data cron), so the guard's early-return was the
      // norm, not the exception — and it skipped this write, so the
      // throttle never engaged and the dashboard re-hit the network on
      // every mount. Recording the check-time unconditionally fixes it.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        cacheTimePrefsKey,
        DateTime.now().toUtc().toIso8601String(),
      );

      // If we already have a cached bundle and the network one is
      // strictly older, keep the local one — protects against an
      // upstream rollback or an empty cron run. (Check-time already
      // recorded above.)
      final cur = _cached;
      if (cur != null) {
        final curAt = generatedAt(cur);
        final newAt = generatedAt(fresh);
        if (curAt != null && newAt != null && newAt.isBefore(curAt)) {
          return;
        }
      }

      _cached = fresh;
      await prefs.setString(cachePrefsKey, body);
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
