#!/usr/bin/env python3
"""Four verses where the word-tap sheet printed a word this edition does not.

`lib/widgets/originals_sheet.dart` renders `assets/tagged/cuvs-yhwh/` VERBATIM
IN PLACE OF the reader's verse whenever `coversVerse` passes, and `coversVerse`
is a subsequence test — it asks whether the reader's ideographs survive in the
tagged line and is blind to a tagged line that has GAINED one. All four of
these pass it, so all four were on screen with no correct copy behind them:

    士師記 15:2   …還美麗嗎？**我請求**你可以娶來代替她吧！
    士師記 15:5   …並**葡萄園**橄欖園盡都燒了。
    士師記 15:18  …施行這麼大的拯救，**現在**豈可任我渴死…
    撒母耳記下 21:2 …卻為以色列人和猶大人**大**發熱心…

**FOUR witness lines read the short form, and they are not one line counted
four times.** `assets/cuvs-yhwh.json` and `assets/cuvs-yhwh-tr.json` (this
edition, in both scripts, hash-pinned by `test/cuvs_yhwh_frozen_test.dart`);
blob `7a2dc43`, the plain 和合本 Traditional, a separate digital line that sets
那裏/甚麼 where this edition sets 那里/什么; and the printed 1919, read for
these four references by `audit_tagged_rendered_extras.py` when it first filed
them. That is the same 4-against-1 margin the fifteen dropped-character
restorations required, pointing the other way.

**WHY THIS WAS HELD, AND WHY THAT REASON DOES NOT HOLD.** The queue entry
declined to delete them because three of the four render something the Hebrew
really has — 我請求 = H4994 נָא, 葡萄園 = H3754 כֶּרֶם, 現在 = H6258 עַתָּה —
and "removing them from the app's account of the Hebrew is not defensible".

The app's account of the Hebrew is not in this file. `originals_sheet.dart`
builds the word-chip row under the verse from `OriginalsService.forVerse`,
which reads `assets/originals/`, a different asset with a different provenance,
and every one of these words is already there with its own chip, gloss and
lexicon entry:

    assets/originals/judges.json    15:2  … תְּהִי/H1961 נָ֥א/H4994 תַּחְתֶּֽיהָ/H8478
    assets/originals/judges.json    15:5  … וְעַד/H5704 כֶּ֥רֶם/H3754 זָֽיִת/H2132
    assets/originals/judges.json    15:18 … הַזֹּ֑את/H2063 וְעַתָּה֙/H6258 אָמ֣וּת/H4191
    assets/originals/2_samuel.json  21:2  … לְהַכֹּתָ֔ם/H5221 בְּקַנֹּאת֥וֹ/H7065

So the choice was never "print the edition or keep the Hebrew". It is "print
the edition on the line that claims to BE the edition, and keep the Hebrew
where the Hebrew already is". Nothing below removes a Strong's number from the
sheet.

Two of the four are not even readings of a word the edition failed to render:

  * 士 15:2 renders נָא, with 吧 at the end of the clause. 我請求 is a SECOND
    rendering of the same particle, an interlinear gloss that leaked into the
    running text.
  * 撒下 21:2's 大 has no Hebrew word behind it at all — בְּקַנֹּאתוֹ is one
    word and 發熱心 already renders it. The queue called this the weakest of
    the four and it is.

The other two are real translation decisions the tagger made and this edition
did not: 士 15:5 reads כֶּרֶם זַיִת as two coordinated nouns (as 和合本2010 and
the LXX do) where this edition reads the construct chain and sets 橄欖園; 士
15:18 renders עַתָּה where this edition leaves it unrendered. Both are
defensible Chinese. Neither is THIS edition's Chinese, and the sheet is not the
place to publish a variant translation over the top of the reader's own.

**WHAT HAPPENS TO THE NUMBER ON A DELETED RUN.** 士 15:2 and 撒下 21:2 trim
characters from inside a run that keeps its word and its number, so nothing
moves. 士 15:5's 葡萄園 and 士 15:18's 現在 are whole runs; deleting the text
alone would leave a run with a number and no word — a zero-width tap target,
the fault `_taggedVerseLine` and `tagged_stray_brackets_test.dart` exist to
keep at 12. So each number is folded into the FOLLOWING run's `i`, the corpus's
better-attested convention for a word this translation does not render (1,455
runs carry one that way, 11 the other) and the one the 列王紀上 19:18 repair
chose for the same reason.

After this, all four verses read ideograph-for-ideograph as the reader's verse,
so they leave the `audit_tagged_rendered_extras.py` long-census entirely.

Idempotent; refuses on drift rather than guessing.
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TAGGED = REPO / "assets/tagged/cuvs-yhwh"

# (book file, verse key, run index, text before, text after) — the run keeps
# its word and its Strong's number.
TRIM = [
    ("judges", "15:2", 11, "吗？我请求你", "吗？你"),
    ("2_samuel", "21:2", 14, "大发热心，", "发热心，"),
]

# (book file, verse key, run index to delete, its Strong's, the word it held)
# The number is folded into the following run's `i`.
DROP = [
    ("judges", "15:5", 9, "H3754", "葡萄园"),
    ("judges", "15:18", 12, "H6258", "现在"),
]


def ideographs(text):
    return "".join(c for c in text if 0x3400 <= ord(c) <= 0x9FFF)


def main():
    changed = {}
    edits = 0

    def book_of(slug):
        if slug not in changed:
            changed[slug] = json.loads(
                (TAGGED / f"{slug}.json").read_text(encoding="utf-8"))
        return changed[slug]

    for slug, key, index, before, after in TRIM:
        runs = book_of(slug)[key]
        if index >= len(runs):
            print(f"REFUSING: {slug} {key} has {len(runs)} runs")
            return 1
        run = runs[index]
        if run["w"] == after:
            continue
        if run["w"] != before:
            print(f"REFUSING: {slug} {key} run {index} reads {run['w']!r}, "
                  f"expected {before!r} or {after!r}")
            return 1
        run["w"] = after
        edits += 1

    for slug, key, index, number, word in DROP:
        runs = book_of(slug)[key]
        if index >= len(runs) or runs[index]["w"] != word:
            # Already applied: the fold must be visible on the run that is now
            # at this index, or the file has drifted.
            following = runs[index] if index < len(runs) else None
            if following is not None and number in following.get("i", []):
                continue
            print(f"REFUSING: {slug} {key} run {index} does not hold "
                  f"{word!r} and the fold of {number} is not there either")
            return 1
        if runs[index]["s"] != number:
            print(f"REFUSING: {slug} {key} run {index} carries "
                  f"{runs[index]['s']!r}, expected {number!r}")
            return 1
        if index + 1 >= len(runs):
            print(f"REFUSING: {slug} {key} run {index} has no following run "
                  f"to hold {number}")
            return 1
        following = runs[index + 1]
        implied = list(following.get("i", []))
        if number not in implied:
            implied.append(number)
        following["i"] = implied
        del runs[index]
        edits += 1

    if not edits:
        print("nothing to do")
        return 0

    for slug, book in changed.items():
        (TAGGED / f"{slug}.json").write_text(
            json.dumps(book, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )
    print(f"{edits} runs repaired across {len(changed)} books")
    return 0


if __name__ == "__main__":
    sys.exit(main())
