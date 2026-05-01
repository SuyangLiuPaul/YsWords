#!/usr/bin/env python3
"""
Generate maps_index.json entries for the 240 Schnorr von Carolsfeld
"Die Bibel in Bildern" woodcuts and append them to the existing maps_index.json.

Skips:
  - Plates 144-159 (apocryphal / deuterocanonical)
  - Plate 201 (duplicate of 189)

Fetches actual Wikimedia Commons thumbnail URLs via the API.
"""

import json
import sys
import time
import urllib.request
import urllib.error
import urllib.parse

# Flush stdout on every print
sys.stdout.reconfigure(line_buffering=True)

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
MAPS_INDEX_PATH = "/Users/pliu0036/Documents/yswords/assets/maps_index.json"

# ---------------------------------------------------------------------------
# Artist name constants
# ---------------------------------------------------------------------------
ARTIST_EN = "Julius Schnorr von Carolsfeld"
ARTIST_ZH_HANS = "尤利乌斯·施诺尔·冯·卡罗尔斯费尔德"
ARTIST_ZH_HANT = "尤利烏斯·施諾爾·馮·卡羅爾斯費爾德"
SNIPPET_ZH_HANS = "施诺尔"
SNIPPET_ZH_HANT = "施諾爾"
YEAR = "1860"

