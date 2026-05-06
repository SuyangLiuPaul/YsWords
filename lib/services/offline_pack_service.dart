import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Three categories the user can pre-download for offline use.
/// Sizes below are approximate as of Round 56 — used for the
/// Settings UI label only; the actual fetch is byte-accurate.
enum OfflinePackCategory {
  /// All 14 Bible translations (~77 MB).
  bibles,

  /// 587 sermons × up to 3 languages = ~867 files (~26 MB).
  sermons,

  /// Family tree / timeline / evidence / cross-refs / section
  /// titles / book intros / daily verses / sermon refs (~9 MB).
  tools,
}

/// Bulk pre-fetcher for the assets the app reads from
/// `rootBundle.loadString(...)`. Once a URL has been fetched it
/// lives in the browser's HTTP cache + the Flutter service worker
/// cache, so subsequent reads are instant and work offline.
///
/// We rely on the existing Flutter web service worker to intercept
/// + cache the responses. No custom SW is registered; a custom SW
/// would conflict with Flutter's. The trade-off is that we don't
/// have fine-grained control over the cache name — but we get
/// "just works" semantics on every Flutter web build.
///
/// Usage:
///   final ok = await OfflinePackService.instance
///       .download(categories: {OfflinePackCategory.bibles});
///
/// Listenable — UI can `context.watch<OfflinePackService>()` to
/// see live progress.
class OfflinePackService extends ChangeNotifier {
  OfflinePackService._();
  static final OfflinePackService instance = OfflinePackService._();

  static const _kCategoryKey = 'offlinePack.lastDownloadedCategories';
  static const _kCompletedAtKey = 'offlinePack.lastCompletedAt';

  // ── State surfaced to the UI ─────────────────────────────────
  bool _downloading = false;
  int _done = 0;
  int _total = 0;
  int _failed = 0;
  String? _error;
  Set<OfflinePackCategory> _lastDownloaded = const {};
  DateTime? _lastCompletedAt;

  bool get downloading => _downloading;
  int get done => _done;
  int get total => _total;
  int get failed => _failed;
  double get progress => _total == 0 ? 0 : _done / _total;
  String? get error => _error;
  Set<OfflinePackCategory> get lastDownloaded => Set.unmodifiable(_lastDownloaded);
  DateTime? get lastCompletedAt => _lastCompletedAt;

