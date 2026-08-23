#!/usr/bin/env python3
"""Does the printed-1919 witness address the same verses we do?

The Wikisource transcription of the printed 1919 和合本 is the witness this
repo reaches for when the two digital witnesses agree with each other and that
is not enough — 創 39:22 and 41:30 taught us that two witnesses sharing an
ancestor can agree and both be late. Verses have been repaired, and proposed
repairs refused, on the strength of "the print reads …". Nothing had ever
checked that its verse ids point at the same verses ours do.

**They do, in 31,059 of 31,102, and every one of the 43 exceptions is
enumerated below.** Three are places the transcription divides verses
differently from every other edition in this repo — 歷代志上 22, 馬可福音 9,
and 約翰福音 7:53 — and in all three OUR division is the standard one, so this
file exists mainly so that nobody reading the print later "corrects" our
numbering to match a page that is wrong. (約翰三書 1:15 looks like a fourth
and is not: there the print agrees with NASB and LEB against KJV, which is a
real versification variant rather than a defect of the page.)

Check 1 is structural: do both editions number the same ids, and merge the
same ids? Check 2 is content: for ids live on both sides, is it the same
verse? Check 3 settles a queue item — "37 printed notes are missing from our
text entirely" — which is false; none is missing.

**Read the loader before trusting any of it.** `audit_note_placement.py`
anchors its verse pattern at the start of a line, which is right for the
31,032 verses that begin one. But the print writes a merged pair as
`{{verse|1|20}} {{verse|1|21}}以色列的長子…` — two markers over one block —
and the second of each pair is mid-line. There are exactly 70 such markers,
which is exactly the size of our 「見上節」 class, so a line-anchored read
loses precisely the verses check 1 is about and makes the print look SILENT
where it in fact agrees with us verse for verse. Counting every marker gives
31,102, our verse count exactly. That correction came from a refuter sent to
break an earlier version of this file, which had reported the parser artifact
as a finding about the print.

The print cache lives in /tmp/wscuv; delete it to re-fetch. It needs the
network on a cold cache, so this is a tool and not a test; the
offline-checkable half is pinned by test/print_witness_alignment_test.dart.
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audit_note_placement as base  # noqa: E402

CJK = re.compile(r"[一-鿿㐀-䶿]")
STUB = "見上節"
VERSE_MARK = re.compile(r"\{\{verse\|(\d+)\|(\d+)\}\}")
# A continuation line is scripture only if it carries no wiki or HTML syntax
# at all — the page footer after 約伯記 42:17 starts `}}<div…` and would
# otherwise be appended to the last verse of the book.
CONTROL = re.compile(r"[=*#|{}\[\]<>]")
MERGED = "〔merged into the verse above〕"

# ── the 37 exceptions, each read individually ────────────────────────────────

# An id one edition numbers and the other does not.
ID_ONLY = {
    "013021031": "print only — the page ends 歷代志上 21 a verse late; this is "
                 "our 22:1 「大衛說：這就是雅偉神的殿」.",
    "013022019": "ours only — the far end of the same shift.",
    "064001015": "print only — 約翰三書 1:15. Our 1:14 carries the sentence "
                 "behind a 「15節」 note. Queued for the user; NASB and LEB in "
                 "this repo number it and KJV does not.",
    "043007053": "ours only — 約翰福音 7:53, which we number and stub with "
                 "「見下節」; the print folds it into 8:1 and numbers nothing.",
}

# A verse one edition merges into the one above and the other sets on its own.
MERGE_ONLY = {
    "019063006": "print merges 詩篇 63:6; we agree it is merged and say so in "
                 "different words — 「合和譯本並入上一節」 rather than "
                 "「見上節」. Notation, not division.",
    "042021030": "HELD FOR THE USER. The print numbers 路加福音 21:30 and gives "
                 "it text (「他發芽的時候…夏天近了。」); we merge it into 21:29 "
                 "and stub 21:30. It is the ONLY one of our 70 merges the "
                 "print does not also make. Splitting it is a versification "
                 "change — every id, highlight and note anchored to 21:29 "
                 "moves — so it is the user's call, like 約翰三書 1:14.",
}

# Live on both sides, but not the same verse. Two signals of different shape:
# set-overlap catches a wholesale shift, length ratio catches a split, and
# 約翰三書 1:14 and 路加福音 21:29 are caught only by the second.
CONTENT = {
    **{f"013022{n:03d}": "歷代志上 22 — the page numbers our 22:1 as 21:31 and "
                         "slides 22:2–19 down to 22:1–18. KJV, LEB and NASB "
                         "here all put 1 Chr 21 at 30 verses and 22:1 at "
                         "「Then David said, This is the house of the LORD "
                         "God」. Nothing may be decided from the print in this "
                         "chapter without applying the offset."
       for n in range(1, 19)},
    "041009043": "馬可福音 9:43 — the page splits our 9:43 and gives its second "
                 "half the number 9:44, which belongs to the bracketed variant "
                 "「在那裏蟲是不死的，火是不滅的」. KJV agrees with us.",
    "041009045": "馬可福音 9:45 — the same split one pair later.",
    "042021029": "路加福音 21:29 — the other half of the merge held above.",
    "044024006": "使徒行傳 24:6 — convention, not division. Our 〔有古卷在此有："
                 "…〕 bracket runs from 24:6 into 24:7; the print sets the same "
                 "words as a note, which this check strips.",
    "064001014": "約翰三書 1:14 — carries verse 15 merged in. See ID_ONLY.",
}

# One edition sets a textual variant as text and the other as apparatus, so
# stripping notes empties one side. Every one is accounted for by check 3.
VARIANT_CONVENTION = {
    "002016036", "040018011", "040023014", "041007016", "041009044",
    "041009046", "041015028", "042017036", "042023017", "043005004",
    "044008037", "044015034", "044024007", "044028029",
}

# 作/是 and 或作/或譯 are this edition's house wording against the print's;
# 乃/卽/就是 introduce the same gloss; 云云 is the print's elision marker —
# 「高舉云云」 stands for text rather than being text. Folded on BOTH sides so
# a four-character note is not scored absent over one particle.
NORM = [("原文作", "原文"), ("原文是", "原文"), ("原文用", "原文"),
        ("或作", "或"), ("或译", "或"), ("就是", ""), ("乃", ""),
        ("卽", ""), ("即", ""), ("做", "作"), ("云云", "")]

COVERAGE = 0.85
OVERLAP = 0.34
RATIO = 1.75


def pure(text):
    out = "".join(CJK.findall(text))
    for a, b in NORM:
        out = out.replace(a, b)
    return out


def bare(text):
    """CJK content with both editions' apparatus stripped."""
    return "".join(
        CJK.findall(base.OUR_NOTE.sub("", base.PRINT_NOTE.sub("", text))))