# ---------------------------------------------------------------------------
# Plate data: (plate_number, short_title_en, title_zh_hans, title_zh_hant, books_dict)
# books_dict maps book name -> [start_chapter, end_chapter]
# ---------------------------------------------------------------------------
PLATES = [
    # === PLATES 1-43: Genesis ===
    (1, "creation_of_light",
     "光的创造", "光的創造",
     {"Genesis": [1, 1]}),
    (2, "creation_of_the_sky",
     "天空的创造", "天空的創造",
     {"Genesis": [1, 1]}),
    (3, "creation_of_plants",
     "植物的创造", "植物的創造",
     {"Genesis": [1, 1]}),
    (4, "creation_of_heavenly_bodies",
     "天体的创造", "天體的創造",
     {"Genesis": [1, 1]}),
    (5, "creation_of_birds_and_sea_creatures",
     "鸟与海洋生物的创造", "鳥與海洋生物的創造",
     {"Genesis": [1, 1]}),
    (6, "creation_of_humanity",
     "人类的创造", "人類的創造",
     {"Genesis": [1, 1]}),
    (7, "god_rests",
     "神安息", "神安息",
     {"Genesis": [2, 2]}),
    (8, "fall",
     "堕落", "墮落",
     {"Genesis": [3, 3]}),
    (9, "confrontation",
     "对质", "對質",
     {"Genesis": [3, 3]}),
    (10, "expulsion",
     "逐出伊甸园", "逐出伊甸園",
     {"Genesis": [3, 3]}),
    (11, "adam_eve_and_family",
     "亚当、夏娃和家人", "亞當、夏娃和家人",
     {"Genesis": [4, 4]}),
    (12, "cain_and_abel",
     "该隐与亚伯", "該隱與亞伯",
     {"Genesis": [4, 4]}),
    (13, "cain_kills_abel",
     "该隐杀亚伯", "該隱殺亞伯",
     {"Genesis": [4, 4]}),
    (14, "cain_establishes_enoch",
     "该隐建立以诺城", "該隱建立以諾城",
     {"Genesis": [4, 4]}),
    (15, "days_of_noah",
     "挪亚的时代", "挪亞的時代",
     {"Genesis": [6, 6]}),
    (16, "noahs_ark",
     "挪亚方舟", "挪亞方舟",
     {"Genesis": [6, 6]}),
    (17, "noahs_ark_and_the_flood",
     "挪亚方舟与大洪水", "挪亞方舟與大洪水",
     {"Genesis": [7, 7]}),
    (18, "noah_exits_the_ark",
     "挪亚出方舟", "挪亞出方舟",
     {"Genesis": [8, 8]}),
    (19, "noahs_altar_and_gods_promise",
     "挪亚筑坛与神的应许", "挪亞築壇與神的應許",
     {"Genesis": [8, 8]}),
    (20, "noah_curses_ham",
     "挪亚咒诅含", "挪亞咒詛含",
     {"Genesis": [9, 9]}),
    (21, "tower_of_babel",
     "巴别塔", "巴別塔",
     {"Genesis": [11, 11]}),
    (22, "abrahamic_covenant",
     "亚伯拉罕之约", "亞伯拉罕之約",
     {"Genesis": [12, 12]}),
    (23, "abram_and_melchizedek",
     "亚伯兰与麦基洗德", "亞伯蘭與麥基洗德",
     {"Genesis": [14, 14]}),
    (24, "abram_leaves_haran",
     "亚伯兰离开哈兰", "亞伯蘭離開哈蘭",
     {"Genesis": [12, 12]}),
    (25, "abrahams_three_visitors",
     "亚伯拉罕的三位访客", "亞伯拉罕的三位訪客",
     {"Genesis": [18, 18]}),
    (26, "fleeing_sodom_and_gomorrah",
     "逃离所多玛和蛾摩拉", "逃離所多瑪和蛾摩拉",
     {"Genesis": [19, 19]}),
    (27, "hagar_and_ishmael_sent_away",
     "夏甲和以实玛利被遣走", "夏甲和以實瑪利被遣走",
     {"Genesis": [21, 21]}),
    (28, "sacrifice_of_isaac",
     "以撒的献祭", "以撒的獻祭",
     {"Genesis": [22, 22]}),
    (29, "rebekah_at_the_well",
     "井旁的利百加", "井旁的利百加",
     {"Genesis": [24, 24]}),
    (30, "isaac_and_rebekah_meet",
     "以撒与利百加相遇", "以撒與利百加相遇",
     {"Genesis": [24, 24]}),
    (31, "isaac_blesses_jacob",
     "以撒祝福雅各", "以撒祝福雅各",
     {"Genesis": [27, 27]}),
    (32, "jacobs_dream",
     "雅各的梦", "雅各的夢",
     {"Genesis": [28, 28]}),
    (33, "jacob_meets_rachel",
     "雅各遇见拉结", "雅各遇見拉結",
     {"Genesis": [29, 29]}),
    (34, "jacob_works_for_laban",
     "雅各为拉班做工", "雅各為拉班做工",
     {"Genesis": [30, 30]}),
    (35, "jacob_flees_laban",
     "雅各逃离拉班", "雅各逃離拉班",
     {"Genesis": [31, 31]}),
    (36, "jacob_wrestles_with_god",
     "雅各与神摔跤", "雅各與神摔跤",
     {"Genesis": [32, 32]}),
    (37, "jacob_and_esau_reunited",
     "雅各与以扫重逢", "雅各與以掃重逢",
     {"Genesis": [33, 33]}),
    (38, "ishmaelites_purchase_joseph",
     "以实玛利人买下约瑟", "以實瑪利人買下約瑟",
     {"Genesis": [37, 37]}),
    (39, "joseph_and_potiphars_wife",
     "约瑟与波提乏的妻子", "約瑟與波提乏的妻子",
     {"Genesis": [39, 39]}),
    (40, "joseph_interprets_pharaohs_dreams",
     "约瑟解法老的梦", "約瑟解法老的夢",
     {"Genesis": [41, 41]}),
    (41, "joseph_promoted_in_egypt",
     "约瑟在埃及被提拔", "約瑟在埃及被提拔",
     {"Genesis": [41, 41]}),
    (42, "joseph_revealed",
     "约瑟表明身份", "約瑟表明身份",
     {"Genesis": [45, 45]}),
    (43, "jacob_and_joseph_reunited",
     "雅各与约瑟重逢", "雅各與約瑟重逢",
     {"Genesis": [46, 46]}),

    # === PLATES 44-65: Exodus / Numbers / Deuteronomy ===
    (44, "slavery_and_massacre_of_innocents",
     "奴役与屠杀婴儿", "奴役與屠殺嬰兒",
     {"Exodus": [1, 1]}),
    (45, "moses_is_found",
     "摩西被发现", "摩西被發現",
     {"Exodus": [2, 2]}),
    (46, "moses_kills_an_egyptian",
     "摩西杀死埃及人", "摩西殺死埃及人",
     {"Exodus": [2, 2]}),
    (47, "burning_bush",
     "燃烧的荆棘", "燃燒的荊棘",
     {"Exodus": [3, 3]}),
    (48, "staffs_to_snakes",
     "杖变蛇", "杖變蛇",
     {"Exodus": [7, 7]}),
    (49, "the_passover_and_death_of_the_firstborn",
     "逾越节与长子之死", "逾越節與長子之死",
     {"Exodus": [12, 12]}),
    (50, "pharaoh_frees_hebrews",
     "法老释放希伯来人", "法老釋放希伯來人",
     {"Exodus": [12, 12]}),
    (51, "miriams_song",
     "米利暗之歌", "米利暗之歌",
     {"Exodus": [15, 15]}),
    (52, "manna_and_water_from_the_rock",
     "吗哪与磐石出水", "嗎哪與磐石出水",
     {"Exodus": [16, 16]}),
    (53, "battle_with_the_amalekites",
     "与亚玛力人的争战", "與亞瑪力人的爭戰",
     {"Exodus": [17, 17]}),
    (54, "ten_commandments",
     "十诫", "十誡",
     {"Exodus": [20, 20]}),
    (55, "golden_calf",
     "金牛犊", "金牛犢",
     {"Exodus": [32, 32]}),
    (56, "judgment",
     "审判", "審判",
     {"Exodus": [32, 32]}),
    (57, "ten_commandments_second",
     "十诫（第二次）", "十誡（第二次）",
     {"Exodus": [34, 34]}),
    (58, "expedition_returns",
     "探子回报", "探子回報",
     {"Numbers": [13, 13]}),
    (59, "korahs_rebellion",
     "可拉的叛乱", "可拉的叛亂",
     {"Numbers": [16, 16]}),
    (60, "aarons_staff_buds",
     "亚伦的杖发芽", "亞倫的杖發芽",
     {"Numbers": [17, 17]}),
    (61, "bronze_serpent",
     "铜蛇", "銅蛇",
     {"Numbers": [21, 21]}),
    (62, "balaams_donkey",
     "巴兰的驴", "巴蘭的驢",
     {"Numbers": [22, 22]}),
    (63, "the_selection_of_joshua",
     "约书亚被拣选", "約書亞被揀選",
     {"Numbers": [27, 27]}),
    (64, "moses_sees_the_promised_land",
     "摩西远眺应许之地", "摩西遠眺應許之地",
     {"Deuteronomy": [34, 34]}),
    (65, "burial_of_moses",
     "摩西的安葬", "摩西的安葬",
     {"Deuteronomy": [34, 34]}),

    # === PLATES 66-73: Joshua ===
    (66, "rahab",
     "喇合", "喇合",
     {"Joshua": [2, 2]}),
    (67, "crossing_the_jordan",
     "渡过约旦河", "渡過約旦河",
     {"Joshua": [3, 3]}),
    (68, "joshua_and_the_angel",
     "约书亚与天使", "約書亞與天使",
     {"Joshua": [5, 5]}),
    (69, "battle_of_jericho",
     "耶利哥之战", "耶利哥之戰",
     {"Joshua": [6, 6]}),
    (70, "fall_of_ai",
     "艾城陷落", "艾城陷落",
     {"Joshua": [8, 8]}),
    (71, "sun_stands_still",
     "日头停留", "日頭停留",
     {"Joshua": [10, 10]}),
    (72, "kings_captured",
     "诸王被擒", "諸王被擒",
     {"Joshua": [10, 10]}),
    (73, "tribal_inheritance",
     "支派分地", "支派分地",
     {"Joshua": [14, 14]}),

    # === PLATES 74-83: Judges ===
    (74, "jael_shows_barak_the_body_of_sisera",
     "雅亿把西西拉的尸体给巴拉看", "雅億把西西拉的屍體給巴拉看",
     {"Judges": [4, 4]}),
    (75, "gideons_call",
     "基甸的呼召", "基甸的呼召",
     {"Judges": [6, 6]}),
    (76, "gideon_choosing_his_soldiers",
     "基甸挑选士兵", "基甸挑選士兵",
     {"Judges": [7, 7]}),
    (77, "death_of_abimelech",
     "亚比米勒之死", "亞比米勒之死",
     {"Judges": [9, 9]}),
    (78, "jephthahs_daughter",
     "耶弗他的女儿", "耶弗他的女兒",
     {"Judges": [11, 11]}),
    (79, "samson_slays_a_lion",
     "参孙撕裂狮子", "參孫撕裂獅子",
     {"Judges": [14, 14]}),
    (80, "samson_slays_1000_philistines",
     "参孙击杀一千非利士人", "參孫擊殺一千非利士人",
     {"Judges": [15, 15]}),
    (81, "samson_and_delilah",
     "参孙与大利拉", "參孫與大利拉",
     {"Judges": [16, 16]}),
    (82, "death_of_samson",
     "参孙之死", "參孫之死",
     {"Judges": [16, 16]}),
    (83, "benjaminites_seize_wives_from_shiloh",
     "便雅悯人在示罗抢妻", "便雅憫人在示羅搶妻",
     {"Judges": [21, 21]}),

    # === PLATES 84-85: Ruth ===
    (84, "naomi_ruth_and_orpah",
     "拿俄米、路得和俄珥巴", "拿俄米、路得和俄珥巴",
     {"Ruth": [1, 1]}),
    (85, "boaz_meets_ruth",
     "波阿斯遇见路得", "波阿斯遇見路得",
     {"Ruth": [2, 2]}),

    # === PLATES 86-107: 1 Samuel / 2 Samuel ===
    (86, "hannahs_prayer",
     "哈拿的祷告", "哈拿的禱告",
     {"1 Samuel": [1, 1]}),
    (87, "god_calls_samuel",
     "神呼召撒母耳", "神呼召撒母耳",
     {"1 Samuel": [3, 3]}),
    (88, "death_of_eli",
     "以利之死", "以利之死",
     {"1 Samuel": [4, 4]}),
    (89, "samuel_anoints_saul",
     "撒母耳膏扫罗", "撒母耳膏掃羅",
     {"1 Samuel": [10, 10]}),
    (90, "god_rejects_saul",
     "神弃绝扫罗", "神棄絕掃羅",
     {"1 Samuel": [15, 15]}),
    (91, "david_chosen",
     "大卫被拣选", "大衛被揀選",
     {"1 Samuel": [16, 16]}),
    (92, "david_and_goliath",
     "大卫与歌利亚", "大衛與歌利亞",
     {"1 Samuel": [17, 17]}),
    (93, "saul_attacks_david",
     "扫罗追杀大卫", "掃羅追殺大衛",
     {"1 Samuel": [18, 18]}),
    (94, "david_and_jonathan",
     "大卫与约拿单", "大衛與約拿單",
     {"1 Samuel": [20, 20]}),
    (95, "david_spares_sauls_life",
     "大卫饶扫罗的命", "大衛饒掃羅的命",
     {"1 Samuel": [24, 24]}),
    (96, "david_and_abigail",
     "大卫与亚比该", "大衛與亞比該",
     {"1 Samuel": [25, 25]}),
    (97, "saul_consults_the_medium_at_endor",
     "扫罗求问隐多珥的女巫", "掃羅求問隱多珥的女巫",
     {"1 Samuel": [28, 28]}),
    (98, "death_of_saul",
     "扫罗之死", "掃羅之死",
     {"1 Samuel": [31, 31]}),
    (99, "samuel_anoints_david_as_king",
     "撒母耳膏大卫为王", "撒母耳膏大衛為王",
     {"2 Samuel": [2, 2]}),
    (100, "david_brings_the_ark_to_jerusalem",
     "大卫将约柜迎回耶路撒冷", "大衛將約櫃迎回耶路撒冷",
     {"2 Samuel": [6, 6]}),
    (101, "david_and_bathsheba",
     "大卫与拔示巴", "大衛與拔示巴",
     {"2 Samuel": [11, 11]}),
    (102, "nathan_confronts_david",
     "拿单责备大卫", "拿單責備大衛",
     {"2 Samuel": [12, 12]}),
    (103, "davids_child_dies",
     "大卫的孩子死去", "大衛的孩子死去",
     {"2 Samuel": [12, 12]}),
    (104, "shimei_curses_david",
     "示每咒骂大卫", "示每咒罵大衛",
     {"2 Samuel": [16, 16]}),
    (105, "death_of_absalom",
     "押沙龙之死", "押沙龍之死",
     {"2 Samuel": [18, 18]}),
    (106, "david_pours_out_water",
     "大卫倒掉水", "大衛倒掉水",
     {"2 Samuel": [23, 23]}),
    (107, "god_smites_israel_with_a_deadly_plague",
     "神用瘟疫击打以色列", "神用瘟疫擊打以色列",
     {"2 Samuel": [24, 24]}),

    # === PLATES 108-113: 1 Kings ===
    (108, "solomon_made_king",
     "所罗门登基", "所羅門登基",
     {"1 Kings": [1, 1]}),
    (109, "solomons_wisdom",
     "所罗门的智慧", "所羅門的智慧",
     {"1 Kings": [3, 3]}),
    (110, "solomon_plans_construction_of_the_temple",
     "所罗门筹划建殿", "所羅門籌劃建殿",
     {"1 Kings": [5, 5]}),
    (111, "the_queen_of_sheba",
     "示巴女王", "示巴女王",
     {"1 Kings": [10, 10]}),
    (112, "solomons_idolatry",
     "所罗门的偶像崇拜", "所羅門的偶像崇拜",
     {"1 Kings": [11, 11]}),
    (113, "rehoboam_and_jeroboam",
     "罗波安与耶罗波安", "羅波安與耶羅波安",
     {"1 Kings": [12, 12]}),

    # === PLATES 114-124: 1 Kings / 2 Kings ===
    (114, "ravens_feed_elijah",
     "乌鸦供养以利亚", "烏鴉供養以利亞",
     {"1 Kings": [17, 17]}),
    (115, "elijah_raises_the_widows_son",
     "以利亚复活寡妇之子", "以利亞復活寡婦之子",
     {"1 Kings": [17, 17]}),
    (116, "slaughter_of_the_prophets_of_baal",
     "屠杀巴力先知", "屠殺巴力先知",
     {"1 Kings": [18, 18]}),
    (117, "god_appears_to_elijah",
     "神向以利亚显现", "神向以利亞顯現",
     {"1 Kings": [19, 19]}),
    (118, "death_of_ahab",
     "亚哈之死", "亞哈之死",
     {"1 Kings": [22, 22]}),
    (119, "chariot_of_fire",
     "火车火马", "火車火馬",
     {"2 Kings": [2, 2]}),
    (120, "elisha_raises_the_shunammites_son",
     "以利沙复活书念妇人之子", "以利沙復活書念婦人之子",
     {"2 Kings": [4, 4]}),
    (121, "death_of_jezebel",
     "耶洗别之死", "耶洗別之死",
     {"2 Kings": [9, 9]}),
    (122, "jerusalem_delivered_from_sennacherib",
     "耶路撒冷脱离亚述之手", "耶路撒冷脫離亞述之手",
     {"2 Kings": [19, 19]}),
    (123, "book_of_the_law",
     "律法书", "律法書",
     {"2 Kings": [22, 22]}),
    (124, "fall_of_jerusalem",
     "耶路撒冷沦陷", "耶路撒冷淪陷",
     {"2 Kings": [25, 25]}),

    # === PLATES 125-128: Ezra / Nehemiah ===
    (125, "return_from_exile",
     "从被掳之地归回", "從被擄之地歸回",
     {"Ezra": [1, 1], "Nehemiah": [1, 1]}),
    (126, "rebuilding_the_jerusalem_temple",
     "重建耶路撒冷圣殿", "重建耶路撒冷聖殿",
     {"Ezra": [3, 3]}),
    (127, "rebuilding_the_jerusalem_temple_2",
     "重建耶路撒冷圣殿（二）", "重建耶路撒冷聖殿（二）",
     {"Ezra": [4, 4]}),
    (128, "ezra_reads_the_book_of_the_law",
     "以斯拉宣读律法书", "以斯拉宣讀律法書",
     {"Nehemiah": [8, 8], "Ezra": [7, 7]}),

    # === PLATES 129-130: Esther ===
    (129, "the_coronation_of_esther",
     "以斯帖加冕", "以斯帖加冕",
     {"Esther": [2, 2]}),
    (130, "mordecai_honored",
     "末底改受尊荣", "末底改受尊榮",
     {"Esther": [6, 6]}),

    # === PLATES 131-133: Job ===
    (131, "messengers_to_job",
     "报信者来到约伯那里", "報信者來到約伯那裡",
     {"Job": [1, 1]}),
    (132, "jobs_affliction",
     "约伯的苦难", "約伯的苦難",
     {"Job": [2, 2]}),
    (133, "restoration_of_job",
     "约伯的恢复", "約伯的恢復",
     {"Job": [42, 42]}),

    # === PLATES 134-138: Psalms / Proverbs ===
    (134, "david_the_psalmist",
     "诗人大卫", "詩人大衛",
     {"Psalms": [1, 1]}),
    (135, "david_confesses",
     "大卫认罪", "大衛認罪",
     {"Psalms": [51, 51]}),
    (136, "david_prays_for_deliverance",
     "大卫求拯救", "大衛求拯救",
     {"Psalms": [3, 3]}),
    (137, "david_the_psalmist_2",
     "诗人大卫（二）", "詩人大衛（二）",
     {"Psalms": [23, 23]}),
    (138, "solomon_and_lady_wisdom",
     "所罗门与智慧女士", "所羅門與智慧女士",
     {"Proverbs": [1, 1]}),

    # === PLATES 139-143: Prophets ===
    (139, "isaiah",
     "以赛亚", "以賽亞",
     {"Isaiah": [1, 1]}),
    (140, "jeremiahs_call",
     "耶利米的蒙召", "耶利米的蒙召",
     {"Jeremiah": [1, 1]}),
    (141, "jeremiahs_lament",
     "耶利米的哀歌", "耶利米的哀歌",
     {"Lamentations": [1, 1]}),
    (142, "ezekiels_vision",
     "以西结的异象", "以西結的異象",
     {"Ezekiel": [1, 1]}),
    (143, "daniel_interpreting_the_writing_on_the_wall",
     "但以理解读墙上的文字", "但以理解讀牆上的文字",
     {"Daniel": [5, 5]}),

    # === PLATES 144-159: SKIPPED (apocryphal) ===
    # Plate 160 included below

    (160, "daniel_in_the_lions_den",
     "但以理在狮子坑中", "但以理在獅子坑中",
     {"Daniel": [6, 6]}),

    # === PLATES 161-240: New Testament ===
    (161, "gabriel_visits_zechariah",
     "加百列拜访撒迦利亚", "加百列拜訪撒迦利亞",
     {"Luke": [1, 1]}),
    (162, "the_annunciation",
     "天使报喜", "天使報喜",
     {"Luke": [1, 1]}),
    (163, "the_visitation",
     "圣母访亲", "聖母訪親",
     {"Luke": [1, 1]}),
    (164, "naming_of_john_the_baptist",
     "施洗约翰的命名", "施洗約翰的命名",
     {"Luke": [1, 1]}),
    (165, "angel_visits_shepherds",
     "天使向牧羊人报信", "天使向牧羊人報信",
     {"Luke": [2, 2]}),
    (166, "shepherds_visit",
     "牧羊人前来朝拜", "牧羊人前來朝拜",
     {"Luke": [2, 2]}),
    (167, "shepherds_spread_good_news",
     "牧羊人传扬好消息", "牧羊人傳揚好消息",
     {"Luke": [2, 2]}),
    (168, "simeon_and_anna",
     "西面与亚拿", "西面與亞拿",
     {"Luke": [2, 2]}),
    (169, "visit_of_the_wise_men",
     "博士来访", "博士來訪",
     {"Matthew": [2, 2]}),
    (170, "angel_warns_joseph",
     "天使警告约瑟", "天使警告約瑟",
     {"Matthew": [2, 2]}),
    (171, "flight_to_egypt",
     "逃往埃及", "逃往埃及",
     {"Matthew": [2, 2]}),
    (172, "massacre_of_the_innocents",
     "屠杀无辜者", "屠殺無辜者",
     {"Matthew": [2, 2]}),
    (173, "the_young_jesus_in_the_temple",
     "少年耶稣在圣殿", "少年耶穌在聖殿",
     {"Luke": [2, 2]}),
    (174, "john_the_baptist",
     "施洗约翰", "施洗約翰",
     {"Matthew": [3, 3], "Mark": [1, 1], "Luke": [3, 3], "John": [1, 1]}),
    (175, "baptism_of_jesus",
     "耶稣受洗", "耶穌受洗",
     {"Matthew": [3, 3], "Mark": [1, 1], "Luke": [3, 3], "John": [1, 1]}),
    (176, "angels_attend_to_jesus",
     "天使伺候耶稣", "天使伺候耶穌",
     {"Matthew": [4, 4], "Mark": [1, 1]}),
    (177, "witness_of_john_the_baptist",
     "施洗约翰的见证", "施洗約翰的見證",
     {"John": [3, 3]}),
    (178, "first_disciples",
     "首批门徒", "首批門徒",
     {"John": [1, 1]}),
    (179, "wedding_at_cana",
     "迦拿的婚宴", "迦拿的婚宴",
     {"John": [2, 2]}),
    (180, "cleansing_the_temple",
     "洁净圣殿", "潔淨聖殿",
     {"John": [2, 2], "Matthew": [21, 21], "Mark": [11, 11], "Luke": [19, 19]}),
    (181, "nicodemus",
     "尼哥底母", "尼哥底母",
     {"John": [3, 3]}),
    (182, "woman_at_the_well",
     "井旁的撒玛利亚妇人", "井旁的撒瑪利亞婦人",
     {"John": [4, 4]}),
    (183, "jesus_heals_a_paralytic",
     "耶稣医治瘫子", "耶穌醫治癱子",
     {"John": [5, 5]}),
    (184, "jairus_daughter",
     "睚鲁的女儿", "睚魯的女兒",
     {"Mark": [5, 5], "Matthew": [9, 9], "Luke": [8, 8]}),
    (185, "healing_the_blind",
     "医治瞎子", "醫治瞎子",
     {"John": [9, 9]}),
    (186, "sermon_on_the_mount",
     "登山宝训", "登山寶訓",
     {"Matthew": [5, 5]}),
    (187, "death_of_john_the_baptist",
     "施洗约翰之死", "施洗約翰之死",
     {"Mark": [6, 6], "Matthew": [14, 14]}),
    (188, "resurrection_at_nain",
     "拿因城复活", "拿因城復活",
     {"Luke": [7, 7]}),
    (189, "jesus_forgives_the_adulteress",
     "耶稣赦免淫妇", "耶穌赦免淫婦",
     {"John": [8, 8]}),
    # Plate 201 is a duplicate of 189 — skipped below

    (190, "jesus_sleeps_in_boat",
     "耶稣在船上睡觉", "耶穌在船上睡覺",
     {"Mark": [4, 4], "Matthew": [8, 8], "Luke": [8, 8]}),
    (191, "exorcism",
     "赶鬼", "趕鬼",
     {"Mark": [5, 5], "Matthew": [8, 8], "Luke": [8, 8]}),
    (192, "jesus_sends_out_the_twelve_disciples",
     "耶稣差遣十二门徒", "耶穌差遣十二門徒",
     {"Matthew": [10, 10], "Mark": [6, 6], "Luke": [9, 9]}),
    (193, "feeding_the_5000",
     "喂饱五千人", "餵飽五千人",
     {"Matthew": [14, 14], "Mark": [6, 6], "Luke": [9, 9], "John": [6, 6]}),
    (194, "jesus_walks_on_water",
     "耶稣在水面上行走", "耶穌在水面上行走",
     {"Matthew": [14, 14], "Mark": [6, 6], "John": [6, 6]}),
    (195, "the_transfiguration",
     "登山变像", "登山變像",
     {"Matthew": [17, 17], "Mark": [9, 9], "Luke": [9, 9]}),
    (196, "mary_and_martha",
     "马利亚和马大", "馬利亞和馬大",
     {"Luke": [10, 10]}),
    (197, "parable_of_the_good_samaritan",
     "好撒玛利亚人的比喻", "好撒瑪利亞人的比喻",
     {"Luke": [10, 10]}),
    (198, "parable_of_the_prodigal_son",
     "浪子回头的比喻", "浪子回頭的比喻",
     {"Luke": [15, 15]}),
    (199, "rich_man_and_lazarus",
     "财主与拉撒路", "財主與拉撒路",
     {"Luke": [16, 16]}),
    (200, "parable_of_the_pharisee_and_the_tax_collector",
     "法利赛人与税吏的比喻", "法利賽人與稅吏的比喻",
     {"Luke": [18, 18]}),

    # Plate 201 skipped (duplicate of 189)

    (202, "jesus_raises_lazarus",
     "耶稣使拉撒路复活", "耶穌使拉撒路復活",
     {"John": [11, 11]}),
    (203, "jesus_teaching_on_greatness",
     "耶稣论 greatness", "耶穌論 greatness",
     {"Matthew": [20, 20], "Mark": [10, 10], "Luke": [18, 18]}),
    (204, "the_anointing_of_jesus_at_bethany",
     "耶稣在伯大尼受膏", "耶穌在伯大尼受膏",
     {"Matthew": [26, 26], "Mark": [14, 14], "John": [12, 12]}),
    (205, "triumphal_entry",
     "荣入圣城", "榮入聖城",
     {"Matthew": [21, 21], "Mark": [11, 11], "Luke": [19, 19], "John": [12, 12]}),
    (206, "jesus_washes_the_disciples_feet",
     "耶稣为门徒洗脚", "耶穌為門徒洗腳",
     {"John": [13, 13]}),
    (207, "institution_of_the_eucharist",
     "设立圣餐", "設立聖餐",
     {"Matthew": [26, 26], "Mark": [14, 14], "Luke": [22, 22], "1 Corinthians": [11, 11]}),
    (208, "garden_of_gethsemane",
     "客西马尼园", "客西馬尼園",
     {"Matthew": [26, 26], "Mark": [14, 14], "Luke": [22, 22], "John": [18, 18]}),
    (209, "arrest_of_jesus",
     "耶稣被捕", "耶穌被捕",
     {"Matthew": [26, 26], "Mark": [14, 14], "Luke": [22, 22], "John": [18, 18]}),
    (210, "jesus_before_caiaphas",
     "耶稣在该亚法面前", "耶穌在該亞法面前",
     {"Matthew": [26, 26], "Mark": [14, 14], "Luke": [22, 22], "John": [18, 18]}),
    (211, "peter_denies_jesus",
     "彼得否认耶稣", "彼得否認耶穌",
     {"Matthew": [26, 26], "Mark": [14, 14], "Luke": [22, 22], "John": [18, 18]}),
    (212, "jesus_mocked",
     "耶稣被戏弄", "耶穌被戲弄",
     {"Matthew": [27, 27], "Mark": [15, 15], "Luke": [22, 22], "John": [19, 19]}),
    (213, "jesus_delivered_to_be_crucified_by_pilate",
     "耶稣被彼拉多交出钉十字架", "耶穌被彼拉多交出釘十字架",
     {"Matthew": [27, 27], "Mark": [15, 15], "Luke": [23, 23], "John": [19, 19]}),
    (214, "death_of_judas_iscariot",
     "犹大之死", "猶大之死",
     {"Matthew": [27, 27]}),
    (215, "carrying_the_cross",
     "背十字架", "背十字架",
     {"John": [19, 19], "Matthew": [27, 27], "Mark": [15, 15], "Luke": [23, 23]}),
    (216, "the_crucifixion",
     "钉十字架", "釘十字架",
     {"Matthew": [27, 27], "Mark": [15, 15], "Luke": [23, 23], "John": [19, 19]}),
    (217, "the_burial_of_jesus",
     "耶稣的安葬", "耶穌的安葬",
     {"Matthew": [27, 27], "Mark": [15, 15], "Luke": [23, 23], "John": [19, 19]}),
    (218, "the_resurrection",
     "复活", "復活",
     {"Matthew": [28, 28], "Mark": [16, 16], "Luke": [24, 24], "John": [20, 20]}),
    (219, "the_empty_tomb",
     "空坟墓", "空墳墓",
     {"John": [20, 20], "Matthew": [28, 28], "Mark": [16, 16], "Luke": [24, 24]}),
    (220, "jesus_appears_to_mary_magdalene",
     "耶稣向抹大拉的马利亚显现", "耶穌向抹大拉的馬利亞顯現",
     {"John": [20, 20], "Mark": [16, 16]}),
    (221, "jesus_appears_to_mary_magdalene_2",
     "耶稣向抹大拉的马利亚显现（二）", "耶穌向抹大拉的馬利亞顯現（二）",
     {"John": [20, 20], "Mark": [16, 16]}),
    (222, "road_to_emmaus",
     "以马忤斯之路", "以馬忤斯之路",
     {"Luke": [24, 24]}),
    (223, "doubting_thomas",
     "多马的怀疑", "多馬的懷疑",
     {"John": [20, 20]}),
    (224, "miraculous_catch_of_fish",
     "奇迹打鱼", "奇蹟打魚",
     {"John": [21, 21]}),
    (225, "the_ascension",
     "升天", "升天",
     {"Acts": [1, 1], "Luke": [24, 24]}),
    (226, "pentecost",
     "五旬节", "五旬節",
     {"Acts": [2, 2]}),
    (227, "healing_the_crippled_beggar",
     "医治瘸腿乞丐", "醫治瘸腿乞丐",
     {"Acts": [3, 3]}),
    (228, "stoning_of_stephen",
     "司提反殉道", "司提反殉道",
     {"Acts": [7, 7]}),
    (229, "ethiopian_eunuch",
     "埃塞俄比亚太监", "埃塞俄比亞太監",
     {"Acts": [8, 8]}),
    (230, "sauls_conversion",
     "扫罗归信", "掃羅歸信",
     {"Acts": [9, 9], "Romans": [1, 1], "1 Corinthians": [1, 1], "2 Corinthians": [1, 1],
      "Galatians": [1, 1], "Ephesians": [1, 1], "Philippians": [1, 1], "Colossians": [1, 1],
      "1 Thessalonians": [1, 1], "2 Thessalonians": [1, 1], "1 Timothy": [1, 1],
      "2 Timothy": [1, 1], "Titus": [1, 1], "Philemon": [1, 1], "Hebrews": [1, 1]}),
    (231, "peters_vision_at_joppa",
     "彼得在约帕的异象", "彼得在約帕的異象",
     {"Acts": [10, 10]}),
    (232, "paul_and_barnabas_in_lystra",
     "保罗和巴拿巴在路司得", "保羅和巴拿巴在路司得",
     {"Acts": [14, 14]}),
    (233, "paul_at_the_areopagus",
     "保罗在亚略巴古", "保羅在亞略巴古",
     {"Acts": [17, 17], "Romans": [1, 1]}),
    (234, "paul_leaves_ephesus",
     "保罗离开以弗所", "保羅離開以弗所",
     {"Acts": [20, 20], "Ephesians": [1, 1]}),
    (235, "paul_arrives_in_rome",
     "保罗抵达罗马", "保羅抵達羅馬",
     {"Acts": [28, 28], "Romans": [1, 1]}),
    (236, "one_like_a_son_of_man",
     "人子", "人子",
     {"Revelation": [1, 1]}),
    (237, "four_horsemen_and_throne_room",
     "四骑士与宝座", "四騎士與寶座",
     {"Revelation": [4, 4]}),
    (238, "144000_sealed_and_trumpets",
     "十四万四千人受印与号角", "十四萬四千人受印與號角",
     {"Revelation": [7, 7]}),
    (239, "michael_and_the_dragon",
     "米迦勒与龙", "米迦勒與龍",
     {"Revelation": [12, 12]}),
    (240, "new_jerusalem",
     "新耶路撒冷", "新耶路撒冷",
     {"Revelation": [21, 21]}),
]

