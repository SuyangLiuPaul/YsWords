#!/usr/bin/env python3
"""Rebuild `glossZh`/`glossZhTw` in the Strong's lexicons from the whole
of CBOL's sense 1, instead of from the first physical LINE of it.

`tools/build_originals.py` derives `glossZh` with a single
`^\\s*1\\)\\s*(.+?)\\s*$` match over `defZh`, so it stops at the newline
CBOL happened to wrap on. CBOL wraps a long sense at its own column
width with a `\\n   ` continuation, which means the shipped gloss for
426 entries is a sentence cut in half:

    H86    ...呼叫声, 昭告约瑟坐的副车来了
           and the next line — 可能是"你们要下拜"或"俯首"的意思 —
           carries the actual definition
    G3712  ...一般用来测量深度
           losing 当两手臂往外伸直, 两手中指指尖距离所测得的长度
    G1179  ...北方紧邻大马色,        losing 南方是非拉铁非
    G2815  ...根据传统说法,          losing 他就是初世纪末的罗马主教革利免

`glossZh` is what the originals sheet, the Strong's entry page, search
results and the distribution table print as the word's meaning, so every
one of those fragments is on screen.

The opposite error is the real risk, because CBOL uses one newline both
for a wrap and for a deliberate break. G749's sense 1 is `祭司长, 大祭司`
on a 17-column line inside a 90-column entry, and the line after it opens
a fresh article; joining them yields `大祭司在祭司中最大的一`, a reading
found in no lexicon. So a break counts as a wrap only when the line that
ends on it could not have held more — see `sense_one_gloss`.

**No network and no `opencc`.** `defZh` and `defZhTw` both ship whole, so
both glosses are derivable from what is already in the tree.

`glossZhTw` is read out of `defZhTw`, not converted from the repaired
`glossZh`. `scripts/build_strongs_traditional.py` builds the Traditional
columns by running `opencc -c s2t.json` line by line over the Simplified
ones, which makes `defZhTw` character-for-character `s2t(defZh)` with
every newline and every column width preserved. Running this same
line-joining derivation over `defZhTw` therefore lands on exactly the
string `opencc` would have produced from the new `glossZh` — without
re-running a conversion, and without inventing a character that has not
already shipped. That matters here: s2t is not a safe blanket operation
on this corpus (`tools/repair_lexicon_zhu_glyph.py`,
`tools/repair_strongs_tw_ambiguous.py` and the `repair_tr_*` family all
exist to undo places where it went wrong), and re-converting would drop
those repairs on the floor.

Rejected: importing the derivation from `tools/build_originals.py` and
fixing it there, the way the same repair was done in SeekSparks. Sharing
one implementation is the better shape — the generator and the shipped
asset cannot then drift — but `build_originals.py` is outside what this
change owns. **Until it is fixed too, re-running the generator will
re-truncate these 426 glosses**; that is the known cost of the split and
it is recorded here so the next person does not have to rediscover it.

Idempotent: the derivation is a pure function of `defZh`/`defZhTw`,
neither of which this script writes, so a second run measures 0.

    python3 tools/repair_zh_gloss_linebreaks.py            # measure
    python3 tools/repair_zh_gloss_linebreaks.py --apply
"""
from __future__ import annotations

import argparse
import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEXICON = ["assets/strongs/greek.json", "assets/strongs/hebrew.json"]

# The only two fields this script writes, each derived from the body
# beside it. Nothing else in the entry is read back or rewritten.
PAIRS = (("glossZh", "defZh"), ("glossZhTw", "defZhTw"))

# Pinned per file: (rejoined, comma_only, other). Measured 2026-09-08
# over this tree. `rejoined` is a gloss that gained text from a wrapped
# continuation line; `comma_only` is job 3, a gloss whose only defect
# was CBOL's trailing separator; `other` is the remainder — glosses the
# old `(.+?)` match mis-split for some reason other than a wrap, listed
# by `--measure` so a change in the number is visible rather than
# absorbed.
EXPECT = {
    "assets/strongs/greek.json": (91, 29, 0),
    "assets/strongs/hebrew.json": (335, 30, 0),
}

# ── CBOL's line grammar ───────────────────────────────────────────────

