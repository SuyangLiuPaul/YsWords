#!/usr/bin/env python3
"""Corrections only the official 和合本 could settle, one verse at a time.

WHY THIS EXISTS
---------------
`sync_cuv_yhwh_to_publisher.py` brought this edition up to the
publisher's current text, which is the right base: it is their edition
and they have edited 14,718 verses since our snapshot. But their text
is not error-free, and a few of their edits move AWAY from the 和合本
they are an edition of.

The owner's ruling, 2026-09-08: 「参考和合本繁體官方的去决定」. So where
our reading and the publisher's differ and the question is what the
和合本 says, the official edition decides. Read at bible.fhl.net
(VERSION1=unv) and quoted here with the verse, so the next reader can
check the same thing the same way.

Most such repairs already have a tool of their own — dropped
characters, transpositions, speech colons — and those tools were simply
re-run over the new base. This file is for the ones that are nobody
else's: a single verse, a single reading, no class to generalise to.

WHY EACH IS ANCHORED TO ITS VERSE
---------------------------------
Never a global substitution. 反復 -> 反覆 as a rule would rewrite 復活
233 times; the correction that came from reading three verses is
applied to those three. If a fourth appears it gets read, not swept.

Usage:  tools/repair_by_official_cuv.py [--write]
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIMP = os.path.join(ROOT, 'assets', 'cuvs-yhwh.json')
TRAD = os.path.join(ROOT, 'assets', 'cuvs-yhwh-tr.json')

# (verse id, scripts, ours, the official reading, where and why[, the
# settled state a LATER tool leaves it in]). scripts: 's' simplified,
# 't' traditional, 'st' both.
CORRECTIONS = [
    # 复 is one Simplified character standing for three Traditional ones
    # -- 復 (again), 複 (compound), 覆 (turn over) -- and every converter
    # that has touched this text mapped all 265 to 復. Right 262 times.
    ('042001029', 't', '反復思想', '反覆思想', '路加福音 1:29'),
    ('042002019', 't', '反復思想', '反覆思想', '路加福音 2:19'),
    ('047001017', 't', '反復不定', '反覆不定', '哥林多後書 1:17'),

    # The publisher's current text drops the 的, which changes the
    # sentence: 「認耶穌基督是成了肉身來的」 predicates something about
    # Jesus; 「成了肉身來」 leaves the clause hanging. SeekSparks' copy
    # of this same edition has the 的, and so does the official.
    ('062004002', 's', '成了肉身来，', '成了肉身来的，', '約翰一書 4:2'),
    ('062004002', 't', '成了肉身來，', '成了肉身來的，', '約翰一書 4:2'),

    # A leaked opener. The official prints this note SPLIT across two
    # verses -- 23:16 ends 「（有古卷加：」 and 23:17 closes it 「…給他們。）」
    # -- but this app renders a note inside the verse that carries it,
    # and our 23:17 already holds the whole thing. So 23:16's copy of
    # the opener annotates nothing, has no closer, and is the single
    # unpaired bracket that made `repair_orphan_close_bracket.py`
    # refuse to run at all. SeekSparks' copy of this verse ends clean at
    # 釋放了。」 and this makes ours match.
    ('042023016', 's', '把他释放了。 ”〔有古卷在此有：',
     '把他释放了。”', '路加福音 23:16'),
    ('042023016', 't', '把他釋放了。」〔有古卷在此有：',
     '把他釋放了。」', '路加福音 23:16'),

    # --- the two the publisher sync's mirror got wrong ------------
    #
    # Not an editorial question at all: `mirror_publisher_sync_to_tr.py`
    # derived its 简→繁 table by recording only the positions where the
    # two scripts DIFFER, so a character that is usually itself and
    # occasionally something else looked unambiguous. 面 differs only
    # ever as 麵 (107 times), so every 面 the publisher inserted became
    # flour, and 馬太福音 6:2 shipped 「不可在你麵前吹號」 — do not sound
    # a trumpet before your dough. The mirror now counts a character
    # standing opposite ITSELF as a form, which puts 面 back among the
    # 15 ambiguous characters it refuses; these two verses are the
    # damage already written, and they are the only two (every other
    # 麵 in the file is checked and is flour).
    # `repair_transposed_characters.py` then reorders this same phrase
    # to 你前面吹號 (the printed reading), so the settled state is that
    # one and the sixth field says so — otherwise re-running this tool
    # after that one reports a verse it just repaired as drifted.
    ('040006002', 't', '不可在你麵前吹號', '不可在你面前吹號',
     '馬太福音 6:2', '不可在你前面吹號'),
    # Same mechanism, opposite direction: 亿 reached the Traditional as
    # 忆 — a Simplified character — because the pair had never shown the
    # table what 亿 becomes. 雅億 is what this edition prints in the
    # other eleven places the name appears.
    ('007004018', 't', '雅忆用被', '雅億用被', '士師記 4:18'),
    # 馍 is the Simplified form of 饃 (a steamed bun) and has no business
    # in either script here: the word is 模糊. The Simplified file
    # already reads 模糊不清; only the Traditional carries the leak.
    # `repair_cuv_typo_corruptions.py` knows this verse as 饃糊 -> 模糊
    # and refused to run at all while the asset held a third spelling.
    ('046013012', 't', '馍糊不清', '模糊不清', '哥林多前書 13:12'),

    # --- a defect in BOTH scripts, which is why no converter found it --
    #
    # 五壳 is not a word. 以賽亞書 36:17 promises 五穀和新酒 — grain and
    # new wine — and 壳 (a shell) got there in place of 谷/穀 before the
    # script split, so both files carry it and every simplified-leak
    # sweep passes them. Only reading the verse finds this one.
    ('023036017', 's', '有五壳和新酒', '有五谷和新酒', '以賽亞書 36:17'),
    ('023036017', 't', '有五壳和新酒', '有五穀和新酒', '以賽亞書 36:17'),

    # --- punctuation the publisher's current text doubled -----------
    #
    # Three verses where their edit left two marks where there is one.
    # Our copy at HEAD read correctly at all three, so these are
    # regressions in the newer text rather than anything we introduced,
    # and `stray_punctuation_test` names them the moment they land.
    # None is a reading: 「當醒起；！」 and 「日子，，那時辰」 are not
    # something an edition decides, they are a keystroke.
    ('019057008', 's', '当醒起；！', '当醒起！', '詩篇 57:8'),
    ('019057008', 't', '當醒起；！', '當醒起！', '詩篇 57:8'),
    ('040025013', 's', '那日子，，那时辰', '那日子，那时辰', '馬太福音 25:13'),
    ('040025013', 't', '那日子，，那時辰', '那日子，那時辰', '馬太福音 25:13'),
    ('058008002', 's', '所支的，，不是', '所支的，不是', '希伯來書 8:2'),
    ('058008002', 't', '所支的，，不是', '所支的，不是', '希伯來書 8:2'),

    # --- one note inside another --------------------------------
    #
    # 馬太福音 17:21 is a wholly-editorial verse — the whole of it is the
    # publisher's 〔有古卷在此有21節：…〕 — and it is the only one in the
    # edition with a SECOND bracket nested inside the first. `unfold()`
    # in the sync tool matches 〔([^〕]*)〕, which cannot see nesting: it
    # closed the outer note on the inner bracket's 〕 and left 。」〕
    # standing outside as if it were scripture. The other thirteen
    # wholly-editorial verses have no nesting and came through intact.
    #
    # unfold() now refuses to convert a verse whose brackets do not
    # nest cleanly, which is the same rule it already applies to a
    # verse that would be left empty. This entry is the damage already
    # written; the shape it goes back to is the shape its thirteen
    # siblings have.
    ('040017021', 's',
     '<note: 有古卷在此有21节：“至于这一类的鬼，若不祷告、禁食，'
     '它就不出来〔或作："不能赶它出来">。”〕',
     '〔有古卷在此有21节：“至于这一类的鬼，若不祷告、禁食，'
     '它就不出来〔或作："不能赶它出来"〕。”〕', '馬太福音 17:21'),
    ('040017021', 't',
     '<note: 有古卷在此有21節：「至於這一類的鬼，若不禱告、禁食，'
     '它就不出來〔或作："不能趕它出來">。」〕',
     '〔有古卷在此有21節：「至於這一類的鬼，若不禱告、禁食，'
     '它就不出來〔或作："不能趕它出來"〕。」〕', '馬太福音 17:21'),

    # --- found by re-running this repo's own guards over the new base --
    #
    # Each of these is a place the publisher's newer text lost something
    # the official edition prints. They were found by the tests, not by
    # a sweep: every one made an existing assertion fail.

    # 列王紀上 14:5 — the transposition repaired once already, back.
    # Our own tagged corpus still reads 告诉她.
    ('011014005', 's', '告她诉', '告诉她', '列王紀上 14:5'),
    ('011014005', 't', '告她訴', '告訴她', '列王紀上 14:5'),

    # 啟示錄 — the sevenfold refrain lost its ！ six times out of seven.
    # 2:17 alone still reads 就應當聽！, which is what says this was not
    # a decision: an edition that meant to set the refrain with a full
    # stop would not have left one behind.
    ('066002007', 's', '就应当听。', '就应当听！', '啟示錄 2:7'),
    ('066002007', 't', '就應當聽。', '就應當聽！', '啟示錄 2:7'),
    ('066002011', 's', '就应当听。', '就应当听！', '啟示錄 2:11'),
    ('066002011', 't', '就應當聽。', '就應當聽！', '啟示錄 2:11'),
    ('066002029', 's', '就应当听。', '就应当听！', '啟示錄 2:29'),
    ('066002029', 't', '就應當聽。', '就應當聽！', '啟示錄 2:29'),
    ('066003006', 's', '就应当听。', '就应当听！', '啟示錄 3:6'),
    ('066003006', 't', '就應當聽。', '就應當聽！', '啟示錄 3:6'),
    ('066003013', 's', '就应当听。', '就应当听！', '啟示錄 3:13'),
    ('066003013', 't', '就應當聽。', '就應當聽！', '啟示錄 3:13'),
    ('066003022', 's', '就应当听。', '就应当听！', '啟示錄 3:22'),
    ('066003022', 't', '就應當聽。', '就應當聽！', '啟示錄 3:22'),

    # 撒母耳記上 16:11 and 列王紀下 10:13 — a closing quote lost, so the
    # question never closes and the ANSWER opens inside it: 「你的兒子都
    # 在這裏嗎？他回答說：「還有個小的. Our own tagged corpus already
    # reads the official's way, so the reading text had regressed behind
    # the word-tap sheet drawn over it and one verse said two things.
    ('009016011', 's', '都在这里吗？他回答说', '都在这里吗？”他回答说',
     '撒母耳記上 16:11'),
    ('009016011', 't', '都在這裏嗎？他回答說', '都在這裏嗎？」他回答說',
     '撒母耳記上 16:11'),
    ('012010013', 's', '你们是谁？回答说', '你们是谁？”回答说',
     '列王紀下 10:13'),
    ('012010013', 't', '你們是誰？回答說', '你們是誰？」回答說',
     '列王紀下 10:13'),

    # 箴言 30:15 — two cries run together. The official prints
    # 常說：給呀，給呀！ ; the quotation marks are ours and stay.
    ('020030015', 's', '给呀给呀。', '给呀，给呀！', '箴言 30:15'),
    ('020030015', 't', '給呀給呀。', '給呀，給呀！', '箴言 30:15'),

    # 詩篇 104:31 ends on a full-width solidus, the only one in either
    # edition. The official ends on ！.
    ('019104031', 's', '所造的／', '所造的！', '詩篇 104:31'),
    ('019104031', 't', '所造的／', '所造的！', '詩篇 104:31'),

    # 耶利米書 10:5 — 鏇 is turning on a lathe, which is what an idol is
    # made by; 旋 is turning round. The publisher's newer text writes
    # 旋 and the official writes 鏇.
    ('024010005', 's', '是旋成的', '是镟成的', '耶利米書 10:5'),
    ('024010005', 't', '是旋成的', '是鏇成的', '耶利米書 10:5'),

    # 撒母耳記下 2:23 — REVERTED, and left as a question rather than a
    # repair. 𨱔 (U+28C54) is the Simplified form of 鐏 and the
    # Traditional carries it, which IS wrong: the official edition reads
    # 槍鐏. But 𨱔 is outside the BMP and 鐏 is not, so correcting it
    # makes this the one verse pair whose two scripts differ in UTF-16
    # length — and that equality is the foundation the whole
    # Simplified/Traditional correspondence is derived from
    # (`search_synonyms_test`: "every verse pair is the same length once
    # the spaces come out"). Fixing one character by making the pair
    # underivable is a bad trade to make unasked. Recorded for the
    # owner; the character is wrong and the structure is intact.

    # 約書亞記 5:13 — a stray U+2009 THIN SPACE before the closing
    # quote, in both editions. The official has no space there, and
    # neither does any other verse.
    ('006005013', 's', '敌人呢？\u2009”', '敌人呢？”', '約書亞記 5:13'),
    ('006005013', 't', '敵人呢？\u2009」', '敵人呢？」', '約書亞記 5:13'),

    # 約伯記 31:36 — 敵我敵者 is not a word. The official reads 敵我者,
    # and so did our own text before the sync and so does the tagged
    # corpus. Verified present verbatim in the publisher's own
    # `bsapp_bible_cuvs` row, so it is theirs.
    ('018031036', 's', '那敌我敌者', '那敌我者', '約伯記 31:36'),
    ('018031036', 't', '那敵我敵者', '那敵我者', '約伯記 31:36'),

    # 歷代志上 21:17 — the 的 moved four characters right, so the
    # sentence asks 「吩咐數點百姓不是我嗎」 and then says 「行了惡的」,
    # which is neither clause's reading. Official: 吩咐數點百姓的不是我
    # 嗎？我犯了罪，行了惡. Our own previous text and the tagged corpus
    # both agree with the official. Not caught by
    # `settle_transpositions_by_witness.py` because this verse differs
    # from the witness in three other places at once.
    ('013021017', 's', '数点百姓不是我吗？我犯了罪，行了恶的，',
     '数点百姓的不是我吗？我犯了罪，行了恶，', '歷代志上 21:17'),
    ('013021017', 't', '數點百姓不是我嗎？我犯了罪，行了惡的，',
     '數點百姓的不是我嗎？我犯了罪，行了惡，', '歷代志上 21:17'),
]

# CHECKED AND LEFT ALONE
# ----------------------
# 約書亞記 10:3 希伯崙王何咸. 咸 looks like a Simplified leak for 鹹 and
# is not: the official edition prints 何咸, so both our scripts are
# right and SeekSparks' copy — which reads 何鹹 — is the one that
# differs. Recorded here so the next sweep does not "repair" it.


def main():
    write = '--write' in sys.argv
    files = {'s': (SIMP, json.load(open(SIMP, encoding='utf-8'))),
             't': (TRAD, json.load(open(TRAD, encoding='utf-8')))}
    index = {k: {r['id']: r for r in rows} for k, (_, rows) in files.items()}

    applied = already = failed = 0
    touched = set()
    for entry in CORRECTIONS:
        vid, scripts, old, new, where = entry[:5]
        settled = entry[5] if len(entry) > 5 else None
        for k in scripts:
            r = index[k].get(vid)
            if r is None:
                print('MISSING  %s %s  %s' % (vid, k, where))
                failed += 1
                continue
            if old not in r['text']:
                if new in r['text'] or (settled and settled in r['text']):
                    print('already  %s %s  %s' % (vid, k, where))
                    already += 1
                else:
                    print('NO MATCH %s %s  %s: neither %r nor %r'
                          % (vid, k, where, old, new))
                    failed += 1
                continue
            if r['text'].count(old) != 1:
                print('AMBIGUOUS %s %s  %s: %r appears %d times'
                      % (vid, k, where, old, r['text'].count(old)))
                failed += 1
                continue
            r['text'] = r['text'].replace(old, new)
            print('applied  %s %s  %s  %s -> %s'
                  % (vid, k, where, old, new))
            applied += 1
            touched.add(k)

    print('\napplied %d, already correct %d, could not apply %d'
          % (applied, already, failed))
    if failed:
        raise SystemExit('REFUSING TO WRITE: go and read the verse rather '
                         'than loosening this')
    if not write:
        print('(dry run; pass --write)')
        return
    for k in sorted(touched):
        path, rows = files[k]
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print('WROTE %s' % path)


if __name__ == '__main__':
    main()
