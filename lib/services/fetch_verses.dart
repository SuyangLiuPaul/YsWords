import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/error_reporter.dart';
import 'package:yswords/services/fetch_books.dart'
    show bookNameToEnglish, standardBookOrder;

/// Lightweight record of paragraph metadata for one verse, used when applying
/// shared structure across all Bible versions so paragraph mode reads
/// consistently regardless of translation.
class _ParaInfo {
  final bool isParagraphStart;
  final String paragraphType;
  const _ParaInfo(this.isParagraphStart, this.paragraphType);
}

class FetchVerses {
  /// LJK2 supplies NT paragraph metadata. WEB USFM supplies derived OT starts.
  /// Both are replayed onto every version so readers get consistent paragraph
  /// breaks across translations.
  static const _kNewTestamentParagraphRefPath = 'assets/biblexg-v2.json';
  static const _kOldTestamentParagraphRefPath = 'assets/web-ot-paragraphs.json';

  /// Cached map: english-book-name -> "chapter:verse" -> _ParaInfo.
  /// Populated lazily on first load and reused across version switches.
  static Map<String, Map<String, _ParaInfo>>? _paragraphMapCache;

  static Future<Map<String, Map<String, _ParaInfo>>> _loadParagraphMap() async {
    if (_paragraphMapCache != null) return _paragraphMapCache!;
    final result = <String, Map<String, _ParaInfo>>{};

    await _mergeParagraphReference(
      result,
      _kOldTestamentParagraphRefPath,
    );
    await _mergeParagraphReference(
      result,
      _kNewTestamentParagraphRefPath,
    );

    _paragraphMapCache = result;
    return result;
  }

