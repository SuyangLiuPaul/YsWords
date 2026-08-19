#!/usr/bin/env python3
"""Put nine verses back into the order the CUV prints them in.

箴言 22:11 read 「因他嘴的恩言，王必與他為上友」. 為上友 is not a word in
any register of Chinese; 上 belongs one clause earlier, in 嘴上的恩言.
尼希米記 8:4 read 「木臺上。站瑪他提雅…和瑪西雅在他的右邊」 — a verb
stranded in front of a name list, and a prepositional phrase left with
nothing to govern it, while the SAME VERSE gets the identical clause right
eight names later: 「和米書蘭站在他的左邊」.

使徒行傳 26:16 read 「你起來站著，特意向你我顯現」. 向你我 occurs in exactly
one verse of 31,102 — this one — and its only natural reading is the compound
"to you and me", which is false: Jesus is speaking to Paul alone.

Every one of the nine is a PERMUTATION: no character is added and none is
lost, which is why they survived `audit_dropped_characters.py` — that check
compares the set of ideographs, and a swap leaves it untouched.

`audit_inserted_characters.py` is the exception, and it was measured rather
than assumed: it diffs POSITIONALLY, so a moved character reads as an
insertion where it arrived. 使徒行傳 26:16 was reported there as extra 我@9
for as long as it was broken, and it is the only one of the nine that was.

WHY THIS IS SAFE TO WRITE
  Reordering scripture is as dangerous as inserting it, so each verse was
  settled on four independent lines before anything was written:

  1. `SeekSparks/assets/cuvs-plus.json`, a separate Simplified import.
  2. `assets/cuv-tr.json`, a separately imported Traditional 和合本, dropped
     from the repo at v1.4.5 and permanently readable as git blob 7a2dc43.
     Witnesses 1 and 2 disagree with each other in 5,338 of 31,101 verses.
  3. The Wikisource transcription of the PRINTED 1919 text — fetched per
     verse, and it decided two that the first two could not:

       馬太福音 6:2   of the 42 tagged runs carrying ἔμπροσθεν (G1715), 26
                      spelt it 面前 and 2 spelt it 前面; corpus-wide it was
                      面前 1,186 to 前面 77. Frequency argued for keeping
                      ours. The print reads 「不可在你前面吹號」.
       使徒行傳 24:16 both orders are ordinary Chinese and our corpus reads
                      因此我 25 times to 我因此 once. The print reads
                      「我因此自己勉勵」 — and the one 我因此 is 耶利米書 2:9,
                      so the reordering leaves the phrase attested, not
                      invented.

     Neither would have been safe on the two witnesses alone.
  4. Evidence internal to this repo, which is independent of all three
     because it was imported separately:

       俄巴底亞書 1:5  is the parallel of 耶利米書 49:9, and OUR OWN asset
                      prints the same clause correctly there:
                      「摘葡萄的若來到他那裏」. Ours reads 若到來 in Obadiah.
       馬太福音 25:20 our Traditional file ALREADY reads 那另外的五千來,
                      our Simplified reads 那另外五千的來, and the tagged
                      corpus reads 五的千 — the same clause scrambled three
                      different ways in three of our own files. The print
                      and both witnesses agree with the Traditional.
       尼希米記 8:4   the tagged corpus already has 站 in the right place.
       箴言 22:11     嘴 is tagged H8193 (שָׂפָה, lip) and 友 H7453 (רֵעַ,
                      friend). 上 attached to neither.

  使徒行傳 26:16 got a FIFTH line, and it is the strongest kind: SeekSparks
  tags `cuvs-plus` independently of everything above, and its segmentation of
  this verse is 你起来 / 站着 / ， / 我 / 特意 / 向你 / 显现 — the printed
  order, with 我 already standing as its own run. Its Strong's number for that
  run (G1519, εἰς) is an alignment artifact of a strictly left-to-right
  pairing and is NOT copied here: our own tagger already folds εἰς into 特意
  as i:["G1519"], so tagging 我 with it would count the preposition twice.

ONE THAT COMES OFF THE LIST BY BEING MEASURED
  This is the last of the class. Scanning all 31,102 verses for permutations
  against both witnesses leaves three: 耶利米書 7:14 (below, do not fix),
  那鴻書 3:4 (a note placement, settled separately) and this one.

ONE THAT WAS ON THIS LIST AND CAME OFF IT — do not "fix" it
  耶利米書 7:14 reads 稱我為名下 where both witnesses read 稱為我名下. The
  printed 1919 sides with OURS. Recorded in `audit_dropped_characters.py`.

Run with --apply to write; without it, reports and changes nothing.
"""
import argparse
import json
import sys
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SIMPLIFIED = REPO / "assets/cuvs-yhwh.json"
TRADITIONAL = REPO / "assets/cuvs-yhwh-tr.json"

# Marks an output run that keeps only `w` and `s` — see TAGGED_REPAIRS.
BARE = "bare"

