#!/usr/bin/env python3
"""39 word-tap runs answered a content word with a particle it does not spell.

`assets/tagged/cuvs-yhwh/` is what "tap a word to see the original" prints.
Each run is `{"w": <Chinese>, "s": <the number the tap shows>, "i": [...]}`,
where `i` is documented in `lib/services/tagged_text_service.dart` as "numbers
the original has that this text does not render" — the Hebrew object marker
אֵת, the Greek article. `TaggedRun.implied` is parsed and carried, but **no
WIDGET reads it**, so on screen it is inert: a number reachable by no tap.

約翰福音 3:5's 神 is `{"w":"神","s":"G3588","i":["G2316"]}`. The sheet answers
神 with ὁ, *the*, and θεός is no run's `s` anywhere in that verse, so a reader
cannot reach it at all. 錫安 answers מִן *from*; 櫃 answers עַל *upon*;
弟兄們 answers ἀνήρ. 馬太福音 6:8's 父 answers G2316 θεός, which that verse's
Greek — ὁ πατὴρ ὑμῶν — does not contain at all.

**The repair promotes; it demotes only where that is true.** `s` takes the
number the Chinese renders, and the displaced particle moves into `i` **when
the verse's original actually has it**: after 的子孙 becomes
`{"s":"H1121","i":["H4480"]}` the data says "this renders בֵּן; מִן is in the
original and this does not render it", true of 1 Chr 24:3's וּמִן־בְּנֵי. In
four runs it is not true — 賽 17:3's 以法蓮 and 大馬色, 賽 2:3's 錫安 and
馬太福音 6:8's 父 show a number their own verse does not contain — so writing
it into `i` would trade one false claim for another, and there the number is
dropped. `i` is inert on screen, so a dropped number costs coverage, not
truth; the corpus already carries gaps of that kind.

**What the pass COSTS, stated precisely, because "demote the particle" flatters
it.** `i` is inert, so a number that is no run's `s` anywhere in the verse is a
number no tap can reach. The pass touches 39 runs in 36 verses and leaves the
displaced number unreachable in **30 of those verses (33 of the 39 runs)**; in
the other 6 it survives on a sibling run — 民數記 7:89's 的施恩座以上 still
shows H5921, 腓立比書 3:3's 真受割禮的 still shows G3588. (Three counts are in
play and mixing them is easy: 30 is (verse, number) losses, and 歷代志上 24:3,
以賽亞書 17:3 and 約翰福音 3:5 each spend two runs on one of them.)

Of the 30, **18 are particles** (G3588 x6, H4480 x4, H853 x3, H3605 x3, H5921,
H1931), **11 are content words** the Chinese genuinely leaves unrendered — ἀνήρ
of ἄνδρες ἀδελφοί (x2), פֶּה of עַל־פִּי (申 17:11), מִסְפָּר of מִסְפַּר יְמֵי
(傳 6:12), עֵת of עֵת הָעֶרֶב (x2), מִשְׁפָּחָה (書 21:26), שָׁלֹשׁ of
שָׁלֹשׁ וְעֶשְׂרִים (耶 52:30) and בֵּן of בְּנֵי־יִשְׂרָאֵל (x3) — and **1 is
not a loss at all**: 太 6:8's G2316 is removed because that verse's Greek, ὁ
πατὴρ ὑμῶν, does not contain θεός, so the tap was answering with a word that
is not there. Calling that one a particle, as a draft of this paragraph did,
made θεός the least particle-like member of a list of particles.

The trade is still right — a tap on 弟兄們 must answer ἀδελφοί and not ἀνήρ —
but it is a trade, not a free repair. **約翰福音 3:5 is the clearest case and a
draft of this file got its direction backwards**: pre-repair BOTH 神 and 的国。
showed G3588, so ὁ was reachable twice over while θεός and βασιλεία were
reachable nowhere; after, each Chinese chunk answers the word it renders and
the article answers nothing. That is the trade this pass makes 30 times, and
it is worth making, but "the reader only gains" was false.
`unreachable_after` in `test/strongs_alignment_test.dart` recomputes all three
figures, so this paragraph cannot drift from the data the way a sentence can.

**The gate is whether the run SPELLS the word it is showing, and adding that
gate cut the pass from 53 runs to 39.** The audit's `spans-the-word` class is
defined structurally — the dominant number for this run text sits in this run's
own `i` — and a structural definition is not enough, because where the Chinese
spells BOTH words the current `s` is partial, not false, and swapping trades
one partial answer for another while writing "this text does not render it"
about a character that plainly does. 王下 3:27's 的長子 spells בֵּן in 子 and
בְּכוֹר in 長; 創 33:17's 名叫 spells שֵׁם in 名 and קָרָא in 叫, and its `g`
code H8804 is that verb's Qal perfect, which the promotion would leave parsing a noun.
Fourteen runs are held for reasons of that kind and are listed in `HELD` below
with the reason on each; the tool refuses to run if a member of the class is in
neither table, so the exclusions cannot quietly grow or shrink. 39 + 14 = 53.

The gate is a judgement per run, not a rule, so it is worth naming where the
two passes over this class disagreed. 耶利米書 52:30's 二十 was held first as
"the numeral convention" and is repaired here, because the verse's own four
sibling numerals show there is no such convention. 以斯拉記 7:11's 誡命 and the
two 和 rows went the other way: 誡 carries H1697 elsewhere in the corpus and
bare 和 carries H5921 in 61 runs, so those runs do spell what they show.

**Ground truth is the corpus's own tagging of the identical Chinese string, not
a rarity argument.** `tools/repair_strongs_alignment_core.py` records why that
distinction matters: its first draft justified six repairs by "this pair occurs
exactly once", and 367 runs have that property with 約伯記 3:2 among them and
correct. Here a row is admitted only when the same run text occurs >= 20 times
with the proposed number covering >= 95% of them — 的子孙 is H1121 in 294 of
297, 以色列 is H3478 in 1303 of 1312, 父 is G3962 in 211 of 215 — **and** that
number already sits in this very run's `i`, so the importer had aligned the word
to this chunk and merely made it secondary. Neither line is
frequency-of-the-wrong-pair. Both are recomputed here at run time, so a stale
row refuses rather than applying on evidence that has moved.

**`REPAIRS` and `HELD` are hand-written lists and the held verses are excluded
by hand.** An earlier draft of this docstring claimed the nine recorded
disagreements of the core repair were excluded "by a property of the data"; that
is false. 約翰一書 5:3's 他 run is `{"s":"G3588","i":["G2316"]}` — a structural
member of this very class — and it stays out only because that verse is held and
because 他's own dominant number is G846. 民數記 32:11's 歲 and 利未記 15:24's 所
are likewise held here, as the twins of 民數記 33:39 and 出埃及記 16:23: repairing
either would settle a held question by side effect.

**This does not clear the defect, only the part the corpus can see.** A run
text has to occur >= 20 times before the detector has an opinion about it, so
identical faults in rarer strings stay invisible: 使徒行傳 2:29's 明明的,
民數記 7:89's 的施恩座以上 and 撒迦利亞書 14:7's 日， are the same defect and are
not in this pass. That floor is the audit's known property, not a new one.

`tools/audit_strongs_alignment.py` enumerates the class;
`test/strongs_alignment_test.dart` pins the census and the held verses.

Usage:
    python3 tools/repair_strongs_spans.py [--write]
"""