# Build a set of plate numbers to skip
SKIP_PLATES = set(range(144, 160)) | {201}

# Plates we actually process (in order)
ACTIVE_PLATES = [p for p in PLATES if p[0] not in SKIP_PLATES]

print(f"Total plates defined: {len(PLATES)}")
print(f"Plates to skip: {sorted(SKIP_PLATES)}")
print(f"Plates to generate: {len(ACTIVE_PLATES)}")


# ---------------------------------------------------------------------------
# Wikimedia Commons API helpers
# ---------------------------------------------------------------------------
BATCH_SIZE = 20  # Smaller batches to avoid rate-limiting


def fetch_urls_batch(plate_nums: list[int], retries: int = 3) -> dict[int, str]:
    """Fetch thumbnail URLs for a batch of plate numbers (max 50).

    Returns {plate_num: thumburl} for plates that were found.
    """
    results: dict[int, str] = {}
    titles = "|".join(
        f"File:Schnorr_von_Carolsfeld_Bibel_in_Bildern_1860_{n:03d}.png"
        for n in plate_nums
    )
    body = urllib.parse.urlencode({
        "action": "query",
        "titles": titles,
        "prop": "imageinfo",
        "iiprop": "url",
        "iiurlwidth": "1280",
        "format": "json",
    }).encode("utf-8")
    api_url = "https://commons.wikimedia.org/w/api.php"

    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(api_url, data=body,
                                         headers={"User-Agent": "YSWordsSchnorrScript/1.0",
                                                  "Content-Type": "application/x-www-form-urlencoded"})
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = json.loads(resp.read().decode("utf-8"))

            pages = data.get("query", {}).get("pages", {})
            for _pageid, page in pages.items():
                title = page.get("title", "")
                # Extract plate number from "File:Schnorr von Carolsfeld Bibel in Bildern 1860 001.png"
                # (Wikimedia normalizes underscores to spaces in titles)
                try:
                    num_part = title.replace("_", " ").split(" 1860 ")[1].replace(".png", "")
                    plate_num = int(num_part)
                except (IndexError, ValueError):
                    continue
                ii = page.get("imageinfo", [])
                if ii:
                    thumb = ii[0].get("thumburl") or ii[0].get("url")
                    if thumb:
                        results[plate_num] = thumb
            return results

        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as exc:
            print(f"  [RETRY {attempt}/{retries}] batch starting at {plate_nums[0]:03d}: {exc}")
            time.sleep(5 * attempt)

    return results


