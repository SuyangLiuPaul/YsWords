#!/usr/bin/env python3
"""Restore 穀 (grain) in the Traditional CUV, where the converter wrote 谷.

Seventh instalment of the same defect. `assets/cuvs-yhwh-tr.json` is a script
conversion of the Simplified edition, and the converter that produced it had
holes: it never once wrote 隻, 淨, 牆, 餘, 髮, 鬍, 鬚, 採, 麵, 罈 … or 穀.
Simplified 谷 collapses two distinct traditional characters — 谷 (a valley) and
穀 (grain) — and the converter resolved every one of them to the valley. So the
harvest reads as terrain all through the corpus: 創世紀 27:28 「並許多五谷新酒」,
申命記 25:4 「牛在場上踹谷的時候」, 何西阿書 9:1 「在各谷場上如妓女喜愛賞賜」,
馬可福音 4:28 「地生五谷是出於自然的」.

WHY THIS IS A HOLE AND NOT AN EDITORIAL PREFERENCE
  Ours has 244 谷 and ZERO 穀 across 31,102 verses. The witness has 177 谷 and
  68 穀, and 244 + 1 = 177 + 68 exactly — the +1 being the separate 殼 typo
  below. A file that never once wrote the character did not choose against it.

WHY THIS IS STILL NOT A BLANKET SUBSTITUTION
  176 of the 244 are the genuine valley — 欣嫩子谷, 以拉谷, 汲淪谷, 亞割谷,
  耶斯列谷, 山谷, 幽谷. This is the 發/髮 shape, not the 淨/牆 shape: the claim
  is not "谷 is 穀" but "these 68 positions are 穀", and each is decided against
  the witness on its own.

THE SWAP THAT CANNOT HIDE HERE
  A false convert at a valley position plus a miss at a grain position in the
  same verse would balance the per-verse count and pass. That needs a verse
  holding both, and in the whole corpus there is exactly one: 詩篇 65:13
  「谷中也長滿了五穀」 — a valley and a harvest in one line. The repair converts
  五穀 and leaves 谷中, confirmed on two-sided context, so the balance is not
  being trusted there. It is not trusted anywhere else either: the last check
  below compares the ordered SEQUENCE of 谷/穀 against the witness verse by
  verse, which no offsetting pair can satisfy.

THE ONE VERSE THE ARITHMETIC EXPOSED — 以賽亞書 36:17 read 「五殼」
  Rabshakeh's promise of 「一個有五穀和新酒之地」 is set in ours with 殼 (a husk
  or shell), not 谷 at all, and it is the single 殼 in the whole corpus — the
  Simplified edition this was converted from carries the same typo (五壳). It is
  not a script-conversion hole but a plain textual error, and it is repaired here
  — in all THREE assets that carry it, the Traditional and Simplified readings and
  the tagged Strong's corpus the Originals sheet prints instead of the verse —
  because this is the verse where the 谷/穀 arithmetic runs one short.

  The tagged corpus settles it without leaving the repo: the run reading
  「就是有五壳」 is tagged **H1715**, דָּגָן, "properly, increase, i.e. grain"
  (KJV "corn, wheat"), and the identical run in the parallel verse reads 五谷.
  Five further readings agree it is grain: the witness 五穀; the
  parallel speech at 列王紀下 18:32, which is word-for-word the same sentence and
  reads 五谷 in our own Simplified and 五穀 in the witness; KJV "a land of corn
  and wine"; NASB and LEB "a land of grain and new wine". It is not something the
  script conversion did — SeekSparks' separately imported `cuvs-plus.json` carries
  五壳 at the same verse, though that copy may share an upstream e-text with ours,
  so it says where the error is NOT, not where it came from. 殼 is needed nowhere
  else: the husk and shell passages read 核…皮 (民 6:4), 新穗子 (王下 4:42),
  不結實 (何 8:7) and 豆莢 (路 15:16).

INDEPENDENT CORROBORATION, recorded because the witness is one source
  * 新譯本 Traditional (git blob 57c4686), a different translation: 93 穀.
  * KJV: corn / grain / wheat / threshingfloor / tread out the corn stand behind
    the readings converted here (申 25:4 and its two NT citations, 林前 9:9 and
    提前 5:18, are all "the ox that treadeth out the corn").

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
SIMPLIFIED = ROOT / "assets/cuvs-yhwh.json"
WITNESS_BLOB = "7a2dc43"

TAGGED = ROOT / "assets/tagged/cuvs-yhwh/isaiah.json"
HUSK_ID = "023036017"
HUSK_BEFORE, HUSK_AFTER = "五壳", "五谷"

TRAD = "穀"
# 殼 is not a second reading of the same Simplified glyph; it is the 以賽亞書
# 36:17 typo, carried here so that verse can be repaired by the same evidence.
SOURCES = ("谷", "殼")

# Readings in which 谷 can only be grain. Used to audit the result, never to
# decide it — every one of them is spelt out at full phrase length.
GRAIN_CUES = (
    "五谷", "谷种", "谷種", "谷場", "谷堆", "谷穗", "谷實", "踹谷", "百谷",
    "炒谷", "烘的谷", "別樣的谷", "谷、酒", "莊稼中的谷", "篩谷", "的谷嗎",
    "谷不可勝數", "谷、新酒", "谷新酒", "谷豐登", "谷健壯", "谷既熟",
    "谷是出於自然", "場上的谷", "禾場的谷", "谷到永生", "殼",
)


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


def grain_cue_hits(corpus: str) -> list[str]:
    hits = []
    for cue in GRAIN_CUES:
        start = 0
        while (j := corpus.find(cue, start)) != -1:
            start = j + 1
            hits.append(corpus[max(0, j - 8):j + len(cue) + 6])
    return hits


def totals(text: str) -> int:
    return text.count(TRAD) + sum(text.count(c) for c in SOURCES)


def repair_simplified(apply: bool) -> int:
    """The 以賽亞書 36:17 husk, on the Simplified side. Idempotent."""
    verses = json.loads(SIMPLIFIED.read_text(encoding="utf-8"))
    husks = [v for v in verses if "壳" in v["text"]]
    if not husks:
        print("  Simplified: no 壳 in the corpus — nothing to do")
        return repair_tagged(apply)
    if len(husks) != 1 or husks[0]["id"] != HUSK_ID:
        print(f"  ✗ Simplified: expected the single 壳 at {HUSK_ID}, found "
              f"{[v['id'] for v in husks]} — refusing")
        return 1
    v = husks[0]
    if v["text"].count(HUSK_BEFORE) != 1:
        print(f"  ✗ Simplified: {v['id']} does not read 「{HUSK_BEFORE}」 "
              f"— refusing")
        return 1
    fixed = v["text"].replace(HUSK_BEFORE, HUSK_AFTER)
    print(f"  Simplified: {v['book']} {v['chapter']}:{v['verse']} "
          f"「{HUSK_BEFORE}」 → 「{HUSK_AFTER}」")
    if apply:
        v["text"] = fixed
        SIMPLIFIED.write_text(
            json.dumps(verses, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8")
        print(f"  written → {SIMPLIFIED.relative_to(ROOT)}")
    return repair_tagged(apply)


def repair_tagged(apply: bool) -> int:
    """The same husk in the tagged Strong's corpus, which the Originals sheet
    prints *instead of* the verse. Edited as raw text so the file's compact
    formatting survives byte for byte. Idempotent."""
    raw = TAGGED.read_text(encoding="utf-8")
    if "壳" not in raw:
        print("  tagged: no 壳 — nothing to do")
        return 0
    if raw.count("壳") != 1 or raw.count(HUSK_BEFORE) != 1:
        print(f"  ✗ tagged: expected one 「{HUSK_BEFORE}」, found "
              f"{raw.count('壳')} 壳 — refusing")
        return 1
    # The run carrying it is tagged H1715 (דָּגָן, "properly, increase, i.e.
    # grain"), so the tagging itself says this word is grain.
    if '五壳","s":"H1715"' not in raw:
        print("  ✗ tagged: the husk run is not the H1715 run — refusing")
        return 1
    print(f"  tagged: isaiah 36:17 「{HUSK_BEFORE}」 → 「{HUSK_AFTER}」 (H1715)")
    if apply:
        TAGGED.write_text(raw.replace(HUSK_BEFORE, HUSK_AFTER),
                          encoding="utf-8")
        print(f"  written → {TAGGED.relative_to(ROOT)}")
    return 0


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
        # over every form so the check still holds once the repair is applied.
        if totals(text) != totals(wit):
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — ours holds "
                  f"{totals(text)} 谷/穀/殼, witness {totals(wit)} — refusing")
            return 1
        out = list(text)
        here = 0
        for i, ch in enumerate(text):
            if ch not in SOURCES:
                continue
            grain = confirm(text, i, TRAD, wit)
            kept = confirm(text, i, ch, wit)
            if grain and kept:
                print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — the "
                      f"witness reads 「{text[max(0, i - 8):i + 8]}」 both ways "
                      f"— refusing")
                return 1
            if not grain:
                continue
            out[i] = TRAD
            here += 1
            changed += 1
            tiers[grain[:3]] += 1
            report.append(f"{v['book']} {v['chapter']}:{v['verse']}\t{ch}\t"
                          f"{grain}\t…{text[max(0, i - 8):i + 8]}…")
        if here + text.count(TRAD) != wit.count(TRAD):
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — confirmed "
                  f"{here + text.count(TRAD)} grains, witness has "
                  f"{wit.count(TRAD)} — refusing")
            return 1
        v["text"] = "".join(out)

    after = "".join(v["text"] for v in verses)

    if len(before) != len(after):
        print("  ✗ the corpus changed length — refusing")
        return 1
    blind = str.maketrans({c: "\0" for c in (TRAD, *SOURCES)})
    if before.translate(blind) != after.translate(blind):
        print("  ✗ something other than 谷/穀/殼 changed — refusing")
        return 1
    if totals(before) != totals(after):
        print("  ✗ the 谷/穀/殼 total moved — refusing")
        return 1
    if changed + before.count(TRAD) != expected:
        print(f"  ✗ {changed + before.count(TRAD)} 穀 against {expected} in "
              f"the witness — refusing")
        return 1
    if after.count("殼") != 0:
        print("  ✗ 殼 survives the repair — refusing")
        return 1
    # The strongest check available, and the one that rules out an offsetting
    # pair inside a single verse: the ordered sequence of valleys and grains
    # must match the witness verse for verse, not merely the counts.
    for v in verses:
        wit = witness.get(v["id"])
        if wit is None:
            continue
        keep = "谷穀"
        if ([c for c in v["text"] if c in keep] != [c for c in wit if c in keep]):
            print(f"  ✗ {v['book']} {v['chapter']}:{v['verse']} — the 谷/穀 "
                  f"sequence disagrees with the witness — refusing")
            return 1
    leftover = grain_cue_hits(after)
    if leftover:
        print(f"  ✗ {len(leftover)} grain readings still set 谷 — refusing")
        for s in leftover[:10]:
            print(f"      …{s}…")
        return 1

    print(f"  {changed} substitutions →穀 "
          f"(witness has {expected} 穀; before: {before.count('谷')} 谷, "
          f"{before.count('殼')} 殼, {before.count(TRAD)} 穀 → after: "
          f"{after.count('谷')} 谷, {after.count('殼')} 殼, "
          f"{after.count(TRAD)} 穀)")
    print(f"  confirmation: {dict(sorted(tiers.items()))}")
    print(f"  grain readings still setting 谷: "
          f"{len(grain_cue_hits(before))} before → {len(leftover)} after")

    if args.report:
        Path(args.report).write_text("\n".join(report) + "\n", encoding="utf-8")
        print(f"  full diff ({len(report)} lines) → {args.report}")

    if args.apply:
        TR.write_text(json.dumps(verses, ensure_ascii=False, indent=2) + "\n",
                      encoding="utf-8")
        print(f"  written → {TR.relative_to(ROOT)}")
    else:
        print("  dry run — nothing written")
    return repair_simplified(args.apply)


if __name__ == "__main__":
    sys.exit(main())
