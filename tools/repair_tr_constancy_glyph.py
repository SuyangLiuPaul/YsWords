#!/usr/bin/env python3
"""Restore 恆 (constant/enduring) in the Traditional CUV, where the converter
wrote 恒.

Twelfth instalment of the same defect. `assets/cuvs-yhwh-tr.json` is a script
conversion of the Simplified edition, and the converter that produced it had
holes: it never once wrote 隻, 淨, 牆, 餘, 髮, 鬍, 鬚, 採, 麵, 罈, 穀, 鬆, 乾, 干,
卜 … or 恆. So Bethlehem is spelt 伯利恒 in a Traditional Bible — 彌迦書 5:2
「伯利恒、以法他啊」, 路加福音 2:4 and every one of the nativity references —
and so is every 恆心 / 恆久 / 恆切: 箴言 11:19 「恒心為義的」, 使徒行傳 1:14
「都同心合意的恒切禱告」, 羅馬書 2:7 「恒心行善」.

恒 is the character the mainland standard adopted; 恆 is the form in both the
Taiwan (教育部標準字體) and Hong Kong lists, and it is what every published
Traditional 和合本 sets. This is not a variant preference in this file, it is a
hole — see below.

WHY THIS IS A HOLE AND NOT AN EDITORIAL PREFERENCE
  Before this repair ours held 79 恒 and ZERO 恆 across 31,102 verses. The
  witness holds 79 恆 and ZERO 恒. That is a partition, not a preference: a file
  that never once wrote the character in 31,102 verses did not choose against
  it. There is no hypothesis left in which an editor picked 恒 seventy-nine
  times and 恆 never.

WHY THIS ONE NEEDS NO PER-POSITION JUDGEMENT
  Unlike 發/髮, 谷/穀 or 干/乾/幹 — where our form was ALSO correct hundreds or
  thousands of times, so only some positions moved — neither side here has a
  correct-in-our-form case to protect: the witness holds no 恒 at all. The two
  characters are the same word, not two words sharing a Simplified form, so
  there is no meaning to decide. The class moves whole.

  This script still checks that position by position rather than asserting it:
  every verse's 恒+恆 count must equal the witness's 恆 count (agrees on all
  31,102 verses — zero mismatches), and afterwards the ordered sequence of the
  two forms must match the witness verse for verse.

  Independently of the witness, all 79 were read in context: 54 are the place
  name 伯利恒 (Bethlehem), one is the name 雅叔比利恒 (Jashubi-lehem, 代上 4:22),
  and the remaining 24 are 恆久 ×8 / 恆心 ×8 / 恆切 ×4 / 恆常 / 恆守 / 恆忍 and
  詩篇 89:36 「如日之恆一般」, where it stands alone. There is no third reading
  and no name in which 恒 would be right.

INDEPENDENT CORROBORATION, recorded because the witness is one source
  * `assets/biblexg-v2-tr.json` — 梁家鏗's separately produced Traditional NT,
    not a conversion of anything in this repo — has 32 恆 and ZERO 恒, all
    伯利恆.
  * 新譯本 Traditional (git blob 57c4686), a different translation: 79 恆,
    ZERO 恒. (The totals matching is coincidence — it is a different rendering
    of a different base — so the load-bearing part is the zero.)
  * Our own Simplified `assets/cuvs-yhwh.json` (79 恒, 0 恆) and the tagged
    Strong's corpus under `assets/tagged/` (79 恒, 0 恆) are Simplified and
    correctly write 恒. Nothing to do on either side.

SCOPE — THE VERSE ASSET ONLY
  `assets/sermons/zh-TW/` was produced by a different, phrase-aware converter
  which does not have this defect (276 恆 against 2 恒) and must not be swept by
  a repo-wide substitution; its two stray 恒 are spot errors belonging to the
  separate sermon item in the queue. `assets/bible_evidence.json` has 42 恒 in
  its zh-Hant fields, but those fields hold wholly Simplified prose — a bigger
  and different defect, also queued separately. This script only ever opens the
  file named in TR.

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

TRAD = "恆"
SOURCE = "恒"

# Every reading the 79 occurrences actually take, spelt out at full phrase
# length. Used to audit the result, never to decide it. 利恒 rather than 伯利恒
# so that 雅叔比利恒 (代上 4:22) is covered too — with 伯利恒 the audit silently
# reached 78 of 79.
READING_CUES = (
    "利恒", "恒心", "恒久", "恒切", "恒常", "恒忍", "恒守", "恒一",
)


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
    # our form anywhere. If it held even one 恒 this would be a split like
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
