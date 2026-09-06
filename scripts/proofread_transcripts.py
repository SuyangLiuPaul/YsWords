#!/usr/bin/env python3
"""Proofreading corrections for the machine transcripts, held where they survive.

WHY THIS FILE EXISTS. `assets/sermon_library/` is gitignored — it is a
local staging area rebuilt from `scripts/sync_sermon_library.py` and, for
these sixteen, from `scripts/transcribe_sermons.py`. The proofreading is
the expensive part of the work and it lived ONLY in those untracked
files. `transcribe_sermons.py --force` rebuilds every body from the
cached decode, which its own docstring advertises as the cheap way to
change an edit rule; measured 2026-09-06, that rebuild would have
discarded corrections in **12 of the 16 bodies** and left no trace that
it had. This module is the fix: the corrections are data in the
repository, applied inside `build()`, so a rebuild reproduces them.

WHAT MAY BE CORRECTED, AND WHAT MAY NOT. The owner's standing rule is
that a preacher's transcribed words are never re-punctuated or rewritten.
A machine mishearing is not his words — it is the machine's — so the only
thing repaired here is a mishearing, back to what he demonstrably said.
Three classes qualify:

  BOOK      A book of the Bible spelt as it is not spelt. 加勒泰書 for
            加拉太書. No judgement is involved and the correct form is
            not in doubt.
  SCRIPTURE A verse he announces and then reads aloud, where the reading
            deviates from the bundled 和合本 by a homophone. The ground
            truth is `assets/cuvs-yhwh.json`, and `scripts/
            transcribe_sample_check.py` is the instrument that finds
            these.
  SENSE     A string that is not Chinese — 作亡 where 作王 is meant,
            民宿紀 for 民數記 — whose intended word is fixed by the
            surrounding sentence and is not a matter of taste.

A variant is NOT an error and is left alone: 服侍 for 服事, 按照 for
按著, 新生的樣子 for 新生的樣式. They change no meaning, and the preacher
paraphrases constantly. So is anything where two readings are both
possible; those are listed in `docs/OPEN-ITEMS.md` rather than guessed at.

REMOVED, not corrected: a hallucinated advertisement and four fabricated
subtitle credits naming real people for work nobody did.

HOW A MISTAKE HERE SHOWS UP. Every fix carries the number of times it
must match. `apply()` raises if the count is off by one in either
direction, so a re-decode that changes the underlying text fails loudly
instead of silently applying a fix to the wrong place — or to nothing.
"""
from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

BOOK, SCRIPTURE, SENSE, REMOVED = "BOOK", "SCRIPTURE", "SENSE", "REMOVED"


@dataclass(frozen=True)
class Fix:
    old: str
    new: str
    n: int
    kind: str
    why: str = ""


class ProofreadError(RuntimeError):
    pass


# ---------------------------------------------------------------------------
# Pass 1 (2026-09-06) — what a machine can locate: book names that are not
# book names, and fabricated credits. Recovered from the untracked bodies by
# rebuilding each from the raw decode and diffing, then re-verified here.
# ---------------------------------------------------------------------------

_CREDIT = ("A fabricated subtitle credit. The decoder emitted a real "
           "person's name as a volunteer subtitler for work nobody did, "
           "inside sung lyrics where it reads exactly like a real credit.")

FIXES: dict[str, list[Fix]] = {
    "2728": [
        # The trailing SPACE, not the leading newline. Written with the
        # newline in pass 2, which deleted the paragraph break as well as
        # the credit and welded the following paragraph onto whatever came
        # before it. In the shipped corpus that was the 「[注：…]」 line, so
        # `assets/sermons/zh-CN/fy-cm03.txt` has a 1,450-character opening
        # paragraph: the provenance note running straight on into the
        # opening hymn with no break. Nothing caught it — the note still
        # STARTED that paragraph, so every assertion about it held.
        # Removing the credit and its own trailing space instead leaves
        # the break alone and the hymn standing as its own paragraph.
        Fix("中文字幕志愿者 李宗盛 ", "", 1, REMOVED, _CREDIT),
    ],
    "4259": [
        Fix("明述记", "民数记", 1, BOOK),
        Fix("民俗记", "民数记", 1, BOOK),
        Fix("格林多", "哥林多", 1, BOOK),
    ],
    "4263": [
        Fix("罗马人书", "罗马书", 2, BOOK),
        Fix("加勒泰书", "加拉太书", 3, BOOK),
        Fix("加勒派书", "加拉太书", 1, BOOK),
        Fix("加勒太书", "加拉太书", 1, BOOK),
    ],
    "4266": [
        Fix("金木太前书", "提摩太前书", 1, BOOK),
        Fix("贝利比书", "腓立比书", 1, BOOK),
        Fix("加勒泰书", "加拉太书", 2, BOOK),
    ],
    "4267": [
        Fix("格林多", "哥林多", 2, BOOK),
        Fix("加勒泰书", "加拉太书", 2, BOOK),
    ],
    "4271": [
        Fix("西伯来书", "希伯来书", 1, BOOK),
    ],
    "4274": [
        Fix("诺玛书", "罗马书", 1, BOOK),
        Fix("和希阿书", "何西阿书", 1, BOOK),
        Fix("西伯来书", "希伯来书", 1, BOOK),
    ],
    "4278": [
        Fix("以福所书", "以弗所书", 3, BOOK),
        Fix("伊夫所书", "以弗所书", 1, BOOK),
        Fix("以夫所书", "以弗所书", 1, BOOK),
        Fix("西伯来书", "希伯来书", 1, BOOK),
        Fix("提摩泰前书", "提摩太前书", 1, BOOK),
    ],
    "4279": [
        Fix("哥罗西书", "歌罗西书", 2, BOOK),
    ],
    "4282": [
        Fix("诺玛书", "罗马书", 1, BOOK),
    ],
    "6012": [
        Fix("菲利比书", "腓立比书", 15, BOOK),
        Fix("格林多", "哥林多", 7, BOOK),
        Fix("贴萨罗尼迦", "帖撒罗尼迦", 1, BOOK),
        Fix("帖撒罗尼加", "帖撒罗尼迦", 1, BOOK),
        Fix("字幕志愿者 杨栋梁 ", "", 1, REMOVED, _CREDIT),
    ],
    "6015": [
        Fix(" 中文字幕志愿者 李宗盛 字幕志愿者 杨茜茜", "", 1, REMOVED, _CREDIT),
        Fix("格林多", "哥林多", 5, BOOK),
        Fix("菲利比书", "腓立比书", 2, BOOK),
    ],
}

# The advertisement. 28 seconds of audio decoded to nothing, and the decoder
# filled the silence by repeating one unrelated sentence fourteen times. The
# SIGNAL is worth keeping — a reader should know that stretch is missing —
# so it becomes a note that says so, rather than being deleted quietly.
_ADVERT_RUN = " ".join(["全片以Google Pixel 4拍摄"] * 14)
_ADVERT_NOTE = ("[注：此处约 28 秒录音未能解出内容。机器转录在此重复输出了"
                "一段与讲道无关的广告词，已移除；讲道正文到上一段为止。]")
FIXES["4266"].append(Fix(
    _ADVERT_RUN, _ADVERT_NOTE, 1, REMOVED,
    "A hallucinated advertisement emitted 14 times over ~28 s of audio "
    "that decoded to nothing. Replaced by a note recording that the "
    "stretch is missing, which is the part worth keeping."))


# ---------------------------------------------------------------------------
# Pass 2 (2026-09-06) — the part only reading finds. Every one of these was
# located by reading all sixteen transcripts end to end, ~118 000 characters.
# The machine checks that came before found none of them: they are ordinary
# Chinese words, so a spell check has nothing to object to, and most sit in
# the preacher's own sentences rather than in a quoted verse, so
# `transcribe_sample_check.py`'s scripture CER cannot see them either.
#
# Two calibrations worth keeping, because they say what these numbers mean:
#
#   The measured 2.4% CER on read scripture in 4258 is a FLOOR, and this pass
#   shows how far below the real rate it sits. In 4259 that instrument found
#   ONE substitution. Reading the same file found twenty-six, including 作亡
#   for 作王 (Rom 6:12 — sin REIGNS, and 作亡 is not a word), 救人 for 舊人
#   three times, and 心靈的信仰 for 心靈的新樣 (Rom 7:6).
#
#   And the instrument's own worst score was a FALSE positive. Romans 7:6
#   scored 31.4% in 4259 mostly because the bundled CUV carries the marginal
#   note 「心靈：或作聖靈」 inside the verse text, which no preacher reads
#   aloud. The real errors in that verse were smaller than the metric and in
#   a different place. A number is not a finding.
#
# What was deliberately NOT changed, though it was noticed:
#   - Variants that change no meaning: 服侍/服事, 按照/按著, 新生的樣子 for
#     樣式, 降伏/降服, 十戒 for 十誡, 哥斯大黎加. He paraphrases constantly
#     and these are his words, not a mishearing.
#   - 創世紀 — `assets/cuvs-yhwh.json` itself spells it that way, so
#     "correcting" it to 創世記 would have made the app disagree with its own
#     Bible. Caught by checking rather than assuming.
#   - Chapter and verse numbers that are plausible but wrong (4271 calls
#     Rom 9:6 「九節」 three times; 4274 calls 9:8 「九章十三節」). 六/九 are
#     not homophones, so the likeliest explanation is that the preacher
#     misspoke — and correcting THAT would be rewriting him. Listed in
#     `docs/OPEN-ITEMS.md` for someone with the audio.
#   - Roughly two dozen phrases that are certainly wrong but whose intended
#     word is not uniquely fixed by the context — 救恩的功臣, 抵掉約翰,
#     律法建立, 主持宏大. Guessing at those is how a proofreader introduces
#     errors instead of removing them. Also in `docs/OPEN-ITEMS.md`.
#   - The sung hymns, which are garbled beyond safe repair. Only the two
#     fabricated credits and one 「阿彌陀佛」 — decoder noise at the head of
#     a Christmas carol — were touched.
# ---------------------------------------------------------------------------

