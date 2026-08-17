#!/usr/bin/env python3
"""Restore 麵 (flour) in the Traditional CUV, where the converter wrote 面.

Fifth instalment of the same defect. `assets/cuvs-yhwh-tr.json` is a script
conversion of the Simplified edition, and the converter that produced it had
holes: it never once wrote 隻, 淨, 牆, 餘, 髮, 鬍, 鬚, 採 … or 麵. Simplified 面
collapses two distinct traditional characters — 面 (face, surface, side) and 麵
(flour, dough, noodles) — and the converter resolved every one of them to 面. So
「一伊法細麵」, the substance of the grain offering all through 利未記 and
民數記, reads 「一伊法細面」 — an ephah of *face*. 摶麵盆 (kneadingtrough) reads
摶面盆, and 「一點麵酵能使全團發起來」 reads 面酵.

WHY THIS IS NOT A BLANKET SUBSTITUTION, and could not be
  Unlike 淨/牆/餘, 面 is overwhelmingly CORRECT here: 2,184 occurrences of which
  only 107 are flour. 面前, 臉面, 前面, 四面, 地面, 海面 must not move. The claim
  is therefore not "面 is 麵" but "these 107 positions are 麵", and each has to be
  decided on its own evidence. This is the 發/髮 shape, not the 淨/牆 shape.

THE WITNESSES
  `assets/cuv-tr.json`, the plain 和合本 Traditional (耶和華, not 雅偉), a
  separately imported edition of the same base text, dropped from the repo at
  v1.4.5 and permanently readable as git blob 7a2dc43. It holds 107 麵 / 2,073 面
  in 90 verses, against our 0 / 2,184.

  The partition is what makes this a converter hole and not an editorial
  choice: ours has ZERO 麵 across 31,102 verses. A file that never once wrote
  the character did not decide against it.

  In all 90 verses where the witness has 麵, our count of 面 equals its count of
  面 plus 麵 — the two editions agree on how many of the word there are and
  differ only on the script. That per-verse equality is asserted below.

HOW EACH OCCURRENCE IS DECIDED
  Substitute 麵 into the surrounding context and look for it verbatim in the
  witness's verse; then do the same leaving 面 in place. An occurrence is taken
  as flour ONLY if the first matches and the second does not, so any position the
  witness cannot separate is refused rather than guessed. All 107 resolve — 104
  on a context window of 6–8 characters either side, 3 on the left side only —
  and not one is ambiguous.

THE AUDIT THAT WOULD CATCH A MISSED ONE
  The witness can only vote on verses it shares wording with. So after
  substitution the whole corpus is swept for flour collocations that still read
  面 — 細面, 麥面, 磨面, 面酵, 面餅, 摶面, 面伊法 … — and the run is refused if
  any survives. Before the repair that sweep finds every one of the 107; after
  it, none. Nothing outside the witness's 90 verses fires, which is the useful
  half of the result: there is no flour verse the witness failed to cover.

THE ONE ARITHMETIC HOLE, and why it is closed
  The per-verse count check above would still pass if the repair converted a
  *face* position and missed a *flour* one in the same verse — the totals would
  balance. That can only happen in a verse holding both glyphs, and across the
  whole corpus there is exactly ONE: 士師記 6:19, 「用一伊法細麵做了無酵餅 …
  獻在使者面前」. The repair converts 細麵 and leaves 面前. Every other one of the
  90 verses has flour readings only, so a swap has nowhere to hide.

INDEPENDENT CORROBORATION, recorded here because the witness is one source
  * KJV: 83 of the 90 verses carry flour / meal / leaven / dough / bread /
    kneadingtrough / lump / cake / wafer. (The figure is word-list dependent —
    出 8:3 needs "kneadingtroughs" and 羅 11:16 needs "lump" to qualify.) The
    seven that do not are all still flour on inspection: 利 5:13 is "the
    remnant" of the meal offering, 申 28:5 and 28:17 are 摶麵盆 rendered "thy
    store", and 結 45:24 / 46:5, 7, 11 are "a meat offering of an ephah".
  * 新譯本 Traditional (git blob 57c4686), a different translation and so an
    independent vote on whether a passage is about flour: it has 麵 in 86 of the
    90. The four it lacks it words without the noun at all — 申 16:4 「不可見有
    酵」, 撒下 16:1-2 「兩百個餅」/「餅」, 利 5:13 「其餘的祭物」.

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

SIMP, TRAD = "面", "麵"

# Collocations in which 面 can only be flour. Used to audit the result, never to
# decide it.
FLOUR_CUES = (
    "細面", "麥面", "磨面", "粗面", "新面", "面酵", "面餅", "面伊法",
    "摶面", "面摶", "把面", "面撒", "點面來", "剩下的面", "罈內的面",
)
# …and the readings that make a cue fire on a genuine 面.
CUE_EXCEPTIONS = ("著面來", "裏面必", "裡面必")


def confirm(text: str, i: int, ch: str, witness: str) -> str | None:
    """Strongest witness evidence for reading position `i` as `ch`, or None."""
    for w in (8, 6, 4, 3, 2, 1):
        if text[max(0, i - w):i] + ch + text[i + 1:i + 1 + w] in witness:
            return f"ctx{w}"
    for w in (4, 3, 2, 1):
        if i >= w and text[i - w:i] + ch in witness:
            return f"left{w}"
        if len(text) >= i + 1 + w and ch + text[i + 1:i + 1 + w] in witness:
            return f"right{w}"
    return None


def flour_cue_hits(corpus: str) -> list[str]:
    hits = []
    for cue in FLOUR_CUES:
        start = 0
        while (j := corpus.find(cue, start)) != -1:
            start = j + 1
            window = corpus[max(0, j - 3):j + len(cue)]
            if any(x in window for x in CUE_EXCEPTIONS):
                continue
            hits.append(corpus[max(0, j - 8):j + len(cue) + 6])
    return hits


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
    tiers: collections.Counter[str] = collections.Counter()
    report: list[str] = []
    changed = 0

    for v in verses:
        text = v["text"]
        wit = witness.get(v["id"], "")
        if TRAD not in wit:
            continue
        # The two editions must agree on how many of the word this verse holds,
        # otherwise the witness is not talking about the same sentence. Counted
        # over both forms so the check still holds once the repair is applied.
        if (text.count(SIMP) + text.count(TRAD)
                != wit.count(SIMP) + wit.count(TRAD)):
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — ours has "
                  f"{text.count(SIMP)} 面 + {text.count(TRAD)} 麵, witness "
                  f"{wit.count(SIMP)} 面 + {wit.count(TRAD)} 麵 — refusing")
            return 1
        out = list(text)
        here = 0
        for i, ch in enumerate(text):
            if ch != SIMP:
                continue
            flour = confirm(text, i, TRAD, wit)
            face = confirm(text, i, SIMP, wit)
            if flour and face:
                print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — the "
                      f"witness reads 「{text[max(0, i - 8):i + 8]}」 both ways "
                      f"— refusing")
                return 1
            if not flour:
                continue
            out[i] = TRAD
            here += 1
            changed += 1
            tiers[flour[:3]] += 1
            report.append(f"{v['book']} {v['chapter']}:{v['verse']}\t{flour}\t"
                          f"…{text[max(0, i - 8):i + 8]}…")
        if here + text.count(TRAD) != wit.count(TRAD):
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — confirmed "
                  f"{here + text.count(TRAD)} flour, witness has "
                  f"{wit.count(TRAD)} — refusing")
            return 1
        v["text"] = "".join(out)

    after = "".join(v["text"] for v in verses)

    if len(before) != len(after):
        print("  ✗ the corpus changed length — refusing")
        return 1
    blind = str.maketrans({SIMP: "\0", TRAD: "\0"})
    if before.translate(blind) != after.translate(blind):
        print("  ✗ something other than 面/麵 changed — refusing")
        return 1
    if after.count(SIMP) != before.count(SIMP) - changed:
        print("  ✗ the 面 count did not fall by exactly the number of "
              "substitutions — refusing")
        return 1
    if changed + before.count(TRAD) != expected:
        print(f"  ✗ {changed + before.count(TRAD)} 麵 against {expected} in "
              f"the witness — refusing")
        return 1
    leftover = flour_cue_hits(after)
    if leftover:
        print(f"  ✗ {len(leftover)} flour collocations still read 面 — refusing")
        for s in leftover[:10]:
            print(f"      …{s}…")
        return 1

    print(f"  {changed} substitutions 面→麵 "
          f"(witness has {expected} 麵; before: {before.count(SIMP)} 面, "
          f"{before.count(TRAD)} 麵 → after: {after.count(SIMP)} 面, "
          f"{after.count(TRAD)} 麵)")
    print(f"  confirmation: {dict(sorted(tiers.items()))}")
    print(f"  flour collocations still reading 面: "
          f"{len(flour_cue_hits(before))} before → {len(leftover)} after")

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
