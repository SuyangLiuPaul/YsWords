#!/usr/bin/env python3
"""Seven verses printed a character of scripture twice on the word-tap sheet.

`assets/tagged/cuvs-yhwh/` is a second import of the same translation, and
`originals_sheet.dart` renders it **verbatim in place of** the reader's verse
whenever `coversVerse` passes. `coversVerse` only checks that the reader's
ideographs survive as a subsequence, so a tagged line that has GAINED a
character passes it and is printed. 馬太福音 9:28 has been showing
「耶穌說說：」 over a verse that reads 「耶穌說：」.

WHY THESE SEVEN AND NOT THE OTHER 17 that read long
(`audit_tagged_rendered_extras.py` has the full triage): deleting is only the
safe direction when the added text is IMPOSSIBLE. A doubled character is —
「若若」, 「箭箭」, 「我們我們」 are not Chinese, our reading text does not have
them, and the printed 1919 Wikisource text does not have them. The four verses
where the tagged import supplies a whole WORD are readings, not damage, and are
left alone: 士師記 15:5's 葡萄園 renders כֶּרֶם, which that verse's Hebrew
really has.

WHICH COPY IS DROPPED. Five of the seven double inside a single run, so the
run keeps its Strong's number and only loses the repeat. Two straddle a run
boundary and were decided by counting the corpus, not by picking the nearer
one:

  以西結書 36:1  ...{"w":"啊！你要","s":"H859"},{"w":"要对","s":"H413"}...
      A run reading exactly 「要对」 tagged H413 occurs 7 times in the corpus,
      and at 以西結書 33:10 and 33:12 — the same 「人子啊！你要对…发预言」
      construction — the pair is 「啊！你」/H859 + 「要对」/H413. A run reading
      exactly 「啊！你」 tagged H859 occurs 35 times. So the second run is the
      corpus's shape and the repeat belongs to the first.

  馬太福音 9:28  ...{"w":"说","s":"G3004","i":["G846"]},{"w":"说：“","s":"G3004"}...
      Both runs carry G3004 (λέγω), so this is one word split in two rather
      than two words. They are MERGED rather than one deleted, because the
      first carries i:["G846"] — αὐτοῖς, "to them", which the verse really has
      (καὶ λέγει αὐτοῖς ὁ Ἰησοῦς) and which deleting that run would throw away.

列王紀上 19:18 is the one deletion of a whole run. It reads
...{"w":"未","s":"H834"},{"w":"未曾","s":"H3808"}... where the first clause of
the same verse reads {"w":"是","s":"H834"},{"w":"未曾","s":"H3808"}: H834 is
אֲשֶׁר, and this translation renders the first one 是 and the second one not at
all. The print reads 「未曾與巴力親嘴的」 — no 是 and no doubled 未. So the run
has no word to hold, and its number is folded into the following run's `i`.
That is the better-attested of the corpus's TWO conventions for a word the
translation does not render, not the only one: 1,455 runs carry H834 in `i`,
while 11 keep a number on a run with an empty `w`. The `i` form was chosen
because emptying the run would have made a 13th zero-width tap target — a
lexicon entry opening for a word that is not on the line (see
`tagged_stray_brackets_test.dart`, which pins that count at 12).

Idempotent: a second run finds nothing to do and exits 0.
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TAGGED = REPO / "assets/tagged/cuvs-yhwh"

# (book file, verse key, run index, text before, text after)
TRIM = [
    ("leviticus", "5:7", 1, "若若", "若"),
    ("1_samuel", "20:37", 11, "箭箭", "箭"),
    ("2_kings", "10:5", 9, "我们是你的仆人，", "是你的仆人，"),
    ("job", "31:36", 0, "愿那敌我敌", "愿那敌我"),
    ("ezekiel", "36:1", 2, "啊！你要", "啊！你"),
]

# (book file, verse key, index of the run to drop, index that absorbs it)
MERGE = [
    # 馬太福音 9:28 — same Strong's, one word split in two. The survivor keeps
    # the punctuation of the second and the i:["G846"] of the first.
    ("matthew", "9:28", 8, 7, "说：“"),
]

# (book file, verse key, index of the run to delete, Strong's to fold into the
#  following run's `i`)
DROP = [
    ("1_kings", "19:18", 10, "H834"),
]


def main():
    changed = {}

    def book_of(slug):
        if slug not in changed:
            path = TAGGED / f"{slug}.json"
            changed[slug] = json.loads(path.read_text(encoding="utf-8"))
        return changed[slug]

    edits = 0

    for slug, key, index, before, after in TRIM:
        runs = book_of(slug)[key]
        run = runs[index]
        if run["w"] == after:
            continue
        assert run["w"] == before, (slug, key, index, run["w"])
        run["w"] = after
        edits += 1

    for slug, key, drop, keep, text in MERGE:
        runs = book_of(slug)[key]
        if len(runs) <= drop or runs[keep]["w"] == text:
            continue
        survivor = runs[keep]
        assert runs[drop]["s"] == survivor["s"], (slug, key)
        survivor["w"] = text
        del runs[drop]
        edits += 1

    for slug, key, index, number in DROP:
        runs = book_of(slug)[key]
        if runs[index]["s"] != number or runs[index]["w"] not in ("未",):
            continue
        following = runs[index + 1]
        implied = following.get("i", [])
        if number not in implied:
            implied = implied + [number]
        following["i"] = implied
        del runs[index]
        edits += 1

    if not edits:
        print("nothing to do")
        return 0

    for slug, book in changed.items():
        path = TAGGED / f"{slug}.json"
        path.write_text(
            json.dumps(book, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )
    print(f"{edits} runs repaired across {len(changed)} books")
    return 0


if __name__ == "__main__":
    sys.exit(main())
