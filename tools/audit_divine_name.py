#!/usr/bin/env python3
"""Reproducible census of H3069 vs H3068 in assets/tagged/cuvs-yhwh/.

§三 of docs/和合本雅伟版-请教出版方.md tells the publisher "贵方的逐词对照
档在约六十处标 H3069，而我方所用的希伯来原文底本在同一个字上标 H3068"
(约六十處 = 57 + 12, per docs/autonomous-queue.md:3855). That figure was
computed ad hoc and was NOT reproducible from the repo alone: a
2026-09-06 attempt (docs/p0-drift-2026-09-06.md) got 56+12+2-unresolved
against it, because a straight `book/chapter:verse` key lookup between
`assets/tagged/cuvs-yhwh/` (CUV/English versification) and
`assets/originals/` (Hebrew versification) misses every verse the two
number differently — Ezekiel 20:45-49 is Hebrew 21:1-5, and five Psalms
(9:19, 31:21, 38:15, 48:8, 64:10) shift by one verse from their own
superscriptions on. This script applies the same
`originals_versification.json` / `_merged.json` remap
`tools/audit_strongs_tagging.py` already uses for exactly this problem,
so the count is reproducible without redoing the analysis from scratch.

Method — VERSE granularity, matching how the 2026-09-06 attempt and the
letter both counted ("56/57 verses", "12 verses"), not per-occurrence:
for every verse in the tagged corpus holding at least one H3069 run, look
up the Strong's codes present in the Hebrew word list at the remapped
ref(s) and bucket the verse:

    agree            — the Hebrew has H3069 too
    disagree_h3068   — the Hebrew has H3068 and no H3069 (the "56/57" class)
    neither           — the Hebrew has neither number at this ref (the "12" class)
    unresolved        — no Hebrew data found for any remapped ref at all

The default run also walks the 41 rows already applied by
`tools/apply_cuv_divine_name_audit.py` (tracked in
tools/cuv-2026-09-12-divine-name-audit.tsv) and, using each row's OWN
before/after strings rather than the now-already-fixed corpus, says which
bucket each row would have landed in before it was applied.

Usage:
    python3 tools/audit_divine_name.py              # census + reconciliation
    python3 tools/audit_divine_name.py --check       # pinned totals, for CI
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
TAGGED = ROOT / "assets" / "tagged" / "cuvs-yhwh"
ORIGINALS = ROOT / "assets" / "originals"
VERSIFICATION = ROOT / "assets" / "originals_versification.json"
MERGED = ROOT / "assets" / "originals_versification_merged.json"
AUDIT_TSV = ROOT / "tools" / "cuv-2026-09-12-divine-name-audit.tsv"


def load(path: pathlib.Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def mapped_refs(book: str, ref: str, base: dict, merged: dict) -> list[str]:
    return merged.get(book, {}).get(ref) or base.get(book, {}).get(ref) or [ref]


def original_codes(book: str, ref: str, cache: dict, base: dict,
                    merged: dict) -> set[str] | None:
    """Strong's codes present at the remapped Hebrew ref(s), or None if no
    Hebrew data exists for ANY of them (a genuinely unresolved key)."""
    originals = cache.get(book)
    if originals is None:
        path = ORIGINALS / f"{book}.json"
        originals = load(path) if path.exists() else {}
        cache[book] = originals
    have: set[str] = set()
    found = False
    for r in mapped_refs(book, ref, base, merged):
        words = originals.get(r)
        if words is None:
            continue
        found = True
        for w in words:
            if w.get("s"):
                have.add(w["s"])
    return have if found else None


def bucket_of(have: set[str] | None) -> str:
    if have is None:
        return "unresolved"
    if "H3069" in have:
        return "agree"
    if "H3068" in have:
        return "disagree_h3068"
    return "neither"


def census() -> dict[str, list[tuple[str, str]]]:
    base = load(VERSIFICATION)
    merged = load(MERGED).get("cuvs-yhwh", {})
    cache: dict = {}
    buckets: dict[str, list[tuple[str, str]]] = {
        "agree": [], "disagree_h3068": [], "neither": [], "unresolved": [],
    }
    for book_path in sorted(TAGGED.glob("*.json")):
        book = book_path.stem
        tagged = load(book_path)
        for ref, runs in tagged.items():
            if not any(r.get("s") == "H3069" for r in runs):
                continue
            have = original_codes(book, ref, cache, base, merged)
            buckets[bucket_of(have)].append((book, ref))
    return buckets


# --- reconciliation of the 41 already-applied rows -------------------------

TAG_RE = re.compile(r"<W([GH])(\d+)([a-z]*)>")


def tags_of(text: str) -> list[tuple[str, str, str]]:
    return TAG_RE.findall(text)


def book_key(code: str, tagged_dir: pathlib.Path) -> str | None:
    """`Gen` -> `genesis.json`, using the directory's own file names.
    Mirrors tools/apply_cuv_divine_name_audit.py's book_key exactly, so a
    change to one book-code convention cannot silently desync the two."""
    names = sorted(p.name for p in tagged_dir.glob("*.json"))
    digits = "".join(c for c in code if c.isdigit())
    letters = "".join(c for c in code if c.isalpha()).lower()
    for name in names:
        stem = name[:-5]
        if digits and not stem.startswith(digits + "_"):
            continue
        if not digits and stem[0].isdigit():
            continue
        bare = stem.split("_", 1)[-1] if digits else stem
        if bare.replace("_", "").startswith(letters):
            return name
    return None


def audit_rows() -> list[dict]:
    rows = []
    for line in AUDIT_TSV.open(encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 5:
            continue
        book, chapter, verse, before, after = parts[:5]
        pairs = [(b, a) for b, a in zip(tags_of(before), tags_of(after))
                 if b != a]
        if not pairs:
            continue
        (_, was, _), (_, now, _) = pairs[0]
        rows.append({
            "book": book, "chapter": chapter, "verse": verse,
            "was": "H" + was, "now": now and "H" + now,
        })
    return rows


def reconcile() -> dict:
    base = load(VERSIFICATION)
    merged = load(MERGED).get("cuvs-yhwh", {})
    cache: dict = {}
    result = {"in_disagree_h3068": [], "in_neither": [], "outside_both": []}
    for row in audit_rows():
        name = book_key(row["book"], TAGGED)
        if name is None:
            result["outside_both"].append((row, "no such book file"))
            continue
        book = name[:-5]
        ref = f"{int(row['chapter'])}:{int(row['verse'])}"
        if row["was"] != "H3069":
            # The reverse direction (37 vs 4 in the TSV's own words): the
            # corpus HAD H3068 and the Hebrew has H3069. That is not the
            # "corpus tags H3069" universe the letter's 57/12 count is
            # about at all.
            result["outside_both"].append((row, "reverse direction (H3068→H3069)"))
            continue
        have = original_codes(book, ref, cache, base, merged)
        b = bucket_of(have)
        if b == "disagree_h3068":
            result["in_disagree_h3068"].append(row)
        elif b == "neither":
            result["in_neither"].append(row)
        else:
            result["outside_both"].append((row, f"census says {b}"))
    return result


def audit() -> int:
    buckets = census()
    agree = buckets["agree"]
    disagree = buckets["disagree_h3068"]
    neither = buckets["neither"]
    unresolved = buckets["unresolved"]

    print("verses in assets/tagged/cuvs-yhwh/ carrying at least one H3069 "
          "run, classified by the Hebrew at the versification-remapped ref:")
    print(f"  agree (Hebrew also has H3069):            {len(agree)}")
    print(f"  disagree (Hebrew has H3068, no H3069):     {len(disagree)}"
          "   <- the letter's ~57 class")
    print(f"  neither (Hebrew has neither number here):  {len(neither)}"
          "   <- the letter's 12 class")
    print(f"  unresolved (no Hebrew data at any ref):    {len(unresolved)}")
    if unresolved:
        for book, ref in unresolved:
            print(f"    {book} {ref}")
    rec = reconcile()
    already = len(rec["in_disagree_h3068"]) + len(rec["in_neither"])
    pre_fix_total = len(disagree) + len(neither) + already
    print(f"  disagree + neither, measured NOW (after the 41-row fix) "
          f"= {len(disagree) + len(neither)}")
    print(f"  + rows already fixed that were drawn from either class "
          f"= {already}")
    print(f"  => pre-fix total = {pre_fix_total}  "
          f"(letter says 約六十處; queue's restated '57 + 12 = 69' does not "
          f"survive proper remapping — see below)")
    print()

    print("reconciliation of the 41 rows already applied "
          "(tools/cuv-2026-09-12-divine-name-audit.tsv):")
    print(f"  drawn from the disagree class:  "
          f"{len(rec['in_disagree_h3068'])}")
    print(f"  drawn from the neither class:    "
          f"{len(rec['in_neither'])}")
    print(f"  outside both (reverse-direction or a mismatch worth reading): "
          f"{len(rec['outside_both'])}")
    for row, why in rec["outside_both"]:
        print(f"    {row['book']} {row['chapter']}:{row['verse']} "
              f"{row['was']}->{row['now']}: {why}")
    print()
    print("Why 69 does not survive: the naive (non-versified) 2026-09-06 "
          "attempt got 56 'disagree' + 12 'neither' + 2 unresolved keys. "
          "Under the versified census above, 'neither' is 0 RIGHT NOW, and "
          "the reconciliation shows none of the 41 already-applied rows "
          "came from a 'neither' verse -- the fix only ever removed "
          "disagree-class verses. Since fixing disagree-class verses cannot "
          "change the neither-class count, 'neither' was ALSO 0 before the "
          "fix: there is no versified reading under which those 12 verses "
          "were ever a class distinct from 'disagree'. The 2 unresolved "
          "keys (Ezek 20:47, 20:49) resolve as AGREEMENT, not disagreement, "
          "once mapped to Hebrew 21:3/21:5. That leaves one undifferentiated "
          "disagree class, pre-fix total 60, not 57+12=69. This script "
          "cannot say what the 12 naive 'neither' verses actually were "
          "(the 2026-09-06 note did not list them) -- only that, remapped "
          "correctly, no verse in this corpus behaves the way that class "
          "was described. The near-round 60 is a light corroboration that "
          "this is what '約六十處' was counting.")
    return 0


# Pinned census, measured 2026-09-15 against commit 226450c8 (after the 41
# rows / 42 edits from tools/cuv-2026-09-12-divine-name-audit.tsv were
# applied). This is a RATCHET like tools/audit_strongs_tagging.py's PINNED:
# a legitimate future sweep of the remaining disagree/neither verses can
# move these numbers, and when it does the fix updates this pin in the
# same commit and explains the delta, rather than the check being widened
# to tolerate drift.
PINNED = {
    "agree": 295,
    "disagree_h3068": 23,
    "neither": 0,
    "unresolved": 0,
}
PINNED_RECONCILE = {
    "in_disagree_h3068": 37,
    "in_neither": 0,
    "outside_both": 4,
}


def check() -> int:
    buckets = census()
    actual = {k: len(v) for k, v in buckets.items()}
    rec = reconcile()
    actual_rec = {k: len(v) for k, v in rec.items()}
    problems = []
    for key, want in PINNED.items():
        got = actual[key]
        if got != want:
            problems.append(f"census {key}: pinned {want}, measured {got} "
                             f"(delta {got - want:+d})")
    for key, want in PINNED_RECONCILE.items():
        got = actual_rec[key]
        if got != want:
            problems.append(f"reconcile {key}: pinned {want}, measured {got} "
                             f"(delta {got - want:+d})")
    if problems:
        print("FAIL:")
        for p in problems:
            print(f"  {p}")
        return 1
    print("OK: divine-name census and TSV reconciliation match PINNED.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                     help="assert PINNED holds; for CI, exits 1 on drift")
    args = ap.parse_args()
    if args.check:
        return check()
    return audit()


if __name__ == "__main__":
    raise SystemExit(main())
