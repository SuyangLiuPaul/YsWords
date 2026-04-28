#!/usr/bin/env python3
"""
Author section/paragraph titles for Bible chapters and bundle them
into a single asset:  assets/section_titles.json.

Schema:
  {
    "_meta": { "version": 1, "books": ["Genesis", "Matthew", "John", "Romans"] },
    "sets": {
      "<set-id>": {
        "<EnglishBookName>": {
          "<chapter-as-string>": [
            {"verse": <int>, "title": "<heading text>"},
            ...
          ]
        }
      }
    }
  }

Three sets are emitted in this Phase-1 file:
  • cuv               — simplified-Chinese 和合本-style headings
  • cuv-tr            — traditional-Chinese mirror of cuv
  • english-classic   — neutral English Bible-society style headings

The title-set-per-version mapping lives in
`lib/constants/section_title_map.dart`. New title sets (e.g. cnv) can
be added later without code changes once authored.

Pairs are author-curated (not machine-translated) so that each
language reads naturally for its audience.
"""
from __future__ import annotations

import datetime as _dt
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "section_titles.json")


# Each entry is: (chapter, verse, title_simplified, title_traditional, title_english)
# Authored against well-known CUV / KJV-style section divisions.
GENESIS: list[tuple[int, int, str, str, str]] = [
    (1, 1, "起初创造天地", "起初創造天地", "The Creation"),
    (1, 14, "第四日：日月星辰", "第四日：日月星辰", "The Fourth Day: Sun, Moon, and Stars"),
    (1, 26, "创造人类", "創造人類", "The Creation of Mankind"),
    (2, 1, "第七日安息", "第七日安息", "The Seventh Day, God Rests"),
    (2, 4, "伊甸园", "伊甸園", "The Garden of Eden"),
    (2, 18, "造夏娃", "造夏娃", "The Creation of Woman"),
    (3, 1, "人类的堕落", "人類的墮落", "The Fall of Mankind"),
    (3, 14, "神的审判", "神的審判", "Judgment and Promise"),
    (3, 22, "驱逐出园", "驅逐出園", "Expulsion from Eden"),
    (4, 1, "该隐与亚伯", "該隱與亞伯", "Cain and Abel"),
    (4, 17, "该隐的后裔", "該隱的後裔", "The Descendants of Cain"),
    (4, 25, "塞特的家系", "塞特的家系", "Seth and His Descendants"),
    (5, 1, "亚当的家谱", "亞當的家譜", "The Genealogy from Adam to Noah"),
    (6, 1, "人类的败坏", "人類的敗壞", "The Wickedness of Mankind"),
    (6, 9, "挪亚造方舟", "挪亞造方舟", "Noah and the Ark"),
    (7, 1, "洪水来到", "洪水來到", "The Great Flood"),
    (8, 1, "洪水退去", "洪水退去", "The Flood Recedes"),
    (8, 20, "挪亚献祭", "挪亞獻祭", "Noah's Sacrifice"),
    (9, 1, "神与挪亚立约", "神與挪亞立約", "God's Covenant with Noah"),
    (9, 18, "挪亚的预言", "挪亞的預言", "Noah's Sons"),
    (10, 1, "列国的起源", "列國的起源", "The Table of Nations"),
    (11, 1, "巴别塔", "巴別塔", "The Tower of Babel"),
    (11, 10, "闪的家谱", "閃的家譜", "The Genealogy from Shem to Abram"),
    (11, 27, "他拉的家谱", "他拉的家譜", "The Family of Terah"),
    (12, 1, "神呼召亚伯兰", "神呼召亞伯蘭", "The Call of Abram"),
    (12, 10, "亚伯兰下埃及", "亞伯蘭下埃及", "Abram in Egypt"),
    (13, 1, "亚伯兰与罗得分地", "亞伯蘭與羅得分地", "Abram and Lot Separate"),
    (14, 1, "列王交战", "列王交戰", "Abram Rescues Lot"),
    (14, 17, "麦基洗德祝福亚伯兰", "麥基洗德祝福亞伯蘭", "Melchizedek Blesses Abram"),
    (15, 1, "神与亚伯兰立约", "神與亞伯蘭立約", "God's Covenant with Abram"),
    (16, 1, "夏甲与以实玛利", "夏甲與以實瑪利", "Hagar and Ishmael"),
    (17, 1, "立割礼之约", "立割禮之約", "The Covenant of Circumcision"),
    (18, 1, "三位访客", "三位訪客", "The Three Visitors"),
    (18, 16, "亚伯拉罕为所多玛代求", "亞伯拉罕為所多瑪代求", "Abraham Pleads for Sodom"),
    (19, 1, "所多玛与蛾摩拉的毁灭", "所多瑪與蛾摩拉的毀滅", "The Destruction of Sodom and Gomorrah"),
    (19, 30, "罗得与他的女儿们", "羅得與他的女兒們", "Lot and His Daughters"),
    (20, 1, "亚伯拉罕与亚比米勒", "亞伯拉罕與亞比米勒", "Abraham and Abimelech"),
    (21, 1, "以撒出生", "以撒出生", "The Birth of Isaac"),
    (21, 8, "夏甲与以实玛利被遣", "夏甲與以實瑪利被遣", "Hagar and Ishmael Sent Away"),
    (21, 22, "亚比米勒之约", "亞比米勒之約", "Treaty with Abimelech"),
    (22, 1, "亚伯拉罕献以撒", "亞伯拉罕獻以撒", "Abraham Offers Isaac"),
    (22, 20, "拿鹤的子孙", "拿鶴的子孫", "The Children of Nahor"),
    (23, 1, "撒拉之死与安葬", "撒拉之死與安葬", "Sarah's Death and Burial"),
    (24, 1, "以撒娶利百加", "以撒娶利百加", "Isaac Marries Rebekah"),
    (25, 1, "亚伯拉罕去世", "亞伯拉罕去世", "The Death of Abraham"),
    (25, 19, "雅各与以扫的出生", "雅各與以掃的出生", "The Birth of Jacob and Esau"),
    (25, 29, "以扫卖长子名分", "以掃賣長子名分", "Esau Sells His Birthright"),
    (26, 1, "以撒在基拉耳", "以撒在基拉耳", "Isaac and Abimelech"),
    (26, 34, "以扫娶妻", "以掃娶妻", "Esau's Wives"),
    (27, 1, "雅各骗取祝福", "雅各騙取祝福", "Jacob Receives Isaac's Blessing"),
    (27, 41, "雅各逃往哈兰", "雅各逃往哈蘭", "Jacob Flees from Esau"),
    (28, 10, "雅各在伯特利的梦", "雅各在伯特利的夢", "Jacob's Dream at Bethel"),
    (29, 1, "雅各与拉班相会", "雅各與拉班相會", "Jacob Meets Rachel"),
    (29, 31, "雅各的儿子们", "雅各的兒子們", "Jacob's Children"),
    (30, 25, "雅各的产业", "雅各的產業", "Jacob's Flocks Increase"),
    (31, 1, "雅各离开拉班", "雅各離開拉班", "Jacob Flees from Laban"),
    (32, 1, "雅各预备见以扫", "雅各預備見以掃", "Jacob Prepares to Meet Esau"),
    (32, 22, "雅各与神摔跤", "雅各與神摔跤", "Jacob Wrestles with God"),
    (33, 1, "雅各与以扫和好", "雅各與以掃和好", "Jacob Meets Esau"),
    (34, 1, "底拿被玷污", "底拿被玷污", "The Defilement of Dinah"),
    (35, 1, "雅各回到伯特利", "雅各回到伯特利", "Jacob Returns to Bethel"),
    (35, 16, "拉结之死", "拉結之死", "The Death of Rachel"),
    (36, 1, "以扫的后裔", "以掃的後裔", "The Descendants of Esau"),
    (37, 1, "约瑟的梦", "約瑟的夢", "Joseph's Dreams"),
    (37, 12, "约瑟被卖", "約瑟被賣", "Joseph Sold into Slavery"),
    (38, 1, "犹大与他玛", "猶大與他瑪", "Judah and Tamar"),
    (39, 1, "约瑟在波提乏家", "約瑟在波提乏家", "Joseph in Potiphar's House"),
    (39, 7, "约瑟受诬下监", "約瑟受誣下監", "Joseph Falsely Accused"),
    (40, 1, "约瑟解囚犯的梦", "約瑟解囚犯的夢", "The Cupbearer and the Baker"),
    (41, 1, "约瑟解法老的梦", "約瑟解法老的夢", "Joseph Interprets Pharaoh's Dreams"),
    (41, 38, "约瑟治理埃及", "約瑟治理埃及", "Joseph Made Ruler of Egypt"),
    (42, 1, "约瑟的兄弟下埃及", "約瑟的兄弟下埃及", "Joseph's Brothers Come to Egypt"),
    (43, 1, "第二次到埃及", "第二次到埃及", "The Second Journey to Egypt"),
    (44, 1, "约瑟试验兄弟", "約瑟試驗兄弟", "Joseph Tests His Brothers"),
    (45, 1, "约瑟与兄弟相认", "約瑟與兄弟相認", "Joseph Reveals Himself"),
    (46, 1, "雅各下埃及", "雅各下埃及", "Jacob Goes to Egypt"),
    (47, 13, "约瑟治理饥荒", "約瑟治理饑荒", "Joseph Manages the Famine"),
    (47, 28, "雅各祝福约瑟的儿子", "雅各祝福約瑟的兒子", "Jacob Blesses Joseph's Sons"),
    (49, 1, "雅各祝福十二支派", "雅各祝福十二支派", "Jacob Blesses His Sons"),
    (49, 29, "雅各之死", "雅各之死", "The Death of Jacob"),
    (50, 1, "约瑟葬父", "約瑟葬父", "Jacob's Burial"),
    (50, 15, "约瑟安慰兄弟", "約瑟安慰兄弟", "Joseph Reassures His Brothers"),
    (50, 22, "约瑟之死", "約瑟之死", "The Death of Joseph"),
]

