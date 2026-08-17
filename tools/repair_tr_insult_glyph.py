#!/usr/bin/env python3
"""Restore 凌 (to insult / ride roughshod over) in the Traditional CUV, where
the converter wrote 淩.

Thirteenth instalment of the same defect. `assets/cuvs-yhwh-tr.json` is a script
conversion of the Simplified edition, and the converter that produced it had
holes: it never once wrote 隻, 淨, 牆, 餘, 髮, 鬍, 鬚, 採, 麵, 罈, 穀, 鬆, 乾, 干,
卜, 恆 … or 凌. So every 凌辱 in the Traditional Bible is spelt 淩辱 —
士師記 19:25 「終夜淩辱她」, 撒母耳記上 31:4 「淩辱我」, 路加福音 6:28
「淩辱你們的，要為他禱告」 — and so is 欺淩 and the 淩遲 of 但以理書 2:5.

凌 is the standard form in the Taiwan (教育部標準字體) and Hong Kong lists and
is what every published Traditional 和合本 sets. 淩 is a rare variant used
almost only as a surname and in water senses; it is not the character of 凌辱,
欺凌 or 凌遲 in any of them. Note the direction of this one: unlike most of the
class, Simplified and Traditional agree — 凌 is ALSO the correct Simplified
form, and our Simplified asset writes it 37 times. The converter did not
simplify anything here, it corrupted a character that needed no conversion at
all.

WHY THIS IS A HOLE AND NOT AN EDITORIAL PREFERENCE
  Before this repair ours held 37 淩 and ZERO 凌 across 31,102 verses. The
  witness holds 37 凌 and ZERO 淩. That is a partition, not a preference: a file
  that never once wrote the character in 31,102 verses did not choose against
  it. There is no hypothesis left in which an editor picked 淩 thirty-seven
  times and 凌 never — least of all when our own Simplified edition of the same
  text writes 凌 in the same 37 places.

WHY THIS ONE NEEDS NO PER-POSITION JUDGEMENT
  Unlike 發/髮, 谷/穀 or 干/乾/幹 — where our form was ALSO correct hundreds or
  thousands of times, so only some positions moved — neither side here has a
  correct-in-our-form case to protect: the witness holds no 淩 at all. The one
  reading in which 淩 would be right is the surname, and no 淩 occurs anywhere
  in scripture as a name. The class moves whole.

  This script still checks that position by position rather than asserting it:
  every verse's 淩+凌 count must equal the witness's 凌 count (agrees on all
  31,102 verses — zero mismatches), and afterwards the ordered sequence of the
  two forms must match the witness verse for verse.

  Independently of the witness, all 37 were read in context and take exactly
  three readings: 凌辱 ×32, 欺凌 ×3 (代下 28:20, 詩 69:19, 箴 26:18) and 凌遲
  ×2 (但 2:5, 3:29). There is no fourth reading and no name.

INDEPENDENT CORROBORATION, recorded because the witness is one source
  * `assets/biblexg-v2-tr.json` — 梁家鏗's separately produced Traditional NT,
    not a conversion of anything in this repo — has 10 凌 in its verse text
    (欺凌 ×2, 凌辱 ×7, 凌駕) and ZERO 淩. Five more 凌 sit in its translator's
    notes, as 凌晨.
  * 新譯本 Traditional (git blob 57c4686), a different translation: 30 凌,
    ZERO 淩.
  * Our own Simplified `assets/cuvs-yhwh.json` (37 凌, 0 淩) and the tagged
    Strong's corpus under `assets/tagged/` (37 凌, 0 淩) already write the
    correct form. Nothing to do on either side.

SCOPE — THE VERSE ASSET ONLY
  This is the narrowest scope of any instalment so far: 淩 occurs in no other
  text file tracked in this repo. `assets/sermons/zh-TW/` (23 凌, 0 淩),
  `assets/section_titles.json` (2 凌) and `assets/bible_evidence.json` (2 凌)
  are already right. This script only ever opens the file named in TR.

  One historical copy shares the hole and is deliberately left alone: the
  retired LJK1 `assets/biblexg-tr.json` had 10 淩 / 0 凌, but it was deleted
  from the tree and dropped from the bundle at v1.4.5 (commit 69307c7), so
  nothing ships it. Stale pre-fix copies of the CUV asset also sit in the
  gitignored build outputs; those need a rebuild, not an edit.

Dry-run by default; --apply writes. Re-running after --apply is safe.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TR = ROOT / "assets/cuvs-yhwh-tr.json"
WITNESS_BLOB = "7a2dc43"

TRAD = "凌"
SOURCE = "淩"

# Every reading the 37 occurrences actually take, spelt out at full phrase
# length. Used to audit the result, never to decide it.
READING_CUES = ("淩辱", "欺淩", "淩遲")


def cue_hits(corpus: str) -> list[str]:
    hits = []
    for cue in READING_CUES:
        start = 0
        while (j := corpus.find(cue, start)) != -1:
            start = j + 1
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

    # The whole basis of "no judgement needed": the witness must hold none of
    # our form anywhere. If it held even one 淩 this would be a split like
    # 發/髮 and would have to be decided position by position instead.
    witness_all = "".join(witness.values())
    if witness_all.count(SOURCE) != 0:
        print(f"  ✗ the witness holds {witness_all.count(SOURCE)} {SOURCE} — "
              f"this is a split, not a partition — refusing")
        return 1

    report: list[str] = []
    changed = 0

    for v in verses:
        text = v["text"]
        if SOURCE not in text and TRAD not in text:
            continue
        wit = witness.get(v["id"])
        if wit is None:
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — no witness "
                  f"verse to confirm against — refusing")
            return 1
        # Counted over both forms so the check still holds once applied.
        if text.count(SOURCE) + text.count(TRAD) != wit.count(TRAD):
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — ours holds "
                  f"{text.count(SOURCE)} {SOURCE} + {text.count(TRAD)} {TRAD}, "
                  f"witness {wit.count(TRAD)} {TRAD} — refusing")
            return 1
        for i, ch in enumerate(text):
            if ch != SOURCE:
                continue
            changed += 1
            report.append(f"{v['book']} {v['chapter']}:{v['verse']}\t"
                          f"…{text[max(0, i - 8):i + 8]}…")
        v["text"] = text.replace(SOURCE, TRAD)

    after = "".join(v["text"] for v in verses)

    if len(before) != len(after):
        print("  ✗ the corpus changed length — refusing")
        return 1
    blind = str.maketrans({TRAD: "\0", SOURCE: "\0"})
    if before.translate(blind) != after.translate(blind):
        print(f"  ✗ something other than {TRAD}/{SOURCE} changed — refusing")
        return 1
    if after.count(SOURCE) != 0:
        print(f"  ✗ {after.count(SOURCE)} {SOURCE} survive the repair — "
              f"refusing")
        return 1
    if after.count(TRAD) != expected:
        print(f"  ✗ {after.count(TRAD)} {TRAD} against {expected} in the "
              f"witness — refusing")
        return 1
    # The strongest check available: the ordered sequence of the two forms must
    # match the witness verse for verse, not merely the totals.
    for v in verses:
        wit = witness.get(v["id"])
        if wit is None:
            continue
        keep = TRAD + SOURCE
        if [c for c in v["text"] if c in keep] != [c for c in wit if c in keep]:
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — the "
                  f"{TRAD}/{SOURCE} sequence disagrees with the witness — "
                  f"refusing")
            return 1
    leftover = cue_hits(after)
    if leftover:
        print(f"  ✗ {len(leftover)} readings still set {SOURCE} — refusing")
        for s in leftover[:10]:
            print(f"      …{s}…")
        return 1

    print(f"  {changed} substitutions →{TRAD} "
          f"(witness has {expected} {TRAD} and 0 {SOURCE}; before: "
          f"{before.count(SOURCE)} {SOURCE}, {before.count(TRAD)} {TRAD} → "
          f"after: {after.count(SOURCE)} {SOURCE}, {after.count(TRAD)} {TRAD})")
    print(f"  readings still setting {SOURCE}: "
          f"{len(cue_hits(before))} before → {len(leftover)} after")

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