# ---------------------------------------------------------------------------
# Build title/description helpers
# ---------------------------------------------------------------------------
def _build_entry_from_url(plate_num: int, slug: str,
                          title_zh_hans: str, title_zh_hant: str,
                          books: dict, file_url: str) -> dict:
    padded = f"{plate_num:03d}"
    title_en = slug.replace("_", " ").title()

    entry = {
        "id": f"illus_schnorr_{padded}_{slug}",
        "kind": "scene",
        "title": {
            "en": f"{title_en} (Schnorr)",
            "zh-Hans": f"{title_zh_hans} ({SNIPPET_ZH_HANS})",
            "zh-Hant": f"{title_zh_hant} ({SNIPPET_ZH_HANT})",
        },
        "description": {
            "en": f"{ARTIST_EN}, {YEAR} — {title_en} ({_books_str_en(books)}).",
            "zh-Hans": f"{ARTIST_ZH_HANS},{YEAR}年——{title_zh_hans}（{_books_str_zh(books, 'hans')}）。",
            "zh-Hant": f"{ARTIST_ZH_HANT},{YEAR}年——{title_zh_hant}（{_books_str_zh(books, 'hant')}）。",
        },
        "books": books,
        "file": file_url,
    }
    return entry


def _books_str_en(books: dict) -> str:
    """E.g. 'Genesis 1' or 'Matthew 26; Mark 14'"""
    parts = []
    for book, (ch_start, ch_end) in books.items():
        if ch_start == ch_end:
            parts.append(f"{book} {ch_start}")
        else:
            parts.append(f"{book} {ch_start}-{ch_end}")
    return "; ".join(parts)