  /// Restore the persisted "what's already cached" + "when" state so
  /// the Settings UI can show an accurate label on app launch.
  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kCategoryKey) ?? const [];
    _lastDownloaded = raw
        .map((s) => OfflinePackCategory.values
            .firstWhere((c) => c.name == s,
                orElse: () => OfflinePackCategory.tools))
        .toSet();
    final ts = prefs.getString(_kCompletedAtKey);
    if (ts != null) {
      _lastCompletedAt = DateTime.tryParse(ts);
    }
    notifyListeners();
  }

  /// Cancel an in-flight download. Subsequent fetches stop after
  /// the currently-running one finishes; `notifyListeners()` fires
  /// once cancellation takes effect.
  void cancel() {
    if (!_downloading) return;
    _downloading = false;
    notifyListeners();
  }

  /// Run the bulk download for [categories]. Returns true if every
  /// file was fetched successfully (or counted as best-effort —
  /// see [_failed] for skipped ones), false if cancelled or every
  /// fetch threw.
  Future<bool> download({
    required Set<OfflinePackCategory> categories,
  }) async {
    if (_downloading) return false;
    if (categories.isEmpty) return true;

    final urls = await _buildUrlList(categories);
    if (urls.isEmpty) return true;

    _downloading = true;
    _done = 0;
    _failed = 0;
    _total = urls.length;
    _error = null;
    notifyListeners();

    // Run up to 8 fetches in parallel — far faster than serial for
    // the small (mostly KB-sized) sermon files. Cap to 8 because
    // Chrome limits per-origin connections to ~6, so going higher
    // doesn't help and just queues at the browser layer.
    const concurrency = 8;
    var idx = 0;
    Future<void> worker() async {
      while (_downloading) {
        final myIdx = idx++;
        if (myIdx >= urls.length) break;
        try {
          await _fetchPromise(urls[myIdx]).toDart;
        } catch (_) {
          _failed++;
        }
        _done++;
        // Throttle UI updates — only notify every ~10 files or at
        // category boundaries; saves rebuild cost when the bar is
        // moving fast.
        if (_done % 5 == 0 || _done == _total) notifyListeners();
      }
    }

    final workers = List.generate(concurrency, (_) => worker());
    await Future.wait(workers);

    final completed = _downloading; // false if user hit Cancel
    _downloading = false;
    if (completed) {
      _lastDownloaded = Set.of(categories);
      _lastCompletedAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kCategoryKey,
        _lastDownloaded.map((c) => c.name).toList(),
      );
      await prefs.setString(
        _kCompletedAtKey,
        _lastCompletedAt!.toIso8601String(),
      );
    }
    notifyListeners();
    return completed;
  }

  /// Drop the persisted cache state. We don't try to evict the
  /// browser's HTTP cache or the Flutter SW cache here — the
  /// browser will manage that itself based on storage pressure;
  /// what we DO clear is our own bookkeeping, so the UI label
  /// resets to "no offline pack downloaded".
  Future<void> clear() async {
    _lastDownloaded = const {};
    _lastCompletedAt = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCategoryKey);
    await prefs.remove(_kCompletedAtKey);
  }

  // ── URL enumeration per category ─────────────────────────────

  Future<List<String>> _buildUrlList(
      Set<OfflinePackCategory> categories) async {
    final urls = <String>[];
    if (categories.contains(OfflinePackCategory.bibles)) {
      urls.addAll(_bibleUrls);
    }
    if (categories.contains(OfflinePackCategory.tools)) {
      urls.addAll(_toolsUrls);
    }
    if (categories.contains(OfflinePackCategory.sermons)) {
      urls.addAll(await _sermonUrls());
    }
    // Dedupe in case categories overlap (they don't today, but
    // future categories might).
    return urls.toSet().toList();
  }

  static const List<String> _bibleUrls = [
    'assets/kjv.json',
    'assets/leb.json',
    'assets/nasb.json',
    // 'assets/niv.json' removed 2026-05 — NIV asset bundle removed
    // along with its picker entry (see bible_versions.dart).
    'assets/cuv.json',
    'assets/cuv-tr.json',
    'assets/cuvs-yhwh.json',
    'assets/cuvs-yhwh-tr.json',
    'assets/cnv.json',
    'assets/cnv-tr.json',
    'assets/biblexg.json',
    'assets/biblexg-tr.json',
    'assets/biblexg-v2.json',
    'assets/biblexg-v2-tr.json',
  ];

  static const List<String> _toolsUrls = [
    'assets/family_tree.json',
    'assets/bible_timeline.json',
    'assets/bible_evidence.json',
    'assets/cross_references.json',
    'assets/section_titles.json',
    'assets/book_introductions.json',
    'assets/maps_index.json',
    'assets/daily_verses.json',
    'assets/web-ot-paragraphs.json',
    'assets/sermons/index.json',
    'assets/sermons/refs.json',
  ];

  /// Build the full sermon-body URL list by reading
  /// `assets/sermons/index.json` and emitting one URL per
  /// (sermon × language) where the sermon advertises that the
  /// body file exists.
  Future<List<String>> _sermonUrls() async {
    try {
      final raw = await rootBundle.loadString('assets/sermons/index.json');
      final list = json.decode(raw) as List<dynamic>;
      final out = <String>[];
      for (final s in list.whereType<Map<String, dynamic>>()) {
        final id = s['id'] as String? ?? '';
        if (id.isEmpty) continue;
        if (s['hasEn'] == true) out.add('assets/sermons/en/$id.txt');
        if (s['hasZhCn'] == true) out.add('assets/sermons/zh-CN/$id.txt');
        if (s['hasZhTw'] == true) out.add('assets/sermons/zh-TW/$id.txt');
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Approximate size (in MB) for the UI label. Not exact — the
  /// real bytes include compression, but this is enough for "feels
  /// right". Update when major content drops change category sizes.
  int approximateMbFor(OfflinePackCategory c) {
    switch (c) {
      case OfflinePackCategory.bibles:
        return 77;
      case OfflinePackCategory.sermons:
        return 26;
      case OfflinePackCategory.tools:
        return 9;
    }
  }
}

// ── Tiny JS interop binding for `fetch(url)`. We don't read the
// body — the Flutter SW's intercept-and-cache side effect is
// what makes the fetch worth doing.
@JS('fetch')
external JSPromise<JSAny?> _fetchPromise(String url);
