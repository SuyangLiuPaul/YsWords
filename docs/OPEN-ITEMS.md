# OPEN-ITEMS.md — what is not done

One register for everything outstanding: unfinished data and pipeline
work, product gaps, build hazards, and decisions only the owner can
take. Written 2026-09-05, because YsWords was the only one of the three
Flutter apps without such a file — SeekSparks and Yahweh's World both
keep one and their `AGENTS.md` points at it.

**Every item carries a verification status.** `[verified 2026-09-05]`
means it was checked against this tree, this Mac, or the live sites on
that date, by the pass that wrote this file. `[carried forward]` means
it was transcribed from `docs/autonomous-queue.md` or another document
and the check was **not** redone — treat those as leads, not facts.
Nothing here is asserted more strongly than it was checked.

**This file does not replace the three that already exist.** It sits
above them:

| file | what it is |
|---|---|
| `PROJECT_STATE.md` | orientation — which tier is on which version, and the traps |
| `docs/autonomous-queue.md` | the per-item work queue, ~12 500 lines, resolved and open interleaved |
| `docs/priorities.md` | an append-only priorities log, mostly release history |
| `docs/OPEN-ITEMS.md` | **this file** — only what is still open, each line with its evidence |

Nothing here is duplicated from those three without re-deriving it or
saying plainly that it was not re-derived.

> **The tree was not clean when this was written.** A concurrent session
> was mid-run in this same checkout on 2026-09-05 (`git status` showed 10
> modified files and two untracked tests; `ps` showed `flutter test
> test/bible_map_chapter_ranges_test.dart` in flight). Where a number
> below could differ between the committed and the working tree, the item
> says which one it was measured against. Nothing in this file was
> committed and nothing was fixed.

---

## Data and pipeline

### The songs pipeline has written nothing since 2026-08-30 `[verified 2026-09-05]`

The publisher runs, fetches, and then refuses to write, so the live
catalogue is frozen while the bundled one has moved on.

`~/Documents/CodingProject/yswords-data/.github/refresh-songs-state.json`:

```json
{
  "reason": "ERROR: cdc hymns: 15 page(s) answered but NONE contained an mp3 — treating as a failed fetch, not an upstream deletion of all 15 hymns — refusing to write. | ",
  "first_seen": "2026-08-30",
  "last_seen": "2026-09-03"
}
```

The guard is `fetch_cdc_hymns` raising at
`yswords-data/scripts/sync_songs.py:1142`, caught by `main()` at
`:1851-1853`. The effect, measured today:

| catalogue | generatedAt | count |
|---|---|---|
| live `yswords-data.netlify.app/data/songs.json` | `2026-08-30T11:03:57Z` | 621 |
| bundled `assets/songs.json` | `2026-09-03T08:29:25Z` | 628 |

The live one predates `setapak` and `ydh` entirely — its `bySource` has
only four keys.

**The guard is doing its job and must not be weakened.** It exists
because on 2026-08-10 a partial CDC fetch shipped 36 hymns with a dead
play button. What is open is the upstream condition: CDC's 15 hymn pages
answer but carry no mp3. Someone has to look at the church's site.

### The reference copy of the sync script is not the copy that runs `[verified 2026-09-05]`

`scripts/sync_songs.py` in this repo (1922 lines) has no
`fetch_cdc_hymns` at all — `grep -c "answered but NONE"` returns 0 here
and matches at line 1142 in the yswords-data copy. Two scripts with the
same name and path have drifted, and the one in this repo is the one a
reader is most likely to open.

### The 191 CDC cover images exist only in the bundled catalogue `[verified 2026-09-05]`

`tools/add_cdc_artwork.py` wrote 191 `artworkUrl` values into
`assets/songs.json` on 2026-09-03. The publisher cannot reproduce them.

- `assets/songs.json`: 298 CDC rows, **191** with `artworkUrl` (453 across all 628).
- `yswords-data/scripts/sync_songs.py`'s `fetch_cdc` contains no artwork
  logic — every `artworkUrl` hit in that file is in `fetch_fydt`,
  `fetch_cgdc`, or a field list.
- `test/cdc_artwork_test.dart` exists and fails loudly if a snapshot pull
  blanks them.

So a snapshot pull today would delete 191 covers. This is already
recorded as **STILL OPEN** at `docs/autonomous-queue.md:12127-12131`;
this pass re-verified it rather than transcribing it.

**Mitigated in the client 2026-09-05; STILL OPEN at the publisher.** The
entry stays open on purpose — the client change is a shim, not the fix.

`RemoteDataService` gained a `reconcileJson(incoming, bundled)` hook
behind a `reconcilesIncoming` flag that defaults to **false**, so every
other dataset is byte-for-byte unchanged and does no extra work. It runs
on payloads from the network AND from the prefs cache, while the cache
still stores the raw upstream body — so prefs stays a faithful copy of
what the publisher sent, and the shim is re-applied on each load rather
than baked in.

The gate is the part that matters: the backfill fires **only when the
incoming payload carries zero non-null CDC covers**. One surviving cover
anywhere upstream disables it permanently. That is deliberate — it keeps
the publisher's right to DELETE a cover, and it means the shim
self-cancels the day the real fix lands instead of quietly masking its
absence forever. Measured against the live dataset when written: 298 CDC
rows, the key present on all of them, **0** non-null.

