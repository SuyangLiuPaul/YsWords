#!/usr/bin/env python3
"""Build assets/commentary/jfb-matthew.json from the published JFB SWORD module.

Source of record
----------------
CrossWire Bible Society, SWORD module ``JFB`` version 3.0
(``SwordVersionDate=2021-02-15``), distributed as a packaged module —
NOT scraped from any website. See ``docs/jfb-commentary-licence.md`` for
the licence evidence and the download URL / SHA-256 of the archive this
was built from.

Why the alignment here can be trusted
-------------------------------------
A commentary block shown against the wrong verse is the same class of
defect as a citation opening the wrong chapter, so nothing here is
assumed. The verse each entry belongs to is derived from the module's
own binary index, and then checked against TWO independent statements
the text itself makes:

1. Every chapter-heading slot must carry ``osisID="Matt.<n>"`` matching
   the chapter the walk predicts. 28/28 must match.
2. JFB prints its own verse number at the head of nearly every comment
   ("**12. And being warned of God...**", "**3-6. And Judas begat...**").
   The verse the walk assigns must fall inside the range the entry
   prints for itself.

Either check failing aborts the build. The chapter verse counts driving
the walk are read from ``assets/kjv.json`` (the KJV versification the
module declares), never typed in by hand.

Section titles are NOT used as an alignment check, because SWORD stores
the title that introduces the *next* section at the tail of the
*preceding* verse's entry (the ``x-preverse`` convention). Attaching a
title to the verse whose entry physically contains it would caption
Mt 2:12 with "Mt 2:13-23. The Flight into Egypt" — a heading one verse
early, the same defect class as a citation opening the wrong chapter.
Instead each trailing title is moved to the verse its own ``osisRef``
names, so a title can only ever land where it says it belongs.

zCom4 format
------------
``nt.bzs``  block index, 12 bytes/block: offset u32, compressed u32,
            uncompressed u32.
``nt.bzv``  entry index, 12 bytes/entry: block u32, start u32, size u32.
``nt.bzz``  concatenated zlib blocks. ``BlockType=BOOK``, so block N is
            book N of the testament; Matthew is block 1.

Entry slots for a testament are laid out
``[0] reserved, [1] testament heading, [2] book heading,
[3] chapter-1 heading, [4..] chapter-1 verses, ...``.

Usage
-----
    python3 tools/build_commentary_jfb.py --module-dir <unzipped JFB.zip>
"""

from __future__ import annotations

import argparse
import collections
import html
import json
import os
import re
import struct
import sys
import zlib

BOOK = "Matthew"
OSIS_BOOK = "Matt"
NT_BLOCK = 1  # BlockType=BOOK => Matthew is the first book block of the NT.

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# --------------------------------------------------------------------------
# module reading
# --------------------------------------------------------------------------
def read_block(module_dir: str, block: int) -> bytes:
    bzs = open(os.path.join(module_dir, "nt.bzs"), "rb").read()
    bzz = open(os.path.join(module_dir, "nt.bzz"), "rb").read()
    off, csize, usize = struct.unpack_from("<III", bzs, block * 12)
    raw = zlib.decompress(bzz[off : off + csize])
    if len(raw) != usize:
        raise SystemExit(f"block {block}: got {len(raw)} bytes, index says {usize}")
    return raw


