#!/usr/bin/env python3
"""
Author book-level introductions and bundle into
`assets/book_introductions.json`.

Schema:
  {
    "_meta": { "version": 1, "books": ["Genesis", ...] },
    "intros": {
      "<EnglishBookName>": {
        "subtitle":              { "en": "...", "zh-Hans": "...", "zh-Hant": "..." },
        "summary":               { "en": "...", "zh-Hans": "...", "zh-Hant": "..." },
        "author":                { "en": "...", "zh-Hans": "...", "zh-Hant": "..." },
        "date":                  { "en": "...", "zh-Hans": "...", "zh-Hant": "..." },
        "audience":              { "en": "...", "zh-Hans": "...", "zh-Hant": "..." },
        "themes":                { "en": [...], "zh-Hans": [...], "zh-Hant": [...] },
        "keyPassage":            "Genesis 12:1-3",
        "keyPassageDescription": { "en": "...", "zh-Hans": "...", "zh-Hant": "..." }
      }
    }
  }

Loaded by lib/services/book_intro_service.dart and rendered as a
collapsible card at the top of chapter 1 in the reading pane.
"""
from __future__ import annotations

import datetime as _dt
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "book_introductions.json")


def _make(
    *,
    subtitle_en: str,
    subtitle_hans: str,
    subtitle_hant: str,
    summary_en: str,
    summary_hans: str,
    summary_hant: str,
    author_en: str,
    author_hans: str,
    author_hant: str,
    date_en: str,
    date_hans: str,
    date_hant: str,
    audience_en: str,
    audience_hans: str,
    audience_hant: str,
    themes_en: list[str],
    themes_hans: list[str],
    themes_hant: list[str],
    key_passage: str,
    key_passage_desc_en: str,
    key_passage_desc_hans: str,
    key_passage_desc_hant: str,
) -> dict:
    return {
        "subtitle": {
            "en": subtitle_en,
            "zh-Hans": subtitle_hans,
            "zh-Hant": subtitle_hant,
        },
        "summary": {
            "en": summary_en,
            "zh-Hans": summary_hans,
            "zh-Hant": summary_hant,
        },
        "author": {
            "en": author_en,
            "zh-Hans": author_hans,
            "zh-Hant": author_hant,
        },
        "date": {"en": date_en, "zh-Hans": date_hans, "zh-Hant": date_hant},
        "audience": {
            "en": audience_en,
            "zh-Hans": audience_hans,
            "zh-Hant": audience_hant,
        },
        "themes": {
            "en": themes_en,
            "zh-Hans": themes_hans,
            "zh-Hant": themes_hant,
        },
        "keyPassage": key_passage,
        "keyPassageDescription": {
            "en": key_passage_desc_en,
            "zh-Hans": key_passage_desc_hans,
            "zh-Hant": key_passage_desc_hant,
        },
    }