The real fix is still `yswords-data/scripts/sync_songs.py`'s `fetch_cdc`,
which needs the artwork logic `tools/add_cdc_artwork.py` already
implements. Note this is the same file the entry above is about: the
reference copy in this repo and the copy that runs have diverged, and
the one that runs is the one missing it.

---

## Chapter illustrations

### Genuine per-chapter artwork covers 361 of 1189 chapters `[verified 2026-09-05]`

Measured against the **working tree** `assets/maps_index.json`, using the
`kind` field as the classifier (55 survey maps carry no `kind`; 1137
carry `scene` 1083 / `parable` 38 / `teaching` 16):

```
chapters with >=1 kind-tagged illustration: 361 of 1189   (30.4%)
  Ezekiel      1/48        Isaiah    3/66
  Deuteronomy  1/34        Psalms   10/150
  Proverbs     1/31
  Jeremiah     2/52
```

Isaiah 6, Isaiah 53, Ezekiel 37 and Job 38 have **no** dedicated artwork
at all — verified by running the same range match over those four
chapters.

This is the part that remains open. The two mechanisms that made the
problem invisible were diagnosed and fixed in the working tree on
2026-09-05 (not committed): the 55 bundled survey maps carried whole-book
ranges, and `tools/integrate_all_tissot.py` had collapsed discrete
chapter lists to min/max. The scale of what they were hiding, measured
against **`HEAD` (`git show HEAD:assets/maps_index.json`, v1.4.214)**:

```
(chapter, image) display pairs                     7602
  from ranges wider than 3 chapters                5899   (77.6%)
    of those, from the 55 bundled survey maps      5843
chapters with no illustration of range <= 3         806 of 1189
```

Every one of the 1189 chapters matched *something*, which is why the
sheet's own "no illustration for this chapter" strings were unreachable.

### `maps_index.json` carries no licence or attribution field `[verified 2026-09-05]`

The 1192 entries use exactly seven keys — `books`, `description`,
`file`, `id`, `kind`, `source`, `title`. There is no `license`,
`attribution`, `credit` or `source_url` field, and no entry has the
strings `licen` or `CC BY` anywhere in any of its values (0 of 1192).

40 entries are Sweet Publishing images (`grep` on `id` for `sweet`).
Whatever attribution those carry today is incidental free text in a
`description`.

---

## Product gaps

### ~~The sermon list gives no sign that a sermon is playable~~ `[CLOSED 2026-09-05]`

`lib/pages/sermons_page.dart` is 988 lines and contains **zero**
occurrences of `audio` (case-insensitive). The player is docked only on
the detail page — `lib/pages/sermon_detail_page.dart:506`,
`bottomNavigationBar: SermonAudioBar(sermonId: s.id)`.

Worth stating precisely, because the shape of the gap is not what it
looks like: **every sermon has audio.** `assets/sermons/index.json` holds
289 sermons with 289 unique ids; `assets/sermons/audio_index.json` holds
an entry for all 289 and none of them is empty. So there is nothing to
distinguish — the list simply never tells a reader that any of the 289 is
playable at all.

**FIXED.** One clause on the existing summary line, not a badge on 289
rows — the page's own byline comment already reasons that a mark true of
every row is decoration, not information, and that precedent transfers.
`sermonAudioClause()` is a pure function of (configured, total, playable)
with four branches, and both counts are computed as the INTERSECTION of
the loaded corpus with the audio manifest, so **the number 289 appears
nowhere in the feature** and the line stays true if the corpus changes.
Renders `289 篇讲道,共 20 个主题 · 每篇都有录音`.

Worth recording how nearly this shipped untested: the first "no per-row
badge" test PASSED with a play icon inserted on all 289 rows. The rows
sit inside collapsed `ExpansionTile`s and are never built, so a
`find.byIcon` over an unbuilt subtree finds nothing no matter what you
put there. The test now expands a group first and asserts the rows were
actually built.

### Browser Forward is structurally unreachable on web `[measured 2026-09-05 — DEFERRED, not a defect]`

Re-measured against a real release build, planted and control:
`push-added-history-entry=false`, forward count **0 at every sample**.

**The queue entry's warning against `SystemNavigator.selectMultiEntryHistory()`
is now TESTED rather than argued.** A throwaway bundle that calls it
after the first frame turns one Back press into 1 popstate + 2 pushes,
growing the history stack **8 → 11**, and pushes GetX's `unknownRoute`.
Back becomes a route-push. The shortcut is worse than the gap.

Also corrected: `createHistoryForExistingState` does not decide the mode.
`NavigatorState.initState` calls `selectSingleEntryHistory()` on **every
boot**, so multi-entry is unreachable from a shipping build by any user
action.

Ruled DEFER. Two preconditions before anyone attempts
`GetMaterialApp.router`, and they are in this order for a reason:
1. A routing gate that cold-loads every registered route AND a Bible
   reference, checking address bar, Back, Forward and the prerendered
   paths — **built green against the current `home:` build first**, so it
   is a ratchet and not a hope.