from __future__ import annotations

import argparse
import collections
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TAGGED = ROOT / "assets" / "tagged" / "cuvs-yhwh"
ORIGINALS = ROOT / "assets" / "originals"
VERSIFICATION = ROOT / "assets" / "originals_versification.json"
MERGED = ROOT / "assets" / "originals_versification_merged.json"

NOT_CJK = re.compile(r"[^一-鿿]")
SUPPLIED = "H0"
MIN_OCCURRENCES = 20
MIN_DOMINANCE = 0.95

# book, ref, the run's `w` exactly as stored, the number now shown, the number
# the Chinese renders — which is already in that run's own `i`.
#
# The Greek article. CUV never renders it as a Chinese word, so a run showing
# it is answering a content word with "the".
REPAIRS = [
    ("ephesians", "2:15", "律法", "G3588", "G3551"),
    ("ephesians", "2:18", "父", "G3588", "G3962"),
    ("john", "1:32", "圣灵，", "G3588", "G4151"),
    ("john", "3:5", "的国。", "G3588", "G932"),
    ("john", "3:5", "神", "G3588", "G2316"),
    ("luke", "11:2", "名", "G3588", "G3686"),
    ("luke", "11:39", "法利赛人", "G3588", "G5330"),
    ("mark", "15:10", "祭司长", "G3588", "G749"),
    ("matthew", "22:37", "神。", "G3588", "G2316"),
    ("philippians", "3:3", "的灵", "G3588", "G4151"),

    # H853 אֵת, the object marker, which this translation renders with nothing
    # — the same reasoning that settled 耶利米書 47:4 in the core repair.
    ("deuteronomy", "31:2", "约但河。’", "H853", "H3383"),
    ("deuteronomy", "5:3", "约", "H853", "H1285"),
    ("genesis", "19:15", "女儿", "H853", "H1323"),

    # H4480 מִן in a construct chain. 的子孙 is "the sons of"; the "from" is
    # carried by the sentence, not by any character of the run. At the three
    # 以賽亞書 verses H4480 is not a TOKEN of the original as our
    # `assets/originals` tags it — מִצִּיּוֹן, מֵאֶפְרַיִם and מִדַּמֶּשֶׂק fuse
    # the preposition as a prefix and are tagged H6726 / H669 / H1834 with no
    # separate H4480. Saying "H4480 is not in the Hebrew" would be false, and
    # one draft of this comment said exactly that; what is true is that no
    # H4480 exists for `i` to point AT. In 賽 2:3 the "from" is rendered
    # anyway, by 必出于 (H3318) in the preceding run.
    ("1_chronicles", "24:3", "的子孙", "H4480", "H1121"),
    ("1_chronicles", "27:3", "的子孙，", "H4480", "H1121"),
    ("isaiah", "17:3", "以法莲", "H4480", "H669"),
    ("isaiah", "17:3", "大马色", "H4480", "H1834"),
    ("isaiah", "2:3", "锡安；", "H4480", "H6726"),

    # H5921 עַל, which no character of these three runs spells. An earlier
    # draft said the preposition "is rendered by a different run" in every
    # verse of this group; that is false in the two 和 rows, which is why they
    # are HELD — bare 和 carries H5921 in 61 runs corpus-wide.
    ("1_kings", "1:35", "以色列", "H5921", "H3478"),
    ("deuteronomy", "33:8", "水", "H5921", "H4325"),
    ("numbers", "7:89", "柜", "H5921", "H727"),

    # H3605 כֹּל, where the Chinese leaves it unrendered (כָּל־יְמֵי = 日子)
    # or renders it in another run (都, 全地).
    ("1_kings", "15:6", "日子", "H3605", "H3117"),
    ("2_chronicles", "11:13", "祭司", "H3605", "H3548"),
    ("deuteronomy", "12:1", "的日子，", "H3605", "H3117"),
    ("genesis", "10:21", "子孙", "H3605", "H1121"),

    # H1121 בֵּן as the first member of בְּנֵי יִשְׂרָאֵל / בְּנֵי עַמּוֹן,
    # which CUV contracts to the bare nation name.
    ("exodus", "4:29", "以色列", "H1121", "H3478"),
    ("jeremiah", "27:3", "亚扪", "H1121", "H5983"),
    ("numbers", "8:9", "以色列", "H1121", "H3478"),

    # H4940 מִשְׁפָּחָה, unrendered in לְמִשְׁפְּחוֹת בְּנֵי־קְהָת = 哥辖…子孙.
    ("joshua", "21:26", "子孙", "H4940", "H1121"),

    # G2316 θεός is not in this verse's Greek at all — ὁ πατὴρ ὑμῶν — so the
    # sheet answered 父 with a word the verse does not contain.
    ("matthew", "6:8", "父", "G2316", "G3962"),

    # A construct-chain head the Chinese drops entirely: מִסְפַּר יְמֵי,
    # עַל־פִּי הַתּוֹרָה, עֵת הָעֶרֶב, הַיּוֹם הַהוּא, ἄνδρες ἀδελφοί.
    # No character of the run spells the number it showed.
    ("acts", "2:29", "“弟兄们！", "G435", "G80"),
    ("acts", "2:37", "弟兄们，", "G435", "G80"),
    ("deuteronomy", "17:11", "你的律法，", "H6310", "H8451"),
    ("ecclesiastes", "6:12", "日子，", "H4557", "H3117"),
    ("ezekiel", "38:14", "之日，", "H1931", "H3117"),
    ("joshua", "8:29", "晚上。", "H6256", "H6153"),
    ("zechariah", "14:7", "晚上", "H6256", "H6153"),

    # שָׁלֹשׁ וְעֶשְׂרִים = 二十三. Held in a first pass as "the numeral
    # convention puts the compound's first Hebrew token in `s`", but there is
    # no such convention: this verse's four sibling numerals (七百 H7651,
    # 四千 H702, 六百 H8337, 四十五 H705) all have their `s` spelled by the
    # run's leading character, and only this one inverts. 三 sits in the next
    # run and is tagged H8141, so 二十 spells no part of שָׁלֹשׁ.
    ("jeremiah", "52:30", "二十", "H7969", "H6242"),
]

