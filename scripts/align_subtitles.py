#!/usr/bin/env python3
"""Give the church's own words the video's timings.

The problem this solves: 獨一真神 ships as three recordings with a
transcript that has **no timings of any kind** — 15,729 characters and
the only time-shaped strings in it are scripture references like
"John 5:44". So subtitles need timings from somewhere.

The wrong answer is to subtitle with speech recognition. This is a
teaching about who God is; an ASR slip does not read as a glitch, it
reads as the church saying something it did not say. The app already
carries a scar from this — EC018/EC019 are raw ASR and the queue's note
on them is "never re-punctuate a preacher's words".

So: **Whisper supplies the timings, the church supplies the words.**
Whisper's transcript is used only as a ruler to measure against and is
then thrown away. Measured on episode 01, the two agree on 94.2% of the
church's characters across 114 anchor blocks of six characters or more,
which is dense enough that the gaps between anchors interpolate to
within a word.

Comparison is done on Simplified, CJK only — the church's document is
Traditional and Whisper emits Simplified, so without `t2s` the two
texts disagree on almost every line for a reason that has nothing to do
with what was said.

Usage:
    align_subtitles.py --asr subs/cmn.json --docx <script>.docx \\
                       --out assets/subtitles/01/cmn
"""

import argparse
import difflib
import html
import json
import pathlib
import re
import zipfile

try:
    from opencc import OpenCC
except ImportError:  # pragma: no cover - tooling, not app code
    raise SystemExit('opencc-python-reimplemented is required '
                     '(pip install opencc-python-reimplemented)')

_T2S = OpenCC('t2s')
_S2T = OpenCC('s2t')

CJK = re.compile(r'[一-鿿]')

# A cue longer than this is hard to read before it is replaced; a
# paragraph longer than this gets split on sentence punctuation.
MAX_CUE_CHARS = 42

# Below this a cue is on screen and gone before it can be read. Cues are
# stretched toward it whenever the next one leaves room.
MIN_CUE_SECONDS = 1.4

# Shorter than this and a cue cannot be read at all, so it is merged
# into its neighbour rather than shown or dropped.
MERGE_BELOW_SECONDS = 0.5


def read_docx(path):
    """Paragraph texts, in order, from a .docx."""
    xml = zipfile.ZipFile(path).read('word/document.xml').decode(
        'utf-8', 'replace')
    out = []
    for p in re.findall(r'<w:p[ >].*?</w:p>', xml, re.S):
        t = ''.join(re.findall(r'<w:t[^>]*>(.*?)</w:t>', p, re.S))
        t = html.unescape(re.sub(r'<[^>]+>', '', t)).strip()
        if t:
            out.append(t)
    return out


def split_scripts(paras):
    """Separate the two scripts this document actually contains.

    The file is named `..._Chinese.docx`, which is misleading: it holds
    the Chinese script AND the full English one, back to back. Episode
    01 is 162 Chinese paragraphs (3,168 characters) then 159 English
    ones (2,131 words), both ending on the same closing line — 「下星期
    見。」 and "See you next week."

    That matters twice over. Aligning the whole file against a Chinese
    recording drags 159 paragraphs of English through the matcher with
    nothing to anchor them, which is what first produced cues crushed
    into half a second each at the tail. And it means English subtitles
    need nothing further from the church — the script was already here.

    The boundary is found from the data, not hard-coded: the English
    half is the trailing run with no CJK at all.
    """
    last_cjk = -1
    for i, p in enumerate(paras):
        if CJK.search(p):
            last_cjk = i
    if last_cjk < 0 or last_cjk == len(paras) - 1:
        return _drop_heading(paras), []      # single-language document
    return (_drop_heading(paras[:last_cjk + 1]),
            _drop_heading(paras[last_cjk + 1:]))


# A paragraph that is entirely parenthetical is a note to whoever cut
# the video — "(Back to the slide of the Greek the only true God)" —
# not a line anyone speaks. Subtitling it would put words in the
# speaker's mouth, the same failure as printing an editor's manuscript
# note as scripture.
STAGE_DIRECTION = re.compile(r'^\s*[（(\[].{0,120}[）)\]]\s*$')


def _drop_heading(paras):
    """Remove the episode-number heading each script opens with.

    `01 Who is the only true God?` is a title on the page, not a line
    anyone says. Left in, it aligns to position zero and squeezes the
    first real sentence into a cue too short to read — episode 01 gave
    "Today's topic is…" 0.33 seconds. Removing it is not cosmetic: a
    heading shown as a subtitle claims the speaker said it.
    """
    out = [p for p in paras if not STAGE_DIRECTION.match(p)]
    while out and re.match(r'^\s*\d{1,3}[\s.\-–—]', out[0]):
        out.pop(0)
    return out


