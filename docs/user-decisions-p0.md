# P0 — the decisions only you can make

Generated 2026-09-01 from `docs/autonomous-queue.md` plus a fresh census
(`python3 tools/audit_p0.py`).

> ## Revised 2026-09-01 after a review by Fable 5.1
>
> The first version of this page had **two errors of my own**, both now
> verified and corrected below. Recording them because they change what you
> should do:
>
> 1. **I put the gate on the wrong edition.** The 427/86 wording differences
>    and "rebuild the Traditional from the corrected Simplified" are about
>    **梁家鏗譯本 (`biblexg-v2*`)** — `docs/梁家鏗譯本-請教出版方.md` is the
>    letter, and its title says so. They have nothing to do with
>    `cuvs-yhwh-tr.json`. **So §A and §C are NOT gated by the publisher and
>    never were.** My "don't start, the rebuild will overwrite it" warning was
>    wrong for the CUV work.
> 2. **I quoted a verdict the queue had already retracted.** For 蹟/跡 and
>    鍊/鏈 the queue table now reads `~~蹟/跡~~ … **this verdict was WRONG —
>    see below**`, and the text below it says these are *"NOT edition
>    preferences … the same one-to-many collapse as every fixed instalment."*
>    I grepped for the old sentence and never read far enough to see the
>    strikethrough. Item 3 is a real defect, not a preference.
>
> Also: **item 13 (NASB) is not an editorial decision. It is a live
> exposure** — see below. And items 5 and 6 turn out to be defects with one
> sensible repair each, not rulings.

---

## ⚠️ First — item 13 is not like the others

Measured against prod just now:

```
https://yahwehword.com/assets/assets/nasb.json  →  HTTP 200, 7,215,432 bytes
assets/nasb.json  →  31,090 verses
```

The Lockman Foundation's gratis-use policy caps quotation at **1,000 verses**,
and separately states that no more than 1,000 verses may be **stored in an
electronic retrieval system**. A publicly fetchable 31,090-verse JSON is
outside that on both clauses. README currently claims *"used under the
publisher's free-quotation provisions"* — that claim does not hold at this
size.

**This is a decision, but not a leisurely one:** obtain a written licence from
Lockman, or drop `nasb.json` from the public web build. I have not touched it
— removing a translation is your call — but it should not wait behind glyph
policy. *(I verified the URL, byte count and verse count myself. I have not
independently re-read Lockman's policy text; that clause summary is Fable's,
and worth your own look before you act.)*

---

## A. Traditional glyph policy — now 1 real ruling, not 4

| pair | ours | witness | verdict |
|---|---|---|---|
| 兇 / 凶 | 48 兇, 0 凶 | 11 兇 / 37 凶 (mixed) | **your call** |
| 剋 / 克 | 0 剋, 23 克 | witness keeps 剋 5 of 6 | not a defect |
| 蹟 / 跡 | 0 蹟, 103 跡 | **95 蹟, 8 跡** | **defect — fix** |
| 鍊 / 鏈 | 0 鍊, 60 鏈 | **62 鍊, 1 鏈** | **defect — fix** |

1. **兇 → 凶?** *Genuinely your call, and genuinely close.* Both forms are
   legitimate; the witness is itself mixed (11/37), so there is no clean rule
   to copy; modern Taiwan usage favours 兇 in 兇手/兇惡/兇猛. Fable's
   recommendation: **don't** — 48 verses of churn for no reader benefit.
   Revisit only as part of a full per-position witness diff.
2. **剋 — is zero correct?** **Yes, nothing to do.** 克制 is the MOE standard.
   Not your call; it was never a defect.
3. **蹟/跡 and 鍊/鏈 — restore the distinction?** **Yes.** Two witnesses agree
   this is a converter collapse, and 神跡 is the non-standard spelling for a
   Traditional reader where 神蹟 is what every Traditional Bible prints.
   Implement as a **per-position copy of the witness**, not a blanket
   replace — the 8 legitimate 跡 and 1 鏈 must survive. ~163 scripture
   positions plus the tagged corpus and lexicon.
4. **Do the sermons follow?** **No ruling needed — they are already correct.**
   `sermons/zh-TW` already distinguishes 神蹟/痕跡 and 鍛鍊/鎖鏈; my "83 files"
   was the count of files *containing* 蹟, i.e. files already right. The one
   real sermon defect is the **17 wrong 幹** (幹枯/幹淨/幹擾) — that is work,
   not a decision, and my first version omitted it.

> **貴胄 / 貴冑 is ANSWERED.** All 26 positions take 貴胄 (a noble scion);
> 和合本 renders "helmet" as 盔/頭盔/盔甲/鎧甲 with zero 甲冑 in 31,102 verses.
> Nothing to undo. Drop it from the blocked list.

---

## B. Verse numbering — 1 ruling, 3 defects