# The grammatical categories CBOL prints on a line of their own between
# a sense and its sub-senses. They are metadata about the headword, not
# part of any definition, so they END sense 1 rather than continue it.
#
# Both orthographies are listed because the same derivation runs over
# the Traditional `defZhTw` column.
#
# A closed vocabulary, not a length or an indentation test, because both
# of those misclassify the real data: CBOL indents three of these tags
# (H369, H4616, H8478) and leaves the rest at column zero, while genuine
# definition text runs as short as `的手上` (H2078) and `地名` is itself
# a two-character tag. Only the words separate them.
_POS_TERMS = frozenset({
    "名词", "名詞", "阳性名词", "陽性名詞", "阴性名词", "陰性名詞",
    "中性名词", "中性名詞", "专有名词", "專有名詞",
    "阳性专有名词", "陽性專有名詞", "阴性专有名词", "陰性專有名詞",
    "专有地名词", "專有地名詞", "地名专有名词", "地名專有名詞",
    "专有名词地名", "專有名詞地名",
    "形容词", "形容詞", "形容词的", "形容詞的",
    "副词", "副詞", "作为副词", "作為副詞", "受格的副词", "受格的副詞",
    "连接词", "連接詞", "附介系词", "附介系詞",
    # This tree's s2t writes 系 as 係 in 介係詞, so the Traditional
    # spelling is NOT the one a s2t-of-the-Simplified-list would give.
    # H2108 is the entry that proves it: without 介係詞 here, the
    # Traditional gloss picks up the part-of-speech tag on line two and
    # reads `移動, 撤退 (但只見於作介係詞與連接詞) 介係詞` while the
    # Simplified one stops correctly. Both spellings are listed so the
    # two columns join the same lines.
    "介系词", "介系詞", "介係詞", "附介係詞",
    "动词", "動詞", "及物动词", "及物動詞", "不及物动词", "不及物動詞",
    "实名词", "實名詞", "作名词用", "作名詞用",
    "关系代名词", "關係代名詞", "阴性关系代名词", "陰性關係代名詞",
    "代名词", "代名詞", "假设分词", "假設分詞",
    "否定词", "否定詞", "复合字", "複合字",
    "地名", "人名", "种族名称", "種族名稱",
    "复数", "複數", "单数", "單數", "抽象", "加强语气", "加強語氣",
    "阳性", "陽性", "阴性", "陰性", "中性",
    "感叹词", "感嘆詞", "疑问词", "疑問詞", "数词", "數詞", "冠词", "冠詞",
})
_POS_SEP = re.compile(r"[\s,，、;；()（）]+")

# CBOL nests to at least four levels: `1)`, `1a)`, `1a1)`, `1a1a)`. A
# `\d+[a-zA-Z]*\)` pattern stops at two and reads `1a1) 神话中的海怪`
# as ordinary text continuing sense 1 of H7293.
_NUMBERED = re.compile(r"^\s*\d+(?:[a-zA-Z]+\d*)*\)")

# Ideographs and the fullwidth forms. A boundary between two of these
# carries its own spacing and must not be given another.
_WIDE = re.compile(r"[　-〿㐀-鿿豈-﫿＀-￯]")

# Punctuation that closes what came before it, so a wrap landing just
# ahead of it must not be given a space either: CBOL breaks G5330
# between `以自以为是的好行为自豪` and `, 相对之下…`.
_LEADS_TIGHT = re.compile(r"[,，、;；.。!！?？:：)）\]】]")

# A line ending on one of these is unfinished — CBOL ran out of column.
_DANGLING = re.compile(r"[,，、;；]\s*$")

# A line has said what it came to say when it closes a sentence, or when
# it ends on a CBOL citation closer — `|`, optionally inside the bracket
# that the `(#` opened. A PLAIN bracket is NOT terminal: `(今 Anata
# 亚拿塔)` (H1374), `别是巴[884]` (H5683) and `与莉达(Leda)` (G1359) all
# close a parenthesis mid-sentence, and reading those as the end leaves
# H1374 saying the village is AT Anathoth rather than between the ridges
# of Anathoth and Nob.
_TERMINAL = re.compile(r"(?:[.。!！?？:：]|\|\s*[)）\]】]?)\s*$")

# Share of the entry's own widest line that a line must reach before the
# break ending it is read as CBOL running out of column. Below it, the
# break is the editor's. The comparison is per entry because the corpus
# has no single column width — sense-1 line widths run continuously from
# 5 to 99 with no gap to cut at.
_WRAP_RATIO = 0.70


def _is_pos_line(line: str) -> bool:
    """True when the whole line is grammatical metadata."""
    toks = [t for t in _POS_SEP.split(line.strip()) if t]
    return bool(toks) and all(t in _POS_TERMS for t in toks)


def _display_width(line: str) -> int:
    """Columns `line` occupies in CBOL's fixed-width layout."""
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1
               for c in line)


