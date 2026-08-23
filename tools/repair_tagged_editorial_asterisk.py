#!/usr/bin/env python3
"""Take the importer's `主*` marker out of the word-tap corpus.

`assets/tagged/cuvs-yhwh/` is what "tap a word to see the original" prints:
`originals_sheet.dart` renders those runs verbatim *instead of* the reader's
verse whenever `TaggedTextService.coversVerse` says the runs lose nothing. So
a character in this asset that is not scripture is a character printed to the
reader as scripture.

115 verses carried one. 哥林多前書 2:8 printed 「就不把榮耀的主* 釘在十字架
上了」; 馬太福音 20:33 printed 「主* 啊，要我們的眼睛能看見！」. 122 of the
124 asterisks stand immediately after 主 and the other two after 主 and a
space (路加福音 24:34, 馬太福音 9:28); 118 of the runs carrying one are tagged
G2962, κύριος.

**The rule is measured, not chosen.** `*` occurs **zero** times in the 62,204
verses of the two reading assets (`assets/cuvs-yhwh.json` and `-tr.json`) and
124 times in this second transcription, so it is import residue rather than
something the edition prints. More directly: at all 115 references the reading
verse — the text the reader is actually looking at — reads a plain 主.

**It is a deletion, not a substitution, and that is the difference from `#`.**
`repair_tagged_markup.py` turns `主#` into `主[基督]` in 15 verses, but only
because `cuvs-yhwh.json` prints 主[基督] at those very references. The corpus
can carry this edition's referent glosses — 哥林多前書 1:31 stores runs reading
`主 [` and `雅伟] 夸口。` — and the edition uses them freely in the NT, where
these 115 all are: `主[雅伟]` in 197 reading verses and `[基督]` in 15. The
overlap with these 115 is **zero and zero**. So the asterisk is not a mangled
gloss with something to restore, and it is not this edition's divine-name
convention either — that convention is the bracket, and it is demonstrably
absent here. The marker simply goes.

**The 19 split runs keep their word, and no tag moves onto a word it did not
already cover.** 105 asterisks are glued to their word
(`{"w":"主* ","s":"G2962","i":["G3588"]}`) and deleting the marker leaves 主
tagged κύριος. In 19 the importer split it off instead —
`{"w":"主","s":"G3588"}, {"w":"* ","s":"G2962"}` — and there a plain deletion
does damage twice over: 11 runs would be left holding a Strong's number and no
text at all, and the other 8 would be left as a bare `，` or `。”` carrying a
tap recognizer. Either way κύριος becomes unreachable and tapping 主 answers
G3588, ὁ, the article.

So the 主 those runs mark is moved into them — in all 19 it is the last
character of the run before, and in all 19 that run is tagged G3588 against
the marker's G2962 — and the leftover punctuation stays attached to it. Where
that empties the preceding run it is dropped and its number folded into `i`,
which is what `i` is documented to hold (`tagged_text_service.dart`: "Numbers
the original has that this text does not render — … the Greek article").

**The resulting shape is not invented, and the precedent is corpus-wide
rather than local.** `{"w":"主","s":"G2962","i":["G3588"]}` occurs **125
times** in this corpus already, and 195 runs read exactly 主 tagged G2962. It
would be wrong to say "the other 105 asterisks look like this": only 23 of
them carry `i:["G3588"]` and six are not tagged G2962 at all (使徒行傳 7:59
G2532, 22:18 G846, 約翰福音 13:24 G2076, 路加福音 9:59 G2010, 17:5 G4369,
22:31 G4613 — a pre-existing mis-alignment this repair does not touch and
does not create).

Four of the 19 do not empty their predecessor — `有人把主`, `称呼我主`,
`是你们的主`, `对主` — and there the remainder keeps the exact number it
already had and only 主 takes κύριος. Merging the whole phrase instead would
have made 有人把 answer κύριος, which is why it is done this way. The honest
cost: in those four the article's G3588 stays on a run that no longer holds
its noun, and in the other 15 it moves into `i`, which the sheet does not
render. Neither is a new falsehood — before this, tapping 主 in all 19 places
answered ὁ, "the".

**Three gates, and every verse must pass all three.** The reading verse for
the same reference carries no `*` of its own; the Chinese is conserved
character for character; and the verse does not move away from the reader's
verse. 114 of the 115 land at distance 0. The one that does not is
馬太福音 9:28, where the corpus reads 「耶穌說說：」 for the reading asset's
「耶穌說：」 — a doubled character that is a different defect, filed separately
and left exactly as it was.

Usage:
    python3 tools/repair_tagged_editorial_asterisk.py [--write]
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
TAGGED = ROOT / "assets" / "tagged" / "cuvs-yhwh"

_spec = importlib.util.spec_from_file_location(
    "repair_tagged_markup", ROOT / "tools" / "repair_tagged_markup.py"
)
markup = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(markup)

CJK = re.compile(r"[一-鿿㐀-䶿]")
# The marker and the single space the importer set beside it. Anchored on
# the asterisk, so the spaces the corpus uses legitimately — 「主 [雅伟]」,
# 「以巴录 、」, 624 of them — are never touched.
MARKER = re.compile(r" ?\* ?")
MARKED_WORD = "主"


def chinese(s: str) -> list[str]:
    return sorted(c for c in s if CJK.fullmatch(c))


def repair_verse(runs: list[dict]) -> list[dict] | None:
    """The verse with the marker gone, or None if it never carried one.

    A run left with no word of its own reclaims the 主 it marks from the
    run before it, so that κύριος stays reachable and nothing else in
    that run inherits it.
    """
    if not any("*" in r.get("w", "") for r in runs):
        return None
    out: list[dict] = []
    for run in runs:
        text = run.get("w", "")
        if "*" not in text:
            out.append(dict(run))
            continue
        leftover = MARKER.sub("", text)
        replacement = dict(run)
        if CJK.search(leftover):
            replacement["w"] = leftover
            out.append(replacement)
            continue
        if not out or not out[-1].get("w", "").rstrip(" ").endswith(MARKED_WORD):
            # The marker has nothing to attach to. Refused upstream.
            replacement["w"] = leftover
            out.append(replacement)
            continue
        previous = out[-1]
        previous["w"] = previous["w"].rstrip(" ")[: -len(MARKED_WORD)]
        replacement["w"] = MARKED_WORD + leftover
        if not previous["w"]:
            out.pop()
            implied = [previous.get("s", "")] + list(replacement.get("i", []))
            implied = [n for i, n in enumerate(implied) if n and n not in implied[:i]]
            if implied:
                replacement["i"] = implied
        out.append(replacement)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    reading = markup.reading_index()
    repaired: list[str] = []
    refused: list[str] = []

    for path in sorted(TAGGED.glob("*.json")):
        book = json.loads(path.read_text("utf-8"))
        verses = reading.get(path.stem, {})
        touched = False

        for ref, runs in book.items():
            after = repair_verse(runs)
            if after is None:
                continue
            where = f"{path.stem} {ref}"
            reading_text = verses.get(ref)
            if reading_text is None:
                refused.append(f"{where}: no reading verse to check against")
                continue
            if "*" in reading_text:
                refused.append(f"{where}: the reading verse uses an asterisk too")
                continue
            was = "".join(r.get("w", "") for r in runs)
            now = "".join(r.get("w", "") for r in after)
            if "*" in now:
                refused.append(f"{where}: an asterisk survived the repair")
                continue
            if chinese(was) != chinese(now):
                refused.append(f"{where}: the Chinese changed")
                continue
            blank = lambda rs: sum(1 for r in rs if not r.get("w", ""))  # noqa: E731
            if blank(after) > blank(runs):
                refused.append(f"{where}: the repair emptied a run")
                continue
            if markup.distance(reading_text, now) > markup.distance(
                reading_text, was
            ):
                refused.append(f"{where}: moves away from the reader's verse")
                continue
            book[ref] = after
            repaired.append(f"{where}: {was}\n      -> {now}")
            touched = True

        if touched and args.write:
            path.write_text(
                json.dumps(book, ensure_ascii=False, separators=(",", ":")), "utf-8"
            )

    print(f"repaired: {len(repaired)} verses")
    for line in repaired:
        print(f"  -- {line}")
    if refused:
        print(f"\nleft for a human: {len(refused)}")
        for line in refused:
            print(f"  -- {line}")
    if not args.write:
        print("\n(dry run — pass --write to apply)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
