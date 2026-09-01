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
import 'package:yswords/services/error_reporter.dart';
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

/// URL-routing Stage 2 (docs/url-routing-plan.md §6 batch 1): paths
/// registered in main.dart's `getPages` table. Set once via
/// [setKnownRoutes] at boot. A route name in here means GetX's named
/// push already wrote the correct path to the URL directly — the
/// Bible-position correction below must stay out of its way.
Set<String> _knownRoutes = {};

void setKnownRoutes(Set<String> routeNames) {
  _knownRoutes = routeNames;
}

/// The route currently on top of the Navigator stack, as reported by
/// `main.dart`'s `_UrlRestoreObserver` — null means the Bible reader (or
/// any other page pushed the old, unnamed way; see §2's "72 call sites
/// untouched by Stage 2").
String? _currentRouteName;

/// URL-routing Stage 2: fired by `main.dart` on `popstate` when the
/// browser navigated away from a route in [_knownRoutes]. See
/// `UrlSyncService.setPopRouteCallback`.
void Function()? _popRouteCallback;

void setPopRouteCallback(void Function() cb) {
  _popRouteCallback = cb;
}

/// URL-routing Stage 2: fired once, at boot, when the captured boot
/// hash names a path in [_knownRoutes] (e.g. opening `/#/about`
/// directly) rather than a Bible reference. `_applyHashToState` would
/// silently no-op on a hash like this anyway (`_parseHash` only
/// understands the Bible grammar), so cold-loading a registered route
/// needs its own boot path — this is it. Same latch shape as the
/// existing `_bootDeepLinkCallback`/`_bootDeepLinkApplied` pair:
/// whichever of "the boot check ran" and "the callback got registered"
/// happens second fires the navigation.
void Function(String routeName)? _bootRouteCallback;
bool _bootRouteApplied = false;
String? _pendingBootRoute;

void setBootRouteCallback(void Function(String routeName) cb) {
  _bootRouteCallback = cb;
  if (_bootRouteApplied && _pendingBootRoute != null) {
    final route = _pendingBootRoute!;
    Timer.run(() => cb(route));
  }
}

/// Strips a raw location hash down to its path (no leading `#`, no
/// query string), or null for an empty/root hash. Deliberately
/// separate from `_parseHash`, which is Bible-grammar-specific and
/// stays untouched per docs/url-routing-plan.md §1.
String? _hashToPath(String rawHash) {
  var h = rawHash.startsWith('#') ? rawHash.substring(1) : rawHash;
  final qIdx = h.indexOf('?');
  if (qIdx >= 0) h = h.substring(0, qIdx);
  if (h.isEmpty || h == '/') return null;
  return h.startsWith('/') ? h : '/$h';
}

/// Restore the canonical hash after a navigator push/pop. The engine
/// writes the pushed route's minified name into the fragment
/// (`#/minified:Xt`); 350 ms later we put the share link back. The
/// `_lastWrittenUrl = null` reset forces the write even though our
/// state hasn't changed since the last one.
///
/// 2026-09-01 (URL-routing Stage 2): `routeName` is the route now on
/// top (see `UrlSyncService.onRouteChanged`'s doc). When it's a
/// registered route, GetX's named push already wrote `#<routeName>`
/// directly — the correction below would clobber that back to the
/// current Bible position, which is the exact "two histories" bug
/// docs/url-routing-plan.md §5 traces. Skip it entirely for those
/// routes; every other page (§2's other ~72 call sites) is untouched.
void onRouteChanged({String? routeName}) {
  if (!_initialized) return;
  _currentRouteName = routeName;
  if (routeName != null && _knownRoutes.contains(routeName)) return;
  Timer(const Duration(milliseconds: 350), () {
    if (_isApplyingFromUrl) return;
    // The route on top may have changed again since this timer was
    // scheduled (e.g. a fast push-then-pop); re-check rather than
    // trusting the closed-over `routeName`.
    if (_currentRouteName != null &&
        _knownRoutes.contains(_currentRouteName)) {
      return;
    }
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
    // URL-routing Stage 2: a boot hash naming a registered route
    // (`/about`, `/highlights`) is not Bible grammar at all — hand it
    // to the boot-route callback instead of the Bible apply path,
    // which would just silently no-op on it.
    final bootPath = _hashToPath(bootHash);
    if (bootPath != null && _knownRoutes.contains(bootPath)) {
      _bootRouteApplied = true;
      _pendingBootRoute = bootPath;
      _currentRouteName = bootPath;
      final cb = _bootRouteCallback;
      if (cb != null) Timer.run(() => cb(bootPath));
    } else {
      await _applyHashToState(bootHash, isBoot: true);
    }
  } catch (e, st) {
    debugPrint('[UrlSync] boot apply failed: $e\n$st');
    // 2026-09-01: this catch previously only reported through
    // debugPrint, which is a global no-op in release web
    // (main.dart:55-57) — a real throw here was indistinguishable
    // from a clean boot to any diagnostic tool that isn't attached
    // to a debug build. See docs/autonomous-queue.md's boot-crash item.
    ErrorReporter.report(e, st, source: 'UrlSync.boot');
  }

  // (B) Listen for browser back/forward so popstate drives state.
  try {
    _window.addEventListener('popstate', ((JSAny? event) {
      // URL-routing Stage 2: if a registered route (e.g. `/about`) was
      // on top when this fired, the browser just navigated AWAY from
      // it, but the Flutter Navigator stack never heard `popstate` —
      // docs/url-routing-plan.md §5's "two stacks of the same length,
      // different content." Pop the Flutter route to match instead of
      // treating this as a Bible-hash change; the URL already reflects
      // where the browser went.
      final leavingRegisteredRoute =
          _currentRouteName != null && _knownRoutes.contains(_currentRouteName);
      if (leavingRegisteredRoute) {
        _currentRouteName = null;
        _popRouteCallback?.call();
        return;
      }
      _applyHashToState(_window.location.hash)
          .catchError((Object e, StackTrace st) {
        debugPrint('[UrlSync] popstate apply failed: $e');
        ErrorReporter.report(e, st, source: 'UrlSync.popstate');
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
  // URL-routing Stage 2: the single guard both callers (the debounced
  // `_onMpChange` listener AND `onRouteChanged`'s 350ms correction) rely
  // on. Without it, a registered route's URL survived `onRouteChanged`
  // only to be clobbered moments later by an ordinary MainProvider
  // change firing `_onMpChange` — e.g. the boot-time provider setup
  // that runs regardless of which route the boot hash named. Found by
  // testing a cold `/#/about` load against a real web build: the
  // address bar landed back on the default Bible position, because
  // `_onMpChange` had no equivalent check at all.
  if (_currentRouteName != null && _knownRoutes.contains(_currentRouteName)) {
    return;
  }
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