def read_entries(module_dir: str) -> list[tuple[int, int, int]]:
    bzv = open(os.path.join(module_dir, "nt.bzv"), "rb").read()
    if len(bzv) % 12:
        raise SystemExit("nt.bzv is not a whole number of 12-byte entries")
    return [struct.unpack_from("<III", bzv, i * 12) for i in range(len(bzv) // 12)]


def kjv_verse_counts(book: str) -> list[int]:
    """Chapter verse counts for `book`, read from the repo's own KJV asset."""
    with open(os.path.join(REPO, "assets", "kjv.json"), encoding="utf-8") as fh:
        rows = json.load(fh)
    counts: collections.Counter[int] = collections.Counter()
    for row in rows:
        if row["book"] == book:
            counts[int(row["chapter"])] += 1
    if not counts:
        raise SystemExit(f"{book} not found in assets/kjv.json")
    chapters = max(counts)
    if sorted(counts) != list(range(1, chapters + 1)):
        raise SystemExit(f"{book} has gaps in its chapter numbering")
    return [counts[c] for c in range(1, chapters + 1)]


# --------------------------------------------------------------------------
# OSIS -> lightweight text
# --------------------------------------------------------------------------
PARA_BREAK = re.compile(r"<div[^>]*type=\"x-p\"[^>]*/>")
TITLE = re.compile(r"<title\b[^>]*>(.*?)</title>", re.S)
BOLD = re.compile(r"<hi[^>]*type=\"bold\"[^>]*>(.*?)</hi>", re.S)
ITALIC = re.compile(r"<hi[^>]*type=\"italic\"[^>]*>(.*?)</hi>", re.S)
TAG = re.compile(r"<[^>]+>")
WS = re.compile(r"[ \t]+")


def to_text(osis: str) -> str:
    """Flatten OSIS to plain text with `**bold**` runs and blank-line paragraphs.

    `**` is the only markup emitted, so the reader needs one trivial parser
    and there is no HTML in the bundle.
    """
    s = osis
    s = PARA_BREAK.sub("\n\n", s)
    s = BOLD.sub(lambda m: "**" + TAG.sub("", m.group(1)).strip() + "**", s)
    s = ITALIC.sub(lambda m: TAG.sub("", m.group(1)), s)
    s = TAG.sub("", s)
    s = html.unescape(s)
    s = s.replace("\r", "")
    s = WS.sub(" ", s)
    s = re.sub(r"\n{3,}", "\n\n", s)
    s = "\n".join(line.strip() for line in s.split("\n"))
    s = re.sub(r"\*\*\s*\*\*", "", s)
    return s.strip()


def section_titles(osis: str) -> list[tuple[str, str]]:
    """Return (osisRef, plain title) for each section title in `osis`."""
    out = []
    for m in TITLE.finditer(osis):
        inner = m.group(1)
        ref = re.search(r'osisRef="([^"]+)"', inner)
        text = html.unescape(TAG.sub("", inner)).strip()
        text = WS.sub(" ", text)
        if text:
            out.append((ref.group(1) if ref else "", text))
    return out


OSIS_RANGE = re.compile(
    rf"^{OSIS_BOOK}\.(\d+)\.(\d+)(?:-{OSIS_BOOK}\.(\d+)\.(\d+))?$"
)


# --------------------------------------------------------------------------
# build
# --------------------------------------------------------------------------
def build(module_dir: str) -> dict:
    counts = kjv_verse_counts(BOOK)
    entries = read_entries(module_dir)
    block = read_block(module_dir, NT_BLOCK)

    def raw(slot: int) -> str:
        b, start, size = entries[slot]
        if size == 0 or b != NT_BLOCK:
            return ""
        return block[start : start + size].decode("utf-8", "replace")

    def key(slot: int) -> tuple[int, int, int]:
        return entries[slot]

    # ---- walk the index, checking every chapter heading against osisID ----
    slot = 3  # [2] is the book heading; chapter 1's heading follows it
    verse_slots: list[tuple[int, int, int]] = []  # (chapter, verse, slot)
    chapter_heading_slots: list[int] = []
    for chapter, n_verses in enumerate(counts, start=1):
        head = raw(slot)
        if f'osisID="{OSIS_BOOK}.{chapter}"' not in head:
            raise SystemExit(
                f"ALIGNMENT FAILED: slot {slot} should be the heading for "
                f"{OSIS_BOOK}.{chapter} but does not declare that osisID.\n"
                f"  got: {head[:160]!r}"
            )
        chapter_heading_slots.append(slot)
        slot += 1
        for verse in range(1, n_verses + 1):
            verse_slots.append((chapter, verse, slot))
            slot += 1

    expected_end = 3 + len(counts) + sum(counts)
    if slot != expected_end:
        raise SystemExit(f"walk ended at {slot}, expected {expected_end}")

    # ---- split the book introduction out of the Matt 1:1 slot ----
    # The module opens the book introduction at the chapter-1 heading and
    # closes it inside the 1:1 entry, immediately before `<title>CHAPTER 1`.
    # Leaving it in place would print ~15 KB of front matter against 1:1.
    first = raw(verse_slots[0][2])
    cut = first.find('<title type="x-s">CHAPTER 1</title>')
    if cut < 0:
        raise SystemExit("could not find the 'CHAPTER 1' title that ends the introduction")
    intro_osis = raw(chapter_heading_slots[0]) + first[:cut]
    intro = to_text(raw(2) + intro_osis)

    # ---- CHECK 1 (non-circular): does the index put each comment on the
    #      verse the comment prints for itself? Run BEFORE anything is moved.
    LEAD = re.compile(r"<hi[^>]*type=\"bold\"[^>]*>\s*(\d+)\s*(?:[-,]\s*(\d+))?\s*\.")
    mismatches: list[str] = []
    self_declaring = 0
    stored = 0
    for chapter, verse, sl in verse_slots:
        if key(sl)[2] == 0:
            continue
        stored += 1
        body = raw(sl)
        m = LEAD.search(body)
        if not m or body.find("<hi") != m.start():
            continue  # a continuation lemma; it names no verse of its own
        self_declaring += 1
        lo = int(m.group(1))
        hi = int(m.group(2)) if m.group(2) else lo
        if not lo <= verse <= hi:
            mismatches.append(
                f"{OSIS_BOOK} {chapter}:{verse} — the index maps this entry to "
                f"verse {verse}, but the comment prints itself as {lo}-{hi}"
            )
    if mismatches:
        raise SystemExit(
            "ALIGNMENT FAILED: %d stored comments disagree with the verse the "
            "module index assigns them:\n  %s"
            % (len(mismatches), "\n  ".join(mismatches[:20]))
        )

    # ---- group consecutive verses that share one stored comment ----
    # JFB range comments ("3-6.") are stored once and repeated across every
    # verse of the range, so identical index entries collapse to one block.
    groups: list[dict] = []
    # Chapter-heading slots are not decoration. Where JFB defers a whole
    # chapter to a parallel Gospel it stores the section titles and the "For
    # the exposition, see on Mr 13:1-37" stubs THERE and leaves every verse
    # slot empty — that is the entirety of the commentary on Matthew 24 and
    # Matthew 26 (126 verses). Skipping these slots silently loses them.
    for chapter, hsl in enumerate(chapter_heading_slots, start=1):
        if chapter == 1:
            continue  # already consumed as the book introduction
        if key(hsl)[2] == 0:
            continue
        groups.append({"_k": key(hsl), "c": chapter, "v": 1, "_osis": raw(hsl)})
    for chapter, verse, sl in verse_slots:
        if key(sl)[2] == 0:
            continue
        body = first[cut:] if (chapter, verse) == (1, 1) else raw(sl)
        k = ("head", 1) if (chapter, verse) == (1, 1) else key(sl)
        if groups and groups[-1]["_k"] == k and groups[-1]["c"] == chapter:
            continue
        groups.append({"_k": k, "c": chapter, "v": verse, "_osis": body})
    groups.sort(key=lambda g: (g["c"], g["v"]))

    # ---- place each piece on the verse the piece itself names ----
    # Two things travel in a SWORD commentary entry besides the verse's own
    # comment: the title introducing the NEXT section (the x-preverse
    # convention), and — where JFB defers a section to a parallel Gospel — the
    # titles and stub comments of several following sections at once (Matt 8:4
    # carries 8:5-13, 8:14-17 and 8:18-22). A chapter opener travels the other
    # way: the "Mt 22:1-14" title is stored on 22:2 because 22:1 has no comment.
    # So the body is cut at every title and every numbered lead-in, and each
    # piece goes where its own osisRef / printed number says it belongs.
    fragments: dict[tuple[int, int], list[str]] = {}
    rehomed = 0
    for g in groups:
        here = (g["c"], g["v"])
        pieces: list[tuple[tuple[int, int], str]] = []
        for part in re.split(r"(?=<title\b)", g["_osis"]):
            if not part.strip():
                continue
            target = here
            if part.lstrip().startswith("<title"):
                for ref, _text in section_titles(part):
                    m = OSIS_RANGE.match(ref)
                    if m and int(m.group(1)) == g["c"]:
                        v = int(m.group(2))
                        if 1 <= v <= counts[g["c"] - 1]:
                            target = (g["c"], v)
                        break
            # A numbered lead-in inside the piece starts that verse's own
            # comment; everything from it belongs to the verse it names, not
            # to the section title that happens to precede it.
            cuts = [
                (mm.start(), int(mm.group(1)))
                for mm in LEAD.finditer(part)
                if 1 <= int(mm.group(1)) <= counts[g["c"] - 1]
            ]
            bounds = [0] + [c for c, _ in cuts] + [len(part)]
            tgts = [target] + [(g["c"], n) for _, n in cuts]
            for i, t in enumerate(tgts):
                chunk = part[bounds[i] : bounds[i + 1]]
                if chunk.strip():
                    pieces.append((t, chunk))
        for t, chunk in pieces:
            if t != here:
                rehomed += 1
            fragments.setdefault(t, []).append(chunk)

    # ---- assemble blocks ----
    blocks: list[dict] = []
    for (chapter, verse) in sorted(fragments):
        osis = " ".join(fragments[(chapter, verse)])
        heading = ""
        for _ref, text in section_titles(osis):
            if not text.upper().startswith("CHAPTER"):
                heading = text
                break
        # The heading is rendered separately, so drop every <title> from the
        # body rather than printing the same sentence twice.
        body = to_text(TITLE.sub("", osis))
        # Some titles close before their own closing bracket, leaving the
        # parallel-passage list outside the element ("... Second Coming. ( ="
        # + "Mr 13:1-37; Lu 21:5-36)."). Reunite them instead of shipping a
        # heading that stops mid-bracket.
        if heading.count("(") > heading.count(")"):
            close = body.find(")")
            if 0 <= close < 160:
                heading = (heading + " " + body[: close + 1]).strip()
                body = body[close + 1 :].lstrip(" .;")
                heading = WS.sub(" ", heading.replace("( =", "( ="))
        if not body:
            continue
        row = {"c": chapter, "v": verse, "t": body}
        if heading:
            row["h"] = heading
        blocks.append(row)

    # ---- CHECK 2: did the splitter itself misplace anything? Every block
    #      that prints a verse number must print the one it is filed under.
    split_bad = [
        f"{OSIS_BOOK} {r['c']}:{r['v']} holds a comment printed as verse "
        f"{re.match(r'[*]{2}(\d+)', r['t']).group(1)}"
        for r in blocks
        if re.match(r"[*]{2}(\d+)[-,.\s]", r["t"])
        and int(re.match(r"[*]{2}(\d+)", r["t"]).group(1)) != r["v"]
    ]
    if split_bad:
        raise SystemExit(
            "ALIGNMENT FAILED after re-homing: %d blocks:\n  %s"
            % (len(split_bad), "\n  ".join(split_bad[:20]))
        )

    # ---- extend each block to cover the verses between it and the next ----
    # JFB is section-based: a reader sitting on 8:9 must reach the "Mt 8:5-13"
    # block. A chapter's first block also reaches back to verse 1, because JFB
    # anchors a section opener on its first *commented* verse — chapter 24's
    # opener is stored at 24:3, and 24:1-2 would otherwise be unreachable.
    # `v` becomes the first verse covered; the anchor is kept only for CHECK 2.
    for i, row in enumerate(blocks):
        nxt = blocks[i + 1] if i + 1 < len(blocks) else None
        row["e"] = (
            nxt["v"] - 1 if nxt and nxt["c"] == row["c"] else counts[row["c"] - 1]
        )
        if i == 0 or blocks[i - 1]["c"] != row["c"]:
            row["v"] = 1
        if row["e"] < row["v"]:
            raise SystemExit(f"block {row['c']}:{row['v']} has an empty range")

    # ---- CHECK 3: the blocks tile the book exactly, no gap, no overlap ----
    seen: set[tuple[int, int]] = set()
    for row in blocks:
        for v in range(row["v"], row["e"] + 1):
            if (row["c"], v) in seen:
                raise SystemExit(f"overlapping blocks at {OSIS_BOOK} {row['c']}:{v}")
            seen.add((row["c"], v))
    expected = {(c, v) for c, n in enumerate(counts, 1) for v in range(1, n + 1)}
    if seen != expected:
        raise SystemExit(f"blocks do not tile the book; gaps: {sorted(expected - seen)[:10]}")

    total_verses = sum(counts)
    print(f"chapter headings verified    : {len(chapter_heading_slots)}/{len(counts)}")
    print(f"entries printing own verse # : {self_declaring}/{stored} — all agree")
    print(f"pieces re-homed by own ref   : {rehomed}")
    print(f"verses with a stored comment : {stored}/{total_verses}")
    print(f"comment blocks               : {len(blocks)}")
    print(f"verses reachable via a block : {len(seen)}/{total_verses}")

    return {
        "id": "jfb",
        "book": BOOK,
        "bookOsis": OSIS_BOOK,
        "title": "Commentary Critical and Explanatory on the Whole Bible",
        "authors": "Robert Jamieson, A. R. Fausset and David Brown",
        "firstPublished": 1871,
        "license": "Public Domain",
        "licenseEvidence": "docs/jfb-commentary-licence.md",
        "source": "CrossWire Bible Society SWORD module JFB 3.0 (2021-02-15)",
        "chapters": len(counts),
        "verses": total_verses,
        "versesCovered": stored,
        "intro": intro,
        "entries": blocks,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--module-dir",
        required=True,
        help="directory holding nt.bzs/nt.bzv/nt.bzz from an unzipped JFB.zip",
    )
    ap.add_argument(
        "--out",
        default=os.path.join(REPO, "assets", "commentary", "jfb-matthew.json"),
    )
    args = ap.parse_args()

    data = build(args.module_dir)
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, separators=(",", ":"))
        fh.write("\n")
    print(f"wrote {args.out} ({os.path.getsize(args.out)} bytes)")


if __name__ == "__main__":
    main()