def split_long(para):
    """Break an over-long paragraph on sentence punctuation.

    Splits only where the writer already ended a thought, so a cue never
    cuts mid-clause. A run with no punctuation at all is left whole
    rather than chopped at an arbitrary character — a truncated sentence
    on screen is worse than one that lingers.
    """
    if len(para) <= MAX_CUE_CHARS:
        return [para]
    parts, buf = [], ''
    for ch in para:
        buf += ch
        if ch in '。！？；!?;' and len(buf) >= 12:
            parts.append(buf.strip())
            buf = ''
    if buf.strip():
        parts.append(buf.strip())
    return parts or [para]


def char_time_index(segments):
    """Per-character timestamps over the concatenated ASR text.

    Whisper times whole segments, so a character's time is interpolated
    linearly inside its segment. That is an approximation, but at ~3s a
    segment the error is well under the time a cue is on screen.
    """
    times, text = [], []
    for s in segments:
        raw = s['text']
        keep = [c for c in raw if CJK.match(c) or c.isalnum()]
        if not keep:
            continue
        start, end = float(s['start']), float(s['end'])
        span = max(end - start, 0.001)
        for i, c in enumerate(keep):
            text.append(c)
            times.append(start + span * (i / max(len(keep), 1)))
    return ''.join(text), times


def align(church_paras, segments):
    """Map each church paragraph to a (start, end) in the video."""
    asr_text, asr_times = char_time_index(segments)

    # Normalise both sides the same way, and remember where each
    # normalised character came from so paragraph boundaries survive.
    norm, owner = [], []
    for idx, para in enumerate(church_paras):
        for c in _T2S.convert(para):
            if CJK.match(c) or c.isalnum():
                norm.append(c)
                owner.append(idx)
    norm = ''.join(norm)

    sm = difflib.SequenceMatcher(None, norm, asr_text, autojunk=False)
    # church-char index -> asr-char index, for matched runs only.
    anchor = {}
    for bl in sm.get_matching_blocks():
        for k in range(bl.size):
            anchor[bl.a + k] = bl.b + k

    if not anchor:
        raise SystemExit('no alignment at all — wrong script for this video?')

    keys = sorted(anchor)

    def asr_index_for(i):
        """Nearest anchored position, interpolating between anchors."""
        if i in anchor:
            return anchor[i]
        lo = None
        for k in keys:
            if k <= i:
                lo = k
            else:
                hi = k
                break
        else:
            hi = None
        if lo is None:
            return anchor[keys[0]]
        if hi is None:
            return anchor[keys[-1]]
        # Linear between the two surrounding anchors.
        span = hi - lo
        frac = (i - lo) / span if span else 0
        return int(anchor[lo] + (anchor[hi] - anchor[lo]) * frac)

    def time_at(i):
        j = asr_index_for(i)
        j = max(0, min(j, len(asr_times) - 1))
        return asr_times[j]

    # First and last normalised character of each paragraph.
    bounds = {}
    for i, o in enumerate(owner):
        b = bounds.setdefault(o, [i, i])
        b[1] = i

    cues = []
    for idx, para in enumerate(church_paras):
        if idx not in bounds:
            continue          # e.g. a heading with no alignable characters
        lo, hi = bounds[idx]
        start, end = time_at(lo), time_at(hi)
        if end <= start:
            end = start + 1.5
        pieces = split_long(para)
        span = (end - start) / len(pieces)
        for n, piece in enumerate(pieces):
            cues.append((start + span * n, start + span * (n + 1), piece))

    # Reflow into cues a person can actually read.
    #
    # Three things go wrong if this is naive, and all three were seen in
    # the first version of this file:
    #
    #   • Two paragraphs can align to the SAME character position — the
    #     document's title line and the first spoken sentence both land
    #     at 0.000 — which yields a zero-length or inverted cue.
    #   • Resolving overlap by pushing the later cue forward compounds:
    #     episode 01's last line landed at 21.1 minutes on an
    #     18.6-minute video, invisible at the top of the file and
    #     glaring at the end.
    #   • A cue can come out 0.4s long, which is on screen and gone
    #     before it can be read.
    #
    # So: starts are anchored to measured audio and only ever move to
    # break a tie; ends are the negotiable part, clamped to the next
    # start and stretched toward MIN_CUE_SECONDS where there is room.
    cues.sort(key=lambda c: (c[0], c[1]))

    starts = []
    for s_, _e, _t in cues:
        if starts and s_ <= starts[-1]:
            s_ = starts[-1] + 0.05      # bounded: a tie, not a cascade
        starts.append(s_)

    end_of_video = float(segments[-1]['end']) if segments else None
    out = []
    for i, (_s, e, txt) in enumerate(cues):
        s_ = starts[i]
        limit = starts[i + 1] if i + 1 < len(starts) else (
            end_of_video if end_of_video else s_ + MIN_CUE_SECONDS)
        e = min(max(e, s_ + MIN_CUE_SECONDS), limit)
        if e <= s_:
            e = min(s_ + 0.4, limit)
        if end_of_video is not None:
            if s_ >= end_of_video:
                continue            # nothing may outlive the recording
            e = min(e, end_of_video)
        out.append((s_, e, txt))

    # Merge anything still too short to read into the cue after it. The
    # words are kept — dropping a line of the teaching to satisfy a
    # timing rule would be the wrong trade — but they are shown for long
    # enough to be read. Episode 01 left three of these after the
    # heading fix, at 0.13s, 0.31s and 0.33s.
    merged = []
    carry = None          # a too-short FIRST cue, with nothing behind it
    for s_, e, txt in out:
        if carry is not None:
            cs, _ce, ctxt = carry
            s_, txt, carry = cs, f'{ctxt} {txt}'.strip(), None
        if (e - s_) < MERGE_BELOW_SECONDS:
            if merged:
                ps, _pe, ptxt = merged[-1]
                merged[-1] = (ps, e, f'{ptxt} {txt}'.strip())
            else:
                # Nothing before it — carry it FORWARD into the next cue
                # instead. The Cantonese take opened with a 0.05s cue
                # because two paragraphs aligned to the same instant and
                # the tie-break gave the second one a sliver.
                carry = (s_, e, txt)
            continue
        merged.append((s_, e, txt))
    if carry is not None:
        merged.append(carry)
    return merged


