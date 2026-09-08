#!/usr/bin/env python3
"""Where the Traditional Strong's lexicon came from, and what has been edited since.

WHY THIS EXISTS
  `assets/strongs/{hebrew,greek}.json` carry a Simplified field and a
  Traditional field per entry (`glossZh`/`glossZhTw`, `defZh`/`defZhTw`).
  Two separate places in `tools/` asserted how the Traditional side was made,
  and both assertions were load-bearing — the 姪 repair reasoned "opencc has no
  侄 → 姪 mapping, so all 21 came through untouched" — while neither had been
  measured against the file as it stands.

  This matters because the Bible asset next to it was NOT made by opencc. It
  came from a naive unconditional per-character map, which is the origin of
  every converter hole this repo has fixed (隻, 淨, 牆, 餘 …). Two files with
  different provenance need different arguments, so the provenance has to be a
  measurement rather than an assumption.

WHAT IT MEASURES
  Every Simplified field is re-converted with `opencc` and compared to its
  Traditional twin, in four configurations. Then every character-level
  disagreement with the winning configuration is listed, so that hand edits
  made after the conversion are enumerated rather than assumed away.

WHAT IT FOUND, 2026-09-08 at `42e35a2a`
  Raw byte-identical match against opencc, all four configurations:
    s2t   26061 / 28377 fields byte-identical  (91.84%)
    s2tw  27283  (96.14%)   s2twp 26982 (95.08%)   s2hk 26240 (92.47%)

  **The raw ratio stopped being the useful number.** Two deliberate,
  documented edits landed between the 2026-08-23 baseline above and this one
  — `33f04a02` (2026-09-03, 89 wrong Traditional expansions fixed by
  `repair_strongs_tw_ambiguous.py`) and `3c514a7b` (2026-09-06, a 2,816+
  position orthography reset by `reset_lexicon_orthography.py --apply
  --user-ruled` moving the lexicon from opencc's mainland forms to this
  app's Bible-edition forms: 爲→為, 羣→群, 衆→眾, 着→著, 喫→吃, 牀→床). Both
  moved characters IN THE DIRECTION of Taiwan-standard forms, which is also
  the direction `s2tw`/`s2twp` already point — so raw match no longer shows
  `s2t` "clearly ahead": `s2tw` now scores 4.3 points HIGHER than `s2t`. A
  threshold built on raw match cannot survive that without either declaring
  false drift on every deliberate edit this repo has made on purpose, or
  being widened into meaninglessness.

  **What still discriminates cleanly: how much of each configuration's
  mismatch is EXPLAINED by a short, dated list of known edits**, rather than
  by unrelated characters this repo has never touched. Every character-level
  disagreement between `s2t` output and this file falls into exactly 24
  categories, all listed in `KNOWN_EDITS` below and all traced to a specific
  commit — so `s2t`, credited with its own known edits, explains **100.00%**
  (28377/28377) of the file. `s2tw` explains 96.74%, `s2twp` 95.67%, `s2hk`
  94.63% — because THEIR mismatches are a different, much larger set of
  positions this repo's history has no record of touching at all (`s2tw`
  alone disagrees with this file on 啟/啓, 裡/裏, 汙/污, 秘/祕, 峰/峯 and 14
  more pairs — 1,065 characters — none of which any commit here has ever
  mentioned). `s2twp` additionally rewrites whole WORDS (線→接, 援→持, 訊→消 —
  vocabulary substitution, not orthography) and produces 35 length-differing
  fields, which is not a glyph disagreement at all.

  So: opencc, in the `s2t` configuration, is still the correct provenance
  model — now demonstrated by completeness of explanation rather than by
  raw proximity, because raw proximity is exactly the number three separate
  user-ruled decisions have been moving on purpose.

  `s2t` rewrites 103,550 characters drawn from 1,242 distinct source
  characters, across 24,613 of the 28,377 fields — the conversion is doing
  real, non-trivial work, not approximating identity.

KNOWN_EDITS PROVENANCE — three groups, none of them drift
  1. `cf0782d7` (Hebron) + `ca095312` (Lot's nephew), found 2026-08-23:
     侖→崙 (93×), 侄→姪 (22×). [Counts grew from 88/21 after `42e35a2a`
     un-truncated 426 glosses that already held these characters in `defZh`
     — the same text, now visible in `glossZh` too, not a new edit.]
  2. `33f04a02` (2026-09-03), `repair_strongs_tw_ambiguous.py` — opencc
     picking the wrong Traditional expansion of one Simplified character,
     verified name-by-name against the Simplified twin: 併→並 (21), 幹→乾
     (16), 里→裏 (9), 幹→干 (8), 闢→辟 (7), 睏→困 (6), 乾→干 (5), 覆→復 (4),
     須→鬚 (3), 複→復 (3), 面→麪 (2), 裏→里 (2), 谷→穀 (1), 蔘→參 (1), 髮→發
     (1), 徵→征 (1) — 16 categories, 90 characters. [併→並 grew from 20 to
     21 the same way group 1 grew: `42e35a2a` un-truncated a gloss that
     already held 並 in `defZh`, revealing it in `glossZh` too — not a new
     edit. The commit's own count was 89; today's is 90.]
  3. `3c514a7b` (2026-09-06), `reset_lexicon_orthography.py --apply
     --user-ruled` — a delegated user ruling («这个你决定吧») to follow this
     app's Bible-edition orthography over opencc's mainland forms: 爲→為
     (1976), 着→著 (374), 衆→眾 (202), 羣→群 (196), 喫→吃 (77), 牀→床 (47).
     喫→吃 deliberately excludes 5 `口吃` (stammer, H3933/G945) — a different
     word, never swept; 吃 in the file today is 82 = 77 + 5, confirming
     none of the 5 moved. 着→著 was pinned at 419 by the reset script's own
     `--verify`; the audit here counts 374 STILL because that script's own
     commit also fixed 51 of those independently (already-著-sense text that
     had been wrongly written 着 on BOTH sides, via `repair_lexicon_zhu_glyph
     .py`), and later un-truncation revealed 6 more genuine aspect-particle
     positions this measurement had not yet been able to see.

THE CLAIM THIS CORRECTS
  `tools/repair_strongs_tw_ambiguous.py` said the Traditional side was s2t
  "character for character, with ZERO manual edits in all 28,377 field pairs
  (verified by re-converting every Simplified field and comparing)". The
  provenance half is right and is now confirmed, three times over. The "zero
  manual edits" half was already false when it was written: cf0782d landed
  14:03 and that survey 14:15 the same afternoon, so 88 of the 109 then-known
  edits were in the file at the time. Nothing was damaged — that script's
  rules touch neither character — but a later pass reasoning from "no manual
  edits" could quietly convert Hebron back to 希伯侖, or worse, treat the
  2026-09-06 reset's 2,816 positions as accidental corruption to "fix" back
  to opencc's mainland forms. The exceptions are pinned below so neither can
  happen unnoticed.

Exit status 0 when the file matches the expectation, 1 on any drift.
"""
from __future__ import annotations

