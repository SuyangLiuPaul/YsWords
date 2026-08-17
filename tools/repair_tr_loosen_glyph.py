#!/usr/bin/env python3
"""Restore 鬆 (loosen) in the Traditional CUV, where the converter wrote 松.

Eighth instalment of the same defect. `assets/cuvs-yhwh-tr.json` is a script
conversion of the Simplified edition, and the converter that produced it had
holes: it never once wrote 隻, 淨, 牆, 餘, 髮, 鬍, 鬚, 採, 麵, 罈, 穀 … or 鬆.
Simplified 松 collapses two distinct traditional characters — 松 (the pine) and
鬆 (loose, slack, to let go) — and the converter resolved every one of them to
the tree. So 申命記 15:8 「總要向他松開手」, 約伯記 27:6 「必不放松」,
以賽亞書 58:6 「不是要松開兇惡的繩」 and 使徒行傳 16:26 「鎖鏈也都松開了」 all
print the pine.

WHY THIS IS A HOLE AND NOT AN EDITORIAL PREFERENCE
  Ours has 51 松 and ZERO 鬆 across 31,102 verses. The witness has 27 松 and
  24 鬆, and 51 = 27 + 24 exactly. A file that never once wrote the character
  did not choose against it.

THE PARTITION IS VISIBLE WITHOUT THE WITNESS, WHICH IS WHY IT IS SAFE
  Unlike 發/髮 or 谷/穀, where the correct reading is the majority and each
  position had to be argued, all 51 occurrences here sit in one of ten fixed
  collocations, and the two groups are disjoint and exhaustive:

      pine, keep 松 (27)   松香 1, 松木 8, 松類 3, 松樹 13, 杜松 2
      loosen, set 鬆 (24)  松緩 1, 松手 2, 松開 7, 輕松 6, 放松 8

  Every verse holds exactly one, so no verse mixes the two and no offsetting
  pair is arithmetically possible. The repair is still decided position by
  position against the witness — the collocations are used to AUDIT the
  result, never to produce it — but the audit does not depend on the witness
  at all, which no previous instalment could say.

INDEPENDENT CORROBORATION, recorded because the witness is one source
  * 新譯本 Traditional (git blob 57c4686), a different translation: of our 27
    pine verses NONE has 鬆, and of our 24 loosen verses NONE has 松. It
    carries 松 in 19 of the 27 and 鬆 in 13 of the 24; the remainder simply
    word the line differently (歌斐木 for gopher wood, 羅騰 for juniper).
  * KJV, on all 24: loosed / let loose / slack / release / ease / lighter /
    let it go / withdraw not / weakeneth / take off the yoke / respite. On the
    27: fir tree / pine tree / juniper / heath / gopher wood.
  * 梁家鏗's independent Traditional NT (`assets/biblexg-v2-tr.json`) reads
    使徒行傳 27:40 「鬆脫錨鏈，同時鬆開舵繩」; his 16:26 avoids the word
    (「鎖鏈全部脫落」), so it neither confirms nor contradicts.

NOTHING TO DO ON THE SIMPLIFIED OR TAGGED SIDE
  Simplified 松 is the correct single form for both meanings, and both
  `assets/cuvs-yhwh.json` and the tagged Strong's corpus are Simplified —
  they read 51 松 / 0 鬆, which is right. This instalment touches the
  Traditional asset only.

Dry-run by default; --apply writes. Re-running after --apply is safe.
"""
from __future__ import annotations

import argparse
import collections
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TR = ROOT / "assets/cuvs-yhwh-tr.json"
WITNESS_BLOB = "7a2dc43"

TRAD = "鬆"
SOURCE = "松"

# The ten collocations that account for all 51 occurrences. Used to audit the
# result, never to decide it.
PINE_CUES = ("松香", "松木", "松類", "松樹", "杜松")
LOOSEN_CUES = ("鬆緩", "鬆手", "鬆開", "輕鬆", "放鬆")


def confirm(text: str, i: int, ch: str, witness: str) -> str | None:
    """Strongest witness evidence for reading position `i` as `ch`, or None."""
    for w in (8, 6, 4, 3, 2, 1):
        # Only two-sided if there is text on both sides: at a verse boundary
        # this degenerates into a one-sided match and must not be labelled as
        # stronger evidence than it is.
        if i >= w and len(text) >= i + 1 + w:
            if text[i - w:i] + ch + text[i + 1:i + 1 + w] in witness:
                return f"ctx{w}"
    for w in (4, 3, 2, 1):
        if i >= w and text[i - w:i] + ch in witness:
            return f"left{w}"
        if len(text) >= i + 1 + w and ch + text[i + 1:i + 1 + w] in witness:
            return f"right{w}"
    return None


