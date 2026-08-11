#!/usr/bin/env python3
"""Map the CUV's MERGED verses onto the original verses they carry.

`assets/originals_versification.json` answers "which Hebrew/Greek verse
carries the text of this reading verse" for the differences between the
two editions' numbering. It cannot answer a second, separate question:
the CUV translators sometimes fold two numbered verses into one and
print the vacated number as 「见上节」 — literally "see the previous
verse". 民数记 1:21 is such a verse, and the census total it should hold
(四万六千五百) is printed at the end of 1:20.

So the Originals sheet on 民数记 1:20 showed the Hebrew of 1:20 alone —
half the verse the reader is looking at, with 「שִׁשָּׁה וְאַרְבָּעִים
אֶלֶף וַחֲמֵשׁ מֵאוֹת」 missing. Not a wrong word; a missing one.

**This is a property of the TRANSLATION, not of the Hebrew**, which is
why it cannot go in the base map: the base map is applied to every
version, and the KJV, NASB and LEB all number 1:21 as a verse of its own
with text in it. Widening the base map would fix the CUV by showing KJV
readers a Hebrew clause their verse 20 does not contain — the very
defect the base map was built to remove. Hence a per-version overlay.

The evidence is the translation's own marker, never a judgement of ours:

  * 「见上节」 / 「見上節」            — 70 verses, folded into the previous
  * 「合和译本并入上一节」            — 詩篇 63:6, the same thing said longer
  * 「见下节」 / 「見下節」            — 約翰福音 7:53, folded into the NEXT
    verse (8:1 prints 「于是各人都回家去了；耶稣却往橄榄山去」, which is
    Greek 7:53 and 8:1 together)

A verse whose whole text is some other note — 「<note: 有古卷在此有…>」 at
使徒行传 8:37 and its kin — is NOT a merge and is left alone.

Writes assets/originals_versification_merged.json:
    {version: {book slug: {reading ref: [original refs]}}}

Usage:
    python3 tools/build_merged_verse_map.py [--write]
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent
ORIGINALS = ROOT / "assets" / "originals"
BASE = ROOT / "assets" / "originals_versification.json"
OUT = ROOT / "assets" / "originals_versification_merged.json"

VERSIONS = ("cuvs-yhwh", "cuvs-yhwh-tr")

NOTE = re.compile(r"<note:[^>]*>")
BARE_PREV = ("见上节", "見上節")
NOTE_PREV = ("见上节", "見上節", "并入上一节", "並入上一節", "併入上一節")
NOTE_NEXT = ("见下节", "見下節")


def load(path: pathlib.Path) -> object:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def book_slugs() -> dict[str, str]:
    """Chinese/English book name → the slug the originals assets use."""
    src = (ROOT / "lib" / "constants" / "book_names.dart").read_text(
        encoding="utf-8")
    out: dict[str, str] = {}
    for name, english in re.findall(r"'([^']+)':\s*'([A-Za-z0-9' ]+)'", src):
        out[name] = english.lower().replace(" ", "_").replace("'", "")
    return out


def merge_direction(text: str) -> str | None:
    """'prev', 'next', or None — read off the translation's own marker."""
    body = NOTE.sub("", text).strip()
    if body in BARE_PREV:
        return "prev"
    if body:
        return None
    notes = " ".join(NOTE.findall(text))
    if any(k in notes for k in NOTE_NEXT):
        return "next"
    if any(k in notes for k in NOTE_PREV):
        return "prev"
    return None


def sort_key(ref: str) -> tuple[int, int]:
    c, _, v = ref.partition(":")
    return (int(c), int(v))


def build(version: str, base: dict, slugs: dict[str, str],
          verbose: bool) -> tuple[dict[str, dict[str, list[str]]], Counter]:
    rows = load(ROOT / "assets" / f"{version}.json")
    stats: Counter = Counter()

    # Reading order, per book, as the asset ships it.
    verses: list[tuple[str, str, str]] = []  # slug, "c:v", text
    for row in rows:
        slug = slugs.get(row["book"])
        chapter, verse = row.get("chapter"), row.get("verse")
        if not slug or not str(chapter).isdigit() or not str(verse).isdigit():
            continue
        verses.append((slug, f"{chapter}:{verse}", row["text"]))

    def base_refs(slug: str, ref: str) -> list[str]:
        return base.get(slug, {}).get(ref, [ref])

    extra: dict[tuple[str, str], list[str]] = {}
    for i, (slug, ref, text) in enumerate(verses):
        direction = merge_direction(text)
        if direction is None:
            continue
        stats[direction] += 1
        step = -1 if direction == "prev" else 1
        j = i + step
        # Skip a run of pointers: 詩篇 8:6 carries 8:7 AND 8:8.
        while 0 <= j < len(verses) and verses[j][0] == slug \
                and merge_direction(verses[j][2]) is not None:
            j += step
        if not (0 <= j < len(verses)) or verses[j][0] != slug:
            stats["no absorbing verse"] += 1
            continue
        extra.setdefault((verses[j][0], verses[j][1]), []).extend(
            base_refs(slug, ref))
        if verbose:
            print(f"  {slug} {verses[j][1]} absorbs {ref} "
                  f"→ {base_refs(slug, ref)}")

    out: dict[str, dict[str, list[str]]] = {}
    for (slug, ref), added in extra.items():
        refs = sorted(set(base_refs(slug, ref)) | set(added), key=sort_key)
        if refs == base_refs(slug, ref):
            continue
        out.setdefault(slug, {})[ref] = refs
        stats["entries"] += 1

    # Nothing may point at an original verse that does not exist, and
    # nothing may claim a verse whose original text is missing.
    for slug, entries in out.items():
        path = ORIGINALS / f"{slug}.json"
        have = set(load(path).keys()) if path.exists() else set()
        for ref, refs in entries.items():
            for target in refs:
                if target not in have:
                    raise SystemExit(
                        f"{version} {slug} {ref} → {target}, which "
                        f"assets/originals/{slug}.json does not have")
    return out, stats


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    base = load(BASE)
    slugs = book_slugs()
    result: dict[str, dict[str, dict[str, list[str]]]] = {}
    for version in VERSIONS:
        print(f"{version}:")
        entries, stats = build(version, base, slugs, args.verbose)
        result[version] = entries
        print(f"  merged into the previous verse: {stats['prev']}")
        print(f"  merged into the next verse:     {stats['next']}")
        print(f"  reading verses widened:         {stats['entries']} "
              f"in {len(entries)} books")
        if stats["no absorbing verse"]:
            print(f"  UNABSORBED: {stats['no absorbing verse']}")

    if args.write:
        OUT.write_text(
            json.dumps(result, ensure_ascii=False, indent=1, sort_keys=True)
            + "\n", encoding="utf-8")
        print(f"\nwrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