MATTHEW: list[tuple[int, int, str, str, str]] = [
    (1, 1, "耶稣的家谱", "耶穌的家譜", "The Genealogy of Jesus"),
    (1, 18, "耶稣降生", "耶穌降生", "The Birth of Jesus"),
    (2, 1, "博士来朝", "博士來朝", "The Visit of the Magi"),
    (2, 13, "逃往埃及", "逃往埃及", "The Flight to Egypt"),
    (2, 19, "回拿撒勒", "回拿撒勒", "The Return to Nazareth"),
    (3, 1, "施洗约翰传道", "施洗約翰傳道", "John the Baptist Prepares the Way"),
    (3, 13, "耶稣受洗", "耶穌受洗", "The Baptism of Jesus"),
    (4, 1, "耶稣受试探", "耶穌受試探", "The Temptation of Jesus"),
    (4, 12, "在加利利开始传道", "在加利利開始傳道", "Jesus Begins His Ministry"),
    (4, 18, "呼召四个门徒", "呼召四個門徒", "Jesus Calls His First Disciples"),
    (5, 1, "登山宝训：八福", "登山寶訓：八福", "The Sermon on the Mount: The Beatitudes"),
    (5, 13, "盐与光", "鹽與光", "Salt and Light"),
    (5, 17, "耶稣与律法", "耶穌與律法", "The Fulfillment of the Law"),
    (5, 21, "论怒气", "論怒氣", "Teaching About Anger"),
    (5, 27, "论奸淫", "論姦淫", "Teaching About Lust"),
    (5, 31, "论离婚", "論離婚", "Teaching About Divorce"),
    (5, 33, "论起誓", "論起誓", "Teaching About Oaths"),
    (5, 38, "论报复", "論報復", "Teaching About Retaliation"),
    (5, 43, "爱仇敌", "愛仇敵", "Love Your Enemies"),
    (6, 1, "论施舍", "論施捨", "Teaching About Giving"),
    (6, 5, "论祷告", "論禱告", "Teaching About Prayer"),
    (6, 9, "主祷文", "主禱文", "The Lord's Prayer"),
    (6, 16, "论禁食", "論禁食", "Teaching About Fasting"),
    (6, 19, "论财宝", "論財寶", "Treasures in Heaven"),
    (6, 25, "论忧虑", "論憂慮", "Do Not Worry"),
    (7, 1, "论论断人", "論論斷人", "Do Not Judge"),
    (7, 7, "祈求与寻找", "祈求與尋找", "Ask, Seek, Knock"),
    (7, 13, "窄门与宽门", "窄門與寬門", "The Narrow and Wide Gates"),
    (7, 15, "假先知与好果子", "假先知與好果子", "True and False Prophets"),
    (7, 24, "聪明人与愚拙人", "聰明人與愚拙人", "The Wise and Foolish Builders"),
    (8, 1, "洁净长大痲疯", "潔淨長大痲瘋", "Jesus Heals a Leper"),
    (8, 5, "百夫长的信心", "百夫長的信心", "The Faith of the Centurion"),
    (8, 14, "医治许多病人", "醫治許多病人", "Jesus Heals Many"),
    (8, 23, "平静风浪", "平靜風浪", "Jesus Calms the Storm"),
    (8, 28, "赶逐群鬼", "趕逐群鬼", "The Demon-Possessed Men of Gadara"),
    (9, 1, "医治瘫子", "醫治癱子", "Jesus Heals a Paralyzed Man"),
    (9, 9, "呼召马太", "呼召馬太", "The Calling of Matthew"),
    (9, 14, "禁食的问题", "禁食的問題", "Question About Fasting"),
    (9, 18, "复活女孩与医治血漏", "復活女孩與醫治血漏", "The Dead Girl and the Sick Woman"),
    (9, 27, "医治瞎子与哑巴", "醫治瞎子與啞巴", "Jesus Heals the Blind and Mute"),
    (9, 35, "庄稼多工人少", "莊稼多工人少", "The Workers Are Few"),
    (10, 1, "差遣十二门徒", "差遣十二門徒", "Jesus Sends Out the Twelve"),
    (10, 16, "面临逼迫", "面臨逼迫", "Coming Persecutions"),
    (10, 32, "认主与作门徒的代价", "認主與作門徒的代價", "Acknowledging Christ"),
    (11, 1, "施洗约翰的疑问", "施洗約翰的疑問", "Jesus and John the Baptist"),
    (11, 20, "灾祸与安息", "災禍與安息", "Woe to Unrepentant Cities"),
    (12, 1, "安息日的主", "安息日的主", "The Lord of the Sabbath"),
    (12, 22, "耶稣与别西卜", "耶穌與別西卜", "Jesus and Beelzebul"),
    (12, 38, "约拿的兆头", "約拿的兆頭", "The Sign of Jonah"),
    (12, 46, "耶稣的真亲属", "耶穌的真親屬", "The True Family of Jesus"),
    (13, 1, "撒种的比喻", "撒種的比喻", "The Parable of the Sower"),
    (13, 24, "稗子的比喻", "稗子的比喻", "The Parable of the Weeds"),
    (13, 31, "芥菜种与酵的比喻", "芥菜種與酵的比喻", "The Mustard Seed and Yeast"),
    (13, 44, "藏宝与珍珠的比喻", "藏寶與珍珠的比喻", "Hidden Treasure and Pearl"),
    (13, 53, "在拿撒勒被弃", "在拿撒勒被棄", "Rejected at Nazareth"),
    (14, 1, "施洗约翰被斩", "施洗約翰被斬", "John the Baptist Beheaded"),
    (14, 13, "喂饱五千人", "餵飽五千人", "Jesus Feeds the Five Thousand"),
    (14, 22, "耶稣行走海面", "耶穌行走海面", "Jesus Walks on Water"),
    (15, 1, "古人的遗传", "古人的遺傳", "Clean and Unclean"),
    (15, 21, "迦南妇人的信心", "迦南婦人的信心", "The Faith of the Canaanite Woman"),
    (15, 32, "喂饱四千人", "餵飽四千人", "Jesus Feeds the Four Thousand"),
    (16, 1, "求兆头", "求兆頭", "The Demand for a Sign"),
    (16, 13, "彼得的认信", "彼得的認信", "Peter's Confession of Christ"),
    (16, 21, "首次预言受难", "首次預言受難", "Jesus Predicts His Death"),
    (17, 1, "耶稣登山变像", "耶穌登山變像", "The Transfiguration"),
    (17, 14, "医治被鬼附的孩子", "醫治被鬼附的孩子", "Jesus Heals a Demon-Possessed Boy"),
    (17, 24, "纳殿税", "納殿稅", "The Temple Tax"),
    (18, 1, "天国里最大的", "天國裡最大的", "The Greatest in the Kingdom"),
    (18, 10, "迷失羊的比喻", "迷失羊的比喻", "The Parable of the Lost Sheep"),
    (18, 15, "弟兄犯罪当如何对待", "弟兄犯罪當如何對待", "Dealing with Sin in the Church"),
    (18, 21, "无怜悯仆人的比喻", "無憐憫僕人的比喻", "The Parable of the Unforgiving Servant"),
    (19, 1, "论离婚", "論離婚", "Jesus Teaches About Divorce"),
    (19, 13, "耶稣祝福小孩", "耶穌祝福小孩", "Jesus Blesses the Children"),
    (19, 16, "财主的难处", "財主的難處", "The Rich Young Ruler"),
    (20, 1, "葡萄园工人的比喻", "葡萄園工人的比喻", "The Workers in the Vineyard"),
    (20, 17, "再次预言受难", "再次預言受難", "Jesus Foretells His Death Again"),
    (20, 20, "西庇太儿子的请求", "西庇太兒子的請求", "A Mother's Request"),
    (20, 29, "医治瞎眼的人", "醫治瞎眼的人", "Two Blind Men Receive Sight"),
    (21, 1, "光荣进入耶路撒冷", "光榮進入耶路撒冷", "The Triumphal Entry"),
    (21, 12, "洁净圣殿", "潔淨聖殿", "Jesus Cleanses the Temple"),
    (21, 18, "咒诅无花果树", "咒詛無花果樹", "Jesus Curses the Fig Tree"),
    (21, 23, "盘问耶稣的权柄", "盤問耶穌的權柄", "The Authority of Jesus Questioned"),
    (21, 33, "凶恶园户的比喻", "兇惡園戶的比喻", "The Parable of the Wicked Tenants"),
    (22, 1, "婚筵的比喻", "婚筵的比喻", "The Parable of the Wedding Banquet"),
    (22, 15, "纳税给凯撒", "納稅給凱撒", "Paying Taxes to Caesar"),
    (22, 23, "复活的问题", "復活的問題", "Marriage at the Resurrection"),
    (22, 34, "最大的诫命", "最大的誡命", "The Greatest Commandment"),
    (23, 1, "斥责文士与法利赛人", "斥責文士與法利賽人", "Seven Woes to Religious Leaders"),
    (24, 1, "末世的预兆", "末世的預兆", "Signs of the End of the Age"),
    (24, 36, "无人知道那日子", "無人知道那日子", "No One Knows the Day or Hour"),
    (25, 1, "十童女的比喻", "十童女的比喻", "The Parable of the Ten Virgins"),
    (25, 14, "按才受托的比喻", "按才受托的比喻", "The Parable of the Talents"),
    (25, 31, "羊与山羊", "羊與山羊", "The Final Judgment"),
    (26, 1, "杀害耶稣的阴谋", "殺害耶穌的陰謀", "The Plot Against Jesus"),
    (26, 6, "在伯大尼受膏", "在伯大尼受膏", "Jesus Anointed at Bethany"),
    (26, 14, "犹大要卖耶稣", "猶大要賣耶穌", "Judas Agrees to Betray Jesus"),
    (26, 17, "最后的晚餐", "最後的晚餐", "The Last Supper"),
    (26, 36, "客西马尼园祷告", "客西馬尼園禱告", "Gethsemane"),
    (26, 47, "耶稣被捕", "耶穌被捕", "Jesus Arrested"),
    (26, 57, "公会受审", "公會受審", "Jesus Before the Sanhedrin"),
    (26, 69, "彼得三次否认", "彼得三次否認", "Peter Disowns Jesus"),
    (27, 1, "犹大自杀", "猶大自殺", "Judas Hangs Himself"),
    (27, 11, "彼拉多前受审", "彼拉多前受審", "Jesus Before Pilate"),
    (27, 27, "戏弄与定罪", "戲弄與定罪", "The Soldiers Mock Jesus"),
    (27, 32, "钉十字架", "釘十字架", "The Crucifixion"),
    (27, 45, "耶稣之死", "耶穌之死", "The Death of Jesus"),
    (27, 57, "耶稣被埋葬", "耶穌被埋葬", "The Burial of Jesus"),
    (28, 1, "耶稣复活", "耶穌復活", "The Resurrection"),
    (28, 11, "兵丁的报告", "兵丁的報告", "The Report of the Guards"),
    (28, 16, "大使命", "大使命", "The Great Commission"),
]