def lcs(a, b):
    """Longest common subsequence — tolerant of an elision on one side without
    matching unrelated text."""
    prev = [0] * (len(b) + 1)
    for x in a:
        cur = [0] * (len(b) + 1)
        for j, y in enumerate(b, 1):
            cur[j] = prev[j - 1] + 1 if x == y else max(prev[j], cur[j - 1])
        prev = cur
    return prev[-1]


def load():
    ours = {r["id"]: r["text"]
            for r in json.loads(base.OURS.read_text(encoding="utf-8"))}
    printed, last = {}, None
    for n, book in enumerate(base.BOOKS, start=1):
        for line in base.fetch(book).splitlines():
            marks = list(VERSE_MARK.finditer(line))
            if not marks:
                tail = base.unwrap(line).strip()
                if last and tail and not CONTROL.search(tail) \
                        and CJK.search(tail):
                    printed[last] += tail
                continue
            spans = []
            for i, m in enumerate(marks):
                end = marks[i + 1].start() if i + 1 < len(marks) else len(line)
                spans.append(
                    (f"{n:03d}{int(m.group(1)):03d}{int(m.group(2)):03d}",
                     base.unwrap(line[m.end():end]).strip()))
            # Markers with nothing between them share the block that follows.
            # Our edition puts that block on the FIRST id of the run and
            # 「見上節」 on the rest, so key it the same way round.
            i = 0
            while i < len(spans):
                j = i
                while j < len(spans) - 1 and not spans[j][1]:
                    j += 1
                printed[spans[i][0]] = spans[j][1]
                for k in range(i + 1, j + 1):
                    printed[spans[k][0]] = MERGED
                last = spans[i][0]
                i = j + 1
    return ours, printed


