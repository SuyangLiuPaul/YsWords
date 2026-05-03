# Round 51 — UX polish fixes

> Last updated: 2026-05-04

This document captures a batch of small-but-irritating UX bugs reported
by the user in round 51, the root causes, and the fixes shipped. Each
section is reasonably self-contained so a future operator can revisit
any one symptom without re-deriving the full context.

---

## 1. Tapping a highlight / bookmark / note / search-result lands at the top of the chapter, not at the verse

### Symptom

Open Library → Notes / Bookmarks / Highlights → tap a row → the reader
opens but at the top of the chapter, not scrolled to the cited verse.
Same UX bug from the global search page when tapping a verse result.

### Root cause

Five separate sites used the same fragile pattern — call
`mp.setCurrentChapter(...)`, then push the route, then schedule a
`Future.delayed(Duration(milliseconds: 300), () { mp.jumpToIndex(idx);
mp.setHighlightIndex(idx); })`.

300 ms was chosen as "long enough for the bible reader to mount and the
ScrollablePositionedList controller to attach". On warm reload that's
true, but on cold start, after a Bible-version switch (which forces
`FetchVerses.execute`), or on slower devices, 300 ms wasn't enough — the
controller hadn't attached, `jumpToIndex` silently no-op'd, and the user
was left at item 0.

The bible reader already had a "pendingJump" handshake that solved this
elsewhere (round 47, evidence/news/library jump fixes). It pre-stages
the desired index in `MainProvider`, then the reader's post-frame
consumer in `bible_reading_pane.dart` drains it on the very first build
that has both controller-attached AND `verseToItemMap` populated. The
five sites above just hadn't been migrated to it.

### Fix

`lib/utils/jump_to_reference.dart` already had `resolveAndPrepareJump`
for parsed BibleReference inputs. Added a sibling
`prepareJumpToVerse(Verse v, MainProvider mp)` for sites that have a
concrete `Verse` (no parsing needed):

```dart
void prepareJumpToVerse(Verse verse, MainProvider mp) {
  mp.setCurrentChapter(book: verse.book, chapter: verse.chapter);
  mp.updateCurrentVerse(verse: verse);
  final chapterVerses = mp.verses
      .where((v) => v.book == verse.book && v.chapter == verse.chapter)
      .toList()
    ..sort((a, b) => a.verse.compareTo(b.verse));
  final relIdx = chapterVerses.indexWhere((v) => v.verse == verse.verse);
  if (relIdx >= 0) mp.setPendingJump(chapterVerseIndex: relIdx);
}
```

All five sites now call it instead of the `Future.delayed` pattern:

| Site | File | Before | After |
|---|---|---|---|
| Highlights page row tap | `lib/pages/highlights_page.dart` | 19-line fragile pattern | 1 call |
| Library Notes/Bookmarks tap | `lib/pages/library_page.dart` `_navigateToVerse` | 18 lines | 1 call |
| Search list tap | `lib/pages/search_page.dart` `onTap:` | inlined 30 lines | 1 call |
| Search concordance handler | `lib/pages/search_page.dart` 800-block | 14 lines | 1 call |
| Search reference handler | `lib/pages/search_page.dart` 843-block | 13 lines | 1 call |
| Bible-pane cross-reference jump | `lib/widgets/bible_reading_pane.dart` `_navigateToBibleReference` | 10 lines | 1 call |

Six sites total (including the bible-pane one). All now use the same
handshake the rest of the app uses. `Future.delayed`-based jump is
fully retired from the codebase.

---

## 2. Opening split view scrolls the top pane back to the top

### Symptom

User is reading e.g. Romans 8 in the primary pane, scrolled halfway
through. Tap the menu's "Open Split View". The split appears, but the
**primary pane** snaps back to Romans 8:1. Bad experience —
discontinuous reading.

### Root cause

Flutter's element tree preserves the `BibleReadingPane` State across
the layout switch (we already had `key: const ValueKey('primary')`),
but the inner `ScrollablePositionedList` widget gets disposed and
recreated when its parent's layout structure changes (single-pane vs
side-by-side / top-bottom places it under a different ancestor). Each
time the SPL mounts, it consults its `initialScrollIndex` parameter to
choose the starting position. We weren't passing one, so SPL defaulted
to `0` and slammed back to the top.

### Fix

`_BibleReadingPaneState` already tracked the visible index via
`_attachPositionsListener` → `_visibleItemIndex`. Pass that value as
`initialScrollIndex` on the SPL widget:

```dart
ScrollablePositionedList.builder(
  // …
  initialScrollIndex: _visibleItemIndex,
)
```

Now when the SPL is recreated (layout change), it mounts at the index
the user was last looking at, instead of `0`. Cost: one int passed per
build; correctness: total. No state migration, no extra controller.

`_visibleItemIndex` is updated on every scroll movement via
`itemPositionsListener`, so it's always current.

---

## 3. Sermon scroll position not preserved + no progress indicator

### Symptom

Open a sermon, read a few paragraphs, navigate away. Come back later
→ sermon opens at the top, no way to know where you were. Also no
visible scrollbar to gauge length / progress through the sermon.

### Root cause

`SermonDetailPage` used a default `ListView` with no controller, no
scrollbar, no persistence. The user's reading position was lost the
moment they navigated away.

### Fix

Three pieces, all in `lib/pages/sermon_detail_page.dart`:

1. **Persistent scroll position**. Added a `ScrollController`
   `_scrollController` to the State, wired to the `ListView`. On every
   scroll change, debounce 600 ms and write the offset to
   `SharedPreferences` under key
   `sermonScroll:<sermonId>:<lang>`. On body load (and on language
   switch), wait one frame for the ListView to lay out, then read the
   saved offset and `jumpTo` it.

   Per-language storage matters because body lengths differ between
   English, 简体, 繁體 — a raw offset that's halfway through the
   English would be near the start of the (slightly longer) Chinese.
   Storing them separately also lets the user toggle freely between
   languages without losing position in either.

2. **Always-visible scrollbar**. Wrapped the `ListView` in
   `Scrollbar(controller: …, thumbVisibility: true, child: …)`. On
   web, Flutter's default scrollbar is hover-only — `thumbVisibility:
   true` keeps the thumb on screen even at rest, matching the user
   request "there should be a bar at the right and when I read
   through".

3. **Reading-progress strip in the AppBar**. A 2-pixel
   `LinearProgressIndicator` whose `value` is the current scroll
   fraction (`pixels / maxScrollExtent`, clamped to 0..1). Hidden until
   the user actually scrolls (so it doesn't show "0%" on bodies short
   enough not to scroll), and updated live as they read.

### Implementation notes

- `_onScroll` debounces SharedPreferences writes with `Timer(600 ms)`
  so we don't hammer disk on every fling-frame.
- `dispose()` flushes the pending write synchronously — no risk of
  losing state if the user backs out very quickly.
- The restore step compares saved offset against the current
  `maxScrollExtent` and clamps. Prevents jumping past EOF if the body
  has been shortened (e.g. after a re-ingestion).
- Saved offsets below 24 px are wiped, not stored — gives the user a
  trivial "reset" gesture (scroll to top to forget the resume point).

---

## 4. Console-spam fix: 198 "preloaded but not used" warnings

### Symptom

Devtools console showed ~198 yellow warnings every page load:

```
The resource <URL> was preloaded using link preload but not used
within a few seconds from the window's load event.
```

### Root cause

`web/index.html` had `<link rel="preload" href="assets/kjv.json"
as="fetch">` and similar tags for several JSON files, fonts, and
images. **Flutter web fetches bundled assets from
`assets/assets/<file>`** — the user-facing `assets/` directory gets
nested under Flutter's own `assets/` URL prefix in the build output. So
the preloads pointed at the WRONG URLs. Browser dutifully fetched them
eagerly, Flutter's loader fetched the *correct* paths separately, the
preloads were never used → one warning per tag.

### Fix

Removed all preload tags from `web/index.html`. Flutter handles asset
fetching via its own pipeline; the service worker caches everything
after first visit; no functional impact, just cleaner devtools.

If we ever want to re-add preloads we'd have to point them at
`assets/assets/...` (with the doubled prefix) — but it's almost never
worth the maintenance overhead since Flutter's asset cache is already
optimal.

---

## 5. Console-spam: `firestore.googleapis.com ERR_BLOCKED_BY_CLIENT`

### Symptom

Long Firestore retry-spam stack traces in the console.

### Root cause (NOT a bug in our code)

The user's browser has an ad-blocker / privacy extension blocking
`firestore.googleapis.com`. Many privacy lists (uBlock Origin's
defaults, Brave Shields, DDG, Ghostery) categorise Firestore as Google
tracking and block it. Once blocked, the Firestore SDK retries every
few seconds with exponential backoff, generating spam.

### Mitigation

The app already detects `webExperimentalAutoDetectLongPolling: true`
in init and degrades to local-only mode gracefully. The retry-spam
itself comes from the Firestore SDK internals and can't be silenced
without forking the SDK.

User-side workarounds:
- Disable the extension for `yswords.netlify.app`
- Whitelist `firestore.googleapis.com`
- Use a different browser
- Accept the noise

The app remains fully functional in local-only mode — only cloud sync
(highlights, bookmarks, profiles) is affected.

---

## 6. Strong's G4630 — proper-name etymology rendered as a description

### Symptom

User taps Σκευᾶς (Sceva) in Acts 19:14. Strong's panel shows English
gloss "left-handed". Confusing — Sceva isn't a left-handed person, the
gloss is the *etymology* of the name (Σκευᾶς from σκεῦος / vessel,
adjectivally "ready"/"left-handed").

### Status

This is a **property of the bundled Strong's lexicon** (openscriptures),
not a rendering bug. Strong's is consistent: for proper names, it gives
the etymological gloss because that's what a 19th-century concordance
does. Modern Bible-study tools (Logos, Accordance) lean on BDAG /
Thayer's for richer name entries, but those are commercial datasets.

The Chinese gloss for G4630 is actually contextual ("一个祭司长, 住在
以弗所" — a chief priest in Ephesus) which IS more useful for readers,
but mixing two gloss strategies in the same panel would be more
confusing than helpful. **Documented; not changed.**

If we ever swap in a richer lexicon, the model layer
(`lib/models/strongs.dart`) already has the right shape — only the
underlying JSON would need updating.

---

## Round 51 commit summary

| Commit | Subject |
|---|---|
| `f8847a9` | fix(web): remove broken preload tags |
| (this round) | fix(jump): pendingJump handshake for highlights/library/search/cross-ref |
| (this round) | feat(reader): preserve scroll position across split-view toggle |
| (this round) | feat(sermons): persistent scroll position + progress bar |
| (this round) | docs: round-51 UX fixes catalogue |

All deployed to https://yswords.netlify.app via the same `netlify
deploy --prod` workflow described in HANDOFF.md.