2. A measured spike answering whether unnamed `Get.to` still pushes
   correctly under `GetMaterialApp.router` in GetX 4.7.2 (72 call sites,
   none proven), and whether a `/:book/:chapter` GetPage can carry the
   `:verse` and `?v=` grammar **without changing URL text** — the
   `/read/` and `/sermons/` sitemaps depend on the exact paths.

Only if both are yes does it get scheduled, as its own item rather than
attached to "Forward doesn't work".

### ~~On the Bible reader, Back pushes a route instead of popping~~ `[FIXED 2026-09-05]`

Reproduced, fixed, and proven in a real browser.

`_writeStateToUrl`'s raw `pushState(null, …)` left an entry the engine
does not recognise, arming `SingleEntryBrowserHistory.onPopState`'s
manual-URL-edit recovery path on every chapter turn.

| cold `/#/micah/2?v=kjv`, two chapter turns, one Back | before | after |
|---|---:|---:|
| browser entries added by reading | 2 | **0** |
| popstate events for ONE Back | 3 | **1** |
| `currentIndex` drop | 3 | **0** |
| forward entries discarded | 3 | **0** |
| still on the reader 5 s after Back | yes | no |

Fixed with `replaceState(history.state, …)` — handing the engine its own
tag straight back, so this file never learns the engine's private tag
names. **URL text is character-for-character identical**, so the
prerendered sitemaps cannot be affected.

**Correction to the old entry's mechanism:** with only ONE raw entry
above the flutter entry — a reader who has not changed chapter — Back
lands in `onPopState`'s SECOND branch and dispatches `pushRoute` with no
`go(-1)` at all. The three-popstate cascade the entry describes needs ≥2
stacked raw entries. Same outcome, different path.

Gated by `tools/web_verify_headless.mjs bible`, verified RED on the
unfixed build and on the multi-entry experiment build, green on the fix.

### On every Bible deep link the address bar flips through `#/_unknown` `[verified 2026-09-05]`

Noticed while measuring the two items above and deliberately not touched.
GetX has no registered name for the Bible URL grammar, so `unknownRoute`
fires at boot and **its route name reaches the address bar** before the
real page settles. Pre-existing and unchanged by the Back fix — and it is
the same missing registration that blocks the `.router` migration above,
so the two should be scheduled together or not at all.

### EC018 / EC019 sermon transcripts are raw speech recognition `[REOPENED 2026-09-05 — I closed this wrongly]`

**I closed this earlier today and the closure was wrong. Reopening it
with the reasoning, because the mistake is instructive.**

I wrote: "`en/EC019.txt` holds 514 full stops, 356 commas and 130
paragraphs, not 'one period and no commas'." Every one of those numbers
is correct — and they answer a question nobody asked. The original entry
is about **a paragraph**, not a file: "EC019 is said to have one period
and no commas in an 18 205-character paragraph." I refuted a
paragraph-level claim with file-level statistics, which cannot touch it.

Measured properly — paragraphs of 5 000+ characters across all 289
English bodies, of which there are four:

| body | para | chars | full stops | commas |
|---|---:|---:|---:|---:|
| EC019 | 49 | **18 205** | **1** | 2 |
| EC019 | 129 | 10 427 | **1** | 0 |
| EC018 | 71 | 9 805 | **0** | 530 |
| EC014 | 1 | 8 780 | 47 | 377 |

The first row is the entry's own 18 205, unchanged. EC014 is long but
punctuated at a normal density and is a different thing — a paragraph
that was never split, not one that was never punctuated.

The Chinese bodies inherit it: EC019 para 49 is 6 046 characters with
25 full stops and 2 commas, in both scripts.

**And the T7 drive does not help.** `en/EC019.txt` is byte-identical to
T7's `.formatted.txt`, and I confirmed T7's own copy carries the same two
paragraphs at the same sizes with the same 1 full stop each. So the
entry's instruction — "look for better transcripts on the T7 drive
first" — has now been carried out, and the answer is that there are
none. That is the one piece of progress here.

**What remains, and why it is still not a code task:** the rule is that
nobody re-punctuates a preacher's words. Re-deriving the punctuation from
the audio is possible — the church publishes all 589 MP3s — but that is a
re-transcription, and it needs the owner's decision about whose sentence
boundaries end up on the page.

### Three Traditional sermon translations are truncated at source `[verified 2026-09-05]`

Sermons **100, 369 and 370** lose most of their Traditional body:

| id | Simplified | Traditional | lost |
|---|---:|---:|---:|
| 100 | 18 304 | 6 331 | 65% |
| 369 | 13 957 | 5 931 | 57% |
| 370 | 18 015 | 13 209 | 27% |

**The loss is in the T7 source, not in this repo's ingest.** T7's own
`100a…zh-TW.txt` is 3 823 characters against a Simplified 9 700, and the
merge of a+b is arithmetically exact (3 823 + 2 521 + 1 = 6 345). So
Phase 4 produced short files for these parts and Phase 5 ("proofread")
copied them — `*.zh-proofread.txt` is byte-identical to `*.zh-TW.txt`
throughout, so Phase 5 proofread nothing. T7's `PROGRESS.md` reports
Phases 4 and 5 as "589/589 100%": it counted files, not content.

