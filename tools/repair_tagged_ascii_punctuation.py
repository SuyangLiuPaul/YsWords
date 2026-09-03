#!/usr/bin/env python3
"""Settle the half-width ASCII punctuation left in the word-tap corpus.

`assets/tagged/cuvs-yhwh/` is not a side index. `originals_sheet.dart` renders
those runs **verbatim in place of** the reader's verse whenever
`TaggedTextService.coversVerse` says the runs lose nothing, so a half-width
mark in this asset is a half-width mark in scripture on screen — and none of
these is visible to `coversVerse`, which compares ideographs only.

Measured 2026-09-03 over the 31,102 verses of the corpus:

    ,  27 in 21 verses      .  16 in 13 verses
    !  11 in 11 verses      ;   4 in  4 verses
    :  56 in 53 verses  — 52 of them inside the edition's own 〔…〕 note

against 100,000-odd full-width marks in the same files.

**Two of the queue's measurements were wrong and are corrected here.**

* `.` is **not** absent from the reading assets. 羅馬書 8:34 stores
  `<note: 有基督....或作…>` in `cuvs-yhwh.json` AND in `cuvs-yhwh-tr.json`,
  and the tagged corpus stores the same four dots inside its own
  `〔"有基督...."：或作…〕`. Three transcription lines agreeing is the
  strongest witness this repo has: that ellipsis is the edition's apparatus,
  not import damage. It is KEPT, which is why the tool has a `keep` action at
  all rather than a blanket rule.
* `:` is **not** wholly legitimate. 52 of the 56 do live in a cross-reference
  note (`〔創10:3作"利法"〕`) and are out of scope by rule — the scan skips
  anything inside 〔…〕. **Four stand in running text**, three of them in the
  speech-colon shape the edition sets `：` everywhere else: 使徒行傳 1:24
  「祷告说:“主…」, 路加福音 18:37 「他们告诉他:“是拿撒勒人…」, 羅馬書 4:18
  「正如先前所说:“你的后裔…」 and 約伯記 11:6 「所以当知道: 神追讨你」. The
  reading asset sets `：` in the same slot in the first three.

**Nothing is decided by rule; every position is in DECISIONS with its action.**
The tool refuses to run if it finds a scoped mark in a verse it has no
decision for, or a count that does not match. Four actions:

  * **width** — the mark is right and only its width is wrong. `,`→，
    `.`→。 `!`→！ `;`→； `:`→：. 46 positions. Where the reading asset sets
    the full-width mark in the same slot that is the confirmation (all 11 `!`,
    the 1 `;` at 帖前 2:13, three of the four `:`). Where the two
    transcriptions punctuate differently — the 約伯記 11 block reads `, ` at
    clause breaks the reading asset sets `；` or leaves open, 撒母耳記下 22
    reads `; ` where the reading asset reads `，` — the DIVERGENCE IS NOT
    TOUCHED. Which mark this line uses is its own transcription's choice and
    is none of a punctuation repair's business; only its width is. This is the
    rule `tools/repair_ascii_punctuation.py` already settled at 約伯記 6:8.
  * **delete (doubled)** — the ASCII mark stands immediately before the
    full-width mark it duplicates: `強暴.。` at 創世記 6:11, `為定.。` at
    民數記 30:4, `利益.；` at 箴言 31:11. Eight positions; the reading verse
    carries the full-width mark alone.
  * **delete (stray)** — the position is one no Chinese punctuation can
    occupy and no witness marks: a period between 你们 and 了 (馬太福音
    12:28), between 变为 and 荒场 (詩篇 69:25), before an opening 〔note〕 in a
    verse that already closes after it (箴言 4:7), and a comma directly after
    `：` (撒迦利亞書 3:9 「万军之雅伟说：, 我要」) — the same shape
    `tools/repair_stray_punctuation.py` deleted at 阿摩司書 6:10. Four
    positions.
  * **keep** — 羅馬書 8:34's four dots, above.

Three gates run per verse before anything is written, the same three the
bracket repair used: the Chinese is conserved character for character, the
verse does not move away from the reader's verse (`markup.distance`), and no
scoped mark survives except the ones marked `keep`. A verse failing any of
them is reported and left alone.

Run BEFORE `tools/repair_tagged_stray_spaces.py` — that tool reads the
character on either side of a space as its witness, and this one changes it.

Idempotent: a verse whose decisions are already applied holds no scoped mark
and is skipped.

Usage:
    python3 tools/repair_tagged_ascii_punctuation.py [--write]
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import repair_tagged_markup as markup  # noqa: E402

TAGGED = markup.TAGGED
CJK = re.compile(markup.CJK)
NOTE = re.compile(r"〔[^〕]*〕")

WIDTH = {",": "，", ".": "。", "!": "！", ";": "；", ":": "："}
SCOPED = set(WIDTH)

W, D, K = "width", "delete", "keep"

# One entry per verse holding a scoped mark, one action per mark, in the order
# the marks appear in the joined verse. See the module docstring for why each
# action is what it is.
DECISIONS: dict[tuple[str, str], tuple[str, ...]] = {
    ("1_chronicles", "2:8"): (D,),
    ("1_thessalonians", "1:1"): (W,),
    ("1_thessalonians", "2:13"): (W,),
    ("2_samuel", "22:15"): (W,),
    ("2_samuel", "22:43"): (W,),
    ("2_samuel", "22:47"): (W,),
    ("acts", "1:24"): (W,),
    ("acts", "5:12"): (D,),
    ("acts", "27:16"): (W,),
    ("galatians", "1:20"): (W,),
    ("genesis", "6:11"): (D,),
    ("genesis", "43:14"): (W,),
    ("genesis", "43:29"): (W,),
    ("genesis", "44:10"): (W,),
    ("genesis", "44:17"): (W,),
    ("job", "2:11"): (W, W),
    ("job", "6:8"): (W,),
    ("job", "10:21"): (W,),
    ("job", "11:4"): (W,),
    ("job", "11:5"): (W,),
    ("job", "11:6"): (W, W, W),
    ("job", "11:7"): (W,),
    ("job", "11:9"): (W,),
    ("job", "11:12"): (W,),
    ("job", "11:15"): (W,),
    ("job", "11:17"): (W,),
    ("job", "11:18"): (W,),
    ("job", "11:20"): (W, W),
    ("job", "12:2"): (W,),
    ("job", "15:15"): (W,),
    ("job", "15:17"): (W,),
    ("joel", "1:11"): (W,),
    ("joel", "1:15"): (W,),
    ("luke", "8:12"): (W,),
    ("luke", "18:37"): (W,),
    ("mark", "1:5"): (W, W, W),
    ("mark", "14:45"): (W,),
    ("mark", "15:16"): (D,),
    ("matthew", "12:28"): (D,),
    ("matthew", "12:33"): (W,),
    ("matthew", "21:14"): (D,),
    ("matthew", "26:49"): (W,),
    ("numbers", "30:4"): (D,),
    ("proverbs", "4:7"): (D,),
    ("proverbs", "13:9"): (D,),
    ("proverbs", "31:11"): (D,),
    ("psalms", "69:25"): (D,),
    ("romans", "4:18"): (W,),
    ("romans", "8:34"): (K, K, K, K),
    ("zechariah", "2:4"): (W,),
    ("zechariah", "3:9"): (D,),
    ("zechariah", "5:3"): (W, W),
}


def note_spans(verse: str) -> list[tuple[int, int]]:
    return [(m.start(), m.end()) for m in NOTE.finditer(verse)]


def scoped_positions(verse: str) -> list[int]:
    """Indices of the ASCII marks this tool may act on.

    A `:` inside 〔…〕 is the edition's own cross-reference and is skipped;
    every other scoped mark counts wherever it stands.
    """
    spans = note_spans(verse)
    out = []
    for i, ch in enumerate(verse):
        if ch not in SCOPED:
            continue
        if ch == ":" and any(a <= i < b for a, b in spans):
            continue
        out.append(i)
    return out


def chinese(text: str) -> str:
    return "".join(c for c in text if CJK.fullmatch(c))


def apply(runs: list[str], actions: tuple[str, ...]) -> list[str] | None:
    """Rewrite one verse's runs, or None when the actions do not fit it."""
    verse = "".join(runs)
    marks = scoped_positions(verse)
    if not marks:
        return None  # already repaired, or nothing scoped here
    if len(marks) != len(actions):
        raise ValueError(f"{len(marks)} scoped marks, {len(actions)} decisions")

    # Map each global index onto (run, offset) so runs are edited in place and
    # the run boundaries — which carry the Strong's numbers — never move.
    edits: dict[int, list[tuple[int, str]]] = {}
    base = 0
    bounds = []
    for n, run in enumerate(runs):
        bounds.append((base, base + len(run), n))
        base += len(run)
    for index, action in zip(marks, actions):
        if action == K:
            continue
        for start, end, n in bounds:
            if start <= index < end:
                mark = verse[index]
                edits.setdefault(n, []).append(
                    (index - start, WIDTH[mark] if action == W else "")
                )
                break
        else:  # pragma: no cover - bounds cover the whole verse
            raise ValueError(f"index {index} is in no run")

    out = list(runs)
    for n, changes in edits.items():
        text = out[n]
        for offset, replacement in sorted(changes, reverse=True):
            text = text[:offset] + replacement + text[offset + 1 :]
        out[n] = text
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    reading = markup.reading_index()
    repaired: list[str] = []
    refused: list[str] = []
    seen: set[tuple[str, str]] = set()
    counts = {W: 0, D: 0, K: 0}

    for path in sorted(TAGGED.glob("*.json")):
        book = json.loads(path.read_text("utf-8"))
        verses = reading.get(path.stem, {})
        touched = False

        for ref, runs in book.items():
            before = [r.get("w", "") for r in runs]
            joined = "".join(before)
            if not scoped_positions(joined):
                continue
            where = f"{path.stem} {ref}"
            actions = DECISIONS.get((path.stem, ref))
            if actions is None:
                refused.append(f"{where}: no decision recorded for this verse")
                continue
            seen.add((path.stem, ref))
            counts[K] += actions.count(K)
            try:
                after = apply(before, actions)
            except ValueError as exc:
                refused.append(f"{where}: {exc}")
                continue
            if after is None:
                continue

            reading_text = verses.get(ref)
            if reading_text is None:
                refused.append(f"{where}: no reading verse to check against")
                continue
            joined_after = "".join(after)
            if chinese(joined) != chinese(joined_after):
                refused.append(f"{where}: the Chinese changed")
                continue
            if markup.distance(reading_text, joined_after) > markup.distance(
                reading_text, joined
            ):
                refused.append(f"{where}: moves away from the reader's verse")
                continue
            left = scoped_positions(joined_after)
            if len(left) != actions.count(K):
                refused.append(f"{where}: {len(left)} scoped marks survived")
                continue

            if joined_after == joined:
                continue
            for run, text in zip(runs, after):
                run["w"] = text
            for action in actions:
                if action != K:
                    counts[action] += 1
            repaired.append(f"{where}: {joined}\n      -> {joined_after}")
            touched = True

        if touched and args.write:
            path.write_text(
                json.dumps(book, ensure_ascii=False, separators=(",", ":")), "utf-8"
            )

    stale = sorted(set(DECISIONS) - seen)
    print(f"repaired: {len(repaired)} verses")
    for line in repaired:
        print(f"  -- {line}")
    print(
        f"\nmarks: {counts[W]} widened, {counts[D]} deleted, "
        f"{counts[K]} kept as the edition's own"
    )
    if refused:
        print(f"\nleft for a human: {len(refused)}")
        for line in refused:
            print(f"  -- {line}")
    if stale and not repaired:
        # Every decision matched nothing: the corpus is already repaired.
        print(f"\nalready applied: {len(stale)} decisions found no scoped mark")
    elif stale:
        print(f"\nunmatched decisions: {stale}")
    if not args.write:
        print("\n(dry run — pass --write to apply)")
    return 1 if refused else 0


if __name__ == "__main__":
    raise SystemExit(main())