JOHN: list[tuple[int, int, str, str, str]] = [
    (1, 1, "道成肉身", "道成肉身", "The Word Became Flesh"),
    (1, 19, "施洗约翰的见证", "施洗約翰的見證", "John the Baptist's Testimony"),
    (1, 35, "首批门徒", "首批門徒", "The First Disciples Follow Jesus"),
    (1, 43, "呼召腓力与拿但业", "呼召腓力與拿但業", "Jesus Calls Philip and Nathanael"),
    (2, 1, "迦拿婚宴", "迦拿婚宴", "The Wedding at Cana"),
    (2, 13, "洁净圣殿", "潔淨聖殿", "Jesus Clears the Temple"),
    (3, 1, "尼哥底母访耶稣", "尼哥底母訪耶穌", "Jesus Teaches Nicodemus"),
    (3, 22, "施洗约翰为耶稣作证", "施洗約翰為耶穌作證", "John Testifies Again About Jesus"),
    (4, 1, "撒玛利亚妇人", "撒瑪利亞婦人", "The Samaritan Woman at the Well"),
    (4, 27, "庄稼已熟", "莊稼已熟", "The Disciples Rejoin Jesus"),
    (4, 43, "医治大臣的儿子", "醫治大臣的兒子", "Jesus Heals an Official's Son"),
    (5, 1, "毕士大池的医治", "畢士大池的醫治", "Healing at the Pool"),
    (5, 16, "子与父", "子與父", "Life Through the Son"),
    (6, 1, "喂饱五千人", "餵飽五千人", "Jesus Feeds the Five Thousand"),
    (6, 16, "耶稣行走海面", "耶穌行走海面", "Jesus Walks on Water"),
    (6, 25, "生命的粮", "生命的糧", "Jesus the Bread of Life"),
    (6, 60, "许多门徒退去", "許多門徒退去", "Many Disciples Desert Jesus"),
    (7, 1, "上耶路撒冷过节", "上耶路撒冷過節", "Jesus Goes to the Festival"),
    (7, 25, "群众的争论", "群眾的爭論", "Is Jesus the Messiah?"),
    (7, 37, "活水的应许", "活水的應許", "Streams of Living Water"),
    (8, 1, "行淫的妇人", "行淫的婦人", "The Woman Caught in Adultery"),
    (8, 12, "世界的光", "世界的光", "Jesus the Light of the World"),
    (8, 31, "真理使你们自由", "真理使你們自由", "The Truth Will Set You Free"),
    (9, 1, "医治生来瞎眼的人", "醫治生來瞎眼的人", "Jesus Heals a Man Born Blind"),
    (10, 1, "好牧人", "好牧人", "The Good Shepherd"),
    (10, 22, "犹太人不信", "猶太人不信", "Further Conflict"),
    (11, 1, "拉撒路复活", "拉撒路復活", "The Death and Raising of Lazarus"),
    (11, 45, "杀害耶稣的阴谋", "殺害耶穌的陰謀", "The Plot to Kill Jesus"),
    (12, 1, "在伯大尼受膏", "在伯大尼受膏", "Jesus Anointed at Bethany"),
    (12, 12, "光荣进入耶路撒冷", "光榮進入耶路撒冷", "The Triumphal Entry"),
    (12, 20, "希利尼人求见耶稣", "希利尼人求見耶穌", "Jesus Predicts His Death"),
    (13, 1, "为门徒洗脚", "為門徒洗腳", "Jesus Washes the Disciples' Feet"),
    (13, 21, "预告卖主与不认主", "預告賣主與不認主", "Jesus Predicts His Betrayal"),
    (13, 31, "新命令", "新命令", "Jesus Predicts Peter's Denial"),
    (14, 1, "我是道路、真理、生命", "我是道路、真理、生命", "I Am the Way, Truth, and Life"),
    (14, 15, "应许圣灵", "應許聖靈", "The Promise of the Holy Spirit"),
    (15, 1, "真葡萄树", "真葡萄樹", "The True Vine"),
    (15, 18, "世人的恨", "世人的恨", "The World Hates the Disciples"),
    (16, 1, "圣灵的工作", "聖靈的工作", "The Work of the Holy Spirit"),
    (16, 16, "忧愁变为喜乐", "憂愁變為喜樂", "The Disciples' Grief Will Turn to Joy"),
    (17, 1, "耶稣大祭司的祷告", "耶穌大祭司的禱告", "Jesus Prays for Himself and His Disciples"),
    (18, 1, "耶稣被捕", "耶穌被捕", "Jesus Arrested"),
    (18, 15, "彼得的否认", "彼得的否認", "Peter Denies Jesus"),
    (18, 28, "彼拉多前受审", "彼拉多前受審", "Jesus Before Pilate"),
    (19, 1, "戏弄与判刑", "戲弄與判刑", "Jesus Sentenced to Be Crucified"),
    (19, 17, "钉十字架", "釘十字架", "The Crucifixion"),
    (19, 38, "耶稣被埋葬", "耶穌被埋葬", "The Burial of Jesus"),
    (20, 1, "空坟墓", "空墳墓", "The Empty Tomb"),
    (20, 11, "向抹大拉的马利亚显现", "向抹大拉的馬利亞顯現", "Jesus Appears to Mary Magdalene"),
    (20, 19, "向门徒显现", "向門徒顯現", "Jesus Appears to His Disciples"),
    (20, 24, "多马的疑惑", "多馬的疑惑", "Jesus Appears to Thomas"),
    (21, 1, "提比哩亚海边显现", "提比哩亞海邊顯現", "Jesus and the Miraculous Catch of Fish"),
    (21, 15, "三次问爱与托付", "三次問愛與託付", "Jesus Reinstates Peter"),
]

