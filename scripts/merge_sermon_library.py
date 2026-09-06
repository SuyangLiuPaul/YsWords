#!/usr/bin/env python3
r"""Merge Pastor Eric H.H. Chang's records out of the staging library into
the one shipped sermon corpus.

READ THIS BEFORE THE CODE.

`assets/sermon_library/` holds 940 records by 71 preachers fetched from
fuyindiantai.org. It is gitignored, it is not in `pubspec.yaml`, and it ships
NOWHERE. It is a staging area kept on disk so that adding a preacher back
later is a filter change here rather than another crawl of a church's server.

`assets/sermons/` is the one corpus the app ships, and after this merge it
carries Pastor Eric H.H. Chang (张熙和牧师) only. 198 of the library's 940
records are his. 57 of those are confirmed duplicates of a sermon the app
already has; 141 are new.

WHY THE LIBRARY'S TEXT WINS ON A DUPLICATE. The app's Chinese is machine
output end to end. T7's own PROGRESS.md calls Phase 1 a raw Whisper
transcript, the Chinese is a Phase 3/4 machine translation of it, and the
Phase 5 "proofreading" was verified to have done nothing — every
`.zh-proofread.txt` is byte-identical to its `.zh-TW.txt`. The library text
is human. Measured over the 57 pairs, the app body is the SHORTER one in 24
of them, by as much as 10 000 characters (app 126 is 1 152 characters against
the library's 11 535), because those app entries are editorial abstracts
rather than transcripts. The app's machine text also carries errors the human
text does not.

The ENGLISH bodies are not touched by any of this. The library is
Chinese-only; the app's English is the T7 formatted transcript and is the
only English there is.

WHAT THIS SCRIPT REFUSES TO DO, AND WHY EACH REFUSAL EXISTS

  1. It does not replace a body the adjudication could not vouch for.
     `assets/sermon_library/refs.json`'s adjudication block grades every
     confirmed pair with a `completeness`, and only `complete` and
     `library-fuller` say the library body covers the app text's whole
     scope. A wholesale swap on anything else deletes preaching:
       * 3958/079 — the library is the leaven parable only, while app 079 is
         a mustard-seed recap PLUS leaven.
       * 3960/082 — app 082 opens with a recap the library files at the end
         of a different record, 3959.
       * the four `unknown` rows (3972/083, 4082/029, 4103/034, 6014/396)
         have too few shared anchors to establish coverage either way.
     51 of the 57 are replaced. The other six keep the text they shipped
     with, and `HELD_OUT` below names each one and why.

  2. It does not merge a record whose body carries a private-use character
     it cannot resolve. The shipped corpus contains ZERO private-use
     codepoints; the church's typesetting font uses them, and they render as
     an empty box. Three classes appear in Pastor Eric's 182 bodied records:
       * U+F5BD, 3 times, in an unambiguous reverential second-person
         pronoun slot (one of them quoting 馬太福音 26:39, which the CUV
         settles) → 祢, which `opencc -c s2t` writes 禰, which is what the
         289-file corpus already spells it (禰 8, 祢 0).
       * U+F081…U+F090, 11 times in Mt99 and Mt100, each at the START of a
         line and followed by one space: a bullet glyph in front of a
         section heading. The bullet and its space are dropped; not one word
         moves, and the heading keeps its own line.
       * U+E042 in 「權力雜◻一起」 and U+F68F in an onomatopoeia, both in
         ws03. Each stands where a real character was and neither has a
         control. They are NOT guessed — ws03 is held out.
     Anything else refuses rather than shipping a box.

  3. It does not re-punctuate or re-paragraph a preacher. Library bodies are
     paragraph-per-LINE with no blank-line gaps; the app renderer splits on
     BLANK lines (`sermon_detail_page.dart`, `body.split(RegExp(r'\n\s*\n'))`).
     So each single newline becomes a blank line and the paragraph boundaries
     survive EXACTLY — same count, same places. Nothing is merged, split,
     reflowed or re-punctuated. Regenerating three sermons destroyed 103
     correctly-paired 「」 once; that is a recorded defect, not a risk.

  4. It does not invent a date. The library `date` is the WEBSITE
     PUBLICATION date — the 125 new bodied records date 2014-2026, and the
     preacher died in 2013. None of their bodies carries a preaching-date
     header line (measured: 0 of 125; nine library bodies do carry one and
     all nine belong to duplicate pairs whose app record is already dated).
     So every merged record takes the corpus's own undated sentinel,
     `yyyy-mmdd`, which `Sermon.prettyDate` already renders as "—".

WHAT IT WRITES
  assets/sermons/index.json      — 289 existing records, order untouched,
                                   plus 125 appended
  assets/sermons/zh-CN/<id>.txt  — 125 new, 51 replaced
  assets/sermons/zh-TW/<id>.txt  — the same, `opencc -c s2t` plus the five
                                   normalisations to the printed 和合本
  assets/sermons/en/             — NOT TOUCHED

THE WHOLE PIPELINE, AND IT STARTS FROM A CLEAN CORPUS:

  git checkout -- assets/sermons/                           # ← not optional
  python3 scripts/merge_sermon_library.py --apply
  python3 tools/repair_tw_sermon_merged_glyphs.py --apply   # s2t spot errors
  python3 scripts/extract_sermon_refs.py                    # refs.json

Verified byte-for-byte reproducible: two clean runs give an identical
`assets/sermons/`, and the index is rewritten rather than appended to, so a
second `--apply` gives 414 again and not 539.

The `git checkout` is the step to read twice. `--apply` rewrites the 176
bodies from the library source, which un-does the glyph repairs INSIDE those
176 while leaving them applied in the twelve files the repair tool touches
and the merge does not (075, 169, 214, 234, 323, 370, 834, C115, C174, C178,
CP60, c106). That is a half-repaired corpus, and the repair tool refuses one
rather than doing half a job — 「✗ 覆活 → 復活: 12 in the corpus, 17
measured」 is what a skipped checkout looks like, and it is a refusal rather
than a corruption.

THE SEAM FOR THE 16 AUDIO-ONLY RECORDS. 16 of Pastor Eric's 198 have no body
(`hasBody` false) and are another agent's task. They are excluded by exactly
one predicate — `hasBody` — and by nothing else. When a transcript lands in
`assets/sermon_library/bodies/<id>.txt` and `sync_sermon_library.py` sets
`hasBody`, re-running this script merges it with no edit here. `--report`
lists them. One of the 16 needs care and is flagged: library 6012 (ws01,
活着就是基督) has the same title as app CP37 and was tiered confirmed on that
title alone, then refuted AS A PAIR OF TEXTS because there is no library body
to compare. It must not be merged as a new sermon without settling that
first, or the corpus ships one sermon twice.

Run from the repo root:
    python3 scripts/merge_sermon_library.py --report
    python3 scripts/merge_sermon_library.py --apply
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
LIB = REPO / "assets" / "sermon_library"
OUT = REPO / "assets" / "sermons"

PREACHER = "张熙和牧师"

# The library grades every confirmed pair. Only these two gradings say the
# library body covers the app text's whole scope. See the header.
REPLACEABLE = {"complete", "library-fuller"}

# Records excluded by hand, each with the reading that excludes it. A record
# not in this map and not filtered by a rule above is merged.
HELD_OUT: dict[str, str] = {
    "6014": "ws03 carries U+E042 in 「權力雜◻一起」 and U+F68F in an "
            "onomatopoeia; each stands where a real character was and "
            "neither has a control, so neither may be guessed",
}

# The undated sentinel the corpus already uses. `Sermon.prettyDate` renders
# it as "—". 20 of the shipped 289 carry it.
UNDATED = "yyyy-mmdd"

# ── topics ──────────────────────────────────────────────────────────────
# A merged record goes into an EXISTING app topic wherever the adjudicated
# duplicate pairs say which one it belongs to, and into a single new topic
# otherwise. Two constraints shaped this and both are worth writing down.
#
# FIRST: a topic name must be ASCII. `tools/prerender_sermons.dart`'s
# `topicSlug()` strips everything outside `[a-z0-9]` and THROWS
# `StateError('Topic "…" slugs to nothing')` on what is left, so a Chinese
# topic name does not merely look wrong in an English list — it breaks the
# static-site generator. The first draft of this script used the church's own
# taxonomy verbatim (马太福音, 成为新人, 洗礼 …) and `test/prerender_sermons_
# test.dart`'s "no two real topics collide" is what caught it.
#
# SECOND: the church's series do not map one-to-one onto the app's 20 topics,
# and this was measured rather than assumed. Over the 57 confirmed pairs the
# church's `mt` series lands in three different app topics and `sm` in three.
# So the rule below is keyed on the evidence that IS clean, and everything
# else goes into one honest group rather than a guessed one.
#
#   sm01…sm10   → The Beatitudes      10 confirmed pairs, the whole
#                                     contiguous block, no exceptions
#   sm11…sm40   → Sermon on the Mount 10 confirmed (11, 15, 18, 20, 21, 25,
#                                     30, 31, 33, 38) + 4 weaker; the first
#                                     confirmed pair that leaves this topic
#                                     is sm54
#   sm41…       → Matthew and parallels in Luke and Mark
#                                     confirmed 54 and 55, weak 41, 44, 47,
#                                     48, 51
#   Mt..._pbNN  → The Parables of Jesus
#                                     the church's own parable numbering; 7
#                                     of the 9 `_pb` records are confirmed
#                                     pairs and ALL SEVEN land in this topic
#   Mt... else  → Matthew and parallels in Luke and Mark   18 confirmed
#   nm          → Regeneration and Renewal
#                                     the one mapping resting on weak-tier
#                                     rows: 8 of them, unanimous, and the
#                                     church's series name 成为新人 is the
#                                     app label 重生与更新 in other words
#   bp          → Baptism             the app topic's zh-Hans label is
#                                     character-for-character the church's
#                                     series name 洗礼; 2 weak pairs agree
#   trc         → Survey of 2 Timothy 1 confirmed + 3 weak; the app topic's
#                                     zh-Hans label is 提摩太后书概览 and
#                                     the church files these under 提摩太后书
#   lq          → Life Quality        1 confirmed pair
#
# Everything else — im 4, topm 8, mono 2, cm 2, bg 1, est 1, ws 1 — has
# either no adjudicated pair or pairs that disagree, so all 19 go here. The
# name states what they are and claims nothing else.
TOPIC_FALLBACK = "FYDT Chinese Messages"

_SM = "Sermon on the Mount"
_MT = "Matthew and parallels in Luke and Mark"
_SERIES_TOPIC = {
    "nm": "Regeneration and Renewal",
    "bp": "Baptism",
    "trc": "Survey of 2 Timothy",
    "lq": "Life Quality",
}

# ── the five normalisations to the printed 和合本 ────────────────────────
# `assets/cuvs-yhwh-tr.json` is unanimous on all five: 為 7952:0, 裏 4787:0,
# 著 2651:0, 才 240:0, 啟 425:0. See `test/tw_sermon_orthography_test.dart`.
S2T_NORMALISE = (("爲", "為"), ("裡", "裏"), ("着", "著"), ("纔", "才"),
                 ("啓", "啟"))

# ── private-use codepoints ──────────────────────────────────────────────
PUA_PRONOUN = ""          # → 祢, s2t writes 禰
HEADING_BULLETS = "".join(chr(c) for c in range(0xF081, 0xF091))
_BULLET_LINE = re.compile(r"^[" + HEADING_BULLETS + r"] ?", re.M)


def is_pua(ch: str) -> bool:
    cp = ord(ch)
    return 0xE000 <= cp <= 0xF8FF or 0xF0000 <= cp <= 0x10FFFD


# ── the divine name ─────────────────────────────────────────────────────
# The corpus carries a deliberate 耶和华 → 雅伟 substitution. It must NOT
# reach 耶和华见证人, the registered name of an organisation the preacher is
# arguing against; that mistake shipped once and
# `test/sermon_divine_name_proper_noun_test.dart` now pins it. The library
# text already writes 雅伟 364 times of its own accord, so this rule reaches
# 9 places in 182 bodies — but a rule that reaches nine places is still the
# rule.
_DIVINE = re.compile(r"耶和华(?!见证人)")


def apply_divine_name(text: str) -> str:
    return _DIVINE.sub("雅伟", text)


def read_json(p: Path):
    return json.loads(p.read_text(encoding="utf-8"))


def merged_id(refcode: str) -> str:
    """`fy-` plus the church's own refcode, lowercased.

    The prefix is what keeps these ids clear of every id already in the
    corpus (plain numbers, `EC*`, `C*`, `CP*`, `c*`, `<n>-<n>`), and the
    refcodes are unique among Pastor Eric's 198 records case-insensitively,
    which is asserted below rather than assumed.
    """
    return "fy-" + refcode.lower()


def library_body_to_app_body(raw: str, title: str, refcode: str) -> str:
    """One library body → one app body. Paragraph boundaries survive exactly.

    Everything this does is listed in the module header. It refuses rather
    than guessing at anything it has no control for.
    """
    text = raw.replace("\r\n", "\n").rstrip("\n")

    # A heading bullet is a glyph, not a word: it sits at the start of a line
    # and is followed by one space. Both go; the heading keeps its line.
    text = _BULLET_LINE.sub("", text)
    text = text.replace(PUA_PRONOUN, "祢")

    left = sorted({ch for ch in text if is_pua(ch)})
    if left:
        raise ValueError(
            f"{refcode}: unresolved private-use characters "
            + ", ".join("U+%04X" % ord(c) for c in left)
            + " — the shipped corpus has none and neither has a control here")

    lines = text.split("\n")
    # The record's own title is carried by the H1 below, so an opening line
    # that is EXACTLY it would render the title twice. Exactly, not merely
    # similar: an approximate match would start deleting the preacher's
    # first sentence.
    if lines and lines[0].strip() == title.strip():
        lines = lines[1:]
    while lines and not lines[0].strip():
        lines = lines[1:]

    if any(not ln.strip() for ln in lines):
        raise ValueError(f"{refcode}: a blank line inside the body — the "
                         f"single-newline paragraph mapping is not safe here")

    body = "\n\n".join(lines)
    return apply_divine_name(f"# {title}\n\n{body}\n")


def to_traditional(simplified: str) -> str:
    """`opencc -c s2t` plus the five normalisations. Calibrated, not assumed.

    Over every eligible pair in the shipped corpus s2t reproduces the shipped
    Traditional with 0 mismatches in 1.6 M characters. The five
    normalisations are settled unanimously by `assets/cuvs-yhwh-tr.json`.
    """
    proc = subprocess.run(["opencc", "-c", "s2t"], input=simplified,
                          capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"opencc failed: {proc.stderr}")
    out = proc.stdout
    for wrong, right in S2T_NORMALISE:
        out = out.replace(wrong, right)
    if len(out) != len(simplified):
        raise RuntimeError(
            "s2t changed the length of a body — every rule here is one "
            "character for one character")
    return out


def select(lib_index: dict, lib_refs: dict):
    """Partition Pastor Eric's records. Every number this returns is counted
    from the assets, never from a constant."""
    rows = [s for s in lib_index["sermons"] if s.get("author") == PREACHER]
    cross = lib_refs["duplicates"]["crossCorpus"]
    confirmed = {x["libId"]: x for x in cross if x["tier"] == "confirmed"}
    # A confirmed row is by construction a row about this preacher (the
    # duplicate rule is `restrictedToPreacher`), but assert it rather than
    # trust it: a row about someone else would put a stranger's text into a
    # single-preacher corpus.
    ids = {str(s["id"]) for s in rows}
    stray = sorted(set(confirmed) - ids)
    if stray:
        raise SystemExit(f"confirmed duplicate rows for records that are not "
                         f"{PREACHER}'s: {stray}")

    bodied = [s for s in rows if s.get("hasBody")]
    audio_only = [s for s in rows if not s.get("hasBody")]
    new = [s for s in bodied if str(s["id"]) not in confirmed]
    dup = [s for s in bodied if str(s["id"]) in confirmed]
    return rows, bodied, audio_only, new, dup, confirmed


_REFCODE = re.compile(r"^([A-Za-z]+)0*(\d+)")


def topic_for(rec: dict) -> str:
    """The app topic a merged record joins. See the table above; every branch
    here is one row of it."""
    code = rec["refcode"]
    m = _REFCODE.match(code)
    if not m:
        return TOPIC_FALLBACK
    prefix, n = m.group(1).lower(), int(m.group(2))
    if prefix == "sm":
        return ("The Beatitudes" if n <= 10 else _SM if n <= 40 else _MT)
    if prefix == "mt":
        return "The Parables of Jesus" if "_pb" in code.lower() else _MT
    return _SERIES_TOPIC.get(prefix, TOPIC_FALLBACK)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true",
                    help="write; without it nothing is written")
    ap.add_argument("--report", action="store_true",
                    help="print the partition and the seam, then stop")
    ap.add_argument("--out", default=str(OUT),
                    help="write somewhere other than assets/sermons "
                         "(for measuring a merge before installing it)")
    args = ap.parse_args()
    out = Path(args.out)

    lib_index = read_json(LIB / "index.json")
    lib_refs = read_json(LIB / "refs.json")
    app_index = read_json(OUT / "index.json")

    rows, bodied, audio_only, new, dup, confirmed = select(lib_index, lib_refs)

    # Ids must be unique case-insensitively or two sermons collide on one
    # file on a case-insensitive filesystem, which is what this Mac has.
    seen: dict[str, str] = {}
    for s in rows:
        mid = merged_id(s["refcode"])
        if mid in seen:
            raise SystemExit(f"refcode collision: {s['refcode']} and "
                             f"{seen[mid]} both give {mid}")
        seen[mid] = s["refcode"]
    # A merged id must not collide with an id the app already had. The `fy-`
    # prefix is what makes that true by construction — no id in the original
    # 289 begins with it — so the check that matters is the CONVERSE one: no
    # id may sit in this script's namespace unless this script put it there.
    # Stated that way it also stays correct on a SECOND run, when the merged
    # ids are already in the index; a plain intersection would then report
    # every one of this script's own outputs as a collision, and re-running
    # is the whole point of the seam for the 16 audio-only records.
    app_ids = {x["id"] for x in app_index}
    foreign = sorted(i for i in app_ids
                     if i.lower().startswith("fy-") and i.lower() not in seen)
    if foreign:
        raise SystemExit(f"ids in this merge's namespace that this merge "
                         f"does not own: {foreign}")

    replace, skipped = [], []
    for s in dup:
        row = confirmed[str(s["id"])]
        if str(s["id"]) in HELD_OUT:
            skipped.append((s, row, HELD_OUT[str(s["id"])]))
        elif row.get("completeness") in REPLACEABLE:
            replace.append((s, row))
        else:
            skipped.append((s, row, f"completeness={row.get('completeness')!r}"
                                    f" — {row.get('evidence', '')}"))

    print(f"  {PREACHER}: {len(rows)} library records")
    print(f"    {len(bodied)} with a body, {len(audio_only)} audio-only")
    print(f"    {len(confirmed)} confirmed duplicates of an app sermon")
    print(f"    {len(new)} new and bodied  →  merged")
    print(f"    {len(replace)} bodies replaced, {len(skipped)} held back")
    for s, row, why in skipped:
        print(f"      app {row['appId']:<5} ← lib {s['id']:<7} "
              f"({s['refcode']}): {why[:96]}")
    # Counted the way the merge itself counts, so this line stays true when
    # it is printed against a corpus that has already been merged once.
    base = len([r for r in app_index if not r["id"].lower().startswith("fy-")])
    print(f"    app corpus {base} → {base + len(new)}")

    if args.report:
        print("\n  the seam — 16 records with audio and no body, "
              "excluded by `hasBody` and nothing else:")
        for s in audio_only:
            flag = ("  ⚠ same title as app CP37; refuted as a PAIR OF TEXTS "
                    "only because there is no body to compare"
                    if str(s["id"]) == "6012" else "")
            print(f"      {s['id']:<7} {s['refcode']:<10} {s['title']}{flag}")
        return 0

    written = 0
    index_add = []
    for s in new:
        sid = merged_id(s["refcode"])
        raw = (LIB / s["bodyFile"]).read_text(encoding="utf-8")
        cn = library_body_to_app_body(raw, s["title"], s["refcode"])
        tw = to_traditional(cn)
        topic = topic_for(s)
        index_add.append({
            "id": sid,
            "topic": topic,
            "topicSlug": topic,
            "date": UNDATED,
            "parts": "",
            "passage": "",
            "title": s["title"],
            "titles": {"zh-CN": s["title"],
                       "zh-TW": to_traditional(s["title"])},
            "hasEn": False,
            "hasZhCn": True,
            "hasZhTw": True,
        })
        if args.apply:
            (out / "zh-CN" / f"{sid}.txt").write_text(cn, encoding="utf-8")
            (out / "zh-TW" / f"{sid}.txt").write_text(tw, encoding="utf-8")
        written += 1

    replaced = 0
    for s, row in replace:
        sid = row["appId"]
        old = (OUT / "zh-CN" / f"{sid}.txt").read_text(encoding="utf-8")
        # Keep the app's own H1. It pairs with `titles` in index.json, which
        # is what the page and the list render; swapping the body is what was
        # ruled, and a title is not a body.
        h1 = old.split("\n", 1)[0]
        if not h1.startswith("# "):
            raise SystemExit(f"{sid}: app body does not open with an H1")
        raw = (LIB / s["bodyFile"]).read_text(encoding="utf-8")
        cn = library_body_to_app_body(raw, s["title"], s["refcode"])
        cn = h1 + cn[cn.index("\n"):]
        tw = to_traditional(cn)
        if args.apply:
            (out / "zh-CN" / f"{sid}.txt").write_text(cn, encoding="utf-8")
            (out / "zh-TW" / f"{sid}.txt").write_text(tw, encoding="utf-8")
        replaced += 1

    if args.apply:
        # Rewrite this merge's own rows rather than appending them, so a
        # SECOND run produces the same 414 and not 539. The original rows
        # keep their order exactly — this file's order is SERMON_INDEX.md's,
        # not a sort, and re-sorting it would churn every line of the diff.
        kept = [r for r in app_index if not r["id"].lower().startswith("fy-")]
        merged_index = kept + index_add
        (out / "index.json").write_text(
            json.dumps(merged_index, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8")
        print(f"\n  written: {written} new, {replaced} replaced, "
              f"index {len(merged_index)}")
        print("  now run:  python3 scripts/extract_sermon_refs.py")
        print("            python3 tools/repair_tw_sermon_merged_glyphs.py "
              "--apply")
    else:
        print(f"\n  dry run — {written} would be written, {replaced} replaced")
    return 0


if __name__ == "__main__":
    sys.exit(main())
