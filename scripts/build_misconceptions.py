#!/usr/bin/env python3
"""Build `assets/misconceptions.json`, verifying every claim as it goes.

A module that corrects other people's Bible mistakes is the single most
dangerous thing in this app. If it is wrong it is wrong *authoritatively*
— which is exactly the failure the project's standing rule names:

    经文一定要准确,查经的一定要最高 priority 准确
    "an interface that reads plausibly and is wrong gets believed and
     quoted"

So three rules are enforced here rather than trusted to care:

1.  **Every cited verse is read out of the app's own Bible assets** and
    checked to contain the words the entry leans on. A citation that
    does not say what the entry claims fails the build.

2.  **Every entry is categorised, and the categories are honest.**
    `text`      — the passage plainly says it; the claim misremembers
    `absent`    — scripture simply does not contain the claim
    `tradition` — it comes from a translation choice or later custom
    `disputed`  — scholarship is genuinely divided
    A `disputed` entry must never be rendered as a settled correction.
    Getting this wrong would have the module commit the very error it
    exists to point out.

3.  **No doctrinally contested items.** Nothing here adjudicates the
    Trinity, church government, baptism or the like. Not because those
    questions do not matter, but because this church holds positions on
    them and an "everyone gets this wrong" card is the wrong shape for
    a doctrinal argument. The entries below are about what the text
    says, not what it means.

Checking caught two entries that were about to be wrong the other way:
KJV really does print "whale" at Matthew 12:40 and "Lucifer" at Isaiah
14:12, so neither is a reader's invention — both are translation
choices, and the entries say so instead of claiming the Bible never
says it.
"""

import json
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
KJV = REPO / 'assets' / 'kjv.json'
OUT = REPO / 'assets' / 'misconceptions.json'