**DONE 2026-09-05, on the owner's instruction to finish all of it.** One
thing had to be established first: these three are not s2t conversions of
their own Simplified bodies the way the other 286 are — they are a
SEPARATE translation in a different voice (「我應當」 where the Simplified
reads 我应该), and an incomplete one. So there was nothing to repair; the
right move was to put them on the same footing as the rest of the corpus.
Rebuilt with `opencc -c s2t` over the Simplified plus the orthography
rules below. All three now match their Simplified body's length exactly
(18 304 / 13 957 / 18 015, delta 0), and `test/tw_sermon_orthography_test.dart`
asserts that equality for the three by id, so a truncated Traditional
body fails rather than merely looking short.

Three pinned corpus totals moved with the ~38 000 characters this added
(鬥 219→220, 面 5887→5926, 凌 23→24) and one sweep total (12 505→12 528
matches). Every new occurrence was READ before its number was changed:
the four new 鬥 are 戰鬥, the new 凌 is 凌晨, and none of the three
contains 面包/面粉/面糰/面酵, so nothing that should be 麪 is hiding in
the increase. The sweep's parsed total moved by the SAME +23 as its match
total, which is the proof that the rebuild introduced no new
out-of-canon reference.

### The shipped Chinese bodies are one proofreading pass behind T7 `[verified 2026-09-05]`

Across all 289 sermons the shipped Chinese differs from T7 in exactly one
systematic way: **3 912 places where this repo has 他 and T7 has 祂** —
the reverential pronoun for deity. The English is not behind (137 files
byte-identical, the rest differing only in the H1, which the ingest
rewrites on purpose). This repo is *ahead* of T7 on glyph repairs (麪 91,
乾 13, 斗 12), so a plain re-ingest would have traded 3 912 corrections
for about 120 regressions.

**DONE 2026-09-05 as a targeted merge.** Line-aligned against T7 and
applied ONLY where the aligned lines are the same length and every
differing character is exactly 他→祂; anything else was left alone. The
Traditional pass needed T7's side normalised by the orthography rules
first, or the co-occurring glyph differences masked the pronoun on the
same line. Result: 祂 now stands at 6 316 in the Simplified corpus and
6 316 in the Traditional — the two agree exactly, which they did not
before (6 316 vs 6 249 mid-merge, and the gap was sermon 100's truncated
body).

The merge's own refusals are worth keeping: it declined 34 麪, 12 乾,
10 斗 and 4 採 where T7 disagrees — these are this repo's own repairs and
T7 is the one that is behind — and it declined two 己/已 pairs where T7
reads 「對自已說」, a typo. `test/ziji_typo_test.dart` already guards that
class.

### The sermon corpus now has exactly one copy `[verified 2026-09-05]`

`scripts/ingest_sermons.py:33` reads `SOURCE = ~/Downloads/P.Eric Sermon`.
**That directory no longer exists.** The only copy of the 589 transcripts
in five phases is the T7 drive, and `tmutil destinationinfo` reports no
backup destination configured on this Mac. The generated bodies are in
git; the sources are not.

### 940 sermons on fydt.org / fuyindiantai.org are not imported `[verified 2026-09-05]`

Both sites are the same WordPress install behind two names and expose a
`message` post type — 讲道信息 — at `/wp-json/wp/v2/message`:
**940 items, `x-wp-total: 940`**, against the 289 this app ships. The
`content_author` taxonomy holds **77 preachers**: 张成牧师 201,
张熙和牧师 201, 小珊姊妹 151, 李马可牧师 96, 辛岚 76, 昊敏 60,
梁家铿牧师 10, and 70 more. Four other taxonomies come with them
(专题系列, 书卷查考, 圣经一神论, 奇妙恩典, 生命再思).

The songs from these two sites were integrated; the messages were not.

**FETCHER BUILT 2026-09-05 — and my reading of the obstacle was wrong.**
I had written that the bodies were unreachable because `content.rendered`
is empty and the page HTML held only navigation. Both observations were
true and the conclusion was not: the theme renders from ACF, and the same
REST call already returns it.

- **Body** = `acf.transcription_displayed`. Verified independently on
  record 231105: `content.rendered` 0 characters, `transcription_displayed`
  **7 816**. 841 of 940 carry ≥200 characters; 843 body files hold
  5 441 495 characters across **840 distinct first lines**, which is what
  rules out navigation chrome.
- **Audio** = `acf.audio_recording_mp3`, holding WordPress **attachment
  ids, not URLs** — which is exactly why no `.mp3` string appeared
  anywhere I looked. 673 of 940 have audio. Verified: id 189230 →
  `audio/mpeg`, `…/2026/05/2kg28.mp3`, HTTP 200, **25 854 873 bytes**.

`scripts/sync_sermon_library.py` + `test/test_sermon_library.py` (**130
tests, OK** — 54 when written) produce `assets/sermon_library/` — 940
records, 843 bodies, 18 MB.

**The guards were one-sided and are now symmetric `[2026-09-06]`.** They
refused SHRINKAGE and passed SUBSTITUTION: eight attacks wrote a degraded
snapshot with exit 0, the worst of them replacing every body with the
same navigation string — 5.4 M characters down to 770 K, 840 distinct
first lines down to **1** — while `_meta` reported `withBody: 940`, a
number *better* than the true 841. All eight are refused now, and the
shrinkage floors are untouched.

Three things behind that were structural rather than a missing rule:

- **`run_guards()`'s composition was untested.** Any single guard could
  be unwired from the pipeline and all 54 tests stayed green, because
  `main()` calls only the aggregate. Each entry is now proven reachable
  *through* the aggregate, and each isolating case must trip exactly one
  guard — that second assertion caught three sloppy fixtures.
- **Three floors compared a constant to itself.** `MIN_BODIED` could be
  changed from 841 to 1 and the test still passed, because it asserted
  `meta['withBody'] >= MIN_BODIED` — both sides moving together. They now
  assert against measured literals, with a separate check that the
  constants still match.
- **The old fixture was degenerate**: every record shared one body and
  one audio id. A degenerate corpus cannot exercise a distinctness guard,
  because it fails one — which is part of why none of this was noticed.

**And the crawl was unbounded.** If the server ignored `?page=`,
`fetch_messages` never terminated — measured at 201 requests and still
going against a paging-ignorant fake. That is an unbounded crawl against
a church's server, in a script whose own docstring cites an outage caused
by doubled traffic. It is now finite by construction: the `x-wp-total`
headers are the authority, the loop is a bounded range, and the same fake
server aborts after **two** requests. Canonical host is **fuyindiantai.org**, not fydt.org: the REST
root reports it as `home` and the CMS emits it in every `link` and
`source_url` even when queried through fydt.org. 71 distinct authors.

**NOT DONE, and each is a decision rather than a task:**

0. **REMOVED FROM THE REPO 2026-09-06, and it should never have been in
   it.** The 843 body files were committed and then pushed to this
   **public** GitHub repo by a concurrent session, which is
   redistribution of 5.4 million characters of 71 preachers' sermons —
   the exact act `_meta.authorisedScopeNote` says needs the church's
   confirmation first. Not a confidentiality problem: the bodies are
   published on fuyindiantai.org and anyone can read them. A
   redistribution one, and not ours to decide.

   Untracked with `git rm --cached` and gitignored; the files stay on
   disk and `scripts/sync_sermon_library.py` regenerates them. **The
   history still carries them** — the owner chose to leave it rather than
   rewrite a pushed history that several sessions share.

   Note what this costs: on a fresh clone `TestSnapshot` SKIPS, so 130
   tests still pass while the snapshot itself goes unchecked. The skip
   reason says so rather than reading "not generated yet".

1. **Not bundled.** `pubspec.yaml` does not list `assets/sermon_library/`.
   It would add 18 MB to every install on top of the 28 MB
   `assets/sermons/` already costs, for a feature with no UI yet. The
   songs feature fetches at runtime; that is probably the right shape
   here too, and either way it should be chosen deliberately.
2. **No app wiring.** Nothing reads the data. The 289-sermon module and
   this 940-sermon library are separate corpora by separate speakers, and
   whether they merge into one browsing surface or stay apart is a
   product question.
3. ~~**Authorisation is a relayed statement, not a document.**~~
   **SETTLED 2026-09-06 by the owner: 「在那里无所谓，这些信息网上都可以
   搜到」** — it does not matter that the bodies passed through the public
   repo's history, because the material is public and searchable already.
   That is consistent with what was measured rather than a waiver of it:
   every one of these sermons is published on fuyindiantai.org and anyone
   can read it, so this was a redistribution question and never a
   confidentiality one.

   The history keeps the 843 bodies. Rewriting a pushed history that
   several concurrent sessions share was offered and declined.

   `_meta.authorisedBy` still records who said what and when, which is
   worth keeping: the owner's 「有批准」 was said about the SONGS on these
   domains on 2026-08-09, and the sermon library was directed separately
   on 2026-09-05. Nothing about that record is invalidated by this
   decision — it just is not blocking anything now.
4. ~~One record's `date` is `0214-07-02`~~ **RESOLVED 2026-09-06.** Record
   2967 keeps its date **byte for byte** — nothing infers 2014, because
   guessing a year is worse than carrying a flagged one — and now also
   carries `dateSuspect: true`, is listed in `_meta.suspectDates`, and a
   guard refuses a crawl carrying more than three of them.

   **This creates a contract for whoever wires the library into the app:**
   a row with `dateSuspect: true` must sort as UNDATED in any date-ordered
   view, not as the year 214. Nothing reads these assets yet, so this note
   is the only place that requirement currently lives.

---

### A video on the live site plays nothing: it was made private `[FIXED 2026-09-06]`

`yahwehword.com/#/videos/onegod` offers English / Cantonese / Mandarin.
The English track shows YouTube's "This video is private". Not an app
defect: id `QmTEkPquvcQ` returns **HTTP 403** from YouTube's oEmbed
endpoint, while the same episode's Cantonese (`2L4LZ1BNu3Q`) and Mandarin
(`xqau2AqNNno`) both return 200 with their real titles. Someone changed
that video's visibility on YouTube after it was catalogued.

**Swept all 66 ids in `assets/videos.json` again on 2026-09-06: still the
only dead one** (65/66 returned 200 in the same run, batch healthy).

