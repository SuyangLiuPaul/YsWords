// Web implementation of `UrlSyncService`. Reads the boot URL hash,
// applies it to providers, then keeps the URL in lockstep with the
// MainProvider state for the rest of the session.
//
// URL format (hash-based, no server config needed):
//
//   /#/                         → dashboard / default
//   /#/<bookSlug>               → that book, chapter 1
//   /#/<bookSlug>/<chapter>     → that book + chapter
//   /#/<bookSlug>/<chapter>:<verse>
//                               → book + chapter + scroll-to-verse
//   /#/<bookSlug>/...?v=<version>
//                               → also switches the active translation
//
// Book slugs are defined in `lib/constants/book_slugs.dart`; the
// reverse map accepts common short aliases (`gen`, `rev`, `1sam`,
// …) so shared / hand-typed URLs that aren't fully canonical
// still resolve.
//
// Two-direction sync:
//
//   (A) URL → state (cold deep links + browser back/forward).
//       Triggered by `urlSyncInit` at boot and by the `popstate`
//       event afterwards.
//
//   (B) state → URL (user navigates inside the app).
//       MainProvider listener; debounced 150 ms so a rapid
//       `setCurrentChapter + updateCurrentVerse + setPendingJump`
//       burst (the search-jump pattern) writes ONE URL entry, not
//       three.
//
// A `_isApplyingFromUrl` flag short-circuits the listener while
// we're in the middle of applying a URL change so the two paths
// don't fight each other.

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'package:yswords/constants/bible_versions.dart' show bibleVersions;
import 'package:yswords/constants/book_slugs.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_books.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/utils/version_mapper.dart' show translateBookName;

// ── JS interop bindings ─────────────────────────────────────────

@JS('window')
external _Window get _window;

@JS()
@staticInterop
class _Window {}

extension on _Window {
  external _Location get location;
  external _History get history;
  external void addEventListener(String type, JSFunction listener);
}

@JS()
@staticInterop
class _Location {}

extension on _Location {
  external String get hash;
}

@JS()
@staticInterop
class _History {}

extension on _History {
  external void pushState(JSAny? state, String unused, String url);
}

// ── Module-level state ──────────────────────────────────────────

bool _initialized = false;

/// Deep-link hash captured at the very start of `main()`, before the
/// Flutter engine can overwrite the URL with the initial route. See
/// `UrlSyncService.captureBootHash`.
String? _bootHash;

/// Snapshot the current hash. Must run synchronously in `main()`
/// before `runApp` — by first frame the engine may already have
/// rewritten the fragment.
void captureBootHash() {
  try {
    _bootHash = _window.location.hash;
  } catch (e) {
    debugPrint('[UrlSync] captureBootHash failed: $e');
  }
}

/// Fired once after a boot deep link is applied. See
/// `UrlSyncService.setBootDeepLinkCallback`.
void Function()? _bootDeepLinkCallback;

/// Latch: true once a boot deep link has been applied. Decouples the
/// apply (which happens deep in async bootstrap) from callback
/// registration (which happens when _RootRouter first mounts). Either
/// can win the race — whichever is second fires the navigation.
bool _bootDeepLinkApplied = false;

void setBootDeepLinkCallback(void Function() cb) {
  _bootDeepLinkCallback = cb;
  // If the apply already happened before the router mounted, fire now
  // so the late registration isn't dropped.
  if (_bootDeepLinkApplied) {
    Timer.run(cb);
  }
}

/// Restore the canonical hash after a navigator push/pop. The engine
/// writes the pushed route's minified name into the fragment
/// (`#/minified:Xt`); 350 ms later we put the share link back. The
/// `_lastWrittenUrl = null` reset forces the write even though our
/// state hasn't changed since the last one.
void onRouteChanged() {
  if (!_initialized) return;
  Timer(const Duration(milliseconds: 350), () {
    if (_isApplyingFromUrl) return;
    _lastWrittenUrl = '';
    try {
      _writeStateToUrl();
    } catch (e) {
      debugPrint('[UrlSync] route-change rewrite failed: $e');
    }
  });
}
bool _isApplyingFromUrl = false;
Timer? _writeDebounce;
String _lastWrittenUrl = '';
MainProvider? _mp;

// ── Public init ─────────────────────────────────────────────────