def check_structure(ours, printed):
    """Same ids, and the same ids merged?"""
    only = sorted(set(ours) ^ set(printed))
    ours_merged = {v for v, t in ours.items() if t.strip() == STUB}
    print_merged = {v for v, t in printed.items() if t == MERGED}
    merge_diff = sorted(ours_merged ^ print_merged)
    print(f"[1] structure: {len(ours)} ids ours, {len(printed)} print. "
          f"{len(only)} numbered on one side only; "
          f"{len(ours_merged)} merges ours, {len(print_merged)} print, "
          f"{len(merge_diff)} disagreeing")
    for vid in only:
        print(f"      {vid}  {ID_ONLY.get(vid, '!! UNEXPLAINED')}")
    for vid in merge_diff:
        print(f"      {vid}  {MERGE_ONLY.get(vid, '!! UNEXPLAINED')}")
    return ([v for v in only if v not in ID_ONLY]
            + [v for v in merge_diff if v not in MERGE_ONLY])


def check_content(ours, printed):
    """For ids live on both sides, is it the same verse?"""
    live = [v for v in sorted(set(ours) & set(printed))
            if printed[v] != MERGED and ours[v].strip() != STUB]
    fo = dict(zip(live, base.fold([ours[v] for v in live])))
    fp = dict(zip(live, base.fold([printed[v] for v in live])))
    flagged, variant = [], []
    for vid in live:
        a, b = bare(fo[vid]), bare(fp[vid])
        if not a or not b:
            variant.append(vid)
        elif len(set(a) & set(b)) / len(set(a) | set(b)) < OVERLAP:
            flagged.append((vid, "shares too few characters"))
        elif len(a) / len(b) >= RATIO or len(b) / len(a) >= RATIO:
            flagged.append((vid, f"{len(a)} characters against {len(b)}"))
    print(f"[2] content: {len(live)} ids live on both sides. {len(flagged)} "
          f"are not the same verse; {len(variant)} set a textual variant as "
          f"text on one side and as apparatus on the other")
    seen = set()
    for vid, why in flagged:
        why_text = CONTENT.get(vid, "!! UNEXPLAINED")
        if why_text in seen:
            print(f"      {vid}  ({why}) as above")
            continue
        seen.add(why_text)
        print(f"      {vid}  ({why}) {why_text}")
    for vid in sorted(set(variant) - VARIANT_CONVENTION):
        print(f"      {vid}  !! UNEXPLAINED variant-convention difference")
    return ([v for v, _ in flagged if v not in CONTENT]
            + sorted(set(variant) - VARIANT_CONVENTION))


def check_notes(ours, printed):
    """Every printed note our `<note:>` markup does not carry — where is it?

    A queue item read this count as 37 losses. This edition carries most of
    its apparatus as an inline parenthetical instead, which comparing markup
    cannot see: 撒迦利亞書 4:7 was named as one of two pinpointable losses and
    reads 「（殿：或譯石）」 on screen right now.
    """
    shared = sorted(set(ours) & set(printed))
    fo = dict(zip(shared, base.fold([ours[v] for v in shared])))
    fp = dict(zip(shared, base.fold([printed[v] for v in shared])))
    missing, placed = [], {}
    for vid in shared:
        p_notes = base.PRINT_NOTE.findall(fp[vid])
        if len(p_notes) <= len(base.OUR_NOTE.findall(fo[vid])):
            continue
        for note in p_notes:
            want = pure(re.sub(r"<sup>.*?</sup>", "", note))
            if not want:
                continue
            best = (0.0, None)
            for off in (0, 1, -1, 2):
                cid = f"{int(vid) + off:09d}"
                if cid in fo:
                    cov = lcs(want, pure(fo[cid])) / len(want)
                    if cov > best[0]:
                        best = (cov, off)
            if best[0] >= COVERAGE:
                placed[best[1]] = placed.get(best[1], 0) + 1
            else:
                missing.append((vid, note, round(best[0], 2)))
    total = sum(placed.values()) + len(missing)
    print(f"[3] printed notes our <note:> markup does not carry: {total}. "
          f"{placed.get(0, 0)} are inline in the same verse, "
          f"{total - placed.get(0, 0) - len(missing)} in an adjacent verse, "
          f"{len(missing)} NOT FOUND")
    for vid, note, cov in missing:
        print(f"   !! {vid} {note!r} best coverage {cov}")
    return [v for v, *_ in missing]


def main():
    ours, printed = load()
    fails = check_structure(ours, printed)
    fails += check_content(ours, printed)
    fails += check_notes(ours, printed)
    if fails:
        print(f"\n{len(fails)} findings this file does not explain. Read each "
              f"against the print before writing anything.")
        return 1
    print("\nclean — outside the recorded exceptions the print addresses the "
          "same verses we do, and no printed note is unaccounted for")
    return 0


if __name__ == "__main__":
    sys.exit(main())
