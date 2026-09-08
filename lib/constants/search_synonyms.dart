/// 2026-09-08: the synonym and script data a fuzzy search expands a
/// query with — every byte of it derived from, or evidenced by,
/// something this repository already ships.
///
/// Ported from SeekSparks, where the shape of this file was written.
/// The SHAPE came across; none of the numbers did. Every table below
/// was re-derived from YsWords' own `assets/`, and the two repositories
/// disagree — see "What the two trees disagree about" below, which is
/// the reason re-derivation was the instruction rather than a copy.
///
/// ## Why this file exists at all, and what is NOT in it
///
/// 微读圣经's Chinese fuzzy search is driven by four shipped dictionary
/// files (`hmm_model.dict`, `stop_words.dict`, `synonyms_sc.dict`,
/// `synonyms_tc.dict`). **None of them is here and none of them was
/// read.** They are another product's data, under no licence that
/// permits redistribution, and a search feature that cannot be shipped
/// is not a feature. The same ruling closed two other doors:
///
///   * **OpenCC's conversion dictionaries** (Apache-2.0). This repo has
///     already met them and already ruled on them: the Traditional
///     lexicon glosses were produced with opencc OFFLINE, and
///     `test/lexicon_traditional_orthography_test.dart` exists
///     precisely because opencc's output had to be corrected
///     afterwards. Vendoring a 30k-entry table at RUNTIME, to do a job
///     this repo's own two 和合本 editions answer exactly, would be
///     carrying a third party's data and its licence file for nothing.
///   * **A Chinese word-frequency list** from any of the usual corpora.
///     Every one either has no licence statement or has a research-only
///     one, and provenance we cannot name is provenance we do not ship.
///
/// ## Provenance of each table below
///
/// **[kCuvSimplifiedChars] / [kCuvTraditionalChars]** — derived from
/// `assets/cuvs-yhwh.json` and `assets/cuvs-yhwh-tr.json`, the
/// Simplified and Traditional 和合本 (Chinese Union Version, 1919,
/// public domain) this app already ships. The two files hold the same
/// 31,102 verses under the same ids, and — measured — every verse pair
/// is character-for-character the same LENGTH **once ASCII spaces are
/// removed from both sides**, with zero exceptions.
///
/// That space-blind alignment is not a convenience, it is the only
/// alignment this repo's data supports: 60 verse pairs differ in
/// nothing but stray spaces around a `<note:>` or a closing quote
/// (民数记 10:29 and 士师记 1:16 are two), so a raw length comparison
/// throws them away. Removing spaces first recovers all 60 and costs
/// nothing, because the search key this feature runs against
/// (`MainProvider.searchKeys`) is space-stripped too — the derivation
/// aligns the text the same way the search does.
///
/// 1,114 Han character pairs differ, over 1,109 distinct Simplified
/// characters. `test/search_synonyms_test.dart` re-derives all of them
/// from the two assets on every run and fails if these two strings
/// drift from what the shipped text actually says, and
/// `tools/derive_cuv_script_tables.py` is what moves them when it does.
/// Until 2026-09-09 there was no such tool: the file said "derived",
/// the test proved it, and the only way to act on the test was to
/// hand-edit a 1,100-character string literal.
///
/// **2026-09-09.** Both assets were brought up to the publisher's
/// current text and the tables were re-derived off that base. Three
/// pairs moved, and each one is the new text being righter than the
/// old:
///
///   * `复 → 覆` is NEW, 3× — 反覆思想 at 路加福音 1:29 and 2:19, 反覆
///     不定 at 哥林多后书 1:17. The official 和合本繁體 sets all three
///     with 覆; this edition used to set them with 復. So 复 joins the
///     Simplified characters standing opposite two Traditional forms,
///     and there are now five of those rather than four.
///   * `辊 → 輥` is GONE — those seven verses (約書亞記 5:9 among them)
///     read 滚 / 滾 now, which is what the official prints.
///   * `镟 → 鏇` is GONE — the publisher's Simplified reads 旋 at
///     耶利米书 10:5 and the Traditional mirrors it. The official reads
///     鏇 there, so this one is a disagreement with the witness rather
///     than a correction of it; it is a question about the text and is
///     reported as one, not resolved here.
///
/// The 61st raw-length pair went the same way: 路加福音 23:16 carried a
/// stray space and a dangling 〔有古卷在此有： and now carries neither.
///
/// Licence: the source is public-domain scripture already in this
/// repository, and a table of which character stands opposite which is
/// a fact about that text.
///
/// **[kCuvCommonHanChars]** — the same derivation, one step simpler:
/// the Han characters occurring in more than a fifth of the 和合本's
/// verses. This is the licence-clean replacement for a stop-word list.
/// It is deliberately a list of CHARACTERS and not of words, because
/// that is what can be derived without a segmentation dictionary — the
/// thing this file exists to avoid needing.
///
/// **[kSearchSynonymGroups]** — hand-authored, and every group carries
/// the in-repo evidence that licenses it in its own `evidence` field.
/// Every number in those fields was re-measured against THIS repo's
/// assets through THIS repo's `sanitizeForSearch`; every verse cited
/// was re-found here. All four groups SeekSparks shipped survived that
/// check; none was dropped. Nothing was transcribed from a dictionary.
///
/// ## What the two trees disagree about, which is a finding and not a port bug
///
/// SeekSparks derives 1,107 pairs over 1,101 Simplified characters from
/// its own copies of the same two assets. (That figure, and the 23/15
/// split below, were measured on 2026-09-08 against the pre-sync base;
/// the three pairs the 2026-09-09 sync moved have not been re-measured
/// over there, because doing so means reading another repo's assets.
/// The conclusion is unaffected — it is a statement about which repo
/// makes the semantic splits, and this one still makes more of them.)
/// The files are not the same
/// files — YsWords' are ~1.1 MB larger — and the disagreement is not
/// noise. It is systematic, and YsWords is on the right side of it:
/// **this repo's Traditional edition makes the semantic splits that a
/// naive one-to-one conversion cannot.** 23 pairs are here and not
/// there — 发→髮 (hair, 88×), 面→麵 (flour, 107×), 谷→穀 (grain, 68×),
/// 松→鬆, 胡→鬍, 须→鬚, 采→採, 墙→牆, 仑→崙 — and those are the very
/// distinctions `test/traditional_hair_glyph_test.dart`,
/// `traditional_flour_glyph_test.dart`, `traditional_grain_glyph_test.dart`
/// and their siblings were written to enforce. 15 pairs are there and
/// not here, and they are the variant forms this repo swept out
/// (么→麼, 众→衆, 凌→淩, 卜→蔔, 吃→喫, 症→癥, 墙→墻, 仑→侖).
///
/// So the tables MUST NOT be shared between the repos, and a future
/// re-sync must re-derive rather than copy. The common-character list
/// is the one place the two agree exactly: the same 17 characters in
/// the same order, which is worth knowing — it is the only table here
/// that does not depend on the Traditional edition at all.
library;

