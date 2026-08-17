#!/usr/bin/env python3
"""Restore 症 (an illness) in the Traditional CUV, where the converter wrote 癥.

Fourteenth instalment of the same defect. `assets/cuvs-yhwh-tr.json` is a script
conversion of the Simplified edition, and the converter that produced it had
holes: it never once wrote 隻, 淨, 牆, 餘, 髮, 鬍, 鬚, 採, 麵, 罈, 穀, 鬆, 乾, 干,
卜, 恆, 凌 … or 症. So the whole of 利未記 15, the chapter on 漏症, is spelt
漏癥 — 「人若身患漏癥」 — and 馬太福音 4:23 has Jesus healing 各樣的病癥.

症 and 癥 are two different words that share the Simplified form 症. 症 is the
illness (病症, 漏症, 症狀); 癥 is zhēng, an abdominal mass, and in modern
Traditional it survives essentially only in 癥結, the crux of a matter. Taiwan
教育部 and the Hong Kong list both set 症 for the illness sense, and no
published Traditional 和合本 writes 漏癥. This is the same converter accident
as 蔔 for 卜: a Simplified-to-Traditional table picked the rarer of the two
expansions and applied it everywhere.

WHY THIS IS A HOLE AND NOT AN EDITORIAL PREFERENCE
  Before this repair ours held 26 癥 and ZERO 症 across 31,102 verses. The
  witness holds 26 症 and ZERO 癥. That is a partition, not a preference: a file
  that never once wrote the character in 31,102 verses did not choose against
  it. Our own Simplified edition of the same text writes 症 in the same 26
  places, and so does the tagged Strong's corpus.

WHY THIS ONE NEEDS NO PER-POSITION JUDGEMENT
  Unlike 發/髮, 谷/穀 or 干/乾/幹 — where our form was ALSO correct hundreds or
  thousands of times, so only some positions moved — neither side here has a
  correct-in-our-form case to protect: the witness holds no 癥 at all. The one
  reading in which 癥 would be right is 癥結, and no 癥結 occurs anywhere in
  scripture. The class moves whole.

  This script still checks that position by position rather than asserting it:
  every verse's 癥+症 count must equal the witness's 症 count (agrees on all
  31,102 verses — zero mismatches), and afterwards the ordered sequence of the
  two forms must match the witness verse for verse.

  Independently of the witness, all 26 were read in context and take exactly
  four readings: 漏癥 ×20 (利未記 ×18, plus 民數記 5:2 and 撒母耳記下 3:29),
  病癥 ×4 (申命記 7:15, 馬太福音 4:23, 9:35, 10:1), 火癥 ×1 (申命記 28:22) and
  熱癥 ×1 (哈巴谷書 3:5). There is no fifth reading, no 癥結 and no name.

  All 26 were also confirmed against the witness's same-id verse on a two-sided
  context window — characters on BOTH sides matched, none confirmed one-sided
  or on a bare count. The window is narrow in seven places and the figure is
  worthless without it: 19 match at 3 or more characters each side, four
  (利未記 15:9, 15:11, 15:12, 15:13) at 2, and three at 1 — 馬太福音 4:23, 9:35
  and 10:1 all end 各樣的病癥。 so there is nothing to the right but the stop.
  利未記 15:13 loses its left window at 3 because the witness opens the verse
  with 「 where ours does not.

INDEPENDENT CORROBORATION, recorded because the witness is one source
  * 新譯本 Traditional (git blob 57c4686), a different translation: 39 症,
    ZERO 癥.
  * Our own Simplified `assets/cuvs-yhwh.json` (26 症, 0 癥) and the tagged
    Strong's corpus under `assets/tagged/` (26 症, 0 癥) already write the
    correct form. Nothing to do on either side.
  * `assets/biblexg-v2-tr.json` — 梁家鏗's separately produced Traditional NT —
    gives NO corroboration here and is not claimed as any: it holds neither
    character, because it words 各樣的病症 as 各種疾病 at 馬太福音 4:23, 9:35
    and 10:1. Recorded so that a later instalment does not assume it agrees.

SCOPE — THE VERSE ASSET ONLY, AND HERE THAT MATTERS MORE THAN USUAL
  癥 is CORRECT elsewhere in this repo and a repo-wide sweep would corrupt it.
  `assets/sermons/zh-TW/105.txt` reads 「問題和真正的癥結」, which is the one
  modern reading 癥 keeps; the sermon corpus was produced by a different,
  phrase-aware converter that never had this hole (171 症 to that single 癥).
  `HANDOFF.md` and `docs/autonomous-queue.md` also carry the character, in this
  repo's own notes about the pair. This script only ever opens the file named
  in TR.

  Stale pre-fix copies of the CUV asset also sit in the gitignored build
  outputs and in `.claude/worktrees/`; those need a rebuild, not an edit. A
  tracked copy of the same asset carries the same 26 癥 in the SeekSparks repo,
  which is out of bounds for this loop and is queued for its own.

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

TRAD = "症"
SOURCE = "癥"

# Every reading the 26 occurrences actually take, spelt out at full phrase
# length. Used to audit the result, never to decide it.
READING_CUES = ("漏癥", "病癥", "火癥", "熱癥")

# The one reading in which 癥 is right. If it ever appears in the verse asset
# this instalment's premise is wrong and the script must not run.
CORRECT_READING = "癥結"


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
    # our form anywhere. If it held even one 癥 this would be a split like
    # 發/髮 and would have to be decided position by position instead.
    witness_all = "".join(witness.values())
    if witness_all.count(SOURCE) != 0:
        print(f"  ✗ the witness holds {witness_all.count(SOURCE)} {SOURCE} — "
              f"this is a split, not a partition — refusing")
        return 1

    # 癥 is not always wrong in Chinese, only in this corpus. If scripture ever
    # says 癥結 the class is no longer whole and this script is the wrong tool.
    if CORRECT_READING in before:
        print(f"  ✗ the corpus contains {CORRECT_READING}, where {SOURCE} is "
              f"correct — refusing")
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
