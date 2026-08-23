#!/usr/bin/env python3
"""Restore 逆料 in the two verses where the reading text modernised it to 意料.

  以賽亞書 64:3   你曾行我們不能**意料**可畏的事  → 不能**逆料**可畏的事
  使徒行傳 25:18  並沒有我所**意料**的那等惡事    → 我所**逆料**的那等惡事

A substitution, not a dropped character, which is why every audit this repo
runs was blind to it: `audit_dropped_characters.py` and
`audit_tagged_running_text.py` both report only text a witness has and we do
not, because that is the direction that can mean a LOSS. Where we read a
different word of the same length, nothing is missing and nothing fires. The
verse stays grammatical, stays plausible, and stays wrong.

FIVE LINES, all pointing the same way, and the fifth is the one that matters:

  1. The printed 1919 和合本 (Wikisource) reads 「你曾行我們不能逆料可畏的事」
     and 「並沒有我所逆料的那等惡事」.
  2. Witness A, SeekSparks' independently imported `cuvs-plus.json`: 逆料.
  3. Witness B, git blob `7a2dc43` (`assets/cuv-tr.json`, dropped at v1.4.5):
     逆料.
  4. Our OWN tagged corpus, `assets/tagged/cuvs-yhwh/{isaiah,acts}.json`: 逆料
     — so the app's word-tap sheet has been printing 逆料 over a verse that
     reads 意料. The same internal contradiction as 「士師六年」 over
     「士師年」, and the same reason to trust it: the two are separate imports
     of one edition, and only one of them was touched.
  5. Counted over all 31,102 verses rather than assumed: our two reading files
     hold 意料 twice and 逆料 ZERO times; the tagged corpus, witness A and
     witness B each hold 逆料 twice and 意料 zero times. There is no third
     verse anywhere in which the two spellings compete, so this is not a
     convention the edition applies inconsistently — it is two verses.

WHY THE DIRECTION IS SAFE HERE, when it usually is not. Ten OTHER differences
found in the same pass have our running text and our tagged corpus on one side
and the print and both witnesses on the other; none of them is touched, and
they are queued for the user. These two are the only ones where our own tagged
corpus sides with the print AGAINST our reading text, which makes them 4 lines
to 1 instead of 2 to 3.

意料 and 逆料 are not orthographic variants: 逆料 is "to anticipate in
advance", the word CUV uses, and 意料 is the modern colloquial "to expect".

Idempotent. Refuses on any drift rather than guessing.
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
FILES = ("assets/cuvs-yhwh.json", "assets/cuvs-yhwh-tr.json")

# id → (the wrong reading in full, the printed reading in full). Anchored on
# enough context that a blanket 意料 → 逆料 can never run: the sermon
# transcripts and 梁家鏗's translation use 意料 correctly and are not scripture.
REPAIRS = {
    "023064003": ("不能意料可畏的事", "不能逆料可畏的事"),
    "044025018": ("我所意料的那等惡事", "我所逆料的那等惡事"),
}
# The Traditional file is authored in Traditional and the Simplified in
# Simplified; every character in these two anchors happens to be shared except
# 惡/恶 and 事, so the Simplified anchor is spelled out rather than converted.
SIMPLIFIED = {
    "023064003": ("不能意料可畏的事", "不能逆料可畏的事"),
    "044025018": ("我所意料的那等恶事", "我所逆料的那等恶事"),
}


def apply(path, anchors):
    verses = json.loads(path.read_text(encoding="utf-8"))
    changed = 0
    for v in verses:
        anchor = anchors.get(v["id"])
        if anchor is None:
            continue
        wrong, right = anchor
        if right in v["text"]:
            continue
        if wrong not in v["text"]:
            sys.exit(f"{path.name} {v['id']}: neither reading present, refusing:\n"
                     f"  {v['text']}")
        v["text"] = v["text"].replace(wrong, right)
        changed += 1
    if changed:
        path.write_text(
            json.dumps(verses, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8")
    return changed


def main():
    for name in FILES:
        path = REPO / name
        anchors = SIMPLIFIED if name.endswith("yhwh.json") else REPAIRS
        print(f"{name}: {apply(path, anchors)} repaired")


if __name__ == "__main__":
    main()