ZH_BOOK_MAP_HANS = {
    "Genesis": "创世记", "Exodus": "出埃及记", "Leviticus": "利未记",
    "Numbers": "民数记", "Deuteronomy": "申命记", "Joshua": "约书亚记",
    "Judges": "士师记", "Ruth": "路得记", "1 Samuel": "撒母耳记上",
    "2 Samuel": "撒母耳记下", "1 Kings": "列王纪上", "2 Kings": "列王纪下",
    "Ezra": "以斯拉记", "Nehemiah": "尼希米记", "Esther": "以斯帖记",
    "Job": "约伯记", "Psalms": "诗篇", "Proverbs": "箴言",
    "Ecclesiastes": "传道书", "Song of Solomon": "雅歌", "Isaiah": "以赛亚书",
    "Jeremiah": "耶利米书", "Lamentations": "耶利米哀歌", "Ezekiel": "以西结书",
    "Daniel": "但以理书", "Hosea": "何西阿书", "Joel": "约珥书",
    "Amos": "阿摩司书", "Obadiah": "俄巴底亚书", "Jonah": "约拿书",
    "Micah": "弥迦书", "Nahum": "那鸿书", "Habakkuk": "哈巴谷书",
    "Zephaniah": "西番雅书", "Haggai": "哈该书", "Zechariah": "撒迦利亚书",
    "Malachi": "玛拉基书", "Matthew": "马太福音", "Mark": "马可福音",
    "Luke": "路加福音", "John": "约翰福音", "Acts": "使徒行传",
    "Romans": "罗马书", "1 Corinthians": "哥林多前书", "2 Corinthians": "哥林多后书",
    "Galatians": "加拉太书", "Ephesians": "以弗所书", "Philippians": "腓立比书",
    "Colossians": "歌罗西书", "1 Thessalonians": "帖撒罗尼迦前书",
    "2 Thessalonians": "帖撒罗尼迦后书", "1 Timothy": "提摩太前书",
    "2 Timothy": "提摩太后书", "Titus": "提多书", "Philemon": "腓利门书",
    "Hebrews": "希伯来书", "James": "雅各书", "1 Peter": "彼得前书",
    "2 Peter": "彼得后书", "1 John": "约翰一书", "2 John": "约翰二书",
    "3 John": "约翰三书", "Jude": "犹大书", "Revelation": "启示录",
}

