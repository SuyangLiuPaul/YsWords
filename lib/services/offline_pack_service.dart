import 'dart:async';
import 'dart:convert';
// 2026-05-20 (v1.2.67): `dart:js_interop` removed in favour of
// the conditional-export helper. Web build still uses
// `fetch(url)`; native build skips with a debug log (the
// offline-pack UI is web-only anyway).
import 'package:yswords/utils/fetch_helper.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Five categories the user can pre-download for offline use.
/// Sizes below are approximate as of 2026-05 — used for the
/// Settings UI label only; the actual fetch is byte-accurate.
///
/// Categories were reorganised in 2026-05 after a "really works
/// offline?" audit — the previous split into bibles / sermons /
/// tools left out the Strong's lexicons, the per-book interlinear
/// JSONs, and the 55 map images, so word-study and map features
/// silently failed offline. The new `originals` and `maps`
/// categories give the user explicit control over those (large)
/// downloads.
enum OfflinePackCategory {
  /// All 13 Bible translations (~70 MB after NIV removal).
  bibles,

  /// 587 sermons × up to 3 languages = ~867 files (~26 MB).
  sermons,

  /// Family tree / timeline / evidence / cross-refs / section
  /// titles / book intros / daily verses / sermon refs /
  /// reading plans / gospel synopsis / loading + app icon (~10 MB).
  tools,

  /// Strong's lexicon (concordance, Hebrew, Greek, LXX cross-
  /// references) plus the per-book Hebrew/Greek interlinear JSONs
  /// (66 files). Required for the exegesis word-study sheet,
  /// vocabulary tab, and word distribution table to work offline
  /// (~31 MB).
  originals,

  /// 55 Bible-history map images (~29 MB). The maps_index JSON is
  /// in the `tools` category, so without this category the map
  /// picker shows titles but tap → blank.
  maps,
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
  /// 2026-05-07: timestamp the most recent download started — used
  /// by [etaSeconds] to compute time-remaining ("~30 sec left",
  /// "~2 min left") so the user knows whether they should keep the
  /// app open. Reset to null on cancel / completion.
  DateTime? _downloadStartedAt;

  bool get downloading => _downloading;
  int get done => _done;
  int get total => _total;
  int get failed => _failed;
  double get progress => _total == 0 ? 0 : _done / _total;
  String? get error => _error;
  Set<OfflinePackCategory> get lastDownloaded => Set.unmodifiable(_lastDownloaded);
  DateTime? get lastCompletedAt => _lastCompletedAt;

  /// Estimated seconds remaining for the current download, or null
  /// when not enough data is available (download not in flight, or
  /// fewer than 5 files done so the rate estimate would be noisy).
  /// Used by the Settings UI to render "~30 sec left".
  int? get etaSeconds {
    if (!_downloading) return null;
    if (_done < 5) return null; // need a stable rate sample
    final start = _downloadStartedAt;
    if (start == null) return null;
    final elapsedMs = DateTime.now().difference(start).inMilliseconds;
    if (elapsedMs <= 0) return null;
    final remaining = _total - _done;
    if (remaining <= 0) return 0;
    final ratePerMs = _done / elapsedMs; // files per ms
    if (ratePerMs <= 0) return null;
    final etaMs = remaining / ratePerMs;
    return (etaMs / 1000).round();
  }

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
    _downloadStartedAt = null;
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
    _downloadStartedAt = DateTime.now();
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
          await fetchUrl(urls[myIdx]);
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
    _downloadStartedAt = null;
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
    if (categories.contains(OfflinePackCategory.originals)) {
      urls.addAll(_originalsUrls());
    }
    if (categories.contains(OfflinePackCategory.maps)) {
      urls.addAll(await _mapUrls());
    }
    if (categories.contains(OfflinePackCategory.sermons)) {
      urls.addAll(await _sermonUrls());
    }
    // Dedupe in case categories overlap (e.g. tools + originals
    // both reference maps_index.json indirectly via different
    // services).
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
    // Added 2026-05 after the "really offline?" audit — this was
    // missing and caused the gospel synopsis fallback to fail
    // offline. (reading_plans.json removed in v1.2.69.)
    'assets/gospel_synopsis.json',
    'assets/app_icon.png',
    'assets/loading.png',
  ];

  /// 4 Strong's lexicon files + 66 per-book Hebrew/Greek interlinear
  /// files. The interlinear list is hard-coded against the actual
  /// asset filenames — adding a new book requires editing this list,
  /// the same constraint as `pubspec.yaml` already imposes (the
  /// directory is registered as `assets/originals/` so any new file
  /// drops into the bundle automatically; keeping the offline list in
  /// sync is a manual step).
  List<String> _originalsUrls() {
    const lexicon = <String>[
      'assets/strongs/concordance.json',
      'assets/strongs/hebrew.json',
      'assets/strongs/greek.json',
      'assets/strongs/lxx_hebrew_to_greek.json',
    ];
    const books = <String>[
      // OT (39)
      'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy',
      'joshua', 'judges', 'ruth', '1_samuel', '2_samuel',
      '1_kings', '2_kings', '1_chronicles', '2_chronicles',
      'ezra', 'nehemiah', 'esther', 'job', 'psalms', 'proverbs',
      'ecclesiastes', 'song_of_solomon', 'isaiah', 'jeremiah',
      'lamentations', 'ezekiel', 'daniel', 'hosea', 'joel', 'amos',
      'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah',
      'haggai', 'zechariah', 'malachi',
      // NT (27)
      'matthew', 'mark', 'luke', 'john', 'acts', 'romans',
      '1_corinthians', '2_corinthians', 'galatians', 'ephesians',
      'philippians', 'colossians', '1_thessalonians',
      '2_thessalonians', '1_timothy', '2_timothy', 'titus',
      'philemon', 'hebrews', 'james', '1_peter', '2_peter',
      '1_john', '2_john', '3_john', 'jude', 'revelation',
    ];
    return [
      ...lexicon,
      for (final b in books) 'assets/originals/$b.json',
    ];
  }

  /// Map images come from `assets/maps_index.json`'s `file` field
  /// per entry. Reading the index dynamically means we don't need to
  /// re-edit this file every time a map is added or renamed.
  Future<List<String>> _mapUrls() async {
    try {
      final raw = await rootBundle.loadString('assets/maps_index.json');
      final list = json.decode(raw);
      if (list is! List) return const [];
      final out = <String>[];
      for (final m in list) {
        if (m is! Map) continue;
        final f = m['file'];
        if (f is String && f.isNotEmpty) {
          out.add('assets/maps/$f');
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

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
        return 70; // 13 versions after NIV removal
      case OfflinePackCategory.sermons:
        return 26;
      case OfflinePackCategory.tools:
        return 10; // includes reading_plans/synopsis/icons
      case OfflinePackCategory.originals:
        return 31; // 14 MB Strong's + 17 MB per-book interlinear
      case OfflinePackCategory.maps:
        return 29; // 55 jpg/png images
    }
  }
}

// ── Tiny JS interop binding for `fetch(url)`. We don't read the
// body — the Flutter SW's intercept-and-cache side effect is
// what makes the fetch worth doing.
// 2026-05-20 (v1.2.67): `@JS('fetch')` external moved to
// lib/utils/fetch_helper_web.dart so the file compiles on iOS.
