#!/usr/bin/env python3
"""Take the importer's own markup back out of the tagged translation text.

`assets/tagged/cuvs-yhwh/` is what "tap a word to see the original"
reads, and the Originals sheet prints those runs *instead of* the verse
text — `originals_sheet.dart` renders `_taggedVerseLine(vo.tagged!)`
whenever a tagged line exists. So anything wrong in this asset is
printed to the reader as scripture.

185 verses carry raw importer markup inside the printed text. 詩篇 7:5
reads 「使<WH7931s>我的榮耀歸於灰塵」 and 創世記 3:16 reads
「又對<WH413<女人說」. Worse, in five places the markup swallows real
words: 列王紀上 21:8 stores 「送給<WH5612x那些與拿伯同城居住的長老>貴胄」,
so a reader cannot tell which characters are the verse.

The markup is always a mangled Strong's marker — `<` or `>` with an
adjacent run of ASCII letters and digits — and ASCII never appears in
this asset otherwise except inside the CUV's own 〔…〕 cross-reference
notes (「〔創10:3作"利法"〕」, 59 tokens, all in 〔…〕). So the rule is
derived from the data: strip `<`/`>` together with ASCII immediately
adjacent to them, and never touch a run that has no `<`, `>` or `#`.

The 15 `#` are a different fault with the same cause: the importer wrote
`主#` where the edition prints 主[基督], its own referent gloss — the
same bracket it kept intact for 主[雅伟] two words earlier in the very
same verse (使徒行傳 2:34). The `#` is replaced by `[基督]` only where
`assets/cuvs-yhwh.json` — the text the reader is actually looking at —
has `[基督]` in that verse. No character is ever invented.

Every repaired verse is then checked against the reading asset: the
repair must leave no markup behind and must move the verse CLOSER to
the reading text, never further. Anything that does not is left alone
and reported, because a verse this tool cannot settle from evidence is
a verse for a human to settle.

Two such verses were reported for twelve days — 歷代志上 21:17 and
耶利米書 4:22, where the marker had eaten a 的 and a 我 — and both are
settled as of 2026-08-24 by `SWALLOWED_PLACEMENT`. It now reports
`left alone: 0`, which is the audit worth watching: a re-import that
brings the class back will say so.

Usage:
    python3 tools/repair_tagged_markup.py [--write]
"""

from __future__ import annotations

import argparse
import difflib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TAGGED = ROOT / "assets" / "tagged" / "cuvs-yhwh"
READING = ROOT / "assets" / "cuvs-yhwh.json"
BOOK_NAMES = ROOT / "lib" / "constants" / "book_names.dart"

# `<` or `>` plus the ASCII glued to it, and — 耶利米書 34:8 stores
# 「僕人WH853x和婢女」 — a marker that lost both its brackets. Anchored
# either on a bracket or on the `WH`/`WG` prefix, so a bare 「創10:3」
# inside a 〔note〕 can never match.
MARKUP = re.compile(r"<[A-Za-z0-9]*|[A-Za-z0-9]*>|[Ww][HhGgJjMm][0-9]+[A-Za-z]*")
ARTEFACT = re.compile(r"[<>#]|[Ww][HhGgJjMm][0-9]+")

# Editorial apparatus, on either side, so the comparison is between
# scripture and scripture.
NOTE_MARKUP = re.compile(r"<[^>]*>")          # reading: <note: …>
NOTE_BRACKET = re.compile(r"〔[^〕]*〕")        # both: 〔原文作…〕
NOTE_RUNON = re.compile(r"〔[^〕]*$")           # a 〔note continued in the next verse
NON_TEXT = re.compile(
    r"[\s，。、；：？！“”‘’（）《》〈〉…—－─\-·「」『』"
    r"\.,;:!\?\"'\(\)\[\]0-9a-zA-Z]"
)

CJK = r"[一-鿿㐀-䶿]"
SWALLOWED = re.compile(rf"<[A-Za-z0-9]*{CJK}|{CJK}[A-Za-z0-9]*>")


def scripture(s: str, *, reading: bool) -> str:
    """The verse with every editorial mark and all punctuation removed."""
    if reading:
        s = NOTE_MARKUP.sub("", s)
        s = NOTE_RUNON.sub("", s)
    s = NOTE_BRACKET.sub("", s)
    return NON_TEXT.sub("", s)


def distance(reading_text: str, tagged_text: str) -> int:
    """Characters of the two verses that do not line up."""
    a = scripture(reading_text, reading=True)
    b = scripture(tagged_text, reading=False)
    matcher = difflib.SequenceMatcher(None, a, b, autojunk=False)
    return len(a) + len(b) - 2 * sum(m.size for m in matcher.get_matching_blocks())


def book_map() -> dict[str, str]:
    pairs = re.findall(r"'([^']+)'\s*:\s*'([^']+)'", BOOK_NAMES.read_text("utf-8"))
    return {chinese: english for chinese, english in pairs}


def reading_index() -> dict[str, dict[str, str]]:
    names = book_map()
    out: dict[str, dict[str, str]] = {}
    for row in json.loads(READING.read_text("utf-8")):
        english = names.get(row["book"])
        if english is None:
            sys.exit(f"unmapped book name in the reading asset: {row['book']}")
        slug = english.lower().replace(" ", "_")
        out.setdefault(slug, {})[f"{row['chapter']}:{row['verse']}"] = row["text"]
    return out


