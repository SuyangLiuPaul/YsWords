# URL routing plan — Stage 1 (design only, no code)

Queue item: `docs/autonomous-queue.md` — "Only the Bible reader has a
URL. Every other page is unshareable, and Back does the wrong thing."
Approved to start 2026-08-17 ("loop加进去吧"). This document is **Stage
1 of 3** from that item's own sequence: decide the scheme on paper
before converting anything. It ships no routing code and adds no
dependency — see "Out of scope" at the end.

## 1. The existing Bible URL grammar — frozen, unchanged

Quoted verbatim from the header comment and `_parseHash` /
`_writeStateToUrl` in `lib/services/url_sync_service_web.dart`
(verified by reading, not by running — this codebase has no web
integration-test harness that exercises `history.pushState`):

```
/#/                         → dashboard / default
/#/<bookSlug>               → that book, chapter 1
/#/<bookSlug>/<chapter>     → that book + chapter
/#/<bookSlug>/<chapter>:<verse>
                             → book + chapter + scroll-to-verse
/#/<bookSlug>/...?v=<version>
                             → also switches the active translation
```

Confirmed against the actual parser (`_parseHash`, lines 346-403):

- Leading `#` and `/` are stripped; an empty or `/`-only hash returns
  `null` (→ dashboard, no book to apply).
- Path splits into segments; `segments[0]` is the book slug, resolved
  through `bookForSlug` (`book_slugs.dart`), which accepts aliases
  (`gen`, `rev`, `1sam`, …), not only canonical slugs.
- `segments[1]`, if present, is `chapter` or `chapter:verse` (colon
  split, both sides `int.tryParse`'d, defaulting chapter to 1 and verse
  to unset on a parse failure — a malformed segment degrades rather
  than throws).
- The query string is parsed key-by-key on `&`/`=`; only `v` is
  recognised, everything else is silently ignored (a forward-compatible
  choice — a later stage can add its own query keys without touching
  this parser).
- `_writeStateToUrl` (state → URL) always writes `?v=<version>` — a
  shared link is pinned to the translation the sharer was reading in,
  not the reader's default.

**This grammar keeps working unchanged.** `/#/john/3:16?v=cuvs-yhwh`
links already in circulation (the bug report that opened this item
quoted exactly one) must resolve exactly as they do today after every
later stage. No stage in this plan touches `_parseHash`,
`_applyHashToState`, or `_writeStateToUrl`'s path grammar; a later
stage may need to teach the *write* side to stay quiet while a
non-Bible page is on top (see §4), but the *read* grammar for Bible
links is out of scope permanently, not just for Stage 1.

## 2. Destination inventory — re-derived, not trusted from the queue

The queue item says "72 `pushPage` call sites." `NEXT_TASK.md` says "77
hits [...] 26 distinct destination classes" from "a crude regex over
the literal-widget call sites." Neither number survives a direct count,
so here is one, done three ways and cross-checked:

**Method.** `grep -rn "pushPage(" lib/ --include=*.dart` (76 files
searched), then a script matches the constructor name immediately after
each `pushPage(` (stripping an optional leading `const`). Separately,
`grep -rn "Get\.to\b\|Get\.toNamed\|Navigator\.push\|MaterialPageRoute"
lib/ --include=*.dart` finds every push that does **not** go through
`pushPage`, to check the coverage claim below.

**Result: 74 `pushPage(...)` call sites** (77 total hits on the string
`pushPage` includes the 1-line function definition in `app_nav.dart`
plus 2 doc-comment mentions elsewhere that are not calls), resolving to
**28 distinct widget classes**, all as literal constructors — no call
site passes a variable or a factory result, so every one is
staticically resolvable by grep, and none had to be marked "unknown."

**"`pushPage` is the only way pages are pushed" — checked, and false.**
Two call sites bypass it entirely, both using the raw Flutter API
directly:

- `lib/pages/song_score_page.dart:51` —
  `Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
  SongScorePage(...)))`
- `lib/pages/song_video_page.dart:56` — same pattern, `SongVideoPage`.

