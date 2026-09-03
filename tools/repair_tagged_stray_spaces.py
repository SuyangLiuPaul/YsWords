#!/usr/bin/env python3
"""Take the import's own spaces out of the word-tap corpus, and leave the
publisher's.

`assets/tagged/cuvs-yhwh/` is rendered verbatim in place of the reader's verse
by `originals_sheet.dart`, and `TaggedTextService.coversVerse` compares
ideographs, so a space in this asset is invisible to every guard and prints as
scripture: 使徒行傳 9:5 shows 「主 说：」, 歷代志上 21:20 shows
「看见天使 ，就和他 四个儿子」, 列王紀上 15:19 shows 「说 ：」.

Measured 2026-09-03 — **621 spaces in all**, and they fall into three
populations, not two:

  * **429 are the edition's referent gloss** — the `主 [雅伟] 誇口` spacing
    that `TaggedTextService.reuniteGlossRuns` / `_tightenGloss` already close
    at load time, because the tagger walked `主[雅伟]` as ordinary prose and
    split the gloss across a run boundary. Never touched here. Closing them in
    the asset would silently retire the only corpus-wide input that pass has,
    and the queue entry filing this work says so explicitly.
  * **64 are carried by the FROZEN reading asset too.** This is the reason
    this tool has a witness gate rather than a rule. `assets/cuvs-yhwh.json`
    holds 1,273 spaces of its own; 1,189 of them are inside the edition's
    `<note: …>` syntax, but **84 are in running text**, and 64 of the tagged
    corpus's non-gloss spaces stand in a context the SAME verse of the reading
    asset also spaces: 撒迦利亞書 1:6 「他已照樣行了。’ ”」, 1:9
    「這是什麼意思？” 他說」, 哈該書 2:3 「看如無有嗎？’ ”」. Two independent
    transcription lines of one edition agreeing on a space is the strongest
    witness this repo has, and this is the class the corpus has been burned on
    before — a marker deleted three times as importer noise that turned out to
    be the publisher's own notation. **They stay.**
  * **128 are in the tagged corpus alone** and are deleted. 使徒行傳 9:5's
    「主 说：」, 撒母耳記上 3:5's 「你去睡吧。” 他就去睡了」, 歷代志上 1:22's
    「以巴录 、亚比玛利 、」 — the reading verse for each of those references
    has no space anywhere in its running text.

**The gate is per verse, not per corpus.** For a space with `prev` before it
and `next` after it, the tool asks whether the reading text of THAT SAME verse
(with `<note: …>` stripped, so the note syntax's own space cannot vouch for
anything) contains `prev + " " + next`. So `” 他` survives in 撒迦利亞書 1:9,
where the reading asset spaces it, and goes in 撒母耳記上 3:5, where it does
not. That is deliberate: the witness is the other transcription of the verse
in hand, exactly as `tools/repair_tagged_stray_brackets.py` gates per verse.

Deleting a space cannot change what the app believes about scripture:
`markup.scripture` already strips `\\s`, so `markup.distance` to the reader's
verse is unchanged by construction, and `coversVerse` never saw a space in the
first place. Both are asserted anyway, alongside the Chinese being conserved
character for character.

Run AFTER `tools/repair_tagged_ascii_punctuation.py`. That tool widens `,` to
`，` in 26 places that a space follows, and the character before a space is
this tool's witness — running them the other way round would test the reading
asset for `, 提` where it can only ever hold `， 提`. The tool refuses if it
finds an unwidened ASCII mark next to a space.

Idempotent: a second run finds only the 429 gloss spaces and the 64 witnessed
ones, and changes nothing.

Usage:
    python3 tools/repair_tagged_stray_spaces.py [--write]
"""

from __future__ import annotations

import argparse
import collections
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import repair_tagged_markup as markup  # noqa: E402

TAGGED = markup.TAGGED
CJK = re.compile(markup.CJK)
READING_NOTE = re.compile(r"<[^>]*>")

# Half-width marks `repair_tagged_ascii_punctuation.py` widens. One of these
# beside a space means that tool has not run and this one's witness lookup
# would be asking the reading asset a question it cannot answer.
UNWIDENED = set(",.!;:")


def chinese(text: str) -> str:
    return "".join(c for c in text if CJK.fullmatch(c))


def is_gloss_space(verse: str, i: int) -> bool:
    """The `主 [雅伟] 誇口` spacing, which `_tightenGloss` owns."""
    return (i + 1 < len(verse) and verse[i + 1] == "[") or (
        i > 0 and verse[i - 1] == "]"
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    reading = markup.reading_index()
    deleted: list[str] = []
    kept: list[str] = []
    gloss = 0
    refused: list[str] = []
    contexts: collections.Counter[str] = collections.Counter()

    for path in sorted(TAGGED.glob("*.json")):
        book = json.loads(path.read_text("utf-8"))
        verses = reading.get(path.stem, {})
        touched = False

        for ref, runs in book.items():
            before = [r.get("w", "") for r in runs]
            verse = "".join(before)
            if " " not in verse:
                continue
            where = f"{path.stem} {ref}"
            reading_text = verses.get(ref)
            if reading_text is None:
                refused.append(f"{where}: no reading verse to witness against")
                continue
            witness = READING_NOTE.sub("", reading_text)

            drop: set[int] = set()
            stop = False
            for i, ch in enumerate(verse):
                if ch != " ":
                    continue
                if is_gloss_space(verse, i):
                    gloss += 1
                    continue
                prev = verse[i - 1] if i else ""
                nxt = verse[i + 1] if i + 1 < len(verse) else ""
                if prev in UNWIDENED or nxt in UNWIDENED:
                    refused.append(
                        f"{where}: {prev!r} {nxt!r} — run "
                        "repair_tagged_ascii_punctuation.py first"
                    )
                    stop = True
                    break
                if f"{prev} {nxt}" in witness:
                    kept.append(f"{where}: {prev!r} ␣ {nxt!r}")
                    continue
                contexts[f"{prev} {nxt}"] += 1
                drop.add(i)
            if stop or not drop:
                continue

            after = []
            base = 0
            for run in before:
                after.append(
                    "".join(
                        c
                        for n, c in enumerate(run, start=base)
                        if n not in drop
                    )
                )
                base += len(run)
            joined_after = "".join(after)

            if chinese(verse) != chinese(joined_after):
                refused.append(f"{where}: the Chinese changed")
                continue
            if markup.distance(reading_text, joined_after) != markup.distance(
                reading_text, verse
            ):
                refused.append(f"{where}: the distance to the reader's verse moved")
                continue

            for run, text in zip(runs, after):
                run["w"] = text
            deleted.append(f"{where}: {verse}\n      -> {joined_after}")
            touched = True

        if touched and args.write:
            path.write_text(
                json.dumps(book, ensure_ascii=False, separators=(",", ":")), "utf-8"
            )

    print(f"deleted: {sum(contexts.values())} spaces in {len(deleted)} verses")
    for line in deleted:
        print(f"  -- {line}")
    print(f"\ncontexts deleted: {contexts.most_common()}")
    print(f"\nleft as the edition's gloss spacing: {gloss}")
    print(f"left because the reading verse spaces it too: {len(kept)}")
    for line in kept:
        print(f"  -- {line}")
    if refused:
        print(f"\nleft for a human: {len(refused)}")
        for line in refused:
            print(f"  -- {line}")
    if not args.write:
        print("\n(dry run — pass --write to apply)")
    return 1 if refused else 0


if __name__ == "__main__":
    raise SystemExit(main())
