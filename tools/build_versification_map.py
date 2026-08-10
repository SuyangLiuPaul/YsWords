#!/usr/bin/env python3
"""Derive the reading-text → original-text verse map by content.

`assets/originals/` is numbered the way the Hebrew and Greek editions
number themselves. The reading text is numbered the way English and
Chinese Bibles do. Those two disagree in about 1,600 places — the
psalm superscriptions, Joel's and Malachi's chapter boundaries, and the
familiar one-verse slips at Genesis 32, Exodus 22, Jonah 2 and the rest.

The map is *measured*, not typed in from a table: each book's two verse
sequences are aligned by Strong's-number overlap (banded Needleman-
Wunsch), so the evidence for every entry is the text itself. Then the
result is compressed into runs, which is what makes it checkable by
eye — `psalms 3: +1 verse` is a claim a reader can verify in seconds.

Writes assets/originals_versification.json. Verify with
    python3 tools/audit_originals_alignment.py --map

Usage:
    python3 tools/build_versification_map.py [--write]
"""

from __future__ import annotations

import argparse
import json
import pathlib
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent
TAGGED = ROOT / "assets" / "tagged" / "cuvs-yhwh"
ORIGINALS = ROOT / "assets" / "originals"
OUT = ROOT / "assets" / "originals_versification.json"

BAND = 8
GAP = -0.35
# A run is only kept if the verses in it agree with the original
# markedly better than they do at their own number.
MIN_GAIN = 0.15
# How much of an unclaimed original verse a reading verse must account
# for before we say the reading verse covers it too.
ABSORB_MIN = 0.5