import collections
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILES = ("assets/strongs/hebrew.json", "assets/strongs/greek.json")
PAIRS = (("glossZh", "glossZhTw"), ("defZh", "defZhTw"))
SEP = "\n@@@SEP@@@\n"

CONFIGS = ("s2t", "s2tw", "s2twp", "s2hk")
WINNER = "s2t"

# Raw byte-identical ratio stopped discriminating once deliberate edits moved
# the file toward Taiwan-standard forms (see WHAT IT FOUND) — s2tw's raw
# match now EXCEEDS s2t's. The metric that still works is "fraction of
# fields that are byte-identical to opencc OR differ only by a documented
# KNOWN_EDITS pair" — measured 100.00% for s2t and 96.74%/95.67%/94.63% for
# the runner-ups, because their mismatches are unrelated characters this
# repo's history never touched. MIN is exact because that is what today's
# file actually is, not a comfortable rounding: any future unexplained
# deviation, however small, should trip this. MAX sits just above the
# highest measured runner-up (s2tw, 96.74%) with headroom for their small
# runs since the two aren't the same character set.
MIN_WINNER_EXPLAINED = 1.0
MAX_RUNNER_UP_EXPLAINED = 0.97

# Every hand edit the lexicon has ever received, as (opencc writes, we
# write). Three provenance groups — see KNOWN_EDITS PROVENANCE above for
# which commit each one is from and why none of them is drift.
KNOWN_EDITS = {
    # 2026-08-23: cf0782d7 (Hebron), ca095312 (Lot's nephew)
    ("侖", "崙"): 93, ("侄", "姪"): 22,
    # 2026-09-03: 33f04a02, repair_strongs_tw_ambiguous.py
    ("併", "並"): 21, ("幹", "乾"): 16, ("里", "裏"): 9, ("幹", "干"): 8,
    ("闢", "辟"): 7, ("睏", "困"): 6, ("乾", "干"): 5, ("覆", "復"): 4,
    ("須", "鬚"): 3, ("複", "復"): 3, ("面", "麪"): 2, ("裏", "里"): 2,
    ("谷", "穀"): 1, ("蔘", "參"): 1, ("髮", "發"): 1, ("徵", "征"): 1,
    # 2026-09-06: 3c514a7b, reset_lexicon_orthography.py --apply --user-ruled
    ("爲", "為"): 1976, ("着", "著"): 374, ("衆", "眾"): 202, ("羣", "群"): 196,
    ("喫", "吃"): 77, ("牀", "床"): 47,
}


def field_pairs() -> list[tuple[str, str, str, str, str]]:
    out = []
    for name in FILES:
        doc = json.loads((ROOT / name).read_text(encoding="utf-8"))
        for sid, entry in doc.items():
            for simp, trad in PAIRS:
                if isinstance(entry.get(simp), str) and isinstance(entry.get(trad), str):
                    out.append((name, sid, simp, entry[simp], entry[trad]))
    return out


