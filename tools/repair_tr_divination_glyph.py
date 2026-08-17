#!/usr/bin/env python3
"""Restore 卜 (divination) in the Traditional CUV, where the converter wrote 蔔.

Eleventh instalment of the same defect. `assets/cuvs-yhwh-tr.json` is a script
conversion of the Simplified edition, and the converter that produced it had
holes: it never once wrote 隻, 淨, 牆, 餘, 髮, 鬍, 鬚, 採, 麵, 罈, 穀, 鬆, 乾, 干
… or 卜. Simplified 卜 stands for two distinct Traditional characters — 卜
(divination, and the transliterated names built on it) and 蔔 (which occurs only
in 蘿蔔, a radish) — and the converter resolved every single one of them to the
radish. So every divination in the Bible prints as a root vegetable:
申命記 18:10 「不可有占蔔的、觀兆的」, 以西結書 13:6 「是謊詐的占蔔」,
彌迦書 3:11 「先知為銀錢行占蔔」, and the rest of the class is worse still —
the rulers of Ekron are consulted at 巴力西蔔 and the rabbis accuse Jesus of
casting out demons by 別西蔔.

WHY THIS IS A HOLE AND NOT AN EDITORIAL PREFERENCE
  Before this repair ours held 42 蔔 and ZERO 卜 across 31,102 verses. The
  witness holds 42 卜 and ZERO 蔔. That is a partition, not a preference: a file
  that never once wrote the character did not choose against it, and there is no
  hypothesis left in which an editor picked 蔔 forty-two times and 卜 never.

WHY THIS ONE NEEDS NO PER-POSITION JUDGEMENT
  Unlike 發/髮, 谷/穀 or 干/乾/幹 — where our form was also correct hundreds or
  thousands of times and only some positions moved — 蔔 is correct in exactly
  one word in the language, 蘿蔔, and neither the radish nor any other 蔔 word
  occurs anywhere in scripture. The witness confirms it by holding zero 蔔 in
  the whole corpus. So the class is a whole-class 1:1 replacement, and this
  script still checks it position by position rather than asserting it: for
  every verse our 蔔 count must equal the witness's 卜 count, and afterwards
  the ordered sequence of 卜/蔔 must match the witness verse for verse.

  Per-verse counts agree on ALL 31,102 verses — zero mismatches. No verse holds
  both readings, because no verse holds a radish.

THE 42, ALL OF THEM
  30 divination readings (占蔔用的, 占蔔的、觀兆的, 謊詐的占蔔, 行占蔔 …), plus
  the names a rule would have to be told about and this script does not need to
  be: 別西蔔 / 巴力西蔔 ×8 (Beelzebub / Baal-zebub, 王下 1:2,3,6,16; 太 10:25 ×2,
  12:24, 12:27; 可 3:22; 路 11:15,18,19), 巴蔔 ×2 (Bakbuk, 拉 2:51 / 尼 7:53),
  押蔔 (Azbuk, 尼 3:16) and 蔔士 (the diviners, 亞 10:2).

INDEPENDENT CORROBORATION, recorded because the witness is one source
  * `assets/biblexg-v2-tr.json` — 梁家鏗's separately produced Traditional NT,
    not a conversion of anything in this repo — writes 別西卜 eight times and
    占卜 / 預卜 at 使徒行傳 16:16. 10 卜, 0 蔔.
  * Our own Simplified `assets/cuvs-yhwh.json` and the tagged Strong's corpus
    under `assets/tagged/` are Simplified and correctly write 卜; neither holds
    a single 蔔.
  * 新譯本 Traditional (git blob 57c4686), a different translation: 44 卜, 0 蔔.

THE ONE PLACE IN THE REPO WHERE 蔔 IS CORRECT — SCOPE THIS TO THE VERSE ASSET
  "No 蔔 belongs in scripture" is true; "no 蔔 belongs in this repo" is NOT.
  `assets/sermons/zh-TW/751.txt` (6×) and `765.txt` (1×) hold seven correct 蔔,
  all 蘿蔔 / 胡蘿蔔 — a radish in a preacher's illustration. That corpus was
  produced by a phrase-aware converter which does not have this defect at all
  (it holds 隻, 淨, 牆, 餘, 髮, 穀, 鬆, 佔 and all three of 干/乾/幹), so it must
  not be swept. This script only ever opens the file named in TR.
  * 佔/占 is a SEPARATE open class in the same corpus (ours writes 占 where the
    witness has 佔 30 times). It is untouched here and must stay untouched:
    占 is correct in 占卜, so 卜 has to be settled first — which is why this
    instalment runs before that one.

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

TRAD = "卜"
SOURCE = "蔔"

# Readings in which 蔔 can only be a mistake, spelt out at full phrase length.
# Used to audit the result, never to decide it.
DIVINATION_CUES = (
    "占蔔", "蔔士", "別西蔔", "巴力西蔔", "巴蔔", "押蔔",
)


def cue_hits(corpus: str) -> list[str]:
    hits = []
    for cue in DIVINATION_CUES:
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
    # our form anywhere. If it held even one 蔔 this would be a split like
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
        print(f"  ✗ {len(leftover)} divinations still set {SOURCE} — refusing")
        for s in leftover[:10]:
            print(f"      …{s}…")
        return 1

    print(f"  {changed} substitutions →{TRAD} "
          f"(witness has {expected} {TRAD} and 0 {SOURCE}; before: "
          f"{before.count(SOURCE)} {SOURCE}, {before.count(TRAD)} {TRAD} → "
          f"after: {after.count(SOURCE)} {SOURCE}, {after.count(TRAD)} {TRAD})")
    print(f"  divination readings still setting {SOURCE}: "
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
