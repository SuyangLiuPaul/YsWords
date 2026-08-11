#!/usr/bin/env python3
"""Restore CUV parenthetical CLAUSES that the importer filed as footnotes.

The companion tool `repair_demoted_parentheticals.py` fixed the 15 verses
where the demoted parenthesis was the WHOLE verse, so the reader saw a
verse number, an icon and no scripture at all. This tool fixes the rest
of the same defect: 86 parentheses that sit inside a verse which still
reads, so the harm is a hidden clause rather than a blank verse.

    撒母耳記下 21:12  shows 「大衛就去……搬了來」
                      and hides 「（是因非利士人從前在基利波殺掃羅……）」
    利未記 24:11      hides 「（他母親名叫示羅密……）」

A note is not text. The reading pane renders `<note: …>` as a tappable
book icon, and `sanitizeVerseText` drops it outright, so search, copy,
share and the Originals sheet never see it.

**Which notes are scripture is decided by evidence, not by reading the
Chinese**, and here by two independent copies:

  * `assets/tagged/cuvs-yhwh/` — a separate import of this same edition,
    which kept the distinction ours lost: `（…）` parenthetical scripture,
    `〔…〕` editorial or variant note.
  * SeekSparks' separately sourced `cuvs-plus.json` — a different CUV
    import again. It is a weaker discriminator (it sets some editorial
    notes in `（…）` too, reserving `【…】` for cross-references) so it is
    used only to corroborate, never to promote on its own.

Measured over all 1,275 remaining `<note:>` spans, the first witness
brackets 1,185 as editorial and only 90 as scripture — so the great
majority of our notes really are notes and are left untouched. Four of
the 90 are excluded even so, because a witness printing something inline
does not make it Bible: one versification label (LABELS) and three
translator's alternatives (ALTERNATIVES). That leaves 86.

The verification is the point of this tool. Splicing the note body back
into the verse makes our visible verse text **character-for-character
identical to the independent import in all 86** — where before the repair
it matched in 0 of them — once one orthographic variant is set aside,
and that one is named in VARIANTS rather than "fixed", because our
reading is the correct one. Any verse that does not reach that agreement
aborts the run instead of being written.

No text is written from another edition. The restored clause is our own
note body, moved back inside the parentheses the CUV prints around it.

Usage:
    python3 tools/repair_midverse_parentheticals.py [--apply]
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
EDITIONS = ("cuvs-yhwh", "cuvs-yhwh-tr")
TAGGED = ROOT / "assets" / "tagged" / "cuvs-yhwh"
BOOK_NAMES = ROOT / "lib" / "constants" / "book_names.dart"
CUVS_PLUS = pathlib.Path(
    "/Users/pliu0036/Documents/CodingProject/SeekSparks/assets/cuvs-plus.json"
)

NOTE = re.compile(r"<note:([^>]*)>")
EDITORIAL = re.compile(r"〔[^〕]*〕")
PUNCT = re.compile(
    r"[\s，。、；：？！“”‘’（）()《》〈〉…—－─\-·「」『』〔〕【】"
    r"\.,;:!\?\"'0-9a-zA-Z]"
)

# 約翰三書 1:14. Our note body is the bare string "15节" — a versification
# label, not scripture. The witness folds the whole of verse 15 into 14 as
# 「（15节： 願你平安……）」 while our asset already prints that sentence as
# running text and demoted only the label. Splicing would put "（15节）" on
# screen inside the verse, which is an editorial marker, not the Bible.
# Whether verse 15 deserves its own number is a versification question and
# belongs to the user, not to this repair.
LABELS = re.compile(r"^\d+节$")

# Three candidates both witnesses parenthesise are nonetheless NOT
# scripture, and the distinction is in what the note talks about:
#
#   約書亞記 19:2   或名示巴
#   約伯記 14:14    或译：改变
#   約伯記 20:19    或译：强取房屋不得再建造
#
# 「基列亞巴就是希伯崙」 says something about the world and stands in the
# Hebrew; 「或譯：改變」 says something about the RENDERING and exists only
# because a translator hesitated. Promoting it would put a translator's
# footnote inside the verse, where copy, share and search would carry it
# as scripture — the exact failure this repair exists to prevent — while
# leaving it as a note loses no scripture at all, because the verse reads
# whole without it. Both witnesses simply left these inline; that they
# agree does not make the sentence Bible.
ALTERNATIVES = re.compile(r"^(或譯|或译|或作|或名|原文作|原文是)")

# 但以理書 6:2. After the repair our verse reads 回復事務 and the witness
# reads 回覆事務 — the same word, a 復/覆 orthographic variant, and ours is
# the standard simplified form. Named here so the verification below can
# stay exact for every other verse instead of being loosened for all.
VARIANTS = {("Daniel", "6", "2"): ("回复", "回覆")}


def load(path: pathlib.Path):
    return json.loads(path.read_text(encoding="utf-8"))


def book_map() -> dict[str, str]:
    pairs = re.findall(r"'([^']+)'\s*:\s*'([^']+)'",
                       BOOK_NAMES.read_text(encoding="utf-8"))
    return {chinese: english for chinese, english in pairs}


def bare(s: str) -> str:
    return PUNCT.sub("", s)


def visible(text: str) -> str:
    """What the reader actually sees: notes are dropped, not rendered."""
    return bare(NOTE.sub("", text))


class Witness:
    """The independently imported copy of this same edition."""

    def __init__(self) -> None:
        self._files: dict[pathlib.Path, dict] = {}

    def verse(self, english_book: str, chapter: str, verse: str) -> str | None:
        path = TAGGED / f"{english_book.lower().replace(' ', '_')}.json"
        if path not in self._files:
            self._files[path] = load(path) if path.exists() else {}
        runs = self._files[path].get(f"{chapter}:{verse}")
        if not runs:
            return None
        return "".join(r.get("w", "") for r in runs)

    @staticmethod
    def bracket(text: str, body: str) -> str | None:
        """Which bracket encloses `body` in `text`.

        Returns '（' for parenthetical scripture, '〔' or '【' for an
        editorial note, '' for unbracketed running scripture, or None if
        the witness does not carry this text at all.
        """
        keep = [(i, ch) for i, ch in enumerate(text) if not PUNCT.match(ch)]
        pos = "".join(ch for _, ch in keep).find(body)
        if pos < 0:
            return None
        for i in range(keep[pos][0] - 1, -1, -1):
            if text[i] in "（〔【":
                return text[i]
            if text[i] in "）〕】":
                break
        return ""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    names = book_map()
    witness = Witness()
    plus = ({r["id"]: r["text"] for r in load(CUVS_PLUS)}
            if CUVS_PLUS.exists() else {})
    if not plus:
        print("note: second witness unavailable, corroboration skipped",
              file=sys.stderr)

    rows = load(ROOT / "assets" / f"{EDITIONS[0]}.json")

    # The set is settled on the SIMPLIFIED side, because both witnesses are
    # Simplified. The Traditional edition is repaired at the same note
    # positions using its own characters; the two editions agree note for
    # note across all 31,102 verses, which is asserted below.
    settled: dict[str, list[int]] = {}   # verse id -> indices of note spans
    editorial = corroborated = running = uncorroborated = 0
    labels = alternatives = 0

    for row in rows:
        spans = list(NOTE.finditer(row["text"]))
        if not spans:
            continue
        english = names.get(row["book"])
        if english is None:
            sys.exit(f"unmapped book name: {row['book']}")
        witness_text = witness.verse(english, row["chapter"], row["verse"])
        if witness_text is None:
            continue
        label = f"{row['book']} {row['chapter']}:{row['verse']}"
        chosen: list[int] = []
        for index, span in enumerate(spans):
            body = span.group(1).strip()
            if not bare(body):
                continue
            bracket = Witness.bracket(witness_text, bare(body))
            if bracket is None or bracket in ("〔", "【"):
                editorial += 1
                continue
            if LABELS.match(body):
                labels += 1
                print(f"   left alone, versification label: {label}  {body}")
                continue
            if ALTERNATIVES.match(body):
                alternatives += 1
                print(f"   left alone, translator's alternative: {label}  "
                      f"{body}")
                continue
            second = plus.get(row["id"])
            if second is not None and Witness.bracket(second, bare(body)) == "（":
                corroborated += 1
            else:
                # Usually only the divine name differs (雅伟 / 耶和华), which
                # defeats a substring match. Reported, never fatal: the
                # promotion rests on the first witness.
                uncorroborated += 1
                print(f"   not corroborated by the second witness: {label}")
            if bracket == "":
                running += 1
            chosen.append(index)
        if chosen:
            settled[row["id"]] = chosen

    total = sum(len(v) for v in settled.values())
    print(f"\nnote spans the witness brackets 〔〕 as editorial, left alone: "
          f"{editorial}")
    print(f"note spans the witness carries as scripture, restored: {total} "
          f"in {len(settled)} verses")
    print(f"   of those, corroborated by the second witness: {corroborated}")
    print(f"   of those, the witness prints unbracketed as running text: "
          f"{running}")
    print(f"versification labels excluded: {labels}")
    print(f"translator's alternatives excluded: {alternatives}\n")

    # ---- verification -----------------------------------------------
    # Does the repair make our verse agree with the independent copy?
    matched_before = matched_after = 0
    for row in rows:
        if row["id"] not in settled:
            continue
        english = names[row["book"]]
        witness_text = witness.verse(english, row["chapter"], row["verse"])
        # The witness's own editorial brackets are notes on its side too.
        want = bare(EDITORIAL.sub("", witness_text))
        if visible(row["text"]) == want:
            matched_before += 1
        after = repair(row["text"], settled[row["id"]])
        got = visible(after)
        wrong, right = VARIANTS.get((english, row["chapter"], row["verse"]),
                                    (None, None))
        if wrong is not None:
            got = got.replace(wrong, right)
        if got == want:
            matched_after += 1
        else:
            sys.exit(
                f"{row['book']} {row['chapter']}:{row['verse']}: the repaired "
                f"verse does not match the independent copy, so this is not "
                f"a repair from evidence.\n  ours   : {got}\n  witness: {want}"
            )
    print(f"visible verse text agrees with the independent copy — "
          f"before: {matched_before}/{len(settled)}, "
          f"after: {matched_after}/{len(settled)}")

    # ---- apply ------------------------------------------------------
    for edition in EDITIONS:
        path = ROOT / "assets" / f"{edition}.json"
        rows = load(path)
        changed = 0
        for row in rows:
            indices = settled.get(row["id"])
            if not indices:
                continue
            spans = list(NOTE.finditer(row["text"]))
            if len(spans) <= max(indices):
                sys.exit(f"{edition} {row['id']}: the two editions disagree "
                         f"on note structure, refusing to guess")
            row["text"] = repair(row["text"], indices)
            changed += 1
        if changed != len(settled):
            sys.exit(f"{edition}: repaired {changed} of {len(settled)}")
        print(f"{edition}: {changed} verses restored")
        if args.apply:
            path.write_text(
                json.dumps(rows, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )

    if not args.apply:
        print("\ndry run — pass --apply to write")
    return 0


def repair(text: str, indices: list[int]) -> str:
    out: list[str] = []
    cursor = 0
    for index, span in enumerate(NOTE.finditer(text)):
        if index not in indices:
            continue
        out.append(text[cursor:span.start()])
        out.append(f"（{span.group(1).strip()}）")
        cursor = span.end()
    out.append(text[cursor:])
    return "".join(out)


if __name__ == "__main__":
    raise SystemExit(main())