def cue_total(corpus: str, cues: tuple[str, ...]) -> int:
    return sum(corpus.count(c) for c in cues)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--report", default="")
    args = ap.parse_args()

    verses = json.loads(TR.read_text(encoding="utf-8"))
    witness = {
        v["id"]: v["text"]
        for v in json.loads(subprocess.run(
            ["git", "cat-file", "-p", WITNESS_BLOB], cwd=ROOT,
            capture_output=True, text=True, check=True).stdout)
    }

    before = "".join(v["text"] for v in verses)
    expected = sum(t.count(TRAD) for t in witness.values())

    # Every verse the witness sets the word in must be a verse we hold too,
    # otherwise the repair could not reach it and the totals below would be
    # satisfied by the wrong positions.
    ours_ids = {v["id"] for v in verses if SOURCE in v["text"] or TRAD in v["text"]}
    for vid, wit in witness.items():
        if (TRAD in wit or SOURCE in wit) and vid not in ours_ids:
            print(f"  ✗ witness sets 松/鬆 at {vid}, which holds neither here "
                  f"— refusing")
            return 1

    tiers: collections.Counter[str] = collections.Counter()
    report: list[str] = []
    changed = 0

    for v in verses:
        text = v["text"]
        wit = witness.get(v["id"], "")
        if TRAD not in wit:
            continue
        # The two editions must agree on how many of the word this verse
        # holds, otherwise the witness is not talking about the same sentence.
        # Counted over both forms so the check still holds once applied.
        ours_n = text.count(SOURCE) + text.count(TRAD)
        wit_n = wit.count(SOURCE) + wit.count(TRAD)
        if ours_n != wit_n:
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — ours holds "
                  f"{ours_n} 松/鬆, witness {wit_n} — refusing")
            return 1
        out = list(text)
        here = 0
        for i, ch in enumerate(text):
            if ch != SOURCE:
                continue
            loose = confirm(text, i, TRAD, wit)
            kept = confirm(text, i, SOURCE, wit)
            if loose and kept:
                print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — the "
                      f"witness reads 「{text[max(0, i - 8):i + 8]}」 both ways "
                      f"— refusing")
                return 1
            if not loose:
                continue
            out[i] = TRAD
            here += 1
            changed += 1
            tiers[loose[:3]] += 1
            report.append(f"{v['book']} {v['chapter']}:{v['verse']}\t{loose}\t"
                          f"…{text[max(0, i - 8):i + 8]}…")
        if here + text.count(TRAD) != wit.count(TRAD):
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — confirmed "
                  f"{here + text.count(TRAD)} loosenings, witness has "
                  f"{wit.count(TRAD)} — refusing")
            return 1
        v["text"] = "".join(out)

    after = "".join(v["text"] for v in verses)

    if len(before) != len(after):
        print("  ✗ the corpus changed length — refusing")
        return 1
    blind = str.maketrans({TRAD: "\0", SOURCE: "\0"})
    if before.translate(blind) != after.translate(blind):
        print("  ✗ something other than 松/鬆 changed — refusing")
        return 1
    if before.count(SOURCE) + before.count(TRAD) != after.count(SOURCE) + after.count(TRAD):
        print("  ✗ the 松/鬆 total moved — refusing")
        return 1
    if changed + before.count(TRAD) != expected:
        print(f"  ✗ {changed + before.count(TRAD)} 鬆 against {expected} in "
              f"the witness — refusing")
        return 1
    # Rules out an offsetting pair inside a single verse: the ordered sequence
    # of pines and loosenings must match the witness verse for verse, not
    # merely the counts.
    for v in verses:
        wit = witness.get(v["id"])
        if wit is None:
            continue
        keep = SOURCE + TRAD
        if [c for c in v["text"] if c in keep] != [c for c in wit if c in keep]:
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — the 松/鬆 "
                  f"sequence disagrees with the witness — refusing")
            return 1
    # The audit that does not depend on the witness: the ten collocations must
    # account for every occurrence, with none left straddling the two groups.
    pine, loosen = cue_total(after, PINE_CUES), cue_total(after, LOOSEN_CUES)
    if pine != after.count(SOURCE) or loosen != after.count(TRAD):
        print(f"  ✗ the collocations account for {pine} 松 and {loosen} 鬆 "
              f"against {after.count(SOURCE)} and {after.count(TRAD)} in the "
              f"corpus — refusing")
        return 1
    if cue_total(after, tuple(c.replace(TRAD, SOURCE) for c in LOOSEN_CUES)):
        print("  ✗ a loosening still reads 松 — refusing")
        return 1

    print(f"  {changed} substitutions →鬆 (witness has {expected} 鬆; before: "
          f"{before.count(SOURCE)} 松, {before.count(TRAD)} 鬆 → after: "
          f"{after.count(SOURCE)} 松, {after.count(TRAD)} 鬆)")
    print(f"  confirmation: {dict(sorted(tiers.items()))}")
    print(f"  collocations: {pine} pine, {loosen} loosening, "
          f"{pine + loosen} of {after.count(SOURCE) + after.count(TRAD)}")

    if args.report:
        Path(args.report).write_text("\n".join(report) + "\n", encoding="utf-8")
        print(f"  full diff ({len(report)} lines) → {args.report}")

    if args.apply:
        TR.write_text(json.dumps(verses, ensure_ascii=False, indent=2) + "\n",
                      encoding="utf-8")
        print(f"  written → {TR.relative_to(ROOT)}")
    else:
        print("  dry run — nothing written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