Grepping for every other bypass (`Get.to\b` with no `pushPage`
wrapper, `Get.toNamed`, and every other `Navigator.push*` /
`MaterialPageRoute`) turns up nothing further: `Get.toNamed` has zero
real call sites in `lib/`; the only other `MaterialPageRoute` uses are
`main.dart`'s `onUnknownRoute` (rebuilds the existing root shell, not a
new destination) and `loading_page.dart`'s `pushReplacement` to
`HomePage` (already counted). So the true count of page classes
reachable by an in-app push is **30**: 28 through `pushPage`, 2 that
skip it. Any router built on top of `pushPage` alone silently misses
those two — noted in the table below and again in §5's staged order.

`showModalBottomSheet` (15 files) and `showDialog` (12 files) are
**excluded from this inventory on purpose**: they present transient,
non-back-stack overlays (pickers, confirmations, one misconception's
expanded text), not addressable pages, and none of the codebase's own
comments treat them otherwise. The one place this matters for the
item's own example list: **`MisconceptionsPage` shows individual
misconceptions in an inline `showModalBottomSheet`, not a separate page
class** — there is no `MisconceptionDetailPage` today. The queue item
names "misconception" among its example destinations; Stage 1 records
that gap rather than inventing a class to fill it (see the table row).

Two more destinations exist but are **not reached by a push at all** —
`_RootRouter` (`main.dart:907`) selects between them directly by
in-memory flag, with no Navigator entry of their own:

- `DashboardPage` — the default/root view, already covered by the
  frozen grammar's empty-hash case (§1).
- `HomePage` — the Bible reader shell; already covered by the frozen
  grammar's non-empty case. (`HomePage` *is* also one of the 28
  `pushPage` classes — `dashboard_page.dart` and others push it
  explicitly with `routeName: '/HomePage'` to return to the reader from
  elsewhere — so it appears once in the table, not twice.)

**Total addressable destinations this plan accounts for: 30 pushed
classes + 2 root-shell states = 32.** (Both crude counts in circulation
before this document — 26 and 77/72 — undercounted or conflated call
sites with classes; neither is used again below.)

## 3. Destination table

Legend for the last column: **yes** = a cold load with only the
entity's durable id can render the page with no dependency on the
pushing page's in-memory state (beyond boot-time data that already
loads for every session, e.g. the sermon/evidence/song indexes).
**no** = the page's content is itself runtime/session state (current
playback, a scroll position) that has nothing durable to put in a URL.
**partial** = addressable in principle, but the current widget doesn't
accept the parameter that would make it so (documented per-row).