This entry originally weighed two ways out, and rejected both: the
church restoring the video needs a person, not a code change; deleting
the English track throws away the id needed to restore it. **There was a
third option**, now shipped: keep the id, stop offering the button.
`VideoTrack` gained an optional `unavailableSince` / `unavailableNote`
pair (null for the other 65 ids); `QmTEkPquvcQ`'s `en` track is marked,
not removed. `VideoEpisode.playableTracks` filters marked tracks out for
`_languageRow` (no more English chip on this episode), and
`defaultTrack` / `trackForLocale` skip a marked track in favour of an
unmarked one when one exists — falling back to the marked track only if
literally every track on an episode is marked, which is true of no
episode today (pinned by `test/video_series_test.dart`).

**The sharper half of the bug, also fixed**: `QmTEkPquvcQ` is `tracks[0]`
and `preferredTrackLangs` puts `en` first for every non-`zh` locale, so
`trackForLocale('en')` was returning the dead id — an English-locale
reader was auto-selected into the private video before touching
anything, not just offered a dead button. Confirmed by test: with the
fix, an English-locale reader on this episode now lands on the Mandarin
track (`preferredTrackLangs`' next entry after `en`), never on
`QmTEkPquvcQ`.

`tools/known-unavailable-videos.json` is untouched and still deliberately
empty for this id — suppressing the UI button and silencing the weekly
alarm are different things, and the alarm should keep shouting until the
church has actually been asked.

**No guard would have caught the original bug**, and that is still the
more useful finding: nothing in the app or CI probed these 66 ids until
`tools/check_video_ids.js` + the weekly `check-videos.yml` workflow
existed (added 2026-09-05/06). This entry stays as the record of what
happened; the "no guard" gap it names is now closed.

**Follow-up closed 2026-09-06**: a refuter reviewing this fix noticed the
filtering only reached `VideoEpisode.playableTracks`, not
`VideoSeries.compilations` (the "watch the whole series in one video"
row). `VideoSeries.playableCompilations` now applies the same
`isUnavailable` gate, via a `PlayableVideoTracks` extension shared by
both. No live compilation carries `unavailableSince` today, so nothing
visibly changes; the row will simply hide if one ever does, instead of
offering a button that opens "This video is private."

### The book chip says Genesis 1 while the body renders John 3 `[observed 2026-09-06]`

Seen in every browser screenshot taken while verifying the version
picker: a cold load of `/#/john/3` renders John 3 correctly and the
header's BOOK chip reads 「创世记 1」. Identical in two release bundles
that differ only in the picker class, so it is pre-existing and was not
introduced by that work.

**This is the same shape as a defect fixed in the sibling app yesterday**
— there, the reading pane's header pushed the CURSOR while a link that
carries no `:verse` moved only the reference, so the header and the body
disagreed and the verse picker opened on the wrong book. Two release
builds served side by side showed John 3 in the body under a "Genesis 1"
header while the status bar read "John 3 BSB Reader". The fix there was
`_settleCursorInCurrentChapter`, applied only when the cursor falls
outside the new chapter.

Whether Words has the same cause or merely the same symptom is NOT
established — nobody has looked. It is recorded here because it was
observed rather than reasoned about, and because the sibling's fix is a
strong first place to look rather than a conclusion.

## Build and toolchain

### Four test files fail to compile inside a third-party package `[carried forward, with the versions verified 2026-09-05]`

`cahaya_songs_enabled`, `dashboard_font_scaling`,
`dashboard_pull_refresh_removed` and `profile_avatar_tap` are reported to
fail compilation on a null-safety error in `pdfrx_engine` 0.4.5, at
`lib/src/native/pdf_file_cache.dart:380` and `:382`, on Flutter 3.47.2.

**This pass did not run those tests** — another session was running
`flutter test` in this same checkout and the two would have shared
`build/unit_test_assets`. What was verified here is the surrounding fact
pattern:

- `pubspec.yaml:124` pins `pdfrx: ^2.4.7`.
- `pubspec.lock` resolves `pdfrx` 2.4.7 and `pdfrx_engine` 0.4.5.
- `~/.pub-cache/hosted/pub.dev/pdfrx_engine-0.4.5/lib/src/native/pdf_file_cache.dart`
  exists and lines 380/382 are the `readEnd` / `cache.read` pair.
- `pubspec.lock` was clean when the versions above were read. It has
  since been modified by the concurrent session, so re-read it before
  trusting the two version numbers.

Escaping it needs a `pubspec.yaml` constraint bump, and pdfrx renders the
hymn-score PDFs — see "Decisions waiting on the owner".

### Two Flutter toolchains on this Mac, and they disagree `[verified 2026-09-05]`

```
/Users/pliu0036/flutter/bin/flutter      Flutter 3.44.2   (the CI pin)
/opt/homebrew/share/flutter/bin/flutter  Flutter 3.47.2
```

The concurrent test run observed today was using the Homebrew 3.47.2 one.
Which of the two a session picks up is not pinned by anything in the
repo, and the pdfrx failure above is reported only on 3.47.2.

### ~~Android's INTERNET permission is not declared by the app~~ `[CLOSED 2026-09-05]`

Declared explicitly in the main manifest, with the merged-manifest blame
report quoted in the comment. `test/android_internet_permission_test.dart`
strips XML comments before matching — deliberately, because the comment
itself contains the word INTERNET and a plain substring search passed
with the element deleted.

**The guard had a SECOND hole, closed 2026-09-06.** Its regex —
`<uses-permission[^>]*android:name…"[^>]*/?>` — accepted any extra
attribute, so writing `tools:node="remove"` on the element passed all
four tests while deleting the permission from the merged manifest. The
file already declares `xmlns:tools`, and that directive is the idiom
people actually reach for when stripping a plugin-injected permission.

And the consequence is no longer inferred: `./gradlew
:app:processIntlReleaseMainManifest` was run for the first time (JDK 17,
since no JDK was on PATH). INTERNET is **present** in the merged manifest
as shipped and **absent** with the directive, while the other six
permissions are byte-identical and `google_sign_in_android` still
contributes its own — the directive out-ranks it.

The test now parses each element's attributes rather than matching a
regex, checks the attribute's LOCAL name so rebinding `xmlns:tools` to
another prefix cannot slip past, and treats `node="replace"` as benign
because it is.


`android/app/src/main/AndroidManifest.xml` declares
`POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_MEDIA_PLAYBACK` and `WAKE_LOCK` — **not** `INTERNET`.
Only the `debug` and `profile` manifests declare it, which is the stock
Flutter template layout.

The release build does get it, by manifest merge:

```
build/app/intermediates/merged_manifests/intlRelease/processIntlReleaseManifest/AndroidManifest.xml:42
    <uses-permission android:name="android.permission.INTERNET" />
```

and the only plugin contributing it is `google_sign_in_android`. **Not a
bug today** — the current release APK has network. It is a latent one:
drop or replace that plugin and the app loses all network on Android with
a green build and a green analyze. This exact failure cost the sibling
app Yahweh's World three versions; there it was fixed by declaring
`INTERNET` in the main manifest explicitly.

---

## Decisions waiting on the owner

- **NASB and LEB redistribution.** `docs/autonomous-queue.md:12420-12446`
  records both as publicly fetchable from prod at 7.2 MB and 8.8 MB, and
  makes the point that every earlier write-up named NASB alone while LEB
  is the same exposure. The prerender exclusion covers `/read/` pages
  only. Nothing has been decided. `[carried forward]`
- **The `pdfrx` constraint bump.** Unblocking the four test files means
  moving off `^2.4.7`, and pdfrx is what renders the hymn scores. An
  owner call, not a maintenance one. `[carried forward]`
- **NASB divine-pronoun capitalisation (#173-176)** — explicitly tied to
  the NASB licensing question. `docs/autonomous-queue.md:12337`.
  `[carried forward]`
- **The four open questions for the 梁家鏗 publisher** — adopt the 8
  revised verses (`:6108`), 馬可福音 6:8-11 missing from the publisher's
  own Simplified (`:6299`), the two official editions disagreeing
  (`:6315`), and the remaining 86 Simplified wording differences
  (`:6361`), with the Traditional rebuild (`:6387`) waiting behind them.
  `[carried forward]`
- **Whether `assets/sermons/zh-TW/` follows the lexicon into the other
  Traditional orthography** — `docs/autonomous-queue.md:3788`.
  `[carried forward]`
- **The Strong's lexicon's 着 / 著 in 51 places** —
  `docs/autonomous-queue.md:3800`. `[carried forward]`
- ~~**Attribution for the 40 Sweet Publishing illustrations.**~~
  `[CLOSED 2026-09-06]` The Commons tags were checked over the network
  in `e2fe38c1` (all 40 uniform CC BY-SA 3.0, Jim Padgett / Distant
  Shores Media/Sweet Publishing, 1984), and the surface half — the
  About page rendering none of it — is now fixed: `lib/pages/
  about_page.dart`'s `_OtherAttributions` derives the credit row(s)
  from `MapRights` at runtime (not hardcoded), so a future import
  adding a new grouping cannot silently go uncredited. Frozen by
  `test/illustration_rights_test.dart`, which pins the 40 ids and
  asserts the rendered page carries the verbatim credit sentence and
  the modification notice. The blanket "public domain / Creative
  Commons archives" line was false for these 40 and is now the honest
  mixed-collection wording, without flipping to a PD claim for the
  other 1,152 in the other direction.

---

## Unverified — needs a look

Everything in this section is a lead. None of it was proven today.

- **The other unchecked items in the queue.** `grep -c "^- \[ \]"
  docs/autonomous-queue.md` returns **20**. This pass re-verified or
  transcribed six of them. The remaining fourteen — mostly under "P0 —
  scripture accuracy" and "P1 — Bible study correctness" — were not read
  closely enough to summarise honestly, and are not restated here rather
  than restated wrongly.
- **`docs/priorities.md`'s own open lists.** Its "Open (2026-06-14)" and
  "Open — added 2026-08-04" sections, and the CSP re-introduction and
  security follow-ups near the top, were read but not re-verified against
  the tree. Some are years of releases old.

---

## Fixed on 2026-09-05, recorded here because both were silent

### The divine-name substitution had renamed an organisation

The Chinese sermon bodies carry a deliberate corpus-wide 耶和华 → 雅伟
substitution. It was applied as a blanket replace, and a blanket replace
cannot see a name inside another name: **"Jehovah's Witnesses" had become
雅伟见证人 / 雅偉見證人** in sermons 004, 065, 140, 225 and 237 — ten
occurrences, and zero correct spellings left anywhere in the corpus. The
English bodies say "Jehovah's Witness(es)" in all five, which is what
settles it, and the T7 sources had it right, so this was introduced
downstream of them. Restored. `test/sermon_divine_name_proper_noun_test.dart`
pins both sides: the organisation keeps its name, and the 677 other 雅伟
stay.

### The Traditional corpus spelled the same words two ways

`assets/sermons/zh-TW/` is `opencc -c s2t` output — calibrated, not
assumed: over eight sermons whose two Chinese bodies are the same length,
s2t reproduces the shipped Traditional with **0 mismatches in 91 118
characters**. On top of that, 35 of 206 comparable files had been
hand-repaired and 171 had not, leaving the corpus with 爲 23 701 / 為 860,
着 6 915 / 著 454, 裏 10 262 / 裡 399, split by which file you opened.

The owner's ruling — follow the latest printed Traditional 和合本 — is
decidable from a bundled asset: `assets/cuvs-yhwh-tr.json` is unanimous
on every one (為 7952:0, 裏 4787:0, 著 2651:0, 才 240:0, 啟 425:0). Note
裏, not 裡: two of the hand-repaired files had been moved the other way,
so the partial repair was not merely unfinished, it disagreed with the
ruling. **32 220 characters normalised across all 289 files**; glyphs
only, no punctuation, wording or paragraphing touched. Pinned by
`test/tw_sermon_orthography_test.dart`, which also asserts the earlier
麪 repairs survived.

Two tests named the old spelling in a string literal and had to be
edited by hand — `zh_chapter_mark_ref_test.dart` and
`canon_chapters_test.dart`, both pinning 啓示錄三十七章十七節 as a
reference the parser must refuse. It still refuses; only the glyph moved.

**Still unnormalised, and now on measurement rather than caution:**
straight quotes. The corpus holds 25 833 `"` against 574 「.

That rule was a judgement when it was written. It has since been tested.
Rebuilding sermons 100, 369 and 370 destroyed 103 correctly-paired
brackets (corpus 「 574 → 471), and the discarded bodies in `9808dff6^`
are an answer key for 188 of those positions. Scoring the obvious
whole-file alternating rule against that key: **160 right, 28 wrong** —
and sermon 100 slips parity mid-file and inverts every quote after it,
which is exactly the failure the rule exists to prevent. The causes are
single-word emphasis quotes (`這裏的"國"`), nested quotation, and split
dialogue attribution.

So any future pairing pass must clear those 188 positions before it is
allowed near the other 25 833, and must handle all three failure modes.

### 103 correctly-paired corner brackets were destroyed by the rebuild `[verified 2026-09-06]`

Sermons 100, 369 and 370 held 36 / 24 / 43 pairs of `「」` before they
were rebuilt from their Simplified bodies; `opencc -c s2t` replaced them
with 443 straight quotes. A change that moves text from "correct" to the
state this project says it cannot safely reach is a regression by the
project's own definition, and "consistent with the other 286" is a
defence of it rather than a reason it did not happen.

**Ruled: record, do not recover.** The key covers only 32.9 / 41.2 / 71.1
per cent of each new body, because the translation it comes from was
itself truncated — so the best available outcome is 88 of ~221 pairs per
file, which is not a correctly bracketed sermon but one that changes
punctuation style partway through. The corpus is currently partitioned
cleanly by style: 272 files straight-only, 14 bracket-only, 1 mixed.
Between two imperfect states, the one shared with 286 siblings wins.

The three files are unchanged. This entry is the record.

---

## Checked and found NOT open

Recorded so the next pass does not spend the time again.

- **Nothing is missing from the illustration index.** All 1189 chapters
  match at least one entry; all 55 `source: asset` files are present in
  `assets/maps/` (55 files, 0 missing). The gap is quality, not presence.
  `[verified 2026-09-05]`
- **The illustration CDN is healthy.** 100 of 100 sampled
  `source: cdn` URLs returned `200` with an `image/*` content type,
  including 20 drawn deliberately from the 67 entries with non-ASCII
  filenames. `[verified 2026-09-05]`
- **No version drift across the tiers.** `pubspec.yaml`, and the
  `/version.json` of `yswords`, `yswords-dev` and `yswords-qat`, all
  answer **1.4.214**. `[verified 2026-09-05]`
- **The 在十字架下 series is complete.** All ten episodes carry a Mandarin
  track; episode 10 (`AiiyRGaRJBY`) landed 2026-09-05 and
  `assets/videos.json` records the oEmbed check for each. `[verified 2026-09-05]`
- **There is one skipped test and its skip is justified.**
  `test/sermon_audio_bar_test.dart:112` —
  `skip: 'needs rootBundle; covered by sermon_audio_index_test.dart'`.
  It is the only `skip:` or `@Skip` in `test/` and `integration_test/`.
  `[verified 2026-09-05]`
- **The codebase carries almost no debt markers.** `TODO`, `FIXME`,
  `XXX` and `HACK` across `lib/`, `test/`, `tools/`, `scripts/` and
  `integration_test/` return 6 hits, and all six are false positives —
  four are the literal string `XXXX-XX-XX` in a date-format test and an
  mDNS pair-suffix comment, two are `tools/loop/` describing its own
  queue file. There are no `UnimplementedError`s in `lib/`.
  `[verified 2026-09-05]`
