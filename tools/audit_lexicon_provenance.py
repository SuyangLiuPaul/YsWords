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

WHAT IT FOUND, 2026-08-23
  s2t   28276 / 28377 fields byte-identical  (99.64%)
  s2tw  25320, s2twp 25066, s2hk 25260       (~89%)

  So: opencc, in the `s2t` configuration specifically. The gap to the other
  three is the discriminator, and the conversion is doing real work rather than
  approximating identity — s2t rewrites 101,659 characters drawn from 1,242
  distinct source characters, across 24,611 of the 28,377 fields. A naive
  per-character map built from opencc's OWN single-character table scores only
  92.93%, so the phrase dictionary is what the 99.64% is measuring.

  The 101 non-matching fields hold exactly 109 differing characters and no
  length differences: 88 where opencc writes 侖 and we write 崙 (82 fields, 53
  entries), and 21 where it writes 侄 and we write 姪 (21 fields, 14 entries).
  Those are this repo's own later repairs — cf0782d (Hebron) and ca09531
  (Lot's nephew). Nothing else in the file has ever been touched by hand.

  Stated precisely, because the loose version overreaches: what is proven is
  that the file today is `s2t` of its own Simplified side today, minus those
  109 characters. Three later commits (the 自已 → 自己 family) did rewrite
  lexicon text, but edited the Simplified and Traditional sides symmetrically,
  so they preserve the relation rather than showing up as exceptions.

THE CLAIM THIS CORRECTS
  `tools/repair_strongs_tw_ambiguous.py` said the Traditional side was s2t
  "character for character, with ZERO manual edits in all 28,377 field pairs
  (verified by re-converting every Simplified field and comparing)". The
  provenance half is right and is now confirmed. The "zero manual edits" half
  was already false when it was written: cf0782d landed 14:03 and that survey
  14:15 the same afternoon, so 88 of the 109 were in the file at the time.
  Nothing was damaged — that script's rules touch neither character — but a
  later pass reasoning from "no manual edits" could quietly convert Hebron back
  to 希伯侖. The exceptions are pinned below so it cannot.

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
MIN_WINNER_RATIO = 0.99
MAX_RUNNER_UP_RATIO = 0.95  # the other configs must stay clearly behind

# The only hand edits the lexicon has ever received, as (opencc writes, we write).
KNOWN_EDITS = {("侖", "崙"): 88, ("侄", "姪"): 21}


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
              f"{ratios[config] * 100:6.2f}%")

    failures = []
    if ratios[WINNER] < MIN_WINNER_RATIO:
        failures.append(
            f"{WINNER} matches only {ratios[WINNER] * 100:.2f}% — the lexicon is "
            f"no longer opencc {WINNER} output, or has been edited in bulk")
    for config in CONFIGS:
        if config != WINNER and ratios[config] > MAX_RUNNER_UP_RATIO:
            failures.append(
                f"{config} now matches {ratios[config] * 100:.2f}% — it no longer "
                f"discriminates against {WINNER}, so the configuration is unproven")

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
    print("\nclean — the lexicon is opencc s2t plus the two known repairs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