FIXES_PASS2: dict[str, list[Fix]] = {
    "4258": [
        Fix("的诠释下", "的权势下", 2, SENSE, "诠释/权势 are homophones; in Rom 5 sin and righteousness REIGN"),
        Fix("人在罪中", "仍在罪中", 3, SCRIPTURE, "Rom 6:1-2 仍在罪中"),
        Fix("律法本是外天的", "律法本是外添的", 1, SCRIPTURE, "Rom 5:20"),
        Fix("借的罪显明", "借着罪显明", 1, SENSE, "借的 is not Chinese"),
        Fix("身上作网", "身上作王", 1, SCRIPTURE, "Rom 6:12 作王"),
        Fix("将从死里复活的人", "像从死里复活的人", 2, SCRIPTURE, "Rom 6:13 倒要像從死裡復活的人"),
        Fix("宗教意识", "宗教仪式", 1, SENSE, "意识/仪式"),
        Fix("十四和四五节", "十四和十五节", 1, SENSE, "verse number"),
        Fix("献金也要照样", "现今也要照样", 1, SCRIPTURE, "Rom 6:19"),
        Fix("献给一座奴仆", "献给义作奴仆", 1, SCRIPTURE, "Rom 6:19"),
        Fix("借着向罪使", "借着向罪死", 1, SENSE, "使/死"),
        Fix("诗节也清楚", "四节也清楚", 1, SENSE, "he is citing verse 4"),
        Fix("不可以忍在罪中", "不可以仍在罪中", 1, SCRIPTURE, "Rom 6:1"),
        Fix("为人人死", "为仁人死", 1, SCRIPTURE, "Rom 5:7 為仁人死"),
        Fix("向罪死 向生活", "向罪死 向神活", 1, SCRIPTURE, "Rom 6:11"),
        Fix("你们蒙造 愿是为此", "你们蒙召 原是为此", 1, SCRIPTURE, "1 Pet 2:21 蒙召原是為此"),
        Fix("公众再见", "空中再见", 1, SENSE, "the programme sign-off"),
    ],
    "4259": [
        Fix("身上作亡", "身上作王", 2, SCRIPTURE, "Rom 6:12"),
        Fix("救人", "旧人", 3, SCRIPTURE, "Rom 6:6 舊人"),
        Fix("使罪生灭绝", "使罪身灭绝", 1, SCRIPTURE, "Rom 6:6"),
        Fix("顺从生子的私欲", "顺从身子的私欲", 1, SCRIPTURE, "Rom 6:12"),
        Fix("罗马诸六章", "罗马书六章", 1, BOOK),
        Fix("向基督借着父的荣耀", "像基督借着父的荣耀", 1, SCRIPTURE, "Rom 6:4"),
        Fix("前对词", "前缀词", 3, SENSE, "the Greek prefix συν-"),
        Fix("前罪词", "前缀词", 3, SENSE, "same word, second mishearing"),
        Fix("立志向罪使", "立志向罪死", 2, SENSE, "使/死"),
        Fix("今后向生活", "今后向神活", 1, SCRIPTURE, "Rom 6:11"),
        Fix("我们的意愿相互主耶稣", "我们的意愿降服主耶稣", 1, SENSE, "降服, his own phrase earlier"),
        Fix("受感受化", "受感说话", 1, SCRIPTURE, "Num 11:29"),
        Fix("约苏亚", "约书亚", 1, BOOK, "Joshua"),
        Fix("全民接先知", "全民皆先知", 1, SENSE, "皆/接 homophone"),
        Fix("民宿纪", "民数记", 1, BOOK),
        Fix("同钉死之价", "同钉十字架", 1, SENSE),
        Fix("同钉使者架", "同钉十字架", 1, SENSE, "same, second mishearing"),
        Fix("基督教的教育", "基督教的教义", 1, SENSE, "he says 基督教教义 for the same claim two sentences later"),
        Fix("使这个字在罗马书", "死这个字在罗马书", 1, SENSE, "the word under discussion is 死"),
        Fix("探讨 使在罗马书", "探讨 死在罗马书", 1, SENSE, "same"),
        Fix("岂可人在罪中", "岂可仍在罪中", 1, SCRIPTURE, "Rom 6:2"),
        Fix("与基督同时的同这个字", "与基督同死的同这个字", 1, SENSE, "时/死"),
        Fix("要按照心灵的信仰", "要按照心灵的新样", 1, SCRIPTURE, "Rom 7:6 心靈的新樣"),
        Fix("提到了心灵的信仰", "提到了心灵的新样", 1, SCRIPTURE, "the same phrase quoted back"),
        Fix("不按照疑问的救养", "不按照仪文的旧样", 1, SCRIPTURE, "Rom 7:6 儀文的舊樣"),
        Fix("坚决的心智", "坚决的心志", 1, SENSE, "心志 = resolve"),
    ],
    "4262": [
        Fix("因为直到我们的旧人", "因为知道我们的旧人", 1, SCRIPTURE, "Rom 6:6 因為知道"),
        Fix("罗马诸六章", "罗马书六章", 1, BOOK),
        Fix("同定死之价", "同钉十字架", 1, SENSE),
        Fix("伪身", "委身", 5, SENSE, "伪身 is not a word"),
        Fix("对主的尾声是真诚的", "对主的委身是真诚的", 1, SENSE, "尾声/委身"),
        Fix("怪不得他经常增长", "怪不得他经常挣扎", 1, SENSE, "the image is being buried alive"),
        Fix("却没有精力重生", "却没有经历重生", 1, SENSE, "精力/经历 homophones"),
        Fix("交托给信使的神", "交托给信实的神", 1, SENSE, "he says 神是信实的 in the same paragraph"),
        Fix("罪是一种诠释", "罪是一种权势", 1, SENSE, "诠释/权势"),
        Fix("就是要向罪使", "就是要向罪死", 1, SENSE, "使/死"),
        Fix("接着洗礼 神的灵是罪人脱离", "借着洗礼 神的灵使罪人脱离", 1, SENSE, "接着/借着 and 是/使"),
        Fix("扶摇至上", "扶摇直上", 1, SENSE, "the idiom is 直上"),
        Fix("我们下一次重要的时间", "我们下一次同样的时间", 1, SENSE, "the sign-off formula"),
        Fix(" 中文字幕志愿者 李宗盛", "", 1, REMOVED, "a fabricated subtitle credit pass 1 missed"),
    ],
    "4263": [
        Fix("直到现在时代 不一定", "知道现在时态 不一定", 1, SENSE, "直到/知道"),
        Fix("现在时代", "现在时态", 7, SENSE, "grammatical TENSE; he says 语法时态 correctly at the start"),
        Fix("过去时代", "过去时态", 1, SENSE, "same"),
        Fix("戈尼留", "哥尼流", 1, BOOK, "Cornelius, Acts 10"),
        Fix("真言", "箴言", 2, BOOK, "Proverbs"),
        Fix("从身后的经历", "重生后的经历", 1, SENSE, "重生/从身"),
        Fix("从生后的经历", "重生后的经历", 1, SENSE, "same, second mishearing"),
        Fix("情欲和圣灵的象征", "情欲和圣灵的争战", 1, SCRIPTURE, "Gal 5:17 情慾和聖靈相爭"),
        Fix("就是象征的护国", "就是争战的后果", 1, SENSE, "象征/争战 and 护国/后果"),
        Fix("解定的方法", "解经的方法", 1, SENSE, "he says 以经解经 in the same breath"),
        Fix("领导保罗的呢", "临到保罗的呢", 1, SENSE, "he has just quoted 誡命來到"),
        Fix("沉浸在律法之下", "曾经在律法之下", 1, SENSE, "沉浸/曾经"),
        Fix("向律法使", "向律法死", 1, SENSE, "使/死"),
        Fix("必须将律法使", "必须向律法死", 1, SENSE, "将/向 and 使/死"),
        Fix("加勒泰", "加拉太", 3, BOOK, "pass 1 fixed only 加勒泰书 and missed the bare form"),
        Fix("割离", "割礼", 2, BOOK, "离/礼"),
        Fix("我在指责凡受割礼的人", "我再指着凡受割礼的人", 1, SCRIPTURE, "Gal 5:3 我再指著"),
        Fix("行权律法的债", "行全律法的债", 2, SCRIPTURE, "Gal 5:3 欠著行全律法的債"),
        Fix("原来现在就代表着", "原来欠债就代表着", 1, SENSE, "现在/欠债"),
        Fix("在主的指挥", "债主的指挥", 1, SENSE, "在主/债主"),
        Fix("他们的在主", "他们的债主", 1, SENSE, "same"),
        Fix("月份、阶期、年份", "月份、节期、年份", 1, SCRIPTURE, "Gal 4:10 月分、節期、年分"),
        Fix("数以万几", "数以万计", 1, SENSE, "几/计"),
        Fix("都有怨在身", "都有愿在身", 1, SCRIPTURE, "Acts 21:23 都有願在身"),
        Fix("一同行决定的礼", "一同行洁净的礼", 1, SCRIPTURE, "Acts 21:24 潔淨的禮"),
        Fix("循规道具", "循规蹈矩", 1, SCRIPTURE, "Acts 21:24"),
        Fix("已经写定拟定", "已经写信拟定", 1, SCRIPTURE, "Acts 21:25 寫信擬定"),
        Fix("谨记那替偶像之物", "谨忌那祭偶像之物", 1, SCRIPTURE, "Acts 21:25 謹忌那祭偶像之物"),
        Fix("并勒死的身处与坚硬", "并勒死的牲畜与奸淫", 1, SCRIPTURE, "Acts 21:25 勒死的牲畜、與姦淫"),
        Fix("哥罗西、安提亚", "歌罗西、安提阿", 1, BOOK),
    ],
    "4266": [
        Fix("反而会奴隶我们", "反而会奴役我们", 1, SENSE, "奴隶/奴役"),
        Fix("向罪使", "向罪死", 1, SENSE, "使/死"),
        Fix("向律法使", "向律法死", 1, SENSE, "使/死"),
        Fix("必须将律法死", "必须向律法死", 1, SENSE, "将/向"),
        Fix("传乎不是", "断乎不是", 1, SCRIPTURE, "Rom 7:7"),
        Fix("短乎不是", "断乎不是", 1, SCRIPTURE, "Rom 7:7"),
        Fix("转乎不是", "断乎不是", 1, SCRIPTURE, "Rom 7:13"),
        Fix("短乎不可", "断乎不可", 1, SCRIPTURE, "Rom 6:15"),
        Fix("不可体贪心", "不可起贪心", 1, SCRIPTURE, "Rom 7:7"),
        Fix("借命来到", "诫命来到", 1, SCRIPTURE, "Rom 7:9"),
        Fix("就借着借命", "就借着诫命", 1, SCRIPTURE, "Rom 7:8"),
        Fix("然而最趁着机会", "然而罪趁着机会", 1, SCRIPTURE, "Rom 7:8 然而罪趁著機會"),
        Fix("要恩典显多吗", "叫恩典显多吗", 1, SCRIPTURE, "Rom 6:1"),
        Fix("我们可以人在罪中", "我们可以仍在罪中", 1, SCRIPTURE, "Rom 6:1"),
        Fix("暴露在五章", "保罗在五章", 1, SENSE, "暴露/保罗"),
        Fix("救人", "旧人", 4, SCRIPTURE, "Rom 6:6 舊人"),
        Fix("使罪生灭绝", "使罪身灭绝", 1, SCRIPTURE, "Rom 6:6"),
        Fix("正如如此", "正因如此", 1, SENSE),
        Fix("分别散二树上", "分别善恶树上", 1, SCRIPTURE, "Gen 2:17"),
        Fix("因为你吃的日子必定时", "因为你吃的日子必定死", 1, SCRIPTURE, "Gen 2:17"),
        Fix("例如到趁机这两个字", "留意到趁机这两个字", 1, SENSE, "例如/留意; 留意 is his constant idiom"),
        Fix("班祷叫我死", "反倒叫我死", 1, SCRIPTURE, "Rom 7:10"),
        Fix("因为罪乘的机会", "因为罪趁着机会", 1, SCRIPTURE, "Rom 7:11"),
        Fix("罪借的诫命", "罪借着诫命", 1, SENSE, "借的/借着"),
        Fix("蛇如何借的诫命", "蛇如何借着诫命", 1, SENSE, "same"),
        Fix("罪戒的诫命引诱了他们", "罪借着诫命引诱了他们", 1, SENSE, "same"),
        Fix("消动他们里面的谈语", "挑动他们里面的贪欲", 1, SENSE, "he says 挑動…裡頭的貪慾 verbatim earlier"),
        Fix("罪却火了呢", "罪却活了呢", 1, SCRIPTURE, "Rom 7:9 罪又活了"),
        Fix("没有立法前", "没有律法前", 1, SENSE, "立法/律法"),
        Fix("叫人活着诫命", "叫人活的诫命", 1, SCRIPTURE, "Rom 7:10"),
        Fix("最终却会教亚当时呢", "最终却会叫亚当死呢", 1, SENSE, "教/叫 and 时/死"),
        Fix("律法的经义", "律法的精义", 1, SENSE, "the contrast is 精義 against 字眼, spirit against letter"),
        Fix("否则就会置以为意", "否则就会自以为义", 1, SENSE, "置以为意/自以为义; the next clause is 以为自己做得不错"),
        Fix("对救援律法", "对旧约律法", 1, SENSE, "救援/旧约; he says 旧约的律法 in the next line"),
        Fix("从圣灵身成为属灵", "从圣灵生成为属灵", 1, SENSE, "身/生"),
        Fix("对于如此", "正因如此", 1, SENSE),
        Fix("对外方信徒", "对外邦信徒", 1, SENSE, "方/邦"),
        Fix("在你生命中作网", "在你生命中作王", 1, SCRIPTURE, "Rom 6:12 作王"),
        Fix("加拿大教会", "加拉太教会", 1, BOOK, "加拿大/加拉太"),
        Fix("圣灵耽误你的生活", "圣灵干预你的生活", 1, SENSE, "耽误/干预"),
        Fix("罗马书纵然", "罗马书纵览", 1, SENSE, "the title of the series is 縱覽"),
    ],
    "4267": [
        Fix("然而最趁的机会", "然而罪趁着机会", 1, SCRIPTURE, "Rom 7:8"),
        Fix("短乎不是", "断乎不是", 1, SCRIPTURE, "Rom 7:13"),
        Fix("正视这一点", "证实这一点", 1, SENSE, "正视/证实"),
        Fix("向罪也当叹自己是死的 像神在基督耶稣里", "向罪也当看自己是死的 向神在基督耶稣里", 1, SCRIPTURE, "Rom 6:11"),
        Fix("顺从生子的私欲", "顺从身子的私欲", 1, SCRIPTURE, "Rom 6:12"),
        Fix("肢体献给义 做不义的器具", "肢体献给罪 做不义的器具", 1, SCRIPTURE, "Rom 6:13 獻給罪作不義的器具 — 义 reverses it"),
        Fix("不能自罚的犯罪生活", "不能自拔的犯罪生活", 1, SENSE, "自罚/自拔"),
        Fix("身上作网", "身上作王", 1, SCRIPTURE, "Rom 6:12"),
        Fix("需要守世界的", "需要守十戒的", 1, SENSE, "世界/十戒"),
        Fix("不是在守世界了", "不是在守十戒了", 1, SENSE, "same"),
        Fix("世界的字句", "十戒的字句", 1, SENSE, "same"),
        Fix("安息日的字典要求", "安息日的字面要求", 1, SENSE, "字典/字面"),
        Fix("一个星期播出一天", "一个星期拨出一天", 1, SENSE, "播/拨"),
        Fix("安息日就可以固守呢", "安息日就可以不守呢", 1, SENSE, "固守/不守; the question is why this one is NOT kept"),
        Fix("正如此 新约从来没有", "正因如此 新约从来没有", 1, SENSE),
        Fix("必须受割离", "必须受割礼", 1, BOOK, "离/礼"),
        Fix("公然的违背实界", "公然的违背十戒", 1, SENSE, "实界/十戒"),
        Fix("无人侠管", "无人辖管", 1, SCRIPTURE, "1 Cor 9:19"),
        Fix("未要多得人", "为要多得人", 1, SCRIPTURE, "1 Cor 9:19"),
        Fix("未要得", "为要得", 2, SCRIPTURE, "1 Cor 9:20-21"),
        Fix("像犹太人 我就做犹太人", "向犹太人 我就做犹太人", 1, SCRIPTURE, "1 Cor 9:20 向猶太人"),
        Fix("像律法以下的人 我虽不在", "向律法以下的人 我虽不在", 1, SCRIPTURE, "1 Cor 9:20"),
        Fix("像没有律法的人 我就做", "向没有律法的人 我就做", 1, SCRIPTURE, "1 Cor 9:21"),
    ],
    "4270": [
        Fix("圣灵的果汁", "圣灵的果子", 1, SENSE, "果汁/果子"),
        Fix("陷入这种征战中", "陷入这种争战中", 1, SENSE, "he says 属灵争战 and 跟罪争战 elsewhere"),
        Fix("是处于情欲和圣灵的相争", "是出于情欲和圣灵的相争", 1, SENSE, "处于/出于"),
        Fix("失败也不要上之", "失败也不要丧志", 1, SENSE, "he says 因失败而丧志 in the same passage"),
        Fix("直接或者间谍的", "直接或者间接地", 1, SENSE, "间谍/间接"),
        Fix("让圣灵的话来纠正", "让圣经的话来纠正", 1, SENSE, "the sentence before says 用聖經來檢驗"),
        Fix("叫我们结果之给神", "叫我们结果子给神", 1, SCRIPTURE, "Rom 7:4"),
        Fix("起不晓得", "岂不晓得", 3, SCRIPTURE, "Rom 7:1"),
        Fix("用了十字 在罗马书用了三字", "用了十次 在罗马书用了三次", 1, SENSE, "字/次"),
        Fix("死了的 岂可人在罪中", "死了的人 岂可仍在罪中", 1, SCRIPTURE, "Rom 6:2"),
        Fix("比如到 每一次保罗", "留意到 每一次保罗", 1, SENSE, "比如到 is not Chinese"),
        Fix("端乎不可", "断乎不可", 1, SCRIPTURE, "Rom 6:15"),
        Fix("不能够任活在罪中", "不能够仍活在罪中", 1, SENSE, "任/仍"),
        Fix("像律法死的人", "向律法死的人", 1, SENSE, "像/向"),
        Fix("借着相对死", "借着向罪死", 1, SENSE, "相对/向罪"),
        Fix("叫我们接果子给神", "叫我们结果子给神", 1, SCRIPTURE, "Rom 7:4"),
        Fix("会接出死的果子", "会结出死的果子", 1, SENSE, "接/结"),
        Fix("要接出死的果子", "要结出死的果子", 1, SENSE, "接/结"),
        Fix("向律法使", "向律法死", 4, SENSE, "使/死"),
        Fix("脱离罪的瑕疵", "脱离罪的挟制", 1, SENSE, "瑕疵/挟制"),
        Fix("罗马书七章古节", "罗马书七章五节", 1, SENSE, "古/五"),
        Fix("而生的恶语", "而生的恶欲", 1, SCRIPTURE, "Rom 7:5 惡慾"),
        Fix("未完过去时代", "未完过去时态", 4, SENSE, "grammatical TENSE"),
        Fix("鼠肉体是从前", "属肉体是从前", 1, SENSE, "鼠/属"),
        Fix("第六节的史态", "第六节的时态", 1, SENSE, "史/时"),
        Fix("要按照心灵的信仰", "要按照心灵的新样", 1, SCRIPTURE, "Rom 7:6"),
        Fix("不按照疑问的救养", "不按照仪文的旧样", 1, SCRIPTURE, "Rom 7:6"),
        Fix("你们现在所看为羞耻的是 当日有什么果子呢 那些死的结局", "你们现今所看为羞耻的事 当日有什么果子呢 那些事的结局", 1, SCRIPTURE, "Rom 6:21"),
        Fix("所以说到的当日", "所说到的当日", 1, SENSE),
        Fix("罗马书纵然", "罗马书纵览", 1, SENSE),
    ],
    "4271": [
        Fix("只应要显明", "只因要显明", 1, SCRIPTURE, "Rom 9:11 只因要顯明"),
        Fix("那定义的", "那定意的", 1, SCRIPTURE, "Rom 9:16 不在乎那定意的"),
        Fix("竟敢向神抢嘴", "竟敢向神强嘴", 1, SCRIPTURE, "Rom 9:20"),
        Fix("要这样难道没有权柄", "窑匠难道没有权柄", 1, SCRIPTURE, "Rom 9:21 窰匠"),
        Fix("他就会使你刚毅", "他就会使你刚硬", 1, SENSE, "毅/硬"),
        Fix("对神话语的晋升", "对神话语的进深", 1, SENSE, "晋升/进深"),
        Fix("用鸟看法", "用鸟瞰法", 1, SENSE, "看/瞰"),
        Fix("这个鸟看法", "这个鸟瞰法", 1, SENSE, "same"),
        Fix("鸟看法换言之", "鸟瞰法换言之", 1, SENSE, "same"),
        Fix("最基本的决定原则", "最基本的解经原则", 1, SENSE, "决定/解经"),
        Fix("难度相当高的解禁练习", "难度相当高的解经练习", 1, SENSE, "解禁/解经"),
        Fix("这三张的中心思想", "这三章的中心思想", 1, SENSE, "张/章"),
        Fix("跟前面的几张", "跟前面的几章", 1, SENSE, "张/章"),
        Fix("比如说第八张", "比如说第八章", 1, SENSE, "张/章"),
        Fix("保罗结束了八张后", "保罗结束了八章后", 1, SENSE, "张/章"),
        Fix("就暗示的它不是", "就暗示着它不是", 1, SENSE),
        Fix("数数地完结", "速速地完结", 1, SCRIPTURE, "Rom 9:28 速速的完結"),
        Fix("若不是万君之主", "若不是万军之主", 1, SCRIPTURE, "Rom 9:29 萬軍之主"),
        Fix("给我们存留于众", "给我们存留余种", 1, SCRIPTURE, "Rom 9:29 存留餘種"),
        Fix("索多玛 而摩拉", "索多玛 蛾摩拉", 1, SCRIPTURE, "Rom 9:29"),
        Fix("像这些人传福音", "向这些人传福音", 1, SENSE, "像/向"),
        Fix("通过这种的解证方式", "通过这种的解经方式", 1, SENSE, "解证/解经"),
        Fix("御法 礼仪 应许", "律法 礼仪 应许", 1, SCRIPTURE, "Rom 9:4 諸約、律法、禮儀、應許"),
        Fix("以斯玛利", "以实玛利", 1, BOOK, "Ishmael"),
        Fix("以斯玛力", "以实玛利", 3, BOOK, "same, second mishearing"),
        Fix("以扫是我所悟的", "以扫是我所恶的", 1, SCRIPTURE, "Rom 9:13 以掃是我所惡的"),
        Fix("利百家", "利百加", 1, BOOK, "Rebekah"),
        Fix("软身兄弟", "孪生兄弟", 1, SENSE, "软身/孪生"),
        Fix("在乎灵不在乎疑问", "在乎灵不在乎仪文", 1, SCRIPTURE, "Rom 2:29 不在乎儀文"),
        Fix("受割离", "受割礼", 1, BOOK, "离/礼"),
        Fix("因为割离是外面的", "因为割礼是外面的", 1, BOOK, "same"),
        Fix("承受父所住的府", "承受父所祝的福", 1, SCRIPTURE, "Heb 12:17 父所祝的福"),
        Fix("虽然好哭切酒", "虽然号哭切求", 1, SCRIPTURE, "Heb 12:17 號哭切求"),
    ],
    "4274": [
        Fix("体接肉体", "体贴肉体", 1, SENSE, "接/贴"),
        Fix("只应要显明", "只因要显明", 1, SCRIPTURE, "Rom 9:11"),
        Fix("神就对立百家说", "神就对利百加说", 1, BOOK, "Rebekah"),
        Fix("以扫是我所悟的", "以扫是我所恶的", 1, SCRIPTURE, "Rom 9:13"),
        Fix("以扫是他所悟", "以扫是他所恶", 1, SCRIPTURE, "Mal 1:3"),
        Fix("只在乎发联名的神", "只在乎发怜悯的神", 1, SCRIPTURE, "Rom 9:16 發憐憫的神"),
        Fix("那定义的", "那定意的", 2, SCRIPTURE, "Rom 9:16"),
        Fix("生命车上涂掉", "生命册上涂掉", 1, SCRIPTURE, "Exod 32:32 生命冊上"),
        Fix("要教谁刚硬就教谁刚硬", "要叫谁刚硬就叫谁刚硬", 1, SCRIPTURE, "Rom 9:18"),
        Fix("神使法老得心刚硬", "神使法老的心刚硬", 1, SENSE, "得/的"),
        Fix("不凭着定心球", "不凭着信心求", 1, SCRIPTURE, "Rom 9:32 憑著信心求"),
        Fix("只凭着行为球", "只凭着行为求", 1, SCRIPTURE, "Rom 9:32"),
        Fix("不知道神的意 想要立自己的意 就不服神的意了", "不知道神的义 想要立自己的义 就不服神的义了", 1, SCRIPTURE, "Rom 10:3 神的義"),
        Fix("是凡信他的都得到义", "使凡信他的都得着义", 1, SCRIPTURE, "Rom 10:4"),
        Fix("不要从导覆辙", "不要重蹈覆辙", 1, SENSE, "the idiom"),
        Fix("使法老刚命", "使法老刚硬", 1, SENSE, "命/硬"),
        Fix("按自己的意识 决定每一个人", "按自己的意思 决定每一个人", 1, SENSE, "意识/意思"),
        Fix("字面意识", "字面意思", 1, SENSE, "same"),
        Fix("悟以扫", "恶以扫", 1, SCRIPTURE, "Mal 1:3"),
        Fix("蒙爱跟点选是同意思", "蒙爱跟拣选是同意思", 1, SENSE, "点选/拣选"),
        Fix("透过解钉的方法", "透过解经的方法", 1, SENSE, "解钉/解经"),
        Fix("神所证悟的人", "神所憎恶的人", 1, SENSE, "证悟/憎恶"),
        Fix("就被神证悟", "就被神憎恶", 1, SENSE, "same"),
        Fix("失去党子名分", "失去长子名分", 1, SENSE, "党/长"),
        Fix("以施玛利", "以实玛利", 4, BOOK, "Ishmael"),
        Fix("以斯玛力", "以实玛利", 4, BOOK, "same"),
        Fix("按若生生的", "按肉身生的", 1, SENSE, "若生生/肉身"),
        Fix("肉身的割离不是真割离", "肉身的割礼不是真割礼", 1, BOOK, "离/礼"),
        Fix("唯有里面的割离才是真割离", "唯有里面的割礼才是真割礼", 1, BOOK, "same"),
        Fix("不在乎语文", "不在乎仪文", 1, SCRIPTURE, "Rom 2:29 儀文"),
    ],
    "4275": [
        Fix("以斯玛力", "以实玛利", 1, BOOK, "Ishmael"),
        Fix("以斯玛利", "以实玛利", 1, BOOK, "same"),
        Fix("你们道蒙了连续", "你们倒蒙了怜恤", 1, SCRIPTURE, "Rom 11:30 倒蒙了憐恤"),
        Fix("施给你们的连续", "施给你们的怜恤", 2, SCRIPTURE, "Rom 11:31"),
        Fix("现在也就蒙连续", "现在也就蒙怜恤", 2, SCRIPTURE, "Rom 11:31"),
        Fix("特意要连续众人", "特意要怜恤众人", 1, SCRIPTURE, "Rom 11:32 憐恤眾人"),
        Fix("告蒙了神的怜悯", "倒蒙了神的怜悯", 1, SENSE, "告/倒"),
        Fix("心理刚硬", "心里刚硬", 7, SENSE, "理/里"),
        Fix("唯有蒙捡选的人", "唯有蒙拣选的人", 1, SCRIPTURE, "Rom 11:7"),
        Fix("还梗不化", "顽梗不化", 2, SCRIPTURE, "Rom 11:7 頑梗不化"),
        Fix("因为他们还等不化", "因为他们顽梗不化", 1, SENSE, "还等/顽梗"),
        Fix("还雇不化", "顽梗不化", 1, SENSE, "same"),
        Fix("数目签满了", "数目添满了", 1, SCRIPTURE, "Rom 11:25 添滿了"),
        Fix("存留鱼种", "存留余种", 1, SCRIPTURE, "Rom 9:29 餘種"),
        Fix("索多玛和摩拉", "索多玛和蛾摩拉", 1, SCRIPTURE, "Rom 9:29"),
        Fix("我将你信起来", "我将你兴起来", 1, SCRIPTURE, "Rom 9:17 我將你興起來"),
        Fix("出埃及第九章", "出埃及记第九章", 1, BOOK),
        Fix("使神的名传遍千家", "使神的名传遍天下", 1, SCRIPTURE, "Rom 9:17 傳遍天下"),
        Fix("是非常福利的", "是非常不利的", 1, SENSE, "福利/不利; the next paragraph says 很不利"),
        Fix("巴劳跟以色列", "法老跟以色列", 1, SENSE, "巴劳/法老"),
        Fix("那可怒 欲被遭毁灭的器皿", "那可怒 预备遭毁灭的器皿", 1, SCRIPTURE, "Rom 9:22 豫備遭毀滅"),
        Fix("那个欲被遭毁灭的器皿", "那个预备遭毁灭的器皿", 1, SCRIPTURE, "same"),
        Fix("他是神称多次忍耐", "他是神曾多次忍耐", 1, SENSE, "称/曾"),
        Fix("明述集十四章", "民数记十四章", 1, BOOK),
        Fix("没有任何借口背弥神", "没有任何借口背逆神", 1, SENSE, "弥/逆"),
        Fix("不耽误人的行为", "不在乎人的行为", 1, SCRIPTURE, "Rom 9:11 不在乎人的行為"),
        Fix("只应要显明", "只因要显明", 1, SCRIPTURE, "Rom 9:11"),
        Fix("因如此 保罗在五节", "正因如此 保罗在五节", 1, SENSE),
        Fix("即使出于恩典", "既是出于恩典", 1, SCRIPTURE, "Rom 11:6 既是出於恩典"),
        Fix("救主从西安出来", "救主从锡安出来", 1, SCRIPTURE, "Rom 11:26 從錫安出來"),
        Fix("旧的福音说", "就着福音说", 2, SCRIPTURE, "Rom 11:28 就著福音說"),
        Fix("旧的简选说", "就着拣选说", 2, SCRIPTURE, "Rom 11:28 就著揀選說"),
        Fix("恩赐和选照", "恩赐和选召", 1, SCRIPTURE, "Rom 11:29 選召"),
        Fix("成了神的头顶", "成了神的仇敌", 1, SCRIPTURE, "Rom 11:28 是仇敵"),
        Fix("以色列全家会在蒙神拣选", "以色列全家会再蒙神拣选", 1, SENSE, "在/再"),
        Fix("做个初步的小解", "做个初步的小结", 1, SENSE, "解/结"),
        Fix("以色列全家会回准", "以色列全家会回转", 1, SENSE, "准/转"),
        Fix("你们不得再见我 只等到", "你们不得再见我 直等到", 1, SCRIPTURE, "Matt 23:39 直等到"),
        Fix("不是不定不变的", "不是固定不变的", 1, SENSE, "the next line says 神的揀選是靈活的"),
        Fix("求告主明的人", "求告主名的人", 1, SCRIPTURE, "Rom 10:13"),
        Fix("要教谁刚硬就教谁刚硬", "要叫谁刚硬就叫谁刚硬", 1, SCRIPTURE, "Rom 9:18"),
        Fix("那资子被折下来", "那枝子被折下来", 1, SCRIPTURE, "Rom 11:19 枝子"),
        Fix("是特位叫我接上", "是特为叫我接上", 1, SCRIPTURE, "Rom 11:19"),
        Fix("凡要惧怕", "反要惧怕", 1, SCRIPTURE, "Rom 11:20 反要懼怕"),
        Fix("原来的资子", "原来的枝子", 1, SCRIPTURE, "Rom 11:21"),
        Fix("以扫是神所悟的", "以扫是神所恶的", 1, SCRIPTURE, "Mal 1:3"),
        Fix("我们下一次重要的时间", "我们下一次同样的时间", 1, SENSE, "the sign-off formula"),
    ],
    "4278": [
        Fix("按着自己意志所喜悦的", "按着自己意旨所喜悦的", 1, SCRIPTURE, "Eph 1:5 自己意旨所喜悅的"),
        Fix("借着耶稣基督的儿子的名分", "借着耶稣基督得儿子的名分", 1, SCRIPTURE, "Eph 1:5"),
        Fix("他在爱之里所赐给我们", "他在爱子里所赐给我们", 1, SCRIPTURE, "Eph 1:6 在愛子裡"),
        Fix("父神在基督里称赐给我们", "父神在基督里曾赐给我们", 1, SCRIPTURE, "Eph 1:3"),
        Fix("未要借着教会是天上执政的", "为要借着教会使天上执政的", 1, SCRIPTURE, "Eph 3:10 為要藉著教會、使天上執政的"),
        Fix("谦基督徒不要做糊涂人", "劝基督徒不要做糊涂人", 1, SENSE, "谦/劝"),
        Fix("西利尼人", "希利尼人", 1, SCRIPTURE, "Rom 10:12 希利尼人"),
        Fix("这不像御定论所说的", "这不像预定论所说的", 1, SENSE, "御/预"),
        Fix("因为他是预先所知道的人", "因为他预先所知道的人", 1, SCRIPTURE, "Rom 8:29"),
        Fix("只应要显明", "只因要显明", 1, SCRIPTURE, "Rom 9:11"),
        Fix("神就对立百家说", "神就对利百加说", 1, BOOK, "Rebekah"),
        Fix("所以神对立百家说", "所以神对利百加说", 1, BOOK, "same"),
        Fix("以扫是我所悟的", "以扫是我所恶的", 1, SCRIPTURE, "Rom 9:13"),
        Fix("以扫是他所悟的", "以扫是他所恶的", 1, SCRIPTURE, "Mal 1:3"),
        Fix("以扫是我所悟", "以扫是我所恶", 1, SCRIPTURE, "Mal 1:3"),
        Fix("将来大的要扶持小的", "将来大的要服事小的", 1, SCRIPTURE, "Rom 9:12 大的要服事小的"),
        Fix("正如今上所递", "正如经上所记", 1, SCRIPTURE, "Rom 9:13"),
        Fix("以扫自我所悟", "以扫是我所恶", 1, SCRIPTURE, "Mal 1:3"),
        Fix("施行异能 歧视神迹", "施行异能 奇事神迹", 1, SCRIPTURE, "Acts 2:22 異能、奇事、神蹟"),
        Fix("他即按着神的定旨先见", "他既按着神的定旨先见", 1, SCRIPTURE, "Acts 2:23 他既按著"),
        Fix("借着无法知人的手", "借着无法之人的手", 1, SCRIPTURE, "Acts 2:23 無法之人"),
        Fix("好在取回来", "好再取回来", 1, SCRIPTURE, "John 10:17 好再取回來"),
        Fix("关乎结果之的问题", "关乎结果子的问题", 1, SENSE, "之/子"),
        Fix("以为他是单言 其实不是单言", "以为他是耽延 其实不是耽延", 1, SCRIPTURE, "2 Pet 3:9 耽延"),
        Fix("那愿人人都悔改", "乃愿人人都悔改", 1, SCRIPTURE, "2 Pet 3:9 乃願人人都悔改"),
        Fix("这小子里施上一个", "这小子里失丧一个", 1, SCRIPTURE, "Matt 18:14 失喪一個"),
        Fix("不愿意有一个人施上", "不愿意有一个人失丧", 1, SENSE, "same"),
        Fix("推翻了传统预定文", "推翻了传统预定论", 1, SENSE, "文/论"),
        Fix("选择心理刚硬", "选择心里刚硬", 1, SENSE, "理/里"),
        Fix("难怪真言提醒我们", "难怪箴言提醒我们", 1, BOOK, "Proverbs"),
        Fix("我们下一次重要的时间", "我们下一次同样的时间", 1, SENSE, "the sign-off formula"),
    ],
    "4279": [
        Fix("究竟是什么出发了保罗的心", "究竟是什么触发了保罗的心", 1, SENSE, "出发/触发"),
        Fix("感动保罗写的三章", "感动保罗写这三章", 1, SENSE, "的/这"),
        Fix("他要写的三章呢", "他要写这三章呢", 1, SENSE, "的/这"),
        Fix("按照我们的意识 我们的想法", "按照我们的意思 我们的想法", 1, SENSE, "意识/意思"),
        Fix("救恩领导不守律法的中国人", "救恩临到不守律法的中国人", 1, SENSE, "领导/临到"),
        Fix("眼前的德与失", "眼前的得与失", 1, SENSE, "德/得"),
        Fix("就如经上所迹", "就如经上所记", 1, SCRIPTURE, "Rom 9:33"),
        Fix("我在西安放一块绊脚的石头", "我在锡安放一块绊脚的石头", 1, SCRIPTURE, "Rom 9:33 錫安"),
        Fix("跌人的盘子", "跌人的磐石", 1, SCRIPTURE, "Rom 9:33 跌人的磐石"),
        Fix("信号他的人", "信靠他的人", 1, SCRIPTURE, "Rom 9:33 信靠他的人"),
        Fix("蒙简选的和不蒙简选的", "蒙拣选的和不蒙拣选的", 1, SENSE, "简/拣"),
        Fix("求告主明的", "求告主名的", 4, SCRIPTURE, "Rom 10:13"),
        Fix("不在乎定义的", "不在乎那定意的", 2, SCRIPTURE, "Rom 9:16"),
        Fix("而十章 这强调人的决定", "而十章 则强调人的决定", 1, SENSE, "这/则"),
        Fix("救恩的交集", "救恩的焦急", 1, SENSE, "交集/焦急"),
        Fix("谈到半小时", "谈到绊脚石", 1, SENSE, "半小时/绊脚石"),
        Fix("又提到了半小时", "又提到了绊脚石", 1, SENSE, "same"),
        Fix("我们被神所造的", "我们被神所召的", 1, SCRIPTURE, "Rom 9:24 被神所召的"),
        Fix("西利尼人", "希利尼人", 1, SCRIPTURE, "Rom 10:12"),
        Fix("救必得救呢", "就必得救呢", 1, SCRIPTURE, "Rom 10:13"),
        Fix("表面上我们都很正义 一件到不公平的事就马上向神信施问罪", "表面上我们都很正义 一见到不公平的事就马上向神兴师问罪", 1, SENSE, "一件到/一见到 and 信施/兴师"),
        Fix("以色列的不胜服", "以色列的不顺服", 1, SENSE, "胜/顺"),
        Fix("最根就底", "归根究底", 1, SENSE, "the idiom"),
        Fix("伊玛五思路上", "以马忤斯路上", 1, BOOK, "Emmaus"),
        Fix("立自己的意", "立自己的义", 1, SCRIPTURE, "Rom 10:3 立自己的義"),
        Fix("用人的定义来奔跑", "用人的定意来奔跑", 1, SCRIPTURE, "Rom 9:16 那定意的、那奔跑的"),
    ],
    "4282": [
        Fix("并供行义", "秉公行义", 1, SCRIPTURE, "Gen 18:19 秉公行義"),
        Fix("生命纪", "申命记", 6, BOOK, "Deuteronomy"),
        Fix("圣灵纪三十章", "申命记三十章", 1, BOOK, "same"),
        Fix("一切诫明", "一切诫命", 1, SCRIPTURE, "Deut 6:25"),
        Fix("律法的意", "律法的义", 2, SENSE, "意/义"),
        Fix("不服神的意 想要立自己的意", "不服神的义 想要立自己的义", 1, SCRIPTURE, "Rom 10:3"),
        Fix("使凡信他的都得着意", "使凡信他的都得着义", 1, SCRIPTURE, "Rom 10:4"),
        Fix("经常说 凡信他的人", "经上说 凡信他的人", 1, SCRIPTURE, "Rom 10:11 經上說"),
        Fix("西里尼人", "希利尼人", 1, SCRIPTURE, "Rom 10:12"),
        Fix("他也后代一切求告他的人", "他也厚待一切求告他的人", 1, SCRIPTURE, "Rom 10:12 厚待"),
        Fix("能叫使人复活", "能叫死人复活", 1, SENSE, "使人/死人"),
        Fix("是礼表的关系", "是里表的关系", 1, SENSE, "礼/里"),
        Fix("他们的脚中何等加美", "他们的脚踪何等佳美", 1, SCRIPTURE, "Rom 10:15 腳蹤何等佳美"),
        Fix("求告主明", "求告主名", 1, SCRIPTURE, "Rom 10:13"),
        Fix("求告主民", "求告主名", 1, SCRIPTURE, "same"),
        Fix("在申班应考", "在生搬硬套", 1, SENSE, "申班应考/生搬硬套"),
        Fix("保罗斯引用了", "保罗是引用了", 1, SENSE, "斯/是"),
        Fix("我在西安放一块半角的石头 别人的磐石", "我在锡安放一块绊脚的石头 跌人的磐石", 1, SCRIPTURE, "Rom 9:33"),
        Fix("先知以撒亚", "先知以赛亚", 1, BOOK, "Isaiah"),
        Fix("所说的盘石", "所说的磐石", 1, SENSE, "盘/磐"),
        Fix("愿他们的言习变为网罗 变为低贱", "愿他们的筵席变为网罗 变为机槛", 1, SCRIPTURE, "Rom 11:9 筵席變為網羅、變為機檻"),
        Fix("因为他所猜来的", "因为他所差来的", 1, SCRIPTURE, "John 5:38 他所差來的"),
        Fix("则能信我的话呢", "怎能信我的话呢", 1, SCRIPTURE, "John 5:47"),
        Fix("看啊我在西安放一块石头", "看啊我在锡安放一块石头", 1, SCRIPTURE, "Isa 28:16 錫安"),
        Fix("宝贵的防脚石", "宝贵的房角石", 1, SCRIPTURE, "Isa 28:16 房角石"),
        Fix("但要尊万君之耶和华为圣", "但要尊万军之耶和华为圣", 1, SCRIPTURE, "Isa 8:13 萬軍之耶和華"),
        Fix("许多人被在骑上绊脚跌倒", "许多人必在其上绊脚跌倒", 1, SCRIPTURE, "Isa 8:15 必在其上"),
        Fix("将人所弃的石头 已做了防脚的头块石头", "匠人所弃的石头 已做了房角的头块石头", 1, SCRIPTURE, "Matt 21:42 匠人所棄的石頭、已作了房角的頭塊石頭"),
        Fix("赐给那能接国之的百姓", "赐给那能结果子的百姓", 1, SCRIPTURE, "Matt 21:43 能結果子的百姓"),
        Fix("必要跌谁", "必要跌碎", 1, SCRIPTURE, "Matt 21:44"),
        Fix("那仿角的头块石头", "那房角的头块石头", 1, SCRIPTURE, "Matt 21:42"),
        Fix("是匠人所砌的 成了半轮角的石头", "是匠人所弃的 成了房角的石头", 1, SCRIPTURE, "Matt 21:42"),
        Fix("随自己的意识发挥", "随自己的意思发挥", 1, SENSE, "意识/意思"),
        Fix("不是自己而是经理", "不是字句而是经义", 1, SENSE, "自己/字句 and 经理/经义"),
        Fix("字句背后的经意", "字句背后的经义", 1, SENSE, "意/义"),
        Fix("带不出信息的经译", "带不出信息的经义", 1, SENSE, "译/义"),
        Fix("律法背后的经译", "律法背后的经义", 1, SENSE, "same"),
        Fix("中文和赫本圣经", "中文和合本圣经", 1, BOOK, "和合本"),
        Fix("唯有和和本中文圣经", "唯有和合本中文圣经", 1, BOOK, "same"),
        Fix("其他版本都是沦为的", "其他版本都是人为的", 1, SENSE, "沦为/人为"),
    ],
    "2728": [
        Fix("张希和牧师", "张熙和牧师", 1, SENSE, "the preacher's name"),
        Fix("画饼", "话柄", 7, SCRIPTURE, "Luke 2:34 毀謗的話柄 — 画饼/话柄 are homophones"),
        Fix("经文绘编", "经文汇编", 1, SENSE, "绘/汇"),
        Fix("长鞭大论", "长篇大论", 1, SENSE, "the idiom"),
        Fix("阴海", "婴孩", 3, SENSE, "阴海/婴孩"),
        Fix("应海耶稣", "婴孩耶稣", 1, SENSE, "same"),
        Fix("一致在等待着弥赛亚", "一直在等待着弥赛亚", 1, SENSE, "致/直"),
        Fix("他会招人拒绝", "他会遭人拒绝", 1, SENSE, "招/遭"),
        Fix("一把两韵的宽边大剑", "一把两刃的宽边大剑", 1, SENSE, "韵/刃"),
        Fix("心要被吃透", "心要被刺透", 1, SCRIPTURE, "Luke 2:35 被刀刺透"),
        Fix("许多留言", "许多流言", 1, SENSE, "留言/流言 are homophones; the word is rumour"),
        Fix("关于我的留言坏话", "关于我的流言坏话", 1, SENSE, "same"),
        Fix("这些留言", "这些流言", 1, SENSE, "same"),
        Fix("关于耶稣的留言", "关于耶稣的流言", 1, SENSE, "same"),
        Fix("你跟人数位谋面", "你跟人素未谋面", 1, SENSE, "数位/素未"),
        Fix("属于说空穴来风", "俗语说空穴来风", 1, SENSE, "属于/俗语"),
        Fix("就是别人反对耶稣 这也并不重要", "就算别人反对耶稣 这也并不重要", 1, SENSE, "是/算"),
        Fix("你可称留意", "你可曾留意", 1, SENSE, "称/曾"),
        Fix("他说了健忘的话了", "他说了僭妄的话了", 1, SCRIPTURE, "Matt 9:3 說僭妄的話了"),
        Fix("耶稣说了健忘的话", "耶稣说了僭妄的话", 1, SCRIPTURE, "Matt 26:65"),
        Fix("鬼王别西普", "鬼王别西卜", 1, BOOK, "Beelzebul"),
        Fix("法律赛人", "法利赛人", 2, BOOK),
        Fix("贪私好酒", "贪食好酒", 2, SCRIPTURE, "Matt 11:19 貪食好酒"),
        Fix("言语根本是为不足道了", "言语根本是微不足道了", 1, SENSE, "为/微"),
        Fix("插言官色", "察言观色", 1, SENSE, "the idiom"),
        Fix("信心会被他咬动吗", "信心会被他摇动吗", 1, SENSE, "咬/摇"),
        Fix("埃及的法书师们", "埃及的法术师们", 1, SENSE, "书/术"),
        Fix("令你感到差异", "令你感到诧异", 1, SENSE, "差异/诧异"),
        Fix("他们的灵活却熄灭了", "他们的灵火却熄灭了", 1, SENSE, "the next line says 心裡頭再也沒有火了"),
        Fix("再也没有热冲", "再也没有热忱", 1, SENSE, "冲/忱"),
        Fix("为了信仰而上身", "为了信仰而丧身", 1, SENSE, "上身/丧身"),
        Fix("德萨奇州", "德萨斯州", 1, SENSE, "Texas — the date, the toll and the church all match Fort Worth, 1999-09-15"),
        Fix("一间敬信会", "一间浸信会", 1, SENSE, "敬/浸 — a Baptist church"),
        Fix("他吞枪致敬", "他吞枪自尽", 1, SENSE, "致敬/自尽"),
        Fix("完全伪身的基督徒", "完全委身的基督徒", 1, SENSE, "伪身/委身"),
        Fix("奇怪的是 他本来也有一点不正常的 他的脊椎骨是歪的 因此受的伤才不是致命 要不是他有歪骨 他也有可能丧命", "奇怪的是 她本来也有一点不正常的 她的脊椎骨是歪的 因此受的伤才不是致命 要不是她有歪骨 她也有可能丧命", 1, SENSE, "the referent is 一位年轻的女子, named as 她 in the two preceding sentences"),
        Fix("以教幕为首", "以教牧为首", 1, SENSE, "幕/牧"),
        Fix("西门八月拿", "西门巴约拿", 1, SCRIPTURE, "Matt 16:17 西門巴約拿"),
        Fix("那你说了些什么呢", "那里说了些什么呢", 1, SENSE, "那你/那里"),
        Fix("亚纳", "亚拿", 1, BOOK, "Anna, Luke 2:36"),
        Fix("阿弥陀佛 ", "", 1, REMOVED, "decoder noise at the head of a Christmas carol; nothing the preacher said"),
    ],
    "6015": [
        Fix("张希和牧师", "张熙和牧师", 2, SENSE, "the preacher's name"),
        Fix("转若为能", "转弱为能", 3, SENSE, "若/弱 — the series title"),
        Fix("无望不苛的生命", "无往不克的生命", 3, SENSE, "the sermon's own title; he says 無往不克 in the body"),
        Fix("无所不克的基督徒生命", "无往不克的基督徒生命", 1, SENSE, "same"),
        Fix("撒旦的猜疑要攻击我", "撒但的差役要攻击我", 1, SCRIPTURE, "2 Cor 12:7 撒但的差役"),
        Fix("基督的能力 伏逼我", "基督的能力 覆庇我", 1, SCRIPTURE, "2 Cor 12:9 覆庇我"),
        Fix("多下煎熬", "多下监牢", 1, SCRIPTURE, "2 Cor 11:23 多下監牢"),
        Fix("贾弟兄的危险", "假弟兄的危险", 1, SCRIPTURE, "2 Cor 11:26 假弟兄"),
        Fix("刺身入体", "赤身露体", 1, SCRIPTURE, "2 Cor 11:27 赤身露體"),
        Fix("为宗教会挂心", "为众教会挂心", 1, SCRIPTURE, "2 Cor 11:28 為眾教會掛心"),
        Fix("我软弱的事变了", "我软弱的事便了", 1, SCRIPTURE, "2 Cor 11:30 事便了"),
        Fix("如果你只是我一次", "如果你只试我一次", 1, SENSE, "是/试"),
        Fix("你的跑楼梯下去", "你得跑楼梯下去", 1, SENSE, "的/得"),
        Fix("花香满镜", "花香满径", 1, SENSE, "镜/径"),
        Fix("你一定的明白", "你一定得明白", 1, SENSE, "的/得"),
        Fix("一般都是诗经的研究书", "一般都是圣经的研究书", 1, SENSE, "诗经/圣经"),
        Fix("那张书的题目", "那章书的题目", 1, SENSE, "张/章"),
        Fix("名正", "明证", 3, SENSE, "名正/明证 are homophones; the word is proof"),
        Fix("多次招人拿石头打", "多次遭人拿石头打", 1, SENSE, "招/遭"),
        Fix("常常带着耶稣的屎", "常常带着耶稣的死", 1, SCRIPTURE, "2 Cor 4:10 身上常帶著耶穌的死"),
        Fix("天上四五个伤口", "添上四五个伤口", 1, SENSE, "天上/添上"),
        Fix("史提反", "司提反", 1, BOOK, "Stephen"),
        Fix("以至到他伤众致死", "以至到他伤重致死", 1, SENSE, "众/重"),
        Fix("打到脸轻眼肿", "打到脸青眼肿", 1, SENSE, "轻/青"),
        Fix("场中响起之后", "钟声响起之后", 1, SENSE, "a boxing bell"),
        Fix("气定神怡", "气定神闲", 1, SENSE, "the idiom"),
        Fix("你妈妈呼呼地仅以点数取胜", "马马虎虎地仅以点数取胜", 1, SENSE, "the idiom"),
        Fix("以上有余力的姿态", "以尚有余力的姿态", 1, SENSE, "以上/以尚"),
        Fix("他们也都不是实权实美的", "他们也都不是十全十美的", 1, SENSE, "the idiom"),
        Fix("听到同工们说记属灵超人", "听到同工们说起属灵超人", 1, SENSE, "记/起"),
        Fix("纳税党", "纳粹党", 1, SENSE, "税/粹"),
        Fix("那优秀的民主", "那优秀的民族", 1, SENSE, "主/族"),
        Fix("即可沐浴的人有福了", "饥渴慕义的人有福了", 1, SCRIPTURE, "Matt 5:6 飢渴慕義"),
        Fix("亲心的人有福了", "清心的人有福了", 1, SCRIPTURE, "Matt 5:8 清心的人"),
        Fix("清新的人和耶稣", "清心的人和耶稣", 1, SENSE, "the hymn is 《清心的人》"),
        Fix("清新的人这首诗歌", "清心的人这首诗歌", 1, SENSE, "same"),
        Fix("就是守洁心清", "就是手洁心清", 1, SCRIPTURE, "Ps 24:4 手潔心清"),
        Fix("既是不怀诡诈的人", "起誓不怀诡诈的人", 1, SCRIPTURE, "Ps 24:4 起誓不懷詭詐"),
        Fix("使他诚意", "使他成义", 1, SCRIPTURE, "Ps 24:5 使他成義"),
        Fix("我要一声向耶和华唱诗", "我要一生向耶和华唱诗", 1, SENSE, "声/生"),
        Fix("群力读书", "勤力读书", 1, SENSE, "群/勤"),
        Fix("这么群力地读圣经", "这么勤力地读圣经", 1, SENSE, "same"),
        Fix("是个好主义", "是个好主意", 1, SENSE, "义/意"),
        Fix("你的不断的提醒自己", "你得不断地提醒自己", 1, SENSE, "的/得"),
        Fix("我的恭喜你", "我得恭喜你", 1, SENSE, "的/得"),
        Fix("总结以上的个点", "总结以上的几点", 1, SENSE, "个/几"),
        Fix("保罗所说的赤是指什么", "保罗所说的刺是指什么", 1, SENSE, "赤/刺"),
        Fix("属灵的世上能够站立得稳", "属灵的事上能够站立得稳", 1, SENSE, "世/事"),
        Fix("我被痛的毛病", "我背痛的毛病", 1, SENSE, "被/背"),
        Fix("基督徒生命数字", "基督徒生命素质", 1, SENSE, "数字/素质; he says 生命素質 later"),
        Fix("你们读过暗示之后", "你们读过暗室之后", 1, BOOK, "《暗室之后》, 蔡蘇娟's autobiography — the 蔡姐妹 named in the next clause"),
        Fix("他对光敏感 以致他要在黑暗中生活", "她对光敏感 以致她要在黑暗中生活", 1, SENSE, "the referent is 蔡姐妹"),
        Fix("他实在是完全活在黑暗之中", "她实在是完全活在黑暗之中", 1, SENSE, "same"),
        Fix("该有的生命树枝", "该有的生命素质", 1, SENSE, "树枝/素质"),
        Fix("我跟基督同定十字架", "我跟基督同钉十字架", 1, SCRIPTURE, "Gal 2:20 同釘十字架"),
        Fix("顶十字架是绝对软弱", "钉十字架是绝对软弱", 1, SENSE, "顶/钉"),
        Fix("为亦受逼迫的人有福了", "为义受逼迫的人有福了", 1, SCRIPTURE, "Matt 5:10 為義受逼迫"),
        Fix("登山宝讯", "登山宝训", 1, SENSE, "讯/训"),
        Fix("是我的天赋提供了一切", "是我的天父提供了一切", 1, SENSE, "天赋/天父"),
        Fix("一致", "一直", 3, SENSE, "致/直, all three occurrences"),
        Fix("他十分差异", "他十分诧异", 1, SENSE, "差异/诧异"),
        Fix("叫我大为差异的是", "叫我大为诧异的是", 1, SENSE, "same"),
        Fix("省得工作", "神的工作", 2, SENSE, "省得/神的"),
        Fix("小方也再难以跟我联络", "校方也再难以跟我联络", 1, SENSE, "小方/校方"),
        Fix("我便得取到伦敦", "我便得去到伦敦", 1, SENSE, "取/去"),
        Fix("教会并没有寿薪于我", "教会并没有授薪于我", 1, SENSE, "寿/授"),
        Fix("从来没有发心给我", "从来没有发薪给我", 1, SENSE, "心/薪"),
        Fix("你如果纯心不相信", "你如果存心不相信", 1, SENSE, "纯/存"),
        Fix("你既然用不着精力神", "你既然用不着经历神", 1, SENSE, "精力/经历 are homophones"),
        Fix("我是含有的例外", "我是罕有的例外", 1, SENSE, "含有/罕有"),
        Fix("生命纪三十三章", "申命记三十三章", 1, BOOK, "Deut 33:25"),
        Fix("巡猎的手续", "循例的手续", 1, SENSE, "巡猎/循例"),
        Fix("把这些卡足以拿出来", "把这些卡逐一拿出来", 1, SENSE, "足以/逐一"),
        Fix("先上感恩的心", "献上感恩的心", 1, SENSE, "the hymn's own refrain, 獻上感恩的心"),
        Fix("我并不是因缺乏说之话", "我并不是因缺乏说这话", 1, SCRIPTURE, "Phil 4:11 說這話"),
        Fix("透过他的生命 无数的人被祝福", "透过她的生命 无数的人被祝福", 1, SENSE, "the referent is the young woman in the wheelchair"),
        Fix("从他的软弱上彰显出来", "从她的软弱上彰显出来", 1, SENSE, "same"),
    ],
    "6012": [
        Fix("称几何时死亡", "曾几何时死亡", 1, SENSE, "the idiom 曾幾何時"),
        Fix("你一旦撤手成环", "你一旦撒手尘寰", 1, SENSE, "the idiom"),
        Fix("婚约便马上告催", "婚约便马上告吹", 1, SENSE, "催/吹"),
        Fix("为了要给对方灵", "为了要给对方零", 1, SENSE, "灵/零 — the whole passage is about zero"),
        Fix("圆圈能够代表灵", "圆圈能够代表零", 1, SENSE, "same"),
        Fix("完全的尾声", "完全的委身", 1, SENSE, "尾声/委身"),
        Fix("是被你们墙壁的", "是被你们强逼的", 1, SCRIPTURE, "2 Cor 12:11 是被你們強逼的"),
        Fix("五这个字出现了两次", "无这个字出现了两次", 1, SENSE, "五/无 — the sermon's subject is 無"),
        Fix("根据罗契的原则", "根据逻辑的原则", 1, SENSE, "罗契/逻辑"),
        Fix("为什么不说信把它删掉", "为什么不索性把它删掉", 1, SENSE, "说信/索性"),
        Fix("自欺力", "自欺里", 1, SENSE),
        Fix("我们一致在呼求你", "我们一直在呼求你", 1, SENSE, "致/直"),
        Fix("还一致以为自己", "还一直以为自己", 1, SENSE, "same"),
        Fix("承担便宜座位的", "乘搭便宜座位的", 1, SENSE, "承担/乘搭"),
        Fix("我为什么要沉坐软座呢", "我为什么要乘坐软座呢", 1, SENSE, "沉/乘"),
        Fix("你可以承达任何等级的作为", "你可以乘搭任何等级的座位", 1, SENSE, "承达/乘搭 and 作为/座位"),
        Fix("艰辛的硬作", "艰辛的硬座", 1, SENSE, "作/座"),
        Fix("舒服的软作", "舒服的软座", 1, SENSE, "same"),
        Fix("还有谁愿意做硬做", "还有谁愿意做硬座", 1, SENSE, "same"),
        Fix("一定要做硬做", "一定要做硬座", 1, SENSE, "same"),
        Fix("妈妈呼呼的挂名信徒", "马马虎虎的挂名信徒", 1, SENSE, "the idiom"),
        Fix("至少可信的是", "至少可喜的是", 1, SENSE, "信/喜"),
        Fix("因我们想一人即替众人死", "因我们想一人既替众人死", 1, SCRIPTURE, "2 Cor 5:14 一人既替眾人死"),
        Fix("以这样的心智", "以这样的心志", 1, SENSE, "心志 = resolve"),
        Fix("大愿我们每一个", "但愿我们每一个", 1, SENSE, "大/但"),
    ],
}