ZH_BOOK_MAP_HANT = {
    "Genesis": "創世記", "Exodus": "出埃及記", "Leviticus": "利未記",
    "Numbers": "民數記", "Deuteronomy": "申命記", "Joshua": "約書亞記",
    "Judges": "士師記", "Ruth": "路得記", "1 Samuel": "撒母耳記上",
    "2 Samuel": "撒母耳記下", "1 Kings": "列王紀上", "2 Kings": "列王紀下",
    "Ezra": "以斯拉記", "Nehemiah": "尼希米記", "Esther": "以斯帖記",
    "Job": "約伯記", "Psalms": "詩篇", "Proverbs": "箴言",
    "Ecclesiastes": "傳道書", "Song of Solomon": "雅歌", "Isaiah": "以賽亞書",
    "Jeremiah": "耶利米書", "Lamentations": "耶利米哀歌", "Ezekiel": "以西結書",
    "Daniel": "但以理書", "Hosea": "何西阿書", "Joel": "約珥書",
    "Amos": "阿摩司書", "Obadiah": "俄巴底亞書", "Jonah": "約拿書",
    "Micah": "彌迦書", "Nahum": "那鴻書", "Habakkuk": "哈巴谷書",
    "Zephaniah": "西番雅書", "Haggai": "哈該書", "Zechariah": "撒迦利亞書",
    "Malachi": "瑪拉基書", "Matthew": "馬太福音", "Mark": "馬可福音",
    "Luke": "路加福音", "John": "約翰福音", "Acts": "使徒行傳",
    "Romans": "羅馬書", "1 Corinthians": "哥林多前書", "2 Corinthians": "哥林多後書",
    "Galatians": "加拉太書", "Ephesians": "以弗所書", "Philippians": "腓立比書",
    "Colossians": "歌羅西書", "1 Thessalonians": "帖撒羅尼迦前書",
    "2 Thessalonians": "帖撒羅尼迦後書", "1 Timothy": "提摩太前書",
    "2 Timothy": "提摩太後書", "Titus": "提多書", "Philemon": "腓利門書",
    "Hebrews": "希伯來書", "James": "雅各書", "1 Peter": "彼得前書",
    "2 Peter": "彼得後書", "1 John": "約翰一書", "2 John": "約翰二書",
    "3 John": "約翰三書", "Jude": "猶大書", "Revelation": "啟示錄",
}


