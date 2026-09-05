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

import 'package:yswords/constants/bible_versions.dart' show availableVersions;
import 'package:yswords/constants/book_slugs.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/error_reporter.dart';
import 'package:yswords/services/fetch_books.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/utils/route_paths.dart'
    show hashToRoutePath, matchesRegisteredRoute;
import 'package:yswords/utils/version_mapper.dart' show translateBookName;
import 'package:yswords/utils/log_diag.dart';

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
  // 2026-09-05: `pushState` is deliberately NOT declared any more. The
  // Bible reader's URL write is a REPLACE — see `_writeStateToUrl` for
  // the measured reason — and leaving the binding here is an invitation
  // to reintroduce the defect one autocomplete at a time.
  external void replaceState(JSAny? state, String unused, String url);

  /// The state object on the entry the browser is currently showing.
  ///
  /// Read only so it can be written straight back by
  /// [_writeStateToUrl]. The Flutter web engine TAGS its own history
  /// entries (`{'origin': true}` on the page's landing entry,
  /// `{'flutter': true}` on the one it keeps on top) and decides what a
  /// `popstate` means by reading that tag back. Passing the existing
  /// state through means this file never has to know the engine's
  /// private tag names and never destroys one.
  external JSAny? get state;
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
    logDiag('[UrlSync] captureBootHash failed: $e');
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