INTROS: dict[str, dict] = {
    "Genesis": _make(
        subtitle_en="Beginnings — Creation, Fall, and the Promise of Redemption",
        subtitle_hans="起源——创造、堕落与救赎的应许",
        subtitle_hant="起源——創造、墮落與救贖的應許",
        summary_en=(
            "Genesis is the prologue of the entire Bible. The first eleven chapters trace "
            "the origins of the cosmos, humanity, sin, and the nations. From chapter 12 onward "
            "the focus narrows to one family — Abraham and his descendants — through whom God "
            "promises to bless every nation on earth. Every later book of Scripture builds on "
            "the foundations laid here."
        ),
        summary_hans=(
            "创世记是整本圣经的序言。前11章追溯宇宙、人类、罪恶与列国的起源。从第12章起，"
            "焦点收窄到一个家族——亚伯拉罕及其后裔——神应许借他们使地上万族得福。"
            "圣经后续每一卷都建立在这里所奠定的根基之上。"
        ),
        summary_hant=(
            "創世記是整本聖經的序言。前11章追溯宇宙、人類、罪惡與列國的起源。從第12章起，"
            "焦點收窄到一個家族——亞伯拉罕及其後裔——神應許藉他們使地上萬族得福。"
            "聖經後續每一卷都建立在這裡所奠定的根基之上。"
        ),
        author_en="Traditionally Moses, drawing on earlier oral and written sources",
        author_hans="传统认为是摩西，根据更早的口传与书面资料汇编",
        author_hant="傳統認為是摩西，根據更早的口傳與書面資料彙編",
        date_en="ca. 1446–1406 BCE (events span from creation to ca. 1800 BCE)",
        date_hans="约公元前1446–1406年（叙事跨越从创世到约公元前1800年）",
        date_hant="約公元前1446–1406年（敘事跨越從創世到約公元前1800年）",
        audience_en="Israel after the Exodus, learning their identity as God's covenant people",
        audience_hans="出埃及后的以色列民，认识自己作为神立约子民的身份",
        audience_hant="出埃及後的以色列民，認識自己作為神立約子民的身份",
        themes_en=[
            "Creation",
            "Fall",
            "Covenant",
            "Promise",
            "Patriarchs",
            "Providence",
        ],
        themes_hans=["创造", "堕落", "立约", "应许", "列祖", "护理"],
        themes_hant=["創造", "墮落", "立約", "應許", "列祖", "護理"],
        key_passage="Genesis 12:1-3",
        key_passage_desc_en=(
            "God's call of Abram contains the seed of every later promise. "
            "Through Abraham's family, every nation on earth would one day be blessed."
        ),
        key_passage_desc_hans=(
            "神对亚伯兰的呼召是后续一切应许的种子。借亚伯拉罕的家族，地上万族都将得福。"
        ),
        key_passage_desc_hant=(
            "神對亞伯蘭的呼召是後續一切應許的種子。藉亞伯拉罕的家族，地上萬族都將得福。"
        ),
    ),
    "Exodus": _make(
        subtitle_en="From Slavery to Sinai — God Forms a People for Himself",
        subtitle_hans="从为奴到西奈山——神为自己塑造一族子民",
        subtitle_hant="從為奴到西奈山——神為自己塑造一族子民",
        summary_en=(
            "Exodus tells how God rescued Israel from Egyptian slavery, formed them into a "
            "covenant nation at Mount Sinai, and came to dwell among them in the tabernacle. "
            "The Passover, the parting of the Red Sea, the giving of the Ten Commandments, "
            "and the construction of the tabernacle anchor the rest of the Old Testament."
        ),
        summary_hans=(
            "出埃及记记载神如何拯救以色列脱离埃及为奴之地，在西奈山立约成为一族，"
            "并借会幕住在他们中间。逾越节、过红海、颁布十诫、建造会幕——这些事件成为整部旧约的根基。"
        ),
        summary_hant=(
            "出埃及記記載神如何拯救以色列脫離埃及為奴之地，在西奈山立約成為一族，"
            "並藉會幕住在他們中間。逾越節、過紅海、頒布十誡、建造會幕——這些事件成為整部舊約的根基。"
        ),
        author_en="Traditionally Moses",
        author_hans="传统认为是摩西",
        author_hant="傳統認為是摩西",
        date_en="ca. 1446–1406 BCE",
        date_hans="约公元前1446–1406年",
        date_hant="約公元前1446–1406年",
        audience_en="The Israelites in the wilderness, learning to live as God's redeemed people",
        audience_hans="旷野中的以色列民，学习作为蒙救赎的子民而活",
        audience_hant="曠野中的以色列民，學習作為蒙救贖的子民而活",
        themes_en=[
            "Redemption",
            "Covenant",
            "Law",
            "Worship",
            "Presence of God",
        ],
        themes_hans=["救赎", "立约", "律法", "敬拜", "神同在"],
        themes_hant=["救贖", "立約", "律法", "敬拜", "神同在"],
        key_passage="Exodus 19:4-6",
        key_passage_desc_en=(
            "God's covenant identity statement: 'You shall be my treasured possession… "
            "a kingdom of priests and a holy nation.' Echoed in 1 Peter 2:9 about the church."
        ),
        key_passage_desc_hans=(
            "神立约时的身份宣告：「你们要归我作为珍贵的产业……作祭司的国度和圣洁的国民」。"
            "彼得前书2:9以同样的话形容教会。"
        ),
        key_passage_desc_hant=(
            "神立約時的身份宣告：「你們要歸我作為珍貴的產業……作祭司的國度和聖潔的國民」。"
            "彼得前書2:9以同樣的話形容教會。"
        ),
    ),
    "Psalms": _make(
        subtitle_en="The Bible's Songbook — Prayers for Every Season of the Soul",
        subtitle_hans="圣经的诗歌集——心灵各样光景的祷文",
        subtitle_hant="聖經的詩歌集——心靈各樣光景的禱文",
        summary_en=(
            "Psalms is the Bible's songbook — 150 prayers and hymns spanning every emotion the "
            "human heart knows: joy, grief, anger, doubt, hope, awe. Many were written by King "
            "David. Together they teach not only what to believe about God but how to talk with "
            "him in every condition of life."
        ),
        summary_hans=(
            "诗篇是圣经的诗歌集——150篇祷文与赞歌，涵盖人心一切的情感：喜乐、哀痛、忿怒、"
            "疑惑、盼望、敬畏。许多由大卫王所作。它们不仅教我们信什么，也教我们在人生各样境况中如何向神说话。"
        ),
        summary_hant=(
            "詩篇是聖經的詩歌集——150篇禱文與讚歌，涵蓋人心一切的情感：喜樂、哀痛、忿怒、"
            "疑惑、盼望、敬畏。許多由大衛王所作。它們不僅教我們信什麼，也教我們在人生各樣境況中如何向神說話。"
        ),
        author_en="Multiple — David (73), the sons of Korah, Asaph, Solomon, Moses, others",
        author_hans="多位作者——大卫(73篇)、可拉后裔、亚萨、所罗门、摩西等",
        author_hant="多位作者——大衛(73篇)、可拉後裔、亞薩、所羅門、摩西等",
        date_en="ca. 1400–500 BCE; final compilation post-exile",
        date_hans="约公元前1400–500年；被掳归回后最终汇编成书",
        date_hant="約公元前1400–500年；被擄歸回後最終彙編成書",
        audience_en="Worshipers of all generations — Israel's hymnal, the early church's prayer book",
        audience_hans="历世历代的敬拜者——以色列的赞美诗集、早期教会的祷告手册",
        audience_hant="歷世歷代的敬拜者——以色列的讚美詩集、早期教會的禱告手冊",
        themes_en=[
            "Praise",
            "Lament",
            "Trust",
            "Repentance",
            "Messianic hope",
            "Wisdom",
        ],
        themes_hans=["赞美", "哀歌", "信靠", "悔罪", "弥赛亚的盼望", "智慧"],
        themes_hant=["讚美", "哀歌", "信靠", "悔罪", "彌賽亞的盼望", "智慧"],
        key_passage="Psalm 23",
        key_passage_desc_en=(
            "The most beloved chapter in all Scripture. In one short psalm, David captures "
            "what it means for Yahweh himself to be your shepherd through every season of life."
        ),
        key_passage_desc_hans=(
            "整本圣经最为人熟知的一章。在这短短一篇诗篇中，大卫道出了「耶和华作我牧者」"
            "在人生各样境况中的意义。"
        ),
        key_passage_desc_hant=(
            "整本聖經最為人熟知的一章。在這短短一篇詩篇中，大衛道出了「耶和華作我牧者」"
            "在人生各樣境況中的意義。"
        ),
    ),
    "Isaiah": _make(
        subtitle_en="The Holy One of Israel — Judgment and Hope from the Prophet of the Cross",
        subtitle_hans="以色列的圣者——预言十架的先知所传的审判与盼望",
        subtitle_hant="以色列的聖者——預言十架的先知所傳的審判與盼望",
        summary_en=(
            "Isaiah is the longest and most quoted prophetic book. Half judgment (chapters 1-39), "
            "half consolation (40-66), it warns of Assyrian and Babylonian devastation while "
            "painting the most detailed prophetic portrait of the suffering Servant — fulfilled "
            "in Jesus seven centuries later."
        ),
        summary_hans=(
            "以赛亚书是篇幅最长、被新约引用最多的先知书。前39章为审判，后27章为安慰；预言亚述、"
            "巴比伦的毁灭，同时描绘出受苦仆人最详细的预表——七百年后在耶稣身上得着完全应验。"
        ),
        summary_hant=(
            "以賽亞書是篇幅最長、被新約引用最多的先知書。前39章為審判，後27章為安慰；預言亞述、"
            "巴比倫的毀滅，同時描繪出受苦僕人最詳細的預表——七百年後在耶穌身上得著完全應驗。"
        ),
        author_en="Isaiah son of Amoz, prophet in Judah",
        author_hans="亚摩斯的儿子以赛亚，犹大国先知",
        author_hant="亞摩斯的兒子以賽亞，猶大國先知",
        date_en="ca. 740–680 BCE (during the reigns of Uzziah, Jotham, Ahaz, Hezekiah)",
        date_hans="约公元前740–680年（乌西雅、约坦、亚哈斯、希西家在位期间）",
        date_hant="約公元前740–680年（烏西雅、約坦、亞哈斯、希西家在位期間）",
        audience_en="Judah and Jerusalem facing Assyrian threat; later, exiles longing for restoration",
        audience_hans="面对亚述威胁的犹大与耶路撒冷；之后被掳异乡、渴望归回的子民",
        audience_hant="面對亞述威脅的猶大與耶路撒冷；之後被擄異鄉、渴望歸回的子民",
        themes_en=[
            "Holiness of God",
            "Judgment",
            "Messiah",
            "Suffering Servant",
            "Restoration",
        ],
        themes_hans=["神的圣洁", "审判", "弥赛亚", "受苦的仆人", "复兴"],
        themes_hant=["神的聖潔", "審判", "彌賽亞", "受苦的僕人", "復興"],
        key_passage="Isaiah 53",
        key_passage_desc_en=(
            "The clearest pre-Christian portrait of substitutionary atonement. "
            "Written 700 years before Calvary, every line maps to the crucifixion of Christ."
        ),
        key_passage_desc_hans=(
            "在基督到来前最清晰的代赎预言。写于各各他七百年前，每一句都对应基督的十架受难。"
        ),
        key_passage_desc_hant=(
            "在基督到來前最清晰的代贖預言。寫於各各他七百年前，每一句都對應基督的十架受難。"
        ),
    ),
    "Matthew": _make(
        subtitle_en="The Promised King — Jesus, Son of Abraham, Son of David",
        subtitle_hans="应许的君王——耶稣，亚伯拉罕的子孙，大卫的子孙",
        subtitle_hant="應許的君王——耶穌，亞伯拉罕的子孫，大衛的子孫",
        summary_en=(
            "Matthew writes for a Jewish audience, structuring his Gospel around five major "
            "discourses (mirroring the five books of Moses) and over 60 Old Testament quotations. "
            "His thesis: Jesus is the Messiah, the long-awaited King who fulfills every promise "
            "made to Abraham and David."
        ),
        summary_hans=(
            "马太面向犹太读者书写。他将福音书架构成五大讲论（呼应摩西五经），引用旧约逾60处。"
            "他的论点：耶稣就是弥赛亚，是应许给亚伯拉罕和大卫的、众民盼望已久的君王。"
        ),
        summary_hant=(
            "馬太面向猶太讀者書寫。他將福音書架構成五大講論（呼應摩西五經），引用舊約逾60處。"
            "他的論點：耶穌就是彌賽亞，是應許給亞伯拉罕和大衛的、眾民盼望已久的君王。"
        ),
        author_en="Matthew (Levi), the apostle and former tax collector",
        author_hans="马太（利未），使徒，曾任税吏",
        author_hant="馬太（利未），使徒，曾任稅吏",
        date_en="ca. 60–70 CE",
        date_hans="约公元60–70年",
        date_hant="約公元60–70年",
        audience_en="Jewish believers in the Roman Empire",
        audience_hans="罗马帝国境内的犹太信徒",
        audience_hant="羅馬帝國境內的猶太信徒",
        themes_en=[
            "Kingdom of Heaven",
            "Fulfillment of prophecy",
            "Discipleship",
            "The Church",
        ],
        themes_hans=["天国", "应验预言", "门徒训练", "教会"],
        themes_hant=["天國", "應驗預言", "門徒訓練", "教會"],
        key_passage="Matthew 28:18-20",
        key_passage_desc_en=(
            "The Great Commission. The risen King's marching orders — make disciples of all "
            "nations — define the church's mission until he returns."
        ),
        key_passage_desc_hans=(
            "大使命。复活的君王所颁的命令——使万民作主门徒——定义了教会从此到祂再来的使命。"
        ),
        key_passage_desc_hant=(
            "大使命。復活的君王所頒的命令——使萬民作主門徒——定義了教會從此到祂再來的使命。"
        ),
    ),
    "Mark": _make(
        subtitle_en="The Servant King — Action-Driven Gospel of Jesus' Mighty Works",
        subtitle_hans="仆人君王——以行动彰显耶稣大能的福音书",
        subtitle_hant="僕人君王——以行動彰顯耶穌大能的福音書",
        summary_en=(
            "The shortest, fastest-paced Gospel. Mark's favorite word is 'immediately' — Jesus "
            "moves from miracle to teaching to confrontation at breakneck speed. The narrative "
            "hinges on Peter's confession at chapter 8 and tilts toward the cross from there."
        ),
        summary_hans=(
            "最简短、节奏最快的福音书。马可最常用的词是「立刻」——耶稣从神迹到教训、到冲突，"
            "一气呵成。叙事在第8章彼得的认信处转折，自此一路指向十架。"
        ),
        summary_hant=(
            "最簡短、節奏最快的福音書。馬可最常用的詞是「立刻」——耶穌從神蹟到教訓、到衝突，"
            "一氣呵成。敘事在第8章彼得的認信處轉折，自此一路指向十架。"
        ),
        author_en="John Mark, companion of Peter and Paul",
        author_hans="约翰马可，彼得与保罗的同工",
        author_hant="約翰馬可，彼得與保羅的同工",
        date_en="ca. 55–65 CE",
        date_hans="约公元55–65年",
        date_hant="約公元55–65年",
        audience_en="Roman Christians, possibly during Nero's persecution",
        audience_hans="罗马的基督徒，可能写于尼禄逼迫期间",
        audience_hant="羅馬的基督徒，可能寫於尼祿逼迫期間",
        themes_en=[
            "Jesus as Son of God",
            "Servant Messiah",
            "Discipleship",
            "Suffering and the Cross",
        ],
        themes_hans=["神的儿子", "仆人弥赛亚", "门徒训练", "受苦与十架"],
        themes_hant=["神的兒子", "僕人彌賽亞", "門徒訓練", "受苦與十架"],
        key_passage="Mark 10:45",
        key_passage_desc_en=(
            "The mission statement of Jesus' earthly ministry: 'The Son of Man came not to be "
            "served but to serve, and to give his life as a ransom for many.'"
        ),
        key_passage_desc_hans=(
            "耶稣对自己事工的定义：「人子来，不是要受人服事，乃是要服事人，并且要舍命，作多人的赎价。」"
        ),
        key_passage_desc_hant=(
            "耶穌對自己事工的定義：「人子來，不是要受人服事，乃是要服事人，並且要捨命，作多人的贖價。」"
        ),
    ),
    "John": _make(
        subtitle_en="The Word Made Flesh — That You May Believe",
        subtitle_hans="道成肉身——使你们可以相信",
        subtitle_hant="道成肉身——使你們可以相信",
        summary_en=(
            "John writes last among the Gospel writers, decades after the synoptic Gospels, with "
            "deep theological reflection. He selects seven signs and seven 'I am' sayings to drive "
            "one message home: Jesus is fully God and fully man, and believing in him is eternal life."
        ),
        summary_hans=(
            "约翰是四福音书最后一位作者，写于其他福音书后数十年，神学反思最深。他精选七个神迹与七个"
            "「我是」宣告，集中表达一个信息：耶稣完全是神、完全是人；信祂的，就有永生。"
        ),
        summary_hant=(
            "約翰是四福音書最後一位作者，寫於其他福音書後數十年，神學反思最深。他精選七個神蹟與七個"
            "「我是」宣告，集中表達一個信息：耶穌完全是神、完全是人；信祂的，就有永生。"
        ),
        author_en="John, the apostle, son of Zebedee",
        author_hans="使徒约翰，西庇太的儿子",
        author_hant="使徒約翰，西庇太的兒子",
        date_en="ca. 85–95 CE",
        date_hans="约公元85–95年",
        date_hant="約公元85–95年",
        audience_en="Believers and seekers of every background — explicitly evangelistic",
        audience_hans="各种背景的信徒与寻道者——明确以传福音为目的",
        audience_hant="各種背景的信徒與尋道者——明確以傳福音為目的",
        themes_en=[
            "Jesus as the eternal Word",
            "Belief and eternal life",
            "Light vs. darkness",
            "Truth",
            "Love",
        ],
        themes_hans=["永恒的道", "信与永生", "光与暗", "真理", "爱"],
        themes_hant=["永恆的道", "信與永生", "光與暗", "真理", "愛"],
        key_passage="John 3:16",
        key_passage_desc_en=(
            "The Bible's most-known verse, summarizing the Gospel in one sentence: God's love for "
            "the world expressed by sending his only Son, with eternal life freely offered to all who believe."
        ),
        key_passage_desc_hans=(
            "圣经中最为人所知的一节，一句话概括福音：神爱世人，赐下祂的独生子，凡信祂的，得永生。"
        ),
        key_passage_desc_hant=(
            "聖經中最為人所知的一節，一句話概括福音：神愛世人，賜下祂的獨生子，凡信祂的，得永生。"
        ),
    ),
    "Acts": _make(
        subtitle_en="The Spirit-Empowered Church — From Jerusalem to the Ends of the Earth",
        subtitle_hans="圣灵带领的教会——从耶路撒冷直到地极",
        subtitle_hant="聖靈帶領的教會——從耶路撒冷直到地極",
        summary_en=(
            "Acts is volume two of Luke's writings, picking up where his Gospel ends. After "
            "Pentecost, the Spirit propels the message from Jerusalem to Judea and Samaria and "
            "finally to Rome itself. Acts closes mid-mission — because the mission has not ended."
        ),
        summary_hans=(
            "使徒行传是路加著作的下篇，承接路加福音的结尾。五旬节之后，圣灵推动福音从耶路撒冷"
            "传到犹太、撒玛利亚，最终到罗马。全书在使命未完之处突然收尾——因为使命尚未结束。"
        ),
        summary_hant=(
            "使徒行傳是路加著作的下篇，承接路加福音的結尾。五旬節之後，聖靈推動福音從耶路撒冷"
            "傳到猶太、撒瑪利亞，最終到羅馬。全書在使命未完之處突然收尾——因為使命尚未結束。"
        ),
        author_en="Luke, the physician and traveling companion of Paul",
        author_hans="路加，医生，保罗的旅伴",
        author_hant="路加，醫生，保羅的旅伴",
        date_en="ca. 60–62 CE (some date as late as 80–90)",
        date_hans="约公元60–62年（部分学者认为晚至80–90年）",
        date_hant="約公元60–62年（部分學者認為晚至80–90年）",
        audience_en="Theophilus and the broader Greco-Roman world; an apologetic for the faith",
        audience_hans="提阿非罗及更广的希腊—罗马世界；为信仰辩护",
        audience_hant="提阿非羅及更廣的希臘—羅馬世界；為信仰辯護",
        themes_en=[
            "Holy Spirit",
            "Witness",
            "Mission",
            "Persecution",
            "Gentile inclusion",
        ],
        themes_hans=["圣灵", "见证", "宣教", "逼迫", "外邦人得入"],
        themes_hant=["聖靈", "見證", "宣教", "逼迫", "外邦人得入"],
        key_passage="Acts 1:8",
        key_passage_desc_en=(
            "Jesus' final command before ascension and the literal outline of the book: "
            "'You will be my witnesses in Jerusalem, in all Judea and Samaria, and to the ends of the earth.'"
        ),
        key_passage_desc_hans=(
            "耶稣升天前的最后命令，也是全书的结构纲要："
            "「你们要在耶路撒冷、犹太全地，和撒玛利亚，直到地极，作我的见证。」"
        ),
        key_passage_desc_hant=(
            "耶穌升天前的最後命令，也是全書的結構綱要："
            "「你們要在耶路撒冷、猶太全地，和撒瑪利亞，直到地極，作我的見證。」"
        ),
    ),
    "Romans": _make(
        subtitle_en="The Gospel Explained — Paul's Most Systematic Letter",
        subtitle_hans="福音的阐释——保罗最具系统性的书信",
        subtitle_hant="福音的闡釋——保羅最具系統性的書信",
        summary_en=(
            "Romans is Paul's most systematic explanation of the Gospel. Sin, justification by "
            "faith, the work of the Spirit, God's plan for Israel, and the practical life of the "
            "believer — all woven into one masterful argument. The letter has shaped every great "
            "Christian renewal from Augustine to Luther to today."
        ),
        summary_hans=(
            "罗马书是保罗对福音最具系统的阐述。罪、因信称义、圣灵的工作、神对以色列的计划、"
            "信徒的实际生活——交织成一篇精湛的论述。从奥古斯丁、路德到今日的每场基督教复兴，皆受其影响。"
        ),
        summary_hant=(
            "羅馬書是保羅對福音最具系統的闡述。罪、因信稱義、聖靈的工作、神對以色列的計劃、"
            "信徒的實際生活——交織成一篇精湛的論述。從奧古斯丁、路德到今日的每場基督教復興，皆受其影響。"
        ),
        author_en="The apostle Paul, writing from Corinth",
        author_hans="使徒保罗，写于哥林多",
        author_hant="使徒保羅，寫於哥林多",
        date_en="ca. 57 CE",
        date_hans="约公元57年",
        date_hant="約公元57年",
        audience_en="The Christians in Rome (a church Paul had not yet visited)",
        audience_hans="罗马的基督徒（保罗当时尚未到访的教会）",
        audience_hant="羅馬的基督徒（保羅當時尚未到訪的教會）",
        themes_en=[
            "Justification by faith",
            "The Gospel",
            "Sin and grace",
            "Life in the Spirit",
            "God's covenant faithfulness",
        ],
        themes_hans=["因信称义", "福音", "罪与恩典", "圣灵中的生命", "神的立约信实"],
        themes_hant=["因信稱義", "福音", "罪與恩典", "聖靈中的生命", "神的立約信實"],
        key_passage="Romans 1:16-17",
        key_passage_desc_en=(
            "Paul's thesis statement for the entire letter: the Gospel is the power of God "
            "for salvation, and 'the righteous shall live by faith' — the verse that sparked the Reformation."
        ),
        key_passage_desc_hans=(
            "保罗整卷书的论点宣告：福音是神的大能，要救一切相信的；「义人必因信得生」——"
            "正是引发宗教改革的那一节。"
        ),
        key_passage_desc_hant=(
            "保羅整卷書的論點宣告：福音是神的大能，要救一切相信的；「義人必因信得生」——"
            "正是引發宗教改革的那一節。"
        ),
    ),
    "Revelation": _make(
        subtitle_en="The Unveiling — Christ Triumphant Over History",
        subtitle_hans="揭示——基督在历史中得胜",
        subtitle_hant="揭示——基督在歷史中得勝",
        summary_en=(
            "The Bible's final book is also its most symbolic. John, exiled to Patmos, receives "
            "visions that pull back the curtain on cosmic history. Beneath the dragons, beasts, "
            "and trumpets is one assurance: the Lamb who was slain has conquered, and he will "
            "make all things new."
        ),
        summary_hans=(
            "圣经最后一卷，也是最具象征性的一卷。被流放到拔摩岛的约翰得到异象，揭开宇宙历史的帷幕。"
            "在龙、兽、号角的意象之下，是一个核心的应许：曾被杀的羔羊已经得胜，要使万物更新。"
        ),
        summary_hant=(
            "聖經最後一卷，也是最具象徵性的一卷。被流放到拔摩島的約翰得到異象，揭開宇宙歷史的帷幕。"
            "在龍、獸、號角的意象之下，是一個核心的應許：曾被殺的羔羊已經得勝，要使萬物更新。"
        ),
        author_en="John, the apostle, exiled on Patmos",
        author_hans="使徒约翰，被流放至拔摩岛",
        author_hant="使徒約翰，被流放至拔摩島",
        date_en="ca. 95 CE (during Domitian's reign)",
        date_hans="约公元95年（多米田在位期间）",
        date_hant="約公元95年（多米田在位期間）",
        audience_en="Seven churches in Asia Minor facing imperial persecution",
        audience_hans="小亚细亚的七间教会，面对罗马帝国的逼迫",
        audience_hant="小亞細亞的七間教會，面對羅馬帝國的逼迫",
        themes_en=[
            "Christ's victory",
            "Worship",
            "Judgment",
            "New creation",
            "The Lamb",
        ],
        themes_hans=["基督得胜", "敬拜", "审判", "新创造", "羔羊"],
        themes_hant=["基督得勝", "敬拜", "審判", "新創造", "羔羊"],
        key_passage="Revelation 21:3-4",
        key_passage_desc_en=(
            "The Bible's closing scene: God dwelling with his people, every tear wiped away, "
            "death and pain finally undone. The fulfillment of every promise from Genesis onward."
        ),
        key_passage_desc_hans=(
            "圣经的结尾画面：神与子民同住，擦去一切眼泪，死亡与痛苦都消失。"
            "从创世记开始的每个应许，都在此处成就。"
        ),
        key_passage_desc_hant=(
            "聖經的結尾畫面：神與子民同住，擦去一切眼淚，死亡與痛苦都消失。"
            "從創世記開始的每個應許，都在此處成就。"
        ),
    ),
}


def main() -> int:
    payload = {
        "_meta": {
            "version": 1,
            "books": list(INTROS.keys()),
            "generatedAt": _dt.datetime.now(_dt.timezone.utc).strftime(
                "%Y-%m-%dT%H:%M:%SZ"
            ),
            "description": (
                "Book-level introductions: subtitle, summary, author, date, audience, "
                "themes, and key-passage spotlight. Loaded by BookIntroService and "
                "rendered as a collapsible card at the top of the reading pane when a "
                "book opens at chapter 1."
            ),
        },
        "intros": INTROS,
    }
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    print(
        f"Wrote {len(INTROS)} book intros → {OUT} ({os.path.getsize(OUT)} bytes)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