ENTRIES = [
    {
        'id': 'saul-paul',
        'topic': 'people',
        'category': 'text',
        'claim': {
            'zh-Hans': '保罗信主后，神把他的名字从「扫罗」改成「保罗」。',
            'zh-Hant': '保羅信主後，神把他的名字從「掃羅」改成「保羅」。',
            'en': 'God renamed Saul to Paul at his conversion.',
        },
        'says': {
            'zh-Hans': '经文从未记载改名。使徒行传 13:9 说的是「扫罗，又名保罗」——'
                       '两个名字同时属于他。扫罗是希伯来名，保罗（Paulus）是罗马名。'
                       '他生来就是罗马公民（徒 22:28「我生来就是」），罗马公民本就有'
                       '罗马名。而且他信主是在使徒行传第 9 章，「保罗」这个名字却到第 '
                       '13 章才出现——中间四章他仍叫扫罗。',
            'zh-Hant': '經文從未記載改名。使徒行傳 13:9 說的是「掃羅，又名保羅」——'
                       '兩個名字同時屬於他。掃羅是希伯來名，保羅（Paulus）是羅馬名。'
                       '他生來就是羅馬公民（徒 22:28「我生來就是」），羅馬公民本就有'
                       '羅馬名。而且他信主是在使徒行傳第 9 章，「保羅」這個名字卻到第 '
                       '13 章才出現——中間四章他仍叫掃羅。',
            'en': 'No renaming is recorded. Acts 13:9 says "Saul, who also '
                  'is called Paul" — both names were his. Saul is the Hebrew '
                  'name, Paul (Paulus) the Roman one, and he was a Roman '
                  'citizen by birth (Acts 22:28, "I was free born"). His '
                  'conversion is in Acts 9; the name Paul does not appear '
                  'until Acts 13, four chapters later.',
        },
        'refs': [
            {'book': 'Acts', 'chapter': '13', 'verse': '9', 'must': 'called Paul'},
            {'book': 'Acts', 'chapter': '22', 'verse': '28', 'must': 'free born'},
        ],
    },
    {
        'id': 'forbidden-fruit-apple',
        'topic': 'events',
        'category': 'tradition',
        'claim': {
            'zh-Hans': '亚当夏娃吃的禁果是苹果。',
            'zh-Hant': '亞當夏娃吃的禁果是蘋果。',
            'en': 'The forbidden fruit was an apple.',
        },
        'says': {
            'zh-Hans': '创世记 3:6 只说「果子」，从头到尾没有指明是什么果。'
                       '苹果的说法来自后来的西方绘画，以及拉丁文 malum 一词'
                       '既可解作「苹果」也可解作「恶」的双关。',
            'zh-Hant': '創世記 3:6 只說「果子」，從頭到尾沒有指明是什麼果。'
                       '蘋果的說法來自後來的西方繪畫，以及拉丁文 malum 一詞'
                       '既可解作「蘋果」也可解作「惡」的雙關。',
            'en': 'Genesis 3:6 says only "fruit" and never identifies it. '
                  'The apple comes from later Western painting and from the '
                  'Latin pun on malum, which means both "apple" and "evil".',
        },
        'refs': [
            {'book': 'Genesis', 'chapter': '3', 'verse': '6', 'must': 'fruit'},
        ],
    },
    {
        'id': 'jonah-whale',
        'topic': 'translation',
        'category': 'tradition',
        'claim': {
            'zh-Hans': '「圣经说约拿被鲸鱼吞了」是错的。',
            'zh-Hant': '「聖經說約拿被鯨魚吞了」是錯的。',
            'en': '"The Bible says a whale swallowed Jonah" is wrong.',
        },
        'says': {
            'zh-Hans': '这一条要小心，因为常见的「纠正」本身也不准确。'
                       '约拿书 1:17 的希伯来原文是 דָּג גָּדוֹל，「大鱼」；'
                       '马太福音 12:40 的希腊原文是 κῆτος，指海中巨兽。'
                       '但英文钦定本（KJV）在马太福音 12:40 确实印着 whale，'
                       '所以「鲸鱼」是译者的选择，不是读者凭空想出来的。'
                       '准确的说法是：原文说的是大鱼／海中巨兽，没有指明鲸鱼。',
            'zh-Hant': '這一條要小心，因為常見的「糾正」本身也不準確。'
                       '約拿書 1:17 的希伯來原文是 דָּג גָּדוֹל，「大魚」；'
                       '馬太福音 12:40 的希臘原文是 κῆτος，指海中巨獸。'
                       '但英文欽定本（KJV）在馬太福音 12:40 確實印著 whale，'
                       '所以「鯨魚」是譯者的選擇，不是讀者憑空想出來的。'
                       '準確的說法是：原文說的是大魚／海中巨獸，沒有指明鯨魚。',
            'en': 'Careful — the usual "correction" is itself inaccurate. '
                  'Jonah 1:17 has Hebrew דָּג גָּדוֹל, "great fish", and '
                  'Matthew 12:40 has Greek κῆτος, a large sea creature. But '
                  'the KJV really does print "whale" at Matthew 12:40, so the '
                  'whale is a translator\'s choice rather than a reader\'s '
                  'invention. What the originals say is a great fish or sea '
                  'creature, unspecified.',
        },
        'refs': [
            {'book': 'Jonah', 'chapter': '1', 'verse': '17', 'must': 'great fish'},
            {'book': 'Matthew', 'chapter': '12', 'verse': '40', 'must': 'whale'},
        ],
    },
    {
        'id': 'three-kings',
        'topic': 'events',
        'category': 'absent',
        'claim': {
            'zh-Hans': '有三位博士（或三位王）来朝拜婴孩耶稣。',
            'zh-Hant': '有三位博士（或三位王）來朝拜嬰孩耶穌。',
            'en': 'Three wise men (or three kings) visited the infant Jesus.',
        },
        'says': {
            'zh-Hans': '马太福音第 2 章从未说他们有几个人，也从未称他们为王。'
                       '「三」来自礼物的数目——黄金、乳香、没药（太 2:11）。'
                       '经文只说「有几个博士从东方来」。',
            'zh-Hant': '馬太福音第 2 章從未說他們有幾個人，也從未稱他們為王。'
                       '「三」來自禮物的數目——黃金、乳香、沒藥（太 2:11）。'
                       '經文只說「有幾個博士從東方來」。',
            'en': 'Matthew 2 never gives their number and never calls them '
                  'kings. The three comes from the three gifts — gold, '
                  'frankincense and myrrh (Matthew 2:11). The text says only '
                  '"wise men from the east".',
        },
        'refs': [
            {'book': 'Matthew', 'chapter': '2', 'verse': '1', 'must': 'wise men'},
            {'book': 'Matthew', 'chapter': '2', 'verse': '11', 'must': 'gold'},
        ],
    },
    {
        'id': 'money-root-of-evil',
        'topic': 'sayings',
        'category': 'text',
        'claim': {
            'zh-Hans': '圣经说「金钱是万恶之根」。',
            'zh-Hant': '聖經說「金錢是萬惡之根」。',
            'en': 'The Bible says money is the root of all evil.',
        },
        'says': {
            'zh-Hans': '提摩太前书 6:10 说的是「贪财是万恶之根」——'
                       '是「贪」，不是钱本身。少了一个字，意思就从'
                       '「对金钱的爱」变成了「金钱」。',
            'zh-Hant': '提摩太前書 6:10 說的是「貪財是萬惡之根」——'
                       '是「貪」，不是錢本身。少了一個字，意思就從'
                       '「對金錢的愛」變成了「金錢」。',
            'en': '1 Timothy 6:10 says "the LOVE of money is the root of all '
                  'evil". Drop three words and a warning about desire becomes '
                  'a claim about currency.',
        },
        'refs': [
            {'book': '1 Timothy', 'chapter': '6', 'verse': '10',
             'must': 'love of money'},
        ],
    },
    {
        'id': 'mary-magdalene-prostitute',
        'topic': 'people',
        'category': 'absent',
        'claim': {
            'zh-Hans': '抹大拉的马利亚是妓女。',
            'zh-Hant': '抹大拉的馬利亞是妓女。',
            'en': 'Mary Magdalene was a prostitute.',
        },
        'says': {
            'zh-Hans': '圣经从未这样说。路加福音 8:2 介绍她时说的是'
                       '「曾有七个鬼从她身上赶出来」。这个说法源自把她'
                       '与路加福音 7:37 那位没有名字的「有罪的女人」混为一谈——'
                       '那是另一段记载，经文也没有说那女人是妓女。',
            'zh-Hant': '聖經從未這樣說。路加福音 8:2 介紹她時說的是'
                       '「曾有七個鬼從她身上趕出來」。這個說法源自把她'
                       '與路加福音 7:37 那位沒有名字的「有罪的女人」混為一談——'
                       '那是另一段記載，經文也沒有說那女人是妓女。',
            'en': 'Scripture never says so. Luke 8:2 introduces her as the '
                  'one "out of whom went seven devils". The idea comes from '
                  'conflating her with the unnamed "sinner" of Luke 7:37 — a '
                  'different passage, which does not call that woman a '
                  'prostitute either.',
        },
        'refs': [
            {'book': 'Luke', 'chapter': '8', 'verse': '2', 'must': 'seven devils'},
            {'book': 'Luke', 'chapter': '7', 'verse': '37', 'must': 'sinner'},
        ],
    },
    {
        'id': 'lucifer-satan',
        'topic': 'translation',
        'category': 'tradition',
        'claim': {
            'zh-Hans': '以赛亚书 14:12 的「路西弗」就是撒但的名字。',
            'zh-Hant': '以賽亞書 14:12 的「路西弗」就是撒但的名字。',
            'en': 'Lucifer in Isaiah 14:12 is Satan\'s name.',
        },
        'says': {
            'zh-Hans': '这段话有明确的对象：以赛亚书 14:4 说「你必题这诗歌论'
                       '巴比伦王」。希伯来原文 הֵילֵל 意思是「明亮者／晨星」，'
                       '「路西弗」是拉丁文武加大译本的译法，钦定本沿用了它。'
                       '把它当作撒但的专名是后来的传统，不是这段经文本身说的。',
            'zh-Hant': '這段話有明確的對象：以賽亞書 14:4 說「你必題這詩歌論'
                       '巴比倫王」。希伯來原文 הֵילֵל 意思是「明亮者／晨星」，'
                       '「路西弗」是拉丁文武加大譯本的譯法，欽定本沿用了它。'
                       '把它當作撒但的專名是後來的傳統，不是這段經文本身說的。',
            'en': 'The passage names its subject: Isaiah 14:4 says "take up '
                  'this proverb against the king of Babylon". The Hebrew '
                  'הֵילֵל means "shining one / morning star"; "Lucifer" is the '
                  'Latin Vulgate\'s rendering, which the KJV kept. Reading it '
                  'as Satan\'s proper name is later tradition, not something '
                  'this passage states.',
        },
        'refs': [
            {'book': 'Isaiah', 'chapter': '14', 'verse': '12', 'must': 'Lucifer'},
            {'book': 'Isaiah', 'chapter': '14', 'verse': '4',
             'must': 'king of Babylon'},
        ],
    },
    {
        'id': 'hebrews-author',
        'topic': 'authorship',
        'category': 'disputed',
        'claim': {
            'zh-Hans': '希伯来书是保罗写的。',
            'zh-Hant': '希伯來書是保羅寫的。',
            'en': 'Paul wrote Hebrews.',
        },
        'says': {
            'zh-Hans': '这一条至今没有定论，本条只陈述可查证的部分：'
                       '希伯来书没有署名。保罗其余的书信都以他的名字开头'
                       '（「作使徒的保罗……」），希伯来书 1:1 却直接从'
                       '「神既在古时藉着众先知……」讲起。归给保罗是很早的传统，'
                       '但那是传统，不是经文的自述。**作者是谁仍是学界公开的问题。**',
            'zh-Hant': '這一條至今沒有定論，本條只陳述可查證的部分：'
                       '希伯來書沒有署名。保羅其餘的書信都以他的名字開頭'
                       '（「作使徒的保羅……」），希伯來書 1:1 卻直接從'
                       '「神既在古時藉著眾先知……」講起。歸給保羅是很早的傳統，'
                       '但那是傳統，不是經文的自述。**作者是誰仍是學界公開的問題。**',
            'en': 'This one is not settled, and this card states only what can '
                  'be checked: Hebrews carries no author\'s name. Paul\'s '
                  'other letters open with his ("Paul, an apostle…"); Hebrews '
                  '1:1 begins straight into "God, who at sundry times…". The '
                  'attribution to Paul is an early tradition, not a claim the '
                  'letter makes. **Who wrote it remains an open question.**',
        },
        'refs': [
            {'book': 'Hebrews', 'chapter': '1', 'verse': '1', 'must': 'God'},
        ],
    },
    {
        'id': 'god-helps-those',
        'topic': 'sayings',
        'category': 'absent',
        'claim': {
            'zh-Hans': '圣经说「神帮助自助者」。',
            'zh-Hant': '聖經說「神幫助自助者」。',
            'en': 'The Bible says "God helps those who help themselves".',
        },
        'says': {
            'zh-Hans': '这句话不在圣经里，任何一卷、任何一节都没有。'
                       '它的出处是古希腊寓言，英语世界的流行则来自'
                       '富兰克林《穷理查年鉴》。',
            'zh-Hant': '這句話不在聖經裡，任何一卷、任何一節都沒有。'
                       '它的出處是古希臘寓言，英語世界的流行則來自'
                       '富蘭克林《窮理查年鑑》。',
            'en': 'It is not in the Bible — not in any book, not in any verse. '
                  'The idea is from Greek fable, and its English currency '
                  'comes from Franklin\'s Poor Richard\'s Almanack.',
        },
        'refs': [],
    },
    {
        'id': 'noah-two-of-each',
        'topic': 'events',
        'category': 'text',
        'claim': {
            'zh-Hans': '方舟上的动物都是一公一母，每种一对。',
            'zh-Hant': '方舟上的動物都是一公一母，每種一對。',
            'en': 'The animals boarded the ark two by two, a pair of each kind.',
        },
        'says': {
            'zh-Hans': '两种说法经文里都有，但常被记漏一半。创世记 7:9 确实说'
                       '「一对一对」地进方舟；而 7:2 先交代了分别：'
                       '洁净的畜类要「每样七公七母」，不洁净的才是「一公一母」。'
                       '七对的用途在 8:20 显明——出方舟后献祭用的正是洁净的牲畜。',
            'zh-Hant': '兩種說法經文裡都有，但常被記漏一半。創世記 7:9 確實說'
                       '「一對一對」地進方舟；而 7:2 先交代了分別：'
                       '潔淨的畜類要「每樣七公七母」，不潔淨的才是「一公一母」。'
                       '七對的用途在 8:20 顯明——出方舟後獻祭用的正是潔淨的牲畜。',
            'en': 'Both are in the text, but half of it is usually forgotten. '
                  'Genesis 7:9 does say they went in "two and two"; 7:2 has '
                  'already drawn the distinction — clean beasts "by sevens", '
                  'unclean ones "by two". What the extra pairs were for '
                  'becomes clear in 8:20, where Noah sacrifices from the '
                  'clean animals after leaving the ark.',
        },
        'refs': [
            {'book': 'Genesis', 'chapter': '7', 'verse': '2', 'must': 'by sevens'},
            {'book': 'Genesis', 'chapter': '7', 'verse': '9', 'must': 'two and two'},
        ],
    },
    {
        'id': 'all-things-work-together',
        'topic': 'sayings',
        'category': 'text',
        'claim': {
            'zh-Hans': '罗马书 8:28 说「万事都互相效力」——凡事发生都有神的美意。',
            'zh-Hant': '羅馬書 8:28 說「萬事都互相效力」——凡事發生都有神的美意。',
            'en': 'Romans 8:28 promises everything happens for a reason.',
        },
        'says': {
            'zh-Hans': '经文有一个明确的对象，引用时常被略去：'
                       '「万事都互相效力，叫**爱神的人**得益处，就是按他旨意被召的人。」'
                       '这是对特定的人说的应许，不是一句关于世事的通则。',
            'zh-Hant': '經文有一個明確的對象，引用時常被略去：'
                       '「萬事都互相效力，叫**愛神的人**得益處，就是按他旨意被召的人。」'
                       '這是對特定的人說的應許，不是一句關於世事的通則。',
            'en': 'The verse names who it is addressed to, and the quotation '
                  'usually drops it: "all things work together for good **to '
                  'them that love God**, to them who are the called according '
                  'to his purpose." It is a promise to particular people, not '
                  'a general rule about events.',
        },
        'refs': [
            {'book': 'Romans', 'chapter': '8', 'verse': '28',
             'must': 'them that love God'},
        ],
    },
    {
        'id': 'magi-at-the-manger',
        'topic': 'events',
        'category': 'text',
        'claim': {
            'zh-Hans': '博士和牧羊人一同在马槽旁朝拜刚出生的耶稣。',
            'zh-Hant': '博士和牧羊人一同在馬槽旁朝拜剛出生的耶穌。',
            'en': 'The magi worshipped the newborn Jesus at the manger, '
                  'alongside the shepherds.',
        },
        'says': {
            'zh-Hans': '马太福音 2:11 说博士进的是「房子」，不是马槽——马槽只出现在'
                       '路加福音的记载里，而那里没有博士。时间也对不上：'
                       '希律照着博士所告诉他的时候，下令杀「两岁以里」的男孩（太 2:16），'
                       '这说明博士到达时已经过了一段时间。',
            'zh-Hant': '馬太福音 2:11 說博士進的是「房子」，不是馬槽——馬槽只出現在'
                       '路加福音的記載裡，而那裡沒有博士。時間也對不上：'
                       '希律照著博士所告訴他的時候，下令殺「兩歲以裡」的男孩（太 2:16），'
                       '這說明博士到達時已經過了一段時間。',
            'en': 'Matthew 2:11 has them entering a house, not a stable — the '
                  'manger belongs to Luke\'s account, which has no magi. The '
                  'timing does not fit either: Herod, going by what the magi '
                  'told him, killed boys "two years old and under" '
                  '(Matthew 2:16), which implies a considerable gap.',
        },
        'refs': [
            {'book': 'Matthew', 'chapter': '2', 'verse': '11', 'must': 'house'},
            {'book': 'Matthew', 'chapter': '2', 'verse': '16',
             'must': 'two years old and under'},
        ],
    },
    {
        'id': 'eye-of-needle-gate',
        'topic': 'sayings',
        'category': 'tradition',
        'claim': {
            'zh-Hans': '「针眼」是耶路撒冷一道矮门的名字，骆驼跪下卸货就能通过。',
            'zh-Hant': '「針眼」是耶路撒冷一道矮門的名字，駱駝跪下卸貨就能通過。',
            'en': 'The "eye of the needle" was a low gate in Jerusalem that a '
                  'camel could squeeze through on its knees.',
        },
        'says': {
            'zh-Hans': '**这一条要反过来纠正：被广传的不是经文，而是那个解释。**'
                       '马太福音 19:24 只说「骆驼穿过针的眼」。'
                       '耶路撒冷有一道叫「针眼」的小门——这个说法最早出现在中世纪的'
                       '注释里，没有任何古代文献或考古证据支持。'
                       '而且它把话讲反了：门徒听完的反应是「这样谁能得救呢」（19:25），'
                       '正说明他们听见的是「不可能」，不是「跪下就行」。',
            'zh-Hant': '**這一條要反過來糾正：被廣傳的不是經文，而是那個解釋。**'
                       '馬太福音 19:24 只說「駱駝穿過針的眼」。'
                       '耶路撒冷有一道叫「針眼」的小門——這個說法最早出現在中世紀的'
                       '註釋裡，沒有任何古代文獻或考古證據支持。'
                       '而且它把話講反了：門徒聽完的反應是「這樣誰能得救呢」（19:25），'
                       '正說明他們聽見的是「不可能」，不是「跪下就行」。',
            'en': '**This one corrects the explanation, not the text.** '
                  'Matthew 19:24 says only "a camel to go through the eye of a '
                  'needle". The Jerusalem gate story first appears in '
                  'medieval commentary and has no ancient source or '
                  'archaeological support. It also inverts the point: the '
                  'disciples answer "Who then can be saved?" (19:25), which is '
                  'the reaction to an impossibility, not to a tight squeeze.',
        },
        'refs': [
            {'book': 'Matthew', 'chapter': '19', 'verse': '24',
             'must': 'eye of a needle'},
            {'book': 'Matthew', 'chapter': '19', 'verse': '25',
             'must': 'Who then can be saved'},
        ],
    },
    {
        'id': 'be-still',
        'topic': 'sayings',
        'category': 'text',
        'claim': {
            'zh-Hans': '诗篇 46:10「你们要休息，要知道我是神」是叫人安静默想。',
            'zh-Hant': '詩篇 46:10「你們要休息，要知道我是神」是叫人安靜默想。',
            'en': 'Psalm 46:10 "Be still, and know that I am God" is a call to '
                  'quiet meditation.',
        },
        'says': {
            'zh-Hans': '上一节定了场景：「他止息刀兵，直到地极；他折弓、断枪，'
                       '把战车焚烧在火中」（诗 46:9）。这句话是对**列国**说的——'
                       '停手，认清谁是神。同一节的后半也是这个方向：'
                       '「我必在外邦中被尊崇，在遍地上也被尊崇。」'
                       '用它安静自己的心并无不可，但那不是这句话原本在说的事。',
            'zh-Hant': '上一節定了場景：「他止息刀兵，直到地極；他折弓、斷槍，'
                       '把戰車焚燒在火中」（詩 46:9）。這句話是對**列國**說的——'
                       '停手，認清誰是神。同一節的後半也是這個方向：'
                       '「我必在外邦中被尊崇，在遍地上也被尊崇。」'
                       '用它安靜自己的心並無不可，但那不是這句話原本在說的事。',
            'en': 'The previous verse sets the scene: "He maketh wars to cease '
                  'unto the end of the earth; he breaketh the bow, and cutteth '
                  'the spear in sunder" (46:9). The line is addressed to the '
                  'nations — stop, and recognise who God is. The rest of the '
                  'same verse points the same way: "I will be exalted among '
                  'the heathen." Using it for personal quiet is no crime; it '
                  'is simply not what the sentence was saying.',
        },
        'refs': [
            {'book': 'Psalms', 'chapter': '46', 'verse': '10', 'must': 'Be still'},
            {'book': 'Psalms', 'chapter': '46', 'verse': '9',
             'must': 'wars to cease'},
        ],
    },
    {
        'id': 'judge-not',
        'topic': 'sayings',
        'category': 'text',
        'claim': {
            'zh-Hans': '马太福音 7:1「你们不要论断人」意思是永远不可评断别人。',
            'zh-Hant': '馬太福音 7:1「你們不要論斷人」意思是永遠不可評斷別人。',
            'en': 'Matthew 7:1 "Judge not" means never evaluate anyone.',
        },
        'says': {
            'zh-Hans': '同一段话在四节之后自己给出了结论：'
                       '「你这假冒为善的人，先去掉自己眼中的梁木，'
                       '**然后才能看得清楚，去掉你弟兄眼中的刺**」（太 7:5）。'
                       '结尾不是「不要去掉」，而是「先处理自己的，然后才看得清楚」。'
                       '被禁止的是伪善的论断，不是分辨本身。',
            'zh-Hant': '同一段話在四節之後自己給出了結論：'
                       '「你這假冒為善的人，先去掉自己眼中的梁木，'
                       '**然後才能看得清楚，去掉你弟兄眼中的刺**」（太 7:5）。'
                       '結尾不是「不要去掉」，而是「先處理自己的，然後才看得清楚」。'
                       '被禁止的是偽善的論斷，不是分辨本身。',
            'en': 'The same passage states its own conclusion four verses '
                  'later: "Thou hypocrite, first cast out the beam out of '
                  'thine own eye; **and then shalt thou see clearly to cast '
                  'out the mote out of thy brother\'s eye**" (Matthew 7:5). '
                  'It does not end in "leave the mote alone" but in "deal with '
                  'your own first, then you will see clearly". What is '
                  'forbidden is hypocritical judgement, not discernment.',
        },
        'refs': [
            {'book': 'Matthew', 'chapter': '7', 'verse': '1', 'must': 'Judge not'},
            {'book': 'Matthew', 'chapter': '7', 'verse': '5',
             'must': 'see clearly'},
        ],
    },
    {
        'id': 'i-am-god-never-said',
        'topic': 'sayings',
        'category': 'text',
        'claim': {
            'zh-Hans': '福音书里有耶稣说「我是神」的记载。',
            'zh-Hant': '福音書裡有耶穌說「我是神」的記載。',
            'en': 'The Gospels record Jesus saying "I am God".',
        },
        'says': {
            'zh-Hans': '**这是一个可以数的事实。**「我是神」（I am God）这句话'
                       '在全本圣经出现 9 次，**四福音里一次也没有**。'
                       '那 9 处全是旧约中神自己说的（创 35:11、46:3；'
                       '诗 46:10、50:7；赛 43:12、45:22、46:9），'
                       '加上以西结 28:9 那句对推罗君王的反问。\n\n'
                       '**但数一句话不等于解决一个问题。** 讨论这件事时常被引用的'
                       '经文都真实存在，各家读法不同：约翰福音 8:58「还没有亚伯拉罕'
                       '就有了我」、10:30「我与父原为一」、14:9「人看见了我，就是'
                       '看见了父」、20:28 多马说「我的主，我的神」；另一边常引的是'
                       '约翰福音 17:3「认识你独一的真神」、14:28「父是比我大的」、'
                       '马可福音 13:32「那日子、那时辰，没有人知道……子也不知道」。'
                       '本卡片只报告字句的分布，不替任何一方作结论——'
                       '上面每一处都可以点开自己读。',
            'zh-Hant': '**這是一個可以數的事實。**「我是神」（I am God）這句話'
                       '在全本聖經出現 9 次，**四福音裡一次也沒有**。'
                       '那 9 處全是舊約中神自己說的（創 35:11、46:3；'
                       '詩 46:10、50:7；賽 43:12、45:22、46:9），'
                       '加上以西結 28:9 那句對推羅君王的反問。\n\n'
                       '**但數一句話不等於解決一個問題。** 討論這件事時常被引用的'
                       '經文都真實存在，各家讀法不同：約翰福音 8:58「還沒有亞伯拉罕'
                       '就有了我」、10:30「我與父原為一」、14:9「人看見了我，就是'
                       '看見了父」、20:28 多馬說「我的主，我的神」；另一邊常引的是'
                       '約翰福音 17:3「認識你獨一的真神」、14:28「父是比我大的」、'
                       '馬可福音 13:32「那日子、那時辰，沒有人知道……子也不知道」。'
                       '本卡片只報告字句的分佈，不替任何一方作結論——'
                       '上面每一處都可以點開自己讀。',
            'en': '**This part is countable.** The phrase "I am God" occurs 9 '
                  'times in the whole Bible and **not once in the four '
                  'Gospels**. All nine are God speaking in the Old Testament '
                  '(Genesis 35:11, 46:3; Psalms 46:10, 50:7; Isaiah 43:12, '
                  '45:22, 46:9), plus Ezekiel 28:9 taunting the prince of '
                  'Tyre.\n\n**But counting a phrase does not settle a '
                  'question.** The passages people bring to this discussion '
                  'are real and are read differently: John 8:58 "Before '
                  'Abraham was, I am", 10:30 "I and my Father are one", 14:9 '
                  '"he that hath seen me hath seen the Father", 20:28 Thomas\'s '
                  '"My Lord and my God"; and on the other side John 17:3 '
                  '"thee the only true God", 14:28 "my Father is greater than '
                  'I", Mark 13:32 "neither the Son, but the Father". This '
                  'card reports where the words fall and draws no conclusion '
                  'for you — every passage above opens with a tap.',
        },
        'refs': [
            {'book': 'Isaiah', 'chapter': '45', 'verse': '22', 'must': 'I am God'},
            {'book': 'John', 'chapter': '8', 'verse': '58', 'must': 'Before Abraham'},
            {'book': 'John', 'chapter': '10', 'verse': '30', 'must': 'are one'},
            {'book': 'John', 'chapter': '20', 'verse': '28', 'must': 'My LORD and my God'},
            {'book': 'John', 'chapter': '17', 'verse': '3', 'must': 'only true God'},
            {'book': 'John', 'chapter': '14', 'verse': '28', 'must': 'greater than I'},
            {'book': 'Mark', 'chapter': '13', 'verse': '32', 'must': 'neither the Son'},
        ],
    },
    {
        'id': 'theos-outnumbers-iesous',
        'topic': 'sayings',
        'category': 'text',
        'claim': {
            'zh-Hans': '新约既然是讲耶稣的，「耶稣」一定是出现最多的名词。',
            'zh-Hant': '新約既然是講耶穌的，「耶穌」一定是出現最多的名詞。',
            'en': 'Since the New Testament is about Jesus, "Jesus" must be '
                  'its most frequent name.',
        },
        'says': {
            'zh-Hans': '在本应用所载的希腊文新约里数过：'
                       'θεός（神，G2316）**1,317** 次，'
                       'Ἰησοῦς（耶稣，G2424）**917** 次。\n\n'
                       '更值得看的是分布：四福音里耶稣（566）多于神（305），'
                       '这很自然，因为那是叙述他生平的书卷；'
                       '**但四福音以外，神（1,012）几乎是耶稣（351）的三倍。**'
                       '这只是词频，不是教义论证——但它是可以自己数出来的。',
            'zh-Hant': '在本應用所載的希臘文新約裡數過：'
                       'θεός（神，G2316）**1,317** 次，'
                       'Ἰησοῦς（耶穌，G2424）**917** 次。\n\n'
                       '更值得看的是分佈：四福音裡耶穌（566）多於神（305），'
                       '這很自然，因為那是敘述他生平的書卷；'
                       '**但四福音以外，神（1,012）幾乎是耶穌（351）的三倍。**'
                       '這只是詞頻，不是教義論證——但它是可以自己數出來的。',
            'en': 'Counted in the Greek New Testament this app ships: θεός '
                  '(God, G2316) **1,317** times, Ἰησοῦς (Jesus, G2424) **917**.'
                  '\n\nThe distribution is the interesting part. In the four '
                  'Gospels Jesus (566) outnumbers God (305), which is what you '
                  'would expect of books narrating his life; **outside them, '
                  'God (1,012) outnumbers Jesus (351) by nearly three to '
                  'one.** This is word frequency, not a doctrinal argument — '
                  'but it is something you can count yourself.',
        },
        'refs': [],
    },
    {
        'id': 'lord-jesus-after-ascension',
        'topic': 'sayings',
        'category': 'text',
        'claim': {
            'zh-Hans': '「主耶稣」是福音书里常见的称呼。',
            'zh-Hant': '「主耶穌」是福音書裡常見的稱呼。',
            'en': '"Lord Jesus" is a common form of address in the Gospels.',
        },
        'says': {
            'zh-Hans': '数过希腊文：κύριος 紧接 Ἰησοῦς（「主耶稣」）在全新约出现 '
                       '**56 次**，其中**四福音里只有 2 次** —— '
                       '馬可福音 16:19 和 路加福音 24:3，'
                       '**而这两处都在复活之后**（一处是升天，一处是空坟墓）。'
                       '其余 54 次全在使徒行传和书信里，使徒行传单独占 15 次。\n\n'
                       '换句话说：门徒跟随他的时候不这样称呼他，'
                       '这个称呼属于复活与升天之后的教会。',
            'zh-Hant': '數過希臘文：κύριος 緊接 Ἰησοῦς（「主耶穌」）在全新約出現 '
                       '**56 次**，其中**四福音裡只有 2 次** —— '
                       '馬可福音 16:19 和 路加福音 24:3，'
                       '**而這兩處都在復活之後**（一處是升天，一處是空墳墓）。'
                       '其餘 54 次全在使徒行傳和書信裡，使徒行傳單獨佔 15 次。\n\n'
                       '換句話說：門徒跟隨他的時候不這樣稱呼他，'
                       '這個稱呼屬於復活與升天之後的教會。',
            'en': 'Counted in the Greek: κύριος immediately followed by Ἰησοῦς '
                  '("Lord Jesus") occurs **56 times** in the New Testament, of '
                  'which **only 2 are in the four Gospels** — Mark 16:19 and '
                  'Luke 24:3, **and both are after the resurrection** (the '
                  'ascension, and the empty tomb). The other 54 are all in '
                  'Acts and the letters, 15 in Acts alone.\n\nPut plainly: '
                  'it is not how the disciples addressed him while they '
                  'followed him. The title belongs to the church after the '
                  'resurrection and ascension.',
        },
        'refs': [
            {'book': 'Mark', 'chapter': '16', 'verse': '19', 'must': 'Lord'},
            {'book': 'Luke', 'chapter': '24', 'verse': '3', 'must': 'Lord Jesus'},
        ],
    },
    {
        'id': 'matthew-effect',
        'topic': 'sayings',
        'category': 'tradition',
        'claim': {
            'zh-Hans': '「马太效应」（强者愈强、弱者愈弱）出自马太福音，是圣经的教导。',
            'zh-Hant': '「馬太效應」（強者愈強、弱者愈弱）出自馬太福音，是聖經的教導。',
            'en': 'The "Matthew effect" — the rich get richer — is a teaching '
                  'of Matthew\'s Gospel.',
        },
        'says': {
            'zh-Hans': '这个词是社会学家 Robert Merton 在 1968 年提出的，'
                       '取自马太福音 25:29「凡有的，还要加给他，叫他有余；'
                       '没有的，连他所有的也要夺过来。」\n\n'
                       '但那节经文的上下文不是讲财富分配。它是**才干的比喻**的结尾：'
                       '主人远行前把家业交给仆人（25:14），回来后与他们算账；'
                       '被夺去的那位是把银子埋起来、什么都没做的仆人，'
                       '下一节称他为「无用的仆人」（25:30）。'
                       '比喻讲的是**如何对待主人所托付的**，不是社会上的贫富累积。\n\n'
                       '术语本身没有错——Merton 也从未说那是解经；'
                       '错的是把社会学的名字回过头当成经文的意思。',
            'zh-Hant': '這個詞是社會學家 Robert Merton 在 1968 年提出的，'
                       '取自馬太福音 25:29「凡有的，還要加給他，叫他有餘；'
                       '沒有的，連他所有的也要奪過來。」\n\n'
                       '但那節經文的上下文不是講財富分配。它是**才幹的比喻**的結尾：'
                       '主人遠行前把家業交給僕人（25:14），回來後與他們算賬；'
                       '被奪去的那位是把銀子埋起來、什麼都沒做的僕人，'
                       '下一節稱他為「無用的僕人」（25:30）。'
                       '比喻講的是**如何對待主人所託付的**，不是社會上的貧富累積。\n\n'
                       '術語本身沒有錯——Merton 也從未說那是解經；'
                       '錯的是把社會學的名字回過頭當成經文的意思。',
            'en': 'The term was coined by the sociologist Robert Merton in '
                  '1968, taking its name from Matthew 25:29: "unto every one '
                  'that hath shall be given… but from him that hath not shall '
                  'be taken away even that which he hath."\n\nThe context is '
                  'not wealth distribution. It closes the **parable of the '
                  'talents**: a master entrusts his goods to servants before '
                  'travelling (25:14) and settles accounts on his return. The '
                  'one who loses what he has is the servant who buried it and '
                  'did nothing; the next verse calls him "the unprofitable '
                  'servant" (25:30). The parable is about what you do with '
                  'what you were entrusted, not about advantage accumulating '
                  'in society.\n\nThe term itself is fine — Merton never '
                  'offered it as exegesis. The mistake is reading the '
                  'sociology back into the passage.',
        },
        'refs': [
            {'book': 'Matthew', 'chapter': '25', 'verse': '29',
             'must': 'shall be given'},
            {'book': 'Matthew', 'chapter': '25', 'verse': '14',
             'must': 'delivered unto them his goods'},
            {'book': 'Matthew', 'chapter': '25', 'verse': '30',
             'must': 'unprofitable servant'},
        ],
    },
    {
        'id': 'major-minor-prophets',
        'topic': 'canon',
        'category': 'tradition',
        'category_note': '',
        'claim': {
            'zh-Hans': '圣经把先知书分成「大先知书」和「小先知书」，大的更重要。',
            'zh-Hant': '聖經把先知書分成「大先知書」和「小先知書」，大的更重要。',
            'en': 'The Bible divides the prophets into Major and Minor, the '
                  'major ones being more important.',
        },
        # 2026-08-25, corrected on the user's report. The old answer argued
        # that "the length rule is not even applied consistently", citing
        # Lamentations (154 verses) as a Major Prophet shorter than Zechariah
        # (211). The numbers were right — all five counts below were re-counted
        # from assets/cuvs-yhwh.json — but the ARGUMENT was wrong, and the user
        # caught why: Lamentations is grouped with the Major Prophets because
        # tradition attributes it to Jeremiah and the Greek and Latin orderings
        # place it directly after his book. Jeremiah's own scroll is 1,364
        # verses, the longest of the group. So the classifiers were not being
        # sloppy about length; Lamentations arrived by association, and saying
        # otherwise accused them of an inconsistency they did not commit.
        #
        # It is now used the other way round — as the clearest evidence that
        # the category is a human one — together with the fact the old answer
        # missed entirely: in the Hebrew Bible neither Lamentations nor Daniel
        # sits among the Prophets at all. Both are in the Writings.
        'says': {
            'zh-Hans': '**这个划分不是圣经本身作的。**圣经从头到尾没有把先知'
                       '分成「大」「小」——这是后人加的类别，而且「大」「小」'
                       '说的是篇幅长短，不是分量轻重。\n\n'
                       '在希伯来圣经里，那十二卷根本不算十二本书，而是合为一卷，'
                       '称为「十二书」（תרי עשר）——十二卷加起来 **1,050 节**，'
                       '才够抄满一个卷轴，与以赛亚（**1,292 节**）、'
                       '耶利米（**1,364 节**）各自一卷相当。所以那个「小」字，'
                       '本来说的是**卷轴**，不是价值。「大先知」「小先知」这对'
                       '名称出自后来的拉丁教会；奥古斯丁在《上帝之城》里说得很'
                       '直白：那十二位被称为「小」，是因为他们的话短。\n\n'
                       '**最能说明这是人订的分类，是耶利米哀歌和但以理书。**'
                       '在希伯来圣经里，这两卷根本不在先知书（Nevi\'im）中，'
                       '而是归在「著作」（Ketuvim）里。是希腊文和拉丁文译本把'
                       '哀歌挪到耶利米书后面，它才跟着算进「大先知」。'
                       '哀歌只有 **154 节**，比「小先知书」里的撒迦利亚书'
                       '（**211 节**）还短——它算「大」，靠的是传统归给耶利米的'
                       '作者身份和排列的位置，不是篇幅。耶利米自己那一卷 '
                       '**1,364 节**，是这一组里最长的。',
            'zh-Hant': '**這個劃分不是聖經本身作的。**聖經從頭到尾沒有把先知'
                       '分成「大」「小」——這是後人加的類別，而且「大」「小」'
                       '說的是篇幅長短，不是分量輕重。\n\n'
                       '在希伯來聖經裡，那十二卷根本不算十二本書，而是合為一卷，'
                       '稱為「十二書」（תרי עשר）——十二卷加起來 **1,050 節**，'
                       '才夠抄滿一個卷軸，與以賽亞（**1,292 節**）、'
                       '耶利米（**1,364 節**）各自一卷相當。所以那個「小」字，'
                       '本來說的是**卷軸**，不是價值。「大先知」「小先知」這對'
                       '名稱出自後來的拉丁教會；奧古斯丁在《上帝之城》裡說得很'
                       '直白：那十二位被稱為「小」，是因為他們的話短。\n\n'
                       '**最能說明這是人訂的分類，是耶利米哀歌和但以理書。**'
                       '在希伯來聖經裡，這兩卷根本不在先知書（Nevi\'im）中，'
                       '而是歸在「著作」（Ketuvim）裡。是希臘文和拉丁文譯本把'
                       '哀歌挪到耶利米書後面，它才跟著算進「大先知」。'
                       '哀歌只有 **154 節**，比「小先知書」裡的撒迦利亞書'
                       '（**211 節**）還短——它算「大」，靠的是傳統歸給耶利米的'
                       '作者身份和排列的位置，不是篇幅。耶利米自己那一卷 '
                       '**1,364 節**，是這一組裡最長的。',
            'en': '**Scripture does not make this division.** Nowhere does the '
                  'Bible sort the prophets into major and minor — the category '
                  'is a later human one, and "major" and "minor" describe '
                  'length, not weight.\n\nIn the Hebrew Bible the twelve are '
                  'not twelve books at all but one, "The Twelve" (תרי עשר), '
                  'because together (**1,050 verses**) they filled a single '
                  'scroll of about the size Isaiah (**1,292**) or Jeremiah '
                  '(**1,364**) needed on their own. The word "minor" was '
                  'describing a scroll, not a value. The labels themselves come '
                  'from the later Latin church; Augustine, in *The City of '
                  'God*, says it plainly — the twelve are called minor because '
                  'their discourses are short.\n\n**The clearest sign that '
                  'the category is ours and not the Bible\'s is Lamentations '
                  'and Daniel.** In the Hebrew Bible neither sits among the '
                  'Prophets at all; both belong to the Writings (Ketuvim). It '
                  'was the Greek and Latin orderings that moved Lamentations to '
                  'follow Jeremiah, and only then did it travel with the Major '
                  'Prophets. It runs to **154 verses**, shorter than Zechariah '
                  '(**211**) among the Minor ones — it counts as major on the '
                  'strength of its traditional authorship and its position, not '
                  'its length. Jeremiah\'s own scroll, at **1,364 verses**, is '
                  'the longest of the group.',
        },
        'refs': [],
    },
    {
        'id': 'angel-hierarchy',
        'topic': 'people',
        'category': 'tradition',
        'claim': {
            'zh-Hans': '天使有严格的等级，加百列是最大的天使。',
            'zh-Hant': '天使有嚴格的等級，加百列是最大的天使。',
            'en': 'Angels have a strict rank order, and Gabriel is the '
                  'highest angel.',
        },
        'says': {
            'zh-Hans': '**两个方向都要更正，而第二个更少人知道。**\n\n'
                       '一、加百列全圣经只出现 4 次（但 8:16、9:21、路 1:19、'
                       '1:26），**从来没有被称为天使长**。他自己的说法是'
                       '「我是站在神面前的加百列」（路 1:19）。'
                       '「天使长」这个词全圣经只出现 2 次（帖前 4:16、犹 9），'
                       '而犹大书 9 点名的是**米迦勒**。'
                       '但以理书 10:13 也称米迦勒为「大君中的一位」——'
                       '「一位」这个说法本身就表示还有别的。\n\n'
                       '二、**但「严格的等级」本身也不是圣经说的。**'
                       '经文确实提到多种天上的活物：基路伯（创 3:24）、'
                       '撒拉弗（赛 6:2）、以及「有位的、主治的、执政的、掌权的」'
                       '（西 1:16）——但那是列举，不是排名。'
                       '圣经从未把它们排出高低次序。\n\n'
                       '我们熟悉的九级天使体系（撒拉弗、基路伯、座天使……）'
                       '出自约公元 500 年托名「亚略巴古的丢尼修」的著作，'
                       '是后来的系统化，不是经文的分类。'
                       '所以说「基路伯比加百列高」，同样是在断言经文没有给的次序。',
            'zh-Hant': '**兩個方向都要更正，而第二個更少人知道。**\n\n'
                       '一、加百列全聖經只出現 4 次（但 8:16、9:21、路 1:19、'
                       '1:26），**從來沒有被稱為天使長**。他自己的說法是'
                       '「我是站在神面前的加百列」（路 1:19）。'
                       '「天使長」這個詞全聖經只出現 2 次（帖前 4:16、猶 9），'
                       '而猶大書 9 點名的是**米迦勒**。'
                       '但以理書 10:13 也稱米迦勒為「大君中的一位」——'
                       '「一位」這個說法本身就表示還有別的。\n\n'
                       '二、**但「嚴格的等級」本身也不是聖經說的。**'
                       '經文確實提到多種天上的活物：基路伯（創 3:24）、'
                       '撒拉弗（賽 6:2）、以及「有位的、主治的、執政的、掌權的」'
                       '（西 1:16）——但那是列舉，不是排名。'
                       '聖經從未把它們排出高低次序。\n\n'
                       '我們熟悉的九級天使體系（撒拉弗、基路伯、座天使……）'
                       '出自約公元 500 年託名「亞略巴古的丟尼修」的著作，'
                       '是後來的系統化，不是經文的分類。'
                       '所以說「基路伯比加百列高」，同樣是在斷言經文沒有給的次序。',
            'en': '**Both halves need correcting, and the second is the less '
                  'well known.**\n\nFirst: Gabriel appears four times in the '
                  'whole Bible (Daniel 8:16, 9:21, Luke 1:19, 1:26) and is '
                  '**never called an archangel**. His own words are "I am '
                  'Gabriel, that stand in the presence of God" (Luke 1:19). '
                  'The word "archangel" occurs exactly twice (1 Thess 4:16, '
                  'Jude 9), and Jude 9 names **Michael**. Daniel 10:13 calls '
                  'Michael "one of the chief princes" — "one of" implying '
                  'others.\n\nSecond: **the strict hierarchy is not '
                  'scripture either.** The text names several kinds of '
                  'heavenly beings — cherubim (Genesis 3:24), seraphim '
                  '(Isaiah 6:2), "thrones, dominions, principalities, powers" '
                  '(Colossians 1:16) — but that is a list, not a ranking. '
                  'Scripture nowhere orders them above one another.\n\nThe '
                  'familiar nine orders come from the writings attributed to '
                  'Dionysius the Areopagite, around AD 500 — a later '
                  'systematisation, not the Bible\'s own scheme. So "cherubim '
                  'outrank Gabriel" asserts an order the text does not give '
                  'either.',
        },
        'refs': [
            {'book': 'Luke', 'chapter': '1', 'verse': '19', 'must': 'I am Gabriel'},
            {'book': 'Jude', 'chapter': '1', 'verse': '9',
             'must': 'Michael the archangel'},
            {'book': 'Daniel', 'chapter': '10', 'verse': '13',
             'must': 'one of the chief princes'},
            {'book': 'Genesis', 'chapter': '3', 'verse': '24', 'must': 'Cherubims'},
            {'book': 'Isaiah', 'chapter': '6', 'verse': '2', 'must': 'seraphims'},
            {'book': 'Colossians', 'chapter': '1', 'verse': '16', 'must': 'thrones'},
        ],
    },
    {
        'id': 'ark-is-a-box',
        'topic': 'translation',
        'category': 'text',
        'claim': {
            'zh-Hans': '挪亚方舟是一艘船，像图画里那样有船头、龙骨和风帆。',
            'zh-Hant': '挪亞方舟是一艘船，像圖畫裡那樣有船頭、龍骨和風帆。',
            'en': "Noah's ark was a ship, with a bow, a keel and sails, the "
                  'way it is always drawn.',
        },
        'says': {
            'zh-Hans': '**希伯来原文用的字是 תֵּבָה（tebah），意思是「箱子」。**'
                       '这个字在整本希伯来圣经只出现 **28 次**，'
                       '而且只在两个地方：创世记里挪亚的方舟（26 次），'
                       '和出埃及记 2:3、2:5 里摩西那个蒲草箱子——'
                       '一个漂在河边芦苇丛中的篮子。'
                       '同一个字，同一类东西：一个能浮起来、'
                       '把里面的东西保住的容器。\n\n'
                       '经文给的也是箱子的尺寸，不是船的线条：'
                       '长三百肘、宽五十肘、高三十肘（创 6:15），'
                       '一扇窗、旁边一个门、上中下三层（创 6:16）。'
                       '**没有提到船头、龙骨、舵、桅杆、帆或桨——一样都没有。**'
                       '希伯来文另有「船」这个字（אֳנִיָּה），'
                       '全书用了 31 次，却一次也没有用在方舟上。\n\n'
                       '这不是抠字眼，是关乎这段记载在说什么：'
                       '方舟不是用来航行的，是用来漂的。'
                       '创世记 8:4 说它「停在」亚拉腊山上——它从没有被驾驶过，'
                       '也没有航向。保全他们的不是挪亚的操舵。\n\n'
                       '顺带一提，中文和英文里「约柜」的「柜／ark」是另一个字'
                       '（אֲרוֹן，aron，全书 202 次），跟方舟毫无关系；'
                       '创世记 50:26 里同一个字指的是约瑟的棺材。'
                       '两个字在中文英文里碰巧撞在一起，在希伯来文里从不相干。',
            'zh-Hant': '**希伯來原文用的字是 תֵּבָה（tebah），意思是「箱子」。**'
                       '這個字在整本希伯來聖經只出現 **28 次**，'
                       '而且只在兩個地方：創世記裡挪亞的方舟（26 次），'
                       '和出埃及記 2:3、2:5 裡摩西那個蒲草箱子——'
                       '一個漂在河邊蘆葦叢中的籃子。'
                       '同一個字，同一類東西：一個能浮起來、'
                       '把裡面的東西保住的容器。\n\n'
                       '經文給的也是箱子的尺寸，不是船的線條：'
                       '長三百肘、寬五十肘、高三十肘（創 6:15），'
                       '一扇窗、旁邊一個門、上中下三層（創 6:16）。'
                       '**沒有提到船頭、龍骨、舵、桅桿、帆或槳——一樣都沒有。**'
                       '希伯來文另有「船」這個字（אֳנִיָּה），'
                       '全書用了 31 次，卻一次也沒有用在方舟上。\n\n'
                       '這不是摳字眼，是關乎這段記載在說什麼：'
                       '方舟不是用來航行的，是用來漂的。'
                       '創世記 8:4 說它「停在」亞拉臘山上——它從沒有被駕駛過，'
                       '也沒有航向。保全他們的不是挪亞的操舵。\n\n'
                       '順帶一提，中文和英文裡「約櫃」的「櫃／ark」是另一個字'
                       '（אֲרוֹן，aron，全書 202 次），跟方舟毫無關係；'
                       '創世記 50:26 裡同一個字指的是約瑟的棺材。'
                       '兩個字在中文英文裡碰巧撞在一起，在希伯來文裡從不相干。',
            'en': '**The Hebrew word is תֵּבָה (tebah) — a box, a chest.** It '
                  'occurs **28 times** in the whole Hebrew Bible, in exactly '
                  "two places: Noah's ark in Genesis (26), and the basket of "
                  'bulrushes Moses was laid in at Exodus 2:3 and 2:5 — a '
                  'container floating in the reeds by a riverbank. Same word, '
                  'same kind of object: something that floats and keeps what '
                  'is inside it alive.\n\nThe measurements given are a '
                  "box's, not a hull's: three hundred cubits by fifty by "
                  'thirty (Gen 6:15), one window, a door in the side, and '
                  'three decks (Gen 6:16). **No bow, no keel, no rudder, no '
                  'mast, no sail, no oars are mentioned — not one.** Hebrew '
                  'has a perfectly good word for ship (אֳנִיָּה), used 31 '
                  'times, and it is never once used of the ark.\n\nThis is '
                  'not pedantry about a word; it is what the account is '
                  'saying. The ark was not built to sail but to float. '
                  'Genesis 8:4 says it *rested* on the mountains of Ararat — '
                  'it was never steered and had no course. What preserved '
                  'them was not Noah\'s seamanship.\n\nWorth adding: the '
                  '"ark" of the covenant is a different Hebrew word '
                  'altogether (אֲרוֹן, aron, 202 times), unrelated to this '
                  'one — and at Genesis 50:26 that same word means Joseph\'s '
                  'coffin. The two arks collide only in English.',
        },
        'refs': [
            {'book': 'Genesis', 'chapter': '6', 'verse': '15',
             'must': 'three hundred cubits'},
            {'book': 'Genesis', 'chapter': '6', 'verse': '16',
             'must': 'door of the ark shalt thou set in the side'},
            {'book': 'Exodus', 'chapter': '2', 'verse': '3',
             'must': 'ark of bulrushes'},
            {'book': 'Exodus', 'chapter': '2', 'verse': '5',
             'must': 'saw the ark among the flags'},
            {'book': 'Genesis', 'chapter': '8', 'verse': '4',
             'must': 'ark rested'},
            {'book': 'Genesis', 'chapter': '50', 'verse': '26',
             'must': 'put in a coffin'},
        ],
    },
]


