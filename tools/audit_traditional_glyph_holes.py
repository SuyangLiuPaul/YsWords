#!/usr/bin/env python3
"""Audit EVERY Traditional-bearing asset for the glyph holes already fixed in
the CUV — the queue item "Audit every OTHER Traditional asset for the eight
glyph holes already known".

WHY THIS EXISTS
  Instalments 1–20 of the converter-hole defect were each counted in
  `assets/cuvs-yhwh-tr.json` and NOWHERE ELSE. The 松/鬆 instalment proved the
  risk is real rather than theoretical by turning up one leftover in
  `assets/biblexg-v2-tr.json` id `47005010` — inside a `blockNotes` list, which
  a `text`-only scan walks straight past. So this audit walks every string in
  every asset structurally: every value at every depth, plus the plain-text
  sermon transcripts and the Traditional strings in Dart source.

THE ONE THING THAT MAKES THE NUMBERS MEAN ANYTHING — lanes
  Most of these assets are BILINGUAL in one file: `zh-Hans` beside `zh-Hant`,
  `descZhHans` beside `descZhHant`, `sets.cuv` beside `sets.cuv-tr`,
  `glossZh` beside `glossZhTw`. Counting a whole file at once mixes the two
  and every row comes out "mixed", which says nothing. Each string is
  therefore assigned to the lane of the NEAREST ENCLOSING locale key, and only
  the **hant** lane can carry this defect. A first draft of this script did
  not do that and reported 12 spurious HOLEs.

WHAT IT LOOKS FOR — and what a hit does and does NOT mean
  For each known pair it counts BOTH forms per asset lane. Three signatures:

    HOLE      the lane holds >=1 of the wrong form and ZERO of the right one.
              That is the exact shape the CUV had for all twenty instalments:
              a file produced by a converter with no mapping at all. Strong.

    mixed     the lane holds both. NOT automatically a defect — 谷/穀, 發/髮,
              面/麵, 松/鬆, 余/餘, 制/製, 干/乾/幹 are all pairs where the
              *Simplified-looking* member is itself a correct Traditional
              character used far more often than the other. A mixed row needs
              reading position by position; it is a work list, not a verdict.

    clean     zero of the wrong form.

  A HOLE row is not a licence to blanket-substitute either. See the tail-glyph
  instalment: 歎/嘆, 祕/秘, 蹟/跡, 鍊/鏈, 甦/蘇 all show the zero-count
  signature purely because both forms are live Traditional characters and two
  editions chose differently. **The signature is necessary, not sufficient.**

ASSETS THAT ARE NOT OURS TO REPAIR — read this before acting on any row
  Two kinds, and the audit labels both in its output and skips both in
  --suspects, because a suspect list is a work list and neither of these is
  work:

  FROZEN — `assets/cuvs-yhwh.json` and `assets/cuvs-yhwh-tr.json`. The
  publisher declined our corrections (user, 2026-09-02) and
  `test/cuvs_yhwh_frozen_test.dart` pins both by SHA-256. Their rows are
  printed so a future reader does not mistake their absence for cleanliness.

  NOT OURS — `assets/biblexg-v2*.json`, which reproduce a publisher's own
  printed edition. **A glyph there is evidence about the SOURCE, never about
  our converter.** This label exists because the first version of this audit
  led a pass straight into that: it reported 隻, 崙, 穀 and 癒 rows for
  `biblexg-v2-tr.json`, ten positions were "repaired", and every one turned
  out to be the printed 註釋本's own spelling. The commit was reverted whole.

  The trap is worth naming because the evidence that felt strongest was the
  one that was wrong: the asset's INTERNAL inconsistency. 馬太福音 10:29 sets
  只 and 隻 nine characters apart and 路加福音 12:6 sets 隻 — and all of that
  is true of the printed edition. An internal inconsistency is evidence about
  the source. Before repairing ANY asset, find out whether an external
  authority for it exists.

This script only reads. It writes nothing and repairs nothing.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# (label, accepted Traditional form(s), the form the CUV converter wrote)
# Every row is an instalment that was applied to assets/cuvs-yhwh-tr.json.
#
# The right side is a SET, not a character, and that matters: 麵 and 麪 are
# both standard Traditional and this repo uses BOTH — `cuvs-yhwh-tr.json` and
# `biblexg-v2-tr.json` set 麵 (107 / 44, zero 麪), while `assets/strongs/*` and
# `assets/sermons/zh-TW/` set 麪 (55 / 71, zero 麵). Counting only 麵 reported
# the Strong's lexicon and all 289 Traditional transcripts as flour HOLEs when
# they are nothing of the kind. Same lesson as the tail-glyph instalment: a
# zero count is only a defect once you have checked that the other spelling of
# the same word is zero too.
PAIRS = [
    ("classifier", "隻", "只"),
    ("clean", "淨", "凈"),
    ("wall", "牆", "墻"),
    ("surplus", "餘", "余"),
    ("hair", "髮", "發"),
    ("beard-hu", "鬍", "胡"),
    ("beard-xu", "鬚", "須"),
    ("gather", "採", "采"),
    ("flour", "麵麪", "面"),
    ("jar", "罈", "壇"),
    ("grain", "穀", "谷"),
    ("loosen", "鬆", "松"),
    ("dry", "乾", "幹"),
    ("offend", "干", "幹"),
    ("divination", "卜", "蔔"),
    ("constancy", "恆", "恒"),
    ("insult", "凌", "淩"),
    ("ailment", "症", "癥"),
    ("recovery", "癒", "愈"),
    ("ridge", "崙", "侖"),
    ("lye", "鹼", "堿"),
    ("nephew", "姪", "侄"),
    ("restraint", "制", "製"),
]

FROZEN = {"assets/cuvs-yhwh.json", "assets/cuvs-yhwh-tr.json"}

# Assets that are NOT our conversion — a publisher's own text that this repo
# reproduces. A glyph in one of these is evidence about the SOURCE, never about
# our converter, and it is never ours to repair. Where it looks wrong it goes
# in the enquiry document named here; it does not get edited.
#
# This list exists because the audit led a pass straight into that trap on
# 2026-09-03. `biblexg-v2-tr.json` reported HOLE / mixed rows for 隻, 崙, 穀 and
# 癒; all four were the printed 註釋本's own spellings, ten positions were
# "repaired", and the commit was reverted in full. The repo already said so in
# three places — the docstring of `test/traditional_conversion_test.dart`, the
# enquiry document, and `tools/proofread_ljk_tr.py` — and the audit said
# nothing, so the audit says it now.
#
# The trap has a specific shape worth naming: the strongest-looking evidence
# was the asset's INTERNAL inconsistency (馬太福音 10:29 sets 只 and 隻 nine
# characters apart; 路加福音 12:6 sets 隻). Both are true of the print. An
# internal inconsistency is evidence about the source, not about our
# conversion.
EXTERNAL_AUTHORITY = {
    "assets/biblexg-v2-tr.json":
        "梁家鏗譯本 註釋本 2025 第二版 — verify with `pdftotext -enc UTF-8` "
        "over the publisher's PDFs before believing any row here; report to "
        "docs/梁家鏗譯本-請教出版方.md, never repair",
    "assets/biblexg-v2.json":
        "the publisher's own Simplified web edition — same rule",
}

# ---------------------------------------------------------------------------
# The layer that makes the counts actionable.
#
# A bare count cannot decide anything for the one-to-many pairs. `麵 0 / 面 111`
# in a Traditional asset is NOT a defect unless one of those 面 means flour;
# 面 is the correct Traditional character for face/side/surface and carries the
# other 111. So for each pair this table lists the COLLOCATIONS in which the
# form the converter wrote is certainly wrong — written as the collapsed
# spelling a broken converter produces. A hit here is a candidate for repair;
# a count without a hit is noise.
#
# Every entry was checked against the twenty applied CUV instalments, whose
# docstrings name both the substitution list and the keep list. The keep side
# is the dangerous side, and it is recorded in the comments so a later pass
# does not widen a pattern back over it.
# ---------------------------------------------------------------------------
SUSPECTS: dict[str, list[str]] = {
    # 面 is face/side/surface — correct. 麵 is flour and only flour.
    "flour": ["面包", "面粉", "面團", "面团", "細面", "细面", "面酵", "面食",
              "麥面", "麦面", "面條", "面条", "面糊", "面線", "面线", "拉面",
              "泡面", "和面", "揉面", "一團面", "白面"],
    # 發 is emit/issue/prosper — correct. 髮 is hair on a head.
    "hair": ["頭發", "毛發", "白發", "長發", "短發", "理發", "剃發", "束發",
             "發辮", "削發", "結發", "發膚", "假發", "金發",
             "銀發", "發絲", "披頭散發", "怒發衝冠", "間不容發"],
    # 須髮/鬚髮 deliberately NOT listed: 必須發生 / 無須發言 make it useless
    # as a cue, and the word itself does not occur in these assets.
    # 胡 is a surname, 胡亂, 胡說 — correct. 鬍 is facial hair.
    "beard-hu": ["胡須", "胡鬚", "胡子", "落腮胡", "大胡", "山羊胡", "胡渣"],
    # 須 is "must" (必須, 須要) — correct. 鬚 is a beard or a tendril.
    "beard-xu": ["胡須", "鬍須", "觸須", "須根", "留須"],
    # 只 is "only" — correct. 隻 is the classifier, and every classifier in the
    # CUV instalment was preceded by a numeral, 每, 那, 幾, 這 or 船.
    # The negative lookahead is load-bearing: 那只是 / 這只有 / 一只能 are the
    # adverb "only" and are CORRECT. Without it this pattern reports ~140
    # false positives in the sermon transcripts alone. The CUV instalment hit
    # the same trap from the other side — opencc wanted to convert 詩 17:14
    # 「那只在今生有福分的世人」 and 賽 29:17 「不是只有一點點時候嗎」, and
    # both were excluded by hand.
    "classifier": [r"[一二兩三四五六七八九十百千萬幾那這每數各]只"
                   r"(?![是有能要不剩會為爲在需想知好怕管])",
                   "船只", "只數"],
    # 壇 is an altar (祭壇), a forum (論壇), a flower bed (花壇) — correct.
    "jar": ["酒壇", "壇子", "一壇", "醋壇", "壇罐", "小壇", "大壇"],
    # 谷 is a valley — correct, 176 times in the CUV. 穀 is grain.
    "grain": ["五谷", "谷物", "谷場", "谷场", "谷倉", "谷仓", "谷類", "谷类",
              "打谷", "稻谷", "谷粒", "谷種", "谷种", "踹谷", "新谷", "谷食"],
    # 松 is a pine tree (松樹, 杜松, 松香) — correct. 鬆 is loose/relaxed.
    "loosen": ["放松", "輕松", "轻松", "松開", "松开", "松手", "松弛", "松動",
               "松动", "松懈", "松散", "松綁", "松绑", "松緩", "松脫", "松脱"],
    # 愈 is "the more…" (愈來愈) — correct. 癒 is healed.
    "recovery": ["痊愈", "治愈", "愈合", "病愈", "傷愈", "康愈"],
    # 幹 is a trunk or doing (樹幹, 才幹, 幹活) — correct. Dryness is 乾.
    "dry": ["幹淨", "幹燥", "幹旱", "幹涸", "枯幹", "幹渴", "幹杯", "幹糧",
            "幹粮", "幹枯", "曬幹", "晒幹", "烘幹", "風幹", "擦幹", "哭幹",
            "排幹", "凍幹", "弄幹", "幹蘿蔔", "幹草", "幹柴", "幹裂", "幹脆",
            "口幹", "嘴幹", "幹果", "幹地", "幹沙", "幹土", "水幹",
            "河幹", "幹了"],
    # …and interference/offence is 干.
    "offend": ["幹擾", "幹涉", "幹預", "幹预", "幹犯", "幹戈", "無幹", "无幹",
               "相幹", "幹係", "若幹", "幹卿"],
    # 恒 / 淩 / 凈 / 墻 / 余(as surplus) / 癥(as illness) / 蔔(as divination) /
    # 侖(as a place) / 堿 / 侄 are not editorial choices — the CUV instalments
    # established each as an exact partition, so the wrong form is wrong
    # wherever the sense holds.
    "constancy": ["恒"],
    "insult": ["淩"],
    "clean": ["凈"],
    "wall": ["墻"],
    "ailment": ["漏癥", "病癥", "癥狀", "重癥", "癌癥", "炎癥"],   # keep 癥結
    "divination": ["占蔔", "蔔卦", "蔔筮", "求蔔", "蔔問"],        # keep 蘿蔔
    "ridge": ["希伯侖", "西伯侖", "崑侖", "昆侖", "亞實基侖", "希實侖"],  # keep 加侖
    "lye": ["堿"],
    "nephew": ["侄"],
    # 余 is a first-person pronoun and a surname; in these assets every 余 that
    # means "the rest" is 餘.
    "surplus": ["其余", "余下", "剩余", "余數", "余数", "多余", "余地",
                "余生", "余民", "余剩", "富余", "残余", "殘余"],
    # 采 is 神采/風采/喝采 — correct. 採 is to pick or to adopt.
    "gather": ["采取", "采用", "采集", "采納", "采纳", "采訪", "采访", "采購",
               "采购", "采石", "開采", "开采", "采摘", "采果", "采買", "采买"],
    # 製 is to manufacture (製造, 銅製) — correct. Restraint/system is 制.
    "restraint": ["製止", "製度", "節製", "限製", "控製", "抑製", "專製",
                  "體製", "轄製", "壓製", "製服從", "牽製", "強製", "製約"],
}

HANT_KEYS = {"zh-Hant", "zh-TW", "zh_Hant", "zh-hant", "cuv-tr", "hant", "tw"}
HANS_KEYS = {"zh-Hans", "zh-CN", "zh_Hans", "zh-hans", "cuv", "hans", "zh", "cn"}
EN_KEYS = {"en", "english", "english-classic", "eng"}

HANT_SUFFIX = re.compile(r"(ZhHant|ZhTw|Hant|Tw)$")
# `Zh$` catches the Strong's Simplified twins `glossZh` / `defZh`. It is tested
# AFTER the Traditional suffixes so `glossZhTw` cannot fall through to it.
HANS_SUFFIX = re.compile(r"(ZhHans|ZhCn|Hans|Zh)$")
EN_SUFFIX = re.compile(r"En$")

# Files with no locale keys at all: the whole file is one lane.
FILE_LANE = [
    (re.compile(r"^assets/cuvs-yhwh-tr\.json$"), "hant"),
    (re.compile(r"^assets/biblexg-v2-tr\.json$"), "hant"),
    (re.compile(r"^assets/sermons/zh-TW/"), "hant"),
    (re.compile(r"^assets/cuvs-yhwh\.json$"), "hans"),
    (re.compile(r"^assets/biblexg-v2\.json$"), "hans"),
    (re.compile(r"^assets/sermons/zh-CN/"), "hans"),
    (re.compile(r"^assets/tagged/"), "hans"),
    (re.compile(r"^assets/sermons/en/"), "en"),
    # Simplified-only by construction, and there is NO render-time converter in
    # the app (`grep` for s2t/opencc over `lib/` finds only a docstring in
    # `lib/models/strongs.dart` describing how the lexicon asset was BUILT), so
    # a Traditional reader is shown these strings exactly as stored. They are
    # counted in the `hans` lane because that is what they are — the defect
    # they carry is "untranslated", not "wrong glyph".
    (re.compile(r"^assets/songs\.json$"), "hans"),
]

# `lib/constants/ui_strings.dart` is a Dart map literal, so there is no JSON
# tree to walk. Its lanes are one per line: `'zh-Hant': '…',`.
DART_LANE = re.compile(r"'(zh-Hant|zh-Hans|en)'\s*:")


def file_lane(rel: str) -> str:
    for pat, lane in FILE_LANE:
        if pat.search(rel):
            return lane
    return "?"


def key_lane(key: str) -> str | None:
    if key in HANT_KEYS or HANT_SUFFIX.search(key):
        return "hant"
    if key in HANS_KEYS or HANS_SUFFIX.search(key):
        return "hans"
    if key in EN_KEYS or EN_SUFFIX.search(key):
        return "en"
    return None


def iter_strings(node, lane):
    """Every string anywhere in a decoded JSON document, with its lane.

    Lane = the nearest enclosing locale key. Deliberately NOT restricted to
    `text` fields: the 松 defect that opened this item lived in `blockNotes`.
    """
    if isinstance(node, str):
        yield lane, node
    elif isinstance(node, list):
        for item in node:
            yield from iter_strings(item, lane)
    elif isinstance(node, dict):
        for key, value in node.items():
            sub = key_lane(key) or lane
            yield from iter_strings(value, sub)


def targets(root: Path):
    out = []
    for p in sorted((root / "assets").rglob("*.json")):
        rel = p.relative_to(root).as_posix()
        if rel.startswith("assets/build"):
            continue
        out.append(p)
    for sub in ("zh-TW", "zh-CN"):
        d = root / "assets/sermons" / sub
        if d.is_dir():
            out.extend(sorted(d.glob("*.txt")))
    ui = root / "lib/constants/ui_strings.dart"
    if ui.exists():
        out.append(ui)
    return out


def group(rel: str) -> str:
    """Collapse the per-book / per-file fleets into one row each."""
    for prefix in ("assets/sermons/zh-TW/", "assets/sermons/zh-CN/",
                   "assets/originals/", "assets/tagged/",
                   "assets/subtitles/", "assets/commentary/"):
        if rel.startswith(prefix):
            return prefix + "*"
    return rel


def read_lanes(path: Path, rel: str) -> list[tuple[str, str]]:
    """Every human-readable string of a file, tagged with its lane."""
    default = file_lane(rel)
    raw = path.read_text(encoding="utf-8")
    if path.suffix == ".json":
        try:
            return list(iter_strings(json.loads(raw), default))
        except json.JSONDecodeError as exc:  # pragma: no cover
            print(f"!! {rel}: {exc}", file=sys.stderr)
            return []
    if path.suffix == ".dart":
        out = []
        for line in raw.splitlines():
            m = DART_LANE.search(line)
            lane = {"zh-Hant": "hant", "zh-Hans": "hans",
                    "en": "en"}[m.group(1)] if m else default
            out.append((lane, line))
        return out
    return [(default, raw)]


def audit(root: Path, only: str | None):
    """{group: {lane: {label: [right, wrong]}}}"""
    merged: dict[str, dict[str, dict[str, list[int]]]] = {}
    for path in targets(root):
        rel = path.relative_to(root).as_posix()
        if only and only not in rel:
            continue
        strings = read_lanes(path, rel)
        lanes: dict[str, list[str]] = {}
        for lane, s in strings:
            lanes.setdefault(lane, []).append(s)
        bucket = merged.setdefault(group(rel), {})
        for lane, chunks in lanes.items():
            if lane == "en":
                continue
            text = "\n".join(chunks)
            per = bucket.setdefault(lane, {})
            for label, right, wrong in PAIRS:
                r = sum(text.count(c) for c in right)
                w = text.count(wrong)
                if r or w:
                    acc = per.setdefault(label, [0, 0])
                    acc[0] += r
                    acc[1] += w
    return merged


def suspects(root: Path, only: str | None, lane_want: str):
    """The work list: every position where the wrong form sits in a
    collocation that demands the right one. This is what a repair pass reads;
    the count table above only says which files to look at."""
    found: dict[tuple[str, str], list[tuple[str, str]]] = {}
    for path in targets(root):
        rel = path.relative_to(root).as_posix()
        if only and only not in rel:
            continue
        if rel in FROZEN or rel in EXTERNAL_AUTHORITY:
            # Audited by count only. A suspect list is a work list, and neither
            # a frozen asset nor a publisher's own text is work.
            continue
        for lane, s in read_lanes(path, rel):
            if lane_want != "all" and lane != lane_want:
                continue
            for label, patterns in SUSPECTS.items():
                for pat in patterns:
                    for m in re.finditer(pat, s):
                        lo = max(0, m.start() - 12)
                        hi = min(len(s), m.end() + 12)
                        found.setdefault((rel, label), []).append(
                            (m.group(0), s[lo:hi].replace("\n", " ")))
    return found


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="substring filter on the asset path")
    ap.add_argument("--lane", default="hant",
                    help="lane to print: hant (default), hans, ?, all")
    ap.add_argument("--holes-only", action="store_true")
    ap.add_argument("--suspects", action="store_true",
                    help="print the collocation work list rather than counts")
    ap.add_argument("--max", type=int, default=8,
                    help="with --suspects, contexts printed per file+label")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    if args.suspects:
        found = suspects(ROOT, args.only, args.lane)
        total = 0
        for (rel, label) in sorted(found):
            hits = found[(rel, label)]
            total += len(hits)
            print(f"\n{rel}  [{label}]  {len(hits)} hit(s)")
            for got, ctx in hits[:args.max]:
                print(f"    {got}   …{ctx}…")
            if len(hits) > args.max:
                print(f"    … {len(hits) - args.max} more")
        print(f"\nTOTAL {total} suspect position(s) in lane {args.lane}")
        return 0

    merged = audit(ROOT, args.only)
    if args.json:
        print(json.dumps(merged, ensure_ascii=False, indent=2, sort_keys=True))
        return 0

    glyphs = {label: ("/".join(right), wrong) for label, right, wrong in PAIRS}
    for rel in sorted(merged):
        for lane in sorted(merged[rel]):
            if args.lane != "all" and lane != args.lane:
                continue
            per = merged[rel][lane]
            lines = []
            for label in sorted(per):
                right, wrong = glyphs[label]
                r, w = per[label]
                sig = "clean" if w == 0 else ("HOLE" if r == 0 else "mixed")
                if args.holes_only and sig != "HOLE":
                    continue
                lines.append(
                    f"    {label:<12} {right} {r:>6}   {wrong} {w:>6}   {sig}")
            if not lines:
                continue
            tags = []
            if rel in FROZEN:
                tags.append("FROZEN — report only, never repair")
            if rel in EXTERNAL_AUTHORITY:
                tags.append("NOT OURS — " + EXTERNAL_AUTHORITY[rel])
            tag = ("  [" + "; ".join(tags) + "]") if tags else ""
            print(f"\n{rel}  ({lane}){tag}")
            print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
