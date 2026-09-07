#!/usr/bin/env python3
"""The Traditional sermon transcripts print the measure word 隻 where the
speaker said 只 (only) — 144 positions, all read individually.

READ THE ITEM BEFORE THE CODE. `assets/sermons/zh-TW/` was produced by
`opencc -c s2t`, phrase-aware and generally good (see
`tools/repair_tw_sermon_spot_glyphs.py`'s docstring for the evidence). But
its phrase table treats every Simplified 只 as the classifier 隻 unless the
surrounding phrase is in its table, and 只 is also Simplified for the adverb
"only" (只是/只要/只有/只能/…). Where the table doesn't carry that reading,
s2t writes the classifier anyway — so the corpus reads 「這**隻**能治標不
治本」, 「就是**隻**要擯棄」, 「而是**隻**有一件是不可缺少的」ーnot a
variant, a different word. This is a converter hole, but a NARROWER one than
CUV's: most of the corpus's 671 隻 are correct (一隻眼, 一隻手, 一隻羊,
隻字不提/未提, 船隻, 那隻, 隻身, 形單影隻 and the like), so this is not
`tools/repair_tr_*.py`'s territory and a blanket sweep would destroy ~530
correct positions.

THE DISCRIMINATOR — three passes, not one regex, because the first two
drafts of this script each missed a real class before this one shipped

  Pass 1 — the safe cues. A classifier is reliably preceded by a numeral,
  每/幾/數/百/千/萬, or is one of the fixed words 隻字/片言隻語/隻言片語/
  形單影隻/隻身/隻手遮天/船隻. None of those words can also be read as the
  adverb, so this pass needs no per-position reading — EXCEPT 船隻 has one
  word-boundary trap, below.

  Pass 2 — 那隻 and 這隻, read individually, all 106 of them, not sampled.
  這/那 are NOT a safe cue on their own: unlike a numeral, 這/那 can also
  stand alone as the sentence's subject ("this/that"), and 「這只有…才…」
  ("this can only… by…"), 「那只不過是…」("that's merely…") are exactly
  as common in this register as 「這隻鳥」("this bird"). An earlier draft
  of this script treated 那/這 as a blanket classifier cue the same way it
  treats a numeral, and a refuter's spot-check caught the result: it had
  left in 「這隻能治標不治本」(014.txt) — the corpus's OWN clearest example
  of the defect — because 這 preceded it. 31 of the 144 rules below come
  from this pass, none reachable by a trailing-character rule alone (two,
  031.txt「那隻證明你不是基督徒」and 099.txt「那隻意味著」, have a
  following character — 證, 意 — that never appeared in any list drafted
  for this corpus, because nothing shorter than reading the sentence finds
  them).

  Pass 3 — everything else (not preceded by a numeral cue or 那/這). Here
  隻 immediately followed by a function word or verb it cannot quantify
  (有/要/是/在/對/為/說/關/想/能/給/讓/打/用/影/與/求/委/照/保/撒/考/向/坐/
  看/跟/消/授/作/以/從/致/追/信/背/需/帶/適/出/針/買/願) is the defect,
  because no noun begins with any of those characters — but each of the
  112 positions here was still read, because a few shapes look like this
  and are not: 「有隻鳥叫了一聲」(232.txt) and 「被某隻蚊子煩擾著」
  (410-1.txt) are the classifier with the 一 dropped (colloquial Chinese
  drops it freely — English does the same: "a bird", not "a one bird"),
  and fy-ws02.txt's running metaphor 「我是隻狼」…「其實是隻披著羊皮的
  狼」 is the same dropped-一 shape after 是 rather than 有, repeated five
  times in one sermon.

  THE 船隻 TRAP, found checking every occurrence of that word rather than
  trusting the substring match: 102.txt reads 「汽船隻需二十分鐘」 — a
  STEAMBOAT (汽船) that only NEEDS twenty minutes — where 船隻 (vessels) is
  not the word at all; the 船 belongs to 汽船 and the 隻 that follows is the
  adverb. A plain "does the string 船隻 appear" check would have kept this
  one wrong. Confirmed against `assets/sermons/zh-CN/102.txt`, which reads
  「汽船只需二十分钟」.

  A rule keyed on the trailing character alone — even restricted to Pass 3
  — would still be unsafe applied corpus-wide: 隻有 appears 30 times in this
  corpus and only 18 (all in Pass 3) are the adverb, the other 12 being
  numeral/每/那/這-cued classifier+有 readings like 「這隻有趣的飛蛾」("this
  interesting moth") or classifier+relative-clause+有 readings; 隻能 is 9
  and only 3 (Pass 3) are. Every rule below is therefore anchored to one
  exact position in one exact file, not to a pattern.

THERE IS NO WITNESS EDITION FOR SERMON TEXT. Every rule rests on the
sentence alone, quoted in the file at its anchor, plus the Simplified twin's
position for 082.txt and 102.txt, checked directly. Not one word changes;
every rule is 隻→只, one character for one character, and the script
refuses if any string changes length.

Dry-run by default; --apply writes. Re-running after --apply is a no-op.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIR = ROOT / "assets/sermons/zh-TW"

# (file, wrong, right) — wrong/right differ in exactly one character, 隻→只.
# `wrong` is the minimal substring that is unique within that file, so a
# plain `str.replace` cannot land on the wrong occurrence.
RULES = (
    # --- Pass 3: 隻 immediately followed by a function word or verb -------
    ("004.txt", "，還是隻是真理", "，還是只是真理"),
    ("009.txt", "哭不是隻與逼迫", "哭不是只與逼迫"),
    ("017.txt", "清心是隻求一件", "清心是只求一件"),
    ("018.txt", "，不是隻委身兩", "，不是只委身兩"),
    ("018.txt", "你要是隻打算委", "你要是只打算委"),
    ("027.txt", "是不是隻照耀基", "是不是只照耀基"),
    ("040.txt", "，而是隻能用豬", "，而是只能用豬"),
    ("040.txt", "，就是隻要擯棄", "，就是只要擯棄"),
    ("047.txt", "呢？是隻為今天", "呢？是只為今天"),
    ("047.txt", "者不是隻保住了", "者不是只保住了"),
    ("063.txt", "，可是隻要對他", "，可是只要對他"),
    ("067.txt", "他不是隻說善—", "他不是只說善—"),
    ("071.txt", "，可是隻要你向", "，可是只要你向"),
    ("075.txt", "有很多隻用嘴巴", "有很多只用嘴巴"),
    ("076.txt", "夫不是隻在撒種", "夫不是只在撒種"),
    ("078.txt", "他不是隻撒了一", "他不是只撒了一"),
    ("082.txt", "，而豬隻關心食", "，而豬只關心食"),
    ("082.txt", "，而是隻有一件", "，而是只有一件"),
    ("086.txt", "有多少隻是為了", "有多少只是為了"),
    ("088.txt", "神不是隻給你另", "神不是只給你另"),
    ("092.txt", "？還是隻是不去", "？還是只是不去"),
    ("093.txt", "為這是隻有神才", "為這是只有神才"),
    ("097.txt", '經不是隻說"全', '經不是只說"全'),
    ("099.txt", "且不是隻在過去", "且不是只在過去"),
    ("100.txt", "們最多隻打五折", "們最多只打五折"),
    ("100.txt", "，還是隻是一個", "，還是只是一個"),
    ("101.txt", "大都是隻關心自", "大都是只關心自"),
    ("102.txt", "，汽船隻需二十", "，汽船只需二十"),
    ("105.txt", "，就是隻考慮自", "，就是只考慮自"),
    ("105.txt", "，可是隻要一言", "，可是只要一言"),
    ("126.txt", "。但是隻要你有", "。但是只要你有"),
    ("131.txt", "，可是隻要你穿", "，可是只要你穿"),
    ("137.txt", "—不是隻向門徒", "—不是只向門徒"),
    ("206.txt", "，而是隻要你願", "，而是只要你願"),
    ("206.txt", "穌不是隻對我一", "穌不是只對我一"),
    ("211.txt", "，不是隻坐回來", "，不是只坐回來"),
    ("217.txt", '"不是隻有一件', '"不是只有一件'),
    ("219.txt", "們還是隻看第十", "們還是只看第十"),
    ("219.txt", "。而是隻為那些", "。而是只為那些"),
    ("219.txt", "，還是隻是許多", "，還是只是許多"),
    ("224.txt", "，不是隻是為了", "，不是只是為了"),
    ("224.txt", "人中是隻有學者", "人中是只有學者"),
    ("231.txt", "。不是隻有基督", "。不是只有基督"),
    ("244.txt", "我不是隻讓你看", "我不是只讓你看"),
    ("317.txt", "你最多隻能達到", "你最多只能達到"),
    ("323.txt", "。不是隻跟從一", "。不是只跟從一"),
    ("325.txt", "穌也是隻消一句", "穌也是只消一句"),
    ("326.txt", "它不是隻說好聽", "它不是只說好聽"),
    ("329.txt", "原來是隻授予大", "原來是只授予大"),
    ("341.txt", "們最多隻能繼續", "們最多只能繼續"),
    ("341.txt", "—不是隻有當你", "—不是只有當你"),
    ("352.txt", "，還是隻是神話", "，還是只是神話"),
    ("357.txt", "你。它隻影響你", "你。它只影響你"),
    ("357.txt", "失。它隻影響你", "失。它只影響你"),
    ("364.txt", "，而是隻作為神", "，而是只作為神"),
    ("365.txt", "命不是隻以立體", "命不是只以立體"),
    ("366.txt", "代這是隻有聖職", "代這是只有聖職"),
    ("393.txt", "他還是隻是嘴上", "他還是只是嘴上"),
    ("398.txt", "是不是隻有我一", "是不是只有我一"),
    ("410-2.txt", "有很多隻在星期", "有很多只在星期"),
    ("411.txt", "們不是隻從聖經", "們不是只從聖經"),
    ("423.txt", "我總是隻致力於", "我總是只致力於"),
    ("425.txt", "，還是隻是為了", "，還是只是為了"),
    ("763.txt", "，一是隻追求從", "，一是只追求從"),
    ("763.txt", "\n不是隻有牧師", "\n不是只有牧師"),
    ("765.txt", "有太多隻想享受", "有太多只想享受"),
    ("CP70.txt", "說，別隻信我的", "說，別只信我的"),
    ("CP70.txt", "。猶大隻背叛了", "。猶大只背叛了"),
    ("EC010.txt", "人性是隻需要很", "人性是只需要很"),
    ("EC013.txt", "羅不是隻說他看", "羅不是只說他看"),
    ("EC013.txt", "。不是隻有一個", "。不是只有一個"),
    ("EC014.txt", "，不是隻在永恆", "，不是只在永恆"),
    ("EC018.txt", "他不是隻在那裏", "他不是只在那裏"),
    ("EC018.txt", "們不是隻是在—", "們不是只是在—"),
    ("c106.txt", "—不是隻對保羅", "—不是只對保羅"),
    ("c106.txt", "。不是隻對巴拿", "。不是只對巴拿"),
    ("c106.txt", "。不是隻對彼得", "。不是只對彼得"),
    ("fy-bg01.txt", "，可是隻要他屬", "，可是只要他屬"),
    ("fy-bp02.txt", "！不單隻對教會", "！不單只對教會"),
    ("fy-bp06.txt", "，還是隻帶給你", "，還是只帶給你"),
    ("fy-lq02.txt", "罪不是隻在教會", "罪不是只在教會"),
    ("fy-mt111.txt", "，就是隻關心外", "，就是只關心外"),
    ("fy-mt58.txt", "教導是隻要相信", "教導是只要相信"),
    ("fy-mt59.txt", "，還是隻想在一", "，還是只想在一"),
    ("fy-mt60.txt", "是不是隻想了解", "是不是只想了解"),
    ("fy-mt61.txt", "？是不是隻有主耶穌", "？是不是只有主耶穌"),
    ("fy-mt61.txt", "，是不是隻有主耶穌", "，是不是只有主耶穌"),
    ("fy-mt61.txt", "記號是隻給那些", "記號是只給那些"),
    ("fy-mt62.txt", "是不是隻想利用", "是不是只想利用"),
    ("fy-mt80.txt", "不單單隻適用於", "不單單只適用於"),
    ("fy-mt91.txt", "柄不是隻給了一", "柄不是只給了一"),
    ("fy-nm02.txt", "是不是隻要踩到", "是不是只要踩到"),
    ("fy-nm07.txt", "樣都是隻有神的", "樣都是只有神的"),
    ("fy-nm13.txt", "他沒有隻讓義人", "他沒有只讓義人"),
    ("fy-nm13.txt", "也沒有隻讓義人", "也沒有只讓義人"),
    ("fy-nm16.txt", "。若是隻出現了", "。若是只出現了"),
    ("fy-rms07-01.txt", "是不是隻關注猶", "是不是只關注猶"),
    ("fy-rms07-01.txt", "是不是隻針對猶", "是不是只針對猶"),
    ("fy-rms07-02.txt", " 但是隻要他小", " 但是只要他小"),
    ("fy-sm14.txt", "是不是隻買了一", "是不是只買了一"),
    ("fy-sm17.txt", "，就是隻願拿、", "，就是只願拿、"),
    ("fy-sm19.txt", "是不是隻在商店", "是不是只在商店"),
    ("fy-sm28.txt", "他還是隻用二十", "他還是只用二十"),
    ("fy-sm34.txt", "們大多隻有頭腦", "們大多只有頭腦"),
    ("fy-sm52.txt", "，可是隻有極少", "，可是只有極少"),
    ("fy-topm_05.txt", "哥林多隻是聖經", "哥林多只是聖經"),
    ("fy-trc05r.txt", "，不是隻為了自", "，不是只為了自"),
    ("fy-trc05r.txt", "，不是隻為了救", "，不是只為了救"),
    ("fy-trc05r.txt", "戰不是隻要上戰", "戰不是只要上戰"),
    ("fy-trc06.txt", "體不是隻有眼睛", "體不是只有眼睛"),
    ("fy-trc06.txt", "\n不是隻有傳道", "\n不是只有傳道"),
    ("fy-trc06.txt", "。不是隻有全職", "。不是只有全職"),

    # --- Pass 2: 那隻/這隻 read individually, all 106, not sampled --------
    ("014.txt", "然而這隻能治標不治本", "然而這只能治標不治本"),
    ("029.txt", "那隻不過是一段古英語", "那只不過是一段古英語"),
    ("031.txt", "禱告，那隻證明你不是基督徒", "禱告，那只證明你不是基督徒"),
    ("099.txt", "他所以神就不存在了。那隻意味著",
     "他所以神就不存在了。那只意味著"),
    ("139.txt", "免得我們以為這隻適用於法利賽人", "免得我們以為這只適用於法利賽人"),
    ("149.txt", "這隻能通過比喻性語言的力量", "這只能通過比喻性語言的力量"),
    ("150.txt", "向所有人可見，那隻能意味著一件事",
     "向所有人可見，那只能意味著一件事"),
    ("219.txt", "或女兒（這隻有靠著他的恩典才可能）",
     "或女兒（這只有靠著他的恩典才可能）"),
    ("224.txt", "在復活的生命中。但這隻有在你被聖靈充滿",
     "在復活的生命中。但這只有在你被聖靈充滿"),
    ("231.txt", "是可能的，但這隻有藉著神的大能通過聖靈",
     "是可能的，但這只有藉著神的大能通過聖靈"),
    ("246.txt", "的咔嗒聲。這隻意味著我沒有裝實彈", "的咔嗒聲。這只意味著我沒有裝實彈"),
    ("331.txt", "所充滿。這隻有如他在第16節指出的", "所充滿。這只有如他在第16節指出的"),
    ("331.txt", "才能成就。這隻有藉著神的靈才有可能",
     "才能成就。這只有藉著神的靈才有可能"),
    ("343.txt", "存在於你裏面，但這隻有在道被理解為活的東西時才有意義。\n\n在",
     "存在於你裏面，但這只有在道被理解為活的東西時才有意義。\n\n在"),
    ("343.txt", "存在你裏面，但這隻有在道被理解為活的東西時才有意義。\n\n在",
     "存在你裏面，但這只有在道被理解為活的東西時才有意義。\n\n在"),
    ("344.txt", "同樣的原則。如果你認為這隻適用於舊約，那麼你也不瞭解",
     "同樣的原則。如果你認為這只適用於舊約，那麼你也不瞭解"),
    ("344.txt", "沒有救藥。\n\n如果你認為這隻適用於舊約，讓我告訴你",
     "沒有救藥。\n\n如果你認為這只適用於舊約，讓我告訴你"),
    ("412.txt", "你管那叫什麼？那隻不過是在需要的時候利用神",
     "你管那叫什麼？那只不過是在需要的時候利用神"),
    ("C115.txt", "換句話說。這隻有藉著神的大能才能成就",
     "換句話說。這只有藉著神的大能才能成就"),
    ("CP37.txt", "這又有什麼意義呢 那隻不過是相信一宗",
     "這又有什麼意義呢 那只不過是相信一宗"),
    ("EC003.txt", "我愛我的母親，而這隻有在耶穌進入我生命之後",
     "我愛我的母親，而這只有在耶穌進入我生命之後"),
    ("EC015.txt", "感受到了神心中的負擔。這隻有一個解釋",
     "感受到了神心中的負擔。這只有一個解釋"),
    ("M5.txt", "聯繫起來。這隻有一種方式可以實現", "聯繫起來。這只有一種方式可以實現"),
    ("fy-bp02.txt", "便已抵達終點，其實那隻不過是整個旅程的第一步",
     "便已抵達終點，其實那只不過是整個旅程的第一步"),
    ("fy-cm03.txt", "是因為衆人都相信耶穌 那隻不過是羊羣的效應",
     "是因為衆人都相信耶穌 那只不過是羊羣的效應"),
    ("fy-im21.txt", "如果你以為明天會更好，這隻能說明你還不明白局勢",
     "如果你以為明天會更好，這只能說明你還不明白局勢"),
    ("fy-im21.txt", "開玩笑吧，這隻能算是個小山丘", "開玩笑吧，這只能算是個小山丘"),
    ("fy-mt85.txt", "將要得著生命。”我們以為這隻適用於非基督徒",
     "將要得著生命。”我們以為這只適用於非基督徒"),
    ("fy-nm13.txt", "為什麼要給忘恩的或者惡人呢？這隻會縱容他們行惡",
     "為什麼要給忘恩的或者惡人呢？這只會縱容他們行惡"),
    ("fy-ws02.txt", "狼羣不會因喫羊而轉變，(那隻不過是狼的本性)",
     "狼羣不會因喫羊而轉變，(那只不過是狼的本性)"),
    ("fy-ws04.txt", "比擬基督徒的生命 因為這隻會榮耀人",
     "比擬基督徒的生命 因為這只會榮耀人"),

    # --- one more: a numeral cue that isn't a classifier's numeral --------
    # 十分之一 ("one tenth") ends in the numeral 一, which Pass 1's cue check
    # took for a classifier count. It counts a FRACTION, not an animal, so
    # the 隻 after it is still the adverb. Found only by re-deriving the
    # discriminator's failure modes after the 那/這 gap surfaced — this is
    # the same shape (a cue character that isn't functioning as a cue) and
    # the corpus has exactly one of it. Confirmed against zh-CN/fy-sm16.txt,
    # which reads 「十分之一只不过是在表示」.
    ("fy-sm16.txt", "十分之一隻不過是在表示", "十分之一只不過是在表示"),
)

# Readings the rules must NOT reach — the classifier shapes that look most
# like the defect. Every one is a near-miss for a rule above it.
MUST_SURVIVE = (
    ("232.txt", "有隻鳥叫了一聲"),        # 有 + 隻 + noun, "a bird"
    ("410-1.txt", "被某隻蚊子煩擾著"),     # 某 + 隻 + noun, "a mosquito"
    ("fy-ws02.txt", "我是隻狼"),           # 是 + 隻 + noun, "is a wolf"
    ("fy-ws02.txt", "我仍然會是隻狼"),
    ("fy-ws02.txt", "其實是隻披著羊皮的狼"),
    ("fy-ws02.txt", "內裏仍然是隻狼"),
    ("fy-ws02.txt", "你內裏卻仍然是隻狼"),
    ("fy-ws02.txt", "要從我這隻狼的身上"),  # 這 + 隻 + noun, same file
    ("018.txt", "隻字不提"),               # the lexical keep, not a cue
    ("049.txt", "船隻"),                   # the lexical keep, checked at
    ("148.txt", "船隻可能會延誤"),         # every occurrence — 102.txt's
    ("341.txt", "保持船隻不沉"),           # 汽船隻需 is the one that ISN'T
    ("fy-mt62.txt", "形單影隻"),
    ("fy-sm14.txt", "買了一隻胳膊"),       # numeral-cued classifier, untouched
    ("083.txt", "一隻需要被控制的怪物"),   # classifier + relative clause +
    ("092.txt", "一兩隻出沒"),             # noun, or classifier-as-pronoun —
    ("244.txt", "這隻在空中飛的小甲蟲"),   # both shapes a trailing-character
    ("324.txt", "我把這隻帶到聖殿獻祭"),   # rule alone would have corrupted
    ("364.txt", "另一隻是淺色的"),
    ("385.txt", "一隻能夠勝過狼羣的羊羔"),
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    texts = {p.name: p.read_text(encoding="utf-8")
             for p in sorted(DIR.glob("*.txt"))}

    for name, reading in MUST_SURVIVE:
        if reading not in texts.get(name, ""):
            print(f"  ✗ {name}: 「{reading}」 is gone — the survey behind "
                  f"these rules no longer matches the corpus — refusing")
            return 1

    before = sum(t.count("隻") for t in texts.values())

    already = 0
    touched: set[str] = set()
    for name, wrong, right in RULES:
        t = texts.get(name)
        if t is None:
            print(f"  ✗ {name} is not in the corpus — refusing")
            return 1
        n = t.count(wrong)
        if n == 0:
            if t.count(right) == 1:
                already += 1
                continue
            print(f"  ✗ {name}: 「{wrong}」 is gone and 「{right}」 is not "
                  f"there either — the corpus has moved under this script "
                  f"— refusing")
            return 1
        if n != 1:
            print(f"  ✗ {name}: 「{wrong}」 matches {n} times, expected "
                  f"exactly 1 — refusing")
            return 1
        new = t.replace(wrong, right)
        if len(new) != len(t):
            print(f"  ✗ {name}: 「{wrong}」 changed the length of the "
                  f"transcript — this repair is one character for one "
                  f"character and never a rewording — refusing")
            return 1
        texts[name] = new
        touched.add(name)

    if already == len(RULES):
        print("  already applied — nothing to do")
        return 0
    if already:
        print(f"  ✗ {already} of {len(RULES)} rules had already run — the "
              f"corpus is half-repaired — refusing")
        return 1

    for name, wrong, _ in RULES:
        if wrong in texts[name]:
            print(f"  ✗ {wrong} survives in {name} — refusing")
            return 1

    after = sum(t.count("隻") for t in texts.values())
    print(f"  {len(RULES)} substitutions across {len(touched)} files")
    print(f"  隻  {before:>4} → {after:<4}")

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