/// One set of spellings a fuzzy search treats as the same word.
class SearchSynonymGroup {
  const SearchSynonymGroup({required this.forms, required this.evidence});

  /// Every accepted spelling, lower-cased where the script has case.
  /// A query matching any one of them may be rewritten to any other.
  final List<String> forms;

  /// Where the claim comes from — a verse of a shipped edition, a
  /// measurement over one, or another table in this repository. Not
  /// decoration: this string is the reason the group is allowed to
  /// exist, and a group that cannot state one does not go in.
  final String evidence;
}

/// Simplified Han characters that differ from their Traditional
/// counterpart in the shipped 和合本, positionally paired with
/// [kCuvTraditionalChars].
///
/// 1,114 pairs over 1,109 distinct Simplified characters. Five
/// Simplified characters stand opposite two different Traditional ones
/// (发 → 發/髮, 坛 → 壇/罈, 干 → 乾/幹, 须 → 須/鬚, and since the
/// 2026-09-09 publisher sync 复 → 復/覆), so they appear
/// twice here; the more frequent Traditional form is listed FIRST,
/// which is what makes `simplifiedToTraditional` deterministic. In the
/// other direction there is no ambiguity at all — measured, not
/// assumed: no Traditional character in these 31,102 verses stands
/// opposite two different Simplified ones.
const String kCuvSimplifiedChars =
    '万与丑专业丛东丝丢两严丧个丰临为丽举么义乌乐习乡书买乱争于亏云亘亚产亩亲亵亿仅仆从仑仓仪们价仿众伙会伟传伤伦伪体余佛佣侄侧借债倾偿儿兑党兰关兴养兽内冈册写军农冲决况净凄准凉凋减凑几凤凭凯凶击凿划则刚创'
    '删别制剑剥劝办务动励劲劳势匀区医华协单卖卤卧卫却厂厅历厉压厌厕厨参双发发变叙叠只台叶号叹吁后吓吕吗听启吴呐呕员咙咸响哑哒哗唤啬喂喷嗳嘘嘱团园围囵国图圆圣场坏块坚坛坛坟坠垒垦垫堕墙壮声壶处备复复够头夸夹'
    '夺奁奋奖奥妆妇妈娇娈婴嫔孙学宁宝实宠审宫宽宾寝对寻导寿将尔尘尝尸尽层屉属屡岁岂岖岛岩岭岳帅师帐帘帜带帮干干并广庄庆库应庙废廪开异弃弑张弥弯弹强归当录径御志忧怀态怜总恋恒恳恶恸恺恼悦悬悯惊惧惨惩惫惭惯愈'
    '愤愿懒戏战户扎扑执扩扪扫扬扰抚抛抟抡抢护报抬担拟拢拣拥拦拧拨择挂挞挟挡挣挤损捡换捣据捻掳掷搀搁搂搅携摆摇撑撵攒敌敛数斋斗斩断无旧时旷昼显晋晒晓暂术朴机杀杂权杆条来杨杰松极构枢枪枫柜标栋栏树栖样桨梦检棂'
    '楼榄槛横橹欢残殓殡殴毁毂毕毙气汉汤汹沉沟没沦沧泞注泪泻泼洁洒洼浅浆浇浊测济浑浓涂涌涛涤润涨渊渎渐渔温游湾湿溃溅滚满滤滥滨滩澜灭灯灵灶灾灿炉点炼烁烂烛烟烦烧烫热爱牵牺犊状犹独狭狮狱狸猎猪猫献玛环现玺珰琏'
    '琐璎瓮电画畅疖疟疮疯痒痨痪痫痴瘪瘫癣癫皱盏盐监盖盗盘着睁瞒矶矿码砖确碍碜碱礼祷祸禀禄离秃种积称秸秽税稣稳穑穷窃窍窑窜窝窥竖竞笃笔笼筑筛筹签箩箫篓篮篱籴类粜粪粮紧红约级纪纬纯纲纳纵纶纷纸纹纺纽线练细织终'
    '绊经绑绒结绕给络绝统绣继续绰绳绵绸绺绿缄缅缆缒缓编缘缚缝缠缦缩网罗罚罢羁羡耸耻聂聋职联聪肃肠肤肮肾肿胀胁胆胜胡胶脉脏脐脑脓脚脱脸腊腌腾舱艰艳艺节芦芸苇苍苏苟苹范茔荆荐荚荡荣荤荫药莱莲获营萨葱蓝虑虚虫虽'
    '蚀蚁蚂蚕蛮蜗蜡蝇蝎衔补衮装裤见观规觅视觉觌觐触誉誊计订认讥讨让训议记讲讳讶讷许讹论讼设访诀证评诅识诈诉词诏译诓试诗诚话诡询该详诧诫诬语诮误诰诱诲说诵请诸诺读课诿谁调谄谅谆谈谊谋谎谏谒谕谗谜谢谣谤谦谨谬'
    '谱谷贝贞负贡财责贤败账货质贩贪贫贬贯贱贴贵贷贸费贺贻贼贾贿赀赁赂赃资赉赌赎赏赐赒赔赖赘赚赛赞赠赢赶趋跃践踊踪蹿车轧轨转轭轮软轰轴轻载轿较辅辆辇辈辉辋辎辐输辔辖辗辞辩辫边辽达迁过迈运还这进远违连迟迹适选'
    '逊递逻遗遥邻郑酿采释里鉴錾针钉钏钓钝钢钥钦钩钮钱钹钻铁铃铅铊铙铛铜铠铭铮铲银铸铺链销锁锄锅锈锉锋锐错锚锡锣锤锥锦锨锭锯锸锹镀镇镊镌镕镜镟镣镯镰镶长门闩闪闭问闯闲间闵闷闸闹闺闻阁阄阉阔队阳阴阵阶陆陇陈险'
    '随隐隶难雏雾霉静面韦顶顷项顺须须顽顾顿颁颂预领颈颊颗题颜额颠颤风飕飖飘飞餍饥饫饭饮饰饱饶饷饼饿馆馈馋馐馑马驮驯驰驱驳驴驹驻驼驾驿骂骄骆骇验骏骑骗骚骟骡髅鬓鱼鲁鲜鳄鳞鸟鸠鸡鸣鸦鸪鸬鸮鸱鸵鸶鸷鸽鸿鹈鹌鹑鹕'
    '鹚鹞鹤鹧鹭鹯鹰鹳麦黄齐齿龈龙龛';

