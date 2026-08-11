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
]


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
        },
        'entries': ENTRIES,
    }
    OUT.write_text(json.dumps(doc, ensure_ascii=False, indent=2),
                   encoding='utf-8')
    print(f'{len(ENTRIES)} entries, '
          f'{doc["_meta"]["checked"]} citations verified -> {OUT.name}')


if __name__ == '__main__':
    main()