def load(path: pathlib.Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def nums(words: list[dict]) -> Counter:
    return Counter(w["s"] for w in words
                   if w.get("s") and w["s"] not in ("H0", "G0"))


def sim(a: Counter, b: Counter) -> float:
    if not a or not b:
        return 0.0
    return sum((a & b).values()) / max(sum(a.values()), sum(b.values()))


def covers(a: Counter, b: Counter) -> float:
    """How much of original verse [b] the reading verse [a] accounts for.

    Deliberately not symmetric. A psalm's verse 1 in the CUV carries the
    whole superscription plus the first line of the poem, so it is much
    longer than the superscription alone — symmetric similarity scores
    that pairing low precisely where the containment is total.
    """
    if not a or not b:
        return 0.0
    return sum((a & b).values()) / sum(b.values())


def refs_in_order(data: dict) -> list[tuple[int, int]]:
    out = []
    for ref in data:
        c, _, v = ref.partition(":")
        if c.isdigit() and v.isdigit():
            out.append((int(c), int(v)))
    return sorted(out)


def align(read: list[Counter], orig: list[Counter]) -> list[int | None]:
    """Banded global alignment; returns orig index (or None) per read index.

    The band follows the previous row's best cell rather than the
    diagonal: Psalms drifts a full 66 verses by chapter 150, so a band
    pinned to i == j loses the alignment less than a third of the way
    through the book.
    """
    n, m = len(read), len(orig)
    neg = float("-inf")
    prev = {0: 0.0}
    back: list[dict[int, tuple[int, int]]] = []
    for i in range(1, n + 1):
        cur: dict[int, tuple[float, int]] = {}
        row: dict[int, tuple[int, int]] = {}
        center = max(prev, key=lambda j: prev[j]) if prev else i
        lo = max(0, center - BAND)
        hi = min(m, center + BAND)
        for j in range(lo, hi + 1):
            best, move = neg, 0
            if j - 1 >= 0 and (j - 1) in prev:
                s = prev[j - 1] + sim(read[i - 1], orig[j - 1])
                if s > best:
                    best, move = s, 1  # diagonal: read i pairs with orig j
            if j in prev:
                s = prev[j] + GAP
                if s > best:
                    best, move = s, 2  # read verse has no original
            if (j - 1) in cur:
                s = cur[j - 1][0] + GAP
                if s > best:
                    best, move = s, 3  # original verse unmatched
            if best == neg:
                continue
            cur[j] = (best, move)
            row[j] = (move, 0)
        prev = {j: v[0] for j, v in cur.items()}
        back.append({j: v[1] for j, v in cur.items()})
        if not prev:
            return [None] * n

    # walk back from (n, m)
    out: list[int | None] = [None] * n
    i, j = n, m
    while i > 0:
        move = back[i - 1].get(j)
        if move is None:
            break
        if move == 1:
            out[i - 1] = j - 1
            i, j = i - 1, j - 1
        elif move == 2:
            i -= 1
        else:
            j -= 1
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    result: dict[str, list[list[int]]] = {}
    total_entries = 0

    for book_path in sorted(TAGGED.glob("*.json")):
        book = book_path.stem
        orig_path = ORIGINALS / f"{book}.json"
        if not orig_path.exists():
            continue
        tagged = load(book_path)
        originals = load(orig_path)
        r_refs = refs_in_order(tagged)
        o_refs = refs_in_order(originals)
        r_nums = [nums(tagged[f"{c}:{v}"]) for c, v in r_refs]
        o_nums = [nums(originals[f"{c}:{v}"]) for c, v in o_refs]

        mapping = align(r_nums, o_nums)

        # Runs of constant (chapter delta, verse delta), judged as a
        # whole: one noisy verse in the middle of a shifted stretch must
        # not punch an identity-mapped hole through it.
        runs: list[list[int]] = []
        gains: list[list[float]] = []
        for idx, (c, v) in enumerate(r_refs):
            j = mapping[idx]
            if j is None:
                continue
            oc, ov = o_refs[j]
            if (oc, ov) == (c, v):
                continue
            there = sim(r_nums[idx], o_nums[j])
            same = originals.get(f"{c}:{v}")
            here = sim(r_nums[idx], nums(same)) if same else 0.0
            dc, dv = oc - c, ov - v
            if runs and runs[-1][0] == c and runs[-1][2] == v - 1 \
                    and runs[-1][3] == dc and runs[-1][4] == dv:
                runs[-1][2] = v
                gains[-1].append(there - here)
            else:
                runs.append([c, v, v, dc, dv])
                gains.append([there - here])

        shifted: dict[tuple[int, int], tuple[int, int]] = {}
        for run, g in zip(runs, gains):
            if sum(g) / len(g) < MIN_GAIN:
                continue
            c, v0, v1, dc, dv = run
            for v in range(v0, v1 + 1):
                shifted[(c, v)] = (c + dc, v + dv)

        # A reading verse may cover MORE than one original verse: the
        # CUV prints a psalm's superscription inside verse 1, where the
        # Hebrew numbers it as a verse of its own, and 1 Chronicles 12:4
        # is Hebrew 12:4 and 12:5 together. Give those verses the whole
        # range rather than picking one half — picking loses text.
        claimed = {j: i for i, j in enumerate(mapping) if j is not None}
        o_index = {ref: i for i, ref in enumerate(o_refs)}
        entries: dict[str, list[str]] = {}
        for idx, (c, v) in enumerate(r_refs):
            j = mapping[idx]
            target = shifted.get((c, v))
            # A rejected shift falls back to the verse's own number
            # rather than to nothing, so absorption can still run: 3
            # John has 14 verses here and 15 in the Greek, and verse 14
            # carries both — the body of Greek 14 and, parenthesised,
            # the whole of Greek 15.
            if target is not None:
                anchor = o_index.get(target)
            elif (c, v) in o_index:
                anchor = o_index[(c, v)]
            else:
                anchor = j
            if anchor is None:
                continue
            here = [o_refs[anchor]]

            def claims(k: int, ahead: bool) -> bool:
                if k < 0 or k >= len(o_refs):
                    return False
                if claimed.get(k, idx) != idx:
                    return False
                mine = covers(r_nums[idx], o_nums[k])
                if mine < ABSORB_MIN:
                    return False
                other = idx + 1 if ahead else idx - 1
                if 0 <= other < len(r_nums) and \
                        covers(r_nums[other], o_nums[k]) >= mine:
                    return False
                return True

            k = anchor - 1
            while claims(k, False):
                here.insert(0, o_refs[k])
                k -= 1
            # And forwards: the CUV prints Revelation 12:18 at the end of
            # 12:17, and 3 John's verse 15 inside verse 14 as a
            # parenthetical. Those original verses trail the match
            # instead of leading it.
            k = anchor + len(here)
            while claims(k, True):
                here.append(o_refs[k])
                k += 1
            mapped = [f"{a}:{b}" for a, b in here]
            if mapped != [f"{c}:{v}"]:
                entries[f"{c}:{v}"] = mapped

        if entries:
            result[book] = entries
            total_entries += len(entries)

    print(f"books with a differing versification: {len(result)}")
    print(f"verses remapped: {total_entries}")
    for book, entries in result.items():
        sample = list(entries.items())[:3]
        summary = ", ".join(f"{k}→{'+'.join(v)}" for k, v in sample)
        print(f"  {book}: {len(entries)} verses  {summary} …")

    if args.write:
        OUT.write_text(
            json.dumps(result, ensure_ascii=False, indent=1, sort_keys=True)
            + "\n", encoding="utf-8")
        print(f"\nwrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