def sense_one_gloss(body: str) -> str:
    """Sense 1 of a CBOL definition body, joined back across the
    physical lines CBOL wrapped it on.

    A following line ends sense 1 when it is blank, when it opens a new
    numbered item, or when it is grammatical metadata. Otherwise the
    question is whether CBOL broke the line or the editor did, and the
    answer is whether the line that ends on the break could have held
    more: it dangles on a separator, or it is unterminated AND reaches
    `_WRAP_RATIO` of the widest line in its own entry.

    The join is direct between two wide characters and spaced otherwise.
    A space is not a word boundary in Chinese, so joining `藉着神所赐`
    to `解梦的恩赐` with one would invent a break inside a phrase (H1841;
    also H3038 `他的后` + `裔`, H6540 `里` + `海和`) — while
    `崇拜太阳神的中心,` + `波提非拉` needs the space CBOL's own style
    puts after a comma.

    Finally a trailing separator is dropped (job 3). After joining, one
    can only be CBOL's own: measured across both lexicons, every gloss
    still ending on a comma is followed by a sub-sense, by the next
    sense, or by the end of the body — never by text we declined to take.
    """
    if not body:
        return ""
    lines = body.split("\n")
    start = None
    for i, ln in enumerate(lines):
        if re.match(r"^\s*1\)\s*\S", ln):
            start = i
            break
    if start is None:
        # `build_originals.py` falls back to the first TOP-LEVEL numbered
        # line, and the depth restriction is load-bearing. H7665's body
        # is the raw CBOL entry — CBOL prints its sense 1 as a bare line
        # (`折断, 打碎`) and numbers only the stems under it — so a
        # fallback that accepted `1a)` would ship `(Qal)` as the word's
        # meaning. The shipped gloss is empty there instead, and
        # `StrongsEntry.localizedGloss` already reads the body at runtime
        # for exactly that case.
        for i, ln in enumerate(lines):
            if re.match(r"^\s*\d+\)\s*\S", ln):
                start = i
                break
    if start is None:
        return ""
    wrap = max(_display_width(ln.rstrip()) for ln in lines)
    # CBOL is inconsistent about the space after the marker (G25 has
    # `1)珍爱`, G2316 has `1) 神或女神`), so `\s*` rather than `\s`.
    out = re.sub(r"^\s*\d+[a-zA-Z]*\)\s*", "", lines[start]).strip()
    prev = lines[start].rstrip()
    for ln in lines[start + 1:]:
        piece = ln.strip()
        if not piece or _NUMBERED.match(ln) or _is_pos_line(ln):
            break
        if not _DANGLING.search(prev):
            if _TERMINAL.search(prev):
                break
            if _display_width(prev) < _WRAP_RATIO * wrap:
                break
        prev = ln.rstrip()
        tight = out and (_LEADS_TIGHT.match(piece[0])
                         or (_WIDE.match(out[-1]) and _WIDE.match(piece[0])))
        if tight:
            out += piece
        elif out:
            out += " " + piece
        else:
            out = piece
    return out.rstrip(" \t,，、;；")


# ── the repair ────────────────────────────────────────────────────────

def _classify(old: str, new: str) -> str:
    """Which of the three pinned rules this rewrite falls under."""
    if new.startswith(old.rstrip(" \t,，、;；")) and len(new) > len(
            old.rstrip(" \t,，、;；")):
        return "rejoined"
    if new == old.rstrip(" \t,，、;；"):
        return "comma_only"
    return "other"


def _scan(path: Path) -> tuple[dict, dict[str, int], list[str]]:
    doc = json.loads(path.read_text(encoding="utf-8"))
    counts = {"rejoined": 0, "comma_only": 0, "other": 0}
    notes: list[str] = []
    for key, entry in doc.items():
        touched = set()
        for gloss_key, def_key in PAIRS:
            old = entry.get(gloss_key)
            body = entry.get(def_key)
            if not isinstance(old, str) or not isinstance(body, str) or not body:
                continue
            new = sense_one_gloss(body)
            # A body we cannot parse leaves the shipped value alone —
            # an empty gloss is a regression, not a repair.
            if not new or new == old:
                continue
            entry[gloss_key] = new
            touched.add(gloss_key)
            # Only the Simplified column is counted. The Traditional one
            # is the same defect seen twice, and counting both would
            # double every number in EXPECT for no extra information.
            if gloss_key == "glossZh":
                rule = _classify(old, new)
                counts[rule] += 1
                if rule == "other":
                    notes.append(f"  {key}  {old!r} -> {new!r}")
        # The two columns are the same body in two orthographies, so a
        # rewrite that lands on one and not the other means the
        # derivation read them differently — which is a bug in the line
        # grammar, not a fact about the entry. H2108 was exactly this:
        # `介係詞` was missing from `_POS_TERMS`, so the Traditional
        # gloss swallowed a part-of-speech tag the Simplified one stopped
        # at. Reported rather than silently written.
        if len(touched) == 1 and {"glossZh", "glossZhTw"} <= set(entry):
            notes.append(f"  {key}  ONE-SIDED rewrite, only {touched.pop()} "
                         "changed — the two columns disagree")
            counts["other"] += 1
    return doc, counts, notes


def run(apply: bool) -> int:
    failed = False
    for name in LEXICON:
        path = ROOT / name
        doc, counts, notes = _scan(path)
        got = (counts["rejoined"], counts["comma_only"], counts["other"])
        print(f"{name}: rejoined {got[0]}, trailing separator only {got[1]}, "
              f"other {got[2]} (expect {EXPECT[name]})")
        for note in notes:
            print(note)
        # `(0, 0, 0)` is the second run of the same repair, not a
        # failure — this script has to be safe to re-run.
        if got != EXPECT[name] and got != (0, 0, 0):
            failed = True
            continue
        if apply:
            # Serialisation has to match what the file already carries,
            # or the repair reformats five megabytes and buries itself.
            path.write_text(
                json.dumps(doc, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8")
    if failed:
        print("REFUSING to write: the measured counts are neither the pinned "
              "numbers nor an already-repaired zero.")
    assert not failed, "measured counts do not match EXPECT"
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true",
                    help="write the rebuilt glosses back (default: measure)")
    args = ap.parse_args()
    return run(args.apply)


if __name__ == "__main__":
    raise SystemExit(main())