/// The Traditional character standing opposite each of
/// [kCuvSimplifiedChars], same index.
const String kCuvTraditionalChars =
    '萬與醜專業叢東絲丟兩嚴喪個豐臨為麗舉麽義烏樂習鄉書買亂爭於虧雲亙亞產畝親褻億僅僕從崙倉儀們價彷眾夥會偉傳傷倫偽體餘彿傭姪側藉債傾償兒兌黨蘭關興養獸內岡冊寫軍農沖決況淨淒準涼雕減湊幾鳳憑凱兇擊鑿劃則剛創'
    '刪別製劍剝勸辦務動勵勁勞勢勻區醫華協單賣鹵臥衛卻廠廳歷厲壓厭廁廚參雙發髮變敘疊隻臺葉號嘆籲後嚇呂嗎聽啟吳吶嘔員嚨鹹響啞噠嘩喚嗇餵噴噯噓囑團園圍圇國圖圓聖場壞塊堅壇罈墳墜壘墾墊墮牆壯聲壺處備復覆夠頭誇夾'
    '奪奩奮獎奧妝婦媽嬌孌嬰嬪孫學寧寶實寵審宮寬賓寢對尋導壽將爾塵嘗屍盡層屜屬屢歲豈嶇島巖嶺嶽帥師帳簾幟帶幫乾幹並廣莊慶庫應廟廢廩開異棄弒張彌彎彈強歸當錄徑禦誌憂懷態憐總戀恆懇惡慟愷惱悅懸憫驚懼慘懲憊慚慣癒'
    '憤願懶戲戰戶紮撲執擴捫掃揚擾撫拋摶掄搶護報擡擔擬攏揀擁攔擰撥擇掛撻挾擋掙擠損撿換搗據撚擄擲攙擱摟攪攜擺搖撐攆攢敵斂數齋鬥斬斷無舊時曠晝顯晉曬曉暫術樸機殺雜權桿條來楊傑鬆極構樞槍楓櫃標棟欄樹棲樣槳夢檢欞'
    '樓欖檻橫櫓歡殘殮殯毆毀轂畢斃氣漢湯洶沈溝沒淪滄濘註淚瀉潑潔灑窪淺漿澆濁測濟渾濃塗湧濤滌潤漲淵瀆漸漁溫遊灣濕潰濺滾滿濾濫濱灘瀾滅燈靈竈災燦爐點煉爍爛燭煙煩燒燙熱愛牽犧犢狀猶獨狹獅獄貍獵豬貓獻瑪環現璽璫璉'
    '瑣瓔甕電畫暢癤瘧瘡瘋癢癆瘓癇癡癟癱癬癲皺盞鹽監蓋盜盤著睜瞞磯礦碼磚確礙磣鹼禮禱禍稟祿離禿種積稱稭穢稅穌穩穡窮竊竅窯竄窩窺豎競篤筆籠築篩籌簽籮簫簍籃籬糴類糶糞糧緊紅約級紀緯純綱納縱綸紛紙紋紡紐線練細織終'
    '絆經綁絨結繞給絡絕統繡繼續綽繩綿綢綹綠緘緬纜縋緩編緣縛縫纏縵縮網羅罰罷羈羨聳恥聶聾職聯聰肅腸膚骯腎腫脹脅膽勝鬍膠脈臟臍腦膿腳脫臉臘醃騰艙艱艷藝節蘆蕓葦蒼蘇茍蘋範塋荊薦莢蕩榮葷蔭藥萊蓮獲營薩蔥藍慮虛蟲雖'
    '蝕蟻螞蠶蠻蝸蠟蠅蠍銜補袞裝褲見觀規覓視覺覿覲觸譽謄計訂認譏討讓訓議記講諱訝訥許訛論訟設訪訣證評詛識詐訴詞詔譯誆試詩誠話詭詢該詳詫誡誣語誚誤誥誘誨說誦請諸諾讀課諉誰調諂諒諄談誼謀謊諫謁諭讒謎謝謠謗謙謹謬'
    '譜穀貝貞負貢財責賢敗賬貨質販貪貧貶貫賤貼貴貸貿費賀貽賊賈賄貲賃賂贓資賚賭贖賞賜賙賠賴贅賺賽讚贈贏趕趨躍踐踴蹤躥車軋軌轉軛輪軟轟軸輕載轎較輔輛輦輩輝輞輜輻輸轡轄輾辭辯辮邊遼達遷過邁運還這進遠違連遲跡適選'
    '遜遞邏遺遙鄰鄭釀採釋裏鑒鏨針釘釧釣鈍鋼鑰欽鉤鈕錢鈸鉆鐵鈴鉛鉈鐃鐺銅鎧銘錚鏟銀鑄鋪鏈銷鎖鋤鍋銹銼鋒銳錯錨錫鑼錘錐錦鍁錠鋸鍤鍬鍍鎮鑷鐫鎔鏡鏇鐐鐲鐮鑲長門閂閃閉問闖閑間閔悶閘鬧閨聞閣鬮閹闊隊陽陰陣階陸隴陳險'
    '隨隱隸難雛霧黴靜麵韋頂頃項順須鬚頑顧頓頒頌預領頸頰顆題顏額顛顫風颼颻飄飛饜饑飫飯飲飾飽饒餉餅餓館饋饞饈饉馬馱馴馳驅駁驢駒駐駝駕驛罵驕駱駭驗駿騎騙騷騸騾髏鬢魚魯鮮鱷鱗鳥鳩雞鳴鴉鴣鸕鴞鴟鴕鷥鷙鴿鴻鵜鵪鶉鶘'
    '鶿鷂鶴鷓鷺鸇鷹鸛麥黃齊齒齦龍龕';