| Page class | Proposed path | Params | Durable identifier | Cold-load reconstructable |
|---|---|---|---|---|
| `DashboardPage` | `/` (empty hash) | none | n/a | yes — frozen, already works |
| `HomePage` | `/<bookSlug>/<chapter>[:verse][?v=]` | see §1 | book+chapter (+verse, +version) | yes — frozen, already works |
| `SettingsPage` | `/settings/:section?` | `initialSection` (enum) | enum name, e.g. `ai`, `display` | yes |
| `SermonDetailPage` | `/sermons/:id` | `sermon` (object), `highlight` (UI-only filter) | `Sermon.id` (e.g. `"004"`, `"EC010"`, `"397-1"`) | yes — sermon index loads at boot; drop `highlight` from the URL, it's a search-result artifact not page identity |
| `LibraryPage` | `/library/:tab?` | `initialTab` (0/1) | tab name (`bookmarks`\|`notes`) | yes |
| `StrongsEntryPage` | `/strongs/:number` | `number` (String, e.g. `H430`) | the Strong's number itself | yes — lexicon is a bundled asset |
| `SearchPage` | `/search` | none today (query text is local `TextEditingController` state) | — | **partial** — landing on blank search works now; a shareable pre-filled query needs a new `q` param plumbed into the widget, not just the router (later-stage work, not a Stage-1 gap) |
| `EvidenceDetailPage` | `/evidence/:id` | `evidence` (object) | `BibleEvidence.id` | yes — evidence list loads on demand by id |
| `NowPlayingPage` | `/now-playing` | none (reads the live playback provider) | — | **no** — nothing is playing on a cold load; recommend a cold hit here redirect to `SongsPage` rather than render empty |
| `BibleTriviaPage` | `/trivia` | none (tag filter is local `setState`) | — | **partial** — same shape as `SearchPage`: base page addressable, the active tag filter isn't parameterized yet |
| `HighlightsPage` | `/highlights` | none | — | yes — reads local storage |
| `VideosPage` | `/videos` | none | — | yes |
| `SongsPage` | `/songs` | none | — | yes |
| `StatsPage` | `/stats` | none | — | yes — reads accumulated local stats |
| `EvidencePage` | `/evidence` | `filterBook?`, `filterChapter?` | canonical English book name + chapter int (both already used as URL-safe strings elsewhere) | yes |
| `SongDownloadsPage` | `/songs/downloads` | none | — | yes |
| `SongPlaylistsPage` | `/songs/playlists` | none | — | yes |
| `VideoSeriesPage` | `/videos/:seriesId` | `series` (object) | `VideoSeries.id` | yes — series list is a bundled asset |
| `ProfileEditPage` | — | none (edits "the current profile" from provider state) | — | **no** — there is no profile id param to put in a URL; opens only from `ProfilesPage`, recommend leaving it unrouted (Back returns to the parent list, which is already correct today since it's a same-stack push) |
| `SermonsPage` | `/sermons` | none (search/filter is local state) | — | yes for the base list; filter state has the same partial gap as `SearchPage` |
| `FamilyTreePage` | `/family-tree` | none | — | yes |
| `BibleTimelinePage` | `/timeline` | none | — | yes |
| `MisconceptionsPage` | `/misconceptions` | none | — | yes for the list; **individual entries are not a separate page today** (§2) — out of scope until/unless a `MisconceptionDetailPage` is split out |
| `FeedbackPage` | `/feedback` | none | — | yes |
| `ProfilesPage` | `/profiles` | none | — | yes |
| `AboutPage` | `/about` | none | — | yes |
| `SongPlaylistDetailPage` | `/songs/playlists/:id` | `playlistId` (String) | the playlist id itself | yes |
| `BooksPage` | — | `chapterIdx`, `bookIdx`, `providerOverride` (a live `MainProvider` instance) | — | **no** — this is the split-view secondary reader pane, pushed from inside `bible_reading_pane.dart` with a live provider object that cannot serialize to a URL; recommend leaving split view session-only, same as today |
| `MapViewerPage` | `/maps/:id` | `map`, `locale`, `relatedMaps` | `BibleMap.id` | yes — map data is a bundled asset |
| `SongScorePage` | `/songs/:songId/score` | `song`, `locale` (bypasses `pushPage`, see §2) | `Song.id` (e.g. `"cdc:d0180"`) | yes |
| `SongVideoPage` | `/songs/:songId/video` | `song`, `locale` (bypasses `pushPage`, see §2) | `Song.id` | yes |

23 of 32 destinations are cleanly addressable with an id already
carried by their pushing call site. 3 (`ProfileEditPage`,
`NowPlayingPage`, `BooksPage`'s split-view use) genuinely have nothing
durable to address and should stay unrouted by design, not by
oversight. 2 (`SearchPage`, `BibleTriviaPage`, and `SermonsPage`'s
filter) are addressable for the base page today and would need a small
widget-level change (accepting a query param they don't accept now) to
carry their active filter — that widget change is later-stage work,
not part of this document. `MisconceptionsPage`'s per-entry gap is
recorded, not solved, per §2.

## 4. Router recommendation

**Recommendation: GetX `getPages` / named routes, not `go_router`.**

| | GetX `getPages` | `go_router` |
|---|---|---|
| New dependency | none — `get: ^4.6.6` is already in `pubspec.yaml` and is the app's navigator for every push in this codebase | yes — a new package across all six build targets (iOS/Android/macOS/Windows/Linux/web), weighed against guard rails that ask for that trade to be justified in the commit |
| Migration size | `pushPage` already computes `routeName: '/${page.runtimeType}'` for every call site (`app_nav.dart:24-32`, added 2026-08-03) — the per-page name GetX needs for a `getPages` table already exists at every call site today | would replace `pushPage` and every call site's navigation idiom; a strictly larger diff for the same destination set |
| Known trap already paid for | `app_nav.dart`'s whole existing comment block documents a `preventDuplicates`/route-name interaction that broke navigation app-wide once already (2026-08-03) — that trap is GetX-specific institutional knowledge this codebase already has | a fresh migration reopens exposure to whatever `go_router`'s own equivalent traps are, with no prior incident to learn from |
| Back-stack / URL story | weaker out of the box — this is precisely why the item exists — but GetX 4.6 does support named routes with URL sync (`GetMaterialApp` + `getPages` + `Get.toNamed`), which is the mechanism this plan proposes to adopt in a later stage | stronger by design — declarative routes, built-in deep-link + back-stack handling |

The deciding factor is not "which is the better router in the
abstract" — `go_router` documented behaviour is more URL-native, not
verified here — it's that **GetX is already the app's navigator and
already carries a per-page route name at every one of the 74 call
sites**, and the guard rails for this very item ask for a new
dependency to be justified, not assumed. Converting to `go_router`
would mean re-doing 74 call sites' navigation idiom *and* adding a
dependency, to solve a problem GetX's own named-route + `getPages`
mechanism can solve without either. Documented GetX behaviour, not
verified by running it here: `Get.toNamed('/sermons/004')` against a
`getPages` table writes the named route to the browser URL directly,
which is the piece missing today (only `home:` is set, no `getPages`
table exists yet — confirmed by reading `main.dart`, no `routes`,
`getPages`, or `onGenerateRoute` argument is passed to
`GetMaterialApp`).

The 2 raw-`Navigator.push` sites (`SongScorePage`, `SongVideoPage`,
§2) will need to move onto `pushPage`/GetX's route mechanism as part of
whichever batch converts them — noted in §5's staged order so they
aren't quietly left on the old path when everything around them
moves.

## 5. The two-histories problem

This is the item's "worse of the two" symptom, traced to its actual
mechanism by reading (not by reproducing in a browser — no automated
web-history harness exists in this repo to verify the following against
a live `popstate` event):

1. A `pushPage` call (e.g. `pushPage(SermonDetailPage(...))`) drives
   `Get.to`, which pushes a Flutter `Route` — a **Flutter Navigator
   stack entry** — but does not itself touch `window.location.hash`.
2. `_UrlRestoreObserver` (`main.dart:897-905`) fires on every
   `didPush`/`didPop` and calls `UrlSyncService.onRouteChanged()`.
3. `onRouteChanged()` (`url_sync_service_web.dart:125-136`) waits 350
   ms — long enough for the Flutter web engine to have already written
   its own minified route name into the hash (`#/minified:Xt`,
   per the comment at `main.dart:892-896`) — then forces
   `_writeStateToUrl()` to run again regardless of whether app state
   actually changed (`_lastWrittenUrl = ''` before calling it).
4. `_writeStateToUrl()` (`url_sync_service_web.dart:214-246`) only
   knows about `MainProvider`'s book/chapter/verse/version. It has no
   concept of "a `SermonDetailPage` is currently on top." So the 350 ms
   correction **always rewrites the hash back to the current Bible
   position**, regardless of what was actually just pushed. This is the
   direct mechanism of "the address bar still read Micah 2:1" while
   reading a sermon — confirmed by reading the code path the bug
   report's symptom would have to go through, not by reproducing it.
5. Because `history.pushState` (called inside `_writeStateToUrl`) adds
   a **new** history entry every time it runs, regardless of whether
   the URL text differs from the previous entry, each `pushPage`
   navigation still creates a browser history entry — just one that
   duplicates the current Bible position instead of describing where
   the app actually went. The browser's history stack and Flutter's
   Navigator stack are therefore two different stacks of the same
   *length* (roughly) but different *content*: browser history is a
   list of Bible positions; the Navigator stack is a list of pages.
6. Pressing Back fires `popstate`, which is wired only to
   `_applyHashToState` (state ← URL) — it does **not** call
   `Navigator.pop()`. So Back moves the browser history pointer to an
   entry that, per step 4, usually holds the *same* Bible position as
   the entry it left (a no-op the user perceives as "Back did
   nothing"), while the Flutter Navigator stack — which never heard
   about the `popstate` at all — still has the sermon page on top.

**What the later stage needs to do, stated as a requirement, not
code:** the two stacks must become one. Concretely, the state → URL
writer needs to know the *current route*, not just `MainProvider`, and
compute the hash from whichever is actually on top of the Navigator
(`getPages`'s route entry when a non-Bible page is active, the existing
Bible grammar when it isn't) — and `popstate` needs to drive
`Navigator.pop()`/`Get.back()` when the URL change represents leaving a
pushed page, not only `_applyHashToState`. Both halves are natural
consequences of adopting `getPages` (§4): GetX's own named-route
push/pop already ties into `Navigator`, so the browser and Flutter
stacks collapse into one by construction rather than needing a second
hand-rolled sync layer. This is why §4 recommends deciding the router
before converting any page — bolting per-page `pushState` calls onto
the *current* `pushPage` without also replacing `_UrlRestoreObserver`'s
"always rewrite to Bible position" behaviour would add more history
entries with the same duplication bug, which is exactly the outcome the
queue item's own instruction warns against ("Do NOT bolt `pushState`
calls onto `pushPage`").

## 6. Staged conversion order (for Stage 3)

Easiest fully-parameterizable pages first, so early batches prove the
mechanism on the lowest-risk destinations before anything with a
runtime-only gap (§3) is attempted:

1. **Zero-param leaf pages** — `AboutPage`, `FeedbackPage`,
   `HighlightsPage`, `VideosPage`, `SongsPage`, `StatsPage`,
   `SongDownloadsPage`, `SongPlaylistsPage`, `ProfilesPage`,
   `FamilyTreePage`, `BibleTimelinePage`, `SermonsPage`,
   `MisconceptionsPage` (list only). No id to plumb, proves the
   `getPages` mechanism and the two-histories fix (§5) end to end
   before anything harder.
2. **Single-id detail pages** — `SermonDetailPage`, `EvidenceDetailPage`,
   `StrongsEntryPage`, `VideoSeriesPage`, `SongPlaylistDetailPage`,
   `MapViewerPage`. Each needs a boot-time or on-demand lookup by id;
   batch together since the lookup pattern repeats.
3. **Multi-param / enum pages** — `SettingsPage` (`initialSection`),
   `LibraryPage` (`initialTab`), `EvidencePage` (`filterBook`/
   `filterChapter`).
4. **The 2 raw-`Navigator.push` sites** — `SongScorePage`,
   `SongVideoPage`. Move them onto `pushPage`/`getPages` in the same
   batch as `SongPlaylistDetailPage` (their sibling in the songs
   feature), since they already carry a `Song` id.
5. **Explicitly-unrouted, by design** — `ProfileEditPage`,
   `NowPlayingPage`, `BooksPage`'s split-view push. Confirm each stays
   reachable (same-stack push from its parent, no address-bar entry)
   rather than accidentally becoming inaccessible when the pages around
   them gain routes.
6. **Deferred, needs a widget change first** — `SearchPage` and
   `BibleTriviaPage`'s active-filter state, and `SermonsPage`'s filter.
   Do not attempt these until a param is added to accept the filter
   value; converting the base page without it would ship a URL that
   looks parameterized but silently drops the filter on reload.

Batch 1 lands first and on its own, per the item's "land each stage on
its own so a bad stage can be reverted" — this document does not ship
any of these batches.

## 7. Drift detector

`test/url_routing_plan_table_test.dart` (added in this commit) parses
this file's §3 table for `` `ClassName` `` entries in the first column,
and separately scans `lib/**/*.dart` for every `pushPage(...)` call and
every `Navigator.of(context).push(MaterialPageRoute(...))` call,
resolving each to its pushed widget class exactly as §2's method did.
It fails when a class appears in the code that this table does not
list — so a page added next month (a 33rd destination) cannot silently
sit outside the scheme this document defines. It does not check that
Stage 3 actually implements a listed route — only that Stage 1's
inventory stays complete as the codebase moves.

## Out of scope this pass

Per `NEXT_TASK.md`'s brief for Stage 1:

- No `go_router` (or any) dependency added to `pubspec.yaml`.
- No routing code, `getPages` tables, or `pushState` calls written.
- `url_sync_service_web.dart` was read only, not edited.
- The boot-crash item (`docs/autonomous-queue.md`, "Invalid argument:
  0") was not touched.