# Members of the same class that are NOT repaired, each with the reason. The
# shape of a run is not enough on its own: where the Chinese spells BOTH words
# the current `s` is not false, only partial, and a swap would trade one
# partial answer for another while writing "this text does not render it" about
# a character that plainly does.
HELD = {
    ("2_kings", "3:27", "的长子，"): "子 spells בֵּן and 长 spells בְּכוֹר",
    ("ezekiel", "14:9", "以色列中"): "中 spells תָּוֶךְ",
    ("2_samuel", "19:20", "下来"): "下 spells יָרַד and 来 spells בּוֹא; the "
                                   "run's two `g` codes cover both verbs",
    ("genesis", "33:17", "名叫"): "叫 spells קָרָא, and the run's `g` H8804 is "
                                 "that verb's Qal perfect — it would be left "
                                 "parsing a noun",
    ("1_kings", "11:41", "都写在"): "都 may spell הֵם; but the `g` H8803 is "
                                   "כְּתוּבִים's participle, so the run's own "
                                   "grammar code names H3789 — unsettled",
    ("numbers", "32:11", "岁"): "the twin of 民數記 33:39, which is HELD as the "
                                "בֶּן … שָׁנָה age idiom; repairing one would "
                                "settle the other by side effect",
    ("leviticus", "15:24", "所"): "the twin of 出埃及記 16:23, HELD",
    ("genesis", "14:5", "十四"): "十 spells עֶשְׂרֵה and 四 spells אַרְבַּע — "
                                 "neither number is false for it",
    ("1_kings", "1:35", "和犹大"): "和 spells the וְ of וְעַל־יְהוּדָה, and bare "
                                   "和 carries H5921 in 61 runs corpus-wide, so "
                                   "this run does render עַל",
    ("numbers", "19:18", "和一切"): "同上 — 和 in וְעַל־כָּל renders עַל on the "
                                     "corpus's own 61-run precedent",
    ("ezra", "7:11", "诫命"): "诫 carries H1697 in both of its other corpus "
                              "occurrences (申 4:13, 10:4, where 十诫 = "
                              "הַדְּבָרִים), so 诫命 does spell דִּבְרֵי",
    ("2_samuel", "1:6", "马兵"): "马 spells פָּרָשׁ and 兵 may spell בַּעֲלֵי",
    ("2_chronicles", "21:6", "为妻，"): "为 may spell הָיְתָה",
    ("jude", "1:25", "永永远远。"): "the same verse's 从万古 carries the identical "
                                    "G3956/G165 pair and is too rare a run text "
                                    "for the audit to see, so repairing one "
                                    "would split a matched pair",
}


