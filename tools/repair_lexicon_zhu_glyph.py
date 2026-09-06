#!/usr/bin/env python3
"""Fix 著名/著稱/著作/著述/顯著 spelt with 着 in the Strong's lexicon's
Simplified fields (`glossZh`/`defZh`) — 51 positions, wrong in both
orthographies.

着 is the Simplified aspect particle (跟着, 看着, ...); the zhù of 著名 is a
different word and is never written 着 in correct Simplified either. All 419
着 in these fields are NOT this defect — only the five zhù bigrams below are,
and they are matched as whole bigrams so the aspect particle is never
touched: after this repair 着 in `glossZh`/`defZh` still numbers 368 (419 -
51), all of them the aspect particle.

The Traditional fields (`glossZhTw`/`defZhTw`) do not need this script: they
already read 著 for these same 51 positions after
`tools/reset_lexicon_orthography.py --apply` swept every 着 to 著 there.

--measure   count matches without writing (default)
--apply     write the substitutions
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEXICON = ["assets/strongs/hebrew.json", "assets/strongs/greek.json"]
SC_FIELDS = ("glossZh", "defZh")

BIGRAMS = ["着名", "着称", "着作", "着述", "显着"]
REPLACEMENTS = {
    "着名": "著名",
    "着称": "著称",
    "着作": "著作",
    "着述": "著述",
    "显着": "显著",
}
EXPECT_TOTAL = 51


def measure() -> int:
    total = 0
    for name in LEXICON:
        doc = json.loads((ROOT / name).read_text(encoding="utf-8"))
        for key, entry in doc.items():
            for field in SC_FIELDS:
                value = entry.get(field)
                if not isinstance(value, str):
                    continue
                for bigram in BIGRAMS:
                    n = value.count(bigram)
                    if n:
                        total += n
                        print(f"{name} {key} {field} {bigram} x{n}")
    print(f"\ntotal: {total} (expect {EXPECT_TOTAL})")
    return 0 if total == EXPECT_TOTAL else 1


def apply() -> int:
    if measure() != 0:
        print("REFUSING: measured total does not match the pinned 51 — "
              "re-check before applying.")
        return 1
    changed = 0
    for name in LEXICON:
        path = ROOT / name
        doc = json.loads(path.read_text(encoding="utf-8"))
        for entry in doc.values():
            for field in SC_FIELDS:
                value = entry.get(field)
                if not isinstance(value, str):
                    continue
                new = value
                for bigram, fixed in REPLACEMENTS.items():
                    new = new.replace(bigram, fixed)
                if new != value:
                    for bigram in BIGRAMS:
                        changed += value.count(bigram)
                    entry[field] = new
        path.write_text(
            json.dumps(doc, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8")
    print(f"re-set {changed} positions")
    return 0 if changed == EXPECT_TOTAL else 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    return apply() if args.apply else measure()


if __name__ == "__main__":
    raise SystemExit(main())