NT_BOOKS = [
    'matthew', 'mark', 'luke', 'john', 'acts', 'romans', '1_corinthians',
    '2_corinthians', 'galatians', 'ephesians', 'philippians', 'colossians',
    '1_thessalonians', '2_thessalonians', '1_timothy', '2_timothy', 'titus',
    'philemon', 'hebrews', 'james', '1_peter', '2_peter', '1_john', '2_john',
    '3_john', 'jude', 'revelation',
]
GOSPELS = {'matthew', 'mark', 'luke', 'john'}


def _hebrew_strongs_count(code):
    """How many times a Strong's Hebrew number occurs in assets/originals.

    The ark card asserts three counts — tebah 28, aron 202, oniyah 31 —
    and the whole point of that card is that the word choice is exact.
    Numbers asserted about the Hebrew have to be recomputed from the
    Hebrew, not from an English translation that renders two different
    words as the same "ark".
    """
    total = 0
    books = set()
    for path in sorted((REPO / 'assets' / 'originals').glob('*.json')):
        data = json.loads(path.read_text(encoding='utf-8'))
        for words in data.values():
            for w in words:
                if (w.get('s') or '').split('/')[0] == code:
                    total += 1
                    books.add(path.stem)
    return total, books


def _greek_counts():
    """Recount the Greek NT rather than trusting a number in a card.

    Entries that assert "X occurs more often than Y" are the easiest
    kind to get wrong and the hardest for a reader to check, so the
    build recomputes them from assets/originals and fails if a card's
    figure has drifted.
    """
    import collections
    total = collections.Counter()
    gospels = collections.Counter()
    lord_jesus = {'gospels': [], 'rest': 0}
    for b in NT_BOOKS:
        f = REPO / 'assets' / 'originals' / f'{b}.json'
        if not f.exists():
            continue
        d = json.loads(f.read_text(encoding='utf-8'))
        for ref, toks in d.items():
            for i, t in enumerate(toks):
                st = t.get('s')
                if st in ('G2316', 'G2424'):
                    total[st] += 1
                    if b in GOSPELS:
                        gospels[st] += 1
                # κύριος immediately followed by Ἰησοῦς
                if (st == 'G2962' and i + 1 < len(toks)
                        and toks[i + 1].get('s') == 'G2424'):
                    if b in GOSPELS:
                        lord_jesus['gospels'].append(f'{b} {ref}')
                    else:
                        lord_jesus['rest'] += 1
    return total, gospels, lord_jesus


