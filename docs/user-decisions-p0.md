# P0 — the decisions only you can make

Generated 2026-09-01 from `docs/autonomous-queue.md` plus a fresh census
(`python3 tools/audit_p0.py`). Every number below was measured today, not
copied from the backlog — where the two disagree, the backlog is stale and
this file says so.

**Why this page exists.** 56 of the P0 items are open. A large fraction of
them are not waiting on work — they are waiting on a ruling. No amount of
parallel agent time moves them, and two of them gate a whole downstream
chain. This is the critical path.

**The rule these all share:** in every case below, *nothing false is printed
today*. These are edition-consistency and editorial-policy calls, not bugs.
That is exactly why they are yours and were not swept.

---

## A. Traditional glyph policy — 4 rulings, ~250 positions

Our Traditional asset consistently picks one character from a pair where the
printed 和合本 picks the other. Both read correctly; the question is which
convention this edition follows.

| pair | ours | the other | in scripture | in `sermons/zh-TW` |
|---|---|---|---|---|
| 兇 / 凶 | **兇** ×48 | 凶 ×0 | 48 verses | 20 files |
| 剋 / 克 | 剋 ×0 | **克** ×23 | — | 2 files |
| 蹟 / 跡 | 蹟 ×0 | **跡** ×103 | — | 83 files |
| 鍊 / 鏈 | 鍊 ×0 | **鏈** ×60 | — | 15 files |

1. **兇 → 凶?** The Traditional witness splits 11 兇 / 37 凶 and Wikisource's
   CUV shows 凶 ×25, 兇 ×0. Ours is 48 兇 and zero 凶 — a likely systematic
   over-conversion. *(Backlog says 47; the count today is **48**.)*
2. **剋 — is zero correct?** We hold no 剋 at all. Either this edition never
   needs it, or a converter flattened it into 克.
3. **蹟/跡 and 鍊/鏈 — restore the distinction?** ~163 scripture positions
   plus ~98 sermon files. The backlog's standing note: *"standard Traditional
   spellings that read correctly, so nothing false is printed today.
   Restoring the distinction is an improvement to ask the user for."*
4. **Do the sermon assets follow scripture?** `assets/sermons/zh-TW/` is a
   separate corpus of 289 files. Whatever you rule above, say whether it
   applies there too — it is where most of the instances actually live.

> **貴胄 / 貴冑 is ANSWERED and needs nothing.** All 26 positions take 貴胄
> (a noble scion). 和合本 renders "helmet" as 盔 / 頭盔 / 盔甲 / 鎧甲, with
> **zero** 甲冑 in all 31,102 verses. We hold no 冑 because the sense never
> occurs — not because a converter failed. The "blocked on user" list can
> drop this one.

---

## B. Verse numbering and labels — 4 rulings

These change verse **identity**, which is why they were held. Highlights,
bookmarks and notes are keyed to the verse id *across versions*, so a label
change desyncs a user's existing data from every other translation.

5. **路加福音 23:34a — give it a sub-verse label?** The printed 註釋本 prints
   34a / 34b; the publisher's Simplified keeps the second half as plain 34.
   Cost of labelling ours: a highlight on Luke 23:34 desyncs from every other
   translation, and Dart's unstable sort would not reliably keep 34a before
   34.
6. **路加福音 21:30 — stub or split?** It is currently a 「見上節」 stub
   pointing at 21:29, the only one of its kind. Leave it, or split 21:29 so
   21:30 carries 「他發芽的時候…」 on its own? Splitting moves any bookmark or
   note anchored to 21:29.
7. **約翰三書 1:14 — does verse 15 deserve its own number?** Same class as
   the two above; this is the precedent the others cite.
8. **創 45:10 「你和你我兒子孫子」 — emend or leave?** Both witnesses read
   你**的**兒子 and 你我 is ungrammatical — **but Wikisource's transcription
   of the printed 1919 和合本 reads 你我 too.** If the printed text says it,
   changing it is an emendation of the CUV itself. Held for exactly that
   reason.

---

## C. Quotation marks — 1 ruling, and one finding that changes the work

Measured today, and this is new:

| | 「/“ | 」/” | 『/‘ | 』/’ | imbalanced verses | 2nd-level unclosed |
|---|---|---|---|---|---|---|
| Traditional | 3438 | 3123 | 665 | 642 | 2336 | 143 |
| Simplified | 3438 | 3123 | 665 | 642 | 2336 | 143 |

**Every number is identical.** The two editions are mechanically parallel, so
this is **one defect, not two** — repair it in one edition and regenerate the
other and both are fixed. Note the editions use different marks (Traditional
「」『』, Simplified “”‘’), which is why a naive count reports Simplified as
flawless.

Also: a verse-level imbalance is *expected* — CUV speech runs across verse
boundaries, so an unclosed 「 mid-speech is normal. The 2,336 figure is not
2,336 bugs. The checkable set is the **143 verses that open a second-level
quote and never close it**.

9. **Should the five 『 in Revelation's letters be closed?** The backlog's own
   note is that *both positions are defensible*. Ruling this one gives the
   rule for the other 138.

---

## D. Blocked on someone else — 3 with the publisher, 1 legal

10. **The 427 Traditional wording differences** — awaiting the publisher.
11. **The 86 Simplified wording differences** — awaiting the publisher.
12. **The two official editions disagree with each other** — needs the
    publisher to say which is authoritative.
13. **NASB licensing** — `assets/nasb.json` is 7.2 MB and publicly served.
    Confirm the licence permits it.

> ### This is the gate
> ```
> decide 427  →  decide 86  →  rebuild Traditional from corrected Simplified
> ```
> Items 10 and 11 block the rebuild, and **the rebuild overwrites
> `cuvs-yhwh-tr.json`.** Any repair written into that file before the rebuild
> is work the rebuild throws away. That is the single strongest argument
> against starting a wide sweep now: not risk, waste.
>
> `docs/梁家鏗譯本-請教出版方.md` is the drafted publisher letter. Its
> Simplified counts are settled; the Traditional 427 still need per-book
> review before it can go out.

---

## What can proceed without you

Two corpora are file-per-item and disjoint from the scripture JSONs, so work
there conflicts with nothing and is not overwritten by the rebuild:

* **`assets/tagged/cuvs-yhwh/`** — 66 files, 367,574 runs. 253 tagged `H0`
  (not a Strong's number), 11 with a number and no word, 1 with a CJK-internal
  space. *(Backlog says 12 and 182; today's counts are 11 and 1 — either
  partly done already or measured differently. Worth reconciling before
  anyone acts on the old numbers.)*
* **`assets/sermons/zh-TW/`** — 289 files, pending your ruling in §A.

Re-run the census any time — it writes nothing:

```bash
python3 tools/audit_p0.py
```