def _books_str_zh(books: dict, variant: str) -> str:
    """E.g. '创世记第1章' or '马太福音第26章;马可福音第14章'"""
    zh_map = ZH_BOOK_MAP_HANS if variant == "hans" else ZH_BOOK_MAP_HANT
    parts = []
    for book, (ch_start, ch_end) in books.items():
        zh_book = zh_map.get(book, book)
        if ch_start == ch_end:
            parts.append(f"{zh_book}第{ch_start}章")
        else:
            parts.append(f"{zh_book}第{ch_start}-{ch_end}章")
    return ";".join(parts)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    # 1. Read existing maps_index.json
    with open(MAPS_INDEX_PATH, "r", encoding="utf-8") as f:
        entries = json.load(f)
    print(f"Existing entries: {len(entries)}")

    # 2. Track existing IDs to avoid duplicates
    existing_ids = {e["id"] for e in entries}

    # 3. Filter to plates we actually need
    plates_to_process = [
        (pn, slug, zh_hans, zh_hant, books)
        for pn, slug, zh_hans, zh_hant, books in ACTIVE_PLATES
        if f"illus_schnorr_{pn:03d}_{slug}" not in existing_ids
    ]
    plate_nums_to_fetch = [p[0] for p in plates_to_process]
    print(f"Plates needing URLs: {len(plate_nums_to_fetch)}")

    # 4. Fetch all URLs in batches
    url_map: dict[int, str] = {}
    for batch_start in range(0, len(plate_nums_to_fetch), BATCH_SIZE):
        batch = plate_nums_to_fetch[batch_start:batch_start + BATCH_SIZE]
        print(f"Fetching batch {batch_start // BATCH_SIZE + 1}"
              f" (plates {batch[0]:03d}-{batch[-1]:03d}) ...")
        batch_results = fetch_urls_batch(batch)
        url_map.update(batch_results)
        print(f"  Got {len(batch_results)} URLs")
        time.sleep(2)  # be kind to API between batches

    # 5. Generate new entries
    new_entries = []
    for idx, (plate_num, slug, zh_hans, zh_hant, books) in enumerate(plates_to_process):
        padded = f"{plate_num:03d}"
        entry_id = f"illus_schnorr_{padded}_{slug}"

        file_url = url_map.get(plate_num)
        if file_url is None:
            print(f"  [SKIP] No URL for plate {padded}: {slug}")
            continue

        entry = _build_entry_from_url(plate_num, slug, zh_hans, zh_hant, books, file_url)
        new_entries.append(entry)

    print(f"\nGenerated {len(new_entries)} new entries.")

    # 6. Append and write back
    if new_entries:
        entries.extend(new_entries)
        with open(MAPS_INDEX_PATH, "w", encoding="utf-8") as f:
            json.dump(entries, f, indent=2, ensure_ascii=False)
        print(f"Wrote {len(entries)} total entries to {MAPS_INDEX_PATH}")
    else:
        print("No new entries to write.")

    print("Done.")


if __name__ == "__main__":
    main()