def _kjv_phrase_count(rows, phrase, books=None):
    import re
    pat = re.compile(r'\b' + re.escape(phrase) + r'\b', re.I)
    return sum(1 for r in rows
               if (books is None or r['book'] in books)
               and pat.search(r['text']))


def main():
    rows = json.loads(KJV.read_text(encoding='utf-8'))
    idx = {(r['book'], r['chapter'], r['verse']): r['text'].strip()
           for r in rows}

    failures = []
    for e in ENTRIES:
        for ref in e['refs']:
            key = (ref['book'], ref['chapter'], ref['verse'])
            text = idx.get(key)
            if text is None:
                failures.append(f"{e['id']}: {key} not in kjv.json")
                continue
            if ref['must'].lower() not in text.lower():
                failures.append(
                    f"{e['id']}: {ref['book']} {ref['chapter']}:{ref['verse']} "
                    f"does not contain {ref['must']!r} — {text[:90]!r}")

    # Countable assertions, recomputed here.
    total, gospels, lj = _greek_counts()
    checks = [
        ('theos>iesous', total['G2316'], 1317),
        ('iesous', total['G2424'], 917),
        ('gospels-theos', gospels['G2316'], 305),
        ('gospels-iesous', gospels['G2424'], 566),
        ('lord-jesus-in-gospels', len(lj['gospels']), 2),
        ('lord-jesus-elsewhere', lj['rest'], 54),
        ('i-am-god-whole-bible', _kjv_phrase_count(rows, 'I am God'), 9),
        ('lamentations-verses',
         sum(1 for r in rows if r['book'] == 'Lamentations'), 154),
        ('zechariah-verses',
         sum(1 for r in rows if r['book'] == 'Zechariah'), 211),
        ('isaiah-verses',
         sum(1 for r in rows if r['book'] == 'Isaiah'), 1292),
        ('jeremiah-verses',
         sum(1 for r in rows if r['book'] == 'Jeremiah'), 1364),
        ('the-twelve-verses',
         sum(1 for r in rows if r['book'] in {
             'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum',
             'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi'}), 1050),
        ('gabriel-mentions', _kjv_phrase_count(rows, 'Gabriel'), 4),
        ('archangel-mentions', _kjv_phrase_count(rows, 'archangel'), 2),
        # The ark card: tebah is a box, and the word for ship is never
        # used of it.
        ('tebah-occurrences', _hebrew_strongs_count('H8392')[0], 28),
        ('aron-occurrences', _hebrew_strongs_count('H727')[0], 202),
        ('oniyah-occurrences', _hebrew_strongs_count('H591')[0], 31),
        ('i-am-god-in-gospels',
         _kjv_phrase_count(rows, 'I am God',
                           {'Matthew', 'Mark', 'Luke', 'John'}), 0),
    ]
    for name, got, want in checks:
        if got != want:
            failures.append(f'count {name}: recomputed {got}, cards say {want}')
    # tebah appears in Genesis and Exodus and NOWHERE else — that
    # exclusivity, not just the count, is what the card argues from.
    tebah_books = _hebrew_strongs_count('H8392')[1]
    if tebah_books != {'genesis', 'exodus'}:
        failures.append(f'tebah is no longer Genesis+Exodus only: '
                        f'{sorted(tebah_books)}')

    if sorted(lj['gospels']) != ['luke 24:3', 'mark 16:19']:
        failures.append(f"lord-jesus gospel occurrences moved: {lj['gospels']}")

    if failures:
        print('VERIFICATION FAILED — nothing written:', file=sys.stderr)
        for f in failures:
            print('  ' + f, file=sys.stderr)
        raise SystemExit(1)

    doc = {
        '_meta': {
            'note': ('Every citation is verified against assets/kjv.json by '
                     'scripts/build_misconceptions.py before this file is '
                     'written. Entries are categorised text / absent / '
                     'tradition / disputed, and a disputed entry must never '
                     'be rendered as a settled correction.'),
            'checked': sum(len(e['refs']) for e in ENTRIES),
        'countChecks': len(checks),
        },
        'entries': ENTRIES,
    }
    OUT.write_text(json.dumps(doc, ensure_ascii=False, indent=2),
                   encoding='utf-8')
    print(f'{len(ENTRIES)} entries, '
          f'{doc["_meta"]["checked"]} citations verified -> {OUT.name}')


if __name__ == '__main__':
    main()