for _sid, _rows in FIXES_PASS2.items():
    FIXES.setdefault(_sid, []).extend(_rows)


def apply(sid: str, body: str) -> tuple[str, int]:
    """Apply every fix for `sid`. Returns (corrected body, fixes applied).

    Raises if any fix does not match exactly the number of times it says
    it does. That is the whole safety property: a fix that silently
    matches nothing is indistinguishable from no proofreading at all.
    """
    applied = 0
    for f in FIXES.get(str(sid), []):
        got = body.count(f.old)
        if got != f.n:
            raise ProofreadError(
                f"{sid}: fix {f.old!r} -> {f.new!r} expected {f.n} "
                f"occurrence(s), found {got}. The transcript changed under "
                f"a correction written against an older decode; re-read the "
                f"passage before touching the count.")
        body = body.replace(f.old, f.new)
        applied += 1
    return body, applied


def occurrence_count(sid: str) -> int:
    """How many PLACES in the text change, not how many rules run.

    `apply` counts rules, which is the right number for a changelog and
    the wrong one for a reader: one rule with `n=7` corrects seven spots.
    The note at the head of each body quotes this instead, because
    「改正 N 处」 is a claim about the text in front of them.
    """
    return sum(f.n for f in FIXES.get(str(sid), []))


def check(sid: str, body: str) -> list[str]:
    """Verify an on-disk body carries the corrections. Returns complaints."""
    bad = []
    for f in FIXES.get(str(sid), []):
        # A fix that only INSERTS — 「因如此」 -> 「正因如此」 — leaves its own
        # `old` inside its `new`, so the presence test below would report it
        # as uncorrected forever. Skip the test for those; `new in body`
        # still covers them.
        if f.old and f.old not in f.new and f.old in body:
            bad.append(f"{sid}: uncorrected {f.old!r} still present")
        if f.new and f.new not in body:
            bad.append(f"{sid}: correction {f.new!r} missing")
    return bad


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    bodies = repo / "assets" / "sermon_library" / "bodies"
    if not bodies.is_dir():
        print("assets/sermon_library/bodies is absent (gitignored) — "
              "nothing to check", file=sys.stderr)
        return 0
    total, complaints = 0, []
    for sid, fixes in sorted(FIXES.items()):
        p = bodies / f"{sid}.txt"
        if not p.exists():
            complaints.append(f"{sid}: body missing")
            continue
        complaints += check(sid, p.read_text(encoding="utf-8"))
        total += len(fixes)
    by_kind: dict[str, int] = {}
    for fixes in FIXES.values():
        for f in fixes:
            by_kind[f.kind] = by_kind.get(f.kind, 0) + f.n
    print(f"{total} fixes over {len(FIXES)} bodies; "
          + ", ".join(f"{k}={v}" for k, v in sorted(by_kind.items())))
    for c in complaints:
        print("  " + c, file=sys.stderr)
    return 1 if complaints else 0


if __name__ == "__main__":
    raise SystemExit(main())