Future<void> urlSyncInit({
  required MainProvider mainProvider,
  required AppSettings appSettings,
}) async {
  // `appSettings` is part of the public API for future extensions
  // (e.g. respecting a "disable URL sync" toggle) — currently
  // unused, suppress the analyzer warning explicitly.
  // ignore: unused_local_variable
  final _ = appSettings;
  if (_initialized) return;
  _initialized = true;
  _mp = mainProvider;

  // (A) URL → state on boot. Best-effort — if the URL is empty,
  // malformed, or points to an unknown book, the existing
  // restoreState() output stays in effect.
  //
  // 2026-06-11 (v1.3.61): prefer the hash captured in main() over the
  // live one. The Flutter web engine reports the initial route ('/')
  // shortly after first frame and overwrites the fragment, so by the
  // time this init runs (post-restoreState) the live hash no longer
  // holds the deep link the user actually opened.
  try {
    final liveHash = _window.location.hash;
    final bootHash = (_bootHash != null && _bootHash!.length > 1)
        ? _bootHash!
        : liveHash;
    await _applyHashToState(bootHash, isBoot: true);
  } catch (e, st) {
    debugPrint('[UrlSync] boot apply failed: $e\n$st');
  }

  // (B) Listen for browser back/forward so popstate drives state.
  try {
    _window.addEventListener('popstate', ((JSAny? event) {
      _applyHashToState(_window.location.hash).catchError((Object e) {
        debugPrint('[UrlSync] popstate apply failed: $e');
      });
    }).toJS);
  } catch (e) {
    debugPrint('[UrlSync] popstate wiring failed: $e');
  }

  // (B) MainProvider listener — debounced 150 ms.
  mainProvider.addListener(_onMpChange);
}

// ── Listener: state → URL ──────────────────────────────────────

void _onMpChange() {
  if (_isApplyingFromUrl) return;
  _writeDebounce?.cancel();
  _writeDebounce = Timer(const Duration(milliseconds: 150), () {
    _writeDebounce = null;
    try {
      _writeStateToUrl();
    } catch (e) {
      debugPrint('[UrlSync] write failed: $e');
    }
  });
}

void _writeStateToUrl() {
  final mp = _mp;
  if (mp == null) return;
  final localBook = mp.currentBook;
  final chapter = mp.currentChapter;
  if (localBook == null || chapter == null) return;
  // Translate the locale-specific book name back to canonical
  // English so the URL slug works across translations.
  final englishBook = bookNameToEnglish[localBook] ?? localBook;
  final slug = slugForBook(englishBook);
  if (slug == null) return;

  // Optionally append `:verse` when the user has a specific
  // currentVerse set AND the verse is in the current chapter.
  final currentVerse = mp.currentVerse;
  String hashPath = '/$slug/$chapter';
  if (currentVerse != null &&
      currentVerse.chapter == chapter &&
      (bookNameToEnglish[currentVerse.book] ?? currentVerse.book) ==
          englishBook) {
    hashPath += ':${currentVerse.verseLabel}';
  }
  // Version is always part of the URL — sharing a link should
  // preserve translation choice.
  final newHash = '#$hashPath?v=${mp.currentVersion}';
  if (newHash == _lastWrittenUrl) return;
  try {
    _window.history.pushState(null, '', newHash);
    _lastWrittenUrl = newHash;
  } catch (e) {
    debugPrint('[UrlSync] pushState threw: $e');
  }
}

// ── Apply: URL → state ─────────────────────────────────────────

