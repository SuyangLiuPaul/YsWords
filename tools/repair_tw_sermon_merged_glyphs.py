#!/usr/bin/env python3
"""Glyph repairs for the sermons merged in from `assets/sermon_library/`.

READ THIS BEFORE THE TABLE. This is the sibling of
`tools/repair_tw_sermon_spot_glyphs.py` and `..._dry_glyph.py`, and it exists
for the same reason they do: `assets/sermons/zh-TW/` is produced by running
`opencc -c s2t` over the Simplified body, and s2t is phrase-aware but not
right. On 2026-09-06 `scripts/merge_sermon_library.py` converted 125 new
sermons and 51 replacement bodies the same way, and every ambiguity s2t got
wrong in them is listed below, one anchored reading at a time.

WHY A SECOND FILE RATHER THAN MORE ROWS IN THE FIRST. `repair_tw_sermon_spot_
glyphs.py` carries EXPECTED COUNTS measured over the 289-file corpus (面酵 63,
面包 8, 采取 3, 采納 1). Those counts are its safety rail — it refuses if the
corpus has moved under it. Adding rows for a corpus half again as large would
mean editing those numbers, which is the one thing that file is built to make
hard. Its rules stay pinned to what they measured; this file carries what the
merge measured. Both are idempotent and both refuse rather than guess.

THIS FILE REPLACES AN EARLIER, UNRUN VERSION OF ITSELF, AND WHY MATTERS.
A previous agent left a `repair_tw_sermon_merged_glyphs.py` in the tree,
never executed, before it stopped at the weekly API limit. Its READINGS are
real — they were measured on converted text, and 41 of its 51 rules match
this merge character for character, including all three of its private-use
findings. Its FILE NAMES are not: it names `fy-mt63`, `fy-mt77`, `fy-mt86`,
`fy-mt103`, `fy-mt109`, `fy-sm31` and `fy-sm38` as merged-in sermons, and
every one of those seven library records is a CONFIRMED DUPLICATE of a sermon
the app already ships (app 071, 105, 112, 129, 136, 040, 047). A merge that
gives those records their own ids while also replacing their app twins ships
seven sermons twice. It also names `fy-rms01`, which is not a refcode in the
library at all (the nearest are `rms06-01`…`rms10-02`, every one of them
audio-only), and it puts 「而是永恒生命的保險」 in `fy-mt86` when that reading
is in `fy-mt85`. So the table below is re-derived from this merge by
enumerating every occurrence of every class, and the old rules are used as
corroboration where they agree rather than as input. Three classes it missed
entirely are marked NEW below.

WHAT s2t GOT WRONG, BY CLASS. Every count below was READ in context before it
was written down.

  斗 → 鬥 (25)  The most serious, and the same defect the 289-file corpus had:
    scripture quoted with the wrong glyph. 斗 is a measuring bowl, 鬥 is to
    fight, and Simplified spells both 斗. So Matthew 5:15 / Luke 8:16 / 11:33
    come out as 「放在鬥底下」 — a lamp under a FIGHT — 12 times across five
    files, and `fy-sm12b`, a whole message ABOUT the bowl, names it outside
    the quotation seven more times. SEVEN MORE WERE ALREADY SHIPPED and are
    repaired here: 075.txt was half-repaired on 2026-09-03 — its 「或鬥底下」
    was fixed and the six places where the same file names the bowl on its
    own were not, so it has read 「鬥——裏面裝著穀物」, a FIGHT with grain in
    it, ever since. `tw_sermon_glyph_test.dart` asserted the opposite of that
    while it was true. Every other 鬥 in these files is 戰鬥 /
    爭鬥 / 奮鬥 / 搏鬥 / 打鬥 / 格鬥 / 決鬥 / 好鬥 / 好勇鬥狠 / 鬥爭 /
    鬥拳 / 角鬥士 / 鉤心鬥角 / 單打獨鬥 and is right, which is why only the
    「鬥底下」 collocation is swept and the other six are anchored one at a
    time.

  乾 / 幹 / 干 (17)  Simplified 干 covers all three. s2t resolves most of them
    correctly — 才幹, 樹幹, 骨幹, 軀幹, 幹活, 幹掉, 幹嘛, 幹革命, 幹道,
    幹線, 乾淨, 乾糧, 枯乾, 乾涸, 乾旱, 乾渴, 餅乾, 一乾二淨, 外強中乾,
    定乾坤, 干犯, 干戈, 干擾, 干涉, 干係, 若干, 不相干 are all right in
    these files and all survive — but it writes 幹 for dryness in five
    places, 乾 for doing in four, 幹 for offence in two, and it splits 乾脆
    three ways across five files.

  恒 → 恆 (6)  All six are 永恒生命. The corpus writes 恆 276 times and 恒
    zero (`repair_tw_sermon_spot_glyphs.py` repaired the last two on
    2026-09-03), so this is not a preference.

  覆活 / 複活 → 復活 (29)  A resurrection is 復活; 覆 is to cover or overturn
    and 複 is to duplicate. **NEW: 複活 was not in the earlier version at
    all** — 10 of its 12 are in the SHIPPED corpus rather than in the merge,
    every one of those 「被複活」 (169 ×2, 214 ×2, 234 ×2, 370, C115, C174,
    C178). Two more of them, in 136 and 325, went away with the machine text
    this merge replaced, which is why the first count written here was 14 and
    the rail below refused it. 覆活 splits 12 in the merge and 5 already
    shipped. Both are swept corpus-wide, because
    leaving the shipped half would make the corpus half-repaired, which is
    the state every one of these scripts refuses to write. The evidence is
    the corpus's own convention, 復活 against 覆活 and 複活 by more than
    fifty to one, and in one paragraph of `fy-mt61` the same speaker writes
    both: 「你們會看見覆活的大能。」復活並非兩千年前發生過的事」. All 29 were
    read: no 覆 and no 複 before 活 is anything but a resurrection, and 反覆,
    覆蓋, 覆轍, 答覆, 回覆, 傾覆, 天翻地覆, 全軍覆沒, 重複, 複雜, 複數,
    複述, 複印 and 錯綜複雜 all survive untouched.

  麪 / 面 (both directions, 8)  s2t writes 麪 for 面對 — so 「全心全意面對真
    理」 became 「全心全意麪對真理」 — and it leaves 面酵 and 面包 alone,
    which are leaven and bread. Both directions are here. **NEW: 面包 was not
    in the earlier version**, and its rule is not a sweep: it is
    `repair_tw_sermon_spot_glyphs.py`'s regex reused character for character,
    because 「裏面包含」 is an INSIDE that CONTAINS and 「層面包裹」 is an
    ASPECT that WRAPS, and one of those was corrupted into flour once
    already. `fy-im21` 「裏面包含許多內容」 is in this merge and is exactly
    that trap.

  采取 → 採取 (2)  The rule the 289-file corpus already settled at 採取 54 :
    采取 3. 尼采, 興高采烈, 風采 and 神采 all survive.

  鍾 → 鐘 (1)  **NEW.** `fy-nm11` 「每一聲都是可怕的“催命鍾”」 — a BELL.
    鍾 is a cup or the surname; the corpus's other 鍾 are 鍾馬田 (Martyn
    Lloyd-Jones) and 一見鍾情, and they are right.

NOT REPAIRED, AND SAID PLAINLY RATHER THAN LEFT UNSAID. s2t also writes 隻
(the measure word) where the sense is 只 (only): 「這隻能治標不治本」,
「就是隻要擯棄」, 「是不是隻有主耶穌在世的那個世代」. Roughly 63 positions in
this merge and roughly 81 already in the shipped 289 — the class predates the
merge, and `test/tw_sermon_glyph_test.dart`'s docstring cites 隻 453 as
EVIDENCE OF A GOOD CONVERTER, which is the opposite of what it is. Separating
those from the 250-odd correct 隻 (一隻羊, 兩隻手, 隻字未提, 形單影隻,
船隻) is a per-occurrence adjudication over ~144 positions and belongs to its
own pass, not to a merge. It is written down here so the next reader finds it.

NEVER THE PREACHER'S WORDING. Every rule is one character for one character
and the script refuses if any string changes length. Dry-run by default;
--apply writes. Re-running after --apply is a no-op.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIR = ROOT / "assets/sermons/zh-TW"

# Files whose repair is COMMITTED and which `merge_sermon_library.py` does
# not rewrite, so their rules are expected to find nothing to do. Measured
# 2026-09-06: all twelve are byte-identical to HEAD after `--apply`.
# Anything else showing up as already-run means the corpus is in a state
# nobody predicted, and that is still a refusal.
EXPECTED_ALREADY = frozenset({"075.txt"})

# ── corpus-wide sweeps ───────────────────────────────────────────────────
# (pattern, replacement, expected hits, why). A pattern is swept only where
# the collocation is decisive on its own; everything else is anchored below.
# The expected count is the safety rail: if the corpus moves under this file,
# it refuses rather than doing a bigger or smaller job than the one measured.
SWEEPS: tuple[tuple[str, str, int, str], ...] = (
    ("鬥底下", "斗底下", 12,
     "馬太福音 5:15 / 路加福音 8:16 / 11:33 — a lamp under a bowl, never "
     "under a fight; 018, 080 ×2, fy-sm12a ×2, fy-sm12b ×6, fy-sm28"),
    # 17 -> 12 and 12 -> 2 on 2026-09-06, and the reason is the same for
    # both: THIS TOOL'S OWN OUTPUT IS NOW COMMITTED. The 5 and the 10
    # "already shipped" hits lived in files the merge does not rewrite
    # (234, 323, 834, CP60, c106; 169, 214, 234, 370, C115, C174, C178), so
    # once their repair was committed, `git checkout` + `--apply` stopped
    # resurrecting them and only the merge's own share comes back. Verified
    # rather than assumed: all twelve of those files are byte-identical to
    # HEAD after `--apply`, and each carries 復活 with zero 覆活/複活.
    # This is the rail doing its job — it refused, and the difference was
    # read before the number moved.
    ("覆活", "復活", 12,
     "a resurrection; the merge's own share, in 129, 136 and fy-mt61"),
    ("複活", "復活", 2,
     "the same word again; the merge's own share, "
     "fy-nm18 and fy-nm19 「將來複活」"),
    ("永恒生命", "永恆生命", 6,
     "against 恆 ×276 and 恒 ×0 in the corpus this merges into; "
     "018, 065, 135, fy-mt85, fy-nm00, fy-nm16"),
    ("面酵", "麪酵", 4,
     "leaven — 080 ×2 「面酵比喻」, fy-mt62 and fy-nm13 「一點面酵能使全團"
     "發起來」 (林前 5:6). The 289-file corpus already spells it 麪酵 ×63"),
    ("采取", "採取", 2,
     "against 採取 ×54 in the same corpus; fy-bp01 and fy-nm29"),
    # Both added 2026-09-06 with the 15 transcribed sermons, and both were
    # found by AUDITING the new bodies against the corpus's own conventions
    # rather than by any test — every zero-side assertion in
    # `tw_sermon_glyph_test.dart` passed while these two were in the tree.
    ("采用", "採用", 1,
     "fy-ws04 「原文采用的文法」; 採用 ×8 against 采用 ×1 in this corpus, "
     "and the Simplified control reads 采用, which is right for Simplified"),
    ("頭髮動", "頭發動", 2,
     "羅馬書 7:8 「叫諸般的貪心在我裡頭發動」 — s2t read 里头发动 as "
     "頭髮 + 動, so the verse said HAIR. fy-rms07-02 and fy-rms07-03; the "
     "Simplified control reads 在我里头发动 in both"),
    ("麪對", "面對", 2,
     "to FACE the truth, not flour — fy-bp03 and fy-bp07; the Simplified "
     "body reads 面对 and is the control"),
    ("催命鍾", "催命鐘", 1,
     "fy-nm11 — a bell tolling, not a cup; the corpus's other 鍾 are "
     "鍾馬田 and 一見鍾情"),
)

# 面包 is the one class that cannot be swept, and this pattern is
# `tools/repair_tw_sermon_spot_glyphs.py`'s, reused character for character
# rather than rewritten. The lookbehind protects 「裏面包含」 and the
# lookahead protects 「層面包裹」 — an aspect that WRAPS, which a narrower
# earlier version of this rule turned into flour.
BREAD = re.compile(r"(?<![裏裡外上下前後層方局場表全兩各情顏見會])面包"
                   r"(?![裹含圍括])")
BREAD_N = 2   # 011.txt 「一片面包」 and 「你是有面包了」 — a slice of bread

# ── anchored rules ───────────────────────────────────────────────────────
# (file, wrong, right, why). Same length on both sides, always. Merged-in
# sermons are `fy-<refcode>.txt`; a replacement body keeps the app id whose
# text it replaced.
RULES: tuple[tuple[str, str, str, str], ...] = (
    # ── 斗 named outside the quotation, in the message that is about it ──
    ("fy-sm12b.txt", "第一樣是“鬥”，鬥是裝穀子的器具",
     "第一樣是“斗”，斗是裝穀子的器具",
     "the first of the four things: the bowl is a grain measure — two here"),
    ("fy-sm12b.txt", "熄滅了燈\n\n鬥是什麼呢", "熄滅了燈\n\n斗是什麼呢",
     "a section heading: what is the bowl?"),
    ("fy-sm12b.txt", "1、鬥（太5：15", "1、斗（太5：15",
     "an enumerated list of the four things that hide the light"),
    ("fy-sm12b.txt", "就是鬥、器皿", "就是斗、器皿",
     "the bowl and the jar — food and a living"),
    ("fy-sm12b.txt", "跟“鬥”字不同", "跟“斗”字不同",
     "the jar, UNLIKE the word 斗 — the second of the four things"),

    # ── and six bowls that were already in the shipped corpus ────────────
    # THESE SIX ARE NOW EXPECTED TO BE ALREADY REPAIRED. 075.txt is one of
    # the twelve files this tool touches and the merge does not rewrite, so
    # once its repair was committed, `git checkout` + `merge --apply`
    # leaves it fixed and these rules find nothing to do. See
    # EXPECTED_ALREADY below: the refusal now compares WHICH rules had
    # already run rather than how many, because "six had already run" is
    # the correct state of a correctly-run pipeline and "some other six"
    # is not.
    # 075.txt was half-repaired on 2026-09-03: its 「或鬥底下」 was fixed and
    # the six places where the same file names the bowl on its own were not,
    # so it has read 「鬥——裏面裝著穀物」 — a FIGHT that contains grain —
    # ever since, while `tw_sermon_glyph_test.dart` asserted that every 鬥 in
    # the corpus outside 鬥底下 was a fight. Its own Simplified body is the
    # control and writes 斗 at all six.
    ("075.txt", "馬可提到了鬥：", "馬可提到了斗：",
     "可 4:21 — Mark mentions the BOWL"),
    ("075.txt", "不要用鬥把它蓋上", "不要用斗把它蓋上", "do not cover it with a bowl"),
    ("075.txt", "被鬥蓋上", "被斗蓋上", "covered by the bowl"),
    ("075.txt", "鬥——裏面裝著穀物", "斗——裏面裝著穀物",
     "the bowl — it has grain in it; the sentence settles itself"),
    ("075.txt", "讓你用鬥蓋上", "讓你用斗蓋上", "not so that you cover it with a bowl"),
    ("075.txt", "鬥裝的是乾貨", "斗裝的是乾貨",
     "the bowl holds dry goods, it is a dry measure"),
    ("fy-sm12b.txt", "鬥用來裝幹穀物", "斗用來裝乾穀物",
     "the jar holds liquid, the BOWL holds DRY grain — 斗 and 乾 together"),

    # ── 乾 is dry; 幹 is a trunk, a cadre, doing; 干 is to offend ────────
    ("018.txt", "淚始幹", "淚始乾",
     "「蠟燭成灰淚始乾」 — the candle burns to ash and the tears DRY, 李商隱"),
    ("fy-sm12b.txt", "淚始幹", "淚始乾", "「蠟炬成灰淚始乾」, the same couplet"),
    ("047.txt", "是幹河牀", "是乾河牀",
     "a wadi is a DRY riverbed — and the same sentence writes 乾涸, "
     "which is the control"),
    ("fy-sm40.txt", "溼了又幹", "溼了又乾", "the trousers get wet and then DRY"),
    ("fy-mt82.txt", "那麼幹脆就不要打了", "那麼乾脆就不要打了", "乾脆 — simply"),
    ("fy-mt82.txt", "那麼幹脆就不要蓋了", "那麼乾脆就不要蓋了",
     "乾脆 again, four clauses later — the earlier version had only the "
     "first of these two"),
    ("fy-mt85.txt", "那麼幹脆丟掉", "那麼乾脆丟掉", "乾脆"),
    ("073.txt", "不如干脆不講道", "不如乾脆不講道", "乾脆, spelt 干 this time"),
    ("fy-sm16.txt", "不如干脆不說", "不如乾脆不說", "乾脆, spelt 干 again"),
    ("fy-im02.txt", "你乾沒幹壞事", "你幹沒幹壞事",
     "whether you DID wrong — s2t split 干没干 two ways inside one word"),
    ("fy-est07.txt", "前兩天干了很多家務活兒", "前兩天幹了很多家務活兒",
     "DID a lot of housework"),
    ("039.txt", "奴隸乾的活", "奴隸幹的活", "work a slave DOES"),
    ("fy-sm48.txt", "奴隸乾的活", "奴隸幹的活", "the same reading, other file"),
    ("fy-mt104.txt", "仇敵乾的", "仇敵幹的",
     "馬太福音 13:28 — this is what the ENEMY DID"),
    ("fy-nm09.txt", "親自幹預", "親自干預",
     "Paul had to INTERVENE — 干預, which the corpus writes elsewhere"),
    # ── 採 is to pick or adopt; 采 is 興高采烈 / 無精打采 / 尼采 ──────────
    ("763.txt", "舉手可采", "舉手可採",
     "「果木飄香、舉手可採」 — fruit within reach, to be PICKED. After this "
     "the corpus's 采 is exactly 興高采烈 ×7, 尼采 ×13 and 無精打采 ×1, and "
     "the test can enumerate all 21 instead of asserting greaterThan(0)"),

    ("fy-sm32.txt", "可能幹犯主的身", "可能干犯主的身",
     "哥林多前書 11:27 — to OFFEND against the body of the Lord; the corpus "
     "writes 干犯 ×16"),
)

# Readings the rules must NOT reach. Every one is a near-miss for a rule
# above it. This is the half that catches a widened pattern, and every entry
# was located in THIS corpus rather than carried over from the earlier file
# — four of that file's eleven pointed at the wrong sermon.
MUST_SURVIVE: tuple[tuple[str, str], ...] = (
    ("040.txt", "狗好鬥是衆所周知的了"),        # 好鬥 + 是, next to 「鬥是」
    ("040.txt", "好勇鬥狠"),
    ("fy-sm12b.txt", "格鬥廝殺"),               # a fight, in the 斗 file itself
    ("763.txt", "武術、格鬥、拳擊"),
    ("fy-im03.txt", "與罪惡的鬥爭中"),
    ("047.txt", "夏天是乾涸的"),                # the control for 乾河牀
    ("080.txt", "正幹著農活"),                  # doing, not drying
    ("039.txt", "幹盡壞事"),                    # doing
    ("407.txt", "幹革命是為了改善"),            # doing
    ("fy-sm17.txt", "你在支線、我在幹線嗎"),    # a trunk road
    ("018.txt", "外強中乾"),                    # dry, already right
    ("063.txt", "一語定乾坤"),
    ("fy-nm00.txt", "扭轉了乾坤"),
    ("fy-im21.txt", "裏面包含許多內容"),        # 裏面 + 包含, not bread
    ("fy-mt59.txt", "桌上一碗長壽麪"),          # noodles, already 麪
    ("fy-mt67_pb03.txt", "製成麪粉"),           # flour, already 麪
    ("fy-nm11.txt", "馬薩達"),                  # the file the 鍾 rule sits in
    ("136.txt", "何以證明復活呢"),              # written by the 覆活 sweep
    ("fy-mt61.txt", "復活並非兩千年前發生過的事"),
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    texts = {p.name: p.read_text(encoding="utf-8")
             for p in sorted(DIR.glob("*.txt"))}

    missing = sorted({f for f, *_ in RULES} - set(texts)) + \
        sorted({f for f, _ in MUST_SURVIVE} - set(texts))
    if missing:
        print(f"  ✗ these files are not in the corpus: {missing} — the "
              f"merge that produced these rules has not been run — refusing")
        return 1

    total_before = sum(len(t) for t in texts.values())
    substitutions = 0
    touched: set[str] = set()
    already = 0
    rule_count = len(SWEEPS) + 1 + len(RULES)

    for wrong, right, expect, why in SWEEPS:
        if len(wrong) != len(right):
            print(f"  ✗ {wrong} → {right} changes length — refusing")
            return 1
        n = sum(t.count(wrong) for t in texts.values())
        if n == 0:
            already += 1
            continue
        if n != expect:
            print(f"  ✗ {wrong} → {right}: {n} in the corpus, {expect} "
                  f"measured. Something moved under this rule — READ the "
                  f"difference before changing the number. Refusing")
            return 1
        for name in list(texts):
            if wrong in texts[name]:
                texts[name] = texts[name].replace(wrong, right)
                touched.add(name)
        substitutions += n
        print(f"  sweep  {wrong} → {right}   ×{n:<3} {why[:62]}")

    n = sum(len(BREAD.findall(t)) for t in texts.values())
    if n == 0:
        already += 1
    elif n != BREAD_N:
        print(f"  ✗ 面包 → 麪包: {n} sites, {BREAD_N} measured — refusing")
        return 1
    else:
        for name in list(texts):
            new = BREAD.sub("麪包", texts[name])
            if new != texts[name]:
                texts[name] = new
                touched.add(name)
        substitutions += n
        print(f"  sweep  面包 → 麪包   ×{n:<3} bread, with the lookbehind and "
              f"lookahead 「裏面包含」 and 「層面包裹」 need")

    already_files: set[str] = set()
    for name, wrong, right, why in RULES:
        n = texts[name].count(wrong)
        if n == 0:
            if right in texts[name]:
                already += 1
                already_files.add(name)
                continue
            print(f"  ✗ {name}: neither 「{wrong}」 nor its repair "
                  f"is present — refusing")
            return 1
        if len(wrong) != len(right):
            print(f"  ✗ {name}: 「{wrong}」 is not the same length "
                  f"as its repair — this is one character for one character "
                  f"and never a rewording — refusing")
            return 1
        texts[name] = texts[name].replace(wrong, right)
        touched.add(name)
        substitutions += n
        print(f"  {name:16} {wrong[:14]} → {right[:14]}   ×{n:<3} {why[:46]}")

    if already == rule_count:
        print("  already applied — nothing to do")
        return 0
    unexpected = already_files - EXPECTED_ALREADY
    if unexpected:
        print(f"  ✗ rules in {sorted(unexpected)} had already run and are "
              f"not in EXPECTED_ALREADY — the corpus is in a state nobody "
              f"predicted — refusing")
        return 1
    if already:
        print(f"  ({already} anchored rules in "
              f"{sorted(already_files)} were already repaired, as expected "
              f"— those files are committed and the merge does not "
              f"rewrite them)")

    # The keeps are checked AFTER the substitutions, which is the only order
    # in which they mean anything: a widened rule has to have run first.
    for name, reading in MUST_SURVIVE:
        if reading not in texts[name]:
            print(f"  ✗ {name}: 「{reading}」 was destroyed by a rule "
                  f"above — refusing")
            return 1

    if sum(len(t) for t in texts.values()) != total_before:
        print("  ✗ the corpus changed length — refusing")
        return 1
    after = {ch: sum(t.count(ch) for t in texts.values()) for ch in "恒麵"}
    if after["恒"]:
        print(f"  ✗ {after['恒']} 恒 survive — refusing")
        return 1
    if after["麵"]:
        print(f"  ✗ {after['麵']} 麵 — the other asset family's flour — "
              f"refusing")
        return 1

    print(f"\n  {substitutions} substitutions across {len(touched)} files")
    if args.apply:
        for name in sorted(touched):
            (DIR / name).write_text(texts[name], encoding="utf-8")
        print(f"  written → {len(touched)} files under "
              f"{DIR.relative_to(ROOT)}")
    else:
        print("  dry run — nothing written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