// 2026-09-03: `_popRouteCallback` / `setPopRouteCallback` used to live
// here. It popped the Flutter Navigator from this file's own `popstate`
// listener whenever a registered route was on top. It was the direct
// cause of "one Back skips a page and lands on the Dashboard", because
// the Flutter web engine ALREADY delivers that same Back as a pop. See
// the popstate listener below for the measured trace.

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
  if (routeName != null && matchesRegisteredRoute(routeName, _knownRoutes)) {
    return;
  }
  Timer(const Duration(milliseconds: 350), () {
    if (_isApplyingFromUrl) return;
    // The route on top may have changed again since this timer was
    // scheduled (e.g. a fast push-then-pop); re-check rather than
    // trusting the closed-over `routeName`.
    if (_currentRouteName != null &&
        matchesRegisteredRoute(_currentRouteName!, _knownRoutes)) {
      return;
    }
    _lastWrittenUrl = '';
    try {
      _writeStateToUrl();
    } catch (e) {
      logDiag('[UrlSync] route-change rewrite failed: $e');
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
    // URL-routing Stage 5: `hashToRoutePath` (moved here from a private
    // `_hashToPath` so it is testable off-web) now KEEPS the query
    // string. `/#/evidence?book=John&chapter=3` has to reach
    // `Get.toNamed` intact or the shared link silently drops its
    // filters and opens the unfiltered list; `matchesRegisteredRoute`
    // strips the query itself before matching, so the recognition step
    // is unaffected.
    final bootPath = hashToRoutePath(bootHash);
    if (bootPath != null && matchesRegisteredRoute(bootPath, _knownRoutes)) {
      _bootRouteApplied = true;
      _pendingBootRoute = bootPath;
      _currentRouteName = bootPath;
      final cb = _bootRouteCallback;
      if (cb != null) Timer.run(() => cb(bootPath));
    } else {
      await _applyHashToState(bootHash, isBoot: true);
    }
  } catch (e, st) {
    logDiag('[UrlSync] boot apply failed: $e\n$st');
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
      // 2026-09-03 — "one Back leaves the app". MEASURED against a real
      // release web build in headless Chrome, with `logDiag` probes in
      // this listener and in `_UrlRestoreObserver.didPop`. Opening
      // sermon 004 from `/#/sermons` and pressing Back ONCE printed, in
      // this order:
      //
      //   [PROBE] didPop popped=/sermons/004 -> now=/sermons
      //   [PROBE] popstate current=/sermons leavingRegistered=true
      //   [PROBE] popRouteCallback canPop=true
      //   [PROBE] didPop popped=/sermons -> now=/
      //
      // Two pops for one Back. The first one is not ours: Flutter's web
      // engine keeps its own history entry on top of the page's origin
      // entry (`SingleEntryBrowserHistory`), and its popstate handler
      // re-pushes that entry and sends the framework a `popRoute`
      // platform message, which `WidgetsApp.didPopRoute` turns into
      // `navigator.maybePop()`. That has already run by the time this
      // listener is called. The second pop was this listener calling
      // `_popRouteCallback` — and because the first pop had already
      // moved `_currentRouteName` on to the route BELOW, the
      // "am I leaving a registered route?" test still passed and popped
      // that one too. Hence: Back from a sermon landed on the Dashboard
      // with `/#/sermons` skipped, and 350 ms later the Bible writer
      // rewrote the address bar to a reference the reader never asked
      // for.
      //
      // So: do not pop here. The engine owns the Back gesture. All this
      // listener still has to do is stay out of the way when the route
      // on top is a registered one — running the Bible `_applyHashToState`
      // against a hash like `#/sermons` would be a no-op anyway
      // (`_parseHash` only knows book slugs), but returning early keeps
      // that explicit rather than accidental.
      final onRegisteredRoute = _currentRouteName != null &&
          matchesRegisteredRoute(_currentRouteName!, _knownRoutes);
      if (onRegisteredRoute) return;
      _applyHashToState(_window.location.hash)
          .catchError((Object e, StackTrace st) {
        logDiag('[UrlSync] popstate apply failed: $e');
        ErrorReporter.report(e, st, source: 'UrlSync.popstate');
      });
    }).toJS);
  } catch (e) {
    logDiag('[UrlSync] popstate wiring failed: $e');
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
      logDiag('[UrlSync] write failed: $e');
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
  if (_currentRouteName != null &&
      matchesRegisteredRoute(_currentRouteName!, _knownRoutes)) {
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
    // 2026-09-05: REPLACE, not push, and pass the current state object
    // straight back. This line used to be
    // `pushState(null, '', newHash)`, and that one word was the whole
    // of docs/autonomous-queue.md's "on the Bible reader, Back pushes a
    // route instead of popping".
    //
    // MEASURED in headless Chrome against a real release bundle
    // (v1.4.214), not reasoned from the source. Cold-open
    // `/#/micah/2?v=kjv`, tap Next Chapter twice, press Back ONCE:
    //
    //     popstate     #/micah/3:1?v=kjv     state=null
    //     popstate     #/micah/2?v=kjv       state=null
    //     popstate     #/HomePage            state={"flutter":true}
    //     replaceState /#/_unknown           state={"flutter":true}
    //     pushState    #/micah/2?v=kjv       state=null
    //
    // Three popstate events and `currentIndex` down by three, for one
    // Back. The mechanism is the engine's, and its source says so out
    // loud: `SingleEntryBrowserHistory.onPopState`'s last branch is
    // commented "The user has pushed a new entry on top of our flutter
    // entry… when the user modifies the hash part of the url directly".
    // A push with `state: null` is exactly that shape, so every chapter
    // turn armed the engine's manual-URL-edit RECOVERY path: it walks
    // `go(-1)` until it finds its own tagged entry, and then dispatches
    // **`pushRoute`** — which `WidgetsApp.didPopRoute`'s sibling turns
    // into `pushNamed`. `/micah/2?v=kjv` is not a registered name, so
    // GetX answered with `unknownRoute`: the `replaceState /#/_unknown`
    // on the fourth line is a PAGE BEING PUSHED by a press of Back.
    // Then the 350 ms route-change correction pushed from a non-tip
    // entry and discarded the three forward entries with it.
    //
    // Replacing fixes it at the root: the engine's `{'flutter': true}`
    // tag survives (hence reading `state` back rather than writing a
    // literal — the tag names are the engine's private business), the
    // app never creates an entry the engine does not own, and Back on
    // the reader becomes the ordinary one-pop `popRoute` every
    // GetX-routed page in this app already gets.
    //
    // What this gives up, and why it is not a loss: browser Back can no
    // longer walk chapter by chapter. It could not before either — the
    // trace above is what "walking back a chapter" actually did. Real
    // per-chapter browser entries need the Router API
    // (`GetMaterialApp.router` + `MultiEntriesBrowserHistory`), which is
    // its own queue item; and note the raw null-state push is wrong
    // under THAT mode too (`MultiEntriesBrowserHistory.onPopState`
    // serial-tags an unrecognised entry and dispatches
    // `pushRouteInformation`), so this is a prerequisite for the
    // migration rather than something it would absorb.
    //
    // The URL TEXT written is unchanged, character for character —
    // share links, `/read/` and `/sermons/` prerendered paths and their
    // sitemaps cannot be affected by a push/replace choice.
    //
    // End-to-end proof: `tools/web_verify_headless.mjs bible`, which
    // fails on the old code and passes on this one.
    _window.history.replaceState(_window.history.state, '', newHash);
    _lastWrittenUrl = newHash;
  } catch (e) {
    logDiag('[UrlSync] replaceState threw: $e');
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
        // 2026-09-02: `availableVersions`, not `bibleVersions` — on web
        // that excludes the editions whose assets release_web.sh strips
        // from the bundle. An old shared link like `#/john/3:16?v=nasb`
        // would otherwise switch to an edition whose JSON now 404s and
        // land the reader on an empty chapter; this keeps them on the
        // version they were already reading.
        availableVersions.any((v) => v.value == parsed.version)) {
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
      logDiag('[UrlSync] book/chapter not in ${mp.currentVersion}; '
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
        ..sort((a, b) {
          final n = a.verse.compareTo(b.verse);
          return n != 0 ? n : a.subVerseOrder.compareTo(b.subVerseOrder);
        });
      // With a sub-verse letter, match the label exactly. Without one,
      // match the number — and because the sort puts 34a before 34b,
      // a bare `23:34` lands on the first half, which is where verse 34
      // begins.
      final relIdx = parsed.verseLabel != null
          ? chapterVerses.indexWhere((v) => v.verseLabel == parsed.verseLabel)
          : chapterVerses.indexWhere((v) => v.verse == parsed.verse);
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

  /// Set only when the URL carried a sub-verse letter (`23:34a`). Null
  /// for an ordinary `23:34`, which must keep matching on the number so
  /// that a link written before the split still resolves.
  final String? verseLabel;
  final String? version;
  const _ParsedHash({
    required this.book,
    required this.chapter,
    this.verse,
    this.verseLabel,
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
  String? verseLabel;
  if (segments.length >= 2) {
    final chapterSeg = segments[1];
    // chapter or chapter:verse
    final colon = chapterSeg.indexOf(':');
    if (colon > 0) {
      chapter = int.tryParse(chapterSeg.substring(0, colon)) ?? 1;
      // 2026-09-02: a verse can carry a sub-verse letter — 梁家鏗譯本
      // prints 路加福音 23:34 in halves, so `/luke/23:34a` is a real
      // reference. `int.tryParse` alone returned null for it and the
      // link silently degraded to the whole chapter. Split the digits
      // from the suffix: the number still drives everything numeric,
      // and the label (kept only when a suffix is actually present)
      // picks the right half out of the two that share the number.
      final raw = chapterSeg.substring(colon + 1);
      final m = RegExp(r'^(\d+)([a-z])?$', caseSensitive: false).firstMatch(raw);
      if (m != null) {
        verse = int.tryParse(m.group(1)!);
        if (m.group(2) != null) verseLabel = '${m.group(1)}${m.group(2)!.toLowerCase()}';
      }
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
    verseLabel: verseLabel,
    version: version,
  );
}