Future<void> _applyHashToState(String rawHash, {bool isBoot = false}) async {
  final parsed = _parseHash(rawHash);
  if (parsed == null) return;
  final mp = _mp;
  if (mp == null) return;

  _isApplyingFromUrl = true;
  try {
    // 2026-06-11 (v1.3.61): version swap FIRST — the book-name
    // translation and the existence check below must run against the
    // version the LINK points at, not whatever the boot default
    // happened to be. Pre-fix order translated against the default
    // version: a fresh en-locale browser booted NASB, so
    // `translateBookName('Revelation', 'nasb')` returned the ENGLISH
    // name, then the swap loaded biblexg-v2 (books named 启示录) and
    // `setCurrentChapter(book: 'Revelation')` found no verses — a
    // shared link like `#/revelation/17:1?v=biblexg-v2` cold-opened
    // to the "End of Bible" empty state on a chapter that exists.
    if (parsed.version != null &&
        parsed.version != mp.currentVersion &&
        bibleVersions.any((v) => v.value == parsed.version)) {
      mp.setVersion(parsed.version!);
      await FetchVerses.execute(mainProvider: mp);
      // v1.3.61: the chapter pager + book picker resolve book names
      // against `mp.books`, which boot built from the DEFAULT version.
      // The canonical in-app switch (reading pane version menu) runs
      // FetchBooks after FetchVerses — without it, a Chinese-named
      // currentBook can't be found in an English book list and every
      // reader page renders the "End of Bible" empty state.
      await FetchBooks.execute(mainProvider: mp);
    }

    // Now translate + verify against the version that is actually
    // loaded. If the (book, chapter) doesn't exist in it (e.g. an OT
    // link into an NT-only version), bail — the reader stays where
    // restoreState put it, in the link's version, and the v1.3.12
    // version-gap UI explains the rest.
    final localBook = translateBookName(parsed.book, mp.currentVersion);
    final hasVerse = mp.verses.any((v) =>
        (bookNameToEnglish[v.book] ?? v.book) == parsed.book &&
        v.chapter == parsed.chapter);
    if (!hasVerse) {
      debugPrint('[UrlSync] book/chapter not in ${mp.currentVersion}; '
          'skipping apply (${parsed.book} ${parsed.chapter})');
      return;
    }

    mp.setCurrentChapter(book: localBook, chapter: parsed.chapter);
    // v1.3.62 UX: a successfully-applied BOOT deep link should land
    // the user in the reader, not on the Dashboard. Fire the
    // registered callback (main.dart navigates on its next frame).
    if (isBoot) {
      _bootDeepLinkApplied = true;
      final cb = _bootDeepLinkCallback;
      if (cb != null) {
        Timer.run(cb);
      }
    }
    // Optional verse jump.
    if (parsed.verse != null) {
      final chapterVerses = mp.verses
          .where((v) =>
              (bookNameToEnglish[v.book] ?? v.book) == parsed.book &&
              v.chapter == parsed.chapter)
          .toList()
        ..sort((a, b) => a.verse.compareTo(b.verse));
      final relIdx = chapterVerses
          .indexWhere((v) => v.verse == parsed.verse);
      if (relIdx >= 0) {
        mp.updateCurrentVerse(verse: chapterVerses[relIdx]);
        mp.setPendingJump(chapterVerseIndex: relIdx);
      }
    }
  } finally {
    _isApplyingFromUrl = false;
    // Don't immediately re-write the URL — let the next legitimate
    // state change debounce + write it.
    _lastWrittenUrl = '#$rawHash'.replaceFirst(RegExp(r'^##'), '#');
  }
}

// ── Parsing ─────────────────────────────────────────────────────

class _ParsedHash {
  final String book; // canonical English
  final int chapter;
  final int? verse;
  final String? version;
  const _ParsedHash({
    required this.book,
    required this.chapter,
    this.verse,
    this.version,
  });
}

_ParsedHash? _parseHash(String rawHash) {
  // Trim leading `#`. Empty hash → dashboard, skip.
  var h = rawHash.startsWith('#') ? rawHash.substring(1) : rawHash;
  if (h.isEmpty || h == '/') return null;

  // Split optional query string.
  String pathPart = h;
  String queryPart = '';
  final qIdx = h.indexOf('?');
  if (qIdx >= 0) {
    pathPart = h.substring(0, qIdx);
    queryPart = h.substring(qIdx + 1);
  }
  // Strip leading `/`.
  if (pathPart.startsWith('/')) pathPart = pathPart.substring(1);
  if (pathPart.isEmpty) return null;

  // Path segments — book / chapter[:verse].
  final segments = pathPart.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  final bookSlug = segments[0];
  final englishBook = bookForSlug(bookSlug);
  if (englishBook == null) return null;

  int chapter = 1;
  int? verse;
  if (segments.length >= 2) {
    final chapterSeg = segments[1];
    // chapter or chapter:verse
    final colon = chapterSeg.indexOf(':');
    if (colon > 0) {
      chapter = int.tryParse(chapterSeg.substring(0, colon)) ?? 1;
      verse = int.tryParse(chapterSeg.substring(colon + 1));
    } else {
      chapter = int.tryParse(chapterSeg) ?? 1;
    }
  }

  // Parse query (?v=<version>&...). Only `v` is recognised today;
  // unknown keys are silently ignored.
  String? version;
  if (queryPart.isNotEmpty) {
    for (final kv in queryPart.split('&')) {
      final eq = kv.indexOf('=');
      if (eq <= 0) continue;
      final k = kv.substring(0, eq);
      final v = kv.substring(eq + 1);
      if (k == 'v') version = Uri.decodeComponent(v);
    }
  }

  return _ParsedHash(
    book: englishBook,
    chapter: chapter,
    verse: verse,
    version: version,
  );
}