ROMANS: list[tuple[int, int, str, str, str]] = [
    (1, 1, "问安", "問安", "Greeting"),
    (1, 8, "渴望访问罗马", "渴望訪問羅馬", "Paul's Longing to Visit Rome"),
    (1, 16, "福音的大能", "福音的大能", "The Power of the Gospel"),
    (1, 18, "神的忿怒", "神的忿怒", "God's Wrath Against Mankind"),
    (2, 1, "神公义的审判", "神公義的審判", "God's Righteous Judgment"),
    (2, 17, "犹太人与律法", "猶太人與律法", "The Jews and the Law"),
    (3, 1, "犹太人的优势", "猶太人的優勢", "The Faithfulness of God"),
    (3, 9, "都在罪恶之下", "都在罪惡之下", "No One Is Righteous"),
    (3, 21, "因信称义", "因信稱義", "Righteousness Through Faith"),
    (4, 1, "亚伯拉罕因信称义", "亞伯拉罕因信稱義", "Abraham Justified by Faith"),
    (4, 13, "应许借着信", "應許藉著信", "The Promise Through Faith"),
    (5, 1, "因信得平安", "因信得平安", "Peace and Hope"),
    (5, 12, "亚当与基督", "亞當與基督", "Adam and Christ"),
    (6, 1, "向罪死，向神活", "向罪死，向神活", "Dead to Sin, Alive in Christ"),
    (6, 15, "义的奴仆", "義的奴僕", "Slaves to Righteousness"),
    (7, 1, "脱离律法", "脫離律法", "Released from the Law"),
    (7, 7, "律法与罪", "律法與罪", "The Law and Sin"),
    (7, 14, "心中的争战", "心中的爭戰", "The Inner Conflict"),
    (8, 1, "圣灵的生命", "聖靈的生命", "Life Through the Spirit"),
    (8, 18, "将来的荣耀", "將來的榮耀", "Future Glory"),
    (8, 28, "万事互相效力", "萬事互相效力", "More Than Conquerors"),
    (9, 1, "保罗为同胞忧伤", "保羅為同胞憂傷", "Paul's Sorrow for Israel"),
    (9, 14, "神的拣选", "神的揀選", "God's Sovereign Choice"),
    (9, 30, "以色列的不信", "以色列的不信", "Israel's Unbelief"),
    (10, 1, "因信得救", "因信得救", "Salvation by Faith for All"),
    (10, 14, "信道是从听道来", "信道是從聽道來", "Faith Comes from Hearing"),
    (11, 1, "以色列的余民", "以色列的餘民", "The Remnant of Israel"),
    (11, 11, "外邦人得救", "外邦人得救", "Ingrafted Branches"),
    (11, 25, "以色列必得救", "以色列必得救", "All Israel Will Be Saved"),
    (11, 33, "颂赞神的智慧", "頌讚神的智慧", "Doxology"),
    (12, 1, "活祭与新生", "活祭與新生", "A Living Sacrifice"),
    (12, 9, "爱与服事", "愛與服事", "Love in Action"),
    (13, 1, "顺服掌权者", "順服掌權者", "Submission to Authorities"),
    (13, 8, "彼此相爱", "彼此相愛", "Love Fulfills the Law"),
    (13, 11, "披戴主基督", "披戴主基督", "The Day Is Near"),
    (14, 1, "信心软弱者", "信心軟弱者", "The Weak and the Strong"),
    (14, 13, "不要绊倒弟兄", "不要絆倒弟兄", "Do Not Cause to Stumble"),
    (15, 1, "讨邻舍喜悦", "討鄰舍喜悅", "Pleasing Others, Not Ourselves"),
    (15, 14, "保罗事奉的呼召", "保羅事奉的呼召", "Paul's Apostolic Ministry"),
    (15, 23, "保罗访问罗马的计划", "保羅訪問羅馬的計劃", "Paul's Plan to Visit Rome"),
    (16, 1, "问候众圣徒", "問候眾聖徒", "Personal Greetings"),
    (16, 17, "防备假师傅", "防備假師傅", "Final Warning"),
    (16, 25, "颂赞", "頌讚", "Doxology"),
]


