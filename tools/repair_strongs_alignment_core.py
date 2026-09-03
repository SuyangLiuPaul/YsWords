#!/usr/bin/env python3
"""Eight word-tap runs answered with the wrong word — six of their own verse.

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

**The seventh, added 2026-09-03, breaks the "its own verse" shape above and the
title now says so.** 民數記 23:11's first run 巴勒 (Balak) answered H319
אַחֲרִית, "latter end", a word that is nowhere in 23:11. It is the last word of
23:**10** — וּתְהִי אַחֲרִיתִי כָּמֹהוּ — and that verse's last run,
我愿如义人之终而终。, carries H319 correctly. So the importer let the previous
verse's final number fall through into the next verse's opening run, and the
evidence is two adjacent runs in the file rather than an argument.

  民數記 23:11   巴勒  H319  -> H1111   וַיֹּאמֶר בָּלָק אֶל־בִּלְעָם. 巴勒 is
                                        בָּלָק, tagged H1111 in 32 of its 33
                                        corpus occurrences, and H1111 was no
                                        run's `s` in the verse. H319 is not in
                                        23:11 at all, so nothing is displaced:
                                        it stays reachable in 23:10, where it
                                        is genuinely the word.

**The eighth, 2026-09-03, is the first row here the audit CANNOT see**, and it
arrived from another agent's pass over word-less runs rather than from
`audit_strongs_alignment.py`. 耶利米書 38:16's 寻索 ("to seek out") answered
H834 אֲשֶׁר, *which*. The Hebrew is אֲשֶׁר מְבַקְשִׁים אֶת־נַפְשֶׁךָ and
מְבַקְשִׁים is H1245 בָּקַשׁ, immediately after the אֲשֶׁר.

  耶利米書 38:16 寻索  H834  -> H1245   寻索 is H1245 in 16 of its 17 Hebrew
                                        occurrences, this verse being the lone
                                        exception, and its one Greek occurrence
                                        (羅 11:3) is G2212 ζητέω, the same
                                        sense. H834 is not displaced: the verse
                                        has two אֲשֶׁר tokens and the run
                                        我指着那 still shows it.

Why the audit is blind to it, stated because the floor is easy to forget: 寻索
occurs 17 times in Hebrew, below the >= 20 bar, so no dominant number is
admitted for it and no hit can be raised. This repair therefore moves NONE of
the pinned figures — the census stays 22, `dominant` stays 256, the singleton
pool stays 335. A repair that changes no counter is exactly what the floor
looks like from the inside.

It also does not invent a claim: the importer had already aligned בָּקַשׁ to
this verse and parked H1245 on a run with no text, which is why the number was
"present" and yet unreachable. **That is a second way a number can be
untappable, and it is the `i` mistake one level further in**: this audit's
`shown` set counts a run's `s` whether or not the run has any characters to
tap. Measured 2026-09-03 — 312 runs corpus-wide have no CJK text, 36 of them
carry a number, and in **24 verses** a number present in the original was some
run's `s` ONLY on such a run. So the census of 22 is a floor by that much too.
This repair closed one of the 24 — H1245 had been reachable in 耶 38:16 only on
its word-less run, and moving it onto 寻索 made it tappable — so the figure is
**23** afterwards, which is what `test/strongs_alignment_test.dart` pins.
Neither 耶 38:16 nor the other verse handed over with it would become a hit
even if the blind spot were closed, because both run texts are below the >= 20
bar; the remaining 23 have not otherwise been triaged. The word-less runs
themselves are another pass's subject and are deliberately untouched here —
only the `s` of a run that HAS text is changed.

**以西結書 35:14 came over with it and is deliberately NOT repaired.** There
H3541 כֹּה sits on a word-less run while 如此说： answers H559 אָמַר, and it is
tempting to call that the same defect. It is not: 说 does render אָמַר, so the
number shown is partial rather than false — the gate that holds eleven runs in
`repair_strongs_spans.py`. And there is nothing to promote it to on evidence:
如此说 occurs four times in the whole corpus, split 2 H1696 דָּבַר / 2 H559
אָמַר, and is tagged H3541 nowhere. Writing H3541 there would be inventing a
tagging the corpus has never made.

That carry-over was checked for corpus-wide rather than assumed unique. Exactly
three verses have a first run repeating the previous verse's last number where
that number is absent from the verse's own original, and **the other two are
not defects**: 使徒行傳 26:4's 我 shows G3450 μοῦ and 路加福音 10:36's 你 shows
G4671 σοί, which are the tagger's inflected-form numbers for the originals'
G1473 ἐγώ and G4771 σύ — the lemma-vs-inflected convention that
`audit_strongs_tagging.py` factors out on purpose and that "fixing" would make
the app less accurate. 民 23:11 is the only one where the displaced number is a
content noun the Chinese plainly does not mean. One instance, not a sweep.

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

歷代志上 16:39 is a half repair on purpose, and 2026-09-03 re-examined it and
left it half. The neighbouring run 的帐幕前 still answers H6440 פָּנִים when it
also spans מִשְׁכָּן, so H4908 is now no run's `s` in that verse. That is a
coverage gap, not a falsehood. The two honest options were to split the run into
的帐幕 / 前 or to leave it, and leaving it won on four measurements:

  * 的帐幕前 occurs ONCE in the corpus, far below the >= 20 bar, so the audit's
    ground truth has no opinion — as already recorded.
  * **Neither half of the proposed split has ground truth either**, which is
    the part that had not been checked. 的帐幕 occurs 25 times and is H168
    אֹהֶל 10 times against H4908 9 — genuinely ambiguous, not dominant. 前
    occurs 199 times and is H6440 in 101, 51%. Both are far below the 95% bar,
    so a split would be guessing twice rather than once.
  * 前 spells לִפְנֵי and 帐幕 spells מִשְׁכָּן, so the run spells BOTH words
    and the current `s` is partial rather than false — the same gate that holds
    eleven runs in `repair_strongs_spans.py`.
  * Splitting a run would change `w`, the Chinese as printed. Every repair in
    this area so far has moved only `s` and `i` and touched no character. This
    verse — where the audit is blind and both halves are ambiguous — is the
    worst possible place to set that precedent.

The gap is also not distinctive: 代上 16:39 has FIVE numbers present in its
original and reachable by no tap (H3605, H4908, H5921, H6680, H853), and
corpus-wide 14,439 (verse, number) pairs are unreachable without even sitting
in some run's `i`. Closing one of them by inventing a split is not a repair.

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
    ("numbers", "23:11", "巴勒", "H319", "H1111"),
    ("jeremiah", "38:16", "寻索", "H834", "H1245"),
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