# id, reference, (simplified before, after), (traditional before, after)
REPAIRS = [
    ("001009011", "創世紀 9:11", ("毁坏了地。", "毁坏地了。"), ("毀壞了地。", "毀壞地了。")),
    (
        "016008004",
        "尼希米記 8:4",
        (
            "木台上。站玛他提雅、示玛、亚奈雅、乌利亚、希勒家，和玛西雅在他的右边",
            "木台上。玛他提雅、示玛、亚奈雅、乌利亚、希勒家，和玛西雅站在他的右边",
        ),
        (
            "木臺上。站瑪他提雅、示瑪、亞奈雅、烏利亞、希勒家，和瑪西雅在他的右邊",
            "木臺上。瑪他提雅、示瑪、亞奈雅、烏利亞、希勒家，和瑪西雅站在他的右邊",
        ),
    ),
    (
        "020022011",
        "箴言 22:11",
        ("因他嘴的恩言，王必与他为上友。", "因他嘴上的恩言，王必与他为友。"),
        ("因他嘴的恩言，王必與他為上友。", "因他嘴上的恩言，王必與他為友。"),
    ),
    ("031001005", "俄巴底亞書 1:5", ("若到来你那里", "若来到你那里"), ("若到來你那裏", "若來到你那裏")),
    ("040006002", "馬太福音 6:2", ("不可在你面前吹号", "不可在你前面吹号"), ("不可在你面前吹號", "不可在你前面吹號")),
    ("040025020", "馬太福音 25:20", ("那另外五千的来", "那另外的五千来"), ("那另外五千的來", "那另外的五千來")),
    ("044024016", "使徒行傳 24:16", ("因此我自己勉励", "我因此自己勉励"), ("因此我自己勉勵", "我因此自己勉勵")),
    (
        "044026016",
        "使徒行傳 26:16",
        ("特意向你我显现", "我特意向你显现"),
        ("特意向你我顯現", "我特意向你顯現"),
    ),
    (
        "045004023",
        "羅馬書 4:23",
        ("算为他的义”这句话", "算为他义”的这句话"),
        ("算為他的義」這句話", "算為他義」的這句話"),
    ),
]


# The Originals sheet prints the tagged runs INSTEAD of the verse, so the same
# reordering has to reach `assets/tagged/cuvs-yhwh/` or the word-tap panel goes
# on showing 為上友 after the reading pane stops. 尼希米記 8:4 is absent here:
# the tagged import already had 站 in the right place, which is part of why the
# reading asset is the one that is wrong.
#
# A run carries more than its Strong's number: `g` is the morphology code and
# `i` the original-language word the CUV renders without a separate Chinese
# word for it. An earlier draft of this tool rebuilt the runs from (text,
# Strong's) alone and silently dropped it in four verses: `g:["H8763"]` off
# 創世記 9:11's verb, `g:["H8804"]` off 俄巴底亞書 1:5's, `i:["G5007"]`
# (τάλαντον) off 馬太福音 25:20 and `i:["G5129"]` (τούτῳ) off 使徒行傳 24:16.
# The characters were right and the parsing data regressed, with nothing on
# screen to show it.
# So an output run names the INPUT run it inherits from and keeps every field
# but the text.
#
# An output may instead be marked BARE, which keeps only `w` and `s`. That is
# the ONE way a run carrying `i`/`g` may be split: exactly one half stays
# whole and the rest come out bare, so the parsing data lands on one word
# instead of being copied onto two. 使徒行傳 26:16 is the case it exists for —
# 我 and 顯現 together render ὤφθην, one Greek word that carries its subject
# in the inflection, and the aorist-passive code belongs to the verb.
#
# slug, ref, contiguous run texts before, runs after as (text, index in
# before) or (text, index in before, BARE)
TAGGED_REPAIRS = [
    ("genesis", "9:11", ["毁坏了", "地。”"], [("毁坏", 0), ("地了。”", 1)]),
    # 上 crosses three runs to get back to 嘴, so the whole span is one edit —
    # split in two, neither half balances and the permutation guard rejects it.
    (
        "proverbs",
        "22:11",
        ["心的人，因他嘴", "的恩", "言，王", "必与他为上友。"],
        [("心的人，因他嘴上", 0), ("的恩", 1), ("言，王", 2), ("必与他为友。", 3)],
    ),
    # 到 was glued to the conjunction 若 (H518); it belongs to 來 (H935, בּוֹא),
    # which is also where the perfect-tense code g:["H8804"] has to stay.
    ("obadiah", "1:5", ["若到", "来"], [("若", 0), ("来到", 1)]),
    ("matthew", "6:2", ["面前"], [("前面", 0)]),
    ("matthew", "25:20", ["那另外", "五的千"], [("那另外的", 0), ("五千", 1)]),
    # αὐτός is rendered by a discontinuous 我…自己 once 因此 sits between them,
    # so it takes two runs, both inheriting G846 from the run that held 我自己.
    # Tagging 我 as G1722 (ἐν τούτῳ) instead would answer "in this" to a reader
    # who taps the pronoun.
    ("acts", "24:16", ["因此", "我自己"], [("我", 1), ("因此", 0), ("自己", 1)]),
    # 我 renders no Greek word of its own — ὤφθην carries the first person in
    # its inflection — so it inherits G3700 from the run it is leaving rather
    # than picking up a number from its new neighbours. The tense code stays
    # on the verb.
    (
        "acts",
        "26:16",
        ["特意", "向你", "我显现，"],
        [("我", 2, BARE), ("特意", 0), ("向你", 1), ("显现，", 2)],
    ),
    ("romans", "4:23", ["的义”这"], [("义”的这", 0)]),
]