def _set_for(book_data: list[tuple[int, int, str, str, str]], lang: str) -> dict:
    """Group authored entries by chapter for one language."""
    out: dict[str, list[dict]] = {}
    for ch, vs, simp, trad, en in book_data:
        title = {"hans": simp, "hant": trad, "en": en}[lang]
        out.setdefault(str(ch), []).append({"verse": vs, "title": title})
    # Sort each chapter's entries by verse for deterministic output.
    for ch in out:
        out[ch].sort(key=lambda e: e["verse"])
    return out


def main() -> int:
    books_data = {
        "Genesis": GENESIS,
        "Matthew": MATTHEW,
        "John": JOHN,
        "Romans": ROMANS,
    }

    payload = {
        "_meta": {
            "version": 1,
            "books": list(books_data.keys()),
            "generatedAt": _dt.datetime.now(_dt.timezone.utc).strftime(
                "%Y-%m-%dT%H:%M:%SZ"
            ),
            "description": (
                "Section / paragraph titles. Loaded by SectionTitleService and "
                "rendered above the matched verse in the reading pane. Three "
                "title sets in this Phase-1 file: cuv (simplified), cuv-tr "
                "(traditional), english-classic (English). The version-to-set "
                "mapping lives in lib/constants/section_title_map.dart."
            ),
        },
        "sets": {
            "cuv": {b: _set_for(d, "hans") for b, d in books_data.items()},
            "cuv-tr": {b: _set_for(d, "hant") for b, d in books_data.items()},
            "english-classic": {b: _set_for(d, "en") for b, d in books_data.items()},
        },
    }

    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    total = sum(len(d) for d in books_data.values())
    print(
        f"Wrote {total} titles × 3 languages → "
        f"{OUT} ({os.path.getsize(OUT)} bytes)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