def convert(texts: list[str], config: str) -> list[str]:
    joined = SEP.join(texts)
    proc = subprocess.run(
        ["opencc", "-c", config], input=joined, capture_output=True, text=True)
    if proc.returncode != 0:
        raise SystemExit(f"opencc -c {config} failed: {proc.stderr.strip()}")
    parts = proc.stdout.rstrip("\n").split(SEP)
    if len(parts) != len(texts):
        raise SystemExit(
            f"opencc -c {config} returned {len(parts)} fields, expected {len(texts)} "
            f"— the separator was rewritten or a field contains it")
    return parts


def explained_ratio(items: list[tuple[str, str, str, str, str]], parts: list[str]) -> float:
    """Fraction of fields that are byte-identical to `parts`, OR differ from
    it only by character pairs already in KNOWN_EDITS (same length)."""
    n = 0
    for (_, _, _, _, mine), theirs in zip(items, parts):
        if theirs == mine:
            n += 1
        elif len(theirs) == len(mine) and all(
                (a, b) in KNOWN_EDITS for a, b in zip(theirs, mine) if a != b):
            n += 1
    return n / len(items)


def main() -> int:
    items = field_pairs()
    simplified = [i[3] for i in items]
    ours = [i[4] for i in items]
    print(f"field pairs: {len(items)}")

    ratios = {}
    converted = {}
    for config in CONFIGS:
        parts = convert(simplified, config)
        converted[config] = parts
        hits = sum(1 for p, o in zip(parts, ours) if p == o)
        ratios[config] = hits / len(items)
        print(f"  opencc -c {config:<6} {hits:>6} / {len(items)}  "
              f"{ratios[config] * 100:6.2f}%  (raw)")

    explained = {config: explained_ratio(items, converted[config]) for config in CONFIGS}
    print()
    for config in CONFIGS:
        print(f"  opencc -c {config:<6} explained (identical or known edit) "
              f"{explained[config] * 100:6.2f}%")

    failures = []
    if explained[WINNER] < MIN_WINNER_EXPLAINED:
        failures.append(
            f"{WINNER} is only {explained[WINNER] * 100:.2f}% explained by identity + "
            f"KNOWN_EDITS — the lexicon has an unrecorded edit; see the per-pair list below")
    for config in CONFIGS:
        if config != WINNER and explained[config] > MAX_RUNNER_UP_EXPLAINED:
            failures.append(
                f"{config} is now {explained[config] * 100:.2f}% explained by identity + "
                f"KNOWN_EDITS — it no longer discriminates against {WINNER}, so the "
                f"configuration is unproven")

    # How much work the conversion does. A near-identity conversion would make a
    # high match rate meaningless, so this is part of the evidence, not colour.
    src = "".join(simplified)
    win = "".join(converted[WINNER])
    rewritten = sum(1 for a, b in zip(src, win) if a != b)
    distinct = len({a for a, b in zip(src, win) if a != b})
    touched = sum(1 for s, p in zip(simplified, converted[WINNER]) if s != p)
    print(f"\n{WINNER} rewrites {rewritten} characters ({distinct} distinct sources) "
          f"in {touched} fields")

    edits: collections.Counter = collections.Counter()
    for (name, sid, field, _, mine), theirs in zip(items, converted[WINNER]):
        if theirs == mine:
            continue
        if len(theirs) != len(mine):
            failures.append(
                f"{name} {sid} {field}: length differs from {WINNER} output "
                f"({len(theirs)} → {len(mine)}) — this is not a glyph edit")
            continue
        for a, b in zip(theirs, mine):
            if a != b:
                edits[(a, b)] += 1

    print("\nhand edits since the conversion (opencc → ours):")
    for (a, b), n in sorted(edits.items(), key=lambda kv: -kv[1]):
        expected = KNOWN_EDITS.get((a, b))
        mark = "ok" if expected == n else f"EXPECTED {expected}"
        print(f"  {a} → {b}  {n:>4}   {mark}")
    if not edits:
        print("  (none)")

    for key, expected in KNOWN_EDITS.items():
        if edits.get(key, 0) != expected:
            failures.append(
                f"{key[0]} → {key[1]} appears {edits.get(key, 0)} times, expected "
                f"{expected} — a known repair has been reverted or extended")
    for key in edits:
        if key not in KNOWN_EDITS:
            failures.append(
                f"{key[0]} → {key[1]} is a hand edit this audit has never seen "
                f"({edits[key]}×) — read it before adding it to KNOWN_EDITS")

    if failures:
        print("\nDRIFT:")
        for f in failures:
            print(f"  ✗ {f}")
        return 1
    print(f"\nclean — the lexicon is opencc s2t plus the {len(KNOWN_EDITS)} known edits above")
    return 0


if __name__ == "__main__":
    sys.exit(main())
