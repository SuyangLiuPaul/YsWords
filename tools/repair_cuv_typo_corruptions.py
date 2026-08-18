#!/usr/bin/env python3
"""Repair 16 transcription errors in the CUV verse text — a DIFFERENT defect family
from the eighteen converter-hole instalments that precede it.

Every instalment so far fixed damage done by the Simplified→Traditional
converter: our Simplified source was right, `opencc` picked the wrong member of
a one-to-many class, and only the Traditional asset was wrong. These sixteen
are the opposite shape. They are wrong in the Simplified asset TOO, so they
predate the conversion. No converter oracle can find them, which is why
eighteen passes over the same corpus missed every one.

WHAT THEY ACTUALLY ARE — and an earlier draft of this docstring got it wrong.
  It said our asset alone carried these and every other copy of the CUV was
  clean. That is false, and an adversarial check broke it: BibleHub's published
  CUV reproduces thirteen of them verbatim, 驢恉骨 and 扔菏 and 犰多 included.
  They are transcription errors in the shared DIGITAL CUV lineage — the
  Online Bible e-text that most Chinese Bible software imported — and we
  inherited them. They are not readings of the printed 和合本.

  That distinction is what makes the repair legitimate rather than editorial.
  We are not emending the CUV; we are restoring what the printed CUV says
  against a transcription that lost it.

THE EVIDENCE, AND WHAT EACH PIECE IS ACTUALLY WORTH
  * Our own corpus spells the same word correctly everywhere else, at ratios
    no editorial hypothesis survives — 囑咐 74:1, 自己 1509:2, 斑鳩 14:1,
    雅億 11:1, 如此如此 17:1, 瑕疵 9:1, 朵多 4:1, 腮骨 4:2, 巳初 2:1. This is
    the strongest single piece and it needs no external source at all.
  * The Traditional witness, git blob 7a2dc43, reads the corrected form at all
    sixteen, and Tertullus is misspelt at BOTH his occurrences, 徒 24:1 and
    24:2 — `cuvs-plus.json` repaired only the first, which is a useful reminder
    that a partially repaired branch is not a clean witness.
  * `cuvs-plus.json` in the sibling SeekSparks repo (read-only from here) is a
    partially-repaired branch of the same lineage: it is already right at
    thirteen and still wrong at 雅忆, 馍糊 and 帖士罗 (徒 24:2). So it
    CORROBORATES thirteen and abstains on three — it does not independently confirm all fifteen, and the
    ones it abstains on rest on the corpus ratio plus the Traditional witness.
  * The Strong's-tagged corpus under `assets/tagged/` is NOT an independent
    witness, though a first draft of this fix treated it as one. It shares
    thirteen of the errors, and carries one of its own — 王上 14:5 reads
    「告她诉」 where the verse asset beside it reads 告訴她, repaired here too.
    It is right at 腮骨 and 凶淫, which is worth something, but only that.

TWO CHOICES THAT ARE OURS AND NOT THE WITNESS'S
  * 士 20:6 is written 兇淫 in Traditional and 凶淫 in Simplified. Our
    Traditional corpus holds 47 兇 and zero 凶, and the Traditional witness
    also reads 兇淫 at this verse, so 兇 is what keeps us internally
    consistent. The printed CUV uses 凶, and our 47:0 split against it is a
    likely systematic over-conversion — real, larger than this fix, queued.
  * 代上 11:12 is written 朵多, matching our own four other occurrences. The
    printed CUV sets 朶; switching one of five would create the inconsistency
    this instalment exists to remove.

DELIBERATELY OUT OF SCOPE
  創 45:10 「你和你我兒子孫子」 was in an earlier draft of this fix and was
  REMOVED. Wikisource's transcription of the printed 1919 和合本 reads 你我
  there too, so correcting it to 你的 would be an emendation of the CUV rather
  than a repair of a transcription, and that is the user's call, not ours.

  Eleven further positions where both witnesses disagree with us but our
  reading is a real word that reads correctly — 意料/逆料 (賽 64:3, 徒 25:18,
  where the printed CUV does read 逆料), 留/等 (徒 27:31), 消息/信息
  (徒 28:15), 異象/顯現 (林後 12:1), 銷滅/消滅 (帖前 5:19), 開始/下手
  (林後 8:10), 對/愛 (林後 7:15), 在/了 (林後 5:19), 歸到/歸他 (創 49:33),
  and 徒 28:6 and 28:17 where the whole clause differs. Nothing false is
  printed today, so they are queued rather than swept.

  Also queued, not touched: 自已 in two sermon transcripts and two Strong's
  glosses. 於沙希悉 at 代上 3:20 was queued here too and has since been fixed
  separately by tools/repair_tr_jushab_hesed.py — it is a converter hole
  rather than a base-text typo, so it did not belong in this family.

Idempotent. Refuses on any drift: every position is verified to hold the bad
reading (or the good one already) before anything is written.
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FLAT_SC = ROOT / "assets" / "cuvs-yhwh.json"
FLAT_TR = ROOT / "assets" / "cuvs-yhwh-tr.json"
TAGGED = ROOT / "assets" / "tagged" / "cuvs-yhwh"

# verse id -> (reference, simplified bad, simplified good, traditional bad,
#              traditional good, tagged file or None, tagged verse key)
FIXES = [
    ("007004018", "士 4:18", "雅忆用被", "雅亿用被",
     "雅憶用被", "雅億用被", "judges", "4:18"),
    ("007015016", "士 15:16", "驴恉骨", "驴腮骨",
     "驢恉骨", "驢腮骨", None, None),
    ("007015017", "士 15:17", "那恉骨", "那腮骨",
     "那恉骨", "那腮骨", None, None),
    ("007020006", "士 20:6", "扔菏丑恶", "凶淫丑恶",
     "扔菏醜惡", "兇淫醜惡", None, None),
    ("010014025", "撒下 14:25", "毫无暇疵", "毫无瑕疵",
     "毫無暇疵", "毫無瑕疵", "2_samuel", "14:25"),
    ("011002001", "王上 2:1", "就嘱吩", "就嘱咐",
     "就囑吩", "就囑咐", "1_kings", "2:1"),
    ("011014005", "王上 14:5", "你当此此如此", "你当如此如此",
     "你當此此如此", "你當如此如此", "1_kings", "14:5"),
    ("013011012", "代上 11:12", "犰多", "朵多",
     "犰多", "朵多", "1_chronicles", "11:12"),
    ("019080015", "詩 80:15", "为自已所", "为自己所",
     "為自已所", "為自己所", "psalms", "80:15"),
    ("019080017", "詩 80:17", "为自已所", "为自己所",
     "為自已所", "為自己所", "psalms", "80:17"),
    ("024012014", "耶 12:14", "所承巡菇业", "所承受产业",
     "所承巡菇業", "所承受產業", "jeremiah", "12:14"),
    ("041015025", "可 15:25", "是已初", "是巳初",
     "是已初", "是巳初", "mark", "15:25"),
    ("042002024", "路 2:24", "班鸠", "斑鸠",
     "班鳩", "斑鳩", "luke", "2:24"),
    ("044024001", "徒 24:1", "帖士罗", "帖土罗",
     "帖士羅", "帖土羅", "acts", "24:1"),
    ("044024002", "徒 24:2", "帖士罗", "帖土罗",
     "帖士羅", "帖土羅", "acts", "24:2"),
    ("046013012", "林前 13:12", "馍糊不清", "模糊不清",
     "饃糊不清", "模糊不清", "1_corinthians", "13:12"),
]

# The tagged corpus was built separately and is already correct at three of the
# positions above, so a tagged fix is only expected where it is still wrong.
# Jeremiah 12:14 is half-corrupt there: it reads 所承巡产业, so only 巡 remains.
# The flat-asset search strings carry leading context to make them unique in a
# 31,102-verse blob; in the tagged corpus that context can straddle a token
# boundary, and a replacement spanning tokens would move the Strong's
# alignment. These are the same repair keyed to the token that actually holds
# it. 耶 12:14 is also half-repaired there already — it reads 所承巡产业, so
# only 巡 is left.
TAGGED_OVERRIDE = {
    "010014025": ("暇疵", "瑕疵"),
    "024012014": ("所承巡", "所承受"),
}

# Defects that exist ONLY in the tagged corpus, so the flat assets have nothing
# to repair. 王上 14:5 there reads 「你當此此如此告她诉」 — two separate
# corruptions in one verse, the second a transposition the flat asset does not
# have.
TAGGED_ONLY = [
    ("1_kings", "14:5", "告她诉", "告诉她"),
]


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def dump_flat(path, data):
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def dump_tagged(path, data):
    path.write_text(
        json.dumps(data, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )


def repair_flat(path, index):
    verses = load(path)
    by_id = {v["id"]: v for v in verses}
    changed = 0
    for fix in FIXES:
        vid, ref, bad, good = fix[0], fix[1], fix[index], fix[index + 1]
        verse = by_id.get(vid)
        if verse is None:
            sys.exit(f"REFUSING: {path.name} has no verse {vid} ({ref})")
        text = verse["text"]
        if bad in text:
            verse["text"] = text.replace(bad, good)
            changed += 1
        elif good not in text:
            sys.exit(
                f"REFUSING: {path.name} {ref} holds neither {bad!r} nor "
                f"{good!r} — the asset has drifted:\n  {text[:120]}"
            )
    if changed:
        dump_flat(path, verses)
    return changed


def repair_tagged():
    changed = 0
    for fix in FIXES:
        vid, ref, bad, good = fix[0], fix[1], fix[2], fix[3]
        book, key = fix[6], fix[7]
        if book is None:
            continue
        bad, good = TAGGED_OVERRIDE.get(vid, (bad, good))
        path = TAGGED / f"{book}.json"
        data = load(path)
        tokens = data.get(key)
        if tokens is None:
            sys.exit(f"REFUSING: tagged/{book}.json has no verse {key} ({ref})")
        joined = "".join(t["w"] for t in tokens)
        if bad not in joined:
            if good not in joined:
                sys.exit(
                    f"REFUSING: tagged/{book}.json {ref} holds neither "
                    f"{bad!r} nor {good!r}:\n  {joined[:120]}"
                )
            continue
        hits = [t for t in tokens if bad in t["w"]]
        if len(hits) != 1:
            sys.exit(
                f"REFUSING: tagged/{book}.json {ref} — {bad!r} spans "
                f"{len(hits)} tokens, not 1; the Strong's alignment would move"
            )
        hits[0]["w"] = hits[0]["w"].replace(bad, good)
        dump_tagged(path, data)
        changed += 1
    for book, key, bad, good in TAGGED_ONLY:
        path = TAGGED / f"{book}.json"
        data = load(path)
        tokens = data[key]
        hits = [t for t in tokens if bad in t["w"]]
        if not hits:
            if good not in "".join(t["w"] for t in tokens):
                sys.exit(f"REFUSING: tagged/{book}.json {key} lost {good!r}")
            continue
        if len(hits) != 1:
            sys.exit(f"REFUSING: tagged/{book}.json {key} — {bad!r} spans "
                     f"{len(hits)} tokens, not 1")
        hits[0]["w"] = hits[0]["w"].replace(bad, good)
        dump_tagged(path, data)
        changed += 1
    return changed


def main():
    sc = repair_flat(FLAT_SC, 2)
    tr = repair_flat(FLAT_TR, 4)
    tg = repair_tagged()
    print(f"cuvs-yhwh.json:     {sc} verse(s) repaired")
    print(f"cuvs-yhwh-tr.json:  {tr} verse(s) repaired")
    print(f"tagged/cuvs-yhwh/:  {tg} verse(s) repaired")
    if sc == tr == tg == 0:
        print("already clean — nothing to do")


if __name__ == "__main__":
    main()
