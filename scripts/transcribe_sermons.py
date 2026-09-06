#!/usr/bin/env python3
"""Machine-transcribe the 16 audio-only sermon-library records to Simplified Chinese.

2026-09-06. These sixteen records of Pastor Eric Chang carry no body and no
transcript document — the audio is the only copy. 18 mp3s, 11 h 15 m: 14
sermons of 29 minutes at 16 kbps and 8 kHz — telephone band, nothing above
4 kHz — and 4 files of 59 minutes at 32 kbps and 22 kHz, which are two
two-part radio programmes plus CM03. (The brief said "23-30 minutes";
four of the eighteen are twice that.) This produces a MACHINE
transcript of each, marks it as one, and drops it on the seam
`merge_sermon_library.py` already built (`bodies/<id>.txt` + `hasBody`).

WHERE THE PROVENANCE MARK HAS TO LIVE, AND WHY IT IS IN THE BODY TEXT
---------------------------------------------------------------------
The owner ruled that a human transcription beats a machine one, and that
ruling is why this corpus was rebuilt. So a machine transcript must never
be presentable as a human one.

The brief asks for the mark to be "in a field the merge carries through".
Read `merge_sermon_library.py` and there is exactly one such field: the
BODY TEXT. Its `index_add` block is a fixed literal — id, topic, date,
parts, passage, title, titles, hasEn/hasZhCn/hasZhTw — and no key of the
library record survives into `assets/sermons/index.json`. Everything else
is dropped at the seam. A `transcription` block added to the library index
would be true, and invisible three minutes later.

So the mark is a `[注：…]` paragraph, second line of the body, naming the
tool, the model and the date. `library_body_to_app_body` turns it into the
first paragraph after the H1; `tools/prerender_sermons.dart::isEditorialNote`
already renders `[注：…]` as an editorial note and keeps it out of the meta
description; `to_traditional` carries it into zh-TW. It travels with the
text when the text is copied, excerpted or exported, which a sibling JSON
does not. (`assets/sermons/EC018.txt` and `EC019.txt` are raw ASR carrying
no marker in `assets/` at all — this is the failure being avoided, not a
hypothetical.)

The sidecar under `transcripts/<id>.json` records the same facts in full,
plus every edit this script made. When a human proofreads one of these,
REWRITE the note and flip `proofread` — never delete the note. A file
should always state its own status.

TOOL AND SETTINGS, EACH MEASURED HERE ON 2026-09-06 (M5 Pro, 24 GB)
-------------------------------------------------------------------
whisper.cpp `whisper-cli`, ggml-large-v3 (f16), Metal:  -l zh -bs 5 -bo 5 -mc 0

  whisper.cpp, not openai-whisper. On the SAME 5-minute clip of rms06-01:
  whisper.cpp 25 s, openai-whisper 515 s — 12x realtime against 0.58x, a
  factor of 20. `--device mps` does not rescue it: it ran 310 s and
  produced no output file at all. Over this corpus's 11 h 15 m of audio
  that is 44 minutes against about 19 hours — the run this settled took
  2 653 s of decode at 15.3x realtime. Quality did not pay for
  it either: on that clip openai-whisper emitted 945 non-space characters
  to whisper.cpp's 948, with ZERO sentence-ending punctuation to
  whisper.cpp's 6, and misread 「像基督借着父的荣耀」 as 「向基督…」.

  large-v3, not large-v3-turbo. Turbo's 4-layer decoder is the wrong
  trade for a corpus whose value is chapter/verse numbers and doctrinal
  vocabulary.

  beam 5. Kept from the inherited script; not re-measured here, and the
  cost of being wrong is a silent dropout, so the safer setting stays.

  -mc 0 (no carried decoder context). Measured over the WHOLE of
  rms06-01, not a clip: -mc 0 gave 502 segments, 5 332 characters and 31
  sentence-ending stops; the default carried context gave 700 segments,
  5 390 characters and ZERO stops. Carried context is also the mechanism
  a repetition loop runs on. See REFUTED below — the inherited script had
  this setting right and its stated reason backwards.

  NO --prompt. A punctuated Chinese prompt DOES buy punctuation, but only
  for as long as the prompt survives: on a 5-minute clip it produced 28
  stops against 5, and on the full 29-minute file it produced 0, because
  after the first window the carried context is the model's own
  unpunctuated output. It also induced a 6x repetition loop
  (「明白这一点就能帮助我们明白洗礼的重要和意义。」) that the no-prompt run
  does not have. Bought nothing, cost a loop.

  NO --vad. Not re-measured; the inherited note that silero turned
  「从前」/「现今」 into 「铜钱」/「现金」 is cheap to respect and expensive to
  be wrong about.

  Temperature fallback LEFT ON. The fallback ladder is what ESCAPES a
  repetition loop. Loops are found afterwards by `transcribe_qa.py`.

  opencc t2s afterwards, because `-l zh` does not control script and
  Whisper mixes Traditional into Simplified inside one file.

REFUTED — claims in the inherited script that did not reproduce
---------------------------------------------------------------
  * "Carried context buys punctuation and costs accuracy. Cost, stated
    plainly: these transcripts carry very little sentence-ending
    punctuation [at -mc 0]." Backwards. Measured on the full file, -mc 0
    gave 31 stops and carried context gave 0.
  * "At the default context the decoder produced 「以致于陈胜」 where the
    audio has 「以至于成圣」, and it did so twice. It also lost a
    60-character quotation of Romans 6:19." Neither reproduced. Both
    configurations, over the full file, wrote 「以至于成圣」 at every site
    and both carried the Romans 6:19 quotation. If anything the error ran
    the other way: -mc 0 wrote 「献金也要照样」 where carried context
    correctly wrote 「现今也要照样」.
  * "NO --prompt. Measured inert: at -mc 0 the output with a prompt is
    BYTE-IDENTICAL to the output without one." True and uninteresting —
    at -mc 0 the prompt IS the context that -mc 0 discards. The prompt is
    not inert at the default context; it is harmful, which is a different
    and better reason to refuse it.
  * The handover's "openai-whisper recovered every marker passage with
    full punctuation". Not reproducible: zero sentence-ending punctuation
    on the clip it was claimed on, and 20x the wall clock.

WHAT THIS SCRIPT EDITS, AND WHAT IT REFUSES TO EDIT
----------------------------------------------------
Every edit is counted in the sidecar. There are four, and no others:

  1. opencc t2s. Character-level, safe direction. `openccCharsMoved`.
  2. Punctuation normalised to fullwidth. whisper.cpp emits ASCII "," "?"
     "!" and, with a prompt, the presentation form U+FE50; the shipped
     corpus is fullwidth throughout. Typography only — no mark is added,
     removed or moved. `punctNormalised`.
  3. Known-hallucination segments dropped. Whisper trained on YouTube
     subtitles and emits their boilerplate over music and silence:
     rms06-01 opens with 「请不吝点赞 订阅 转发 打赏支持明镜与点点栏目」
     TWICE and closes with it once. That is a donation solicitation for a
     news channel inside a sermon; it is provably not the preacher and it
     is not a judgement call. A segment is dropped only when the WHOLE
     segment matches one of the patterns below — never a substring inside
     real speech. Every drop is recorded verbatim in the sidecar's
     `removedHallucinations` and printed by `transcribe_qa.py`, and the
     untouched decode stays in `transcripts/raw/`.
  4. Segments grouped into paragraphs. The decoder emits ~500 segments of
     ~11 characters for a 29-minute sermon, back to back with no silence
     between them (measured: the inter-segment gap is 0.00 s at every
     quantile), so there is no acoustic paragraph boundary to find.
     Grouping is by length, breaking at a sentence stop when one is in
     reach and at a hard cap when one is not. The note in the body says
     the paragraphs are machine-made, because they are.

  REFUSED: inventing punctuation. Segments inside a paragraph are joined
  with a SPACE, not a comma. A space says "the transcriber heard a
  boundary here and did not decide what kind"; a comma would be a
  confident guess at ~500 places per sermon that nobody could later tell
  from the preacher's own.

  A repetition loop is NOT removed. rms07-02 emits 「全片以Google Pixel 4
  拍摄」 fourteen times over 28 seconds at 26:22 — a phone advertisement,
  as obviously not the preacher as the donation line is. It stays,
  because unlike the boilerplate it is also the MARKER that 28 seconds of
  audio produced nothing: delete it and the reader sees a clean transcript
  over a hole. `transcribe_qa.py` reports it under `loop`, twice.

  REFUSED: repairing the tape change on the two-part records (ws01,
  ws04). Each part is decoded separately — concatenating the audio would
  put a splice inside a decode window — and a half-sentence at the seam
  is left as a half-sentence behind a visible note.

6012 IS TRANSCRIBED BUT ITS `hasBody` IS NOT FLIPPED
-----------------------------------------------------
`--set-has-body` closes the seam on 15 of the 16 and holds 6012 (ws01,
活着就是基督) back. The body is written; only the flip is withheld.

The reason is what the body made checkable. `refs.json` tiered 6012/CP37
`confirmed` on an exact title alone and then refuted it "AS A PAIR OF
TEXTS" because there was no library body to compare. There is one now,
and the two texts run the SAME ARGUMENT IN THE SAME ORDER: 2 Corinthians
12:11, 「无」 appearing twice in it, Galatians 6:3, 1 Corinthians 13:2,
"only love makes you something", then back to Philippians 1:21. Measured
by `transcribe_sample_check.py --compare 6012 CP37`, the pair scores a
6-gram Jaccard of 0.0179 — ABOVE the 0.0142 of 6014/396, a pair refs.json
grades `confirmed` — against 0.0014 for both controls. They are the same
sermon: CP37 is the English camp recording, ws01 the Chinese radio
broadcast of it, hymn and studio host included.

`merge_sermon_library.py` reads `confirmed` out of refs.json, and 6012's
row there says `refuted`. So flipping `hasBody` would send 6012 down the
NEW-sermon path and ship 活着就是基督 twice, at 415. Changing that row is
refs.json's owner's call and not this script's: the choice between CP37's
Chinese (a machine translation of the English) and ws01's (a machine
transcript of a different, Chinese delivery) is a judgement about which
sermon the corpus should carry, not a mechanical one.

    python3 scripts/transcribe_sermons.py --set-has-body --hold ""

flips all 16, and should only be run once that row says so.

Usage
-----
    python3 scripts/transcribe_sermons.py                 # all 16, resumable
    python3 scripts/transcribe_sermons.py --only rms06-01
    python3 scripts/transcribe_sermons.py --set-has-body  # close the seam
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))

from transcribe_targets import (  # noqa: E402
    BODIES_DIR, INDEX_JSON, RAW_DIR, TRANSCRIPTS,
    audio_path, load_index, targets,
)
import proofread_transcripts as PROOFREAD  # noqa: E402

WHISPER_CLI = shutil.which("whisper-cli") or "whisper-cli"
FFMPEG = shutil.which("ffmpeg") or "ffmpeg"
FFPROBE = shutil.which("ffprobe") or "ffprobe"
OPENCC = shutil.which("opencc") or "opencc"
MODEL = Path("/Users/pliu0036/Documents/whisper-models/ggml-large-v3.bin")

WHISPER_FLAGS = ["-l", "zh", "-bs", "5", "-bo", "5", "-mc", "0"]
MODEL_NAME = "ggml-large-v3"
TOOL_NAME = "whisper.cpp/whisper-cli (ggml 0.11.1, Metal)"
OPENCC_CONFIG = "t2s"

# ── paragraph grouping ───────────────────────────────────────────────
# Close a paragraph at the first sentence stop past SOFT, or at HARD if
# no stop arrives. HARD keeps an unpunctuated stretch from becoming a
# screen-filling block.
PARA_SOFT_CHARS = 180
PARA_HARD_CHARS = 420
SENT_STOP = "。！？"

# ── punctuation normalisation (typography only) ──────────────────────
PUNCT_MAP = {
    ",": "，", "?": "？", "!": "！", ";": "；", ":": "：",
    "﹐": "，", "﹑": "、", "﹒": "。", "︐": "，", "︒": "。",
}

# ── known Whisper subtitle-boilerplate hallucinations ────────────────
# NARROW ON PURPOSE. Only a segment that matches one of these IN FULL is
# dropped, and every pattern spells the whole boilerplate string out —
# none of them is `.*X.*`.
#
# The first draft of this list WAS `.*打赏支持.*`, and the test that asks
# whether real speech survives it went red immediately:
# 「保罗说我们不是打赏支持神的国度而是把自己献上」 matched, and a rule that
# deletes whole segments would have deleted a sentence of preaching with
# no trace anywhere. A removal rule has to be narrower than the thing it
# is looking for, because the cost of a miss is a visible line of junk
# and the cost of a false positive is silence.
#
# Finding boilerplate this list does NOT know is `transcribe_qa.py`'s job,
# and its net is deliberately much wider — it flags, it does not delete.
HALLUCINATION_PATTERNS = [
    # observed in this corpus (rms06-01, head x2 and tail x1)
    r"请不吝点赞[\s、，,]*订阅[\s、，,]*转发[\s、，,]*打赏支持明镜与点点栏目[。！]?",
    r"字幕(由|制作)[^。！？]{0,16}提供[。！]?",
    r"(由\s*)?[Aa]mara\.org\s*社(区|群)提供的字幕[。！]?",
    # observed in CM03, 4 times: 「优优独播剧场——YoYo Television Series
    # Exclusive」. The tail is 33 characters, so a {0,12} bound written
    # from the Chinese half alone did not match it — measured, not guessed.
    r"优优独播剧场[^。！？]{0,40}",
    r"YoYo Television[^。！？]{0,30}",
]
_HALL_RE = re.compile(r"^(?:" + "|".join(HALLUCINATION_PATTERNS) + r")$")

NOTE_MACHINE = (
    "[注：本篇为机器转录，未经人工校对。转录工具 whisper.cpp {model}，"
    "转录日期 {date}。段落切分与句读为机器所加，非讲员本人的分段；"
    "句读未定之处以空格标示，并非讲员的停顿。"
    "经文引用、人名与地名可能有误，一律以录音为准。]"
)
NOTE_SEAM = (
    "[注：录音分为 {n} 段，此处为第 {i} 段与第 {j} 段的接合点。"
    "换段处可能有重叠或缺漏，未作删改，亦未接合断句。]"
)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def duration_sec(path: Path) -> float:
    out = subprocess.run(
        [FFPROBE, "-v", "error", "-show_entries", "format=duration",
         "-of", "csv=p=0", str(path)],
        capture_output=True, text=True, check=True).stdout.strip()
    return float(out)


def to_wav(src: Path, dest: Path) -> None:
    subprocess.run([FFMPEG, "-v", "error", "-y", "-i", str(src),
                    "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le",
                    str(dest)], check=True)


def opencc_t2s(text: str) -> str:
    return subprocess.run([OPENCC, "-c", f"{OPENCC_CONFIG}.json"],
                          input=text, capture_output=True, text=True,
                          check=True).stdout


def normalise_punct(text: str) -> tuple[str, int]:
    out, moved = [], 0
    for ch in text:
        rep = PUNCT_MAP.get(ch)
        if rep is None:
            out.append(ch)
        else:
            out.append(rep)
            moved += 1
    return "".join(out), moved


def is_hallucination(text: str) -> bool:
    return bool(_HALL_RE.match(re.sub(r"\s+", " ", text).strip()))


def decode(mp3: Path, stem: str, force: bool = False) -> dict:
    """Decode one mp3 with whisper-cli. Cached in transcripts/raw/<stem>.json.

    The cache holds the UNTOUCHED decoder output. Every edit happens
    downstream of it, so changing an edit rule costs a re-run of
    `postprocess` rather than two more minutes of GPU, and the original is
    always there to diff against.
    """
    raw_json = RAW_DIR / f"{stem}.json"
    if raw_json.exists() and not force:
        d = json.loads(raw_json.read_text(encoding="utf-8"))
        d["cached"] = True
        return d

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "audio.wav"
        to_wav(mp3, wav)
        of = Path(td) / "out"
        t0 = time.time()
        proc = subprocess.run(
            [WHISPER_CLI, "-m", str(MODEL), "-f", str(wav), *WHISPER_FLAGS,
             "-np", "-oj", "-of", str(of)],
            capture_output=True, text=True)
        elapsed = time.time() - t0
        if proc.returncode != 0:
            raise RuntimeError(f"whisper-cli failed on {mp3.name}: "
                               f"{proc.stderr[-800:]}")
        # whisper.cpp can emit bytes that are not valid UTF-8 when a
        # multibyte character straddles a token boundary (seen with -ojf).
        # Decode defensively rather than lose a two-minute run to it.
        wj = json.loads(of.with_suffix(".json").read_bytes()
                        .decode("utf-8", errors="replace"))

    d = {
        "audioFile": mp3.name,
        "audioSha256": sha256(mp3),
        "durationSec": round(duration_sec(mp3), 2),
        "wallClockSec": round(elapsed, 1),
        "whisperFlags": " ".join(WHISPER_FLAGS),
        "model": MODEL_NAME,
        "segments": [{"start": s["offsets"]["from"] / 1000.0,
                      "end": s["offsets"]["to"] / 1000.0,
                      "text": s["text"].strip()}
                     for s in wj.get("transcription", [])],
        "cached": False,
    }
    raw_json.write_text(json.dumps(d, ensure_ascii=False), encoding="utf-8")
    return d


def postprocess(raw_segments: list[dict]) -> tuple[list[dict], dict]:
    """Every edit, in one place, each one counted."""
    joined = "\n".join(s["text"] for s in raw_segments)
    converted = opencc_t2s(joined)
    lines = converted.split("\n")
    if len(lines) != len(raw_segments):
        raise RuntimeError("opencc changed the line count — refusing to "
                           "re-align segments by guessing")
    moved_t2s = sum(1 for a, b in zip(joined, converted) if a != b)

    segs, removed = [], []
    moved_punct = 0
    for src, text in zip(raw_segments, lines):
        text, m = normalise_punct(text.strip())
        moved_punct += m
        if is_hallucination(text):
            removed.append({"start": round(src["start"], 2),
                            "end": round(src["end"], 2), "text": text})
            continue
        if not text:
            continue
        segs.append({"start": round(src["start"], 2),
                     "end": round(src["end"], 2), "text": text})
    return segs, {"openccCharsMoved": moved_t2s,
                  "punctNormalised": moved_punct,
                  "removed": removed}


def paragraphs(segs: list[dict]) -> list[str]:
    """Group segments into paragraph lines. Joined with a space, never a comma."""
    return [text for _, text in timed_paragraphs(segs)]


def timed_paragraphs(segs: list[dict]) -> list[tuple[float, str]]:
    """The same grouping, carrying each paragraph's start time.

    The time is for the READING COPY only. A proofreader working from the
    audio needs to know where in the recording a paragraph starts, and
    that is the single most useful thing this pass can hand them; it must
    not reach the body, which ships.
    """
    out, buf, t0 = [], [], 0.0
    for s in segs:
        if not buf:
            t0 = s.get("start") or 0.0
        buf.append(s["text"])
        n = sum(len(t) for t in buf) + len(buf) - 1
        ends_sentence = s["text"][-1:] in SENT_STOP
        if (n >= PARA_SOFT_CHARS and ends_sentence) or n >= PARA_HARD_CHARS:
            out.append((t0, " ".join(buf)))
            buf = []
    if buf:
        out.append((t0, " ".join(buf)))
    return out


def hhmmss(sec: float) -> str:
    sec = int(sec)
    return f"{sec // 3600:d}:{sec % 3600 // 60:02d}:{sec % 60:02d}"


def build(rec: dict, parts: list[dict], today: str) -> tuple[str, str, dict]:
    """Returns (seam body for bodies/<id>.txt, reading copy, sidecar)."""
    note = NOTE_MACHINE.format(model=MODEL_NAME, date=today)
    lines = [rec["title"], note]
    read_lines, offset = [], 0.0
    for i, p in enumerate(parts):
        if i:
            lines.append(NOTE_SEAM.format(n=len(parts), i=i, j=i + 1))
            read_lines.append(NOTE_SEAM.format(n=len(parts), i=i, j=i + 1))
        for t0, text in timed_paragraphs(p["segments"]):
            lines.append(text)
            read_lines.append(f"[{hhmmss(t0 + offset)}] {text}")
        offset += p["durationSec"]

    # `library_body_to_app_body` refuses a blank line inside a body and maps
    # every remaining single newline to a paragraph break. Assert the shape
    # here rather than discovering it inside the merge.
    if not all(ln.strip() for ln in lines):
        raise RuntimeError(f"{rec['refcode']}: blank paragraph line")
    body = "\n".join(lines) + "\n"

    # Proofreading is applied HERE rather than to the file on disk, because
    # a body on disk is untracked and this function is the only thing that
    # writes one. Before 2026-09-06 the corrections lived only in those
    # untracked files and a `--force` rebuild discarded them silently, in 12
    # of 16 bodies. `apply` raises if a fix does not match its stated count.
    body, n_fixed = PROOFREAD.apply(str(rec["id"]), body)

    all_segments, offset = [], 0.0
    for p in parts:
        for s in p["segments"]:
            all_segments.append({"start": round(s["start"] + offset, 2),
                                 "end": round(s["end"] + offset, 2),
                                 "text": s["text"]})
        offset += p["durationSec"]
    full_text = "\n".join(s["text"] for s in all_segments)

    wall = sum(p["wallClockSec"] for p in parts)
    dur = sum(p["durationSec"] for p in parts)
    side = {
        "id": str(rec["id"]),
        "refcode": rec["refcode"],
        "title": rec["title"],
        "author": rec["author"],
        "sourceUrl": rec["url"],
        "language": "zh",
        "script": "Hans",
        "durationSec": round(dur, 2),
        "bodyFile": f"bodies/{rec['id']}.txt",
        # `sync_sermon_library.py` writes `len(body)` with the trailing
        # newline stripped, and `test_sermon_library.py` asserts the index
        # sum equals the sum of the files. Counting non-space characters
        # instead — which is what this did first — leaves the two 9 682
        # characters apart, because these bodies join segments with spaces.
        "bodyChars": len(body.rstrip("\n")),
        "transcription": {
            "kind": "machine",
            "notHuman": True,
            "tool": TOOL_NAME,
            "model": MODEL_NAME,
            "params": " ".join(WHISPER_FLAGS),
            "vad": False,
            "initialPrompt": None,
            "scriptConversion": f"opencc {OPENCC_CONFIG}",
            "transcribedAt": today,
            # NOT "human". The corrections in `proofread_transcripts.py`
            # were made by an agent reading the text against the bundled
            # 和合本 — machine output checked by a machine. The owner's
            # ruling is that a human transcription beats a machine one, so
            # nothing here may be able to pass for a human's work.
            "proofread": "assisted" if n_fixed else "none",
            "proofreadBy": ("agent (not a human), scripts/"
                            "proofread_transcripts.py") if n_fixed else None,
            "proofreadAt": today if n_fixed else None,
            "proofreadFixes": n_fixed,
            "wallClockSec": round(wall, 1),
            "realtimeFactor": round(dur / max(wall, 1e-9), 1),
            "sourceAudio": [{"file": p["audioFile"],
                             "sha256": p["audioSha256"],
                             "durationSec": p["durationSec"],
                             "wallClockSec": p["wallClockSec"]}
                            for p in parts],
            "seamCount": len(parts) - 1,
            "edits": {
                "openccCharsMoved": sum(p["edits"]["openccCharsMoved"]
                                        for p in parts),
                "punctNormalised": sum(p["edits"]["punctNormalised"]
                                       for p in parts),
                "removedHallucinations": [r for p in parts
                                          for r in p["edits"]["removed"]],
                "paragraphRule": f"soft {PARA_SOFT_CHARS} / hard "
                                 f"{PARA_HARD_CHARS} chars, joined with a "
                                 f"space",
            },
        },
        "text": full_text,
        "segments": all_segments,
    }

    reading = (f"# {rec['title']}\n\n{note}\n\n"
               f"[注：以下每段开头的 [h:mm:ss] 为该段在录音中的起始时间，"
               f"供校对时定位之用；此标记不进入正文。]\n\n"
               + "\n\n".join(read_lines) + "\n")
    return body, reading, side


def set_has_body(sidecars: list[dict], hold: set[str]) -> tuple[int, int]:
    """Close the seam: hasBody / bodyFile / bodyChars, and nothing else.

    Three fields, because those are the three `merge_sermon_library.py`
    reads. Provenance is deliberately NOT written here — see the header:
    nothing in this index reaches `assets/sermons/`, so a provenance key
    here would be a mark that vanishes at the seam.
    """
    index = json.loads(INDEX_JSON.read_text(encoding="utf-8"))
    by_id = {s["id"]: s for s in sidecars}
    n = held = 0
    for rec in index["sermons"]:
        sid = str(rec["id"])
        s = by_id.get(sid)
        if not s:
            continue
        if sid in hold:
            held += 1
            continue
        rec["hasBody"] = True
        rec["bodyChars"] = s["bodyChars"]
        rec["bodyFile"] = s["bodyFile"]
        n += 1
    INDEX_JSON.write_text(json.dumps(index, ensure_ascii=False, indent=1)
                          + "\n", encoding="utf-8")
    return n, held


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=None)
    ap.add_argument("--force", action="store_true",
                    help="re-run postprocessing (keeps the cached decode)")
    ap.add_argument("--force-decode", action="store_true",
                    help="re-run whisper as well")
    ap.add_argument("--set-has-body", action="store_true",
                    help="write hasBody/bodyFile/bodyChars into index.json")
    ap.add_argument("--hold", default="6012",
                    help="ids to transcribe but NOT flip. Default 6012 — "
                         "see the module header.")
    args = ap.parse_args()

    if not MODEL.exists():
        print(f"model missing: {MODEL}", file=sys.stderr)
        return 1

    recs = targets(load_index())
    if args.only:
        want = {s.strip() for s in args.only.split(",")}
        recs = [r for r in recs if r["refcode"] in want or str(r["id"]) in want]
    if not recs:
        print("no targets", file=sys.stderr)
        return 1

    TRANSCRIPTS.mkdir(parents=True, exist_ok=True)
    BODIES_DIR.mkdir(parents=True, exist_ok=True)
    today = datetime.date.today().isoformat()
    manifest = []
    t_start = time.time()

    for n, rec in enumerate(recs, 1):
        sid = str(rec["id"])
        side_path = TRANSCRIPTS / f"{sid}.json"
        if side_path.exists() and not (args.force or args.force_decode):
            print(f"[{n}/{len(recs)}] {rec['refcode']}: cached")
            manifest.append(json.loads(side_path.read_text(encoding="utf-8")))
            continue

        parts = []
        for i in range(len(rec["audioUrls"])):
            mp3 = audio_path(rec, i)
            if not mp3.exists():
                print(f"  missing audio {mp3.name} — run "
                      f"transcribe_fetch_audio.py first", file=sys.stderr)
                return 1
            print(f"[{n}/{len(recs)}] {rec['refcode']} part {i + 1}"
                  f"/{len(rec['audioUrls'])}: {mp3.name} "
                  f"({duration_sec(mp3) / 60:.1f} min) …", flush=True)
            d = decode(mp3, mp3.stem, force=args.force_decode)
            segs, edits = postprocess(d["segments"])
            parts.append({**d, "segments": segs, "edits": edits})

        body, reading, side = build(rec, parts, today)
        (BODIES_DIR / f"{sid}.txt").write_text(body, encoding="utf-8")
        (TRANSCRIPTS / f"{sid}.txt").write_text(reading, encoding="utf-8")
        side_path.write_text(json.dumps(side, ensure_ascii=False, indent=1),
                             encoding="utf-8")
        manifest.append(side)
        t = side["transcription"]
        drops = t["edits"]["removedHallucinations"]
        print(f"      {len(side['text']):,} chars, {t['wallClockSec']:.0f}s "
              f"wall for {side['durationSec'] / 60:.1f} min audio "
              f"({t['realtimeFactor']:.1f}x realtime)"
              + (f", dropped {len(drops)} boilerplate segment(s)"
                 if drops else ""))

    (TRANSCRIPTS / "index.json").write_text(json.dumps({
        "_meta": {
            "generatedAt": datetime.datetime.now(datetime.timezone.utc)
                           .strftime("%Y-%m-%dT%H:%M:%SZ"),
            "generator": "scripts/transcribe_sermons.py v2",
            "count": len(manifest),
            "transcription": "machine",
            "warning": "EVERY row here is MACHINE output, unproofread. A "
                       "human transcription always beats one of these. Do "
                       "not merge any of this into a human-transcribed "
                       "body, and do not present it as human text.",
        },
        "sermons": [{k: v for k, v in s.items()
                     if k not in ("text", "segments")} for s in manifest],
    }, ensure_ascii=False, indent=1), encoding="utf-8")

    if args.set_has_body:
        hold = {x.strip() for x in args.hold.split(",") if x.strip()}
        n, held = set_has_body(manifest, hold)
        print(f"\nindex.json: hasBody/bodyFile/bodyChars set on {n} records"
              + (f"; HELD BACK {held}: {sorted(hold)}" if held else ""))

    print(f"\n{len(manifest)} transcripts, bodies in "
          f"{BODIES_DIR.relative_to(REPO)}, sidecars in "
          f"{TRANSCRIPTS.relative_to(REPO)}, {time.time() - t_start:.0f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