def load(path: pathlib.Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def dominant_numbers(books: dict) -> dict[tuple[str, str], tuple[str, int, int]]:
    """(run text, language) -> (number, occurrences, occurrences with it)."""
    seen: dict = collections.defaultdict(
        lambda: collections.defaultdict(collections.Counter))
    for tagged in books.values():
        for runs in tagged.values():
            for run in runs:
                text = NOT_CJK.sub("", run.get("w") or "")
                number = run.get("s") or ""
                if not text or not number or number == SUPPLIED:
                    continue
                seen[text][number[0]][number] += 1

    out: dict = {}
    for text, languages in seen.items():
        for language, counts in languages.items():
            total = sum(counts.values())
            top, top_count = counts.most_common(1)[0]
            if total >= MIN_OCCURRENCES and top_count / total >= MIN_DOMINANCE:
                out[(text, language)] = (top, total, top_count)
    return out


def span_class(books: dict, dominant: dict, base: dict,
               merged: dict) -> set[tuple[str, str, str]]:
    """Every run of the `spans-the-word` class, as (book, ref, run text).

    Recomputed rather than listed, so `REPAIRS` + `HELD` can be checked for
    completeness against the corpus instead of being trusted. A row that
    stops being a member — because someone repaired it elsewhere — drops out
    here and the coverage check below says so.
    """
    members: set[tuple[str, str, str]] = set()
    for book, tagged in books.items():
        if not (ORIGINALS / f"{book}.json").exists():
            continue
        for ref, runs in tagged.items():
            present = original_numbers(book, ref, base, merged)
            if not present:
                continue
            shown = {r["s"] for r in runs if r.get("s")}
            for run in runs:
                text = NOT_CJK.sub("", run.get("w") or "")
                number = run.get("s") or ""
                if not text or not number:
                    continue
                group = dominant.get((text, number[0]))
                if not group or group[0] == number:
                    continue
                expected = group[0]
                if expected in present and expected not in shown \
                        and expected in (run.get("i") or []):
                    members.add((book, ref, run.get("w")))
    return members


_ORIGINALS_CACHE: dict[str, dict] = {}


def original_numbers(book: str, ref: str, base: dict, merged: dict) -> set[str]:
    path = ORIGINALS / f"{book}.json"
    if not path.exists():
        return set()
    # The completeness gate calls this once per verse; re-reading the file each
    # time costs ~15 ms x 31,102 and is what made a first run outlast a watchdog.
    originals = _ORIGINALS_CACHE.get(book)
    if originals is None:
        originals = _ORIGINALS_CACHE[book] = load(path)
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
    books = {p.stem: load(p) for p in sorted(TAGGED.glob("*.json"))}
    dominant = dominant_numbers(books)

    applied = already = 0
    touched: set[str] = set()
    failures: list[str] = []

    # Completeness: nothing in the class may be silently absent from both
    # tables. Skipped once the repair has run, when the class is empty.
    members = span_class(books, dominant, base, merged)
    if members:
        accounted = {(b, r, t) for b, r, t, _, _ in REPAIRS} | set(HELD)
        missing = members - accounted
        if missing:
            for book, ref, text in sorted(missing):
                failures.append(
                    f"{book} {ref}: {text!r} is in the class and is in neither "
                    f"REPAIRS nor HELD")

    for book, ref, text, old, new in REPAIRS:
        tagged = books.get(book)
        runs = (tagged or {}).get(ref)
        if runs is None:
            failures.append(f"{book} {ref}: verse not in the tagged corpus")
            continue

        # The number must be one the verse's own original actually has, or the
        # repair would be inventing a claim rather than reordering one.
        present = original_numbers(book, ref, base, merged)
        if new not in present:
            failures.append(
                f"{book} {ref}: {new} is not in the verse's original; refusing")
            continue

        # The corpus's own tagging of this exact Chinese string, recomputed
        # here so a stale table cannot outlive the evidence for it.
        group = dominant.get((NOT_CJK.sub("", text), new[0]))
        if not group or group[0] != new:
            failures.append(
                f"{book} {ref}: {text!r} is not dominantly {new} in the corpus "
                f"({group}); refusing")
            continue

        matches = [r for r in runs
                   if r.get("w") == text and r.get("s") == old
                   and new in (r.get("i") or [])]
        settled = [r for r in runs
                   if r.get("w") == text and r.get("s") == new]
        if not matches and settled:
            already += len(settled)
            continue
        if not matches:
            failures.append(
                f"{book} {ref}: no run {text!r} tagged {old} with {new} in `i`")
            continue

        for run in matches:
            # `i` means "the original HAS this number and this text does not
            # render it", so the displaced number may be demoted into it only
            # when the verse's original really has it. At 賽 17:3 (twice),
            # 賽 2:3 and 太 6:8 no such token exists to point at — the מִן is
            # fused as a prefix and 太 6:8's Greek is ὁ πατὴρ ὑμῶν with no
            # θεός — and writing it there would replace one false claim with
            # another. There it is dropped. `i` is inert on screen, so
            # dropping costs coverage, not truth.
            implied = [n for n in (run.get("i") or []) if n != new]
            demoted = old in present
            if demoted:
                implied.append(old)
            run["s"] = new
            # No run in the corpus stores an empty `i`; 306,722 of them simply
            # omit the key. Emptying it therefore means removing it.
            if implied:
                run["i"] = implied
            else:
                run.pop("i", None)
            applied += 1
            touched.add(book)
            fate = "displaced into `i`" if demoted \
                else f"{old} dropped — not in the original"
            print(f"  {book:15} {ref:8} {text!r:14} {old} -> {new} "
                  f"({fate})   [{group[2]}/{group[1]}]")

    if failures:
        for line in failures:
            print(f"REFUSED {line}", file=sys.stderr)
        return 1

    # Runs, not rows: 歷代志上 24:3 carries the same 的子孙 twice.
    print(f"\n{applied} runs repaired, {already} already correct, "
          f"{len(REPAIRS)} rows, {len(HELD)} held")
    if not args.write:
        print("dry run — pass --write to apply")
        return 0
    for book in sorted(touched):
        with (TAGGED / f"{book}.json").open("w", encoding="utf-8") as fh:
            json.dump(books[book], fh, ensure_ascii=False,
                      separators=(",", ":"))
    print(f"wrote {len(touched)} book files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
