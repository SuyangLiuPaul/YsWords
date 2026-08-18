#!/usr/bin/env python3
"""Restore 癒 (healed) in the Traditional CUV, where the converter wrote 愈.

Fifteenth instalment of the same defect. `assets/cuvs-yhwh-tr.json` is a script
conversion of the Simplified edition, and the converter that produced it had
holes: it never once wrote 隻, 淨, 牆, 餘, 髮, 鬍, 鬚, 採, 麵, 罈, 穀, 鬆, 乾,
干, 卜, 恆, 凌, 症 … or 癒. So every healing in the Traditional Bible is spelt
痊愈 — 約翰福音 5:6 「你要痊愈嗎？」, 馬可福音 5:34 「你的災病痊愈了」,
利未記 15:13 「患漏症的人痊愈了」.

癒 is the healing (痊癒, 治癒, 癒合); 愈 is the comparative — 愈來愈, 愈加,
愈發, 每況愈下 — and in that sense 愈 is CORRECT Traditional and must never be
touched. Taiwan 教育部 heads 痊癒, and opencc renders 痊愈 → 痊癒 under s2t,
s2tw and s2twp while leaving 愈來愈, 愈加, 愈發 and 每況愈下 alone. Mainland
standard merged both onto 愈, and this file inherited the merge.

THIS ROW WAS NOT FOUND BY THE INVENTORY DIFF, AND THAT IS THE INTERESTING PART
  The queue's table lists characters our asset holds ZERO of. 愈 is not one of
  them — we hold 35 — so the table skipped the pair entirely. It is a hole all
  the same, in the other direction: we hold zero 癒. A merged pair only shows up
  in an inventory diff when the SURVIVING form is the one we lack. Worth
  remembering when the enumerated rows run out.

WHY THIS IS A HOLE AND NOT AN EDITORIAL PREFERENCE
  Before this repair ours held 35 愈 and ZERO 癒 across 31,102 verses. The
  witness holds 35 癒 and ZERO 愈. A file that never once wrote 癒 in 31,102
  verses did not choose against it.

WHY THE CLASS MOVES WHOLE — CHECKED, NOT ASSUMED
  Unlike 症/癥, the source form here is a live Traditional character, so "the
  witness holds none of it" is not enough on its own: a single 愈來愈 among the
  35 would make this a split. There is none. All 35 are preceded by 痊 and by
  nothing else, and the corpus contains no 愈來愈, 愈加, 愈發 or 每況愈下 at
  all. This script refuses if either fact stops being true.

  Every position is still confirmed against the witness rather than asserted:
  each verse's 愈+癒 count must equal the witness's 癒 count (agrees on all
  31,102 verses — zero mismatches, and no witness verse carrying either glyph is
  missing from ours, so an offsetting pair cannot hide), and afterwards the
  ordered sequence of the two forms must match the witness verse for verse.

INDEPENDENT CORROBORATION, recorded because the witness is one source
  * A published 新標點和合本 Traditional (ebible `cmn-cu89t`) reads 34 癒 and
    ZERO 愈, every one 痊癒, and reconciles book for book with our 35. The one
    difference is 約翰福音 5:4 — the bracketed angel-troubling-the-water verse,
    which we carry in 〔〕 and that edition omits, jumping v3 to v5.
    Caveat worth keeping: cu89t words the comparative 越發 and never 愈發, so
    its zero-愈 does NOT independently prove it would have preserved an
    adverbial 愈. Claim 1 above carries that weight, not this edition.
  * `assets/biblexg-v2-tr.json` — 梁家鏗's separately produced Traditional NT —
    writes 痊癒 in all 26 of its healings and no 痊愈.
  * No published Traditional 和合本 could be found that prints 痊愈. Unlike
    冑/胄, where the print tradition was genuinely split and the choice was
    escalated to the user, the witness, the published edition, the orthographic
    standard and opencc all point the same way here.

  NOT corroboration, and recorded so a later instalment does not misread it:
  git blob `57c4686`, a Traditional 新譯本 in this repo's history, reads 37
  痊愈 and ZERO 癒. That is NOT a defective file to be explained away — 新譯本
  genuinely prints 痊愈 in published Traditional e-texts (信望愛 `ncv`,
  cnbible CNV). It is a different translation with a different house style, and
  it is evidence neither for nor against what 和合本 prints.

SCOPE — THIS FILE ONLY
  愈 is correct elsewhere in the repo and a sweep would corrupt it:
  `assets/misconceptions.json` sets zh-Hant 「強者愈強、弱者愈弱」 and the
  zh-TW sermon corpus has 每況愈下 in `CP18.txt`. Both are right.
  `assets/bible_evidence.json` and `assets/songs.json` are Simplified-side
  assets, and `assets/strongs/greek.json`, `assets/maps_index.json` and the
  tagged corpus already carry the correct pair or are Simplified.

  Two same-class findings are deliberately NOT repaired here and are queued
  instead, because neither is converter-backed the way this one is:
  `assets/strongs/hebrew.json` H6867 (`glossZhTw`/`defZhTw` read 傷愈的疤 —
  opencc does not convert 傷愈, so it is an editorial call), and
  `assets/biblexg-v2-tr.json`'s 治愈 ×2 and 愈合 ×2, which are 梁家鏗's own
  wording rather than ours to normalise.

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

TRAD = "癒"
SOURCE = "愈"

# The only reading the 35 occurrences take. Used to audit the result, never to
# decide it.
READING_CUES = ("痊愈",)

# Readings in which 愈 is CORRECT Traditional. If any of these ever appears in
# the verse asset the class no longer moves whole and this script is the wrong
# tool — it would print 愈來癒.
CORRECT_READINGS = ("愈來愈", "愈加", "愈發", "每況愈下", "愈演愈烈")

# The one character that may precede 愈 here. Anything else means a reading this
# instalment has not read.
ONLY_PRECEDER = "痊"


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

    # The witness must hold none of our form anywhere. If it held even one 愈
    # this would be a split like 發/髮 and would have to be decided position by
    # position instead.
    witness_all = "".join(witness.values())
    if witness_all.count(SOURCE) != 0:
        print(f"  ✗ the witness holds {witness_all.count(SOURCE)} {SOURCE} — "
              f"this is a split, not a partition — refusing")
        return 1

    # 愈 is a live Traditional character. If scripture ever says 愈來愈 the class
    # is no longer whole and a blind replace would corrupt it.
    for reading in CORRECT_READINGS:
        if reading in before:
            print(f"  ✗ the corpus contains {reading}, where {SOURCE} is "
                  f"correct — refusing")
            return 1

    # An offsetting pair cannot hide in a verse we do not have.
    ids = {v["id"] for v in verses}
    for vid, text in witness.items():
        if (SOURCE in text or TRAD in text) and vid not in ids:
            print(f"  ✗ witness verse {vid} carries the glyph and is missing "
                  f"from ours — refusing")
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
            if i == 0 or text[i - 1] != ONLY_PRECEDER:
                print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — "
                      f"{SOURCE} not preceded by {ONLY_PRECEDER}: "
                      f"…{text[max(0, i - 8):i + 8]}… — refusing")
                return 1
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