/// Han characters occurring in more than a fifth of the 和合本's 31,102
/// verses — 17 of them, in descending order of how many verses hold
/// them. The threshold is 6,220 verses.
///
/// Used for ONE thing: a character this common cannot narrow an AND of
/// query fragments, so `chinese_segmentation.dart` drops it from the
/// segmented reading of a query. 的 is in 24,525 verses; asking for it
/// as a conjunct asks for nothing.
///
/// 雅 is in the list, and it is in it BECAUSE this edition spells the
/// divine name 雅伟 — 雅 is in 7,289 verses, which is 雅伟's 6,106 plus
/// the ordinary vocabulary. That is the reason the stop filter is
/// applied only AFTER vocabulary matching, and only to segments one
/// character long: 雅伟 survives whole, and a bare 雅 was never going to
/// be a useful conjunct anyway.
const String kCuvCommonHanChars = '的他人们你我在是说就雅不以为有要了';

/// The spellings a fuzzy search may substitute for one another.
///
/// Four groups, and the shortness is the point. Every group here
/// answers a measured hole in the shipped editions, and every rejected
/// candidate below was rejected for a stated reason rather than for
/// caution.
///
/// **Rejected, and why:**
///
///   * **扫罗 / 保罗 (Saul / Paul).** 使徒行传 13:9 licenses the identity,
///     but 扫罗 is also the king — 撒母耳记上 alone gives him 200+ verses
///     — so the group would answer a search for the apostle with the
///     whole of Israel's first monarchy. A synonym that is true of one
///     person and false of another is not a synonym.
///   * **西门 / 彼得 (Simon / Peter).** Same defect: the shipped text
///     also has Simon the Zealot, Simon the leper, Simon the tanner,
///     Simon of Cyrene and Simon Magus.
///   * **圣灵 / 圣神 (the Catholic rendering).** No evidence in this
///     repository — no shipped edition uses 圣神 — and a group whose
///     evidence field would have to say "general knowledge" is exactly
///     what the licence rule forbids.
///   * **English synonym groups in general.** English gets stemming
///     (`porter_stemmer.dart`), which is an algorithm; an English
///     THESAURUS is a data file, and no free one with a nameable licence
///     was found that was worth the audit. The divine name is the single
///     exception, and it is in because it is not a thesaurus entry — it
///     is one name spelled differently by different shipped editions.
const List<SearchSynonymGroup> kSearchSynonymGroups = [
  /// The divine name, which this app exists to restore — and which,
  /// because it restores it, no reader outside this app spells the way
  /// its corpus does.
  ///
  /// Two layers put 雅伟 where a reader expects 耶和华. The ASSETS were
  /// swept: `assets/cuvs-yhwh.json` says 雅伟 6,133 times and 耶和华 not
  /// once. And `text_patterns.dart`'s `_normalizeDivineNames` rewrites
  /// whatever is left as the text is sanitised, in every edition —
  /// 耶和华 → 雅伟, 耶和華 → 雅偉, all-caps `LORD` → `Yahweh`. **Nothing
  /// did the same to the query** until this feature landed. Counted
  /// over the real search key of each shipped edition:
  ///
  ///     typed      cuvs-yhwh  cuvs-yhwh-tr    kjv
  ///     雅伟           6,106             0      —
  ///     雅偉               0         6,106      —
  ///     耶和华             0             0      —
  ///     耶和華             0             0      —
  ///     yahweh         —             —      5,614
  ///     jehovah        —             —          7
  ///     yhwh           —             —          0
  ///
  /// The 耶和华 row is the whole argument. It is the spelling in every
  /// Chinese Bible in print, and it found NOTHING in either Chinese
  /// edition this app ships — not because the verses are missing but
  /// because the text says 雅伟. A reader typing the only name they were
  /// ever taught got an empty page over 6,106 verses about exactly what
  /// they asked for. The 雅偉 / 雅伟 pair is the same defect between the
  /// two scripts, and `yhwh` is the same defect in English.
  ///
  /// **`lord` is deliberately NOT a member.** Adding it would make
  /// `yahweh` return the KJV's 1,265 "Lord" verses as well, and that is
  /// the one distinction `_normalizeDivineNames` goes out of its way to
  /// preserve: it rewrites all-caps LORD and leaves mixed-case Lord
  /// alone, because "Lord" is Adonai and kyrios. The search key is
  /// lower-cased by the time it reaches a matcher, so this layer cannot
  /// tell the two apart at all — which means the only safe thing it can
  /// do is decline to join them.
  SearchSynonymGroup(
    forms: [
      '雅伟', '雅偉', '雅威', '耶和华', '耶和華',
      'yahweh', 'yhwh', 'jehovah',
    ],
    evidence: "strongs_service.dart's _aliasToStrongs pins all of these "
        'to H3068; search keys: cuvs-yhwh 雅伟 6106 / 耶和华 0, '
        'cuvs-yhwh-tr 雅偉 6106 / 耶和華 0, kjv yahweh 5614 / '
        'jehovah 7 / yhwh 0',
  ),

  /// 神 and 上帝 are the two 和合本 editions, not two words. The Union
  /// Version has been printed in a 神版 and a 上帝版 since 1919, and this
  /// app ships the 神版 only: measured over search keys, 上帝 occurs in
  /// ZERO verses of cuvs-yhwh and cuvs-yhwh-tr, while 神 occurs in
  /// 3,995 of each. A reader who grew up on the 上帝版 types the word
  /// they were raised on and gets an empty page.
  SearchSynonymGroup(
    forms: ['神', '上帝'],
    evidence: '和合本 is printed in a 神版 and a 上帝版; this repo ships '
        'the 神版 — search keys: 上帝 0 in both shipped Chinese '
        'editions, 神 3995 in each',
  ),

  /// The scripture text licenses this one itself, in the verse that
  /// introduces the name: 约翰福音 1:42 「你要称为矶法。（矶法翻出来就是
  /// 彼得。）」 Measured over search keys: 矶法 is in 9 verses, 彼得 in
  /// 176, and 哥林多前书 and 加拉太书 use 矶法 for the man 马太福音 and
  /// 马可福音 call 彼得. The Traditional 磯法 finds 0 in the Simplified
  /// edition and 9 in the Traditional one, which is the script rung's
  /// job rather than this one's — both are tried, in that order.
  SearchSynonymGroup(
    forms: ['彼得', '矶法', '磯法'],
    evidence: 'cuvs-yhwh 约翰福音 1:42 「矶法翻出来就是彼得」; search '
        'keys: 矶法 9, 彼得 176, 磯法 0 (9 in cuvs-yhwh-tr)',
  ),

  /// Licensed the same way, by 约翰福音 1:41 「弥赛亚翻出来就是基督」 and
  /// again by 4:25. Measured over search keys, 弥赛亚 is in 2 verses and
  /// 基督 in 543 — which is also the group most likely to annoy: a
  /// reader looking for the two verses that say 弥赛亚 does not
  /// necessarily want the 543 that say 基督. It is in because the
  /// broadened rows are labelled and the literal ones are found first,
  /// and it is the clearest case in the corpus of the text defining its
  /// own synonym.
  SearchSynonymGroup(
    forms: ['基督', '弥赛亚', '彌賽亞'],
    evidence: 'cuvs-yhwh 约翰福音 1:41 「弥赛亚翻出来就是基督」; search '
        'keys: 弥赛亚 2, 基督 543',
  ),
];