  static Future<void> _mergeParagraphReference(
    Map<String, Map<String, _ParaInfo>> result,
    String path,
  ) async {
    try {
      final jsonString = await rootBundle.loadString(path);
      final dynamic decoded = json.decode(jsonString);
      if (decoded is List) {
        for (final entry in decoded) {
          if (entry is! Map<String, dynamic>) continue;
          final isStart = entry['isParagraphStart'] == true;
          final pType = (entry['paragraphType'] as String?) ?? 'inline';
          if (!isStart && pType == 'inline') continue;
          final bookRaw = (entry['book'] as String?) ?? '';
          final bookEn = bookNameToEnglish[bookRaw] ?? bookRaw;
          final chapter = entry['chapter']?.toString() ?? '';
          final verse = entry['verse']?.toString() ?? '';
          if (bookEn.isEmpty || chapter.isEmpty || verse.isEmpty) continue;
          _putParagraphInfo(
            result,
            bookEn,
            chapter,
            verse,
            _ParaInfo(isStart, pType),
          );
        }
      } else if (decoded is Map<String, dynamic>) {
        final books = decoded['books'];
        if (books is Map<String, dynamic>) {
          for (final bookEntry in books.entries) {
            final bookEn = bookNameToEnglish[bookEntry.key] ?? bookEntry.key;
            final chapters = bookEntry.value;
            if (chapters is! Map<String, dynamic>) continue;
            for (final chapterEntry in chapters.entries) {
              final verses = chapterEntry.value;
              if (verses is! List) continue;
              for (final verse in verses) {
                _putParagraphInfo(
                  result,
                  bookEn,
                  chapterEntry.key,
                  verse.toString(),
                  const _ParaInfo(true, 'paragraph'),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Could not load paragraph reference ($path): $e');
    }
  }

  static void _putParagraphInfo(
    Map<String, Map<String, _ParaInfo>> result,
    String book,
    String chapter,
    String verse,
    _ParaInfo info,
  ) {
    if (book.isEmpty || chapter.isEmpty || verse.isEmpty) return;
    result.putIfAbsent(book, () => <String, _ParaInfo>{})['$chapter:$verse'] =
        info;
  }

  /// 2026-05-10 (v1.2.10 → v1.2.12): default retry / timeout knobs
  /// for the initial verse-asset fetch.
  ///
  /// v1.2.10 picked 3 × 12 s. User came back next day saying
  /// "still failed to load, had to reopen". Diagnosis: Flutter
  /// web's `rootBundle.loadString` MEMOIZES the in-flight Future
  /// per-asset — calling it a second time during retry just
  /// re-awaits the same already-failed promise, NEVER triggering
  /// a fresh service-worker fetch. So our 3 attempts collapsed
  /// into 1 effective attempt. Fix in v1.2.12: call
  /// `rootBundle.clear(path)` for every asset before each retry,
  /// forcing a clean fetch. Also bumped the per-attempt timeout
  /// to 20 s so genuinely-slow first-load networks (cold SW
  /// install + 10 MB JSON over LTE) don't get false-failed.
  static const int _kDefaultMaxAttempts = 3;
  static const Duration _kDefaultTimeout = Duration(seconds: 20);

  /// Load the current version's verse JSON into [mainProvider]. Now
  /// auto-retries up to [maxAttempts] times with exponential backoff
  /// before rethrowing the last error.
  ///
  /// `onAttempt(attempt, lastError)` fires at the START of each
  /// attempt with `attempt` 1-indexed and `lastError` set to the
  /// reason the previous attempt failed (null on the first call).
  /// The loading splash uses this to paint a "Retrying… (2/3)"
  /// subtitle so users don't think the app is frozen.
  static Future<void> execute({
    required MainProvider mainProvider,
    int maxAttempts = _kDefaultMaxAttempts,
    Duration timeoutPerAttempt = _kDefaultTimeout,
    void Function(int attempt, Object? lastError)? onAttempt,
  }) async {
    final version = mainProvider.currentVersion.toLowerCase();
    final path = 'assets/$version.json';

    Object? lastError;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      onAttempt?.call(attempt, lastError);
      // 2026-06-12 (v1.3.67): ESCALATING timeout — 1× on attempt 1,
      // 2× on attempt 2, 3× on attempt 3 (20 s / 40 s / 60 s with the
      // defaults). Field report (ErrorReporter, iPhone Safari on
      // cellular, zh-Hans → cuvs-yhwh ≈ 1.4 MB brotli): a slow-but-
      // healthy connection can't finish the download inside a flat
      // 20 s, and because each retry EVICTS the asset cache and
      // restarts the fetch from byte 0, retrying made it strictly
      // worse — boot could never succeed below ~70 KB/s. Attempt 1
      // stays short so genuinely-hung fetches (the v1.2.12 memoised-
      // future bug class) are still detected fast; later attempts give
      // slow links the runway to complete one full download
      // (~31 KB/s ≈ 250 kbps suffices by attempt 3).
      final attemptTimeout = timeoutPerAttempt * attempt;
      try {
        if (attempt > 1) {
          // Cache-bust the paragraph map between attempts. If the
          // FIRST load returned a partial-or-corrupt copy, leaving
          // it cached would poison every subsequent retry.
          clearParagraphCache();
          // 2026-05-10 (v1.2.12): ALSO evict `rootBundle`'s
          // per-asset cache. This is the part v1.2.10 missed —
          // Flutter web memoises the in-flight Future for each
          // loaded asset, so re-calling `loadString(path)`
          // without an evict just re-awaits the same already-
          // failed promise instead of starting a fresh
          // service-worker fetch. Without this, "3 retries"
          // was effectively 1 try. `evict` is the per-key
          // operation; the bare `clear()` would nuke every
          // bundle entry which is overkill (e.g. icon assets
          // already loaded successfully would have to refetch).
          rootBundle.evict(_kOldTestamentParagraphRefPath);
          rootBundle.evict(_kNewTestamentParagraphRefPath);
          rootBundle.evict(path);
          // Exponential-ish backoff: 600 ms after attempt 1,
          // 1500 ms after attempt 2. Slightly longer than v1.2.10
          // so the SW has more breathing room to recover from a
          // transient blip.
          final backoffMs = 600 * (1 << (attempt - 2));
          await Future<void>.delayed(Duration(milliseconds: backoffMs));
        }
        // 2026-07-31 (v1.3.147): the paragraph-map load and the verse
        // fetch are two INDEPENDENT network round-trips (see
        // `_fetchAndDecodeVerses`'s doc comment for the field report
        // this fixes) — run them concurrently under ONE shared
        // deadline instead of paying for both sequentially out of the
        // same per-attempt budget.
        final results = await Future.wait([
          _loadParagraphMap(),
          _fetchAndDecodeVerses(path),
        ]).timeout(attemptTimeout);
        final paraMap = results[0] as Map<String, Map<String, _ParaInfo>>;
        final rawVerses = results[1] as List<Verse>;
        final verses = _enrichWithParagraphs(rawVerses, paraMap);
        // 2026-06-14 (v1.3.73): stale-switch guard. `version` was read
        // from `currentVersion` at the top of execute(); the parse above
        // is async, so a user who switches versions AGAIN before it
        // finishes will have moved `currentVersion` on. Committing this
        // (now stale) list would (a) show the old version's text under
        // the new version's header, and (b) WORSE — `setVerses` caches
        // the list under the CURRENT `currentVersion` key, poisoning the
        // per-version LRU so the wrong text persists on later switches
        // too (the user's "switching doesn't really switch to the right
        // version"). Only commit when we're still the current version;
        // otherwise a newer execute()/useCachedVersion() owns the screen.
        if (mainProvider.currentVersion.toLowerCase() != version) {
          return; // superseded — discard silently.
        }
        mainProvider.setVerses(verses);
        return; // success — drop out of the retry loop.
      } catch (e, st) {
        lastError = e;
        debugPrint(
          'FetchVerses attempt $attempt/$maxAttempts failed for $path: '
          '$e\n$st',
        );
        // v1.3.22: only report after the FINAL attempt fails — earlier
        // attempts often recover on retry, so reporting per-attempt
        // would email about transient flakes that the retry then
        // healed.
        if (attempt == maxAttempts) {
          ErrorReporter.report(e, st,
              source: 'FetchVerses', extra: 'path=$path attempt=$attempt/$maxAttempts');
          // Round 56: rethrow instead of swallowing. The previous
          // "log + return" pattern made the Retry button on the
          // loading page useless — it would call execute(),
          // execute() would log the error to debugPrint and return
          // cleanly, the loading page would see verses still empty
          // and re-show the same error UI without telling the user
          // what actually failed. Propagating lets the caller
          // surface the real error message.
          rethrow;
        }
      }
    }
  }

  /// Wipe the cached paragraph map. Used by the Retry path on the
  /// loading page so a corrupt-on-first-load paragraph reference (a
  /// likely cause of "always-empty after retry" reports) can recover
  /// without a full page refresh.
  static void clearParagraphCache() {
    _paragraphMapCache = null;
  }

  /// 2026-05-10 (v1.2.15): parse a version's verse JSON into a
  /// `List<Verse>` WITHOUT touching any MainProvider state. Used by
  /// the post-boot background pre-loader to stash common alternative
  /// versions in MainProvider's LRU cache silently, so the user's
  /// next version-switch is usually a cache hit (and therefore
  /// instant — no overlay).
  ///
  /// Returns the parsed list on success or null on any failure
  /// (caller treats null as "skip — try a different version or just
  /// wait for the user to manually switch which gets the proper
  /// retry pipeline"). No retry / timeout — background work should
  /// not compete with foreground retries; if the network is bad
  /// enough to time out a 20 s asset load, the foreground manual
  /// switch will retry properly with overlay feedback.
  static Future<List<Verse>?> loadVerseList(String version) async {
    try {
      final path = 'assets/${version.toLowerCase()}.json';
      final results = await Future.wait([
        _loadParagraphMap(),
        _fetchAndDecodeVerses(path),
      ]);
      final paraMap = results[0] as Map<String, Map<String, _ParaInfo>>;
      final rawVerses = results[1] as List<Verse>;
      final list = _enrichWithParagraphs(rawVerses, paraMap);
      return list.isEmpty ? null : list;
    } catch (e, st) {
      debugPrint('Background loadVerseList($version) failed: $e\n$st');
      return null;
    }
  }

  /// 2026-07-31 (v1.3.147): split out of the former `_loadAndParse` so
  /// the network fetch + decode of the VERSE asset can run CONCURRENTLY
  /// with `_loadParagraphMap()`'s fetch of the two paragraph-reference
  /// assets, instead of strictly after it. The paragraph map is only
  /// consumed by `_enrichWithParagraphs` below — nothing here needs it.
  ///
  /// Field report: `TimeoutException — FetchVerses` reported after all
  /// 3 escalating attempts (20/40/60 s) genuinely exhausted on a slow
  /// mobile connection. `execute()` used to `await` this fetch AFTER
  /// already `await`-ing the full paragraph-map load, both under the
  /// SAME per-attempt timeout — so a slow attempt paid for two
  /// sequential network round-trips out of one budget (worst case ~2×
  /// the nominal timeout before either one even got a chance to be the
  /// one that's slow). Running them concurrently means the shared
  /// timeout only has to cover whichever one is slower, not both added
  /// together — roughly doubling the effective per-attempt budget for
  /// the same wall-clock wait the user already tolerates.
  static Future<List<Verse>> _fetchAndDecodeVerses(String path) async {
    final jsonString = await rootBundle.loadString(path);
    return decodeVerses(json.decode(jsonString));
  }

  /// The pure half of [_fetchAndDecodeVerses] — decoded JSON in, verses
  /// out, no I/O. Split out so a test can run the real asset through the
  /// real parser instead of restating what the parser is supposed to do.
  @visibleForTesting
  static List<Verse> decodeVerses(dynamic decoded) {
    List<Map<String, dynamic>> rawList;
    if (decoded is List) {
      rawList = List<Map<String, dynamic>>.from(decoded);
    } else if (decoded is Map<String, dynamic> && decoded['passages'] != null) {
      final passages = decoded['passages'] as Map<String, dynamic>;
      final bookName = decoded['abbreviation'] ?? decoded['book'] ?? '';
      rawList = passages.entries.map((e) {
        final parts = e.key.toString().split(':');
        return {
          'book': bookName,
          'chapter': parts.isNotEmpty ? parts[0] : '',
          'verse': parts.length > 1 ? parts[1] : '',
          'text': '${e.value ?? ''}\n',
        };
      }).toList();
    } else {
      throw Exception('Unsupported verse JSON format');
    }

    // 2026-08-10 (v1.4.37): keep the psalm superscriptions before the
    // non-numeric filter throws them away. `assets/leb.json` ships 116
    // rows with `verse: "title"` — the headings the LEB prints above
    // verse 1 ("A psalm of David at his fleeing from the presence of
    // Absalom, his son."). They are part of the text, but they are not
    // numbered verses, so the filter below dropped all 116 and the
    // reader silently showed less scripture than the asset carried.
    // They are attached to verse 1 rather than admitted to the list as
    // pseudo-verses: see `Verse.superscription` for why an id and a
    // number would both be wrong.
    final superscriptions = <String, String>{};
    for (final m in rawList) {
      if (m['verse']?.toString().trim().toLowerCase() != 'title') continue;
      final text = m['text']?.toString().trim() ?? '';
      if (text.isEmpty) continue;
      superscriptions['${m['book']}|${m['chapter']}'] = text;
    }

    // Filter out entries where verse is non-numeric
    rawList = rawList
        .where((m) => int.tryParse(m['verse']?.toString() ?? '') != null)
        .toList();

    // Map into Verse objects, skipping any parse errors
    final verses = <Verse>[];
    for (final m in rawList) {
      try {
        verses.add(Verse.fromJson(m));
      } catch (_) {}
    }

    if (superscriptions.isNotEmpty) {
      for (var i = 0; i < verses.length; i++) {
        final v = verses[i];
        if (v.verse != 1) continue;
        final s = superscriptions['${v.book}|${v.chapter}'];
        if (s != null) verses[i] = v.copyWith(superscription: s);
      }
    }
    return verses;
  }

  /// Apply shared paragraph metadata to every verse so all translations share
  /// the same paragraph structure, then sort into canonical order. We only
  /// override when a source has a meaningful flag; versions that already
  /// carry their own metadata keep theirs unless the shared source has a
  /// stronger signal. Pure CPU work — no I/O, so it isn't part of the
  /// timeout race in `execute()`.
  static List<Verse> _enrichWithParagraphs(
    List<Verse> verses,
    Map<String, Map<String, _ParaInfo>> paraMap,
  ) {
    final enriched = <Verse>[];
    for (final v in verses) {
      final bookEn = bookNameToEnglish[v.book] ?? v.book;
      final info = paraMap[bookEn]?['${v.chapter}:${v.verse}'];
      if (info == null) {
        enriched.add(v);
        continue;
      }
      final needsStart = info.isParagraphStart && !v.isParagraphStart;
      final needsType = info.paragraphType != 'inline' &&
          info.paragraphType != v.paragraphType;
      if (!needsStart && !needsType) {
        enriched.add(v);
      } else {
        enriched.add(v.copyWith(
          isParagraphStart: needsStart ? true : null,
          paragraphType: needsType ? info.paragraphType : null,
        ));
      }
    }

    // Sort in canonical order
    enriched.sort((a, b) {
      final ai = standardBookOrder.indexOf(bookNameToEnglish[a.book] ?? a.book);
      final bi = standardBookOrder.indexOf(bookNameToEnglish[b.book] ?? b.book);
      if (ai != bi) return ai.compareTo(bi);
      final c = a.chapter.compareTo(b.chapter);
      if (c != 0) return c;
      final v = a.verse.compareTo(b.verse);
      // 2026-09-02: two entries can share a verse number — 路加福音 23:34
      // is printed in halves (34a, then 34b labelled plain "34"). Dart's
      // sort is not stable, so a comparator that returns 0 here leaves
      // their order undefined. See Verse.subVerseOrder.
      return v != 0 ? v : a.subVerseOrder.compareTo(b.subVerseOrder);
    });

    return enriched;
  }
}