# The two verses this tool refused, settled 2026-08-24 — see the note on
# `swallowed_text`. Moving the character IS the repair, so it is written
# out run by run rather than inferred, and three things have to hold
# before it is applied: the character taken out must be the character put
# back (`_conserved`), the finished verse must reproduce the reader's
# verse ideograph for ideograph (`distance == 0`), and every rewrite
# named here must have matched exactly once.
#
# Placement is not a judgement call in either verse. The reading asset,
# the independent Traditional import and the printed 1919 page all read
# 「吩咐數點百姓的不是我嗎」 and 「不認識我」, and the run that receives the
# 我 already carries `i: [H853]` — the untranslated object marker whose
# suffix that 我 is. Nothing else in the verse can take either character
# without contradicting all three.
#
# Until this landed both verses were dropped whole by
# `TaggedTextService.carriesImporterMarkup`, so the word-tap sheet showed
# the plain line and no reader ever saw the markup. What was wrong was
# the asset, and the cost was the gesture on two verses.
SWALLOWED_PLACEMENT: dict[tuple[str, str], tuple[tuple[str, str], ...]] = {
    ("1_chronicles", "21:17"): (("百姓", "百姓的"), ("的，但这", "，但这")),
    ("jeremiah", "4:22"): (("认识；", "认识我；"), ("我的儿女，", "的儿女，")),
}


def repair_run(text: str, *, gloss: bool) -> str:
    out = MARKUP.sub("", text)
    if gloss:
        out = out.replace("#", "[基督]")
    return out


def _conserved(before: list[str], after: list[str]) -> bool:
    """Whether the two run lists hold the same Chinese, in the same count."""
    keep = lambda s: sorted(c for c in s if re.fullmatch(CJK, c))  # noqa: E731
    return keep("".join(before)) == keep("".join(after))


def place_swallowed(key: tuple[str, str], runs: list[str]) -> list[str] | None:
    """Move a swallowed character back to the clause the reader's verse puts it in."""
    rewrites = SWALLOWED_PLACEMENT.get(key)
    if rewrites is None:
        return None
    out = list(runs)
    for was, now in rewrites:
        if out.count(was) != 1:
            return None
        out[out.index(was)] = now
    return out if _conserved(runs, out) else None


def swallowed_text(text: str) -> bool:
    """Whether a marker in this run has a Chinese character inside it.

    歷代志上 21:17 stores `行了恶<WH的8687>` and 耶利米書 4:22 stores
    `<WH873我7>的儿女` — the marker has eaten a 的 and a 我 out of the
    verse, and the reading asset shows both belong somewhere else
    (「吩咐數點百姓**的**不是我嗎」, 「不認識**我**」). Deleting the marker
    would leave the character stranded in the wrong clause, and moving
    it would be reconstruction. Those verses are for a human.

    Detected by adjacency — a Chinese character butted straight against
    the ASCII of a marker, with no bracket between them — because the
    marker itself splits at that character and so cannot be matched
    whole.

    Both are settled now, by `SWALLOWED_PLACEMENT` below.
    """
    return bool(SWALLOWED.search(text))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    reading = reading_index()
    repaired = skipped = 0
    unsettled: list[tuple[str, str, str, str, str]] = []

    for path in sorted(TAGGED.glob("*.json")):
        book = json.loads(path.read_text("utf-8"))
        verses_reading = reading.get(path.stem, {})
        touched = False

        for ref, runs in book.items():
            if not any(ARTEFACT.search(r.get("w", "")) for r in runs):
                continue
            before = "".join(r.get("w", "") for r in runs)
            reading_text = verses_reading.get(ref)
            if reading_text is None:
                skipped += 1
                continue
            gloss = "[基督]" in reading_text
            candidate = [
                r.get("w", "") if not ARTEFACT.search(r.get("w", ""))
                else repair_run(r.get("w", ""), gloss=gloss)
                for r in runs
            ]
            moved = place_swallowed((path.stem, ref), candidate)
            if moved is not None:
                candidate = moved
            after = "".join(candidate)

            # A marker that swallowed Chinese is only settled when the
            # repair reproduces the reader's verse exactly; otherwise
            # the character is left stranded in the wrong clause. Where
            # the marker was pure ASCII the residual difference is the
            # two editions' own punctuation and can be tolerated, as
            # long as the repair moves the verse closer.
            exact = distance(reading_text, after) == 0
            # Never worse. Deleting a pure-ASCII marker cannot change
            # the Chinese at all, so the honest test is that the verse
            # does not move away from the text the reader is looking at.
            closer = distance(reading_text, after) <= distance(reading_text, before)
            settled = exact or (
                closer and not any(swallowed_text(r.get("w", "")) for r in runs)
            )
            if ARTEFACT.search(after.replace("[基督]", "")) or not settled:
                unsettled.append((path.stem, ref, reading_text, before, after))
                skipped += 1
                continue

            for run, text in zip(runs, candidate):
                run["w"] = text
            repaired += 1
            touched = True

        if touched and args.write:
            path.write_text(
                json.dumps(book, ensure_ascii=False, separators=(",", ":")),
                "utf-8",
            )

    print(f"repaired: {repaired} verses")
    print(f"left alone: {skipped} verses")
    for stem, ref, reading_text, before, after in unsettled:
        print(f"  -- {stem} {ref}")
        print(f"     reading: {reading_text}")
        print(f"     was    : {before}")
        print(f"     would  : {after}")
    if not args.write:
        print("\n(dry run — pass --write to apply)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
