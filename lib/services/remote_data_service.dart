import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
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

  /// Whether [reconcileJson] does anything.
  ///
  /// Default **false**, and everything below is gated on it, so a
  /// service that does not override it reads the bundled asset exactly
  /// as often as it did before this hook existed. No extra I/O, no
  /// behaviour change.
  bool get reconcilesIncoming => false;

  /// Repair a payload that arrived from the network or the prefs
  /// cache, using the bundled snapshot as the reference. Identity by
  /// default.
  ///
  /// This exists because a publisher can lose a field it never learned
  /// to emit, and the client is the only place that still knows the
  /// value. See `_SongServiceImpl.reconcileJson` for the one case:
  /// 191 CDC cover images that live only in the bundled catalogue.
  ///
  /// **It runs on the decoded payload, before [parse], and it does NOT
  /// change what gets cached.** The raw upstream body is still what is
  /// written to SharedPreferences, so the cache stays a faithful copy
  /// of what the server said and the repair is re-applied on every
  /// load. That keeps the two artifacts honest: prefs = upstream
  /// truth, in memory = upstream plus a named, logged shim.
  Map<String, dynamic> reconcileJson(
          Map<String, dynamic> incoming, Map<String, dynamic> bundled) =>
      incoming;

  T? _cached;
  Future<T>? _inflight;
  Map<String, dynamic>? _bundledJson;

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
      final chosen = await _freshestLocal(fromCache);
      _cached = chosen;
      // ignore: unawaited_futures
      refresh();
      return chosen;
    } catch (e) {
      _inflight = null;
      rethrow;
    }
  }

  /// The bundled snapshot, decoded once and kept. Only ever read from
  /// the app's own assets, so it cannot go stale within a run.
  Future<Map<String, dynamic>> _loadBundledJson() async {
    final have = _bundledJson;
    if (have != null) return have;
    final raw = await rootBundle.loadString(bundledAssetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _bundledJson = decoded;
    return decoded;
  }

  Future<T> _loadBundled() async => parse(await _loadBundledJson());

  /// Parse a payload that came from the network or the prefs cache,
  /// giving the subclass a chance to repair it first.
  ///
  /// The bundled asset is never itself reconciled — it IS the
  /// reference — and a failure to read it leaves the incoming payload
  /// untouched rather than taking the load down.
  Future<T> _parseIncoming(Map<String, dynamic> incoming) async {
    if (!reconcilesIncoming) return parse(incoming);
    try {
      return parse(reconcileJson(incoming, await _loadBundledJson()));
    } catch (e) {
      debugPrint('[$runtimeType] could not reconcile against '
          '$bundledAssetPath: $e — using the payload as received.');
      return parse(incoming);
    }
  }

  /// Pick the newer of the SharedPreferences cache and the bundled
  /// snapshot, by [generatedAt].
  ///
  /// 2026-08-10 (v1.4.39): this used to return the cache whenever one
  /// existed, and never looked at the bundle. That is wrong in a way
  /// that does not heal, because **SharedPreferences survives an app
  /// upgrade**: once a user cached a bad edition, every later release
  /// shipped a good `assets/songs.json` that was never read.
  ///
  /// It was not hypothetical. A yswords-data cron ran while
  /// christiandiscipleschurch.org was refusing connections and
  /// published a catalogue whose CDC entries had lost their audio.
  /// Clients that fetched during that window then showed 283 CDC songs
  /// with no play button — a language badge where the play button
  /// belongs — and reinstalling the app did not clear it. `refresh()`
  /// already guards the network against exactly this (it keeps the
  /// local copy when the network edition is older); the local tiers
  /// simply never got the same check.
  ///
  /// Only a STRICTLY newer bundle wins, so a user whose cache is
  /// legitimately ahead of the shipped snapshot — the normal case, and
  /// the reason the cache is consulted first at all — keeps it. When
  /// either side has no [generatedAt] the comparison is meaningless
  /// and the cache stays, preserving the old behaviour for services
  /// that do not stamp their data.
  Future<T> _freshestLocal(T? fromCache) async {
    if (fromCache == null) return _loadBundled();
    final cacheAt = generatedAt(fromCache);
    if (cacheAt == null) return fromCache;
    try {
      final bundled = await _loadBundled();
      final bundleAt = generatedAt(bundled);
      if (bundleAt != null && bundleAt.isAfter(cacheAt)) {
        debugPrint('[$runtimeType] bundled snapshot ($bundleAt) is newer '
            'than the cached one ($cacheAt) — using the bundle. A cache '
            'from a bad publish would otherwise outlive the upgrade.');
        return bundled;
      }
    } catch (e) {
      // A missing or malformed bundled asset must not take down a
      // perfectly good cache.
      debugPrint('[$runtimeType] could not read $bundledAssetPath: $e');
    }
    return fromCache;
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

      // A missing file on Netlify comes back 200 with index.html, not
      // 404 — the SPA catch-all answers it. So a renamed or unpublished
      // asset arrives looking like a success, and `jsonDecode` fails on
      // the leading `<`. That was already caught below, but it landed
      // in the same silent branch as "the network is down", making a
      // broken CDN path indistinguishable from a plane — permanently,
      // and with nothing in the log to say which.
      //
      // Same trap bit this repo's own web build: `flutter_bootstrap.js`
      // was served as index.html and Chrome refused it for MIME type.
      if (looksLikeHtml(body)) {
        debugPrint('[$runtimeType] $remoteUrl returned HTML, not JSON — '
            'the file is probably missing and Netlify served the SPA '
            'shell. Keeping the cached copy.');
        return;
      }

      final j = jsonDecode(body) as Map<String, dynamic>;
      final fresh = await _parseIncoming(j);

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
      // Reconciled: a cached body is upstream's, with upstream's gaps,
      // and it outlives an app upgrade.
      return await _parseIncoming(j);
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

  /// The loaded bundle, or null before the first [load] completes.
  ///
  /// Synchronous read-only view for callers that need a detail off the
  /// bundle (its `generatedAt`, a count) without awaiting a second
  /// load — e.g. a footer showing when the data was published. Never
  /// triggers a fetch; if it is null, just don't show the detail.
  T? get cachedOrNull => _cached;

  /// Reset everything (test helper / sign-out path).
  Future<void> clearCache() async {
    _cached = null;
    _inflight = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cachePrefsKey);
    await prefs.remove(cacheTimePrefsKey);
  }
}

/// Whether a response body is an HTML page rather than the JSON we
/// asked for.
///
/// Netlify answers a missing file with 200 and the SPA shell, so this
/// is the difference between "the data moved" and "the user is
/// offline". Checked on the first non-space characters: a JSON
/// document starts `{` or `[`, and nothing we fetch legitimately
/// begins with `<`.
@visibleForTesting
bool looksLikeHtml(String body) {
  final head = body.trimLeft();
  if (head.isEmpty) return false;
  if (head.startsWith('<')) return true;
  // A UTF-8 BOM ahead of the doctype still means HTML.
  return head.codeUnitAt(0) == 0xFEFF && head.trimLeft().startsWith('<');
}
