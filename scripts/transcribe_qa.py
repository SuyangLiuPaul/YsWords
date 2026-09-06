#!/usr/bin/env python3
"""Checks over a machine transcript that a human proofreader cannot do by eye.

2026-09-06. These are ASR outputs of 16 sermons that exist only as audio.
A person reading one of these can hear a wrong word; these seven failures
are the ones a careful reader will not catch:

  loop        Whisper's repetition stall — the decoder re-emits the same
              clause dozens of times. It reads as emphasis, and by the
              time it looks wrong the reader has accepted three
              paragraphs of it.
  badref      A scripture reference that cannot exist. Amos has 9
              chapters, Revelation 22 — a transcript that says
              「阿摩司书十二章」 is a citation nobody can navigate to and it
              looks exactly like a real one. The canon and the reference
              grammar come from `scripts/extract_sermon_refs.py`, which
              already owns both; this module imports them rather than
              restating them, so a fix there reaches here.
  gap         A stretch of AUDIO with no transcript over it. whisper.cpp
              emits contiguous segments, so a hole in the timeline is a
              decode dropout — the single failure mode that leaves no
              trace at all in the text, because what is missing is
              missing.
  boilerplate A YouTube-subtitle hallucination still in the body. The
              transcriber DELETES only the exact strings it knows and
              records each one; this net is deliberately much wider — a
              substring is enough — because its job is to find the ones
              that list does not know, and it only points.
  bookname    A near-miss of a Bible book name in citation position:
              「菲利比书第一章二十一节」 where the preacher said 腓立比书.
              This one is invisible to `badref` by construction — the
              name is not in the canon, so no chapter or verse is ever
              checked and the citation simply vanishes from refs.json
              while still reading as a citation on the page. ws01 does it
              15 times in one sermon.
  runon       A very long run with no sentence-ending punctuation.
  thin        Empty or near-empty output for a file that has audio.
  nonzh       A segment whose text is not Chinese.

NONE OF THESE IS A SUBSTITUTE FOR READING THE TRANSCRIPT. They cannot see
a misheard proper name, a wrong-but-existing chapter number, a dialect
word, or a sentence that means the opposite of what was said. They narrow
where a person has to look; they do not shorten what a person has to read.

READ THE `runon` NUMBER AS A MEASUREMENT, NOT A FLAG. These decodes carry
roughly one sentence-ending stop per 170 characters, so essentially every
file is one long run-on and a `runon` count of 30 means "this file is
unpunctuated", which is already stated in its own header note. The column
that earns its place is `stops/10k`, the punctuation density: it says how
much of the sentence structure the reader will have to supply.

Usage
-----
    python3 scripts/transcribe_qa.py                # check everything
    python3 scripts/transcribe_qa.py --json OUT     # machine-readable
    python3 scripts/transcribe_qa.py --detail 4258  # every finding, verbatim
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))

import extract_sermon_refs as ESR  # noqa: E402  (path set above)
import transcribe_sermons as TS  # noqa: E402
from transcribe_targets import TRANSCRIPTS  # noqa: E402

# ── thresholds, each with the reason it is what it is ────────────────
#
# A loop is three or more CONSECUTIVE segments with the same text. Two in
# a row is a real thing a preacher does (「是的。是的。」); three is already
# unusual and the observed stalls run to dozens, so the bar sits where a
# false positive costs a glance and a false negative costs a paragraph of
# invented text.
LOOP_MIN_RUN = 3
# Within one segment: the same 4+ character phrase immediately repeated
# 4+ times. Short units (「哈哈哈哈」) are excluded by the length floor.
LOOP_NGRAM_MIN_CHARS = 4
LOOP_NGRAM_MIN_REPEATS = 4
# 200 characters of Chinese with no 。！？ is roughly four spoken sentences
# run together.
RUNON_CHARS = 200
# A 29-minute sermon at even a slow spoken 150 chars/min is ~4 000
# characters. 40 chars per minute of audio is a floor continuous speech
# cannot fall under, so falling under it means the decode failed — or
# that the recording is not continuous speech, which is the OTHER thing
# worth knowing (ws01/ws04/CM03 open with sung worship).
THIN_CHARS_PER_MIN = 40
# whisper.cpp's segments butt against each other: measured over
# rms06-01's 502 segments the inter-segment gap is 0.00 s at every
# twentieth-quantile. So 5 s of uncovered audio is not jitter.
GAP_SEC = 5.0
# A segment is "not Chinese" if it is long enough to judge and holds
# almost no CJK.
NONZH_MIN_CHARS = 8
NONZH_CJK_RATIO = 0.30

_CJK = re.compile(r"[一-鿿]")
# NOT `\n`. The sidecar stores one segment per line, ~11 characters each,
# so counting a newline as a sentence stop makes every run 11 characters
# and the check reports zero every time — which is what it did until this
# was measured against a file whose punctuation density is 59 stops per
# 10 000 characters. The run-on this looks for is a run of SPEECH with no
# stop in it, so the newlines are removed before the scan.
_SENT_STOP = re.compile(r"[。！？!?；;]")
_STOPS = "。！？!?"


def _norm(s: str) -> str:
    return re.sub(r"\s+", "", s or "").strip()


# ── loop ────────────────────────────────────────────────────────────

def find_segment_loops(segments: list[dict]) -> list[dict]:
    """Runs of >= LOOP_MIN_RUN consecutive segments with identical text."""
    out = []
    i = 0
    while i < len(segments):
        text = _norm(segments[i].get("text"))
        j = i + 1
        while j < len(segments) and _norm(segments[j].get("text")) == text:
            j += 1
        if text and (j - i) >= LOOP_MIN_RUN:
            out.append({
                "kind": "segment_repeat",
                "runLength": j - i,
                "text": segments[i].get("text", "")[:120],
                "fromSegment": i,
                "toSegment": j - 1,
                "start": segments[i].get("start"),
                "end": segments[j - 1].get("end"),
            })
        i = j
    return out


def find_ngram_loops(text: str) -> list[dict]:
    """A phrase immediately repeated many times inside one stretch of text.

    Catches the stall that lands inside a single long segment, which the
    consecutive-segment detector cannot see.
    """
    out = []
    seen_at: set[int] = set()
    # Longest unit first, so 「因为神爱我们因为神爱我们」 is reported as one
    # 6-char phrase rather than as its 3-char prefix.
    for size in range(24, LOOP_NGRAM_MIN_CHARS - 1, -1):
        pos = 0
        while pos + size * LOOP_NGRAM_MIN_REPEATS <= len(text):
            unit = text[pos:pos + size]
            if not unit.strip():
                pos += 1
                continue
            reps = 1
            while text[pos + reps * size: pos + (reps + 1) * size] == unit:
                reps += 1
            if reps >= LOOP_NGRAM_MIN_REPEATS:
                span = set(range(pos, pos + reps * size))
                if not (span & seen_at):
                    out.append({"kind": "ngram_repeat", "unit": unit,
                                "repeats": reps, "charOffset": pos})
                    seen_at.update(span)
                pos += reps * size
            else:
                pos += 1
    return sorted(out, key=lambda d: d["charOffset"])


# ── badref ──────────────────────────────────────────────────────────

def find_impossible_refs(text: str) -> list[dict]:
    """Citation-shaped strings naming a chapter or verse that does not exist.

    `extract_sermon_refs.extract_refs` already refuses these — that is what
    `exists()` is for — which is exactly why they need their own check: a
    refused reference leaves NO trace in refs.json, so the index looks
    clean while the transcript body still shows the reader 「阿摩司书十二章」.
    This walks the same REF_RE over the same CANON and reports what the
    extractor silently dropped.
    """
    out = []
    for m in ESR.REF_RE.finditer(text):
        canon = ESR.ALIAS.get(ESR.normalize_alias(m.group("book")))
        if canon is None:
            continue
        ch = ESR._int(m.group("ch"), m.group("chcn"))
        if ch is None:
            continue
        verse = ESR._int(m.group("v") or m.group("v2"),
                         m.group("vcn") or m.group("vcn2"))
        if ESR.exists(canon, ch, verse):
            continue
        chapters = ESR.CANON.get(canon) or {}
        # A ONE-CHAPTER BOOK has no chapter to name, so 「犹大书十一节」 is
        # Jude verse 11, not Jude chapter 11. Found by this check firing on
        # CM03 and being WRONG: the transcript reads 「在犹大书十一节，毁谤这
        # 个字是被翻译为背叛，是描述可拉的背叛」 and Jude 11 is precisely the
        # verse about Korah. `extract_refs` gets this right on its own —
        # `extract_refs('犹大书十一节')` returns Jude 1:11 — but loses it when
        # a 「在」 precedes the book name, and REF_RE alone, which is what
        # this walks, never had the rule at all.
        if (verse is None and len(chapters) == 1
                and ch in next(iter(chapters.values()))):
            continue
        if not chapters:
            why = f"{canon} is not in the canon"
        elif ch not in chapters:
            why = f"{canon} has {max(chapters)} chapters"
        else:
            why = f"{canon} {ch} has {max(chapters[ch])} verses"
        out.append({
            "kind": "impossible_ref",
            "matched": m.group(0),
            "book": canon, "chapter": ch, "verse": verse, "why": why,
            "charOffset": m.start(),
            "context": text[max(0, m.start() - 30):m.end() + 30],
        })
    return out


# ── gap ─────────────────────────────────────────────────────────────

def find_gaps(segments: list[dict], duration_sec: float | None,
              removed: list[dict] | None = None) -> list[dict]:
    """Audio with no transcript over it — a decode dropout.

    The one failure that leaves no trace in the text, because what is
    missing is missing. Head and tail count too: a decode that gives up
    at minute 22 of a 29-minute file looks like a complete transcript.

    `removed` matters and was found by measurement: the transcriber drops
    the boilerplate segments, and the first version of this check then
    reported the holes THE TRANSCRIBER had made as decode dropouts — 60 s
    at the head of rms06-01 and 37 s at its tail, both of them exactly the
    three 「请不吝点赞…」 segments. A check that reports its own pipeline's
    edits back to the reader is worse than no check. Removed spans count
    as covered; they are reported separately, verbatim.
    """
    spans = [(s.get("start"), s.get("end") or s.get("start"))
             for s in list(segments) + list(removed or [])
             if s.get("start") is not None]
    spans.sort()
    out = []
    prev = 0.0
    for i, (start, end) in enumerate(spans):
        if start - prev >= GAP_SEC:
            out.append({"kind": "gap", "fromSec": round(prev, 1),
                        "toSec": round(start, 1),
                        "seconds": round(start - prev, 1),
                        "afterSec": round(prev, 1)})
        prev = max(prev, end)
    if duration_sec and duration_sec - prev >= GAP_SEC:
        out.append({"kind": "gap", "fromSec": round(prev, 1),
                    "toSec": round(duration_sec, 1),
                    "seconds": round(duration_sec - prev, 1), "tail": True})
    return out


# ── bookname ───────────────────────────────────────────────────────

# Only names of this length or longer are checked. One- and two-character
# aliases (创, 撒上) are one edit from far too much ordinary Chinese, and a
# check that cries wolf is a check nobody reads.
BOOKNAME_MIN_CHARS = 3
# The near-miss only counts in CITATION POSITION: a chapter or verse
# marker has to follow within this many characters. Without it 「非力」 in
# 「非力所能及」 becomes a Philippians.
BOOKNAME_TAIL_CHARS = 8
_CITE_TAIL = re.compile(r"[章节節篇]|第\s*[0-9一二三四五六七八九十百]")


def _zh_aliases() -> list[str]:
    return sorted({a for a in ESR.ALIAS
                   if len(a) >= BOOKNAME_MIN_CHARS
                   and all("\u4e00" <= c <= "\u9fff" for c in a)})


_ZH_ALIASES = _zh_aliases()
_ALIAS_SET = set(ESR.ALIAS)


def _one_edit_apart(a: str, b: str) -> bool:
    """Exactly one substitution, on equal-length strings."""
    return len(a) == len(b) and sum(x != y for x, y in zip(a, b)) == 1


def find_bad_book_names(text: str) -> list[dict]:
    """A book name one character wrong, standing in citation position.

    Invisible to `badref` by construction: the name is not in the canon,
    so no chapter or verse is ever checked, the citation never reaches
    refs.json, and the page still reads as if it carried one. ws01 writes
    腓立比书 as 「菲利比书」 fifteen times, which is how this check was found
    to be needed — the sermon is TITLED from Philippians 1:21.

    ONE SUBSTITUTION ONLY, AND THAT LEAVES 菲利比书 ITSELF UNCAUGHT — it is
    two. Two was measured before it was rejected: over 60 human library
    bodies (correct text, so every hit is a false positive) one
    substitution gives 9 hits and two gives 92, because 「X罗马书」 is two
    substitutions from 哥罗西书 for any X and the rule then fires on
    「在罗马书」, 「看罗马书」, 「说罗马书」 and forty more. A check nobody reads
    catches nothing. The 2-edit class is a known blind spot; read the
    book names in a citation you care about.

    At one substitution it found, across these 16: 以夫所书, 以福所书,
    加勒太书, 帖撒罗尼加前书, 提摩泰前书, 格林多前书, 格林多后书, 民俗记,
    罗西书, 西伯来书, 马拉基书. Some of those are the church's own spelling
    rather than an error, which is why this points and never edits.
    """
    out, seen = [], set()
    for alias in _ZH_ALIASES:
        n = len(alias)
        for i in range(len(text) - n + 1):
            cand = text[i:i + n]
            if cand in _ALIAS_SET or not _one_edit_apart(cand, alias):
                continue
            if not _CITE_TAIL.search(text[i + n:i + n + BOOKNAME_TAIL_CHARS]):
                continue
            key = (cand, alias)
            if key in seen:
                continue
            seen.add(key)
            out.append({"kind": "bad_book_name", "matched": cand,
                        "probably": alias, "book": ESR.ALIAS[alias],
                        "occurrences": text.count(cand), "charOffset": i,
                        "context": text[max(0, i - 25):i + n + 25]})
    return sorted(out, key=lambda d: -d["occurrences"])


# ── boilerplate / runon / thin / nonzh ──────────────────────────────

# The transcriber's blocklist is narrow because it DELETES. This one is
# wide because it only points: a substring is enough. Its job is to catch
# the boilerplate the narrow list does not know, and its false positives
# cost a glance. Both are run.
SUSPECT_SUBSTRINGS = [
    "点赞", "订阅", "打赏", "字幕", "Amara", "amara", "独播剧场",
    "本频道", "关注我们", "subscribe", "Subscribe",
]


def find_boilerplate(segments: list[dict]) -> list[dict]:
    """Subtitle boilerplate still in the body.

    Two nets. The transcriber's own `_HALL_RE`, so a segment it should
    have dropped and did not is reported as such; and a much wider
    substring net for the boilerplate nobody has seen yet. Whisper was
    trained on YouTube subtitles and will emit their furniture over music
    and silence; this corpus's four long recordings open with sung
    worship, which is exactly the condition that produces it.
    """
    out = []
    for i, s in enumerate(segments):
        text = re.sub(r"\s+", " ", s.get("text", "")).strip()
        exact = bool(TS._HALL_RE.match(text))
        hit = next((w for w in SUSPECT_SUBSTRINGS if w in text), None)
        if exact or hit:
            out.append({"kind": "boilerplate", "segment": i,
                        "start": s.get("start"),
                        "why": ("blocklist match not dropped" if exact
                                else f"contains {hit!r}"),
                        "text": s.get("text", "")[:120]})
    return out


def find_runons(text: str) -> list[dict]:
    text = text.replace("\n", "")
    out, pos = [], 0
    for stop in _SENT_STOP.finditer(text):
        if stop.start() - pos >= RUNON_CHARS:
            out.append({"kind": "runon", "chars": stop.start() - pos,
                        "charOffset": pos, "excerpt": text[pos:pos + 60]})
        pos = stop.end()
    if len(text) - pos >= RUNON_CHARS:
        out.append({"kind": "runon", "chars": len(text) - pos,
                    "charOffset": pos, "excerpt": text[pos:pos + 60]})
    return out


def find_thin(text: str, duration_sec: float | None) -> list[dict]:
    chars = len(_norm(text))
    if not duration_sec:
        return ([] if chars else
                [{"kind": "thin", "chars": 0, "why": "empty output"}])
    floor = THIN_CHARS_PER_MIN * duration_sec / 60.0
    if chars < floor:
        return [{"kind": "thin", "chars": chars,
                 "why": f"{chars} chars for {duration_sec / 60:.1f} min of "
                        f"audio; floor is {floor:.0f}"}]
    return []


def find_non_chinese(segments: list[dict]) -> list[dict]:
    out = []
    for i, seg in enumerate(segments):
        t = _norm(seg.get("text"))
        if len(t) < NONZH_MIN_CHARS:
            continue
        ratio = len(_CJK.findall(t)) / len(t)
        if ratio < NONZH_CJK_RATIO:
            out.append({"kind": "non_chinese", "segment": i,
                        "cjkRatio": round(ratio, 3), "start": seg.get("start"),
                        "end": seg.get("end"), "text": seg.get("text", "")[:120]})
    return out


# ── driver ──────────────────────────────────────────────────────────

def check(text: str, segments: list[dict], duration_sec: float | None,
          removed: list[dict] | None = None) -> dict:
    findings = {
        "loop": find_segment_loops(segments) + find_ngram_loops(text),
        "badref": find_impossible_refs(text),
        "bookname": find_bad_book_names(text.replace("\n", "")),
        "gap": find_gaps(segments, duration_sec, removed),
        "boilerplate": find_boilerplate(segments),
        "runon": find_runons(text),
        "thin": find_thin(text, duration_sec),
        "nonzh": find_non_chinese(segments),
    }
    chars = len(_norm(text))
    stops = sum(text.count(c) for c in _STOPS)
    # `runon` is a measurement, not a flag — see the header. It is
    # deliberately left out of `clean`, or every file would be dirty for
    # the reason its own note already states.
    return {
        "counts": {k: len(v) for k, v in findings.items()},
        "chars": chars,
        "stops": stops,
        "stopsPer10k": round(stops * 10000 / chars) if chars else 0,
        "findings": findings,
        "clean": not any(v for k, v in findings.items() if k != "runon"),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=str(TRANSCRIPTS))
    ap.add_argument("--json", default=None)
    ap.add_argument("--detail", default=None,
                    help="comma-separated ids: print every finding verbatim")
    args = ap.parse_args()

    root = Path(args.dir)
    sidecars = sorted((p for p in root.glob("*.json")
                       if p.name not in ("index.json", "qa_report.json")),
                      key=lambda p: int(p.stem) if p.stem.isdigit() else 0)
    if not sidecars:
        print(f"no transcripts under {root}", file=sys.stderr)
        return 1

    report, total = {}, {}
    for p in sidecars:
        d = json.loads(p.read_text(encoding="utf-8"))
        tr = d.get("transcription", {})
        removed = tr.get("edits", {}).get("removedHallucinations", [])
        res = check(d["text"], d.get("segments", []), d.get("durationSec"),
                    removed)
        res["removedHallucinations"] = removed
        report[p.stem] = {"refcode": d.get("refcode"), "title": d.get("title"),
                          "durationSec": d.get("durationSec"), **res}
        for k, v in res["counts"].items():
            total[k] = total.get(k, 0) + v

    hdr = (f"{'id':>6} {'refcode':<10} {'min':>5} {'chars':>6} "
           f"{'stops/10k':>9}  loop badref book gap boiler thin nonzh  runon")
    print(hdr)
    print("-" * len(hdr))
    for sid, r in report.items():
        c = r["counts"]
        flag = "" if r["clean"] else "  <-- LOOK"
        print(f"{sid:>6} {str(r['refcode']):<10} "
              f"{(r['durationSec'] or 0) / 60:5.1f} {r['chars']:6,} "
              f"{r['stopsPer10k']:9}  "
              f"{c['loop']:>4} {c['badref']:>6} {c['bookname']:>4} "
              f"{c['gap']:>3} "
              f"{c['boilerplate']:>6} {c['thin']:>4} {c['nonzh']:>5}  "
              f"{c['runon']:>5}{flag}")
    print(f"\nTOTAL  {total}")
    dropped = sum(len(r["removedHallucinations"]) for r in report.values())
    print(f"boilerplate segments dropped by the transcriber (recorded, not "
          f"in the body): {dropped}")
    print("\nrunon is a MEASUREMENT, not a flag: these decodes are largely "
          "unpunctuated and every file's own note says so.\n"
          "None of these checks can see a misheard name, a real-but-wrong "
          "verse number, or a reversed meaning. Read the transcripts.")

    if args.detail:
        want = {s.strip() for s in args.detail.split(",")}
        for sid, r in report.items():
            if sid not in want and r["refcode"] not in want:
                continue
            print(f"\n=== {sid} {r['refcode']} {r['title']} ===")
            for kind, items in r["findings"].items():
                if kind == "runon" or not items:
                    continue
                print(f"  [{kind}] {len(items)}")
                for it in items[:40]:
                    print(f"    {json.dumps(it, ensure_ascii=False)}")
            for it in r["removedHallucinations"]:
                print(f"    [dropped] {json.dumps(it, ensure_ascii=False)}")

    if args.json:
        Path(args.json).write_text(
            json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"wrote {args.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