def vtt(cues):
    def ts(t):
        h, rem = divmod(max(t, 0), 3600)
        m, s = divmod(rem, 60)
        return f'{int(h):02d}:{int(m):02d}:{s:06.3f}'
    out = ['WEBVTT', '']
    for s, e, txt in cues:
        out.append(f'{ts(s)} --> {ts(e)}')
        out.append(txt)
        out.append('')
    return '\n'.join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--asr', required=True, help='whisper --output_format json')
    ap.add_argument('--docx', required=True)
    ap.add_argument('--out', required=True, help='output stem, no extension')
    ap.add_argument('--script', choices=('zh', 'en'), default='zh',
                    help='which half of the document this recording speaks')
    args = ap.parse_args()

    zh_paras, en_paras = split_scripts(read_docx(args.docx))
    paras = zh_paras if args.script == 'zh' else en_paras
    if not paras:
        raise SystemExit(f'no {args.script} script in that document')
    segments = json.load(open(args.asr))['segments']
    cues = align(paras, segments)

    stem = pathlib.Path(args.out)
    stem.parent.mkdir(parents=True, exist_ok=True)

    # The document is Traditional; Simplified is generated from it.
    # Traditional -> Simplified is many-to-one and safe. The reverse is
    # ambiguous (one Simplified form maps to several Traditional ones),
    # which is exactly the trap this repo already hit on 梁家鏗譯本 — so
    # the Traditional file is the DOCUMENT's own text, never a
    # round-trip.
    written = []
    if args.script == 'en':
        (stem.with_name(stem.name + '.en.vtt')).write_text(
            vtt(cues), encoding='utf-8')
        written.append('en')
    else:
        (stem.with_name(stem.name + '.zh-Hant.vtt')).write_text(
            vtt(cues), encoding='utf-8')
        (stem.with_name(stem.name + '.zh-Hans.vtt')).write_text(
            vtt([(s, e, _T2S.convert(t)) for s, e, t in cues]),
            encoding='utf-8')
        written += ['zh-Hant', 'zh-Hans']

    total = cues[-1][1] if cues else 0
    print(f'{len(cues)} cues, last ends at {total/60:.1f} min '
          f'-> {stem.name}.{{{",".join(written)}}}.vtt')


if __name__ == '__main__':
    main()
