#!/usr/bin/env python3
"""Remove the two closing brackets the reading assets print with no opener.

士師記 8:24 ends `…都是戴金耳環的。〕` and 耶利米書 10:11 ends `…被除滅！〕`.
Nothing opens either. `〕` is in no annotation pattern in
`build_verse_content_spans.dart`, so both are painted literally: a reader sees
a closing bracket sitting in scripture.

**The direction of the repair was got wrong on the first pass and is the whole
point of this docstring.** The obvious reading is that an opener was lost and
should be restored — blob `7a2dc43` brackets the aside at both verses
(`…耳環給我。」（原來仇敵是以實瑪利人…的。）`, and the whole of 耶 10:11), and
`assets/tagged/cuvs-yhwh/judges.json` 8:24 agrees on that scope. That argument
is wrong twice over, and the measurements that break it are these.

**1. There is only one witness line here, not two.** SeekSparks'
`cuvs-plus.json` is not an independent copy — it is this edition's BASE TEXT.
Normalising 雅伟→耶和华 and 〔〕→（）, **23,845 of 31,102 verses are
character-identical**, and at both disputed verses our string equals the base's
exactly but for `）`→`〕`. So "two lines carry the orphan" is one line counted
twice, and the orphan was inherited rather than independently attested.

**2. This edition has already ruled on this exact shape, three times, and it
ruled DELETE.** Pair every bracket across the whole base text in verse order:
it carries **9 unpaired marks — 5 orphan closers and 4 orphan openers**. The
editorial pass that produced our asset resolved 7 of the 9, and the split is
perfectly clean:

* **Orphan OPENER (the scope is known, because you can see where it starts) —
  completed.** 路加福音 8:45 gained a closing `〕` so the 有古卷 note became a
  self-contained pair; 羅馬書 2:13's aside gained its closer at 2:15;
  約翰福音 4:8's mistyped `〉` was corrected to `）`; 希伯來書 2:7 became a
  `<note: …>`.
* **Orphan CLOSER (only the end survives in the base, so the scope is a
  guess) — the mark is removed.** 出埃及記 9:32 `…還沒有長成。）` →
  `…還沒有長成。`, the text left unbracketed. 出埃及記 16:32 and
  撒母耳記上 14:43 each had a gloss whose opener was gone; both became
  `<note: …>` and the stray `）` went.

  Worth stating exactly, because the precedent is stronger than the rule
  needs: blob `7a2dc43` DOES open 出 9:32's span, at 出 9:31
  `（那時，麻和大麥被雹擊打…`. The scope was recoverable from a witness — just
  not from the base, where 9:31 carries no opener either. Faced with an
  orphan closer this edition removed it rather than reach outside its base
  for a scope.

Every completion in the corpus had a surviving opener. **No completion anywhere
rested on a surviving closer alone.** 士 8:24 and 耶 10:11 are the two the pass
missed, and they are the orphan-closer case — 3 for 3 resolved by removing the
mark.

**3. The witness that would have justified an insertion is the one this repo
has already learned not to lean on.** Blob `7a2dc43` brackets 992 verses that
we do not bracket at all, so "the blob brackets it" describes a house-style
difference, not a defect. And the `〔` **this tool's first draft proposed to
insert** would have been the wrong mark anyway — that is a fault in the
draft, not in the blob, which carries zero `〔〕` and writes this class
`（）` throughout. Our edition brackets its two other 原來-narrator asides
`（原來法利賽人…` (可 7:3) and `（原來在神面前…` (羅 2:13) with `（`, never `〔`,
so completing the surviving `〕` would have produced a `〔原來` token found
nowhere else in the corpus.

**Deletion is also the direction with less to lose.** Removing a mark that
opens nothing takes a false character off the screen without asserting where an
aside begins. At 耶 10:11 an insertion would have asserted a scope two other
lines contradict: `assets/tagged/cuvs-yhwh/jeremiah.json` 10:11 brackets
nothing and uses quotation marks, and the printed 1919 transcription brackets
6 places in Jeremiah — 25:4, 26:5, 29:2, 34:9, 38:7, 51:59 — but not this one.

**Scope of the change: two verses, two files, one character each.** No
ideograph moves. Afterwards the reading assets pair to zero unpaired brackets,
which is what `test/orphan_close_bracket_test.dart` pins. The tagged word-tap
corpus was censused for the same defect and has none: 352 `（`/`）` and 1,290
`〔`/`〕`, balanced in all 66 books.

Usage:
    python3 tools/repair_orphan_close_bracket.py [--write]
"""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ASSETS = [REPO / "assets" / "cuvs-yhwh.json", REPO / "assets" / "cuvs-yhwh-tr.json"]

OPENERS = "（〔"
CLOSERS = "）〕"

# id -> the sentence-final mark the orphan closer must sit directly after.
# The two editions differ in glyphs (環/环, 滅/灭) but not in punctuation, so
# this identifies the verse without needing a table per edition.
TARGETS = {
    "007008024": "。",
    "024010011": "！",
}


def _tail_matches(text: str, preceding: str) -> bool:
    return text.endswith(preceding + "〕")


def unpaired(verses: list[dict]) -> tuple[list[str], list[str]]:
    """Pair every bracket across the corpus in verse order.

    Per-verse balance is the wrong test: eleven of this edition's 〔…〕 asides
    legitimately open at the end of one verse and close at the end of the next.
    """
    stack: list[str] = []
    orphan_closers: list[str] = []
    for v in verses:
        for ch in v["text"]:
            if ch in OPENERS:
                stack.append(v["id"])
            elif ch in CLOSERS:
                if stack:
                    stack.pop()
                else:
                    orphan_closers.append(v["id"])
    return orphan_closers, stack


def main() -> int:
    write = "--write" in sys.argv
    failures = 0

    for path in ASSETS:
        verses = json.loads(io.open(path, encoding="utf-8").read())
        by_id = {v["id"]: v for v in verses}

        orphan_closers, orphan_openers = unpaired(verses)
        if orphan_openers:
            print(f"{path.name}: REFUSING — {len(orphan_openers)} unpaired opener(s): "
                  f"{orphan_openers}")
            failures += 1
            continue
        if sorted(orphan_closers) != sorted(TARGETS):
            print(f"{path.name}: nothing to do (orphan closers: {orphan_closers})")
            continue

        for vid in TARGETS:
            v = by_id[vid]
            if not _tail_matches(v["text"], TARGETS[vid]):
                print(f"{path.name}: REFUSING at {vid} — the orphan 〕 is not "
                      f"verse-final: {v['text'][-12:]!r}")
                failures += 1
                continue
            before = v["text"]
            v["text"] = before[:-1]
            print(f"{path.name} {v['book']} {v['chapter']}:{v['verse']}")
            print(f"    - {before[-24:]}")
            print(f"    + {v['text'][-24:]}")

        if failures:
            continue

        still_closers, still_openers = unpaired(verses)
        if still_closers or still_openers:
            print(f"{path.name}: REFUSING — brackets still unpaired after the edit")
            failures += 1
            continue

        if write:
            # `indent=2` + a trailing newline round-trips these two files
            # byte-for-byte, so the diff is the two characters removed.
            io.open(path, "w", encoding="utf-8").write(
                json.dumps(verses, ensure_ascii=False, indent=2) + "\n"
            )
            print(f"{path.name}: written")

    if not write and not failures:
        print("\ndry run — pass --write to apply")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
