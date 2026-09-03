#!/usr/bin/env python3
"""Re-set the Strong's lexicon from OpenCC's standard-Traditional orthography
(爲/着/羣/衆/喫/牀) into the one this app's Bible edition uses (為/著/群/眾/
吃/床) — 2,816 positions.

  ⚠  DRAFT — NEVER APPLIED, AND --apply IS GATED. This script exists so the
     decision can be executed in one command the moment the user makes it,
     and so the verification behind it does not have to be redone. It is NOT
     evidence that the decision has been made.

WHY IT IS NOT APPLIED
  The queue item ("The lexicon and the Bible are set in two different
  Traditional orthographies") says in both its original and its 2026-09-03
  re-measurement that this **needs one answer from the user**, and
  `test/lexicon_traditional_orthography_test.dart` was written specifically to
  stop it happening as a side effect of some other pass — "which is exactly
  how this repo has lost decisions before". Nothing false is printed either
  way: every character on both sides is legitimate Traditional Chinese.

  The argument for going ahead is the user's glyph ruling of 2026-09-02 —
  「关于繁体字 你可以参考和合本最新版本的繁体版看那边怎么写的然后用他们的」 —
  whose own examples include 著 over 着. **That ruling does not reach here**,
  and the queue says so itself: it was given for `cuvs-yhwh-tr`, and when that
  file was frozen the queue recorded that it "now applies **there**", meaning
  the `biblexg-v2*` rebuild. It is a rule for converting SCRIPTURE against a
  printed edition. The lexicon is glosses, has no printed Traditional edition
  to consult, and was left as its own open question in the same file on the
  same day.

WHAT THE MEASUREMENT ACTUALLY SHOWS — and it is not what the item says
  The item frames this as two files meeting on one screen, 2,816 positions.
  Measured across every Traditional-bearing asset (`--measure`), it is not:

      asset                       爲/為      着/著      喫/吃
      assets/strongs/*.json     1883/0     419/0      77/5
      assets/cuvs-yhwh-tr.json     0/7952     0/2651     0/1043
      assets/biblexg-v2-tr.json    1/2377    10/1166     0/237
      assets/sermons/zh-TW/    23701/860   6915/454   728/15

  **`assets/sermons/zh-TW/` — 289 files, 2.88 MB of reader-facing Traditional
  text — is in the LEXICON's orthography, not the Bible's, and by an
  overwhelming margin: 32,330 positions against the lexicon's 2,816.** The
  same split is already recorded elsewhere for a different character:
  `tools/audit_traditional_glyph_holes.py` notes that the two Bible assets set
  麵 while `assets/strongs/*` and `assets/sermons/zh-TW/` set 麪.

  So converting the lexicon alone does not harmonise the app — it moves 8% of
  the divergence and leaves the sermon corpus as the only asset in the old
  orthography. That is a real argument for a wider sweep, or for leaving both,
  but it is not this script's to make. It is reported so the user answers the
  question that is actually in front of them.

THE PREMISE CHECKS, WHICH DO PASS (`--verify`)
  1. The Bible side is uniform: `cuvs-yhwh-tr.json` has ZERO of all six
     OpenCC forms. (`biblexg-v2-tr.json` has 1 爲 and 10 着, already known to
     the queue as strays for its own rebuild to clear, and NOT ours to touch —
     it reproduces a publisher's printed edition.)
  2. All six pairs are safe one-to-one merges in the direction proposed. Each
     was read in context, and two of them are not what the queue says:

     **喫 → 吃 is safe, but the queue's reason for it is wrong.** The item
     says "the lexicon is not internally uniform either — 5 吃 against 77 喫 —
     so a sweep would tidy that too". Those 5 吃 are NOT untidiness and must
     never be swept: every one is 口吃, a STAMMER — H3933 「譏笑的, 嘲笑,
     口吃」 and G945 「像口吃的人一樣,再三重覆同樣」. 喫 is eat and 吃 there is
     a different word. The partition is already correct; only the 77 move.

     **着 → 著 is safe because 著 subsumes both senses in this edition** —
     the aspect particle and the zhù of 著名. Note 51 of the 419 are already
     the zhù sense (着名, 着稱, 着作, 着述, 顯着), which is a defect in its
     own right and is described under NOT IN SCOPE below.

  3. NOT IN SCOPE, and the script refuses if asked: 幹/乾/干, 發/髮, 後/后,
     里/裡, 復/覆. Those are one-to-many and are a different kind of decision.

ALSO FOUND, NOT FIXED HERE — 51 positions wrong in BOTH orthographies
  The lexicon spells 著名/著稱/著作/著述/顯著 with 着 in 51 places (H210
  「一個以產金着名的地方」, H1316 「以土壤肥沃着稱」, H1862 「以智慧着稱」,
  H3792 「寫作着述」…). That is wrong whichever convention wins, because 着 is
  never the zhù. It is inherited: all 419 Simplified twins write 着 too, so
  the upstream CBOL source carries it and `opencc s2t` passed it through
  unchanged. Fixing it would put 51 著 into the lexicon and trip the pinning
  test, so it is filed for the user as its own item rather than smuggled in
  under this one.

--measure   the full cross-asset table (read-only, the default)
--verify    re-run the premise and variant-safety checks (read-only)
--apply     gated behind --user-ruled; refuses otherwise
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEXICON = ["assets/strongs/hebrew.json", "assets/strongs/greek.json"]
TW_FIELDS = ("glossZhTw", "defZhTw")

# (opencc s2t form, this edition's form, count in the lexicon)
PAIRS: list[tuple[str, str, int]] = [
    ("爲", "為", 1883),
    ("羣", "群", 195),
    ("衆", "眾", 195),
    ("着", "著", 419),
    ("喫", "吃", 77),
    ("牀", "床", 47),
]
EXPECT_TOTAL = 2816

# Characters that must never be swept by anything in this file. Each is
# one-to-many: the Simplified form maps to two or more Traditional characters
# that are different words, so no blanket rule can be right.
OUT_OF_SCOPE = ["幹", "乾", "干", "發", "髮", "後", "后", "里", "裡", "復", "覆"]

# The five 吃 already in the lexicon are 口吃 — a stammer, not eating. They are
# a different word from 喫 and the sweep must leave them exactly where they are.
STAMMER_ENTRIES = {"H3933": 3, "G945": 2}

# Assets measured for the cross-asset table.
CORPORA = [
    "assets/cuvs-yhwh-tr.json",
    "assets/biblexg-v2-tr.json",
    "assets/tagged",
    "assets/sermons/zh-TW",
]


def lexicon_fields() -> list[tuple[str, str, str]]:
    """(strong's id, field name, value) for every Traditional lexicon field."""
    out = []
    for name in LEXICON:
        doc = json.loads((ROOT / name).read_text(encoding="utf-8"))
        for key, entry in doc.items():
            for field in TW_FIELDS:
                value = entry.get(field)
                if isinstance(value, str):
                    out.append((key, field, value))
    return out


def corpus_text(rel: str) -> str:
    p = ROOT / rel
    if p.is_dir():
        parts = []
        for f in sorted(p.rglob("*")):
            if f.is_file() and f.suffix in (".json", ".txt"):
                parts.append(f.read_text(encoding="utf-8", errors="ignore"))
        return "".join(parts)
    return p.read_text(encoding="utf-8") if p.exists() else ""


def measure() -> None:
    lex = "".join(v for _, _, v in lexicon_fields())
    rows = [("assets/strongs/*.json", lex)]
    for rel in CORPORA:
        rows.append((rel, corpus_text(rel)))

    head = "  ".join(f"{a}/{b}".rjust(11) for a, b, _ in PAIRS)
    print(f"{'asset':<28}{head}")
    for label, text in rows:
        cells = []
        for a, b, _ in PAIRS:
            cells.append(f"{text.count(a)}/{text.count(b)}".rjust(11))
        print(f"{label:<28}" + "  ".join(cells))
    print()
    print("NOTE assets/tagged is the SIMPLIFIED word-tap corpus (为 7952, "
          "说 9538) — its 着 are correct Simplified, not a third orthography.")
    lex_total = sum(lex.count(a) for a, _, _ in PAIRS)
    ser = corpus_text("assets/sermons/zh-TW")
    ser_total = sum(ser.count(a) for a, _, _ in PAIRS)
    print(f"\nOpenCC-orthography positions: lexicon {lex_total}, "
          f"sermons/zh-TW {ser_total}, together {lex_total + ser_total}.")
    print("Converting the lexicon alone moves "
          f"{100 * lex_total / (lex_total + ser_total):.0f}% of them.")


def verify() -> int:
    problems = []
    fields = lexicon_fields()
    lex = "".join(v for _, _, v in fields)

    total = 0
    for a, b, want in PAIRS:
        got = lex.count(a)
        total += got
        if got != want:
            problems.append(f"lexicon has {got} {a}, pinned at {want}")
        other = lex.count(b)
        if b == "吃":
            if other != 5:
                problems.append(f"lexicon has {other} 吃, pinned at 5")
        elif other:
            problems.append(
                f"lexicon already has {other} {b} — the orthographies are "
                f"mixing rather than being chosen between")
    if total != EXPECT_TOTAL:
        problems.append(f"total {total}, pinned at {EXPECT_TOTAL}")

    # 1. the Bible side really is uniform
    bible = corpus_text("assets/cuvs-yhwh-tr.json")
    for a, _b, _ in PAIRS:
        if bible.count(a):
            problems.append(
                f"assets/cuvs-yhwh-tr.json has {bible.count(a)} {a} — the "
                f"premise that the Bible side is uniform is false")

    # 2. the five 吃 are 口吃 (a stammer), not eating, and stay put
    seen: dict[str, int] = {}
    for key, _field, value in fields:
        n = value.count("吃")
        if n:
            seen[key] = seen.get(key, 0) + n
            for m in re.finditer("吃", value):
                window = value[max(0, m.start() - 1):m.start() + 1]
                if "口吃" not in window:
                    problems.append(
                        f"{key} has a 吃 that is not 口吃: "
                        f"{value[max(0, m.start() - 8):m.start() + 8]!r}")
    if seen != STAMMER_ENTRIES:
        problems.append(f"the 吃 entries are {seen}, pinned at "
                        f"{STAMMER_ENTRIES} — re-read them before sweeping 喫")

    # 3. nothing out of scope is reachable by the substitutions below
    for a, b, _ in PAIRS:
        if a in OUT_OF_SCOPE or b in OUT_OF_SCOPE:
            problems.append(f"pair {a}/{b} touches the one-to-many class")

    if problems:
        print("VERIFY FAILED:", file=sys.stderr)
        for p in problems:
            print("   ", p, file=sys.stderr)
        return 1
    print("verify: lexicon counts match the pinned table (2,816 positions); "
          "assets/cuvs-yhwh-tr.json holds zero of all six; the 5 吃 are all "
          "口吃 in H3933/G945 and are excluded from the 喫 sweep; no pair "
          "touches 幹/乾/干, 發/髮, 後/后, 里/裡 or 復/覆.")
    return 0


def apply(user_ruled: bool) -> int:
    if not user_ruled:
        print(
            "REFUSING. This is an edition-wide typographic choice that the "
            "queue records as needing one answer from the user, and\n"
            "test/lexicon_traditional_orthography_test.dart exists to stop it "
            "being made as a side effect of another pass.\n\n"
            "Before re-running with --user-ruled, note that --measure shows "
            "the question is wider than the queue item states:\n"
            "assets/sermons/zh-TW/ holds 32,330 positions in the lexicon's "
            "orthography against the lexicon's 2,816, so converting\n"
            "the lexicon alone leaves the sermon corpus as the odd one out. "
            "The user should be answering that question, not this one.\n\n"
            "When they do rule: re-run with --user-ruled, then update the "
            "counts in test/lexicon_traditional_orthography_test.dart in\n"
            "the same commit — its docstring says those numbers are the work "
            "order.", file=sys.stderr)
        return 2
    if verify():
        return 1
    changed = 0
    for name in LEXICON:
        path = ROOT / name
        doc = json.loads(path.read_text(encoding="utf-8"))
        for entry in doc.values():
            for field in TW_FIELDS:
                value = entry.get(field)
                if not isinstance(value, str):
                    continue
                new = value
                for a, b, _ in PAIRS:
                    new = new.replace(a, b)
                if new != value:
                    changed += new != value and sum(
                        value.count(a) for a, _, _ in PAIRS)
                    entry[field] = new
        path.write_text(
            json.dumps(doc, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8")
    print(f"re-set {changed} positions; now update "
          f"test/lexicon_traditional_orthography_test.dart in this commit.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--measure", action="store_true")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--user-ruled", action="store_true",
                    help="assert the user has answered the orthography "
                         "question; without it --apply refuses")
    args = ap.parse_args()
    if args.apply:
        return apply(args.user_ruled)
    if args.verify:
        return verify()
    measure()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
