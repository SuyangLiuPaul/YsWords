#!/usr/bin/env python3
"""Measure the error rate of one machine transcript against a ground truth.

2026-09-06. The brief asks for a measured error rate on a sample actually
checked, rather than an unmeasured claim about sixteen files. The obvious
way to get one is to listen to the audio and type what you hear. That is
what the owner will do; it is not available to an agent with no ears.

So this measures the one place in a sermon where a ground truth already
exists in this repository: THE VERSES THE PREACHER READS ALOUD. When he
says 「罗马书六章第三节说」 and then reads it, the correct characters are
`assets/cuvs-yhwh.json`'s, and every deviation is either a transcription
error or the preacher paraphrasing. Both are worth seeing; the report
prints the pair so a person can tell them apart in a glance instead of a
minute.

WHAT THIS IS NOT. It is a CER on read scripture, which is the EASIEST
text in the sermon — it is formal, it is slow, and the model has seen the
Chinese Bible many times. The error rate on the preacher's own speech, on
proper names, on dialect and on this preacher's Cantonese-inflected
Mandarin will be HIGHER, not lower. Read this number as a floor.

It is optimistic in a second, smaller way that is worth stating: when a
verse is read TWICE — Romans 6:4 is, in rms06-01 — the window search
finds whichever reading came out better, and scores that one.

The instrument itself was checked the only way that means anything:
five substitutions were injected into a matched window and the measured
distance rose by exactly five. On the first attempt it rose by ONE, which
is how the double-reading above was found.

The second measurement, `--disagree`, is a floor of a different kind and
needs no ground truth at all: decode the same audio under two decoder
configurations and count where they differ. Every difference is one of
them being wrong, so the disagreement rate is a lower bound on the error
rate of the better one, over the WHOLE file rather than over its quoted
verses.

Usage
-----
    python3 scripts/transcribe_sample_check.py 4258 --refs "Romans 6:1-14"
    python3 scripts/transcribe_sample_check.py 4258            # auto refs
    python3 scripts/transcribe_sample_check.py --disagree A.json B.json
    python3 scripts/transcribe_sample_check.py --compare 6012 CP37

`--compare` answers the one question the seam cannot: is this audio-only
library record the SAME SERMON as an app record that shares its title?
`refs.json` tiered 6012/CP37 `confirmed` on an exact title alone and then
refuted it "AS A PAIR OF TEXTS, not as an identity claim", because there
was no library body. A body now exists, so the pair of texts exists.

The number on its own means nothing, so `--compare` always prints a
CALIBRATION PAIR alongside it: 6014/396 (救恩与软弱 / Salvation and
Weakness), a pair `refs.json` grades `confirmed` and which is the same
KIND of pair — a Chinese text of this camp against the app's Chinese
translation of the English. Read the candidate against that yardstick and
against the control, never against an absolute threshold.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))

import extract_sermon_refs as ESR  # noqa: E402
from transcribe_targets import TRANSCRIPTS  # noqa: E402

CUV = REPO / "assets" / "cuvs-yhwh.json"

# `cuvs-yhwh.json` is the divine-name edition: it spells the Tetragrammaton
# 雅伟 where a standard 和合本 has 耶和华. A preacher reading aloud says one
# or the other and the difference is an edition, not an error, so both are
# folded before the comparison. Nothing else is normalised.
_DIVINE = re.compile(r"雅伟|耶和华")
_NON_CJK = re.compile(r"[^一-鿿]")


def cuv_index() -> dict[tuple[str, int, int], str]:
    out = {}
    for v in json.loads(CUV.read_text(encoding="utf-8")):
        out[(v["book"], int(v["chapter"]), int(v["verse"]))] = v["text"]
    return out


def strip(s: str) -> str:
    return _NON_CJK.sub("", _DIVINE.sub("神名", s))


def levenshtein(a: str, b: str) -> int:
    if len(a) < len(b):
        a, b = b, a
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1,
                           prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def lcs_len(a: str, b: str) -> int:
    """Longest common CONTIGUOUS substring. The "was this read aloud?" test."""
    if not a or not b:
        return 0
    prev = [0] * (len(b) + 1)
    best = 0
    for ca in a:
        cur = [0] * (len(b) + 1)
        for j, cb in enumerate(b, 1):
            if ca == cb:
                cur[j] = prev[j - 1] + 1
                best = max(best, cur[j])
        prev = cur
    return best


def best_window(hay: str, needle: str) -> tuple[int, int, int]:
    """Cheapest window of `hay` against `needle`. Returns (start, end, dist).

    A full DP over every window is O(n*m^2) over a 5 000-character
    transcript, so the search is anchored: every place a 4-character piece
    of the needle appears in the haystack proposes a start, OFFSET BY THAT
    PIECE'S POSITION IN THE NEEDLE. Anchoring only on the needle's opening
    four characters was the first version and it under-reported: 彼得前書
    2:21 scored 20% because the window began at 「是为此」 and the five
    characters before it were outside the window, not missing from the
    transcript.
    """
    n = len(needle)
    if not n or not hay:
        return (0, 0, max(n, len(hay)))
    starts = {0}
    for i in range(0, n - 3, 2):
        for m in re.finditer(re.escape(needle[i:i + 4]), hay):
            starts.add(max(0, m.start() - i))
    starts |= {i for i in range(0, max(1, len(hay) - n), max(1, n // 3))}
    best = (0, 0, 10**9)
    for st in sorted(starts):
        for length in (n - n // 5, n, n + n // 5, n + n // 3):
            e = min(len(hay), st + length)
            d = levenshtein(hay[st:e], needle)
            if d < best[2]:
                best = (st, e, d)
    return best


# A verse counts as READ ALOUD only if the transcript and the CUV share a
# contiguous run this long. Without it the measurement is meaningless: a
# preacher who says 「罗马书五章十二到二十一节是第六到第八章的总纲」 has cited
# ten verses and read none of them, and scoring the transcript against
# text that was never spoken reported an 87% "error rate" on Romans 5:14.
# Ten characters is far past coincidence in Chinese and far under any
# quotation the model got even half right.
READ_ALOUD_LCS = 10


def measure(sid: str, refs: list[str], verbose: bool) -> None:
    side = json.loads((TRANSCRIPTS / f"{sid}.json").read_text(encoding="utf-8"))
    hay = strip(side["text"])
    cuv = cuv_index()
    # `extract_sermon_refs` speaks English book names; the CUV file is
    # Chinese. ALIAS maps every Chinese alias to the English canon name,
    # so invert it rather than writing a second table of 66 book names.
    zh_for = {}
    for alias, canon in ESR.ALIAS.items():
        if (alias, 1, 1) in cuv or any((alias, c, 1) in cuv for c in (1,)):
            zh_for.setdefault(canon, alias)

    total_chars = total_dist = 0
    rows, mentioned = [], []
    for ref in refs:
        m = re.match(r"^(.+?)\s+(\d+):(\d+)(?:-(\d+))?$", ref.strip())
        if not m:
            print(f"  ?? cannot parse {ref!r}", file=sys.stderr)
            continue
        book, ch = m.group(1), int(m.group(2))
        v0, v1 = int(m.group(3)), int(m.group(4) or m.group(3))
        zh = zh_for.get(book)
        if zh is None:
            print(f"  ?? no Chinese book name for {book}", file=sys.stderr)
            continue
        for v in range(v0, v1 + 1):
            truth = cuv.get((zh, ch, v))
            if truth is None:
                continue
            t = strip(truth)
            st, e, d = best_window(hay, t)
            if lcs_len(t, hay[st:e]) < READ_ALOUD_LCS:
                mentioned.append(f"{zh} {ch}:{v}")
                continue
            total_chars += len(t)
            total_dist += d
            rows.append((f"{zh} {ch}:{v}", len(t), d, d / len(t),
                         t, hay[st:e]))

    rows.sort(key=lambda r: -r[3])
    print(f"\n=== {sid} {side['refcode']} {side['title']} ===")
    print(f"read-scripture CER: {total_dist}/{total_chars} = "
          f"{total_dist / max(total_chars, 1):.1%} over {len(rows)} verses "
          f"the preacher actually read aloud")
    print(f"cited but not read (no {READ_ALOUD_LCS}-character shared run, "
          f"so nothing to score): {len(mentioned)}"
          + (f" — {', '.join(mentioned)}" if mentioned else ""))
    print("(a FLOOR — read scripture is the easiest text in the sermon)\n")
    for ref, n, d, cer, truth, got in rows:
        mark = "!!" if cer > 0.25 else ("!" if cer > 0.10 else "  ")
        print(f"{mark} {ref:<14} {cer:6.1%}  ({d}/{n})")
        if verbose or cer > 0.10:
            print(f"     CUV  {truth}")
            print(f"     ASR  {got}")


def disagree(a_path: Path, b_path: Path) -> None:
    def load(p: Path) -> str:
        raw = p.read_bytes().decode("utf-8", errors="replace")
        d = json.loads(raw)
        segs = (d.get("transcription") or d.get("segments") or [])
        return strip("".join(s["text"] for s in segs))
    a, b = load(a_path), load(b_path)
    d = levenshtein(a, b)
    print(f"\nconfiguration disagreement: {d} edits over "
          f"{max(len(a), len(b))} characters = "
          f"{d / max(len(a), len(b), 1):.1%}")
    print("every one of those is one configuration or the other being "
          "wrong, so this is a LOWER BOUND on the error rate of the better "
          "of the two, over the whole file.")


SERMONS = REPO / "assets" / "sermons"
# A pair `refs.json` grades `confirmed`, of the same kind and the same
# camp as 6012/CP37. It is the yardstick, not a threshold.
CALIBRATION = ("6014", "396")


def ngrams(text: str, n: int = 6) -> set[str]:
    t = _NON_CJK.sub("", text)
    return {t[i:i + n] for i in range(len(t) - n + 1)}


def similarity(a: str, b: str) -> tuple[float, float]:
    A, B = ngrams(a), ngrams(b)
    if not A or not B:
        return (0.0, 0.0)
    return (len(A & B) / len(A | B), len(A & B) / min(len(A), len(B)))


def _lib_text(lib_id: str) -> str:
    side = TRANSCRIPTS / f"{lib_id}.json"
    if side.exists():
        return json.loads(side.read_text(encoding="utf-8"))["text"]
    body = REPO / "assets" / "sermon_library" / "bodies" / f"{lib_id}.txt"
    return body.read_text(encoding="utf-8")


def compare(lib_id: str, app_id: str) -> None:
    lib = _lib_text(lib_id)
    app = (SERMONS / "zh-CN" / f"{app_id}.txt").read_text(encoding="utf-8")
    cal_lib = _lib_text(CALIBRATION[0])
    cal_app = (SERMONS / "zh-CN" / f"{CALIBRATION[1]}.txt").read_text(
        encoding="utf-8")

    rows = [
        (f"CANDIDATE   lib {lib_id} vs app {app_id}", lib, app),
        (f"CALIBRATION lib {CALIBRATION[0]} vs app {CALIBRATION[1]} "
         f"(refs.json: confirmed)", cal_lib, cal_app),
        (f"CONTROL     lib {lib_id} vs app {CALIBRATION[1]}", lib, cal_app),
        (f"CONTROL     lib {CALIBRATION[0]} vs app {app_id}", cal_lib, app),
    ]
    print()
    for label, a, b in rows:
        j, o = similarity(a, b)
        ra, rb = set(ESR.extract_refs(a)), set(ESR.extract_refs(b))
        shared = sorted(ra & rb)
        print(f"{label}")
        print(f"    6-gram Jaccard {j:.4f}   overlap {o:.4f}   "
              f"refs {len(ra)}/{len(rb)} shared {len(shared)}")
        if shared:
            print(f"    shared refs: {', '.join(shared[:12])}"
                  + (" …" if len(shared) > 12 else ""))
    print("\nRead the candidate against the calibration row and the two "
          "controls.\nA machine transcript is noisier than the human text "
          "in the calibration\nrow, so a candidate at or above it is strong "
          "evidence and one an order\nof magnitude below it, at control "
          "level, is evidence of a different sermon.")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("sid", nargs="?")
    ap.add_argument("--refs", default=None,
                    help='e.g. "Romans 6:1-14,Romans 5:20"')
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--disagree", nargs=2, default=None,
                    metavar=("A.json", "B.json"))
    ap.add_argument("--compare", nargs=2, default=None,
                    metavar=("LIB_ID", "APP_ID"))
    args = ap.parse_args()

    if args.compare:
        compare(*args.compare)
        return 0
    if args.disagree:
        disagree(Path(args.disagree[0]), Path(args.disagree[1]))
        return 0
    if not args.sid:
        ap.error("give a transcript id, or --disagree A.json B.json")

    if args.refs:
        refs = [r for r in args.refs.split(",") if r.strip()]
    else:
        side = json.loads((TRANSCRIPTS / f"{args.sid}.json")
                          .read_text(encoding="utf-8"))
        # Every reference the extractor finds, deduped and verse-bearing
        # only: a bare chapter has no single text to compare against.
        refs = sorted({r for r in ESR.extract_refs(side["text"]) if ":" in r})
    measure(args.sid, refs, args.verbose)
    return 0


if __name__ == "__main__":
    sys.exit(main())
