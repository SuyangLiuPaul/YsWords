#!/usr/bin/env python3
"""Six word-tap runs answered with the wrong word of their own verse.

`assets/tagged/cuvs-yhwh/` is what "tap a word to see the original" prints.
Each run is `{"w": <Chinese>, "s": <the Strong's number the tap shows>}`, so a
run whose `s` names a different word of the verse from the one its Chinese
renders puts a false gloss on scripture — and it reads as scholarship, which
is the failure mode this repo cannot afford. 民數記 11:8 answered 百姓, "the
people", with H8081 שֶׁמֶן, *oil*.

`tools/audit_strongs_alignment.py` sized the class at 71 runs, of which 15 are
the "core": the number displayed really is somewhere in the verse, just on the
wrong Chinese chunk. This tool repairs six of the 15. Each is an off-by-one
against an ADJACENT token, where the number the run should carry is the one
whose lemma the Chinese chunk literally translates:

  民數記 11:8    百姓  H8081 -> H5971   שָׁטוּ הָעָם וְלָקְטוּ = H7751 H5971 H3950.
                                        百姓 is הָעָם. The verse's only שֶׁמֶן
                                        is its last word and 油。 already
                                        carries it correctly.
  耶利米書 47:4  一切  H853  -> H3605   לִשְׁדוֹד אֶת־כָּל־פְּלִשְׁתִּים =
                                        H7703 H853 H3605 H6430 over
                                        要毁灭 / 一切 / 非利士人. 一切 is כֹּל;
                                        אֵת is the object marker and this
                                        translation renders it with nothing.
  哥林多前書 1:14 神， G3754 -> G2316   εὐχαριστῶ τῷ θεῷ ὅτι …, 我感谢神.
                                        G3754 is ὅτι, the conjunction opening
                                        the NEXT clause.
  使徒行傳 12:24  神   G3588 -> G2316   ὁ λόγος τοῦ θεοῦ = 神的道. The run was
                                        carrying τοῦ, the noun's own article.
  使徒行傳 20:32  神   G3588 -> G2316   παρατίθεμαι ὑμᾶς τῷ θεῷ =
                                        我把你们交托神. Same shape.
  歷代志上 16:39 邱坛、 H4908 -> H1116   לִפְנֵי מִשְׁכַּן יְהוָה בַּבָּמָה
                                        אֲשֶׁר בְּגִבְעוֹן. 邱壇 is בָּמָה and
                                        帳幕 is מִשְׁכָּן — both Chinese words
                                        are in this verse and the two numbers
                                        sat on the wrong ones.

**The argument that first justified this list was worthless and is recorded so
nobody rebuilds it.** The draft leant on frequency: each of these (run text,
number) pairs occurs EXACTLY ONCE in the corpus while the proposed number
carries the same run text hundreds of times, so a singleton looked like a slip.
Run the test yourself — that property is shared by **371 runs**, and
約伯記 3:2 is one of them and is right: its single run 说： is tagged H6030
עָנָה, *answered*, with H559 in `i`, because the Hebrew is
וַיַּעַן אִיּוֹב וַיֹּאמַר and this translation collapses the pair into one
verb. Rarity detects rare readings, not wrong ones. Every entry above stands on
its own verse or not at all; the frequency is corroboration and nothing more.

**Nine of the 15 are deliberately NOT repaired.** Four were already known to be
defensible (出 16:23, 何 12:8, 士 9:48's 所/我所 for כֹּל/מָה, and 民 33:39's 歲
for the בֶּן … שָׁנָה age idiom). 撒上 13:6 is a plain false positive: 百姓 is
H376 because the Hebrew opens וְאִישׁ יִשְׂרָאֵל and H376 is the verse's first
word. The remaining four are open questions with two positions on record and
are listed in `docs/autonomous-queue.md` — 代下 4:3, 腓立比書 1:29,
約翰一書 5:3 and 耶利米書 33:1. Do not sweep them.

**Only `s` moves. `i` is not touched.** `TaggedRun.implied` is documented as
"numbers the original has that this text does not render", so appending the
displaced number would be writing a fresh claim into a field this repair has no
evidence about. The diff is one number per run.

歷代志上 16:39 is a half repair on purpose. The neighbouring run 的帐幕前 still
answers H6440 פָּנִים when it also spans מִשְׁכָּן, so H4908 is now no run's
`s` in that verse. That is a coverage gap, not a falsehood, and the run occurs
once in the whole corpus so the audit's ground truth cannot judge it. Filed.

Usage:
    python3 tools/repair_strongs_alignment_core.py [--write]
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TAGGED = ROOT / "assets" / "tagged" / "cuvs-yhwh"
ORIGINALS = ROOT / "assets" / "originals"
VERSIFICATION = ROOT / "assets" / "originals_versification.json"
MERGED = ROOT / "assets" / "originals_versification_merged.json"

# book, ref, the run's `w` exactly as stored, the number now shown, the number
# the Chinese actually renders.
REPAIRS = [
    ("numbers", "11:8", "百姓", "H8081", "H5971"),
    ("jeremiah", "47:4", "一切", "H853", "H3605"),
    ("1_corinthians", "1:14", "神，", "G3754", "G2316"),
    ("acts", "12:24", "神", "G3588", "G2316"),
    ("acts", "20:32", "神", "G3588", "G2316"),
    ("1_chronicles", "16:39", "邱坛、", "H4908", "H1116"),
]


def load(path: pathlib.Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def original_numbers(book: str, ref: str, base: dict, merged: dict) -> set[str]:
    path = ORIGINALS / f"{book}.json"
    if not path.exists():
        return set()
    originals = load(path)
    refs = merged.get(book, {}).get(ref) or base.get(book, {}).get(ref) or [ref]
    present: set[str] = set()
    for original_ref in refs:
        present.update(w.get("s", "") for w in originals.get(original_ref, []))
    return present


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    base = load(VERSIFICATION)
    merged = load(MERGED).get("cuvs-yhwh", {})

    changed: dict[str, dict] = {}
    applied = already = 0
    failures: list[str] = []

    for book, ref, text, old, new in REPAIRS:
        path = TAGGED / f"{book}.json"
        tagged = changed.get(book) or load(path)
        changed[book] = tagged
        runs = tagged.get(ref)
        if runs is None:
            failures.append(f"{book} {ref}: verse not in the tagged corpus")
            continue

        # The number must be one the verse's own original actually has, or the
        # repair would be inventing a claim rather than moving one.
        present = original_numbers(book, ref, base, merged)
        if new not in present:
            failures.append(
                f"{book} {ref}: {new} is not in the verse's original; refusing")
            continue

        matches = [r for r in runs if r.get("w") == text and r.get("s") == old]
        settled = [r for r in runs if r.get("w") == text and r.get("s") == new]
        if not matches and settled:
            already += 1
            continue
        if len(matches) != 1:
            failures.append(
                f"{book} {ref}: expected exactly one run {text!r} tagged {old}, "
                f"found {len(matches)}")
            continue
        matches[0]["s"] = new
        applied += 1
        print(f"  {book:15} {ref:8} {text!r:8} {old} -> {new}")

    if failures:
        for line in failures:
            print(f"REFUSED {line}", file=sys.stderr)
        return 1

    print(f"\n{applied} repaired, {already} already correct "
          f"of {len(REPAIRS)}")
    if not args.write:
        print("dry run — pass --write to apply")
        return 0
    if applied:
        for book, tagged in changed.items():
            path = TAGGED / f"{book}.json"
            with path.open("w", encoding="utf-8") as fh:
                json.dump(tagged, fh, ensure_ascii=False, separators=(",", ":"))
        print(f"wrote {len(changed)} book files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