def is_permutation(before, after):
    return Counter(before) == Counter(after)


def repair(path, index, apply):
    verses = json.loads(path.read_text(encoding="utf-8"))
    by_id = {v["id"]: v for v in verses}
    changed = 0
    for vid, ref, *forms in REPAIRS:
        before, after = forms[index]
        verse = by_id[vid]
        text = verse["text"]
        if after in text:
            print(f"  {ref} already in printed order")
            continue
        if text.count(before) != 1:
            print(f"  FAIL {ref}: {before!r} occurs {text.count(before)}x", file=sys.stderr)
            return None
        # The only permitted edit is a reordering. A transposition that gains
        # or loses a character is a different defect and must not ride along.
        if not is_permutation(before, after):
            print(f"  FAIL {ref}: edit is not a permutation", file=sys.stderr)
            return None
        new = text.replace(before, after)
        if not is_permutation(text, new):
            print(f"  FAIL {ref}: verse is not a permutation of itself", file=sys.stderr)
            return None
        print(f"  {ref}: {before} → {after}")
        verse["text"] = new
        changed += 1
    if apply and changed:
        path.write_text(
            json.dumps(verses, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    return changed


def find_slice(runs, before):
    hits = [
        i
        for i in range(len(runs) - len(before) + 1)
        if [r.get("w") for r in runs[i : i + len(before)]] == before
    ]
    return hits


def repair_tagged(apply):
    changed = 0
    dirty = {}
    for slug, ref, before, after in TAGGED_REPAIRS:
        path = REPO / f"assets/tagged/cuvs-yhwh/{slug}.json"
        book = dirty.get(slug) or json.loads(path.read_text(encoding="utf-8"))
        dirty[slug] = book
        runs = book[ref]
        if find_slice(runs, [out[0] for out in after]):
            print(f"  {slug} {ref} already in printed order")
            continue
        hits = find_slice(runs, before)
        if len(hits) != 1:
            print(
                f"  FAIL {slug} {ref}: {before!r} matches {len(hits)} places",
                file=sys.stderr,
            )
            return None
        if not is_permutation("".join(before), "".join(out[0] for out in after)):
            print(f"  FAIL {slug} {ref}: edit is not a permutation", file=sys.stderr)
            return None
        i = hits[0]
        source = runs[i : i + len(before)]
        # Splitting one input run across two outputs would copy its `i`/`g` to
        # both and claim the original has the word twice. A run carrying more
        # than a Strong's number may still be split, but then exactly one half
        # inherits it and the rest are marked BARE.
        used = Counter(out[1] for out in after)
        for src, n in used.items():
            extra = set(source[src]) - {"w", "s"}
            whole = sum(1 for out in after if out[1] == src and BARE not in out[2:])
            if n > 1 and extra and whole != 1:
                print(
                    f"  FAIL {slug} {ref}: run {src} carries {sorted(extra)} and "
                    f"would be split {n} ways, {whole} of them keeping it",
                    file=sys.stderr,
                )
                return None
        after_runs = [
            {"w": out[0], "s": source[out[1]].get("s", "")}
            if BARE in out[2:]
            else {**source[out[1]], "w": out[0]}
            for out in after
        ]
        print(f"  {slug} {ref}: {''.join(before)} → {''.join(out[0] for out in after)}")
        runs[i : i + len(before)] = after_runs
        changed += 1
    if apply:
        for slug, book in dirty.items():
            (REPO / f"assets/tagged/cuvs-yhwh/{slug}.json").write_text(
                json.dumps(book, ensure_ascii=False, separators=(",", ":")),
                encoding="utf-8",
            )
    return changed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    total = 0
    for path, index in ((SIMPLIFIED, 0), (TRADITIONAL, 1)):
        print(f"{path.name}:")
        n = repair(path, index, args.apply)
        if n is None:
            return 1
        total += n
    print("tagged/cuvs-yhwh:")
    n = repair_tagged(args.apply)
    if n is None:
        return 1
    total += n
    print(f"\n{total} readings {'reordered' if args.apply else 'to reorder'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
