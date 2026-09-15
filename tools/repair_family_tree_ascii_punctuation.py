#!/usr/bin/env python3
"""Widen the half-width `;`, `,`, `(`, `)` in family_tree.json's four zh fields.

`assets/family_tree.json` is our own editorial prose (Adam→Jesus family-tree
summaries), not scripture, and it is not one of the frozen 和合本雅偉版 assets
— it is ours to repair. A census of `nameZhHans`, `nameZhHant`, `summaryZhHans`
and `summaryZhHant` across all 277 people found six ASCII marks and, for each,
how it stands against the full-width twin already dominant in the same
fields:

  * `;` — 178, against `；` ×348. Widen.
  * `,` — 56, against `，` ×120. Widen.
  * `(` / `)` — 22 / 22, against `（）` ×176. Widen.
  * `:` — 100. **Left alone.** Every one is digit-adjacent — a scripture
    reference like `馬太福音 1:13-16` — which is a different convention
    (chapter:verse), not a punctuation defect.
  * `'` — 10. **Left alone.** The convention is genuinely undecided: some
    zh-Hans summaries pair `'…'` with a zh-Hant twin using `「…」`, while
    `lib/pages/bible_trivia_page.dart` sets zh-Hans inner quotes as ASCII
    `"`. That needs a call, not a sweep — filed as its own queue item.

This asset feeds `tools/build_bible_chronology.py`, which copies `nameZhHans`
/ `nameZhHant` verbatim into `bible_chronology.json` and interpolates them
into generated `derivationZhHans` / `derivationZhHant` sentences. Re-run that
generator after this script; its own diff should be limited to whichever
names it templated in (as of this writing, only `nahor_elder`'s).

Refuses on any drift: the four before-counts (`;` `,` `(` `)`) must match the
census above exactly, and after widening, `:` and `'` must be untouched (100
and 10) or nothing is written.
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ASSET = REPO / "assets" / "family_tree.json"
FIELDS = ("nameZhHans", "nameZhHant", "summaryZhHans", "summaryZhHant")

WIDEN = {";": "；", ",": "，", "(": "（", ")": "）"}
LEAVE = ":'"

EXPECTED_BEFORE = {";": 178, ",": 56, "(": 22, ")": 22}
EXPECTED_LEAVE = {":": 100, "'": 10}


def count(people, marks):
    n = {m: 0 for m in marks}
    for p in people:
        for f in FIELDS:
            v = p.get(f) or ""
            for ch in v:
                if ch in n:
                    n[ch] += 1
    return n


def main():
    data = json.loads(ASSET.read_text(encoding="utf-8"))
    people = data["people"]

    before = count(people, WIDEN)
    if before != EXPECTED_BEFORE:
        raise SystemExit(
            f"before-count drift, refusing: expected {EXPECTED_BEFORE}, "
            f"found {before}")
    leave_before = count(people, LEAVE)
    if leave_before != EXPECTED_LEAVE:
        raise SystemExit(
            f"'; '/{LEAVE!r} count drift, refusing: expected "
            f"{EXPECTED_LEAVE}, found {leave_before}")

    changed = 0
    for p in people:
        for f in FIELDS:
            v = p.get(f)
            if not v:
                continue
            if not any(m in v for m in WIDEN):
                continue
            p[f] = "".join(WIDEN.get(ch, ch) for ch in v)
            changed += 1

    after = count(people, WIDEN)
    if any(after.values()):
        raise SystemExit(f"still holds half-width marks after widening: {after}")
    leave_after = count(people, LEAVE)
    if leave_after != EXPECTED_LEAVE:
        raise SystemExit(
            f"widening moved '{LEAVE}' — refusing: expected {EXPECTED_LEAVE}, "
            f"found {leave_after}")

    # json.dumps adds no trailing newline, matching the asset's existing
    # convention (round-tripped byte-identical when nothing changes).
    text = json.dumps(data, ensure_ascii=False, indent=2)
    ASSET.write_text(text, encoding="utf-8")
    print(f"{ASSET.relative_to(REPO)}: {changed} fields widened across "
          f"{sum(EXPECTED_BEFORE.values())} marks")


if __name__ == "__main__":
    sys.exit(main())