5. **路加福音 23:34a** — **not a policy call, a visible bug.** `biblexg`
   Luke 23:33 currently prints the literal characters `34a` inside the verse
   body, in both editions. Verified:
   > 「…右手一個，左手一個。**34a**耶穌說：父親啊，赦免他們…」

   The publisher marks it as a doubtful-passage affix, the same construct the
   repo already handles for 22:43, 22:44 and 23:17. Repair: strip the literal
   `34a` and render it as that affix. **Do not introduce sub-verse labels** —
   the app has no non-numeric verse label today and the sort problem is real.
6. **路加福音 21:30 — split.** Also not a policy call: highlights and notes
   key off the verse **id**, and splitting changes no id (21:29 keeps its id
   with shorter text; 21:30 gains text). The witness has a corrupt bare `a`
   at 21:30, so the merge is inherited damage, not an edition's division.
7. **約翰三書 1:14/15 — don't split.** The CUV genuinely has 14 verses
   (KJV versification), and `originals_versification.json` already maps
   `3_john 1:14 → [1:14, 1:15]`. The fix is in the cross-reference lookup.
   Code work, no ruling.
8. **創 45:10 「你和你我兒子孫子」 — this is the real one.** My first version
   framed it as "the printed 1919 says 你我, so changing it emends the CUV."
   **That premise does not survive checking.** Wikisource's "printed 1919" is,
   by its own index page, the CCIM digital e-text reformatted to 1919
   conventions, flagged as unproofread — nobody has looked at a 1919 page.
   The 你我 lineage is the same unproofread e-text family that carried the 16
   typos already repaired. Against it: the Hebrew has no first person, the
   ministry's own Strong's tagging puts no number on 我, and every published
   CUV checked reads 你的.

   **So the question is narrower than "may an app correct scripture":** it is
   *"do we follow our own source's typo?"* Fable recommends fixing it to
   你的, recorded explicitly as an emendation-with-reasons, and telling the
   ministry. **The philosophical version of this question is still yours** —
   but you are not overruling the 1919 printing, because nobody here has
   read the 1919 printing.

---

## C. Quotation marks — 1 ruling

Traditional and Simplified return **identical** numbers: 3438/3123 first
level, 665/642 second, 2336 imbalanced verses, 143 unclosed second-level
opens. The editions are mechanically parallel, so this is **one defect
appearing twice**.

Correction to my first version: I wrote "repair one and regenerate the other."
**There is no regenerator** — `fix_traditional_conversion.py` is a
never-applied draft, and every `repair_*.py` in the repo writes both editions
in one pass. Any fix must be written to both.

A verse-level imbalance is *expected* (CUV speech runs across verses), so
2,336 is not 2,336 bugs. The checkable set is the **143 unclosed second-level
opens**.

9. **Close the five 『 in Revelation's letters?** Punctuation was never part
   of the 1919 text — it is editorial by definition, and this edition already
   closes 『 in 642 of 665 places. Rule it **together with 3:7 and 3:14**
   (the queue says so; my first version dropped that): either all seven
   letters get 『…』 or none do. Low stakes, honestly close.

---

## D. Waiting on the publisher — 梁家鏗譯本, not the CUV

10. **The 427 Traditional wording differences** — your action is not a
    ruling, it is finishing the per-book review of §四之二 so the letter can
    go out.
11. **The 86 Simplified wording differences** — counted and settled; only
    awaiting the publisher's direction.
12. **The two official editions disagree** — drafted; ships with the letter.

These gate the **`biblexg-v2*`** rebuild only. Nothing in §A, §B or §C waits
on them.

---

## Decisions this page was missing

Fable flagged three, and they look right to me:

* **What is the baseline edition for `cuvs-yhwh`?** The repo alternates
  between "the ministry's module", "the two 新標點 witnesses", and "the
  printed 1919" — and the last is actually the CCIM e-text. **This one ruling
  settles item 8 and ~11 other queued lineage positions** (意料/逆料, 留/等,
  消息/信息 …) that this page never listed. Probably the highest-leverage
  decision here.
* **Should the ministry (孙树民 / yahwehdehua.net) be told** about the typos
  found in their module? There is a letter for 梁家鏗 and none for the
  edition the app is named after.
* **Rename the "printed 1919" witness** in `tools/audit_print_witness.py` and
  the queue. Decisions that rested on it alone should be re-marked as resting
  on an e-text.

---

## Suggested order

1. **NASB** — live exposure, not an editorial nicety.
2. **Baseline-edition ruling** — unblocks item 8 and ~11 more at once.
3. **Finish §四之二** so 10–12 leave your desk.
4. Then **6, 5, 3** — none touch a gated asset, and 6 and 5 fix things
   readers can see today.

Re-run the census any time; it writes nothing:

```bash
python3 tools/audit_p0.py
```
