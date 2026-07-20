const uiStrings = {
  // ====== Search Page ======
  'search': {
    'zh-Hans': '搜索',
    'zh-Hant': '搜尋',
    'en': 'Search',
  },
  'searchResultCount': {
    'zh-Hans': '共 {count} 处，按书统计：',
    'zh-Hant': '共 {count} 處，按書統計：',
    'en': 'Total {count} matches, grouped by book:',
  },
  'viewMoreBooksHint': {
    'zh-Hans': '点击查看更多书卷，右上角筛选可跳转到书卷。',
    'zh-Hant': '點擊查看更多書卷，右上角篩選可跳轉到書卷。',
    'en': 'Tap to view more books; use top-right filter to jump to a book.',
  },
  'noResults': {
    'zh-Hans': '未找到结果',
    'zh-Hant': '找不到結果',
    'en': 'No results found',
  },

  // ====== Search Filters ======
  'searchCurrentBook': {
    'zh-Hans': '搜索当前书卷',
    'zh-Hant': '搜尋當前書卷',
    'en': 'Search Current Book',
  },
  'searchEntireBible': {
    'zh-Hans': '搜索整本圣经',
    'zh-Hant': '搜尋整本聖經',
    'en': 'Search Entire Bible',
  },

  // ====== General Navigation ======
  'back': {
    'zh-Hans': '返回',
    'zh-Hant': '返回',
    'en': 'Back',
  },
  'showMenu': {
    'zh-Hans': '显示菜单',
    'zh-Hant': '顯示選單',
    'en': 'Show menu',
  },

  // ====== Bible Navigation ======
  // Renamed from OT/NT to Hebrew Bible / Greek Bible at the user's
  // request — more accurate to the underlying source languages.
  'oldTestament': {
    'zh-Hans': '希伯来圣经',
    'zh-Hant': '希伯來聖經',
    'en': 'Hebrew Bible',
  },
  'newTestament': {
    'zh-Hans': '希腊圣经',
    'zh-Hant': '希臘聖經',
    'en': 'Greek Bible',
  },
  // Short forms used in narrow toggle buttons where the full name
  // would overflow.
  'oldTestamentShort': {
    'zh-Hans': '希伯来',
    'zh-Hant': '希伯來',
    'en': 'Hebrew',
  },
  'newTestamentShort': {
    'zh-Hans': '希腊',
    'zh-Hant': '希臘',
    'en': 'Greek',
  },
  'previousChapter': {
    'zh-Hans': '上一章',
    'zh-Hant': '上一章',
    'en': 'Previous Chapter',
  },
  'nextChapter': {
    'zh-Hans': '下一章',
    'zh-Hant': '下一章',
    'en': 'Next Chapter',
  },
  'bibleBooks': {
    'zh-Hans': '书卷',
    'zh-Hant': '書卷',
    'en': 'Bible Books',
  },
  'addChapter': {
    'zh-Hans': '添加章节',
    'zh-Hant': '新增章節',
    'en': 'Add chapter',
  },
  'openAnotherChapter': {
    'zh-Hans': '打开另一章',
    'zh-Hant': '開啟另一章',
    'en': 'Open another chapter',
  },
  'openPages': {
    'zh-Hans': '打开的页面',
    'zh-Hant': '開啟的頁面',
    'en': 'Open pages',
  },
  'reader': {
    'zh-Hans': '阅读',
    'zh-Hant': '閱讀',
    'en': 'Reader',
  },
  'currentPage': {
    'zh-Hans': '当前页面',
    'zh-Hant': '目前頁面',
    'en': 'Current page',
  },
  'switchPage': {
    'zh-Hans': '切换页面',
    'zh-Hant': '切換頁面',
    'en': 'Switch page',
  },
  'closePage': {
    'zh-Hans': '关闭页面',
    'zh-Hant': '關閉頁面',
    'en': 'Close page',
  },
  'changeVersion': {
    'zh-Hans': '切换版本',
    'zh-Hant': '切換版本',
    'en': 'Change Version',
  },
  // 2026-06-22: language-grouped version picker. Title + the three
  // language-tab labels (shown in the app's UI language) + the
  // per-language section subtitle.
  'versionPickerTitle': {
    'zh-Hans': '选择圣经版本',
    'zh-Hant': '選擇聖經版本',
    'en': 'Choose a version',
  },
  // 2026-07-21: made these three self-referential / locale-INDEPENDENT
  // — same value in all three locale slots — instead of translating
  // "Traditional"/"Simplified" into whatever the UI language happens
  // to be. A language-name tab should read as that language names
  // itself (this already matches Settings → Interface Language's
  // dropdown, which hardcodes 'English' / '简体中文' / '繁體中文'
  // regardless of the app's current locale — these tabs previously
  // didn't follow that same convention). Also switched from the
  // short 2-char forms (繁體/简体) to the full 4-char language names
  // so English-UI users see 繁體中文/简体中文 rather than the bare
  // English words "Traditional"/"Simplified", which don't actually
  // name a script the way the Chinese terms do.
  'versionLangEnglish': {
    'zh-Hans': 'English',
    'zh-Hant': 'English',
    'en': 'English',
  },
  'versionLangTraditional': {
    'zh-Hans': '繁體中文',
    'zh-Hant': '繁體中文',
    'en': '繁體中文',
  },
  'versionLangSimplified': {
    'zh-Hans': '简体中文',
    'zh-Hant': '简体中文',
    'en': '简体中文',
  },
  'chapter': {
    'zh-Hans': '第 {n} 章',
    'zh-Hant': '第 {n} 章',
    'en': 'Chapter {n}',
  },
  'versePosition': {
    'zh-Hans': '第 {current} / {total} 节',
    'zh-Hant': '第 {current} / {total} 節',
    'en': 'Verse {current} of {total}',
  },
  'selectedVerses': {
    'zh-Hans': '已选择 {count} 节',
    'zh-Hant': '已選擇 {count} 節',
    'en': '{count} selected',
  },
  'clearSelection': {
    'zh-Hans': '清除选择',
    'zh-Hant': '清除選擇',
    'en': 'Clear selection',
  },
  'copySelection': {
    'zh-Hans': '复制',
    'zh-Hant': '複製',
    'en': 'Copy',
  },
  'highlight': {
    'zh-Hans': '高亮',
    'zh-Hant': '高亮',
    'en': 'Highlight',
  },
  'highlights': {
    'zh-Hans': '高亮',
    'zh-Hant': '高亮',
    'en': 'Highlights',
  },
  'highlightsEmpty': {
    'zh-Hans': '尚无高亮。长按经文，选择颜色即可添加。',
    'zh-Hant': '尚無高亮。長按經文，選擇顏色即可添加。',
    'en': 'No highlights yet. Long-press a verse and pick a color.',
  },
  'highlightsNoMatch': {
    'zh-Hans': '没有符合此筛选的高亮。',
    'zh-Hant': '沒有符合此篩選的高亮。',
    'en': 'No highlights match this filter.',
  },
  'allColors': {
    'zh-Hans': '所有颜色',
    'zh-Hant': '所有顏色',
    'en': 'All',
  },
  'copyAll': {
    'zh-Hans': '复制全部',
    'zh-Hant': '複製全部',
    'en': 'Copy all',
  },
  'share': {
    'zh-Hans': '分享',
    'zh-Hant': '分享',
    'en': 'Share',
  },
  'originalText': {
    'zh-Hans': '释经',
    'zh-Hant': '釋經',
    'en': 'Exegesis',
  },
  'originalHint': {
    'zh-Hans': '点击词语查看 Strong\'s 词条。',
    'zh-Hant': '點擊詞語查看 Strong\'s 詞條。',
    'en': 'Tap a word to see its Strong\'s entry.',
  },
  'originalNotAvailable': {
    'zh-Hans': '此节经文暂未提供原文数据。',
    'zh-Hant': '此節經文暫未提供原文資料。',
    'en': 'Original-language data not available for this verse yet.',
  },
  'strongsNotFound': {
    'zh-Hans': '未找到该 Strong\'s 词条。',
    'zh-Hant': '未找到該 Strong\'s 詞條。',
    'en': 'Lexicon entry not found.',
  },
  'concordanceUsed': {
    'zh-Hans': '出现 {count} 次',
    'zh-Hant': '出現 {count} 次',
    'en': 'Used {count} times',
  },
  'concordanceShowingFirst': {
    'zh-Hans': '显示前 {shown} 条（共 {total} 条）',
    'zh-Hant': '顯示前 {shown} 條（共 {total} 條）',
    'en': 'showing first {shown} of {total}',
  },
  'copyTable': {
    'zh-Hans': '复制词表',
    'zh-Hant': '複製詞表',
    'en': 'Copy word table',
  },
  'copyWordStudy': {
    'zh-Hans': '复制词语研经',
    'zh-Hant': '複製詞語研經',
    'en': 'Copy word study',
  },
  'distributionTable': {
    'zh-Hans': '分布表',
    'zh-Hant': '分佈表',
    'en': 'Distribution Table',
  },
  'crossRefs': {
    'zh-Hans': '相互参照',
    'zh-Hant': '相互參照',
    'en': 'Cross-references',
  },
  'noteAdd': {'zh-Hans': '笔记', 'zh-Hant': '筆記', 'en': 'Note'},
  'noteEdit': {'zh-Hans': '编辑笔记', 'zh-Hant': '編輯筆記', 'en': 'Edit note'},
  'noteHint': {
    'zh-Hans': '为这节经文写下你的笔记…',
    'zh-Hant': '為這節經文寫下你的筆記…',
    'en': 'Type your note for this verse…',
  },
  'noteSave': {'zh-Hans': '保存', 'zh-Hant': '儲存', 'en': 'Save'},
  'noteDelete': {'zh-Hans': '删除', 'zh-Hant': '刪除', 'en': 'Delete'},
  // 2026-05-20 (v1.2.62): WeChat-style fullscreen toggle on the
  // note editor sheet. Compact ↔ fullscreen.
  'noteExpand': {
    'zh-Hans': '全屏',
    'zh-Hant': '全螢幕',
    'en': 'Expand',
  },
  'noteCollapse': {
    'zh-Hans': '收起',
    'zh-Hant': '收起',
    'en': 'Collapse',
  },
  // 2026-05-19 (v1.2.59): note-editor "+ Verse Reference" button +
  // its book/chapter/verse picker sheet. Tapping a reference in
  // the saved note (Library / wherever displayed) opens the
  // reader at that verse.
  'noteAddReference': {
    'zh-Hans': '+ 经文',
    'zh-Hant': '+ 經文',
    'en': '+ Verse',
  },
  'notePickerPickBook': {
    'zh-Hans': '选择书卷',
    'zh-Hant': '選擇書卷',
    'en': 'Pick a book',
  },
  'notePickerPickChapter': {
    'zh-Hans': '选择章',
    'zh-Hant': '選擇章',
    'en': 'Pick a chapter',
  },
  'notePickerPickVerse': {
    'zh-Hans': '选择经文',
    'zh-Hant': '選擇經文',
    'en': 'Pick verses',
  },
  // 2026-05-19 (v1.2.61): multi-select picker UX strings.
  'notePickerSelectVerses': {
    'zh-Hans': '点击一或多节经文',
    'zh-Hant': '點擊一或多節經文',
    'en': 'Tap one or more verses',
  },
  'notePickerClearSelection': {
    'zh-Hans': '清空选择',
    'zh-Hant': '清空選擇',
    'en': 'Clear selection',
  },
  'notePickerInsert': {
    'zh-Hans': '插入',
    'zh-Hant': '插入',
    'en': 'Insert',
  },
  // 2026-05-20 (v1.2.66): chip-tooltip for the cross-canon fallback
  // indicator on a note-editor ref chip. Surfaces when the ref's
  // book isn't in the user's current Bible version (e.g. they're
  // on LJK2 NT-only but the ref is for Genesis); tapping the chip
  // will trigger `bibleVersionFullCanonFallback` to load CUVS-YHWH.
  'noteChipFallbackTooltip': {
    'zh-Hans': '此书卷不在当前译本中——点击将自动切换到完整的和合本雅伟版',
    'zh-Hant': '此書卷不在當前譯本中——點擊將自動切換到完整的和合本雅偉版',
    'en': "This book isn't in your current version — tapping will "
        "load the full-canon companion",
  },
  // 2026-05-19 (v1.2.61): reference preview sheet (tap a ref in a
  // saved note → bottom sheet shows referenced verses; expand
  // shows whole chapter; open-in-reader navigates fully).
  'notePreviewExpand': {
    'zh-Hans': '展开整章',
    'zh-Hant': '展開整章',
    'en': 'Expand chapter',
  },
  'notePreviewCollapse': {
    'zh-Hans': '收起',
    'zh-Hant': '收起',
    'en': 'Collapse',
  },
  'notePreviewOpenReader': {
    'zh-Hans': '在阅读器中打开',
    'zh-Hant': '在閱讀器中打開',
    'en': 'Open in Reader',
  },
  'notePreviewMissing': {
    'zh-Hans': '此段经文不在当前的圣经版本中。请在阅读器中打开以切换版本。',
    'zh-Hant': '此段經文不在當前的聖經版本中。請在閱讀器中打開以切換版本。',
    'en': "This passage isn't in your current Bible version. "
        "Open it in the reader to switch versions.",
  },
  // `back` already exists earlier in this map at line ~37 — reused.
  'bookmark': {'zh-Hans': '书签', 'zh-Hant': '書籤', 'en': 'Bookmark'},
  // 2026-05-07 (v11): user feedback -- the previous Chinese
  // rendering "我的标记" (literally "My Markings") collided
  // semantically with "我的高亮" (My Highlights, the colored-
  // highlights page). The Library page actually contains
  // Notes + Bookmarks + Reading Plan, so 标记/markings was
  // misleading. "我的收藏" (My Collection / Saved Items) is
  // broader, matches the Library content, and stays clearly
  // distinct from "我的高亮" (Highlights).
  'library': {'zh-Hans': '我的收藏', 'zh-Hant': '我的收藏', 'en': 'Library'},
  'statistics': {'zh-Hans': '圣经工具', 'zh-Hant': '聖經工具', 'en': 'Bible Tools'},
  'statsOverview':
      {'zh-Hans': '总览', 'zh-Hant': '總覽', 'en': 'Overview'},
  'statsBooks': {'zh-Hans': '书卷', 'zh-Hant': '書卷', 'en': 'Books'},
  // Round 56: replaces the per-book Statistics tab with a
  // Strong's-first lookup tool. Tapping a result opens the full
  // StrongsEntryPage (entry + concordance + word family). Same
  // search vocabulary as the Vocabulary tab — by Strong's #, lemma,
  // transliteration, or gloss in any locale.
  'statsLookup': {
    'zh-Hans': '原文查询',
    'zh-Hant': '原文查詢',
    'en': 'Lookup',
  },
  'statsLookupHint': {
    'zh-Hans': '输入 Strong\'s 编号、原文、音译、字义任一项查找',
    'zh-Hant': '輸入 Strong\'s 編號、原文、音譯、字義任一項查找',
    'en': 'Search by Strong\'s number, lemma, transliteration, or gloss',
  },
  'statsLookupTapHint': {
    'zh-Hans': '点击任一字根查看完整释义、词族、经文索引',
    'zh-Hant': '點擊任一字根查看完整釋義、詞族、經文索引',
    'en': 'Tap any entry for full meaning, word family, and concordance.',
  },
  'statsLookupEmpty': {
    'zh-Hans': '未找到匹配的字根',
    'zh-Hant': '未找到匹配的字根',
    'en': 'No matching entries.',
  },
  // Round 56 (continued — exegesis parity): Lookup tab now leads
  // with a passage-study card so users can start from a verse,
  // matching the in-reader exegesis experience.
  'statsLookupPassageTitle': {
    'zh-Hans': '选经文研读',
    'zh-Hant': '選經文研讀',
    'en': 'Study a passage',
  },
  'statsLookupPassageDesc': {
    'zh-Hans': '选择任一节经文，查看其字字对照原文释经——与阅读时点击经文弹出的完全一致。',
    'zh-Hant': '選擇任一節經文，查看其字字對照原文釋經——與閱讀時點擊經文彈出的完全一致。',
    'en':
        'Pick any verse to see its word-by-word original-language breakdown — same view the reader pops when you tap a verse.',
  },
  'statsLookupPickVerse': {
    'zh-Hans': '选择经文',
    'zh-Hant': '選擇經文',
    'en': 'Pick a verse',
  },
  'statsLookupContinueReading': {
    'zh-Hans': '从阅读继续',
    'zh-Hant': '從閱讀繼續',
    'en': 'Continue from reader',
  },
  'statsLookupStepBook': {
    'zh-Hans': '选择书卷',
    'zh-Hant': '選擇書卷',
    'en': 'Pick a book',
  },
  'statsLookupStepChapter': {
    'zh-Hans': '选择章',
    'zh-Hant': '選擇章',
    'en': 'Pick a chapter',
  },
  'statsLookupStepVerse': {
    'zh-Hans': '选择节',
    'zh-Hant': '選擇節',
    'en': 'Pick a verse',
  },
  'statsLookupNoCurrentReading': {
    'zh-Hans': '请先在阅读页打开一段经文，再回来这里继续。',
    'zh-Hant': '請先在閱讀頁打開一段經文，再回來這裡繼續。',
    'en': 'Open a passage in the reader first to continue here.',
  },
  'statsLookupViewDistribution': {
    'zh-Hans': '在分布表中查看',
    'zh-Hant': '在分布表中查看',
    'en': 'View in Distribution',
  },
  // Round 56: Lookup tab redesign — popular-passages quick picks +
  // features card. Topic descriptors are short factual hints
  // (single phrase) so the user knows what each passage is about
  // before tapping.
  'lookupPopularTitle': {
    'zh-Hans': '近期每日经文',
    'zh-Hant': '近期每日經文',
    'en': 'Recent daily verses',
  },
  'lookupPopularDesc': {
    'zh-Hans': '过去几天的每日经文，点击直接进入释经面板。',
    'zh-Hant': '過去幾天的每日經文，點擊直接進入釋經面板。',
    'en':
        'The past few days of daily verse — tap to study any of them in depth.',
  },
  'lookupPopularEmpty': {
    'zh-Hans': '暂时没有每日经文。',
    'zh-Hant': '暫時沒有每日經文。',
    'en': 'No daily verses available yet.',
  },
  'relativeToday': {
    'zh-Hans': '今天',
    'zh-Hant': '今天',
    'en': 'Today',
  },
  'relativeYesterday': {
    'zh-Hans': '昨天',
    'zh-Hant': '昨天',
    'en': 'Yesterday',
  },
  'relativeDayBeforeYesterday': {
    'zh-Hans': '前天',
    'zh-Hant': '前天',
    'en': '2 days ago',
  },
  'relativeDaysAgo': {
    'zh-Hans': '{days} 天前',
    'zh-Hant': '{days} 天前',
    'en': '{days} days ago',
  },
  // Round 56 (continued — daily verse themes): topical category
  // labels for the 'Recent daily verses' chip row. Keys assigned by
  // themeKeyFor() in lib/services/daily_verse_service.dart based on
  // (book, chapter). Short labels (1-3 chars CJK / 1-2 words EN)
  // chosen so chip text fits on one line at 11pt.
  'verseThemeGeneral': {
    'zh-Hans': '经文',
    'zh-Hant': '經文',
    'en': 'Scripture',
  },
  // ── Famous-chapter themes ────────────────────────────────────
  'verseThemeCreation': {
    'zh-Hans': '创造',
    'zh-Hant': '創造',
    'en': 'Creation',
  },
  'verseThemeFall': {
    'zh-Hans': '堕落',
    'zh-Hant': '墮落',
    'en': 'The Fall',
  },
  'verseThemeCalling': {
    'zh-Hans': '蒙召',
    'zh-Hant': '蒙召',
    'en': 'Calling',
  },
  'verseThemeDeliverance': {
    'zh-Hans': '拯救',
    'zh-Hant': '拯救',
    'en': 'Deliverance',
  },
  'verseThemeCommandments': {
    'zh-Hans': '诫命',
    'zh-Hant': '誡命',
    'en': 'Commandments',
  },
  'verseThemeShema': {
    'zh-Hans': '示玛',
    'zh-Hant': '示瑪',
    'en': 'Shema',
  },
  'verseThemeCourage': {
    'zh-Hans': '刚强壮胆',
    'zh-Hant': '剛強壯膽',
    'en': 'Courage',
  },
  'verseThemeLoyalty': {
    'zh-Hans': '忠贞',
    'zh-Hant': '忠貞',
    'en': 'Loyalty',
  },
  'verseThemeFaith': {
    'zh-Hans': '信心',
    'zh-Hant': '信心',
    'en': 'Faith',
  },
  'verseThemeBlessing': {
    'zh-Hans': '蒙福',
    'zh-Hant': '蒙福',
    'en': 'Blessing',
  },
  'verseThemeRevelation': {
    'zh-Hans': '启示',
    'zh-Hant': '啟示',
    'en': 'Revelation',
  },
  'verseThemeServant': {
    'zh-Hans': '受苦的仆人',
    'zh-Hant': '受苦的僕人',
    'en': 'Servant',
  },
  'verseThemeShepherd': {
    'zh-Hans': '牧人',
    'zh-Hant': '牧人',
    'en': 'Shepherd',
  },
  'verseThemeRefuge': {
    'zh-Hans': '避难所',
    'zh-Hant': '避難所',
    'en': 'Refuge',
  },
  'verseThemeRepentance': {
    'zh-Hans': '悔改',
    'zh-Hant': '悔改',
    'en': 'Repentance',
  },
  'verseThemeWord': {
    'zh-Hans': '神的话',
    'zh-Hant': '神的話',
    'en': "God's Word",
  },
  'verseThemeKnown': {
    'zh-Hans': '被神鉴察',
    'zh-Hant': '被神鑒察',
    'en': 'Known by God',
  },
  'verseThemePraise': {
    'zh-Hans': '赞美',
    'zh-Hant': '讚美',
    'en': 'Praise',
  },
  'verseThemeTrust': {
    'zh-Hans': '信靠',
    'zh-Hant': '信靠',
    'en': 'Trust',
  },
  'verseThemeTime': {
    'zh-Hans': '凡事有时',
    'zh-Hant': '凡事有時',
    'en': 'Times & Seasons',
  },
  'verseThemeMessianic': {
    'zh-Hans': '弥赛亚',
    'zh-Hant': '彌賽亞',
    'en': 'Messianic',
  },
  'verseThemeComfort': {
    'zh-Hans': '安慰',
    'zh-Hant': '安慰',
    'en': 'Comfort',
  },
  'verseThemeInvitation': {
    'zh-Hans': '邀请',
    'zh-Hant': '邀請',
    'en': 'Invitation',
  },
  'verseThemeHope': {
    'zh-Hans': '盼望',
    'zh-Hant': '盼望',
    'en': 'Hope',
  },
  'verseThemeNewCovenant': {
    'zh-Hans': '新约',
    'zh-Hant': '新約',
    'en': 'New Covenant',
  },
  'verseThemeFaithfulness': {
    'zh-Hans': '忠心',
    'zh-Hant': '忠心',
    'en': 'Faithfulness',
  },
  'verseThemeBeatitudes': {
    'zh-Hans': '八福',
    'zh-Hant': '八福',
    'en': 'Beatitudes',
  },
  'verseThemePrayer': {
    'zh-Hans': '祷告',
    'zh-Hant': '禱告',
    'en': 'Prayer',
  },
  'verseThemeNarrowWay': {
    'zh-Hans': '窄路',
    'zh-Hant': '窄路',
    'en': 'Narrow Way',
  },
  'verseThemeCommission': {
    'zh-Hans': '大使命',
    'zh-Hant': '大使命',
    'en': 'Great Commission',
  },
  'verseThemeReturning': {
    'zh-Hans': '回家',
    'zh-Hant': '回家',
    'en': 'Returning',
  },
  'verseThemeResurrection': {
    'zh-Hans': '复活',
    'zh-Hant': '復活',
    'en': 'Resurrection',
  },
  'verseThemeWordIncarnate': {
    'zh-Hans': '道成肉身',
    'zh-Hant': '道成肉身',
    'en': 'The Word',
  },
  'verseThemeBornAgain': {
    'zh-Hans': '重生',
    'zh-Hant': '重生',
    'en': 'Born Again',
  },
  'verseThemeWayTruthLife': {
    'zh-Hans': '道路真理生命',
    'zh-Hant': '道路真理生命',
    'en': 'Way Truth Life',
  },
  'verseThemeAbiding': {
    'zh-Hans': '常在',
    'zh-Hant': '常在',
    'en': 'Abiding',
  },
  'verseThemeUnity': {
    'zh-Hans': '合一',
    'zh-Hant': '合一',
    'en': 'Unity',
  },
  'verseThemeMission': {
    'zh-Hans': '宣教',
    'zh-Hant': '宣教',
    'en': 'Mission',
  },
  'verseThemePentecost': {
    'zh-Hans': '五旬节',
    'zh-Hant': '五旬節',
    'en': 'Pentecost',
  },
  'verseThemeSalvation': {
    'zh-Hans': '救恩',
    'zh-Hant': '救恩',
    'en': 'Salvation',
  },
  'verseThemeReconciliation': {
    'zh-Hans': '和好',
    'zh-Hant': '和好',
    'en': 'Reconciliation',
  },
  'verseThemeAssurance': {
    'zh-Hans': '得胜的确据',
    'zh-Hant': '得勝的確據',
    'en': 'Assurance',
  },
  'verseThemeLivingSacrifice': {
    'zh-Hans': '活祭',
    'zh-Hant': '活祭',
    'en': 'Living Sacrifice',
  },
  'verseThemeLove': {
    'zh-Hans': '爱',
    'zh-Hant': '愛',
    'en': 'Love',
  },
  'verseThemeSpiritFruit': {
    'zh-Hans': '圣灵的果子',
    'zh-Hant': '聖靈的果子',
    'en': 'Fruit of the Spirit',
  },
  'verseThemeGrace': {
    'zh-Hans': '恩典',
    'zh-Hant': '恩典',
    'en': 'Grace',
  },
  'verseThemeArmor': {
    'zh-Hans': '神的全副军装',
    'zh-Hant': '神的全副軍裝',
    'en': 'Armor of God',
  },
  'verseThemeHumility': {
    'zh-Hans': '谦卑',
    'zh-Hant': '謙卑',
    'en': 'Humility',
  },
  'verseThemePeace': {
    'zh-Hans': '平安',
    'zh-Hant': '平安',
    'en': 'Peace',
  },
  'verseThemeNewSelf': {
    'zh-Hans': '新人',
    'zh-Hant': '新人',
    'en': 'New Self',
  },
  'verseThemeContentment': {
    'zh-Hans': '知足',
    'zh-Hant': '知足',
    'en': 'Contentment',
  },
  'verseThemeScripture': {
    'zh-Hans': '圣经的功用',
    'zh-Hant': '聖經的功用',
    'en': 'Scripture',
  },
  'verseThemeRunning': {
    'zh-Hans': '奔跑',
    'zh-Hant': '奔跑',
    'en': 'Running the Race',
  },
  'verseThemeTrials': {
    'zh-Hans': '试炼',
    'zh-Hant': '試煉',
    'en': 'Trials',
  },
  'verseThemeChosen': {
    'zh-Hans': '被拣选',
    'zh-Hant': '被揀選',
    'en': 'Chosen',
  },
  'verseThemeNewCreation': {
    'zh-Hans': '新天新地',
    'zh-Hant': '新天新地',
    'en': 'New Creation',
  },
  'verseThemeReturn': {
    'zh-Hans': '主再来',
    'zh-Hant': '主再來',
    'en': 'Return',
  },
  // ── Book-level themes ────────────────────────────────────────
  'verseThemeBeginnings': {
    'zh-Hans': '起源',
    'zh-Hant': '起源',
    'en': 'Beginnings',
  },
  'verseThemeHoliness': {
    'zh-Hans': '圣洁',
    'zh-Hant': '聖潔',
    'en': 'Holiness',
  },
  'verseThemeWilderness': {
    'zh-Hans': '旷野',
    'zh-Hant': '曠野',
    'en': 'Wilderness',
  },
  'verseThemeCovenant': {
    'zh-Hans': '盟约',
    'zh-Hant': '盟約',
    'en': 'Covenant',
  },
  'verseThemeConquest': {
    'zh-Hans': '得地为业',
    'zh-Hant': '得地為業',
    'en': 'Conquest',
  },
  'verseThemeJudges': {
    'zh-Hans': '士师时代',
    'zh-Hant': '士師時代',
    'en': 'Judges Era',
  },
  'verseThemeKingdom': {
    'zh-Hans': '国度',
    'zh-Hant': '國度',
    'en': 'Kingdom',
  },
  'verseThemeChronicle': {
    'zh-Hans': '史记',
    'zh-Hant': '史記',
    'en': 'Chronicle',
  },
  'verseThemeRebuilding': {
    'zh-Hans': '重建',
    'zh-Hant': '重建',
    'en': 'Rebuilding',
  },
  'verseThemeProvidence': {
    'zh-Hans': '神的护佑',
    'zh-Hant': '神的護佑',
    'en': 'Providence',
  },
  'verseThemeSuffering': {
    'zh-Hans': '苦难',
    'zh-Hant': '苦難',
    'en': 'Suffering',
  },
  'verseThemeWorship': {
    'zh-Hans': '敬拜',
    'zh-Hant': '敬拜',
    'en': 'Worship',
  },
  'verseThemeWisdom': {
    'zh-Hans': '智慧',
    'zh-Hant': '智慧',
    'en': 'Wisdom',
  },
  'verseThemeMeaning': {
    'zh-Hans': '人生意义',
    'zh-Hant': '人生意義',
    'en': 'Meaning',
  },
  'verseThemeProphecy': {
    'zh-Hans': '预言',
    'zh-Hant': '預言',
    'en': 'Prophecy',
  },
  'verseThemeLament': {
    'zh-Hans': '哀歌',
    'zh-Hant': '哀歌',
    'en': 'Lament',
  },
  'verseThemeVision': {
    'zh-Hans': '异象',
    'zh-Hant': '異象',
    'en': 'Vision',
  },
  'verseThemeJustice': {
    'zh-Hans': '公义',
    'zh-Hant': '公義',
    'en': 'Justice',
  },
  'verseThemeMercy': {
    'zh-Hans': '怜悯',
    'zh-Hant': '憐憫',
    'en': 'Mercy',
  },
  'verseThemeLife': {
    'zh-Hans': '生命',
    'zh-Hant': '生命',
    'en': 'Life',
  },
  'verseThemeChurch': {
    'zh-Hans': '教会',
    'zh-Hant': '教會',
    'en': 'Church',
  },
  'verseThemeMinistry': {
    'zh-Hans': '事奉',
    'zh-Hant': '事奉',
    'en': 'Ministry',
  },
  'verseThemeFreedom': {
    'zh-Hans': '自由',
    'zh-Hant': '自由',
    'en': 'Freedom',
  },
  'verseThemeJoy': {
    'zh-Hans': '喜乐',
    'zh-Hant': '喜樂',
    'en': 'Joy',
  },
  'verseThemeChrist': {
    'zh-Hans': '基督',
    'zh-Hant': '基督',
    'en': 'Christ',
  },
  'verseThemePastoral': {
    'zh-Hans': '牧养',
    'zh-Hant': '牧養',
    'en': 'Pastoral',
  },
  'verseThemeForgiveness': {
    'zh-Hans': '饶恕',
    'zh-Hant': '饒恕',
    'en': 'Forgiveness',
  },
  'verseThemeLiving': {
    'zh-Hans': '活出信仰',
    'zh-Hant': '活出信仰',
    'en': 'Living Faith',
  },
  'verseThemePromise': {
    'zh-Hans': '应许',
    'zh-Hant': '應許',
    'en': 'Promise',
  },
  'verseThemeTruth': {
    'zh-Hans': '真理',
    'zh-Hant': '真理',
    'en': 'Truth',
  },
  'verseThemeContending': {
    'zh-Hans': '争辩真道',
    'zh-Hant': '爭辯真道',
    'en': 'Contending',
  },
  'verseThemeFinalHope': {
    'zh-Hans': '终极盼望',
    'zh-Hant': '終極盼望',
    'en': 'Final Hope',
  },
  // Round 56 (continued — bible-languages card): replaces the
  // old stat-block grid in the Overview tab. Three source
  // languages with role + sections + background.
  'languagesCardTitle': {
    'zh-Hans': '圣经的原文',
    'zh-Hant': '聖經的原文',
    'en': 'Original languages of the Bible',
  },
  'languagesCardSubtitle': {
    'zh-Hans': '圣经原本由三种语言写成 —— 看看每一种各自承担哪些经文。',
    'zh-Hant': '聖經原本由三種語言寫成 —— 看看每一種各自承擔哪些經文。',
    'en':
        'The three source languages and where each appears in the canon.',
  },
  'languageWordCount': {
    'zh-Hans': '{n} 词',
    'zh-Hant': '{n} 詞',
    'en': '{n} words',
  },
  'languageLemmaCount': {
    'zh-Hans': '{n} 词条',
    'zh-Hant': '{n} 詞條',
    'en': '{n} lemmas',
  },
  // Hebrew
  'languageHebrewName': {
    'zh-Hans': '希伯来文',
    'zh-Hant': '希伯來文',
    'en': 'Hebrew',
  },
  'languageHebrewRole': {
    'zh-Hans': '旧约绝大部分',
    'zh-Hant': '舊約絕大部分',
    'en': 'Most of the Old Testament',
  },
  'languageHebrewSections': {
    'zh-Hans':
        '旧约 39 卷的绝大部分 —— 摩西五经、历史书、诗歌智慧书、绝大多数先知书。',
    'zh-Hant':
        '舊約 39 卷的絕大部分 —— 摩西五經、歷史書、詩歌智慧書、絕大多數先知書。',
    'en':
        'Nearly all 39 books of the Old Testament — Pentateuch, histories, poetry / wisdom, and almost the entire prophetic corpus.',
  },
  'languageHebrewBackground': {
    'zh-Hans':
        '西北闪族语系，22 个辅音字母，从右向左书写。马所拉抄本所采用的元音点系统是中古时期 (主后 7-10 世纪) 才加入的；圣经成书时只写辅音。',
    'zh-Hant':
        '西北閃族語系，22 個輔音字母，從右向左書寫。馬所拉抄本所採用的元音點系統是中古時期 (主後 7-10 世紀) 才加入的；聖經成書時只寫輔音。',
    'en':
        'Northwest Semitic language with a 22-letter consonantal alphabet, read right-to-left. The vowel-pointing system in the Masoretic manuscripts was a much later addition (7th–10th centuries AD) — when Scripture was first written, only the consonants appeared on the page.',
  },
  // Aramaic
  'languageAramaicName': {
    'zh-Hans': '亚兰文',
    'zh-Hant': '亞蘭文',
    'en': 'Aramaic',
  },
  'languageAramaicRole': {
    'zh-Hans': '旧约若干段落 + 新约几处引文',
    'zh-Hant': '舊約若干段落 + 新約幾處引文',
    'en': 'Pockets of the Old Testament + a few NT quotations',
  },
  'languageAramaicSections': {
    'zh-Hans':
        '但以理 2:4b–7:28、以斯拉 4:8–6:18 与 7:12–26、创世记 31:47 (一处地名)、耶利米书 10:11 (一节)。新约中保留了几句亚兰文原文：「亚巴 父啊」(可 14:36)、「以利以利拉马撒巴各大尼」(可 15:34)、「大利大古米」(可 5:41)、「以法大」(可 7:34)、「玛拉那他」(林前 16:22)。',
    'zh-Hant':
        '但以理 2:4b–7:28、以斯拉 4:8–6:18 與 7:12–26、創世記 31:47 (一處地名)、耶利米書 10:11 (一節)。新約中保留了幾句亞蘭文原文：「亞巴 父啊」(可 14:36)、「以利以利拉馬撒巴各大尼」(可 15:34)、「大利大古米」(可 5:41)、「以法大」(可 7:34)、「瑪拉那他」(林前 16:22)。',
    'en':
        'Daniel 2:4b–7:28, Ezra 4:8–6:18 and 7:12–26, Genesis 31:47 (a place name), Jeremiah 10:11 (one verse). The New Testament preserves several Aramaic phrases on the lips of Jesus and the early church: "abba" (Mark 14:36), "eloi eloi lema sabachthani" (Mark 15:34), "talitha koum" (Mark 5:41), "ephphatha" (Mark 7:34), and "maranatha" (1 Cor 16:22).',
  },
  'languageAramaicBackground': {
    'zh-Hans':
        '与希伯来文同属西北闪族语系，是希伯来文的近亲。亚述、巴比伦、波斯帝国先后扩张后，亚兰文成为近东的通用语，被掳归回时期的犹太人多以亚兰文为日常语言；耶稣时代的加利利与犹太地仍以亚兰文交谈。',
    'zh-Hant':
        '與希伯來文同屬西北閃族語系，是希伯來文的近親。亞述、巴比倫、波斯帝國先後擴張後，亞蘭文成為近東的通用語，被擄歸回時期的猶太人多以亞蘭文為日常語言；耶穌時代的加利利與猶太地仍以亞蘭文交談。',
    'en':
        'Closely related to Hebrew (same Northwest Semitic family). After the Assyrian, Babylonian, and Persian empires successively dominated the region, Aramaic became the everyday lingua franca of the Near East. Returning exiles spoke it as their first language, and it was still the conversational tongue of Galilee and Judea in Jesus\' day.',
  },
  // Greek
  'languageGreekName': {
    'zh-Hans': '希腊文',
    'zh-Hant': '希臘文',
    'en': 'Greek',
  },
  'languageGreekRole': {
    'zh-Hans': '新约全书 + 七十士译本',
    'zh-Hant': '新約全書 + 七十士譯本',
    'en': 'All of the New Testament + LXX',
  },
  'languageGreekSections': {
    'zh-Hans':
        '新约 27 卷全部用希腊文写成 —— 福音书、使徒行传、保罗书信、其他书信、启示录。此外旧约的「七十士译本」(LXX) 也是希腊文，主前 3-2 世纪在亚历山大城翻译完成，是新约作者引用旧约时最常依据的版本。',
    'zh-Hant':
        '新約 27 卷全部用希臘文寫成 —— 福音書、使徒行傳、保羅書信、其他書信、啟示錄。此外舊約的「七十士譯本」(LXX) 也是希臘文，主前 3-2 世紀在亞歷山大城翻譯完成，是新約作者引用舊約時最常依據的版本。',
    'en':
        'All 27 books of the New Testament — Gospels, Acts, Pauline epistles, the catholic letters, and Revelation. Plus the Septuagint (LXX), the Greek translation of the Hebrew Old Testament completed in Alexandria in the 3rd–2nd century BC and the version most often quoted when NT authors cite the OT.',
  },
  'languageGreekBackground': {
    'zh-Hans':
        '通用希腊文 (Koine，「平常的」)，亚历山大大帝东征后，整个地中海与近东世界的共通语言。新约作者刻意采用这种百姓都能听懂的口语形式，而不是雅典文人的古典希腊文，让福音从市井走向万民。',
    'zh-Hant':
        '通用希臘文 (Koine，「平常的」)，亞歷山大大帝東征後，整個地中海與近東世界的共通語言。新約作者刻意採用這種百姓都能聽懂的口語形式，而不是雅典文人的古典希臘文，讓福音從市井走向萬民。',
    'en':
        'Koine ("common") Greek, the everyday register of the Hellenistic Mediterranean after Alexander the Great\'s conquests. The NT authors deliberately wrote in this accessible form — the Greek of the marketplace — rather than the polished Attic of classical literature, so the gospel could travel through ordinary readers to the ends of the empire.',
  },
  // Round 56 (continued — Aramaic highlight): badge label rendered on
  // word chips inside the OriginalsSheet for words detected as
  // Aramaic. Kept short (a single character couplet in Chinese) so it
  // fits inside the 56–140 px chip width without wrapping.
  'aramaicWordBadge': {
    'zh-Hans': '亚兰文',
    'zh-Hant': '亞蘭文',
    'en': 'Aramaic',
  },
  // Round 56 (continued — Aramaic copy): tooltip + toast for the
  // copy-list button on the Aramaic passages sheet.
  'aramCopyTooltip': {
    'zh-Hans': '复制亚兰文经文列表',
    'zh-Hant': '複製亞蘭文經文列表',
    'en': 'Copy Aramaic passage list',
  },
  'aramCopiedToast': {
    'zh-Hans': '亚兰文经文列表已复制',
    'zh-Hant': '亞蘭文經文列表已複製',
    'en': 'Aramaic passage list copied',
  },
  // ── Aramaic sheet (full passage list) ─────────────────────────
  'aramSheetTitle': {
    'zh-Hans': '圣经中的亚兰文',
    'zh-Hant': '聖經中的亞蘭文',
    'en': 'Aramaic in the Bible',
  },
  'aramSheetSubtitle': {
    'zh-Hans': '点击任一段进入释经面板 — 字字对照原文 + Gemini AI 解释。',
    'zh-Hant': '點擊任一段進入釋經面板 — 字字對照原文 + Gemini AI 解釋。',
    'en':
        'Tap any entry to open the verse with word-by-word breakdown and Gemini AI explanation.',
  },
  'aramGroupOt': {
    'zh-Hans': '旧约段落',
    'zh-Hant': '舊約段落',
    'en': 'Old Testament sections',
  },
  'aramGroupNt': {
    'zh-Hans': '新约引用',
    'zh-Hant': '新約引用',
    'en': 'New Testament phrases',
  },
  // OT — full sections written in Aramaic.
  'aramRefGenesis': {
    'zh-Hans': '雅各与拉班立约的亚兰文地名',
    'zh-Hant': '雅各與拉班立約的亞蘭文地名',
    'en': "Jacob and Laban's covenant — Aramaic place name",
  },
  'aramDescGenesis': {
    'zh-Hans':
        '雅各与舅舅拉班立石为约时，拉班用亚兰文称那石堆为「伊迦尔撒哈杜他」(Jegar-sahadutha)，意为「见证之堆」；雅各则用希伯来文称之为「迦累得」(Galeed)。两个名字含义相同 — 圣经特地保留两种语言以反映双方各自的母语。',
    'zh-Hant':
        '雅各與舅舅拉班立石為約時，拉班用亞蘭文稱那石堆為「伊迦爾撒哈杜他」(Jegar-sahadutha)，意為「見證之堆」；雅各則用希伯來文稱之為「迦累得」(Galeed)。兩個名字含義相同 — 聖經特地保留兩種語言以反映雙方各自的母語。',
    'en':
        'When Jacob and his uncle Laban set up a stone witness to their covenant, Laban gives it the Aramaic name "Jegar-sahadutha" ("heap of witness") while Jacob gives it the Hebrew "Galeed" with the same meaning. The text preserves both names — a tiny window into the bilingual world of the patriarchs.',
  },
  'aramRefJeremiah': {
    'zh-Hans': '一节亚兰文：警告偶像必灭亡',
    'zh-Hant': '一節亞蘭文：警告偶像必滅亡',
    'en': 'One Aramaic verse — gods that did not make the heavens',
  },
  'aramDescJeremiah': {
    'zh-Hans':
        '在以希伯来文为主的耶利米书中，第 10 章 11 节突然切换为亚兰文。这是先知给被掳百姓的「应答口诀」 — 当外邦人问他们是否要敬拜列国的偶像时，可以用亚兰文 (当时的国际通用语) 直接回应：「不是创造天地的神必从地上、从天下被除灭。」',
    'zh-Hant':
        '在以希伯來文為主的耶利米書中，第 10 章 11 節突然切換為亞蘭文。這是先知給被擄百姓的「應答口訣」 — 當外邦人問他們是否要敬拜列國的偶像時，可以用亞蘭文 (當時的國際通用語) 直接回應：「不是創造天地的神必從地上、從天下被除滅。」',
    'en':
        'A single Aramaic verse embedded in an otherwise Hebrew chapter. It functions as a ready-made reply for exiles to use against the local idols of their captors — written in Aramaic (the international language of the day) so they could quote it back directly to anyone who pressed them to worship pagan gods.',
  },
  'aramRefDaniel': {
    'zh-Hans': '但以理 2:4–7:28（半本书）',
    'zh-Hant': '但以理 2:4–7:28（半本書）',
    'en': 'Daniel 2:4–7:28 — six chapters in Aramaic',
  },
  'aramDescDaniel': {
    'zh-Hans':
        '从迦勒底术士「用亚兰文对王说话」起 (2:4)，到第 7 章的四兽异象结束，整整六章用亚兰文写成 — 帝国的官方语言。叙事 (尼布甲尼撒梦像、火窑、狮坑) 和异象都集中在这段。1 章、8–12 章则回到希伯来文。',
    'zh-Hant':
        '從迦勒底術士「用亞蘭文對王說話」起 (2:4)，到第 7 章的四獸異象結束，整整六章用亞蘭文寫成 — 帝國的官方語言。敘事 (尼布甲尼撒夢像、火窯、獅坑) 和異象都集中在這段。1 章、8–12 章則回到希伯來文。',
    'en':
        'From the moment the Babylonian wise men reply to the king "in Aramaic" (2:4) through the apocalyptic four-beasts vision of chapter 7, six full chapters of Daniel are written in Aramaic — the language of the empire he served. The famous narratives (Nebuchadnezzar\'s dream, the fiery furnace, the lions\' den) all sit in this section. Chapter 1 and chapters 8–12 return to Hebrew.',
  },
  'aramRefEzraA': {
    'zh-Hans': '以斯拉 4:8–6:18 — 波斯朝廷文书',
    'zh-Hant': '以斯拉 4:8–6:18 — 波斯朝廷文書',
    'en': 'Ezra 4:8–6:18 — Persian court correspondence',
  },
  'aramDescEzraA': {
    'zh-Hans':
        '以斯拉记保留了被掳归回时期，犹太人与波斯朝廷之间往来的奏章、上谕、批文，原文是亚兰文 (帝国的行政通用语)，编者直接照录。重点是关于重建圣殿的辩争 — 反对者上书阻挠，大利乌王查档批准重建。',
    'zh-Hant':
        '以斯拉記保留了被擄歸回時期，猶太人與波斯朝廷之間往來的奏章、上諭、批文，原文是亞蘭文 (帝國的行政通用語)，編者直接照錄。重點是關於重建聖殿的辯爭 — 反對者上書阻撓，大利烏王查檔批准重建。',
    'en':
        'During the post-exile period, official correspondence between the Jewish community and the Persian administration was conducted in Aramaic (the imperial language of record). Ezra preserves the original documents verbatim — including the opponents\' letter trying to halt the rebuilding of the Temple, and Darius\' decree authorising it after the imperial archives were searched.',
  },
  'aramRefEzraB': {
    'zh-Hans': '以斯拉 7:12–26 — 亚达薛西王的谕旨',
    'zh-Hant': '以斯拉 7:12–26 — 亞達薛西王的諭旨',
    'en': "Ezra 7:12–26 — Artaxerxes' decree",
  },
  'aramDescEzraB': {
    'zh-Hans':
        '亚达薛西王亲自颁给以斯拉的谕旨全文，授权他带百姓回耶路撒冷并按照神的律法治理。原文是亚兰文，以斯拉同样照录。这道诏书是以斯拉一切事工的法律根基。',
    'zh-Hant':
        '亞達薛西王親自頒給以斯拉的諭旨全文，授權他帶百姓回耶路撒冷並按照神的律法治理。原文是亞蘭文，以斯拉同樣照錄。這道詔書是以斯拉一切事工的法律根基。',
    'en':
        "The full text of Artaxerxes' decree commissioning Ezra to lead the return to Jerusalem and to govern by the law of his God. Issued in imperial Aramaic and quoted verbatim — the legal charter underwriting Ezra's entire mission.",
  },
  // NT — Aramaic phrases preserved in the Greek text.
  'aramRefRaca': {
    'zh-Hans': '太 5:22 — 「拉加」',
    'zh-Hant': '太 5:22 — 「拉加」',
    'en': 'Matthew 5:22 — "raca"',
  },
  'aramDescRaca': {
    'zh-Hans':
        '亚兰文「ריקא」音译，意为「空头」「废人」 — 当时一种带轻蔑的骂语。耶稣在登山宝训中警告：骂弟兄是拉加的，难免公会的审断。',
    'zh-Hant':
        '亞蘭文「ריקא」音譯，意為「空頭」「廢人」 — 當時一種帶輕蔑的罵語。耶穌在登山寶訓中警告：罵弟兄是拉加的，難免公會的審斷。',
    'en':
        'A transliteration of the Aramaic "raqa" — roughly "empty-head" or "good-for-nothing", a contemptuous slur in Jesus\' day. In the Sermon on the Mount, Jesus warns that calling a brother "raca" makes one liable to the council\'s judgement.',
  },
  'aramRefTalitha': {
    'zh-Hans': '可 5:41 — 「大利大古米」',
    'zh-Hant': '可 5:41 — 「大利大古米」',
    'en': 'Mark 5:41 — "talitha koum"',
  },
  'aramDescTalitha': {
    'zh-Hans':
        '耶稣对睚鲁已死的女儿说的亚兰文原话，意为「闺女，起来」。马可福音保留耶稣的原话，紧接着用希腊文翻译给读者 — 这种「保留 + 翻译」格式是马可福音的标志之一，让读者听见耶稣亲口说的方言。',
    'zh-Hant':
        '耶穌對睚魯已死的女兒說的亞蘭文原話，意為「閨女，起來」。馬可福音保留耶穌的原話，緊接著用希臘文翻譯給讀者 — 這種「保留 + 翻譯」格式是馬可福音的標誌之一，讓讀者聽見耶穌親口說的方言。',
    'en':
        'Jesus\' actual Aramaic words to the dead daughter of Jairus — "Little girl, get up." Mark preserves the Aramaic and immediately glosses it in Greek for his readers; this "quote + translate" pattern is a signature of Mark\'s gospel, letting readers hear Jesus in his own dialect.',
  },
  'aramRefEphphatha': {
    'zh-Hans': '可 7:34 — 「以法大」',
    'zh-Hant': '可 7:34 — 「以法大」',
    'en': 'Mark 7:34 — "ephphatha"',
  },
  'aramDescEphphatha': {
    'zh-Hans':
        '亚兰文，意为「开了吧」。耶稣对一位耳聋舌结的人说话医治时所用的原话。马可同样紧接着翻译给希腊读者听。',
    'zh-Hant':
        '亞蘭文，意為「開了吧」。耶穌對一位耳聾舌結的人說話醫治時所用的原話。馬可同樣緊接著翻譯給希臘讀者聽。',
    'en':
        'Aramaic for "be opened." Spoken by Jesus over a deaf-mute man\'s ears at the moment of healing. Mark again preserves the original word and glosses it in Greek.',
  },
  'aramRefAbba': {
    'zh-Hans': '可 14:36 — 「阿爸，父」',
    'zh-Hant': '可 14:36 — 「阿爸，父」',
    'en': 'Mark 14:36 — "abba"',
  },
  'aramDescAbba': {
    'zh-Hans':
        '亚兰文中孩童对父亲最亲昵的称呼 — 类似「爹」。耶稣在客西马尼园祷告时所用，保罗在罗马书 8:15、加拉太书 4:6 也保留这个亚兰文，强调圣灵使我们能像耶稣那样亲昵地呼喊神为父。',
    'zh-Hant':
        '亞蘭文中孩童對父親最親暱的稱呼 — 類似「爹」。耶穌在客西馬尼園禱告時所用，保羅在羅馬書 8:15、加拉太書 4:6 也保留這個亞蘭文，強調聖靈使我們能像耶穌那樣親暱地呼喊神為父。',
    'en':
        'The Aramaic word a child uses for the father — closer to "papa" than the formal "father". Jesus uses it in Gethsemane, and Paul keeps it in the original in Romans 8:15 and Galatians 4:6, emphasising that the Spirit lets believers call God by the same intimate name Jesus did.',
  },
  'aramRefSabachthani': {
    'zh-Hans': '可 15:34 — 「以利以利拉马撒巴各大尼」',
    'zh-Hant': '可 15:34 — 「以利以利拉馬撒巴各大尼」',
    'en': 'Mark 15:34 — "eloi eloi lema sabachthani"',
  },
  'aramDescSabachthani': {
    'zh-Hans':
        '耶稣在十字架上的呼喊，意为「我的神，我的神，为什么离弃我？」 — 引自诗篇 22:1。马可保留亚兰文版本，马太 27:46 则保留略带希伯来色彩的「以利以利」版本。',
    'zh-Hant':
        '耶穌在十字架上的呼喊，意為「我的神，我的神，為什麼離棄我？」 — 引自詩篇 22:1。馬可保留亞蘭文版本，馬太 27:46 則保留略帶希伯來色彩的「以利以利」版本。',
    'en':
        "Jesus' cry from the cross — \"My God, my God, why have you forsaken me?\" — quoting Psalm 22:1. Mark preserves the Aramaic form (\"eloi\"), Matthew 27:46 the slightly more Hebrew-coloured \"eli eli\".",
  },
  'aramRefMaranatha': {
    'zh-Hans': '林前 16:22 — 「玛拉那他」',
    'zh-Hant': '林前 16:22 — 「瑪拉那他」',
    'en': '1 Corinthians 16:22 — "marana tha"',
  },
  'aramDescMaranatha': {
    'zh-Hans':
        '保罗在哥林多前书末尾用的亚兰文教会问候语 — 「我们的主啊，你来吧」(marana tha)，或拼作 maran atha 时意为「我们的主已经来了」。是早期教会承袭自亚兰语圈的礼仪短语，被保罗原文保留下来。',
    'zh-Hant':
        '保羅在哥林多前書末尾用的亞蘭文教會問候語 — 「我們的主啊，你來吧」(marana tha)，或拼作 maran atha 時意為「我們的主已經來了」。是早期教會承襲自亞蘭語圈的禮儀短語，被保羅原文保留下來。',
    'en':
        "Paul ends 1 Corinthians with this Aramaic liturgical greeting — \"Our Lord, come!\" (marana tha) or, parsed differently, \"Our Lord has come\" (maran atha). An early-church prayer kept in its original Aramaic, a window into the language of the very first Christian gatherings.",
  },
  'lookupTopicCreation': {
    'zh-Hans': '创造',
    'zh-Hant': '創造',
    'en': 'Creation',
  },
  'lookupTopicShepherd': {
    'zh-Hans': '牧人',
    'zh-Hant': '牧人',
    'en': 'The Shepherd',
  },
  'lookupTopicServant': {
    'zh-Hans': '受苦的仆人',
    'zh-Hant': '受苦的僕人',
    'en': 'Suffering Servant',
  },
  'lookupTopicLogos': {
    'zh-Hans': '道',
    'zh-Hant': '道',
    'en': 'The Word',
  },
  'lookupTopicLove': {
    'zh-Hans': '神的爱',
    'zh-Hant': '神的愛',
    'en': "God's love",
  },
  'lookupTopicProvidence': {
    'zh-Hans': '万事互相效力',
    'zh-Hant': '萬事互相效力',
    'en': 'All things together',
  },
  'lookupTopicTriad': {
    'zh-Hans': '信望爱',
    'zh-Hant': '信望愛',
    'en': 'Faith, hope, love',
  },
  'lookupTopicFaith': {
    'zh-Hans': '信',
    'zh-Hant': '信',
    'en': 'Faith',
  },
  'lookupFeaturesTitle': {
    'zh-Hans': '释经面板里你能做什么',
    'zh-Hant': '釋經面板裡你能做什麼',
    'en': 'Inside the exegesis sheet',
  },
  'lookupFeatureWords': {
    'zh-Hans': '字字对照原文（希伯来文 / 希腊文）+ 音译 + 字义',
    'zh-Hant': '字字對照原文（希伯來文 / 希臘文）+ 音譯 + 字義',
    'en':
        'Word-by-word original-language breakdown with transliteration and gloss.',
  },
  'lookupFeatureTap': {
    'zh-Hans': '点击任一原文字，看完整 Strong\'s 词条 — 字义、词源、出现次数',
    'zh-Hant': '點擊任一原文字，看完整 Strong\'s 詞條 — 字義、詞源、出現次數',
    'en':
        "Tap any word for the full Strong's entry — meaning, derivation, occurrence count.",
  },
  'lookupFeatureFamily': {
    'zh-Hans': '词族（亲属词）+ 同义词对比，相关字根一目了然',
    'zh-Hant': '詞族（親屬詞）+ 同義詞對比，相關字根一目了然',
    'en':
        'Word family + synonym comparison — see related lemmas at a glance.',
  },
  'lookupFeatureConcordance': {
    'zh-Hans': '可点击的经文索引（concordance），该字出现的每一节经文一键直达',
    'zh-Hant': '可點擊的經文索引（concordance），該字出現的每一節經文一鍵直達',
    'en':
        'Tappable concordance — every verse the word appears in, one tap to navigate.',
  },
  'lookupFeatureCopy': {
    'zh-Hans': '一键复制原文对照表格，方便讲道预备或笔记',
    'zh-Hant': '一鍵複製原文對照表格，方便講道預備或筆記',
    'en':
        'Copy the interlinear table to clipboard for sermon prep or notes.',
  },
  // Round 56: Word Distribution tab — exposes the
  // WordDistributionTable widget (previously only reachable via
  // tap-a-verse → originals sheet → tap a word → "show
  // distribution") as a standalone tab.
  'statsDistribution': {
    'zh-Hans': '字词分布',
    'zh-Hant': '字詞分布',
    'en': 'Distribution',
  },
  'statsDistributionHint': {
    'zh-Hans': '选择字根查看其在各书卷的分布及词族对照',
    'zh-Hant': '選擇字根查看其在各書卷的分布及詞族對照',
    'en':
        'Pick a Strong\'s word to see its distribution across books, plus word-family + synonym comparison.',
  },
  'statsDistributionPicker': {
    'zh-Hans': '更换字根',
    'zh-Hant': '更換字根',
    'en': 'Change word',
  },
  'statsDistributionEmpty': {
    'zh-Hans': '请选择一个字根',
    'zh-Hant': '請選擇一個字根',
    'en': 'Pick a Strong\'s word to begin.',
  },
  'statsBook': {'zh-Hans': '书卷', 'zh-Hant': '書卷', 'en': 'Book'},
  'statsChapters': {'zh-Hans': '章数', 'zh-Hant': '章數', 'en': 'Chapters'},
  'statsVerses': {'zh-Hans': '节数', 'zh-Hant': '節數', 'en': 'Verses'},
  'statsWords': {'zh-Hans': '字词数', 'zh-Hant': '字詞數', 'en': 'Words'},
  'statsChars':
      {'zh-Hans': '字符数', 'zh-Hant': '字符數', 'en': 'Characters'},
  'statsAvgWordsVerse': {
    'zh-Hans': '平均字词/节',
    'zh-Hant': '平均字詞/節',
    'en': 'Avg w/v',
  },
  'statsTime':
      {'zh-Hans': '阅读时间(分)', 'zh-Hant': '閱讀時間(分)', 'en': 'Time (m)'},
  'statsReadingTime': {
    'zh-Hans': '阅读时间 @ 200 wpm',
    'zh-Hant': '閱讀時間 @ 200 wpm',
    'en': 'Reading time @ 200 wpm',
  },
  'statsLongestShortest': {
    'zh-Hans': '最长与最短书卷',
    'zh-Hant': '最長與最短書卷',
    'en': 'Longest and shortest books',
  },
  'statsLongest': {
    'zh-Hans': '最长(按字词数)',
    'zh-Hant': '最長(按字詞數)',
    'en': 'Longest (by word count)',
  },
  'statsShortest': {
    'zh-Hans': '最短(按字词数)',
    'zh-Hant': '最短(按字詞數)',
    'en': 'Shortest (by word count)',
  },
  'statsVocabulary':
      {'zh-Hans': '词汇', 'zh-Hant': '詞彙', 'en': 'Vocabulary'},
  'statsTopWords': {
    'zh-Hans': '高频字词',
    'zh-Hant': '高頻字詞',
    'en': 'Top words',
  },
  'statsTopWordsSub': {
    'zh-Hans': '出现频次最高的实词(已过滤虚词)。',
    'zh-Hant': '出現頻次最高的實詞(已過濾虛詞)。',
    'en': 'Frequency of content words (function words filtered).',
  },
  'statsHapax': {
    'zh-Hans': '独例字词',
    'zh-Hant': '獨例字詞',
    'en': 'Hapax legomena',
  },
  'statsHapaxSub': {
    'zh-Hans': '在所选范围内仅出现一次的字词。',
    'zh-Hant': '在所選範圍內僅出現一次的字詞。',
    'en': 'Words appearing only once in the selected scope.',
  },
  'statsNoHapax':
      {'zh-Hans': '— 无 —', 'zh-Hant': '— 無 —', 'en': '— none —'},
  'statsScope': {'zh-Hans': '范围:', 'zh-Hant': '範圍:', 'en': 'Scope:'},
  'statsAllCanon': {
    'zh-Hans': '整本圣经',
    'zh-Hant': '整本聖經',
    'en': 'Whole Bible',
  },
  'statsScopeTotal': {
    'zh-Hans': '所选范围总字词数:{n}',
    'zh-Hant': '所選範圍總字詞數:{n}',
    'en': 'Total words in scope: {n}',
  },
  'libraryEmptyNotes': {
    'zh-Hans': '尚无笔记。长按经文,点击笔记图标即可添加。',
    'zh-Hant': '尚無筆記。長按經文,點擊筆記圖標即可添加。',
    'en': 'No notes yet. Long-press a verse and tap the note icon to add one.',
  },
  'libraryEmptyBookmarks': {
    'zh-Hans': '尚无书签。长按经文,点击书签图标即可添加。',
    'zh-Hant': '尚無書籤。長按經文,點擊書籤圖標即可添加。',
    'en': 'No bookmarks yet. Long-press a verse and tap the bookmark icon.',
  },
  'tabNotes': {'zh-Hans': '笔记', 'zh-Hant': '筆記', 'en': 'Notes'},
  'tabBookmarks': {'zh-Hans': '书签', 'zh-Hant': '書籤', 'en': 'Bookmarks'},
  // 2026-05-21 (v1.2.70): Notes scope filter — WeDevote-style.
  'notesScopeAll': {'zh-Hans': '全部', 'zh-Hant': '全部', 'en': 'All'},
  'notesScopeChapter': {
    'zh-Hans': '本章',
    'zh-Hant': '本章',
    'en': 'This chapter',
  },
  'notesScopeBook': {
    'zh-Hans': '本书',
    'zh-Hant': '本書',
    'en': 'This book',
  },
  'notesScopeChapterEmpty': {
    'zh-Hans': '本章还没有笔记。',
    'zh-Hant': '本章還沒有筆記。',
    'en': 'No notes in this chapter yet.',
  },
  'notesScopeBookEmpty': {
    'zh-Hans': '本书还没有笔记。',
    'zh-Hant': '本書還沒有筆記。',
    'en': 'No notes in this book yet.',
  },
  'notesScopeNeedsLocation': {
    'zh-Hans': '请先打开圣经,以查看本章/本书的笔记。',
    'zh-Hant': '請先打開聖經,以查看本章/本書的筆記。',
    'en': 'Open the Bible first to see notes for this chapter / book.',
  },
  // 2026-05-24 (v1.2.91): note editor — optional title field hint.
  // Empty title = falls back to verse reference as the Library
  // tile header (current pre-v1.2.91 behaviour).
  'noteTitleHint': {
    'zh-Hans': '标题（可选）',
    'zh-Hant': '標題（可選）',
    'en': 'Title (optional)',
  },
  // 2026-05-24 (v1.2.91): floating-toast confirmation after the
  // user taps Save or Delete in the note editor. Reassures users
  // who couldn't tell the difference between "tapped Save" and
  // "tapped Cancel/closed the sheet" — both close the sheet, but
  // only the former actually persists.
  'noteSaved': {
    'zh-Hans': '笔记已保存',
    'zh-Hant': '筆記已儲存',
    'en': 'Note saved',
  },
  'noteDeleted': {
    'zh-Hans': '笔记已删除',
    'zh-Hant': '筆記已刪除',
    'en': 'Note deleted',
  },
  // 2026-05-24 (v1.2.91): Library → Notes sort picker. Tooltip + the
  // three sort-mode labels in a PopupMenuButton next to the scope
  // segmented control.
  'notesSortLabel': {'zh-Hans': '排序', 'zh-Hant': '排序', 'en': 'Sort'},
  'notesSortCanonical': {
    'zh-Hans': '按圣经顺序',
    'zh-Hant': '按聖經順序',
    'en': 'Bible order',
  },
  'notesSortRecent': {
    'zh-Hans': '最近更新',
    'zh-Hant': '最近更新',
    'en': 'Recently updated',
  },
  'notesSortOldest': {
    'zh-Hans': '最早创建',
    'zh-Hant': '最早建立',
    'en': 'Oldest first',
  },
  // ── Reading plans (Round 26) ─────────────────────────────────────
  'tabPlan': {'zh-Hans': '读经计划', 'zh-Hant': '讀經計劃', 'en': 'Plan'},
  'readingPlans': {
    'zh-Hans': '读经计划',
    'zh-Hant': '讀經計劃',
    'en': 'Reading Plans',
  },
  'todayReading': {
    'zh-Hans': '今日读经',
    'zh-Hant': '今日讀經',
    'en': 'Today\'s Reading',
  },
  'planDayLabel': {
    'zh-Hans': '第 {day} 天 / 共 {total} 天',
    'zh-Hant': '第 {day} 天 / 共 {total} 天',
    'en': 'Day {day} of {total}',
  },
  'planChooseActive': {
    'zh-Hans': '选择读经计划',
    'zh-Hant': '選擇讀經計劃',
    'en': 'Choose Reading Plan',
  },
  'planNoActive': {
    'zh-Hans': '尚未选择读经计划。',
    'zh-Hant': '尚未選擇讀經計劃。',
    'en': 'No reading plan selected.',
  },
  'planActive': {
    'zh-Hans': '当前计划',
    'zh-Hant': '當前計劃',
    'en': 'Active plan',
  },
  'planStartDate': {
    'zh-Hans': '起始日期',
    'zh-Hant': '起始日期',
    'en': 'Start date',
  },
  'planUseCalendarDate': {
    'zh-Hans': '按日历日期推算',
    'zh-Hant': '按日曆日期推算',
    'en': 'Use calendar date',
  },
  'planUseCalendarDateSub': {
    'zh-Hans': '关闭则按一年中的第几天计算（每年 1 月 1 日重置）。',
    'zh-Hant': '關閉則按一年中的第幾天計算（每年 1 月 1 日重置）。',
    'en': 'When off, day-of-plan follows the day of year (resets every Jan 1).',
  },
  'planResetProgress': {
    'zh-Hans': '重置进度',
    'zh-Hant': '重置進度',
    'en': 'Reset Progress',
  },
  'planResetProgressConfirm': {
    'zh-Hans': '确定要清除所有已完成标记吗？',
    'zh-Hant': '確定要清除所有已完成標記嗎？',
    'en': 'Clear all completion marks for this plan?',
  },
  'planMarkDone': {
    'zh-Hans': '标记为已读',
    'zh-Hant': '標記為已讀',
    'en': 'Mark as done',
  },
  'planMarkUndone': {
    'zh-Hans': '取消已读',
    'zh-Hant': '取消已讀',
    'en': 'Mark as unread',
  },
  'planJumpToToday': {
    'zh-Hans': '跳到今天',
    'zh-Hant': '跳到今天',
    'en': 'Jump to today',
  },
  'planProgress': {
    'zh-Hans': '进度: {done} / {total} ({percent}%)',
    'zh-Hant': '進度: {done} / {total} ({percent}%)',
    'en': 'Progress: {done} / {total} ({percent}%)',
  },
  'planNone': {
    'zh-Hans': '不使用读经计划',
    'zh-Hant': '不使用讀經計劃',
    'en': 'No plan',
  },
  'planLibraryEmpty': {
    'zh-Hans': '尚未选择读经计划。前往「设置」中挑选一份。',
    'zh-Hant': '尚未選擇讀經計劃。前往「設定」中挑選一份。',
    'en': 'No reading plan selected. Pick one from Settings.',
  },
  'planHomeHint': {
    'zh-Hans': '选择一份读经计划，每日内容会显示在此。',
    'zh-Hant': '選擇一份讀經計劃，每日內容會顯示在此。',
    'en': 'Choose a reading plan to see today\'s passages here.',
  },
  'planHomeHintSub': {
    'zh-Hans': '点击进入设置。',
    'zh-Hant': '點擊進入設定。',
    'en': 'Tap to open Settings.',
  },
  'home': {
    'zh-Hans': '主页',
    'zh-Hant': '主頁',
    'en': 'Home',
  },
  'homeRecentBookmarks': {
    'zh-Hans': '最近书签',
    'zh-Hant': '最近書籤',
    'en': 'Recent bookmarks',
  },
  'continueReading': {
    // The hero CTA on the dashboard. Earlier copy was '继续阅读 /
    // Continue reading' which felt generic for a Bible-first app.
    // '读经' is the natural Chinese phrase for "read scripture";
    // 'Read Bible' is the English equivalent — direct, on-brand,
    // and pairs with the book + chapter line below the CTA without
    // sounding redundant ("Continue reading: Genesis 1" vs "Read
    // Bible: Genesis 1").
    'zh-Hans': '读经',
    'zh-Hant': '讀經',
    'en': 'Read Bible',
  },
  // Companion CTA below the Bible "Read Bible" hero — the "pick up
  // where you left off in your last sermon" card. Wording mirrors
  // the existing "继续阅读 / Resume" idiom for tracked content.
  'resumeSermon': {
    'zh-Hans': '继续讲道',
    'zh-Hant': '繼續講道',
    'en': 'Resume sermon',
  },
  'dailyVerse': {
    'zh-Hans': '每日金句',
    'zh-Hant': '每日金句',
    'en': 'Verse of the Day',
  },
  // Shown beneath the daily-verse citation when the verse text was
  // pulled from a fallback Bible (e.g. user is on LJK1, today's
  // verse is OT, we display the CUVS-YHWH text). {version} is the
  // friendly menuLabel of the fallback bundle.
  'dailyVerseFromFallback': {
    'zh-Hans': '本句显示自《{version}》',
    'zh-Hant': '本句顯示自《{version}》',
    'en': 'Shown from {version}',
  },
  // ── Onboarding tour (Round 34) ──────────────────────────────────
  'skip': {'zh-Hans': '跳过', 'zh-Hant': '跳過', 'en': 'Skip'},
  'next': {'zh-Hans': '下一步', 'zh-Hant': '下一步', 'en': 'Next'},
  'getStarted': {
    'zh-Hans': '开始使用',
    'zh-Hant': '開始使用',
    'en': 'Get started',
  },
  // Onboarding tour copy. Bumped for v2 (Round 55) so the tour
  // covers the full app surface — sermons, family tree, timeline,
  // evidence, news, and the new dashboard customization. Original
  // v1 strings (welcome / plans / library / cloud) are kept above
  // for any localizations downstream that might still reference
  // them.
  'onboardWelcomeTitle': {
    'zh-Hans': '欢迎使用 YsWords',
    'zh-Hant': '歡迎使用 YsWords',
    'en': 'Welcome to YsWords',
  },
  'onboardWelcomeBody': {
    'zh-Hans': '双语圣经阅读应用，14 个译本（英文／简体／繁体）。主页的「读经」卡片会带你回到上次离开的位置。',
    'zh-Hant': '雙語聖經閱讀應用，14 個譯本（英文／簡體／繁體）。主頁的「讀經」卡片會帶你回到上次離開的位置。',
    'en':
        'A bilingual Bible reader with 14 translations across English and Chinese. The "Read Bible" card on Home picks up exactly where you left off.',
  },
  'onboardReadTitle': {
    'zh-Hans': '阅读、高亮、研经',
    'zh-Hant': '閱讀、高亮、研經',
    'en': 'Read, highlight, study',
  },
  'onboardReadBody': {
    'zh-Hans': '长按经文可添加彩色高亮、书签和笔记；点击经文引用即可跳转，点击 Strong\'s 字可查原文。顶部搜索覆盖整本圣经。',
    'zh-Hant': '長按經文可添加彩色高亮、書籤和筆記；點擊經文引用即可跳轉，點擊 Strong\'s 字可查原文。頂部搜索覆蓋整本聖經。',
    'en':
        'Long-press a verse for color highlights, bookmarks, and notes. Tap any reference to jump; tap a Strong\'s word for originals. Search the whole Bible from the header.',
  },
  // 2026-05-09 (v1.2.9): user pointed out the v2 tour didn't even
  // mention AI — now central to v1.2.0–v1.2.8 (search by theme,
  // BDAG-style word study, evidence Q&A, BYOK key-test). New slide
  // sits between "Read" and "Sermons" so the natural reading-flow
  // intro leads into "and here's what AI can do on top of it".
  'onboardAiTitle': {
    'zh-Hans': 'AI 研经助手',
    'zh-Hant': 'AI 研經助手',
    'en': 'AI study helpers',
  },
  'onboardAiBody': {
    'zh-Hans': '按主题搜经文（"爱"、"信心"），点希腊文／希伯来文原文看 BDAG 级深度释义，对考古和手稿提具体问题。AI 由 Gemini 驱动——可在 设置 → YsWords AI 粘贴自己的免费密钥（按 Test 验证），用自己的额度跳过共享池。',
    'zh-Hant': '按主題搜經文（「愛」、「信心」），點希臘文／希伯來文原文看 BDAG 級深度釋義，對考古和手稿提具體問題。AI 由 Gemini 驅動——可在 設定 → YsWords AI 貼上自己的免費密鑰（按 Test 驗證），用自己的額度跳過共享池。',
    'en':
        'Search the Bible by theme ("love", "faith"), tap any Greek or Hebrew word for a BDAG-style deep dive, or ask questions about archaeology and manuscripts. Powered by Gemini — paste your own free key in Settings → AI (and tap Test to verify) to skip the shared developer pool.',
  },
  'onboardSermonsTitle': {
    'zh-Hans': '讲道',
    'zh-Hant': '講道',
    'en': 'Sermons',
  },
  'onboardSermonsBody': {
    'zh-Hans': '587 篇解经讲道（英／简／繁）。讲道中的经文引用可弹出小窗预览，无需离开。主页有「继续讲道」卡片显示上次进度。',
    'zh-Hant': '587 篇解經講道（英／簡／繁）。講道中的經文引用可彈出小窗預覽，無需離開。主頁有「繼續講道」卡片顯示上次進度。',
    'en':
        '587 expository sermons in EN / 简 / 繁. Verse refs in the body open a popup so you can peek at scripture without leaving. Home shows a "Resume sermon" card with your progress.',
  },
  'onboardDiscoverTitle': {
    'zh-Hans': '探索工具',
    'zh-Hant': '探索工具',
    'en': 'Discover',
  },
  'onboardDiscoverBody': {
    'zh-Hans': '圣经时间轴（97 个事件）、家谱（277 位人物）、圣经证据（225 项考古／抄本／科学发现），都可在主页打开。',
    'zh-Hant': '聖經時間軸（97 個事件）、家譜（277 位人物）、聖經證據（225 項考古／抄本／科學發現），都可在主頁打開。',
    'en':
        'Bible Timeline (97 events), Family Tree (277 people), and Bible Evidence (225 archaeology / manuscript / science finds) — all reachable from Home.',
  },
  'onboardCustomizeTitle': {
    'zh-Hans': '自定义与同步',
    'zh-Hant': '自訂與同步',
    'en': 'Customize & sync',
  },
  'onboardCustomizeBody': {
    'zh-Hans': '在「设置 → 主页布局」中拖动排序或隐藏任意板块；选择读经计划；用 Google 登录即可在所有设备同步书签、笔记和高亮。',
    'zh-Hant': '在「設定 → 主頁佈局」中拖動排序或隱藏任意板塊；選擇讀經計劃；用 Google 登入即可在所有裝置同步書籤、筆記和高亮。',
    'en':
        'Drag-reorder or hide any block under Settings → Dashboard layout. Pick a reading plan. Sign in with Google to sync bookmarks, notes, and highlights across devices.',
  },
  // 2026-05-10 (v1.2.11): the Customize slide above explicitly
  // pitches Google sign-in for cross-device sync — but the China
  // build skips Firebase entirely (see main.dart line ~109's
  // `if (!kChinaMode)`), so cloud sync is not on the table.
  // Promising it in the tour confused early China-build users
  // who then went looking for the Sign-in button (which v1.2.1
  // had already hidden). The China-only variants below replace
  // the Google-sync sentence with the local-only reality:
  // highlights, notes, bookmarks live on this device.
  'onboardCustomizeTitleChina': {
    'zh-Hans': '自定义',
    'zh-Hant': '自訂',
    'en': 'Customize',
  },
  'onboardCustomizeBodyChina': {
    'zh-Hans': '在「设置 → 主页布局」中拖动排序或隐藏任意板块。选择读经计划。中国版的所有标记、笔记和收藏都保存在本设备。',
    'zh-Hant': '在「設定 → 主頁佈局」中拖動排序或隱藏任意板塊。選擇讀經計劃。中國版的所有標記、筆記和收藏都保存在本裝置。',
    'en':
        'Drag-reorder or hide any block under Settings → Dashboard layout. Pick a reading plan. In the China build, highlights, notes, and bookmarks all stay on this device.',
  },

  // Legacy v1 onboarding strings — kept for backward compatibility
  // with any external translation file that still references these
  // keys. The active tour uses the v2 keys above.
  'onboardPlansTitle': {
    'zh-Hans': '读经计划',
    'zh-Hant': '讀經計劃',
    'en': 'Reading plans',
  },
  'onboardPlansBody': {
    'zh-Hans': '在「设置」中选择一年、按历史顺序或麦琴计划——今日内容会自动显示在主页。',
    'zh-Hant': '在「設定」中選擇一年、按歷史順序或麥琴計劃——今日內容會自動顯示在主頁。',
    'en':
        'Pick a one-year, chronological, or McCheyne plan in Settings — today\'s readings show on this Home page automatically.',
  },
  'onboardLibraryTitle': {
    'zh-Hans': '笔记与书签',
    'zh-Hant': '筆記與書籤',
    'en': 'Notes & bookmarks',
  },
  'onboardLibraryBody': {
    'zh-Hans': '长按经文可添加笔记、书签或彩色高亮，可在「我的收藏」和「高亮」中查找。',
    'zh-Hant': '長按經文可添加筆記、書籤或彩色高亮，可在「我的收藏」和「高亮」中查找。',
    'en':
        'Long-press a verse to add a note, bookmark, or color highlight. Find them all in Library and Highlights.',
  },
  'onboardCloudTitle': {
    'zh-Hans': '同步与账号',
    'zh-Hant': '同步與帳號',
    'en': 'Sync & profiles',
  },
  'onboardCloudBody': {
    'zh-Hans': '使用 Google 登录可在所有设备同步；也可使用本地账号仅保存于此设备。',
    'zh-Hant': '使用 Google 登入可在所有裝置同步；也可使用本地帳號僅保存於此裝置。',
    'en':
        'Sign in with Google to sync everything across devices, or use a local profile to keep things on this device only.',
  },
  // ── Settings section headers (Round 34) ─────────────────────────
  'settingsSectionDisplay': {
    'zh-Hans': '显示',
    'zh-Hant': '顯示',
    'en': 'Display',
  },
  'settingsSectionReading': {
    'zh-Hans': '阅读',
    'zh-Hant': '閱讀',
    'en': 'Reading',
  },
  'settingsSectionApp': {
    'zh-Hans': '应用',
    'zh-Hant': '應用',
    'en': 'App',
  },
  'settingsSectionAccount': {
    'zh-Hans': '账号',
    'zh-Hant': '帳號',
    'en': 'Account',
  },
  'settingsSectionPlan': {
    'zh-Hans': '读经计划',
    'zh-Hant': '讀經計劃',
    'en': 'Reading plans',
  },
  'settingsSectionDashboard': {
    // Renamed in Round 55: this section now controls reorder + per-
    // section visibility (the old single "show/hide" switches still
    // work via legacy keys; the new card adds drag-handles and
    // covers every block, not just the three discoverable ones).
    'zh-Hans': '主页布局',
    'zh-Hant': '主頁佈局',
    'en': 'Dashboard layout',
  },
  'dashboardLayoutHint': {
    'zh-Hans': '拖动手柄调整顺序；关闭开关即可隐藏该板块。',
    'zh-Hant': '拖動手柄調整順序；關閉開關即可隱藏該板塊。',
    'en': 'Drag the handle to reorder. Toggle a row off to hide that block.',
  },
  'dashboardLayoutResetConfirm': {
    'zh-Hans': '是否恢复默认顺序，并重新打开所有板块？',
    'zh-Hant': '是否恢復預設順序，並重新打開所有板塊？',
    'en':
        'Restore the original section order and turn every block back on?',
  },
  'resetToDefault': {
    'zh-Hans': '恢复默认',
    'zh-Hant': '恢復預設',
    'en': 'Reset to default',
  },
  // ── App-level reset (Round 55) ──────────────────────────────────
  // Used by Settings → About → "Reset settings". Wipes visual /
  // preference state back to defaults but preserves user content
  // (bookmarks, notes, highlights, profile, language).
  'resetSettings': {
    'zh-Hans': '恢复设置',
    'zh-Hant': '恢復設定',
    'en': 'Reset settings',
  },
  'resetSettingsConfirm': {
    'zh-Hans': '将恢复字体、主题、颜色、主页布局等所有偏好设置。您的书签、笔记、高亮、账号和语言不会改变。是否继续？',
    'zh-Hant': '將恢復字體、主題、顏色、主頁佈局等所有偏好設定。您的書籤、筆記、高亮、帳號和語言不會改變。是否繼續？',
    'en':
        'This restores fonts, theme, color, dashboard layout, and other preferences. Your bookmarks, notes, highlights, profile, and language stay the same. Continue?',
  },
  'resetSettingsNote': {
    'zh-Hans': '恢复字体、主题、颜色、主页布局等偏好设置。您的书签、笔记、高亮、账号和语言不会改变。',
    'zh-Hant': '恢復字體、主題、顏色、主頁佈局等偏好設定。您的書籤、筆記、高亮、帳號和語言不會改變。',
    'en':
        'Restores fonts, theme, color, dashboard layout, and other preferences. Your bookmarks, notes, highlights, profile, and language are kept.',
  },
  'resetSettingsDone': {
    'zh-Hans': '设置已恢复默认。',
    'zh-Hant': '設定已恢復預設。',
    'en': 'Settings restored to defaults.',
  },
  'showTourAgain': {
    'zh-Hans': '重新查看导览',
    'zh-Hant': '重新查看導覽',
    'en': 'Show tour again',
  },
  // ── Offline Pack (Round 56) ─────────────────────────────────────
  // Bulk pre-fetch UI in Settings → About. Lets the user download
  // every Bible / sermon / tool asset into the browser's HTTP +
  // service-worker cache so the app launches instantly + works
  // without network. Three categories (bibles / sermons / tools)
  // each user-toggleable.
  'offlinePackTitle': {
    'zh-Hans': '离线包',
    'zh-Hant': '離線包',
    'en': 'Offline pack',
  },
  'offlinePackHint': {
    'zh-Hans': '预先下载圣经、讲道与工具数据，应用立即打开，断网也能用。',
    'zh-Hant': '預先下載聖經、講道與工具資料，應用立即打開，斷網也能用。',
    'en':
        'Pre-download Bibles, sermons, and tools so the app launches instantly and works without network.',
  },
  'offlinePackBibles': {
    'zh-Hans': '圣经译本（共 13 部）',
    'zh-Hant': '聖經譯本（共 13 部）',
    'en': 'Bibles (13 translations)',
  },
  'offlinePackSermons': {
    'zh-Hans': '张熙和牧师讲道（587 篇 ×3 语）',
    'zh-Hant': '張熙和牧師講道（587 篇 ×3 語）',
    'en': "Pastor Eric's sermons (587 × 3 langs)",
  },
  'offlinePackTools': {
    'zh-Hans': '研经工具（家谱 / 时间轴 / 证据 / 互参 / 读经计划等）',
    'zh-Hant': '研經工具（家譜 / 時間軸 / 證據 / 互參 / 讀經計劃等）',
    'en': 'Tools & references (tree / timeline / evidence / refs / plans)',
  },
  // Added 2026-05 — exegesis word study + Bible-history maps were
  // previously not pre-cached, so they silently failed offline.
  'offlinePackOriginals': {
    'zh-Hans': '原文研究（Strong\'s 编号 + 希伯来 / 希腊原文逐字对照）',
    'zh-Hant': '原文研究（Strong\'s 編號 + 希伯來 / 希臘原文逐字對照）',
    'en': "Originals (Strong's lexicon + Hebrew/Greek interlinear)",
  },
  'offlinePackMaps': {
    'zh-Hans': '圣经历史地图（55 张图）',
    'zh-Hant': '聖經歷史地圖（55 張圖）',
    'en': 'Bible-history maps (55 images)',
  },
  // ── AI BYOK + Drive sync (2026-05-06) ────────────────────────
  'settingsSectionAi': {
    'zh-Hans': 'YsWords AI 释义',
    'zh-Hant': 'YsWords AI 釋義',
    'en': 'YsWords AI',
  },
  'aboutSectionAi': {
    'zh-Hans': 'YsWords AI（高级 · 可选）',
    'zh-Hant': 'YsWords AI（進階 · 可選）',
    'en': 'YsWords AI (advanced · optional)',
  },
  'cloudDiagSection': {
    'zh-Hans': '云端配置自检（开发者 / 诊断用）',
    'zh-Hant': '雲端配置自檢（開發者 / 診斷用）',
    'en': 'Cloud setup status (developer / diagnostic)',
  },
  'cloudDiagTitle': {
    'zh-Hans': '云端配置自检',
    'zh-Hant': '雲端配置自檢',
    'en': 'Cloud setup diagnostic',
  },
  'cloudDiagBody': {
    'zh-Hans': '自动检测 Firebase Auth、Google Drive 同步、Gemini AI 是否正常。'
        '一般用户无需启用任何 API——只有应用作者需要在 Google Cloud Console 启用一次。'
        '若有问题，应用仍能在降级模式下使用（同步退化为本地保存，AI 显示"不可用"）。',
    'zh-Hant': '自動檢測 Firebase Auth、Google Drive 同步、Gemini AI 是否正常。'
        '一般使用者無需啟用任何 API——只有應用作者需要在 Google Cloud Console 啟用一次。'
        '若有問題，應用仍能在降級模式下使用（同步退化為本地保存，AI 顯示「不可用」）。',
    'en':
        'Probes Firebase Auth, Drive sync, and the AI proxy. End '
            'users never need to enable anything — these are '
            'developer-side checks for the YsWords project. The app '
            'keeps working in degraded mode either way (sync goes '
            'local-only, AI shows "not available").',
  },
  'cloudDiagRun': {
    'zh-Hans': '运行检查',
    'zh-Hant': '執行檢查',
    'en': 'Run check',
  },
  'cloudDiagRerun': {
    'zh-Hans': '重新检查',
    'zh-Hant': '重新檢查',
    'en': 'Re-run',
  },
  // Localised "Open …" labels reused by the diagnostic's fix-link
  // buttons so they match the wording on the setup walkthrough.
  'setupStep1OpenLabel': {
    'zh-Hans': '启用 Drive API',
    'zh-Hant': '啟用 Drive API',
    'en': 'Enable Drive API',
  },
  'setupStep3OpenLabel': {
    'zh-Hans': '打开 OAuth 同意屏幕',
    'zh-Hant': '打開 OAuth 同意畫面',
    'en': 'Open OAuth consent screen',
  },
  'setupStep5OpenLabel': {
    'zh-Hans': '打开 Netlify 环境变量',
    'zh-Hant': '打開 Netlify 環境變數',
    'en': 'Open Netlify env vars',
  },
  // ── Setup walkthrough — info popups (2026-05-06) ──────────────
  'setupDetailTooltip': {
    'zh-Hans': '为什么要做这一步？',
    'zh-Hant': '為什麼要做這一步？',
    'en': 'Why this step?',
  },
  'setupDetailDialogClose': {
    'zh-Hans': '我明白了',
    'zh-Hant': '我明白了',
    'en': 'Got it',
  },
  'setupStep1Detail': {
    'zh-Hans': '【作用】在 Firebase Console 中启用 Realtime Database。\n\n'
        '【为什么需要】同步功能（高亮、书签、笔记、读经计划）将每个用户的数据'
        '存放在 RTDB 的 users/{uid}/sync 路径下。RTDB 是 Firebase 的"实时云数据库"——'
        '与 Firestore 是不同的产品，使用 WebSocket 传输（更可靠地穿透防火墙），'
        '而且不需要任何额外的 OAuth 范围。\n\n'
        '【不启用会怎样】用户登录后同步会失败，错误码 database-disabled。\n\n'
        '【是否影响最终用户】不影响。一次性的项目级别设置。'
        '点击 "Create Database" 然后选择 "United States (us-central1)" 区域和 "Start in locked mode"。'
        '步骤 3 设置安全规则后才能真正读写。',
    'zh-Hant': '【作用】在 Firebase Console 中啟用 Realtime Database。\n\n'
        '【為什麼需要】同步功能（標亮、書籤、筆記、讀經計劃）將每個使用者的資料'
        '存放在 RTDB 的 users/{uid}/sync 路徑下。RTDB 是 Firebase 的「即時雲資料庫」——'
        '與 Firestore 是不同的產品，使用 WebSocket 傳輸（更可靠地穿透防火牆），'
        '而且不需要任何額外的 OAuth 範圍。\n\n'
        '【不啟用會怎樣】使用者登入後同步會失敗，錯誤碼 database-disabled。\n\n'
        '【是否影響最終使用者】不影響。一次性的專案級別設定。'
        '點擊「Create Database」然後選擇「United States (us-central1)」區域和「Start in locked mode」。'
        '步驟 3 設定安全規則後才能真正讀寫。',
    'en':
        'WHAT: Enables Firebase Realtime Database in the project. '
            'It\'s a separate product from Firestore — uses '
            'WebSocket transport (works through more firewalls) and '
            'doesn\'t need any extra OAuth scope at sign-in.\n\n'
            "WHY: Sync (highlights / bookmarks / notes / reading-plan "
            "progress) stores each user's data at "
            "users/{uid}/sync.\n\n"
            "WHAT BREAKS WITHOUT IT: Sign-in works but sync fails "
            "with code `database-disabled`. AI features still work.\n\n"
            "DOES IT AFFECT END USERS: No — one-time project-level "
            'setting. Click "Create Database" → pick a region (US '
            'is fine) → "Start in locked mode" (Step 3 opens up '
            'rules afterwards).',
  },
  'setupStep2Detail': {
    'zh-Hans': '【作用】在 ysword 项目里启用 Generative Language API（即 Gemini API）。\n\n'
        '【为什么需要】Netlify 函数（aiExplainWord、aiSearch）通过 Gemini 提供 AI 释义和 AI 搜索。'
        '即使你已经有了 GEMINI_API_KEY 环境变量，如果该 API 在密钥所属项目中没启用，调用就会失败。\n\n'
        '【不启用会怎样】AI 解释和 AI 搜索功能会显示"暂时不可用"消息。其他功能不受影响。\n\n'
        '【是否影响最终用户】不影响。这是项目级别的设置。',
    'zh-Hant': '【作用】在 ysword 專案裡啟用 Generative Language API（即 Gemini API）。\n\n'
        '【為什麼需要】Netlify 函數（aiExplainWord、aiSearch）透過 Gemini 提供 AI 釋義和 AI 搜尋。'
        '即使你已經有了 GEMINI_API_KEY 環境變數，如果該 API 在金鑰所屬專案中沒啟用，呼叫就會失敗。\n\n'
        '【不啟用會怎樣】AI 釋義和 AI 搜尋功能會顯示「暫時不可用」訊息。其他功能不受影響。\n\n'
        '【是否影響最終使用者】不影響。這是專案級別的設定。',
    'en':
        'WHAT: Enables the Generative Language API (the Gemini API) '
            'in the project.\n\n'
            "WHY: The Netlify functions (aiExplainWord, aiSearch) "
            "call Gemini for AI word explanations + AI search. Even "
            "if GEMINI_API_KEY is set in env vars, the call fails "
            "if the API isn't enabled in the project that owns the "
            'key.\n\n'
            "WHAT BREAKS WITHOUT IT: AI explanation and AI search "
            'show "not available right now" messages. Other '
            'features unaffected.\n\n'
            "DOES IT AFFECT END USERS: No. Project-level setting.",
  },
  'setupStep3Detail': {
    'zh-Hans': '【作用】配置 Realtime Database 的安全规则，允许已登录用户读写自己的数据。\n\n'
        '【为什么需要】Firebase 启用 RTDB 后默认规则是 ".read": false / ".write": false——'
        '完全锁死。必须开放给已登录用户才能同步。\n\n'
        '【推荐规则】只允许用户读写自己 uid 下的路径：\n'
        '{\n'
        '  "rules": {\n'
        '    "users": {\n'
        '      "\$uid": {\n'
        '        ".read": "auth != null && auth.uid == \$uid",\n'
        '        ".write": "auth != null && auth.uid == \$uid"\n'
        '      }\n'
        '    }\n'
        '  }\n'
        '}\n\n'
        '【不设置会怎样】所有同步操作返回 permission_denied 错误。\n\n'
        '【是否影响最终用户】不影响。一次性的服务端设置。',
    'zh-Hant': '【作用】配置 Realtime Database 的安全規則，允許已登入使用者讀寫自己的資料。\n\n'
        '【為什麼需要】Firebase 啟用 RTDB 後預設規則是 ".read": false / ".write": false——'
        '完全鎖死。必須開放給已登入使用者才能同步。\n\n'
        '【推薦規則】只允許使用者讀寫自己 uid 下的路徑：\n'
        '{\n'
        '  "rules": {\n'
        '    "users": {\n'
        '      "\$uid": {\n'
        '        ".read": "auth != null && auth.uid == \$uid",\n'
        '        ".write": "auth != null && auth.uid == \$uid"\n'
        '      }\n'
        '    }\n'
        '  }\n'
        '}\n\n'
        '【不設定會怎樣】所有同步操作回傳 permission_denied 錯誤。\n\n'
        '【是否影響最終使用者】不影響。一次性的伺服器端設定。',
    'en':
        'WHAT: Configures Realtime Database security rules so '
            'authenticated users can read & write their own data.\n\n'
            "WHY: Firebase ships RTDB with default rules denying "
            "everything (.read: false / .write: false). Sync needs "
            "the path users/<uid>/* opened up to that user only.\n\n"
            'RECOMMENDED RULES (paste into the Rules tab):\n'
            '{\n'
            '  "rules": {\n'
            '    "users": {\n'
            '      "\$uid": {\n'
            '        ".read": "auth != null && auth.uid == \$uid",\n'
            '        ".write": "auth != null && auth.uid == \$uid"\n'
            '      }\n'
            '    }\n'
            '  }\n'
            '}\n\n'
            "WHAT BREAKS WITHOUT IT: Every sync operation returns "
            '`permission_denied`. The diagnostic surfaces this with '
            "an 'Open RTDB rules' fix-link.\n\n"
            "DOES IT AFFECT END USERS: No — one-time server-side "
            'setting.',
  },
  'setupStep4Detail': {
    'zh-Hans': '【作用】把 yswords.netlify.app 加到 Firebase Auth 的"已授权域名"列表。\n\n'
        '【为什么需要】Firebase Auth 出于安全考虑，会拒绝任何不在白名单中的来源发起的登录请求。\n\n'
        '【不启用会怎样】登录请求会失败，错误码 auth/unauthorized-domain。\n\n'
        '【是否影响最终用户】不影响。这是 Firebase 项目级别的设置。'
        '如果将来部署到新域名（比如自定义域名 yswords.com），也要把那个域名加进来。',
    'zh-Hant': '【作用】把 yswords.netlify.app 加到 Firebase Auth 的「已授權網域」清單。\n\n'
        '【為什麼需要】Firebase Auth 出於安全考量，會拒絕任何不在白名單中的來源發起的登入請求。\n\n'
        '【不啟用會怎樣】登入請求會失敗，錯誤碼 auth/unauthorized-domain。\n\n'
        '【是否影響最終使用者】不影響。這是 Firebase 專案級別的設定。'
        '如果將來部署到新網域（比如自訂網域 yswords.com），也要把那個網域加進來。',
    'en':
        'WHAT: Adds yswords.netlify.app to the Firebase Auth '
            '"Authorized domains" allow-list.\n\n'
            'WHY: Firebase Auth rejects any sign-in attempt from a '
            "domain not on this list, as a security measure.\n\n"
            "WHAT BREAKS WITHOUT IT: Sign-in fails with code "
            "`auth/unauthorized-domain`.\n\n"
            "DOES IT AFFECT END USERS: No. Firebase-project-level "
            'setting. If you ever deploy to a new domain (custom '
            "domain like yswords.com), add that domain here too.",
  },
  'setupStep5Detail': {
    'zh-Hans': '【作用】在 Netlify 仪表盘的环境变量中设置 GEMINI_API_KEY。\n\n'
        '【为什么需要】Netlify 函数（aiExplainWord、aiSearch）需要这个密钥来认证 Gemini API 调用。'
        '密钥从 https://aistudio.google.com/apikey 免费获取。\n\n'
        '【可选】可以最多设置 9 个备用密钥（GEMINI_API_KEY_BACKUP_2..9）'
        '形成密钥链，主密钥额度耗尽时自动切换到备用密钥，提高可用性。\n\n'
        '【不设置会怎样】AI 功能调用时函数会返回 503 错误，提示密钥未配置。\n\n'
        '【注意】这是 Netlify 环境变量，不是 Google Cloud 设置。修改后需要重新部署生效。',
    'zh-Hant': '【作用】在 Netlify 儀表板的環境變數中設置 GEMINI_API_KEY。\n\n'
        '【為什麼需要】Netlify 函數（aiExplainWord、aiSearch）需要這個金鑰來認證 Gemini API 呼叫。'
        '金鑰從 https://aistudio.google.com/apikey 免費取得。\n\n'
        '【可選】可以最多設置 9 個備用金鑰（GEMINI_API_KEY_BACKUP_2..9）'
        '形成金鑰鏈，主金鑰額度耗盡時自動切換到備用金鑰，提高可用性。\n\n'
        '【不設置會怎樣】AI 功能呼叫時函數會回傳 503 錯誤，提示金鑰未配置。\n\n'
        '【注意】這是 Netlify 環境變數，不是 Google Cloud 設定。修改後需要重新部署生效。',
    'en':
        'WHAT: Sets the GEMINI_API_KEY environment variable in '
            'the Netlify dashboard.\n\n'
            "WHY: The Netlify functions (aiExplainWord, aiSearch) "
            "need this credential to authenticate Gemini API calls. "
            "Generate one for free at https://aistudio.google.com/apikey.\n\n"
            "OPTIONAL: Set up to 9 backup keys "
            "(GEMINI_API_KEY_BACKUP_2..9) to form a fallback chain — "
            "when the primary key's quota is exhausted, the function "
            "automatically tries the next one. Improves reliability.\n\n"
            "WHAT BREAKS WITHOUT IT: AI features fail with 503 'GEMINI_"
            "API_KEY is not configured'.\n\n"
            "NOTE: This is a Netlify env var, not a Google Cloud "
            "setting. Changes require a redeploy to take effect.",
  },
  // ── Diagnostic probe result strings (localised) ───────────────
  'cloudDiagFirebaseAuthTitle': {
    'zh-Hans': 'Firebase Auth',
    'zh-Hant': 'Firebase Auth',
    'en': 'Firebase Auth',
  },
  'cloudDiagFirebaseAuthOk': {
    'zh-Hans': '已配置。',
    'zh-Hant': '已配置。',
    'en': 'Configured.',
  },
  'cloudDiagFirebaseAuthPlaceholder': {
    'zh-Hans': 'firebase_options.dart 中仍是占位值。云同步和登录已禁用（仅本地模式）。',
    'zh-Hant': 'firebase_options.dart 中仍是佔位值。雲同步和登入已停用（僅本地模式）。',
    'en':
        'firebase_options.dart still has placeholder values. Cloud '
            'sync + sign-in are disabled (local-only mode).',
  },
  'cloudDiagFirebaseAuthFailed': {
    'zh-Hans': 'Firebase 初始化失败。请在浏览器控制台中查找 [CloudAuthService] 日志。',
    'zh-Hant': 'Firebase 初始化失敗。請在瀏覽器控制台中查找 [CloudAuthService] 日誌。',
    'en': 'Firebase init failed. Check console for [CloudAuthService] log.',
  },
  'cloudDiagSignedInTitle': {
    'zh-Hans': '已登录',
    'zh-Hant': '已登入',
    'en': 'Signed in',
  },
  'cloudDiagSignedInSkip': {
    'zh-Hans': '未配置 Auth。',
    'zh-Hant': '未配置 Auth。',
    'en': 'Auth not configured.',
  },
  'cloudDiagSignedInWarning': {
    'zh-Hans': '尚未登录。在 设置 → 账户 中登录后，云端同步才会启用。',
    'zh-Hant': '尚未登入。在 設定 → 帳號 中登入後，雲端同步才會啟用。',
    'en':
        'Not signed in. Cloud sync stays disabled until the user '
            'signs in via Settings → Account.',
  },
  'cloudDiagSignedInOk': {
    'zh-Hans': '账号：{email}',
    'zh-Hant': '帳號：{email}',
    'en': 'as {email}',
  },
  'cloudDiagDriveScopeTitle': {
    'zh-Hans': 'Drive 权限范围',
    'zh-Hant': 'Drive 權限範圍',
    'en': 'Drive scope',
  },
  'cloudDiagDriveScopeSkip': {
    'zh-Hans': '未登录。',
    'zh-Hant': '未登入。',
    'en': 'Not signed in.',
  },
  'cloudDiagDriveScopeWarning': {
    'zh-Hans': '未捕获 Drive OAuth 访问令牌。可能是用户在添加 drive.file 范围之前登录的——'
        '请在 设置 → 账户 → 同步 中点击"重新连接 Google Drive"。',
    'zh-Hant': '未捕獲 Drive OAuth 存取權杖。可能是使用者在加入 drive.file 範圍之前登入的——'
        '請在 設定 → 帳號 → 同步 中點擊「重新連接 Google Drive」。',
    'en':
        'No Drive OAuth access token captured. User may have signed '
            'in before the drive.file scope was added — they need to '
            'click Reconnect Drive in Settings → Account → Sync.',
  },
  'cloudDiagDriveScopeOk': {
    'zh-Hans': 'OAuth 访问令牌已捕获。',
    'zh-Hant': 'OAuth 存取權杖已捕獲。',
    'en': 'OAuth access token captured.',
  },
  'cloudDiagDriveApiTitle': {
    'zh-Hans': 'Drive REST API',
    'zh-Hant': 'Drive REST API',
    'en': 'Drive REST API',
  },
  'cloudDiagDriveApiSkip': {
    'zh-Hans': '没有访问令牌。',
    'zh-Hant': '沒有存取權杖。',
    'en': 'No access token.',
  },
  'cloudDiagDriveApiOkEmpty': {
    'zh-Hans': 'API 可达；YsWords.json 还不存在（首次同步时会创建）。',
    'zh-Hant': 'API 可達；YsWords.json 還不存在（首次同步時會建立）。',
    'en':
        'API reachable; no YsWords.json yet (will be created on first sync).',
  },
  'cloudDiagDriveApiOkExists': {
    'zh-Hans': 'API 可达；YsWords.json 已存在。',
    'zh-Hant': 'API 可達；YsWords.json 已存在。',
    'en': 'API reachable; YsWords.json exists.',
  },
  'cloudDiagDriveApi401': {
    'zh-Hans': '401 未授权——访问令牌已过期。下次同步会自动静默刷新。',
    'zh-Hant': '401 未授權——存取權杖已過期。下次同步會自動靜默刷新。',
    'en':
        '401 unauthorized — access token expired. The next sync '
            'will silently refresh it.',
  },
  'cloudDiagDriveApiNotEnabled': {
    'zh-Hans': 'ysword 项目中未启用 Drive API。点击下方"打开 Cloud Console"一键启用。',
    'zh-Hant': 'ysword 專案中未啟用 Drive API。點擊下方「打開 Cloud Console」一鍵啟用。',
    'en':
        'Drive API is NOT enabled in the ysword project. Click '
            '"Open Cloud Console" to enable it (one click).',
  },
  'cloudDiagDriveApi403Other': {
    'zh-Hans': '403——可能是 OAuth 同意屏幕缺少 drive.file 范围，或者你的账号被 Workspace 管理员禁用了第三方应用。服务器返回：{body}',
    'zh-Hant': '403——可能是 OAuth 同意畫面缺少 drive.file 範圍，或者你的帳號被 Workspace 管理員停用了第三方應用。伺服器回傳：{body}',
    'en':
        '403 — likely the OAuth consent screen is missing the '
            'drive.file scope, or your account is on a Workspace '
            'admin that blocks third-party apps. Server said: {body}',
  },
  'cloudDiagAiProxyTitle': {
    'zh-Hans': 'AI 代理（Netlify）',
    'zh-Hant': 'AI 代理（Netlify）',
    'en': 'AI proxy (Netlify)',
  },
  'cloudDiagAiProxyOk': {
    'zh-Hans': '函数可达。AI 调用按需访问 Gemini；如有失败请查看 Netlify 控制台中 /api/aiSearch 的日志。',
    'zh-Hant': '函數可達。AI 呼叫按需存取 Gemini；如有失敗請查看 Netlify 控制台中 /api/aiSearch 的日誌。',
    'en':
        'Function reachable. Real AI calls go to Gemini on demand; '
            'if they fail, see /api/aiSearch logs in Netlify '
            'dashboard.',
  },
  'cloudDiagAiProxy503': {
    'zh-Hans': '函数报告：GEMINI_API_KEY 未配置。请在 Netlify 仪表盘中设置。',
    'zh-Hant': '函數報告：GEMINI_API_KEY 未配置。請在 Netlify 儀表板中設置。',
    'en':
        'Function says GEMINI_API_KEY is not configured. Set it in '
            'the Netlify dashboard.',
  },
  'cloudDiagAiProxy404': {
    'zh-Hans': '函数返回 404——未部署，或 netlify.toml 重定向配置错误。',
    'zh-Hant': '函數回傳 404——未部署，或 netlify.toml 重定向配置錯誤。',
    'en':
        'Function returns 404 — not deployed, or netlify.toml '
            'redirects are misconfigured.',
  },
  'cloudDiagTimeout': {
    'zh-Hans': '8 秒后超时。',
    'zh-Hant': '8 秒後逾時。',
    'en': 'Timed out after 8s.',
  },
  'cloudDiagUnknownEmail': {
    'zh-Hans': '（未知邮箱）',
    'zh-Hant': '（未知信箱）',
    'en': '(unknown email)',
  },
  // ── RTDB diagnostic probe (replaces Drive scope + Drive REST) ──
  'cloudDiagRtdbTitle': {
    'zh-Hans': '实时数据库（Realtime Database）',
    'zh-Hant': '即時資料庫（Realtime Database）',
    'en': 'Realtime Database',
  },
  'cloudDiagRtdbSkip': {
    'zh-Hans': '未登录。',
    'zh-Hant': '未登入。',
    'en': 'Not signed in.',
  },
  'cloudDiagRtdbSkipNoUid': {
    'zh-Hans': '没有 uid。',
    'zh-Hant': '沒有 uid。',
    'en': 'No uid.',
  },
  'cloudDiagRtdbOk': {
    'zh-Hans': '读写测试通过。同步数据存放在 users/{uid}/sync 下。',
    'zh-Hant': '讀寫測試通過。同步資料存放在 users/{uid}/sync 下。',
    'en':
        'Read + write OK. Sync data lives at users/{uid}/sync.',
  },
  'cloudDiagRtdbOkWithUrl': {
    'zh-Hans': '读写测试通过 · {url}。同步数据存放在 users/{uid}/sync 下。',
    'zh-Hant': '讀寫測試通過 · {url}。同步資料存放在 users/{uid}/sync 下。',
    'en':
        'Read + write OK at {url}. Sync data lives at users/{uid}/sync.',
  },
  'cloudDiagRtdbTimeoutDetail': {
    'zh-Hans': '连接 {url} 超时（8 秒）。最可能的原因是 Firebase 控制台中尚未'
        '创建数据库——打开 RTDB 标签页点击 "Create Database" 即可。'
        '其他可能：URL 的区域和数据库所在的区域不匹配，或者网络封锁了 firebaseio.com。',
    'zh-Hant': '連接 {url} 逾時（8 秒）。最可能的原因是 Firebase 控制台中尚未'
        '建立資料庫——打開 RTDB 標籤頁點擊「Create Database」即可。'
        '其他可能：URL 的區域和資料庫所在的區域不匹配，或者網路封鎖了 firebaseio.com。',
    'en':
        'Timed out after 8s connecting to {url}. The most likely '
            "cause is that the database hasn't been created yet in "
            'the Firebase Console — open the RTDB tab and click '
            '"Create Database". Other possibilities: the URL\'s '
            'region doesn\'t match where your database lives, or '
            'your network is blocking firebaseio.com.',
  },
  'cloudDiagRtdbReadback': {
    'zh-Hans': '探针写入成功，但读回的值不一致。可能是监听器过期或规则禁止读取。',
    'zh-Hant': '探針寫入成功，但讀回的值不一致。可能是監聽器過期或規則禁止讀取。',
    'en':
        'Wrote a probe value but readback returned a different value. '
            'Could be a stale listener or rules denying read.',
  },
  'cloudDiagRtdbPermissionDenied': {
    'zh-Hans': '权限被拒。打开 Firebase 控制台 → Realtime Database → Rules，'
        '允许已登录用户读写自己的 users/{uid}/* 路径。',
    'zh-Hant': '權限被拒。打開 Firebase 控制台 → Realtime Database → Rules，'
        '允許已登入使用者讀寫自己的 users/{uid}/* 路徑。',
    'en':
        'Permission denied. Open Firebase Console → Realtime '
            'Database → Rules and ensure authenticated users can '
            'read/write their own users/<uid>/* path.',
  },
  'cloudDiagRtdbNotEnabled': {
    'zh-Hans': '该项目尚未启用 Realtime Database。请在 Firebase 控制台的 '
        'Realtime Database 标签页中点击 "Create Database"。',
    'zh-Hant': '該專案尚未啟用 Realtime Database。請在 Firebase 控制台的 '
        'Realtime Database 標籤頁中點擊「Create Database」。',
    'en':
        "Realtime Database isn't enabled yet for this project. "
            'Open Firebase Console and click "Create Database" on '
            'the Realtime Database tab.',
  },
  'cloudDiagRtdbOpenRules': {
    'zh-Hans': '打开 RTDB 规则',
    'zh-Hant': '打開 RTDB 規則',
    'en': 'Open RTDB rules',
  },
  'cloudDiagRtdbOpenConsole': {
    'zh-Hans': '打开 RTDB 控制台',
    'zh-Hant': '打開 RTDB 控制台',
    'en': 'Open RTDB console',
  },
  // ── Exegesis sheet — proper-noun complementary glosses ────────
  // 2026-05-07: for proper nouns (people, places, deities) the
  // English Strong's lexicon gives etymology while the Chinese CBOL
  // gives biblical identification. Showing only the locale-preferred
  // one made users feel the data was inconsistent. Now both are
  // rendered side-by-side with these labels so the user understands
  // they're complementary, not contradictory.
  'exegesisProperNounBadge': {
    'zh-Hans': '专有名词',
    'zh-Hant': '專有名詞',
    'en': 'Proper noun',
  },
  'exegesisProperNounNote': {
    'zh-Hans': '英文给词源，中文给身份——都是对的，互相补充。',
    'zh-Hant': '英文給詞源，中文給身份——都是對的，互相補充。',
    'en':
        'English gives etymology; Chinese gives biblical identification — '
            'both correct, complementary perspectives.',
  },
  'exegesisProperNounRoleLabel': {
    'zh-Hans': '此处指',
    'zh-Hant': '此處指',
    'en': 'Identification',
  },
  'exegesisProperNounEtymLabel': {
    'zh-Hans': '词源',
    'zh-Hant': '詞源',
    'en': 'Etymology',
  },
  'exegesisProperNounComplDefEn': {
    'zh-Hans': '英文 Strong\'s 完整释义（互补视角）',
    'zh-Hant': '英文 Strong\'s 完整釋義（互補視角）',
    'en': "English Strong's full definition (complementary)",
  },
  'exegesisProperNounComplDefZh': {
    'zh-Hans': '中文 CBOL 释义（互补视角）',
    'zh-Hant': '中文 CBOL 釋義（互補視角）',
    'en': 'Chinese CBOL definition (complementary)',
  },
  // v1.3.x: collapsible header for the English-only material
  // (Strong's etymology / derivation, KJV counts) shown in the
  // Chinese exegesis panel. Collapsed by default so the Chinese
  // reader sees Chinese first; tap to reveal the English reference.
  'englishReference': {
    'zh-Hans': '英文参考',
    'zh-Hant': '英文參考',
    'en': 'English reference',
  },
  // ── AI Bible search (2026-05-07) ─────────────────────────────
  // Triggered from the search page's no-results state. Lets the
  // user ask Gemini for Bible references that match a fuzzy /
  // thematic query when exact-text search returns nothing.
  // 2026-05-07: rebrand. The user prefers the YsWords brand to be
  // surfaced rather than a generic "AI" label, with a "for reference
  // only" caveat to set expectations about LLM-generated content.
  // Older "ask AI" wording across the search page maps to the new
  // "search with YsWords AI" copy.
  'askAiForVerses': {
    'zh-Hans': '用 YsWords AI 智能搜索（仅供参考）',
    'zh-Hant': '用 YsWords AI 智慧搜尋（僅供參考）',
    'en': 'Search with YsWords AI (reference only)',
  },
  'aiSearching': {
    'zh-Hans': 'YsWords 正在搜索…',
    'zh-Hant': 'YsWords 正在搜尋…',
    'en': 'YsWords AI searching…',
  },
  'aiBibleSearchHeader': {
    'zh-Hans': 'YsWords 为「{query}」找到了 {count} 处经文（仅供参考）',
    'zh-Hant': 'YsWords 為「{query}」找到了 {count} 處經文（僅供參考）',
    'en': 'YsWords AI found {count} passages for "{query}" (reference only)',
  },
  'aiBibleSearchNoMatches': {
    'zh-Hans': 'AI 没有找到相关经文，换个说法再试一下吧。',
    'zh-Hant': 'AI 沒有找到相關經文，換個說法再試一下吧。',
    'en':
        'AI didn\'t find any matching passages. Try rephrasing.',
  },
  // 2026-05-08 (v1.1.5): tag + snackbar for AI ref cards that don't
  // resolve to a verse in the user's currently-loaded Bible version.
  'aiRefOnlyTag': {
    'zh-Hans': '仅参考',
    'zh-Hant': '僅參考',
    'en': 'reference only',
  },
  'aiRefNotInVersion': {
    'zh-Hans': '这段经文不在您当前的圣经版本中。在「设置」里切换版本后即可阅读。',
    'zh-Hant': '這段經文不在您當前的聖經版本中。在「設定」裡切換版本後即可閱讀。',
    'en':
        'This passage isn\'t in your current Bible version. Switch versions in Settings to read it.',
  },
  // 2026-05-08 (v1.1.10): deep-link CTA for the BYOK Gemini key.
  // Shown under the AI error notice when the failure is a quota /
  // not-configured one AND the user hasn't already set up their own
  // key. Tapping navigates to Settings → YsWords AI section and
  // scrolls the GeminiKeyCard into view.
  'aiOpenByokSettings': {
    'zh-Hans': '使用您自己的 Gemini Key',
    'zh-Hant': '使用您自己的 Gemini Key',
    'en': 'Set up your own Gemini API key',
  },
  // 2026-05-08 (v1.1.11): client-side fallback strings for the
  // AI services (ai_bible_search_service.dart + ai_search_service.dart).
  // Used only when the Netlify function returns a 429/503 without
  // a parseable `error` body — in normal operation the backend
  // sends a user-locale message that's surfaced directly.
  'aiQuotaExhaustedFallback': {
    'zh-Hans': 'YsWords AI 今天的共享配额已用完。明天再试，或在「设置 → '
        'YsWords AI」粘贴您自己的 Gemini API Key 用您的配额。',
    'zh-Hant': 'YsWords AI 今天的共享配額已用完。明天再試，或在「設定 → '
        'YsWords AI」貼上您自己的 Gemini API Key 用您的配額。',
    'en':
        'YsWords AI quota for the developer\'s shared key is used up for today. Try again tomorrow, or paste your own Gemini API key in Settings → AI to use your own quota.',
  },
  'aiNotConfiguredFallback': {
    'zh-Hans': 'YsWords AI 还没有配置。开发者需要在 Netlify 环境变量里设置 '
        'GEMINI_API_KEY。',
    'zh-Hant': 'YsWords AI 還沒有配置。開發者需要在 Netlify 環境變數裡設置 '
        'GEMINI_API_KEY。',
    'en':
        'YsWords AI is not configured. The developer needs to set GEMINI_API_KEY in Netlify env.',
  },
  // 2026-05-09 (v1.2.0): tag appended to the AboutPage footer when
  // the build was compiled with `--dart-define=CHINA_MODE=true`.
  // Lets users + support requests instantly tell which deploy
  // they're on (international vs China-tuned).
  'chinaBuildTag': {
    'zh-Hans': '中国版',
    'zh-Hant': '中國版',
    'en': 'China build',
  },
  // 2026-05-09 (v1.2.1): privacy / data-locality note shown on the
  // Profiles tab in China mode in place of the Sign-in button.
  // Replaces the previous Google sign-in CTA which can never succeed
  // behind the GFW. Same message slot is used by the Profiles "cloud
  // privacy" footnote when `kChinaMode` is true.
  'chinaCloudUnavailable': {
    'zh-Hans': '中国版不支持云同步 · 数据保存在本机',
    'zh-Hant': '中國版不支持雲同步 · 資料保存在本機',
    'en':
        "Cloud sync isn't available in the China build. Highlights, notes, and bookmarks stay on this device.",
  },
  'aiBibleSearchSomeMissing': {
    'zh-Hans': 'YsWords AI 还找到 {n} 处经文，但您当前圣经版本中没有匹配（仅供参考）。',
    'zh-Hant': 'YsWords AI 還找到 {n} 處經文，但您當前聖經版本中沒有匹配（僅供參考）。',
    'en':
        'YsWords AI also suggested {n} passages not in your current '
            'Bible version (reference only).',
  },
  // 2026-05-07 (post-fix v3): AI-result note when the active search
  // filter (e.g. "Search current book") excluded some of the
  // passages YsWords returned. Distinct from
  // aiBibleSearchSomeMissing which is for refs not present in the
  // user's loaded Bible version at all.
  'aiBibleSearchOutOfScope': {
    'zh-Hans': 'YsWords AI 还推荐了 {n} 处经文，但当前筛选范围之外（仅供参考）。',
    'zh-Hant': 'YsWords AI 還推薦了 {n} 處經文，但當前篩選範圍之外（僅供參考）。',
    'en':
        'YsWords AI also suggested {n} passages outside your current '
            'filter scope.',
  },
  // 2026-05-07: italic caveat shown directly below the AI search
  // button. v10 wording aligned with the welcome disclaimer:
  // AI is auxiliary; verify against Scripture; the Spirit guides.
  'aiReferenceOnly': {
    'zh-Hans': 'AI 只是辅助，请以经文为准，让圣灵亲自带领你。',
    'zh-Hant': 'AI 只是輔助，請以經文為準，讓聖靈親自帶領你。',
    'en':
        'AI is only an aid — verify against Scripture and let the Spirit guide you.',
  },
  // Friendly fallback when sync errors are clearly setup-related
  // (RTDB not enabled / permission denied). Replaces the raw
  // Firebase exception message in user-facing UI.
  'syncNotConfigured': {
    'zh-Hans': '云端同步尚未配置完成。本地高亮 / 书签 / 笔记仍可正常使用。'
        '若您是开发者，请在 设置 → 关于 → 底部 查看云端配置状态。',
    'zh-Hant': '雲端同步尚未配置完成。本地標亮 / 書籤 / 筆記仍可正常使用。'
        '若您是開發者，請在 設定 → 關於 → 底部 查看雲端配置狀態。',
    'en':
        "Cloud sync isn't fully set up for this app yet. Local "
            'highlights / bookmarks / notes still work as normal. '
            'If you\'re the developer, see Settings → About → '
            'bottom for the setup walkthrough.',
  },
  'aiByokTitle': {
    'zh-Hans': '使用我自己的 Gemini API 密钥',
    'zh-Hant': '使用我自己的 Gemini API 金鑰',
    'en': 'Use my own Gemini API key',
  },
  'aiByokBody': {
    // 2026-05-10 (v1.2.17): wording softened from "never synced
    // across devices" to "lives on this device" — the key now
    // syncs via the user's own Firebase project to their other
    // signed-in devices when they're signed in. The new
    // `aiByokSyncedNote` ui-string carries the explicit cloud-sync
    // disclosure and only renders below the input when the
    // condition (signed in + key present + intl build) matches.
    'zh-Hans': '从 Google AI Studio 获取免费密钥并粘贴在这里——之后 AI 功能（原文释义、AI 搜索）'
        '将走您自己的额度（每分钟 15 次，每日 1500 次），而不是与开发者池共享。'
        '密钥保存在本设备本地。',
    'zh-Hant': '從 Google AI Studio 取得免費金鑰並貼在這裡——之後 AI 功能（原文釋義、AI 搜尋）'
        '將走您自己的配額（每分鐘 15 次，每日 1500 次），而不是與開發者池共享。'
        '金鑰保存在本裝置本地。',
    'en':
        'Paste your free Gemini API key from AI Studio so AI features '
            '(word explanations, AI search) use your own quota (15 RPM / '
            '1500 RPD) instead of the shared developer pool. The key '
            'lives on this device.',
  },
  // 2026-05-10 (v1.2.17): cloud-sync disclosure shown only when the
  // user is signed in (intl build, Firebase available) and has a
  // key set. Sits in the BYOK card below the buttons. Tells the
  // user the key is synced to their OWN Firebase project under
  // `users/{uid}/account/geminiApiKey` — visible only to them per
  // Firebase rules — so it shows up on every other device they
  // sign in on.
  'aiByokSyncedNote': {
    'zh-Hans': '已登录 — 密钥会实时同步到您账号下的其他已登录设备（无需重启）。',
    'zh-Hant': '已登入 — 密鑰會即時同步到您帳號下的其他已登入裝置（無須重啟）。',
    'en':
        'Signed in — the key syncs in real time to your other signed-in devices (no restart needed).',
  },
  'aiByokGetKey': {
    'zh-Hans': '获取免费密钥',
    'zh-Hant': '取得免費金鑰',
    'en': 'Get free key',
  },
  // 2026-05-10 (v1.2.26): AI model picker — three tiers, mapped to
  // Gemini models on the server.
  //   '快' / 'Fast'      → flash-lite (default; fastest, simplest)
  //   '标准' / 'Standard'→ flash      (balanced)
  //   '深入' / 'Deep'    → pro        (deepest analysis, slower,
  //                                    smaller free-tier quota —
  //                                    BYOK key recommended)
  'aiModelTitle': {
    'zh-Hans': 'AI 响应深度',
    'zh-Hant': 'AI 回應深度',
    'en': 'AI response depth',
  },
  'aiModelBody': {
    'zh-Hans': '选择 AI 回答的速度与详尽度——不同档位对应不同的 Gemini 模型。',
    'zh-Hant': '選擇 AI 回答的速度與詳盡度——不同檔位對應不同的 Gemini 模型。',
    'en':
        'Choose the speed-vs-depth trade-off — each tier maps to a different Gemini model.',
  },
  'aiModelFast': {
    'zh-Hans': '快',
    'zh-Hant': '快',
    'en': 'Fast',
  },
  'aiModelStandard': {
    'zh-Hans': '标准',
    'zh-Hant': '標準',
    'en': 'Standard',
  },
  'aiModelDeep': {
    'zh-Hans': '深入',
    'zh-Hant': '深入',
    'en': 'Deep',
  },
  // 2026-05-10 (v1.2.27): per-tier detail panel — surfaces under
  // the SegmentedButton, updates as the user picks. Tells them
  // (a) which actual Gemini model the tier maps to, (b) which is
  // the default, (c) relative speed vs depth, and (d) free-tier
  // quota reality so they know when to BYOK.
  'aiModelFastDetail': {
    'zh-Hans': '快 (默认) · Gemini 2.5 Flash-Lite。最快、最简明的回答，约 1-3 秒。免费配额最大——开发者共享池基本不会耗尽。适合日常研经、快速查询。',
    'zh-Hant': '快 (預設) · Gemini 2.5 Flash-Lite。最快、最簡明的回答，約 1-3 秒。免費配額最大——開發者共享池基本不會耗盡。適合日常研經、快速查詢。',
    'en':
        'Fast (default) · Gemini 2.5 Flash-Lite. Quickest answers (~1-3 s), brief and direct. Largest free-tier quota — the shared developer pool almost never runs out. Best for everyday study and quick lookups.',
  },
  'aiModelStandardDetail': {
    'zh-Hans': '标准 · Gemini 2.5 Flash。速度和深度的平衡，约 3-6 秒。免费配额中等，平时充足，高峰时段可能耗尽。适合需要稍详细解释的场景。',
    'zh-Hant': '標準 · Gemini 2.5 Flash。速度和深度的平衡,約 3-6 秒。免費配額中等,平時充足,高峰時段可能耗盡。適合需要稍詳細解釋的場景。',
    'en':
        'Standard · Gemini 2.5 Flash. Balanced speed and depth (~3-6 s). Mid-range free-tier quota — usually fine, can run out at peak hours. Best when you want a bit more detail than Fast gives.',
  },
  'aiModelDeepDetail': {
    'zh-Hans': '深入 · Gemini 3 Flash Preview。带"思考"模式的高速推理模型——接近 Pro 级别的释经深度，但速度快得多（约 4-8 秒）。**免费配额可用**：~250 RPD，独立于 Standard / Fast 配额池。Google 在 2026 年 4 月把 gemini-2.5-pro 收费了——所以我们改用这款，免费即可使用，不需要 BYOK。BYOK 仍然推荐用于高频使用（您自己的密钥有独立配额，更稳定）。',
    'zh-Hant': '深入 · Gemini 3 Flash Preview。帶「思考」模式的高速推理模型——接近 Pro 級別的釋經深度，但速度快得多（約 4-8 秒）。**免費配額可用**：~250 RPD，獨立於 Standard / Fast 配額池。Google 在 2026 年 4 月把 gemini-2.5-pro 收費了——所以我們改用這款，免費即可使用，不需要 BYOK。BYOK 仍然推薦用於高頻使用（您自己的密鑰有獨立配額，更穩定）。',
    'en':
        'Deep · Gemini 3 Flash Preview. High-speed thinking model with near-Pro reasoning quality — substantially faster than Pro (~4-8 s). **Free-tier compatible** at ~250 RPD, with quota separate from the Standard / Fast pools. Google moved gemini-2.5-pro behind a paywall in April 2026, so YsWords switched Deep to this model — free, no BYOK needed. BYOK still recommended for heavy use (your own key has its own quota pool).',
  },
  // 2026-05-11 (v1.2.42): three short-lived strings were removed
  // here as dead code:
  //   • `aiDeepFellBackToStandard` (v1.2.37) — surfaced when the
  //     backend silently downgraded Pro → Flash for no-BYOK users.
  //     Obsolete after v1.2.40 switched Deep to
  //     `gemini-3-flash-preview` (works on free tier; no silent
  //     downgrade).
  //   • `aiModelDeepDisabledTooltip` (v1.2.39) — tooltip on the
  //     locked Deep segment when BYOK was missing. v1.2.41 reverted
  //     the gating because Deep works without BYOK now.
  //   • `aiModelDeepLockedNote` (v1.2.39) — italic note under the
  //     locked picker. Same reason.
  // 2026-05-09 (v1.2.7): "Test" button + result row in the BYOK
  // card. Lets the user verify their pasted key actually
  // authenticates against Gemini before saving — previously they
  // had to commit, navigate to the search page, run a query, and
  // hope the result wasn't a fallback to the dev's shared pool.
  'aiByokTest': {
    'zh-Hans': '测试',
    'zh-Hant': '測試',
    'en': 'Test',
  },
  'aiByokTesting': {
    'zh-Hans': '测试中…',
    'zh-Hant': '測試中…',
    'en': 'Testing…',
  },
  'aiByokTestOk': {
    'zh-Hans': '密钥可用！AI 功能将使用您的额度。',
    'zh-Hant': '金鑰可用！AI 功能將使用您的配額。',
    'en': 'Key works! AI features will use your quota.',
  },
  'aiByokTestFailed': {
    'zh-Hans': '测试失败。',
    'zh-Hant': '測試失敗。',
    'en': 'Test failed.',
  },
  'aiByokTestInvalidShape': {
    'zh-Hans': '看起来不像 Gemini API 密钥。它应该以 AIza… 开头'
        '（可以从 aistudio.google.com/apikey 复制一个）。',
    'zh-Hant': '看起來不像 Gemini API 金鑰。它應該以 AIza… 開頭'
        '（可以從 aistudio.google.com/apikey 複製一個）。',
    'en':
        "Doesn't look like a Gemini API key. It should start with "
            'AIza… (you can copy one from aistudio.google.com/apikey).',
  },
  'aiByokTestUnexpected': {
    'zh-Hans': 'AI 服务返回了意外的响应。',
    'zh-Hant': 'AI 服務返回了意外的回應。',
    'en': 'Unexpected response from the AI service.',
  },
  'aiByokTestTimeout': {
    'zh-Hans': 'AI 服务响应超时，请稍后再试。',
    'zh-Hant': 'AI 服務回應逾時，請稍後再試。',
    'en': 'The AI service did not respond in time. Try again.',
  },
  'show': {'zh-Hans': '显示', 'zh-Hant': '顯示', 'en': 'Show'},
  'hide': {'zh-Hans': '隐藏', 'zh-Hant': '隱藏', 'en': 'Hide'},
  // 'save' and 'clear' already exist elsewhere in this map; reuse them.
  'saved': {'zh-Hans': '已保存', 'zh-Hant': '已儲存', 'en': 'Saved'},
  // Drive sync — appears in the Account / Sync card.
  'driveSyncReconnect': {
    'zh-Hans': '重新连接 Google Drive',
    'zh-Hant': '重新連接 Google Drive',
    'en': 'Reconnect Google Drive',
  },
  'driveSyncReconnectBody': {
    'zh-Hans': 'Google Drive 授权已过期。点击下方按钮重新授权以恢复同步——'
        '您的高亮 / 笔记 / 书签存放在您自己的 Drive 隐藏应用文件夹（appDataFolder）中。',
    'zh-Hant': 'Google Drive 授權已過期。點擊下方按鈕重新授權以恢復同步——'
        '您的標亮 / 筆記 / 書籤存放在您自己的 Drive 隱藏應用資料夾（appDataFolder）中。',
    'en':
        'Google Drive authorization expired. Click below to reconnect '
            'and resume sync — your highlights / notes / bookmarks live '
            'in your own Drive AppData folder (hidden, app-private).',
  },
  // 2026-05-07: improved progress + post-download UX:
  // - "{total} files" makes the unit explicit (was just a bare number)
  // - "{eta}" inserts a localized "~30 sec left" suffix once we have
  //   enough samples
  // - offlinePackRedownload is the new outlined button label that
  //   replaces the prominent "Download" button after a successful
  //   download — no more confusing "why is the button still here?"
  'offlinePackEtaSuffix': {
    'zh-Hans': ' · 剩余约 {eta}',
    'zh-Hant': ' · 剩餘約 {eta}',
    'en': ' · ~{eta} left',
  },
  'offlinePackRedownload': {
    'zh-Hans': '重新下载以刷新',
    'zh-Hant': '重新下載以刷新',
    'en': 'Re-download to refresh',
  },
  'offlinePackNetworkNote': {
    'zh-Hans': '以下功能仍需要网络：AI 释义 / AI 搜索、云端同步登录、新闻实时更新，'
        '以及首次加载非 Roboto 字体（Google Fonts 在线下载，下载后会被浏览器缓存）。',
    'zh-Hant': '以下功能仍需要網路：AI 釋義 / AI 搜尋、雲端同步登入、新聞即時更新，'
        '以及首次載入非 Roboto 字體（Google Fonts 線上下載，下載後會被瀏覽器快取）。',
    'en':
        'Network is still required for: AI explanations / search, '
            'cloud-sync sign-in, live news refresh, and the first load '
            'of any non-Roboto font (Google Fonts download once, then '
            'cache in the browser).',
  },
  'offlinePackDownload': {
    'zh-Hans': '下载',
    'zh-Hant': '下載',
    'en': 'Download',
  },
  'offlinePackPickCategory': {
    'zh-Hans': '请勾选一个类别',
    'zh-Hant': '請勾選一個類別',
    'en': 'Pick a category',
  },
  'offlinePackDownloading': {
    'zh-Hans': '下载中… {done} / {total} 个文件（{pct}%）{eta}',
    'zh-Hant': '下載中… {done} / {total} 個檔案（{pct}%）{eta}',
    'en': 'Downloading… {done}/{total} files ({pct}%){eta}',
  },
  'offlinePackReady': {
    'zh-Hans': '已可离线使用 · {categories}',
    'zh-Hant': '已可離線使用 · {categories}',
    'en': 'Ready offline · {categories}',
  },
  'offlinePackSomeFailed': {
    'zh-Hans': '已跳过 {n} 个文件（下次下载时重试）。',
    'zh-Hant': '已跳過 {n} 個檔案（下次下載時重試）。',
    'en': '{n} files skipped (will retry on next download).',
  },
  'offlinePackClear': {
    'zh-Hans': '清除离线包记录',
    'zh-Hant': '清除離線包記錄',
    'en': 'Clear offline pack',
  },
  'offlinePackDoneToast': {
    'zh-Hans': '✓ 离线包就绪 —— 现在断网也能用了。',
    'zh-Hant': '✓ 離線包就緒 —— 現在斷網也能用了。',
    'en': '✓ Offline pack ready — the app now works without network.',
  },
  // ── Verse picker (Round 56) ─────────────────────────────────────
  // Optional second-step picker shown after the user selects a
  // chapter. Toggle in Settings → Reading "Pick verse after chapter".
  'versePickerTitle': {
    'zh-Hans': '选择经节',
    'zh-Hant': '選擇經節',
    'en': 'Pick a verse',
  },
  'versePickerTop': {
    'zh-Hans': '本章开头',
    'zh-Hant': '本章開頭',
    'en': 'Top',
  },
  'settingsPickVerseAfterChapter': {
    'zh-Hans': '选完章再选节',
    'zh-Hant': '選完章再選節',
    'en': 'Pick verse after chapter',
  },
  'settingsPickVerseAfterChapterHint': {
    'zh-Hans': '选完章节后弹出经节列表，可直接定位到具体一节。默认关闭。',
    'zh-Hant': '選完章節後彈出經節列表，可直接定位到具體一節。預設關閉。',
    'en':
        'After picking a chapter, show a verse-number grid so you can land on a specific verse. Off by default.',
  },
  // ── Bible Trivia (冷知识) — Round 56 ────────────────────────────
  'bibleTrivia': {
    'zh-Hans': '冷知识',
    'zh-Hant': '冷知識',
    'en': 'Bible Trivia',
  },
  'bibleTriviaIntro': {
    'zh-Hans': '原文中隐藏的离合体、神名暗藏、数字结构和双关——多数读者错过的彩蛋。点击任意条目可在阅读器中查看相关经文。',
    'zh-Hant': '原文中隱藏的離合體、神名暗藏、數字結構和雙關——多數讀者錯過的彩蛋。點擊任意條目可在閱讀器中查看相關經文。',
    'en':
        'Hidden patterns, acrostics, divine-name codes, and numerical structures most readers miss. Tap any entry to read the related passage in the reader.',
  },
  'bibleTriviaOpenRef': {
    'zh-Hans': '在圣经中查看',
    'zh-Hant': '在聖經中查看',
    'en': 'Read in Bible',
  },
  'bibleTriviaNoneForChapter': {
    'zh-Hans': '本章暂无冷知识。',
    'zh-Hant': '本章暫無冷知識。',
    'en': 'No trivia entries for this chapter yet.',
  },
  'bibleTriviaViewAll': {
    'zh-Hans': '查看全部冷知识',
    'zh-Hant': '查看全部冷知識',
    'en': 'View all trivia',
  },
  'bibleTriviaSearchHint': {
    'zh-Hans': '搜索冷知识…',
    'zh-Hant': '搜尋冷知識…',
    'en': 'Search trivia…',
  },
  // ── Trivia diagrams (Round 56 day-3) ──────────────────────────
  // Captions and labels used by the inline schematic diagrams that
  // visualise structural patterns (Hebrew acrostics, broken-acrostic
  // chapter counts, threefold genealogies, numbered word lists).
  'triviaAlphabetCaption': {
    'zh-Hans': '希伯来字母表 22 个字母',
    'zh-Hant': '希伯來字母表 22 個字母',
    'en': 'Hebrew alphabet · 22 letters',
  },
  'triviaChapterCountsCaption': {
    'zh-Hans': '每章节数（红色 = 离合体被打破）',
    'zh-Hant': '每章節數（紅色 = 離合體被打破）',
    'en': 'Verses per chapter (red = acrostic broken)',
  },
  // Genesis 1:1 — seven Hebrew words.
  'triviaGen11Word1': {
    'zh-Hans': '起初',
    'zh-Hant': '起初',
    'en': 'In the beginning',
  },
  'triviaGen11Word2': {
    'zh-Hans': '创造',
    'zh-Hant': '創造',
    'en': 'created',
  },
  'triviaGen11Word3': {
    'zh-Hans': '神（Elohim）',
    'zh-Hant': '神（Elohim）',
    'en': 'God (Elohim)',
  },
  'triviaGen11Word4': {
    'zh-Hans': '（直接宾语标记）',
    'zh-Hant': '（直接賓語標記）',
    'en': '(direct-object marker)',
  },
  'triviaGen11Word5': {
    'zh-Hans': '诸天',
    'zh-Hant': '諸天',
    'en': 'the heavens',
  },
  'triviaGen11Word6': {
    'zh-Hans': '与（直接宾语标记）',
    'zh-Hant': '與（直接賓語標記）',
    'en': 'and (direct-object marker)',
  },
  'triviaGen11Word7': {
    'zh-Hans': '大地',
    'zh-Hant': '大地',
    'en': 'the earth',
  },
  // Matthew 1:17 — three groups of 14 generations.
  'triviaMatt117GroupA': {
    'zh-Hans': '亚伯拉罕 → 大卫',
    'zh-Hant': '亞伯拉罕 → 大衛',
    'en': 'Abraham → David',
  },
  'triviaMatt117GroupB': {
    'zh-Hans': '大卫 → 被掳',
    'zh-Hant': '大衛 → 被擄',
    'en': 'David → Exile',
  },
  'triviaMatt117GroupC': {
    'zh-Hans': '被掳 → 基督',
    'zh-Hant': '被擄 → 基督',
    'en': 'Exile → Christ',
  },
  'triviaMatt117Generations': {
    'zh-Hans': '14 代',
    'zh-Hant': '14 代',
    'en': '14 generations',
  },
  // Round 56: hint shown under expanded font dropdown.
  'loadingVersion': {
    'zh-Hans': '正在切换译本…',
    'zh-Hant': '正在切換譯本…',
    'en': 'Loading version…',
  },
  // ── Originals stats tab (Round 56) ─────────────────────────────
  'statsOriginals': {
    'zh-Hans': '原文',
    'zh-Hant': '原文',
    'en': 'Originals',
  },
  'statsOriginalsHint': {
    'zh-Hans': '希伯来文（旧约）和希腊文（新约）原文中每个 Strong\'s 编号的出现频率。'
        '点击行可查看各书卷分布。',
    'zh-Hant': '希伯來文（舊約）和希臘文（新約）原文中每個 Strong\'s 編號的出現頻率。'
        '點擊行可查看各書卷分佈。',
    'en':
        'Frequency of every Strong\'s number in the original Hebrew (OT) and Greek (NT) text. Tap a row to see book breakdown.',
  },
  'statsOriginalsAll': {
    'zh-Hans': '全部',
    'zh-Hant': '全部',
    'en': 'All',
  },
  'statsOriginalsHideStopwordsTitle': {
    'zh-Hans': '隐藏常用虚词',
    'zh-Hant': '隱藏常用虛詞',
    'en': 'Hide common particles',
  },
  'statsOriginalsScopeAll': {
    'zh-Hans': '全圣经',
    'zh-Hant': '全聖經',
    'en': 'Whole Bible',
  },
  'statsOriginalsScopeBook': {
    'zh-Hans': '当前：{book}',
    'zh-Hant': '當前：{book}',
    'en': 'Showing: {book}',
  },
  'statsOriginalsBookTotalWords': {
    'zh-Hans': '本卷词数',
    'zh-Hant': '本卷詞數',
    'en': 'Total words in book',
  },
  'statsOriginalsBookUniqueLemmas': {
    'zh-Hans': '本卷词条数',
    'zh-Hant': '本卷詞條數',
    'en': 'Unique lemmas in book',
  },
  'statsOriginalsHideStopwordsDesc': {
    'zh-Hans':
        '过滤"the/and/in/of/who/that"等高频虚词与冠词，让真正有意义的圣经词汇浮上来。',
    'zh-Hant':
        '過濾「the/and/in/of/who/that」等高頻虛詞與冠詞，讓真正有意義的聖經詞彙浮上來。',
    'en':
        'Filter out high-frequency function words like the, and, in, of, who, that — surfacing the meaningful content vocabulary instead.',
  },
  'statsOriginalsHebrew': {
    'zh-Hans': '希伯来文',
    'zh-Hant': '希伯來文',
    'en': 'Hebrew',
  },
  'statsOriginalsGreek': {
    'zh-Hans': '希腊文',
    'zh-Hant': '希臘文',
    'en': 'Greek',
  },
  'statsOriginalsSearchHint': {
    'zh-Hans': '按 Strong\'s 编号、原文或释义搜索…',
    'zh-Hant': '按 Strong\'s 編號、原文或釋義搜索…',
    'en': 'Search by Strong\'s, lemma, or gloss…',
  },
  'statsOriginalsByBook': {
    'zh-Hans': '各书卷分布',
    'zh-Hant': '各書卷分佈',
    'en': 'By book',
  },
  'statsOriginalsTotal': {
    'zh-Hans': '共 {total} 个 Strong\'s 编号',
    'zh-Hant': '共 {total} 個 Strong\'s 編號',
    'en': '{total} unique Strong\'s numbers',
  },
  'statsOriginalsMatchCount': {
    'zh-Hans': '找到 {shown} 条',
    'zh-Hant': '找到 {shown} 條',
    'en': '{shown} matches',
  },
  'statsOriginalsShowAll': {
    'zh-Hans': '显示全部 {total} 条',
    'zh-Hant': '顯示全部 {total} 條',
    'en': 'Show all {total} entries',
  },
  'statsOriginalsEmpty': {
    'zh-Hans': '原文数据未加载。',
    'zh-Hant': '原文資料未載入。',
    'en': 'Original-language data not loaded.',
  },
  'statsOriginalsHebrewTotal': {
    'zh-Hans': '希伯来文总字数',
    'zh-Hant': '希伯來文總字數',
    'en': 'Hebrew words',
  },
  'statsOriginalsGreekTotal': {
    'zh-Hans': '希腊文总字数',
    'zh-Hant': '希臘文總字數',
    'en': 'Greek words',
  },
  'statsOriginalsHebrewUnique': {
    'zh-Hans': '希伯来文词条',
    'zh-Hant': '希伯來文詞條',
    'en': 'Hebrew lemmas',
  },
  'statsOriginalsGreekUnique': {
    'zh-Hans': '希腊文词条',
    'zh-Hant': '希臘文詞條',
    'en': 'Greek lemmas',
  },
  'statsOriginalsHapax': {
    'zh-Hans': '仅出现一次的字',
    'zh-Hant': '僅出現一次的字',
    'en': 'Hapax legomena',
  },
  'statsOriginalsBooksCount': {
    'zh-Hans': '涉及书卷数',
    'zh-Hant': '涉及書卷數',
    'en': 'Books covered',
  },
  'statsOriginalsTopHebrew': {
    'zh-Hans': '希伯来文使用最频繁（旧约）',
    'zh-Hant': '希伯來文使用最頻繁（舊約）',
    'en': 'Top Hebrew (OT)',
  },
  'statsOriginalsTopGreek': {
    'zh-Hans': '希腊文使用最频繁（新约）',
    'zh-Hant': '希臘文使用最頻繁（新約）',
    'en': 'Top Greek (NT)',
  },
  'statsOriginalsWordsShort': {
    'zh-Hans': '字',
    'zh-Hant': '字',
    'en': 'words',
  },
  'statsOriginalsLemmasShort': {
    'zh-Hans': '词条',
    'zh-Hant': '詞條',
    'en': 'lemmas',
  },
  'statsBooksOT': {
    'zh-Hans': '旧约',
    'zh-Hant': '舊約',
    'en': 'OT',
  },
  'statsBooksNT': {
    'zh-Hans': '新约',
    'zh-Hant': '新約',
    'en': 'NT',
  },
  // ── Style presets (Round 56) ──────────────────────────────────
  'stylePresetTitle': {
    'zh-Hans': '风格预设',
    'zh-Hant': '風格預設',
    'en': 'Style preset',
  },
  'stylePresetCustom': {
    'zh-Hans': '自定义 —— 手动调整的设置',
    'zh-Hant': '自訂 —— 手動調整的設定',
    'en': 'Custom — manually tuned settings',
  },
  'stylePresetActive': {
    'zh-Hans': '当前：{name}',
    'zh-Hant': '當前：{name}',
    'en': 'Active: {name}',
  },
  'stylePreset_classic_label': {
    'zh-Hans': '经典',
    'zh-Hant': '經典',
    'en': 'Classic',
  },
  'stylePreset_classic_description': {
    'zh-Hans': 'Roboto 无衬线字体，段落模式开启，标准间距 —— 默认外观。',
    'zh-Hant': 'Roboto 無襯線字體，段落模式開啟，標準間距 —— 預設外觀。',
    'en':
        'Roboto sans-serif, paragraph mode on, normal density — the default look.',
  },
  'stylePreset_modern_label': {
    'zh-Hans': '现代',
    'zh-Hant': '現代',
    'en': 'Modern',
  },
  'stylePreset_modern_description': {
    'zh-Hans': '系统无衬线字体，紧凑一些，段落模式开启 —— 类似 Kindle 阅读器风格。',
    'zh-Hant': '系統無襯線字體，緊湊一些，段落模式開啟 —— 類似 Kindle 閱讀器風格。',
    'en':
        'System sans-serif, slightly compact, paragraph mode — like a modern reading app.',
  },
  'stylePreset_reverent_label': {
    'zh-Hans': '虔敬',
    'zh-Hant': '虔敬',
    'en': 'Reverent',
  },
  'stylePreset_reverent_description': {
    'zh-Hans': 'Garamond 衬线字体，宽行距，段落模式 —— 接近印刷版圣经的感觉。',
    'zh-Hant': 'Garamond 襯線字體，寬行距，段落模式 —— 接近印刷版聖經的感覺。',
    'en':
        'Garamond serif, generous line spacing, paragraph mode — feels like a printed Bible.',
  },
  'stylePreset_compact_label': {
    'zh-Hans': '紧凑',
    'zh-Hant': '緊湊',
    'en': 'Compact',
  },
  'stylePreset_compact_description': {
    'zh-Hans': '小字号、低菜单缩放、逐节模式 —— 信息密度最高，适合查考使用。',
    'zh-Hant': '小字號、低選單縮放、逐節模式 —— 資訊密度最高，適合查考使用。',
    'en':
        'Smaller fonts, lower menu scale, verse-by-verse mode — maximum density for reference use.',
  },
  'stylePreset_reader_label': {
    'zh-Hans': '阅读',
    'zh-Hant': '閱讀',
    'en': 'Reader',
  },
  'stylePreset_reader_description': {
    'zh-Hans': 'Georgia 衬线字体，大字号，宽行距，段落模式 —— 长时间阅读最舒适。',
    'zh-Hant': 'Georgia 襯線字體，大字號，寬行距，段落模式 —— 長時間閱讀最舒適。',
    'en':
        'Georgia serif, larger font, wide line spacing, paragraph mode — comfortable for long reading.',
  },
  // 2026-05-08 (v1.1.2): top-of-list preset that pulls the user's
  // system defaults — OS native font, system theme, system locale.
  // The default landing experience for first-time users + reset.
  'stylePreset_systemDefault_label': {
    'zh-Hans': '系统默认',
    'zh-Hant': '系統預設',
    'en': 'System default',
  },
  'stylePreset_systemDefault_description': {
    'zh-Hans': '使用您设备的系统字体（macOS/iOS 用 SF Pro，Windows 用 '
        '雅黑，Android 用 Roboto），跟随系统深浅色和语言。'
        '最适合大多数用户的默认选项。',
    'zh-Hant': '使用您裝置的系統字體（macOS/iOS 用 SF Pro，Windows 用 '
        '雅黑，Android 用 Roboto），跟隨系統深淺色與語言。'
        '最適合大多數使用者的預設選項。',
    'en':
        'Uses your device\'s system font (San Francisco on Apple, Segoe UI on Windows, Roboto on Android, …) and follows the OS theme + language. The default for most users.',
  },
  // 2026-05-08 (v1.1.1): three new style presets — Liquid Glass
  // (Apple WWDC25 frosted glass), Paper (warm sepia flat), Carbon
  // (dark high-contrast).
  'stylePreset_liquidGlass_label': {
    'zh-Hans': '流光玻璃',
    'zh-Hant': '流光玻璃',
    'en': 'Liquid Glass',
  },
  'stylePreset_liquidGlass_description': {
    'zh-Hans': '苹果 WWDC25 风格 —— 半透明毛玻璃磁贴，柔和高光与阴影，'
        '苹果设备上自动使用 SF Pro 字体。',
    'zh-Hant': '蘋果 WWDC25 風格 —— 半透明毛玻璃磁貼，柔和高光與陰影，'
        '蘋果裝置上自動使用 SF Pro 字體。',
    'en':
        'Apple WWDC25 style — translucent frosted-glass tiles with soft specular highlights and shadows. macOS / iOS users get SF Pro automatically.',
  },
  'stylePreset_paper_label': {
    'zh-Hans': '纸本',
    'zh-Hant': '紙本',
    'en': 'Paper',
  },
  'stylePreset_paper_description': {
    'zh-Hans': '温暖米色纸张质感，发丝边框，无阴影，Garamond 衬线字体 —— '
        '像在读一本印刷的圣经。',
    'zh-Hant': '溫暖米色紙張質感，髮絲邊框，無陰影，Garamond 襯線字體 —— '
        '像在讀一本印刷的聖經。',
    'en':
        'Warm cream paper feel — hairline borders, no shadows, EB Garamond serif. Reads like a printed Bible.',
  },
  'stylePreset_carbon_label': {
    'zh-Hans': '碳黑',
    'zh-Hant': '碳黑',
    'en': 'Carbon',
  },
  'stylePreset_carbon_description': {
    'zh-Hans': '高对比深色界面，锐利的硬阴影，紧凑布局，Inter 字体 —— '
        '面向工具型重度用户。',
    'zh-Hant': '高對比深色界面，銳利的硬陰影，緊湊佈局，Inter 字體 —— '
        '面向工具型重度使用者。',
    'en':
        'High-contrast dark surfaces with sharp drop-shadows, compact density, Inter sans — for power-user vibes.',
  },
  // 2026-05-08 (v1.1.3): rewritten to reflect v1.1.2 reality —
  // "System default" is now the recommended top option (resolves
  // through the OS native font stack), Microsoft YaHei is no longer
  // bundled (removed in v1.0 for licence reasons), and Google
  // Fonts options download on first use.
  'fontFamilyHint': {
    'zh-Hans': '推荐选「系统默认」—— macOS / iOS 用 SF Pro，Windows 用雅黑，'
        'Android 用 Roboto，跟随您设备的系统字体。Roboto 是应用内置的备用'
        '字体，永远可用。其他选项（EB Garamond / Lora / Inter 等）首次使用'
        '时从 Google Fonts 下载并缓存。',
    'zh-Hant': '推薦選「系統預設」—— macOS / iOS 用 SF Pro，Windows 用雅黑，'
        'Android 用 Roboto，跟隨您裝置的系統字體。Roboto 是應用內建的備用'
        '字體，永遠可用。其他選項（EB Garamond / Lora / Inter 等）首次使用'
        '時從 Google Fonts 下載並快取。',
    'en':
        'Pick "System default" — macOS / iOS uses SF Pro, Windows uses Segoe UI, Android uses Roboto, following your device. Roboto is bundled with the app and always available. Other options (EB Garamond / Lora / Inter / …) download from Google Fonts on first use and are cached afterwards.',
  },
  'confirm': {
    'zh-Hans': '确认',
    'zh-Hant': '確認',
    'en': 'Confirm',
  },
  // Per-section labels + descriptions for the dashboard reorder list.
  // Looked up by `DashboardSection.label(locale)` /
  // `DashboardSection.description(locale)` in
  // `lib/models/dashboard_section.dart`. Adding a new section: add a
  // pair of `dashboardSection_<name>_label` and
  // `dashboardSection_<name>_description` entries here.
  'dashboardSection_readBible_label': {
    'zh-Hans': '读经',
    'zh-Hant': '讀經',
    'en': 'Read Bible',
  },
  'dashboardSection_readBible_description': {
    'zh-Hans': '主操作 — 跳回上次读经位置。',
    'zh-Hant': '主操作 — 跳回上次讀經位置。',
    'en': 'Primary CTA — jump back to your last reading position.',
  },
  // Shown beneath the Read Bible row in Settings → Dashboard layout
  // when the user tries to hide it (the Switch is disabled). Round 55
  // user feedback: "if all invisible then can't use the app" — so
  // Read Bible is locked on as the primary entry point.
  'dashboardSection_readBible_locked': {
    'zh-Hans': '常驻显示 — 应用主入口。',
    'zh-Hant': '常駐顯示 — 應用主入口。',
    'en': 'Always visible — primary entry point.',
  },
  'dashboardSection_resumeSermon_label': {
    'zh-Hans': '继续讲道',
    'zh-Hant': '繼續講道',
    'en': 'Resume sermon',
  },
  'dashboardSection_resumeSermon_description': {
    'zh-Hans': '从上次离开的讲道继续。',
    'zh-Hant': '從上次離開的講道繼續。',
    'en': 'Pick up where you left off in the last sermon you opened.',
  },
  'dashboardSection_dailyVerse_label': {
    'zh-Hans': '每日金句',
    'zh-Hant': '每日金句',
    'en': 'Verse of the Day',
  },
  'dashboardSection_dailyVerse_description': {
    'zh-Hans': '每天精选一节经文，所有设备同步。',
    'zh-Hant': '每天精選一節經文，所有設備同步。',
    'en': 'One curated verse per day, the same on every device.',
  },
  'dashboardSection_todayReading_label': {
    'zh-Hans': '今日读经',
    'zh-Hant': '今日讀經',
    'en': "Today's Reading",
  },
  'dashboardSection_todayReading_description': {
    'zh-Hans': '当前读经计划的今日段落。',
    'zh-Hant': '目前讀經計劃的今日段落。',
    'en': "Today's passage from your active reading plan.",
  },
  'dashboardSection_counts_label': {
    'zh-Hans': '收藏 / 笔记 / 高亮',
    'zh-Hant': '收藏 / 筆記 / 高亮',
    'en': 'Bookmarks / Notes / Highlights',
  },
  'dashboardSection_counts_description': {
    'zh-Hans': '一目了然的统计数字。',
    'zh-Hant': '一目了然的統計數字。',
    'en': 'Counts of bookmarks, notes, and highlights.',
  },
  'dashboardSection_recentBookmarks_label': {
    'zh-Hans': '最近收藏',
    'zh-Hant': '最近收藏',
    'en': 'Recent bookmarks',
  },
  'dashboardSection_recentBookmarks_description': {
    'zh-Hans': '最新收藏的五节经文。',
    'zh-Hant': '最新收藏的五節經文。',
    'en': 'Your five most recently bookmarked verses.',
  },
  'dashboardSection_todayEvidence_label': {
    'zh-Hans': '今日证据',
    'zh-Hant': '今日證據',
    'en': "Today's Evidence",
  },
  'dashboardSection_todayEvidence_description': {
    'zh-Hans': '每日轮换的考古、抄本、科学或历史发现。',
    'zh-Hant': '每日輪換的考古、抄本、科學或歷史發現。',
    'en':
        'One archaeology / manuscript / science / history entry per day.',
  },
  'dashboardSection_quickLinks_label': {
    'zh-Hans': '快捷入口',
    'zh-Hant': '快捷入口',
    'en': 'Quick links',
  },
  'dashboardSection_quickLinks_description': {
    'zh-Hans': '资料库、统计、讲道、家谱等的入口磁贴。',
    'zh-Hant': '資料庫、統計、講道、家譜等的入口磁貼。',
    'en': 'Tiles linking to Library, Statistics, Sermons, and more.',
  },
  'settingsSectionNotifications': {
    'zh-Hans': '通知',
    'zh-Hant': '通知',
    'en': 'Notifications',
  },
  'settingsShowEvidenceHint': {
    'zh-Hans': '主页"今日证据"卡片与快捷入口。',
    'zh-Hant': '主頁「今日證據」卡片與快捷入口。',
    'en': "Show Today's Evidence card and quick-link tile.",
  },
  'settingsShowPlanHint': {
    'zh-Hans': '主页显示当前读经计划。',
    'zh-Hant': '主頁顯示當前讀經計劃。',
    'en': 'Show the active reading plan on the dashboard.',
  },
  'notificationsToggle': {
    'zh-Hans': '启用通知',
    'zh-Hant': '啟用通知',
    'en': 'Enable notifications',
  },
  'notificationsHint': {
    'zh-Hans': '每日经文、读经与新闻的轻提醒。',
    'zh-Hant': '每日經文、讀經與新聞的輕提醒。',
    'en': 'Gentle daily reminders for verse, reading, and news.',
  },
  'notificationsUnsupported': {
    'zh-Hans': '此浏览器不支持通知。',
    'zh-Hant': '此瀏覽器不支援通知。',
    'en': "This browser doesn't support notifications.",
  },
  'notificationsBlocked': {
    'zh-Hans': '浏览器已禁止此站点通知。请到浏览器设置中允许后再开启。',
    'zh-Hant': '瀏覽器已禁止此站點通知。請到瀏覽器設定中允許後再開啟。',
    'en': 'Permission blocked at the browser level. Re-enable in browser settings, then toggle on here.',
  },
  'notificationsDenied': {
    'zh-Hans': '浏览器拒绝了通知权限。',
    'zh-Hant': '瀏覽器拒絕了通知權限。',
    'en': 'Browser denied notification permission.',
  },
  'notificationsEnabledBody': {
    'zh-Hans': '通知已开启。我们会发送轻量的每日提醒。',
    'zh-Hant': '通知已開啟。我們會發送輕量的每日提醒。',
    'en': "Notifications are on. You'll get gentle daily reminders.",
  },
  'notificationsTest': {
    'zh-Hans': '发送测试通知',
    'zh-Hant': '發送測試通知',
    'en': 'Send test notification',
  },
  'notificationsTestBody': {
    'zh-Hans': '这是一条测试通知。',
    'zh-Hant': '這是一條測試通知。',
    'en': 'This is a test notification.',
  },
  'appName': {
    'zh-Hans': 'YsWords 雅伟之言',
    'zh-Hant': 'YsWords 雅偉之言',
    'en': 'YsWords',
  },
  'startReading': {
    // Hero CTA shown when the user has no saved reading position
    // yet (fresh install). Mirrors continueReading's voice but
    // signals "first time".
    'zh-Hans': '开始读经',
    'zh-Hant': '開始讀經',
    'en': 'Read Bible',
  },
  'continueReadingHint': {
    'zh-Hans': '从头开始阅读圣经。',
    'zh-Hant': '從頭開始閱讀聖經。',
    'en': 'Open the Bible from the beginning.',
  },
  'syncNow': {
    'zh-Hans': '立即同步',
    'zh-Hant': '立即同步',
    'en': 'Sync now',
  },
  'syncingNow': {
    'zh-Hans': '正在同步…',
    'zh-Hant': '正在同步…',
    'en': 'Syncing now…',
  },
  'syncingNowShort': {
    'zh-Hans': '同步中…',
    'zh-Hant': '同步中…',
    'en': 'Syncing…',
  },
  'lastSyncedAt': {
    'zh-Hans': '上次同步于{when}',
    'zh-Hant': '上次同步於{when}',
    'en': 'Last synced {when}',
  },
  'syncNotYet': {
    'zh-Hans': '此设备尚未同步。',
    'zh-Hant': '此裝置尚未同步。',
    'en': 'Not synced yet on this device.',
  },
  'syncSuccess': {
    'zh-Hans': '同步成功。',
    'zh-Hant': '同步成功。',
    'en': 'Synced.',
  },
  'syncFailed': {
    'zh-Hans': '同步失败，请检查网络后重试。',
    'zh-Hant': '同步失敗，請檢查網路後重試。',
    'en': 'Sync failed. Check your connection and try again.',
  },
  'loading': {
    'zh-Hans': '加载中…',
    'zh-Hant': '載入中…',
    'en': 'Loading…',
  },
  'recentSearches': {
    'zh-Hans': '最近搜索',
    'zh-Hant': '最近搜索',
    'en': 'Recent',
  },
  'clear': {'zh-Hans': '清除', 'zh-Hant': '清除', 'en': 'Clear'},
  // 2026-05-07: explicit "clear all" label for the redesigned recent-
  // searches list footer. Distinct from per-item delete (× icon) and
  // from the generic 'clear' (which is reused elsewhere).
  'clearAllRecent': {
    'zh-Hans': '清除全部',
    'zh-Hant': '清除全部',
    'en': 'Clear all',
  },

  // ── Search help (2026-05-07) ─────────────────────────────────────
  // Localized strings for the new "?" help dialog on the search page.
  // Replaces the old undiscoverable feature surface — until now the
  // page accepted Strong's numbers, Bible refs, lemmas, and translit
  // silently, so most users only ever found the plain text-search
  // path. Help icon lives in the AppBar; the empty state also
  // surfaces a "Tip" line plus a small "Search tips" link.
  'searchHelpTooltip': {
    'zh-Hans': '搜索说明',
    'zh-Hant': '搜尋說明',
    'en': 'Search tips',
  },
  'searchHelpTitle': {
    'zh-Hans': '如何搜索',
    'zh-Hant': '如何搜尋',
    'en': 'How to search',
  },
  'searchHelpBasicTitle': {
    'zh-Hans': '基础',
    'zh-Hant': '基礎',
    'en': 'Basic',
  },
  'searchHelpBasicWord': {
    'zh-Hans': '直接输入字词或短句，可在当前圣经版本中查找包含该内容的经文。',
    'zh-Hant': '直接輸入字詞或短句，可在當前聖經版本中查找包含該內容的經文。',
    'en':
        'Type a word or phrase to find every verse that contains it '
            '(in your current Bible version).',
  },
  'searchHelpBasicRef': {
    'zh-Hans': '输入经文位置可直接跳转，例如「约 3:16」「John 3:16」「Rom 12:1-2」。',
    'zh-Hant': '輸入經文位置可直接跳轉，例如「約 3:16」「John 3:16」「Rom 12:1-2」。',
    'en':
        'Type a reference like "John 3:16", "约 3:16", or '
            '"Rom 12:1-2" to jump directly to that verse.',
  },
  'searchHelpBasicRecent': {
    'zh-Hans': '点击上方任一最近搜索可重复查询；点击右侧 × 可单独删除某条记录。',
    'zh-Hant': '點擊上方任一最近搜尋可重複查詢；點擊右側 × 可單獨刪除某條記錄。',
    'en':
        'Tap any recent search above to repeat it. Tap × to remove a '
            'single entry, or "Clear all" to wipe history.',
  },
  'searchHelpAdvancedTitle': {
    'zh-Hans': '进阶',
    'zh-Hant': '進階',
    'en': 'Advanced',
  },
  'searchHelpAdvStrongs': {
    'zh-Hans': '输入 Strong\'s 编号（如「G2316」「H7200」）打开词典与经文索引。',
    'zh-Hant': '輸入 Strong\'s 編號（如「G2316」「H7200」）打開詞典與經文索引。',
    'en':
        'Strong\'s number: type "G2316" / "H7200" to open the lexicon '
            'entry plus every verse that uses that word.',
  },
  // v1.3.91: combined / boolean Strong's search help + operator tooltips.
  'searchHelpAdvBoolean': {
    'zh-Hans':
        '组合检索：用 AND / OR / ✶ 按钮（输入编号后自动出现）组合多个原文编号。'
            '「G25 AND G26」=同时含两者的经文；「G25 OR G26」=含其一；'
            '「G25✶」=所有以 G25 开头的编号。',
    'zh-Hant':
        '組合檢索：用 AND / OR / ✶ 按鈕（輸入編號後自動出現）組合多個原文編號。'
            '「G25 AND G26」=同時含兩者的經文；「G25 OR G26」=含其一；'
            '「G25✶」=所有以 G25 開頭的編號。',
    'en':
        'Combine Strong\'s numbers with the AND / OR / ✶ buttons (they '
            'appear once you type a number): "G25 AND G26" → verses with '
            'BOTH; "G25 OR G26" → EITHER; "G25✶" → every number starting '
            'with G25.',
  },
  'booleanSearchHeader': {
    'zh-Hans': '{query} — 共 {count} 节',
    'zh-Hant': '{query} — 共 {count} 節',
    'en': '{query} — {count} verses',
  },
  'searchOpAndTip': {
    'zh-Hans': '同时含两者',
    'zh-Hant': '同時含兩者',
    'en': 'Verses with BOTH',
  },
  'searchOpOrTip': {
    'zh-Hans': '含其中之一',
    'zh-Hant': '含其中之一',
    'en': 'Verses with EITHER',
  },
  'searchOpStarTip': {
    'zh-Hans': '前缀通配符（如 G25✶）',
    'zh-Hant': '前綴萬用字元（如 G25✶）',
    'en': 'Prefix wildcard (e.g. G25✶)',
  },
  // v1.3.91: focused help dialog opened from the ? beside the AND/OR/✶ bar.
  'operatorHelpTitle': {
    'zh-Hans': '组合检索（AND / OR / ✶）',
    'zh-Hant': '組合檢索（AND / OR / ✶）',
    'en': 'Combined search (AND / OR / ✶)',
  },
  'operatorHelpAnd': {
    'zh-Hans': 'AND —「G25 AND G26」：同时含两个编号的经文。',
    'zh-Hant': 'AND —「G25 AND G26」：同時含兩個編號的經文。',
    'en': 'AND — "G25 AND G26": verses that contain BOTH numbers.',
  },
  'operatorHelpOr': {
    'zh-Hans': 'OR —「G25 OR G26」：含其中任一编号的经文。',
    'zh-Hant': 'OR —「G25 OR G26」：含其中任一編號的經文。',
    'en': 'OR — "G25 OR G26": verses that contain EITHER number.',
  },
  'operatorHelpStar': {
    'zh-Hans': '✶ —「G25✶」：所有以 G25 开头的 Strong\'s 编号。',
    'zh-Hant': '✶ —「G25✶」：所有以 G25 開頭的 Strong\'s 編號。',
    'en': '✶ — "G25✶": every Strong\'s number that starts with G25.',
  },
  'operatorHelpTip': {
    'zh-Hans': '先输入一个编号（如 G25），再点按钮加入 AND / OR / ✶。',
    'zh-Hant': '先輸入一個編號（如 G25），再點按鈕加入 AND / OR / ✶。',
    'en': 'Type a Strong\'s number (e.g. G25), then tap a button to add it.',
  },
  'searchHelpAdvLemma': {
    'zh-Hans': '直接输入希腊文（ἀγάπη）或希伯来文（אהבה）原文词，匹配后会打开对应的词典条目。',
    'zh-Hant': '直接輸入希臘文（ἀγάπη）或希伯來文（אהבה）原文詞，匹配後會打開對應的詞典條目。',
    'en':
        'Greek / Hebrew: type the original-language word (e.g. ἀγάπη '
            'or אהבה). Matching opens the lexicon entry directly.',
  },
  'searchHelpAdvTranslit': {
    'zh-Hans': '输入音译形式（如「agape」「shalom」「logos」）：完全匹配会直接打开词典；'
        '部分匹配则在搜索结果上方显示「您是否在找…」提示。',
    'zh-Hant': '輸入音譯形式（如「agape」「shalom」「logos」）：完全匹配會直接打開詞典；'
        '部分匹配則在搜尋結果上方顯示「您是否在找…」提示。',
    'en':
        'Transliteration: type "agape", "shalom", "logos". Exact '
            'matches open the lexicon; partial matches surface as a '
            '"Did you mean…" card alongside text results.',
  },
  'searchHelpAdvAi': {
    'zh-Hans': 'YsWords AI 搜索：当关键字搜索没有结果时，可以点击「用 YsWords AI 智能搜索」'
        '让 AI 帮你查找主题或模糊查询（如「最爱的章节」）。结果仅供参考，使用前请自行核对。',
    'zh-Hant': 'YsWords AI 搜尋：當關鍵字搜尋沒有結果時，可以點擊「用 YsWords AI 智慧搜尋」'
        '讓 AI 幫你查找主題或模糊查詢（如「最愛的章節」）。結果僅供參考，使用前請自行核對。',
    'en':
        'YsWords AI search: when keyword search returns nothing, tap '
            '"Search with YsWords AI" for fuzzy or thematic queries '
            '(e.g. "the love chapter"). Results are for reference '
            'only — verify before use.',
  },
  'searchHelpFooter': {
    'zh-Hans': '搜索范围跟随当前阅读的圣经版本，如果结果不符合预期，可在「设置」中切换版本。',
    'zh-Hant': '搜尋範圍跟隨當前閱讀的聖經版本，如果結果不符合預期，可在「設定」中切換版本。',
    'en':
        'Search scans the Bible version you currently have loaded — '
            'change versions in Settings if matches feel off.',
  },
  // Inline tip shown in the no-recents empty state.
  'searchHintQuickList': {
    'zh-Hans': '提示：可输入字词、参考（如「约 3:16」）、Strong\'s 编号「G2316」，或直接输入希腊文 / 希伯来文。',
    'zh-Hant': '提示：可輸入字詞、參考（如「約 3:16」）、Strong\'s 編號「G2316」，或直接輸入希臘文 / 希伯來文。',
    'en':
        'Tip: try a word, a reference like "John 3:16", a Strong\'s '
            'number "G2316", or Greek/Hebrew text directly.',
  },
  // "Did you mean lexicon entry…" card surfaced when a Latin-token
  // query weakly matches a Greek/Hebrew lemma (replaces the previous
  // silent auto-redirect that hijacked common English words).
  'searchLemmaSuggestionTitle': {
    'zh-Hans': '您是否在找词典条目？',
    'zh-Hant': '您是否在找詞典條目？',
    'en': 'Did you mean this lexicon entry?',
  },
  // 2026-05-07 (v5): three search-mode chips below the AppBar.
  // User wanted explicit per-mode entry points instead of a single
  // catch-all Enter handler.
  'searchModeText': {
    'zh-Hans': '经文搜索',
    'zh-Hant': '經文搜尋',
    'en': 'Search',
  },
  'searchModeTextTip': {
    'zh-Hans': '在当前圣经中查找包含这个字词或短句的经节（按 Enter 也可触发）。',
    'zh-Hant': '在當前聖經中查找包含這個字詞或短句的經節（按 Enter 也可觸發）。',
    'en':
        'Find verses containing this word or phrase. Pressing Enter '
            'also triggers this mode.',
  },
  'searchModeWordStudy': {
    'zh-Hans': '原文 / Strong\'s',
    'zh-Hant': '原文 / Strong\'s',
    'en': 'Word study',
  },
  'searchModeWordStudyTip': {
    'zh-Hans': 'Strong\'s 编号（G2316 / H7200）、希腊文 / 希伯来文原文，'
        '或音译形式（agape）。直接跳转到对应词典条目与经文索引。',
    'zh-Hant': 'Strong\'s 編號（G2316 / H7200）、希臘文 / 希伯來文原文，'
        '或音譯形式（agape）。直接跳轉到對應詞典條目與經文索引。',
    'en':
        'Strong\'s numbers (G2316 / H7200), Greek / Hebrew text, or '
            'transliteration (agape). Jumps to the lexicon entry plus '
            'concordance.',
  },
  'searchModeAi': {
    'zh-Hans': 'YsWords AI',
    'zh-Hant': 'YsWords AI',
    'en': 'YsWords AI',
  },
  'searchModeAiTip': {
    'zh-Hans': '通过 YsWords AI 进行模糊或主题搜索（如「最爱的章节」）。结果仅供参考，'
        '使用前请自行核对。',
    'zh-Hant': '透過 YsWords AI 進行模糊或主題搜尋（如「最愛的章節」）。結果僅供參考，'
        '使用前請自行核對。',
    'en':
        'Fuzzy / thematic search via YsWords AI (e.g. "the love '
            'chapter"). Results are reference-only — verify before use.',
  },
  'searchWordStudyNoMatch': {
    'zh-Hans': '没有匹配的词典条目。可以尝试 Strong\'s 编号（G2316 / H7200）、'
        '希腊文 / 希伯来文原文，或精确的音译形式（如「agape」）。',
    'zh-Hant': '沒有匹配的詞典條目。可以嘗試 Strong\'s 編號（G2316 / H7200）、'
        '希臘文 / 希伯來文原文，或精確的音譯形式（如「agape」）。',
    'en':
        'No lexicon entry matched. Try a Strong\'s number '
            '(G2316 / H7200), a Greek / Hebrew word, or an exact '
            'transliteration ("agape").',
  },
  // 2026-05-07 (post-fix): scope banner shown in the no-results
  // state. Helps the user spot when a stuck filter is the reason for
  // 0 results, with a one-tap "widen" affordance.
  'searchScopeWhole': {
    'zh-Hans': '整本圣经',
    'zh-Hant': '整本聖經',
    'en': 'Entire Bible',
  },
  'searchScopeCurrentBook': {
    'zh-Hans': '当前书卷',
    'zh-Hant': '當前書卷',
    'en': 'Current book',
  },
  'searchScopeScanned': {
    'zh-Hans': '已扫描 {n} 节',
    'zh-Hant': '已掃描 {n} 節',
    'en': 'Scanned {n} verses',
  },
  'searchScopeWiden': {
    'zh-Hans': '改为搜索整本圣经',
    'zh-Hant': '改為搜尋整本聖經',
    'en': 'Search entire Bible instead',
  },
  // 2026-05-07 (v10): bulk-copy of search results.
  'copyAllResults': {
    'zh-Hans': '复制全部结果',
    'zh-Hant': '複製全部結果',
    'en': 'Copy all results',
  },
  'copyAllResultsHeader': {
    'zh-Hans': '搜索：「{query}」 · 共 {n} 条结果',
    'zh-Hant': '搜尋：「{query}」 · 共 {n} 條結果',
    'en': 'Search: "{query}" · {n} matches',
  },
  'copyAllResultsToast': {
    'zh-Hans': '已复制 {n} 条结果',
    'zh-Hant': '已複製 {n} 條結果',
    'en': 'Copied {n} matches',
  },
  // 2026-05-07 (post-fix v2): on-demand load states. Surfaced when
  // SearchPage is reached via a refreshed deep-link URL before the
  // app's bootstrap loader has finished parsing the Bible asset.
  'searchLoadingBible': {
    'zh-Hans': '正在加载圣经…',
    'zh-Hant': '正在載入聖經…',
    'en': 'Loading the Bible…',
  },
  'searchLoadBibleFailed': {
    'zh-Hans': '圣经加载失败',
    'zh-Hant': '聖經載入失敗',
    'en': 'Could not load the Bible.',
  },
  // Profile editing (Round 35)
  'profileEditTitle': {
    'zh-Hans': '编辑账号',
    'zh-Hant': '編輯帳號',
    'en': 'Edit profile',
  },
  'displayName': {
    'zh-Hans': '昵称',
    'zh-Hant': '暱稱',
    'en': 'Display name',
  },
  'avatarColor': {
    'zh-Hans': '头像颜色',
    'zh-Hant': '頭像顏色',
    'en': 'Avatar color',
  },
  'save': {'zh-Hans': '保存', 'zh-Hant': '保存', 'en': 'Save'},
  'profileEditNotice': {
    'zh-Hans': '账号名和颜色仅保存在本设备。若已使用 Google 登录，将以 Google 头像优先显示。',
    'zh-Hant': '帳號名和顏色僅保存在本裝置。若已使用 Google 登入，將以 Google 頭像優先顯示。',
    'en':
        'Profile name and color are stored on this device. If you\'re signed in with Google your photo will appear instead of the colored initial.',
  },
  'editProfile': {
    'zh-Hans': '编辑账号',
    'zh-Hant': '編輯帳號',
    'en': 'Edit profile',
  },
  'setPhoto': {
    'zh-Hans': '设置头像',
    'zh-Hant': '設置頭像',
    'en': 'Set photo',
  },
  'changePhoto': {
    'zh-Hans': '更换头像',
    'zh-Hant': '更換頭像',
    'en': 'Change photo',
  },
  'removePhoto': {
    'zh-Hans': '删除头像',
    'zh-Hant': '刪除頭像',
    'en': 'Remove photo',
  },
  // ── Bible Evidence (Round 38) ────────────────────────────────────
  'bibleEvidence': {
    'zh-Hans': '圣经实证',
    'zh-Hant': '聖經實證',
    'en': 'Bible Evidence',
  },
  'bibleEvidenceSubtitle': {
    'zh-Hans': '考古、抄本、科学、历史多角度的实证档案',
    'zh-Hant': '考古、抄本、科學、歷史多角度的實證檔案',
    'en':
        'Archaeological, manuscript, scientific & historical evidence intersecting with the Bible.',
  },
  'evidenceForBook': {
    'zh-Hans': '经文实证 — ',
    'zh-Hant': '經文實證 — ',
    'en': 'Evidence — ',
  },
  'todayEvidence': {
    'zh-Hans': '今日实证',
    'zh-Hant': '今日實證',
    'en': 'Today\'s Evidence',
  },
  'evidenceDescription': {
    'zh-Hans': '详细说明',
    'zh-Hant': '詳細說明',
    'en': 'Description',
  },
  'scripturalCorrelation': {
    'zh-Hans': '经文对应',
    'zh-Hant': '經文對應',
    'en': 'Scriptural correlation',
  },
  'academicSources': {
    'zh-Hans': '学术来源',
    'zh-Hant': '學術來源',
    'en': 'Academic sources',
  },
  'readInBible': {
    'zh-Hans': '阅读经文',
    'zh-Hant': '閱讀經文',
    'en': 'Read',
  },
  'allCategories': {
    'zh-Hans': '全部分类',
    'zh-Hant': '全部分類',
    'en': 'All',
  },
  'resultsCount': {
    'zh-Hans': '共 {n} 条',
    'zh-Hant': '共 {n} 條',
    'en': '{n} results',
  },
  // Evidence scope-disclosure banner (chapter / book / archive).
  // Use {n}, {book}, {chapter} as placeholders; the widget does the
  // .replaceAll so we don't have to format here.
  'evidenceScopeChapter': {
    'zh-Hans': '为 {book} 第 {chapter} 章筛选 {n} 条',
    'zh-Hant': '為 {book} 第 {chapter} 章篩選 {n} 條',
    'en': '{n} entries for {book} {chapter}',
  },
  'evidenceScopeBook': {
    'zh-Hans': '为 {book} 筛选 {n} 条',
    'zh-Hant': '為 {book} 篩選 {n} 條',
    'en': '{n} entries for {book}',
  },
  'evidenceScopeBookFallback': {
    'zh-Hans': '{book} 第 {chapter} 章暂无相关条目 — 显示 {book} 全部 {n} 条',
    'zh-Hant': '{book} 第 {chapter} 章暫無相關條目 — 顯示 {book} 全部 {n} 條',
    'en':
        'No entries for {book} {chapter} — showing all {n} from {book}',
  },
  'evidenceWidenBook': {
    'zh-Hans': '查看 {book} 全部',
    'zh-Hant': '查看 {book} 全部',
    'en': 'Show all in {book}',
  },
  'evidenceWidenArchive': {
    'zh-Hans': '查看完整档案',
    'zh-Hant': '查看完整檔案',
    'en': 'Show full archive',
  },
  // Categories.
  'categoryArchaeology': {
    'zh-Hans': '考古',
    'zh-Hant': '考古',
    'en': 'Archaeology',
  },
  'categoryManuscripts': {
    'zh-Hans': '抄本',
    'zh-Hant': '抄本',
    'en': 'Manuscripts',
  },
  'categoryScience': {
    'zh-Hans': '科学',
    'zh-Hant': '科學',
    'en': 'Science',
  },
  'categoryHistory': {
    'zh-Hans': '历史',
    'zh-Hant': '歷史',
    'en': 'History',
  },
  // Confidence levels.
  'confidenceDefinitive': {
    'zh-Hans': '确证',
    'zh-Hant': '確證',
    'en': 'Definitive',
  },
  'confidenceStrong': {
    'zh-Hans': '强证据',
    'zh-Hant': '強證據',
    'en': 'Strong',
  },
  'confidenceCircumstantial': {
    'zh-Hans': '间接证据',
    'zh-Hant': '間接證據',
    'en': 'Circumstantial',
  },
  // YsWords AI search (Round 39, Stage 4 — Cloud Functions Gemini
  // proxy). Used by the Bible Evidence search button. Rebranded
  // 2026-05-07 from "Ask AI" so the YsWords brand is in front of the
  // user instead of a generic "AI" label, with reference-only caveat
  // surfaced via the disclaimer strings.
  'askAi': {
    'zh-Hans': '问 YsWords',
    'zh-Hant': '問 YsWords',
    'en': 'Ask YsWords',
  },
  'ask': {
    'zh-Hans': '提问',
    'zh-Hant': '提問',
    'en': 'Ask',
  },
  'askAiHint': {
    'zh-Hans': '例如：出埃及有何证据？',
    'zh-Hant': '例如：出埃及有何證據？',
    'en': 'e.g. What evidence supports the Exodus?',
  },
  'citations': {
    'zh-Hans': '引用条目',
    'zh-Hant': '引用條目',
    'en': 'Citations',
  },
  'keywordMatches': {
    'zh-Hans': '关键词匹配',
    'zh-Hant': '關鍵字匹配',
    'en': 'Keyword matches',
  },
  'settingsSectionAbout': {
    'zh-Hans': '关于',
    'zh-Hant': '關於',
    'en': 'About',
  },
  'appTagline': {
    'zh-Hans': '双语圣经研读应用。',
    'zh-Hant': '雙語聖經研讀應用。',
    'en': 'A bilingual Bible study app.',
  },
  'contactIntro': {
    'zh-Hans': '作者 Paul Liu',
    'zh-Hant': '作者 Paul Liu',
    'en': 'Made by Paul Liu',
  },
  'contactTail': {
    'zh-Hans': '问题、反馈或其他事宜：',
    'zh-Hant': '問題、反饋或其他事宜：',
    'en': 'Questions, feedback, or anything else:',
  },
  // ── About / Attributions page (Round 56 day-3, 2026-05-06) ────
  // Standalone page reachable from Settings → About → "Attributions
  // & Licensing". Lists every bundled / referenced third-party
  // resource with its licence + rights holder, and surfaces the
  // takedown / copyright contact email prominently. Added in
  // response to a copyright-risk audit — the app bundles content
  // owned by other parties, so being transparent + reachable is
  // the basic mitigation.
  'aboutPageTitle': {
    'zh-Hans': '关于与版权说明',
    'zh-Hant': '關於與版權說明',
    'en': 'About & Attributions',
  },
  // 2026-06-16 (v1.3.88): in-app "check for updates" (GitHub Releases).
  'checkForUpdates': {
    'zh-Hans': '检查更新',
    'zh-Hant': '檢查更新',
    'en': 'Check for updates',
  },
  'updateChecking': {
    'zh-Hans': '检查中…',
    'zh-Hant': '檢查中…',
    'en': 'Checking…',
  },
  'updateUpToDate': {
    'zh-Hans': '已是最新版本 (v{v})',
    'zh-Hant': '已是最新版本 (v{v})',
    'en': "You're on the latest version (v{v})",
  },
  'updateCheckFailed': {
    'zh-Hans': '无法检查更新，请稍后再试',
    'zh-Hant': '無法檢查更新，請稍後再試',
    'en': "Couldn't check for updates — try again later",
  },
  'updateAvailableTitle': {
    'zh-Hans': '有可用更新',
    'zh-Hant': '有可用更新',
    'en': 'Update available',
  },
  'updateAvailableBody': {
    'zh-Hans': '新版本 v{new} 已发布（当前 v{cur}）。从 GitHub 下载后安装：'
        'Android 点开 APK 安装；桌面版解压后运行；iOS 请改用网页版。',
    'zh-Hant': '新版本 v{new} 已發佈（目前 v{cur}）。從 GitHub 下載後安裝：'
        'Android 點開 APK 安裝；桌面版解壓後執行；iOS 請改用網頁版。',
    'en': 'Version v{new} is available (you have v{cur}). Download it from '
        'GitHub, then install: Android opens the APK; desktop unzips and '
        'runs. iOS uses the web app.',
  },
  'updateDownload': {
    'zh-Hans': '下载',
    'zh-Hant': '下載',
    'en': 'Download',
  },
  // 2026-06-18 (v1.3.89): test-notification confirmation. {platform} is
  // filled in with the actual device (iOS/Android/macOS/Windows/Linux/
  // browser) — it used to hardcode "iOS" on every device.
  'notificationsTestSent': {
    'zh-Hans': '测试通知已发送。如果没有看到横幅，请在 {platform} 的通知设置中查看 YsWords'
        '（以及系统的专注 / 勿扰模式）。',
    'zh-Hant': '測試通知已發送。如果沒有看到橫幅，請在 {platform} 的通知設定中查看 YsWords'
        '（以及系統的專注 / 勿擾模式）。',
    'en': "Test notification sent. If you don't see a banner, check your "
        '{platform} notification settings for YsWords (or Focus / Do Not '
        'Disturb).',
  },
  'platformBrowser': {
    'zh-Hans': '浏览器',
    'zh-Hant': '瀏覽器',
    'en': 'browser',
  },
  'platformDevice': {
    'zh-Hans': '设备',
    'zh-Hant': '裝置',
    'en': 'device',
  },
  'aboutOpenButton': {
    'zh-Hans': '版权说明与联系方式',
    'zh-Hant': '版權說明與聯絡方式',
    'en': 'Attributions & licensing',
  },
  'aboutDisclaimer': {
    'zh-Hans': '本应用是非商业的个人 / 教会研经工具。应用代码以 MIT 许可证开源，'
        '但圣经文本、字典数据、讲道文本、地图等资源仍由其各自版权方所有，仅在'
        '研习用途下使用。本应用与下方列出的任何出版社、机构、字体厂商均无附属关系。',
    'zh-Hant': '本應用是非商業的個人 / 教會研經工具。應用代碼以 MIT 授權開源，'
        '但聖經文本、字典資料、講道文本、地圖等資源仍由其各自版權方所有，僅在'
        '研習用途下使用。本應用與下方列出的任何出版社、機構、字體廠商均無附屬關係。',
    'en':
        'This is a non-commercial personal / community Bible-study tool. '
            'The application code is open source under MIT, but bundled '
            'scripture texts, lexicon data, sermons, maps and other '
            'resources remain the copyright of their respective rights '
            'holders and are reproduced under fair-use / personal-study '
            'exemptions. This app is not affiliated with or endorsed by '
            'any publisher, ministry, or font foundry listed below.',
  },
  'aboutContactTitle': {
    'zh-Hans': '联系方式 · 版权下架请求',
    'zh-Hant': '聯絡方式 · 版權下架請求',
    'en': 'Contact · Takedown requests',
  },
  'aboutContactBody': {
    'zh-Hans': '欢迎反馈、提问，或如果您是版权方对本应用中的任何内容有疑义，请通过下方邮箱联系我。'
        '一封邮件即可——我会及时回复并配合处理。',
    'zh-Hant': '歡迎反饋、提問，或如果您是版權方對本應用中的任何內容有疑義，請通過下方郵箱聯絡我。'
        '一封郵件即可——我會及時回覆並配合處理。',
    'en':
        'Feedback and questions are welcome. If you are a rights '
            'holder and have any concern about content included in this '
            'app, a single email is sufficient — I will respond and act '
            'promptly.',
  },
  'aboutContactSla': {
    'zh-Hans': '一般 24 小时内回复 · 如确认下架，72 小时内移除。',
    'zh-Hant': '一般 24 小時內回覆 · 如確認下架，72 小時內移除。',
    'en':
        'Acknowledged within 24 hours · removed within 72 hours when warranted.',
  },
  'aboutSectionScriptures': {
    'zh-Hans': '内置圣经译本',
    'zh-Hant': '內置聖經譯本',
    'en': 'Bundled scripture texts',
  },
  'aboutSectionLexicons': {
    'zh-Hans': '原文资源 · Strong\'s 编号 · 字典',
    'zh-Hant': '原文資源 · Strong\'s 編號 · 字典',
    'en': "Strong's lexicons & original-language data",
  },
  'aboutSectionOther': {
    'zh-Hans': '地图 · 讲道 · 字体 · AI · 其他',
    'zh-Hant': '地圖 · 講道 · 字體 · AI · 其他',
    'en': 'Maps · Sermons · Fonts · AI · Other',
  },
  'aboutSectionAppLicense': {
    'zh-Hans': '应用代码许可证',
    'zh-Hant': '應用程式碼授權',
    'en': 'Application licence',
  },
  // Per-version licence rows.
  'aboutLicensePublicDomain': {
    'zh-Hans': '公有领域 · 无版权限制。',
    'zh-Hant': '公有領域 · 無版權限制。',
    'en': 'Public domain.',
  },
  'aboutVerKjv': {
    'zh-Hans': 'KJV 钦定本（1611 / 1769）',
    'zh-Hant': 'KJV 欽定本（1611 / 1769）',
    'en': 'KJV (1611 / 1769)',
  },
  'aboutVerLeb': {
    'zh-Hans': 'LEB（Lexham 英文圣经）',
    'zh-Hant': 'LEB（Lexham 英文聖經）',
    'en': 'LEB (Lexham English Bible)',
  },
  'aboutLicenseLeb': {
    'zh-Hans': '© Logos Bible Software · 仅限非商业研经使用。',
    'zh-Hant': '© Logos Bible Software · 僅限非商業研經使用。',
    'en': '© Logos Bible Software · non-commercial study only.',
  },
  'aboutVerNasb': {
    'zh-Hans': 'NASB 2020 新美国标准译本',
    'zh-Hant': 'NASB 2020 新美國標準譯本',
    'en': 'NASB 2020',
  },
  'aboutLicenseNasb': {
    'zh-Hans': '© Lockman 基金会 · 在出版方引用规定下使用。',
    'zh-Hant': '© Lockman 基金會 · 在出版方引用規定下使用。',
    'en':
        '© The Lockman Foundation · used under quotation provisions.',
  },
  'aboutVerCuv': {
    'zh-Hans': 'CUV 和合本 1919（简 / 繁）',
    'zh-Hant': 'CUV 和合本 1919（簡 / 繁）',
    'en': 'CUV 1919 (和合本, simplified / traditional)',
  },
  'aboutVerCuvsYhwh': {
    'zh-Hans': 'CUVS-YHWH 和合本雅伟版（简 / 繁）',
    'zh-Hant': 'CUVS-YHWH 和合本雅偉版（簡 / 繁）',
    'en': 'CUVS-YHWH (和合本雅伟版, simplified / traditional)',
  },
  'aboutLicenseCuvsYhwh': {
    'zh-Hans': '© 雅伟的话事工 · 经授权使用。',
    'zh-Hant': '© 雅偉的話事工 · 經授權使用。',
    'en':
        '© Yahweh De Hua Ministry · used with permission.',
  },
  'aboutVerCnv': {
    'zh-Hans': 'CNV 新译本 1992 / 2011（简 / 繁）',
    'zh-Hant': 'CNV 新譯本 1992 / 2011（簡 / 繁）',
    'en': 'CNV 1992 / 2011 (新译本, simplified / traditional)',
  },
  'aboutLicenseCnv': {
    'zh-Hans': '© 环球圣经公会 · 雅伟版社群研经版本。',
    'zh-Hant': '© 環球聖經公會 · 雅偉版社群研經版本。',
    'en':
        '© Worldwide Bible Society · Yahweh-substituted community-study edition.',
  },
  'aboutVerLjk': {
    'zh-Hans': 'LJK1 / LJK2 原文释经圣经（简 / 繁）',
    'zh-Hant': 'LJK1 / LJK2 原文釋經聖經（簡 / 繁）',
    'en': 'LJK1 / LJK2 (原文释经圣经, simplified / traditional)',
  },
  'aboutLicenseLjk': {
    'zh-Hans': '© 圣经释经事工 · 经授权使用。',
    'zh-Hant': '© 聖經釋經事工 · 經授權使用。',
    'en': '© Bible Exegesis Ministry · used with permission.',
  },
  'aboutNivRemovedNote': {
    'zh-Hans': 'NIV（新国际译本）此前曾内置，但已于 2026 年 5 月移除——'
        'Biblica / Zondervan 对全文保有商业版权，未经出版方授权不得再分发完整文本。'
        '需要 NIV 的读者请使用 Bible Gateway / YouVersion 等官方渠道。',
    'zh-Hant': 'NIV（新國際譯本）此前曾內置，但已於 2026 年 5 月移除——'
        'Biblica / Zondervan 對全文保有商業版權，未經出版方授權不得再分發完整文本。'
        '需要 NIV 的讀者請使用 Bible Gateway / YouVersion 等官方渠道。',
    'en':
        'NIV (New International Version) was previously bundled but '
            'removed in 2026-05. Biblica / Zondervan retain commercial '
            'copyright on the full text and we cannot redistribute the '
            'JSON bundle without an explicit publisher licence. Readers '
            'seeking NIV should use Bible Gateway / YouVersion.',
  },
  // Lexicons.
  'aboutLexStrongs': {
    'zh-Hans': 'Strong\'s 希腊文 + 希伯来文编号',
    'zh-Hant': 'Strong\'s 希臘文 + 希伯來文編號',
    'en': "Strong's Greek + Hebrew Concordance",
  },
  'aboutLexCbol': {
    'zh-Hans': 'CBOL 中文释义',
    'zh-Hant': 'CBOL 中文釋義',
    'en': 'CBOL Chinese definitions',
  },
  'aboutLicenseCbol': {
    'zh-Hans': 'CC-BY-NC-SA 4.0 · 仅限非商业 · 衍生作品须沿用相同许可。',
    'zh-Hant': 'CC-BY-NC-SA 4.0 · 僅限非商業 · 衍生作品須沿用相同授權。',
    'en':
        'CC-BY-NC-SA 4.0 · non-commercial only; derivatives must keep the licence.',
  },
  'aboutLexLxx': {
    'zh-Hans': 'LXX 七十士译本 · 旧约↔希腊文对照',
    'zh-Hant': 'LXX 七十士譯本 · 舊約↔希臘文對照',
    'en': 'LXX (Septuagint) cross-references',
  },
  'aboutLexInterlinear': {
    'zh-Hans': '希腊文 + 希伯来文逐字对照（含 Strong\'s 编号）',
    'zh-Hant': '希臘文 + 希伯來文逐字對照（含 Strong\'s 編號）',
    'en': "Greek + Hebrew interlinear (Strong's-tagged)",
  },
  'aboutLicenseInterlinear': {
    'zh-Hans': '基于公有领域形态学数据库。',
    'zh-Hant': '基於公有領域形態學資料庫。',
    'en': 'Public-domain morphological databases.',
  },
  'aboutLexTsk': {
    'zh-Hans': '互参资料库（TSK）',
    'zh-Hant': '互參資料庫（TSK）',
    'en': 'Treasury of Scripture Knowledge (TSK) cross-references',
  },
  'aboutLicenseTsk': {
    'zh-Hans': '公有领域（R.A. Torrey, 1834）· 与 OpenBible.info 社群投票数据合并（CC-BY）。'
        '共 29,319 条经文索引。',
    'zh-Hant': '公有領域（R.A. Torrey, 1834）· 與 OpenBible.info 社群投票資料合併（CC-BY）。'
        '共 29,319 條經文索引。',
    'en':
        'Public domain (R.A. Torrey, 1834) · merged with '
            'OpenBible.info community votes (CC-BY). 29,319 source '
            'verses indexed.',
  },
  // Other resources.
  'aboutMaps': {
    'zh-Hans': '圣经历史地图（assets/maps/）',
    'zh-Hant': '聖經歷史地圖（assets/maps/）',
    'en': 'Bible-history maps (assets/maps/)',
  },
  'aboutLicenseMaps': {
    'zh-Hans': '来源于公有领域 / Creative Commons 资源库。',
    'zh-Hant': '來源於公有領域 / Creative Commons 資源庫。',
    'en': 'Public domain / Creative Commons archives.',
  },
  'aboutSermons': {
    'zh-Hans': '讲道文本（assets/sermons/）',
    'zh-Hant': '講道文本（assets/sermons/）',
    'en': 'Sermons (assets/sermons/)',
  },
  'aboutLicenseSermons': {
    'zh-Hans': '© 梁家铿 · 经授权使用。',
    'zh-Hant': '© 梁家鏗 · 經授權使用。',
    'en': '© Liang Jia-keng · used with permission.',
  },
  'aboutFontsBundled': {
    'zh-Hans': '内置字体：Roboto',
    'zh-Hant': '內置字體：Roboto',
    'en': 'Bundled font: Roboto',
  },
  'aboutLicenseRoboto': {
    'zh-Hans': 'Apache 2.0 · Google。',
    'zh-Hant': 'Apache 2.0 · Google。',
    'en': 'Apache 2.0 · Google.',
  },
  'aboutFontsGoogle': {
    'zh-Hans': '运行时字体：EB Garamond / Lora / Inter / Noto Serif SC 等',
    'zh-Hant': '執行時字體：EB Garamond / Lora / Inter / Noto Serif SC 等',
    'en':
        'Runtime fonts: EB Garamond / Lora / Inter / Noto Serif SC / …',
  },
  'aboutLicenseOfl': {
    'zh-Hans': 'SIL OFL · 通过 google_fonts 包按需加载。',
    'zh-Hant': 'SIL OFL · 透過 google_fonts 套件按需載入。',
    'en': 'SIL OFL · loaded via google_fonts.',
  },
  'aboutAi': {
    'zh-Hans': 'YsWords AI 经文释义（仅供参考）',
    'zh-Hant': 'YsWords AI 經文釋義（僅供參考）',
    'en': 'YsWords AI explanations (reference only)',
  },
  'aboutLicenseAi': {
    'zh-Hans': 'Google Gemini API · 输出可在 API 条款下重新分发。',
    'zh-Hant': 'Google Gemini API · 輸出可在 API 條款下重新分發。',
    'en':
        'Google Gemini API · output redistribution permitted under API terms.',
  },
  'aboutTrivia': {
    'zh-Hans': '冷知识文本与图示',
    'zh-Hant': '冷知識文本與圖示',
    'en': 'Trivia text + diagrams',
  },
  'aboutLicenseOriginal': {
    'zh-Hans': '本应用原创内容 · MIT（与应用代码同许可）。',
    'zh-Hant': '本應用原創內容 · MIT（與應用程式碼同授權）。',
    'en':
        'Original to this app · MIT (same as application code).',
  },
  'aboutAppLicenseHeading': {
    'zh-Hans': '应用代码：MIT 许可证',
    'zh-Hant': '應用程式碼：MIT 授權',
    'en': 'Application code: MIT licence',
  },
  'aboutAppLicenseBody': {
    'zh-Hans': '本仓库内的 Dart / Flutter 源代码（lib/ 目录及构建配置）以 MIT 许可证开源。'
        '内置的第三方资源不在此 MIT 许可范围内——见上方各表格。',
    'zh-Hant': '本倉庫內的 Dart / Flutter 原始碼（lib/ 目錄及建構設定）以 MIT 授權開源。'
        '內置的第三方資源不在此 MIT 授權範圍內——見上方各表格。',
    'en':
        'The Dart / Flutter source code in this repository (under '
            '`lib/` and the build configuration) is open source under '
            'the MIT licence. Bundled third-party resources are NOT '
            'covered by MIT — see the tables above for each item.',
  },
  'aboutOpenRepo': {
    'zh-Hans': '在 GitHub 查看源代码',
    'zh-Hant': '在 GitHub 查看原始碼',
    'en': 'View source on GitHub',
  },
  // 2026-05-10 (v1.2.20): the date used to be hardcoded in this
  // string ("2026-05-07") and stale-drifted across multiple
  // releases — user noticed at v1.2.19. Now uses a placeholder
  // that the AboutPage footer interpolates with `kAppReleaseTime`
  // from `lib/constants/app_version.dart`. Bumping
  // kAppReleaseTime alongside kAppVersion is the canonical place
  // to keep the footer accurate.
  // 2026-05-10 (v1.2.24): placeholder upgraded `{date}` → `{time}`
  // when kAppReleaseDate became kAppReleaseTime (date+H:M+tz)
  // so back-to-back same-day releases stamp distinct moments.
  'aboutFooterNote': {
    'zh-Hans': '本页最后更新于 {time}。',
    'zh-Hant': '本頁最後更新於 {time}。',
    'en': 'Last updated {time}.',
  },
  'refresh': {
    'zh-Hans': '刷新',
    'zh-Hant': '重新整理',
    'en': 'Refresh',
  },
  // ── Gospel synopsis (Round 27B) ─────────────────────────────────
  'synopsis': {
    'zh-Hans': '福音书对观',
    'zh-Hant': '福音書對觀',
    'en': 'Gospel Synopsis',
  },
  'synopsisChapterTitle': {
    'zh-Hans': '本章对观条目',
    'zh-Hant': '本章對觀條目',
    'en': 'Parallel passages in this chapter',
  },
  'synopsisNone': {
    'zh-Hans': '本章暂无对观条目。',
    'zh-Hant': '本章暫無對觀條目。',
    'en': 'No parallel passages curated for this chapter.',
  },
  'synopsisOnlyHere': {
    'zh-Hans': '仅记于本福音书',
    'zh-Hant': '僅記於本福音書',
    'en': 'Only in this Gospel',
  },
  // ── Strong's # direct lookup (Round 27C) ─────────────────────────
  'strongsDerivation': {
    'zh-Hans': '词源',
    'zh-Hant': '詞源',
    'en': 'Derivation',
  },
  'strongsFamily': {
    'zh-Hans': '同根词',
    'zh-Hant': '同根詞',
    'en': 'Word family',
  },
  'strongsCompare': {
    'zh-Hans': '相关词',
    'zh-Hant': '相關詞',
    'en': 'Compare',
  },
  'strongsOccurrences': {
    'zh-Hans': '出处',
    'zh-Hant': '出處',
    'en': 'Occurrences',
  },
  // v1.3.90: shown when a Strong's occurrence is tapped but the verse
  // isn't present in the user's currently-loaded Bible version (e.g. a
  // NT Greek word while reading an OT-only version).
  'strongsRefNotInVersion': {
    'zh-Hans': '当前译本中没有这节经文。',
    'zh-Hant': '目前譯本中沒有這節經文。',
    'en': 'This verse isn\'t in your current Bible version.',
  },
  // 2026-05-24 (v1.3.19): all `tts*` keys removed with the 朗读
  // feature. Were: ttsListen, ttsStop, ttsVoiceTitle, ttsVoiceBody,
  // ttsVoiceGender, ttsVoiceGenderFemale/Male, ttsVoiceTier,
  // ttsVoiceTierNeural/Standard, ttsCacheSize/Clear/Cleared.
  // ── Keyboard shortcuts (Round 27E) ──────────────────────────────
  'shortcutsHelp': {
    'zh-Hans': '键盘快捷键',
    'zh-Hant': '鍵盤快捷鍵',
    'en': 'Keyboard shortcuts',
  },
  // ── Profiles / sign-in (Round 28) ──────────────────────────────
  'welcomeLocalOnlyNotice': {
    'zh-Hans': '账号仅保存在本设备，不需要密码、不上传服务器。',
    'zh-Hant': '帳號僅保存在本裝置，不需要密碼、不上傳伺服器。',
    'en':
        'Profiles are stored only on this device. No password, no server.',
  },
  'welcomeNameHint': {
    'zh-Hans': '您的姓名',
    'zh-Hant': '您的姓名',
    'en': 'Your name',
  },
  'profileTitle': {
    'zh-Hans': '账号',
    'zh-Hant': '帳號',
    'en': 'Profiles',
  },
  'profileCurrent': {
    'zh-Hans': '当前账号',
    'zh-Hant': '目前帳號',
    'en': 'Active profile',
  },
  'profileSwitchOrAdd': {
    'zh-Hans': '切换或新增账号',
    'zh-Hant': '切換或新增帳號',
    'en': 'Switch or add a profile',
  },
  'profileSwitch': {
    'zh-Hans': '切换到此账号',
    'zh-Hant': '切換到此帳號',
    'en': 'Switch to this profile',
  },
  'profileRename': {
    'zh-Hans': '重命名',
    'zh-Hant': '重新命名',
    'en': 'Rename',
  },
  'profileDelete': {
    'zh-Hans': '删除',
    'zh-Hant': '刪除',
    'en': 'Delete',
  },
  'profileDeleteConfirm': {
    'zh-Hans': '确定要删除「{name}」及其在本设备上的所有笔记、书签、高亮与读经进度吗？',
    'zh-Hant': '確定要刪除「{name}」及其在本裝置上的所有筆記、書籤、高亮與讀經進度嗎？',
    'en':
        'Permanently delete "{name}" and all its notes, bookmarks, highlights and reading-plan progress on this device?',
  },
  'profileCreateTitle': {
    'zh-Hans': '新建账号',
    'zh-Hant': '新建帳號',
    'en': 'Create profile',
  },
  'profileGuestSub': {
    'zh-Hans': '默认账号 — 任何使用本浏览器的人',
    'zh-Hant': '預設帳號 — 任何使用本瀏覽器的人',
    'en': 'Default — anyone using this browser',
  },
  'profileLocalOnly': {
    'zh-Hans': '本地账号',
    'zh-Hant': '本地帳號',
    'en': 'Local profile',
  },
  'cancel': {
    'zh-Hans': '取消',
    'zh-Hant': '取消',
    'en': 'Cancel',
  },
  // ── Cloud auth (rounds 29-30) ───────────────────────────────────
  'cloudSignInGoogle': {
    'zh-Hans': '使用 Google 登录（多设备同步）',
    'zh-Hant': '使用 Google 登入（多裝置同步）',
    'en': 'Sign in with Google',
  },
  'cloudSignIn': {
    'zh-Hans': '登录以在多设备同步',
    'zh-Hant': '登入以在多裝置同步',
    'en': 'Sign in to sync across devices',
  },
  'cloudSignOut': {
    'zh-Hans': '退出',
    'zh-Hant': '登出',
    'en': 'Sign out',
  },
  'cloudSignedInAs': {
    'zh-Hans': '已登录为 {email}',
    'zh-Hant': '已登入為 {email}',
    'en': 'Cloud-synced as {email}',
  },
  'cloudInitFailedTitle': {
    'zh-Hans': '云端登录暂时不可用',
    'zh-Hant': '雲端登入暫時無法使用',
    'en': 'Cloud sign-in temporarily unavailable',
  },
  // 2026-05-09 (v1.2.2): localized fallback message for the Settings
  // sign-in flow. Used when the sign-in popup itself errors and the
  // underlying platform message isn't human-friendly. Previously this
  // was a hardcoded English string ("Sign-in failed.") — a
  // non-English-locale user would see English text on a transient
  // network blip.
  'signInFailed': {
    'zh-Hans': '登录失败。',
    'zh-Hant': '登入失敗。',
    'en': 'Sign-in failed.',
  },
  'cloudInitOk': {
    'zh-Hans': '云端登录已恢复。',
    'zh-Hant': '雲端登入已恢復。',
    'en': 'Cloud sign-in restored.',
  },
  'clearCache': {
    'zh-Hans': '清除缓存并重新加载',
    'zh-Hant': '清除快取並重新載入',
    'en': 'Clear cache & reload',
  },
  'clearCacheTitle': {
    'zh-Hans': '清除缓存并重新加载？',
    'zh-Hant': '清除快取並重新載入？',
    'en': 'Clear cache & reload?',
  },
  'clearCacheBody': {
    'zh-Hans': '此操作将注销 Service Worker、删除浏览器缓存并重新加载应用。'
        '您的标记、笔记和书签存储在别处，不会被清除。',
    'zh-Hant': '此操作會註銷 Service Worker、刪除瀏覽器快取並重新載入應用程式。'
        '您的標記、筆記與書籤儲存在他處，不會被清除。',
    'en': 'This will unregister the service worker, delete browser '
        'caches, and reload the app. Your highlights, notes and '
        'bookmarks are stored separately and will not be cleared.',
  },
  'clearCacheNote': {
    'zh-Hans': '清除浏览器缓存与 Service Worker。您的资料（标记、笔记、书签）会保留。',
    'zh-Hant': '清除瀏覽器快取與 Service Worker。您的資料（標記、筆記、書籤）會保留。',
    'en': 'Wipes browser cache + service workers. Your profile data '
        '(highlights, notes, bookmarks) stays put.',
  },
  'showSectionTitles': {
    'zh-Hans': '段落标题',
    'zh-Hant': '段落標題',
    'en': 'Section titles',
  },
  'showSectionTitlesSubtitle': {
    'zh-Hans': '在相应经文上方显示段落主题（如「登山宝训」、「耶稣家谱」等）。',
    'zh-Hant': '在相應經文上方顯示段落主題（如「登山寶訓」、「耶穌家譜」等）。',
    'en': 'Render paragraph headings (e.g. "The Sermon on the Mount") '
        'above the matched verse in the reading pane.',
  },
  'showBookIntro': {
    'zh-Hans': '书卷简介',
    'zh-Hant': '書卷簡介',
    'en': 'Book introductions',
  },
  'showBookIntroSubtitle': {
    'zh-Hans': '在每卷书第一章顶部显示作者、年代、主题与关键经文等背景介绍。',
    'zh-Hant': '在每卷書第一章頂部顯示作者、年代、主題與關鍵經文等背景介紹。',
    'en': 'Show a collapsible card at the top of chapter 1 with the '
        'book\'s author, date, audience, themes, and key passage.',
  },
  // 2026-05-19 (v1.2.55): the v1.2.53 cross-version LEB overlay
  // ui-strings were removed. LEB's own inline notes render via
  // the normal `<note:>` book-icon path; biblexg-v2's notes do
  // the same. No cross-version overlay ui-strings needed.
  'aboutThisBook': {
    'zh-Hans': '关于此卷书',
    'zh-Hant': '關於此卷書',
    'en': 'About this book',
  },
  'sectionContextTooltip': {
    'zh-Hans': '背景说明',
    'zh-Hant': '背景說明',
    'en': 'Background',
  },
  'readMore': {
    'zh-Hans': '展开',
    'zh-Hant': '展開',
    'en': 'Read more',
  },
  'showLess': {
    'zh-Hans': '收起',
    'zh-Hant': '收起',
    'en': 'Show less',
  },
  'authorLabel': {
    'zh-Hans': '作者',
    'zh-Hant': '作者',
    'en': 'Author',
  },
  'dateLabel': {
    'zh-Hans': '成书年代',
    'zh-Hant': '成書年代',
    'en': 'Date',
  },
  'audienceLabel': {
    'zh-Hans': '原始读者',
    'zh-Hant': '原始讀者',
    'en': 'Audience',
  },
  'themesLabel': {
    'zh-Hans': '主题',
    'zh-Hant': '主題',
    'en': 'Themes',
  },
  'keyPassageLabel': {
    'zh-Hans': '关键经文',
    'zh-Hant': '關鍵經文',
    'en': 'Key passage',
  },
  'cloudSyncing': {
    'zh-Hans': '同步中…',
    'zh-Hant': '同步中…',
    'en': 'Syncing…',
  },
  'cloudSynced': {
    'zh-Hans': '已同步',
    'zh-Hant': '已同步',
    'en': 'Synced',
  },
  'cloudError': {
    'zh-Hans': '同步出错',
    'zh-Hant': '同步出錯',
    'en': 'Sync error',
  },
  'cloudNotConfigured': {
    'zh-Hans': '仅本地',
    'zh-Hant': '僅本地',
    'en': 'Local only',
  },
  'cloudNotSignedIn': {
    'zh-Hans': '未登录',
    'zh-Hant': '未登入',
    'en': 'Not signed in',
  },
  'cloudPrivacyNotice': {
    'zh-Hans': '云端同步使用您自己的 Firebase 项目。每个用户只能读写自己的数据。',
    'zh-Hant': '雲端同步使用您自己的 Firebase 專案。每個用戶只能讀寫自己的資料。',
    'en':
        'Cloud sync uses your own Firebase project. Each user can only read their own data.',
  },
  'crossRefsNone': {
    'zh-Hans': '此节经文暂无人工整理的相互参照。',
    'zh-Hant': '此節經文暫無人工整理的相互參照。',
    'en': 'No curated cross-references for this verse yet.',
  },
  'boldVerseText': {
    'zh-Hans': '加粗经文',
    'zh-Hant': '加粗經文',
    'en': 'Bold verse text',
  },
  'boldVerseTextSubtitle': {
    'zh-Hans': '将经文正文以半粗体呈现。',
    'zh-Hant': '將經文正文以半粗體呈現。',
    'en': 'Render scripture body text in semi-bold weight.',
  },
  'showStrongsBadge': {
    'zh-Hans': '在词卡显示 Strong\'s 号',
    'zh-Hant': '在詞卡顯示 Strong\'s 號',
    'en': "Show Strong's number on word chips",
  },
  'showStrongsBadgeSubtitle': {
    'zh-Hans': '在释经面板每个希伯来/希腊词卡下方显示 G####/H#### 徽标。',
    'zh-Hant': '在釋經面板每個希伯來/希臘詞卡下方顯示 G####/H#### 徽標。',
    'en': "Display the G#### / H#### badge under each Hebrew/Greek word in the exegesis sheet.",
  },
  'autoExpandFirstRef': {
    'zh-Hans': '自动展开首个经文分组',
    'zh-Hant': '自動展開首個經文分組',
    'en': 'Auto-expand first verse group',
  },
  'autoExpandFirstRefSubtitle': {
    'zh-Hans': '在释经面板自动打开第一处经文分组,免去一次点击。',
    'zh-Hant': '在釋經面板自動打開第一處經文分組,免去一次點擊。',
    'en': "Automatically open the first book group of concordance refs in the exegesis sheet.",
  },
  'zoomIn': {'zh-Hans': '放大', 'zh-Hant': '放大', 'en': 'Zoom in'},
  'zoomOut': {'zh-Hans': '缩小', 'zh-Hant': '縮小', 'en': 'Zoom out'},
  'zoomReset': {'zh-Hans': '重置', 'zh-Hant': '重置', 'en': 'Reset zoom'},
  'summary': {'zh-Hans': '汇总', 'zh-Hant': '匯總', 'en': 'Summary'},
  'statWords': {'zh-Hans': '词数', 'zh-Hant': '詞數', 'en': 'Words'},
  'statTotal': {
    'zh-Hans': '总出现次数',
    'zh-Hant': '總出現次數',
    'en': 'Total occurrences',
  },
  'statTopBook': {
    'zh-Hans': '出现最多的书卷',
    'zh-Hant': '出現最多的書卷',
    'en': 'Most frequent book',
  },
  'statCanon': {'zh-Hans': '正典', 'zh-Hant': '正典', 'en': 'Canon'},
  'colStrongs': {
    'zh-Hans': '编号',
    'zh-Hant': '編號',
    'en': "Strong's",
  },
  'bothTestaments': {
    'zh-Hans': '新旧约对照',
    'zh-Hant': '新舊約對照',
    'en': 'Both Testaments',
  },
  'colTotal': {
    'zh-Hans': '总',
    'zh-Hant': '總',
    'en': 'Total',
  },
  'colGospelsActs': {
    'zh-Hans': '福音+徒',
    'zh-Hant': '福音+徒',
    'en': 'G&A',
  },
  'colPauline': {
    'zh-Hans': '保罗',
    'zh-Hant': '保羅',
    'en': 'Paul',
  },
  'colJohannine': {
    'zh-Hans': '约翰',
    'zh-Hant': '約翰',
    'en': 'John',
  },
  'colOtherApostolic': {
    'zh-Hans': '其他',
    'zh-Hant': '其他',
    'en': 'Other',
  },
  'colPentateuch': {
    'zh-Hans': '律法',
    'zh-Hant': '律法',
    'en': 'Torah',
  },
  'colHistory': {
    'zh-Hans': '历史',
    'zh-Hant': '歷史',
    'en': 'Hist.',
  },
  'colWisdom': {
    'zh-Hans': '智慧',
    'zh-Hant': '智慧',
    'en': 'Wisd.',
  },
  'colMajorProphets': {
    'zh-Hans': '大先知',
    'zh-Hant': '大先知',
    'en': 'Maj.Pr.',
  },
  'colMinorProphets': {
    'zh-Hans': '小先知',
    'zh-Hant': '小先知',
    'en': 'Min.Pr.',
  },
  'lxxEquivalents': {
    'zh-Hans': '七十士译本对应',
    'zh-Hant': '七十士譯本對應',
    'en': 'LXX Equivalents',
  },
  'hebrewSources': {
    'zh-Hans': '希伯来源词',
    'zh-Hant': '希伯來源詞',
    'en': 'Hebrew Sources',
  },
  'fullStudy': {
    'zh-Hans': '完整研经',
    'zh-Hant': '完整研經',
    'en': 'Full study',
  },
  'moreRefs': {
    'zh-Hans': '处更多',
    'zh-Hant': '處更多',
    'en': 'more',
  },
  'collapse': {
    'zh-Hans': '收起',
    'zh-Hant': '收起',
    'en': 'Collapse',
  },
  'wordFamily': {
    'zh-Hans': '同源词',
    'zh-Hant': '同源詞',
    'en': 'Word Family',
  },
  'synonyms': {
    'zh-Hans': '同义词',
    'zh-Hant': '同義詞',
    'en': 'Synonyms',
  },
  'concordanceBookCount': {
    'zh-Hans': '出现 {count} 次',
    'zh-Hant': '出現 {count} 次',
    'en': '{count} occurrences',
  },
  'concordanceNoMatchInVersion': {
    'zh-Hans': '此版本未找到该经节',
    'zh-Hant': '此版本未找到該經節',
    'en': 'This verse is not available in the current version',
  },
  'removeHighlight': {
    'zh-Hans': '移除高亮',
    'zh-Hant': '移除高亮',
    'en': 'Remove highlight',
  },
  'highlightColor': {
    'zh-Hans': '高亮颜色',
    'zh-Hant': '高亮顏色',
    'en': 'Highlight color',
  },
  'menuScale': {
    'zh-Hans': '菜单大小',
    'zh-Hant': '選單大小',
    'en': 'Menu Size',
  },
  'listView': {
    'zh-Hans': '列表',
    'zh-Hant': '列表',
    'en': 'List',
  },
  'gridView': {
    'zh-Hans': '网格',
    'zh-Hant': '網格',
    'en': 'Grid',
  },

  // ====== Settings Page ======
  'themeMode': {
    'zh-Hans': '主题模式',
    'zh-Hant': '主題模式',
    'en': 'Theme Mode',
  },
  'themeDay': {
    'zh-Hans': '白天模式',
    'zh-Hant': '白天模式',
    'en': 'Light Mode',
  },
  'themeNight': {
    'zh-Hans': '夜间模式',
    'zh-Hant': '夜間模式',
    'en': 'Dark Mode',
  },
  'themeSystem': {
    'zh-Hans': '跟随系统',
    'zh-Hant': '跟隨系統',
    'en': 'System Default',
  },
  'themeLight': {
    'zh-Hans': '亮色模式',
    'zh-Hant': '亮色模式',
    'en': 'Light Mode',
  },
  'themeDark': {
    'zh-Hans': '暗色模式',
    'zh-Hant': '暗色模式',
    'en': 'Dark Mode',
  },
  'settings': {
    'zh-Hans': '设置',
    'zh-Hant': '設定',
    'en': 'Settings',
  },
  // 2026-05-07 (v12): feedback page -- mailto-driven user feedback
  // form. Strings used by the dashboard tile, the page chrome, and
  // the form fields / hints / outcomes.
  'feedback': {
    'zh-Hans': '意见反馈',
    'zh-Hant': '意見回饋',
    'en': 'Feedback',
  },
  'feedbackIntro': {
    'zh-Hans': '点击「发送」即可直接寄到开发者的邮箱。'
        '如果服务暂时不可用，会自动打开您的邮件应用作为备用。',
    'zh-Hant': '點擊「發送」即可直接寄到開發者的信箱。'
        '如果服務暫時不可用，會自動開啟您的郵件應用作為備用。',
    'en':
        'Tap "Send" and your feedback goes straight to the developer\'s '
            'inbox. If the service is temporarily unavailable, your mail '
            'app opens as a fallback.',
  },
  'feedbackCategoryLabel': {
    'zh-Hans': '反馈类别',
    'zh-Hant': '回饋類別',
    'en': 'What is this about?',
  },
  'feedbackCategoryBug': {
    'zh-Hans': 'Bug 报告',
    'zh-Hant': 'Bug 回報',
    'en': 'Bug report',
  },
  'feedbackCategoryFeature': {
    'zh-Hans': '功能建议',
    'zh-Hant': '功能建議',
    'en': 'Feature request',
  },
  'feedbackCategoryGeneral': {
    'zh-Hans': '一般反馈',
    'zh-Hant': '一般回饋',
    'en': 'General feedback',
  },
  'feedbackCategoryContent': {
    'zh-Hans': '内容/翻译问题',
    'zh-Hant': '內容/翻譯問題',
    'en': 'Content / translation',
  },
  'feedbackMessageLabel': {
    'zh-Hans': '反馈内容 *',
    'zh-Hant': '回饋內容 *',
    'en': 'Your message *',
  },
  'feedbackMessageHint': {
    'zh-Hans': '请描述您遇到的问题、想要的功能或想分享的想法。',
    'zh-Hant': '請描述您遇到的問題、想要的功能或想分享的想法。',
    'en': 'Describe the bug, feature, or thought.',
  },
  'feedbackMessageRequired': {
    'zh-Hans': '请先填写反馈内容再发送。',
    'zh-Hant': '請先填寫回饋內容再發送。',
    'en': 'Please write a message before sending.',
  },
  'feedbackNameLabel': {
    'zh-Hans': '您的名字（选填）',
    'zh-Hant': '您的名字（選填）',
    'en': 'Your name (optional)',
  },
  // 2026-05-07 (v16): single optional reply-to field (replaces the
  // v15 "send me a copy" UI, which depended on Resend domain
  // verification that the user opted out of). Pre-filled with the
  // signed-in email; guests start blank.
  'feedbackReplyToLabel': {
    'zh-Hans': '回复邮箱（选填）',
    'zh-Hant': '回覆信箱（選填）',
    'en': 'Reply-to email (optional)',
  },
  'feedbackSend': {
    'zh-Hans': '发送',
    'zh-Hant': '發送',
    'en': 'Send',
  },
  'feedbackSending': {
    'zh-Hans': '正在发送…',
    'zh-Hant': '正在發送…',
    'en': 'Sending…',
  },
  'feedbackSent': {
    'zh-Hans': '反馈已发送，谢谢您！',
    'zh-Hant': '回饋已發送，謝謝您！',
    'en': 'Feedback sent. Thank you!',
  },
  'feedbackErrorPrefix': {
    'zh-Hans': '发送失败：',
    'zh-Hant': '發送失敗：',
    'en': 'Could not send feedback: ',
  },
  'feedbackOpenedMail': {
    'zh-Hans': '已打开邮件应用，请点击发送即可送达。',
    'zh-Hant': '已開啟郵件應用，請點擊發送即可送達。',
    'en': 'Mail app opened. Tap Send to deliver your feedback.',
  },
  'feedbackCopiedFallback': {
    'zh-Hans': '邮件应用不可用，反馈已复制到剪贴板。'
        '请粘贴到您的邮件中发到 paulsyliu@gmail.com。',
    'zh-Hant': '郵件應用不可用，回饋已複製到剪貼簿。'
        '請貼到您的郵件中發到 paulsyliu@gmail.com。',
    'en':
        'Mail app unavailable — feedback copied to clipboard. '
            'Paste it into your email to paulsyliu@gmail.com.',
  },
  'feedbackPrivacyNote': {
    'zh-Hans': '为方便排查问题，发送时会一并附上：界面语言、圣经版本、'
        '当前阅读位置、屏幕尺寸与主题、时区与提交时间、'
        '浏览器与系统信息（IP 由服务器自动记录）。'
        '只用于回复您和定位问题，不会用于其他用途。',
    'zh-Hant': '為方便排查問題，發送時會一併附上：介面語言、聖經版本、'
        '當前閱讀位置、螢幕尺寸與主題、時區與提交時間、'
        '瀏覽器與系統資訊（IP 由伺服器自動記錄）。'
        '只用於回覆您和定位問題，不會用於其他用途。',
    'en':
        'To help debug your report, the submission also includes: '
            'app locale, Bible version, last position, screen size + '
            'theme, timezone + timestamp, browser + OS (IP is logged '
            'server-side). Used only to reply and reproduce — nothing '
            'else.',
  },
  'interfaceLanguage': {
    'zh-Hans': '界面语言',
    'zh-Hant': '介面語言',
    'en': 'Interface Language',
  },
  'fontSize': {
    'zh-Hans': '字体大小',
    'zh-Hant': '字體大小',
    'en': 'Font Size',
  },
  'lineSpacing': {
    'zh-Hans': '行距',
    'zh-Hant': '行距',
    'en': 'Line Spacing',
  },
  'fontFamily': {
    'zh-Hans': '字体',
    'zh-Hant': '字體',
    'en': 'Font Family',
  },
  'primaryColor': {
    'zh-Hans': '主色调',
    'zh-Hant': '主色調',
    'en': 'Primary Colour',
  },
  'samplePreview': {
    'zh-Hans': '预览示范',
    'zh-Hant': '預覽示範',
    'en': 'Sample Preview',
  },
  'copyFormat': {
    'zh-Hans': '复制格式',
    'zh-Hant': '複製格式',
    'en': 'Copy Format',
  },
  'plainText': {
    'zh-Hans': '纯文字',
    'zh-Hant': '純文字',
    'en': 'Plain Text',
  },
  'withReference': {
    'zh-Hans': '包含经文参考',
    'zh-Hant': '包含經文參考',
    'en': 'Include Reference',
  },
  'devotionalFormat': {
    'zh-Hans': '灵修格式',
    'zh-Hant': '靈修格式',
    'en': 'Devotional Format',
  },
  'copyPreview': {
    'zh-Hans': '复制预览',
    'zh-Hant': '複製預覽',
    'en': 'Copy Preview',
  },
  'copied': {
    'zh-Hans': '已复制！',
    'zh-Hant': '已複製！',
    'en': 'Copied!',
  },
  'sendFeedback': {
    'zh-Hans': '发送反馈',
    'zh-Hant': '發送反饋',
    'en': 'Send Feedback',
  },
  'feedbackHint': {
    'zh-Hans': '请输入您的意见或建议（最多500字）...',
    'zh-Hant': '請輸入您的意見或建議（最多500字）...',
    'en': 'Please enter your feedback (up to 500 characters)...',
  },
  'feedbackSuccess': {
    'zh-Hans': '✅ 已成功发送，谢谢反馈！',
    'zh-Hant': '✅ 發送成功，感謝您的反饋！',
    'en': '✅ Feedback sent. Thank you!',
  },
  'feedbackFailure': {
    'zh-Hans': '❌ 发送失败，请稍后重试。',
    'zh-Hant': '❌ 發送失敗，請稍後重試。',
    'en': '❌ Failed to send. Please try again.',
  },
  'ok': {
    'zh-Hans': '确定',
    'zh-Hant': '確定',
    'en': 'OK',
  },

  'feedbackEmpty': {
    'zh-Hans': '❗️发送内容不能为空，请输入反馈内容。',
    'zh-Hant': '❗️發送內容不能為空，請輸入反饋內容。',
    'en': '❗️Feedback content cannot be empty. Please enter your feedback.',
  },
  'feedbackTooLong': {
    'zh-Hans': '❗️内容超过最大长度（500字），请删减后再发送。',
    'zh-Hant': '❗️內容超過最大長度（500字），請刪減後再發送。',
    'en':
        '❗️Content exceeds the maximum length (500 characters). Please shorten it before sending.',
  },
  'feedbackInvalid': {
    'zh-Hans': '❗️内容包含不支持的符号（如表情符号），请移除后再发送。',
    'zh-Hant': '❗️內容包含不支援的符號（如表情符號），請移除後再發送。',
    'en':
        '❗️Content contains unsupported symbols (such as emojis). Please remove them before sending.',
  },
  'note': {
    'zh-Hans': '注释',
    'zh-Hant': '註釋',
    'en': 'Note',
  },
  'close': {
    'zh-Hans': '关闭',
    'zh-Hant': '關閉',
    'en': 'Close',
  },
  'copiedVerse': {
    'zh-Hans': '已复制第{verse}节',
    'zh-Hant': '已複製第{verse}節',
    'en': 'Copied verse {verse}',
  },
  'noVersesAvailable': {
    'zh-Hans': '暂无经文',
    'zh-Hant': '暫無經文',
    'en': 'No verses available',
  },
  'chapterUnavailable': {
    'zh-Hans': '当前版本没有这一章。',
    'zh-Hant': '目前版本沒有這一章。',
    'en': 'This chapter is not available in the current version.',
  },
  'loadErrorTitle': {
    'zh-Hans': '加载失败',
    'zh-Hant': '載入失敗',
    'en': 'Failed to load',
  },
  // 2026-05-10 (v1.2.29): localised label for the close-pane
  // IconButton tooltip in `bible_reading_pane.dart` (sibling
  // `back` tooltip was already localised; `close` was not).
  'tooltipClose': {
    'zh-Hans': '关闭',
    'zh-Hant': '關閉',
    'en': 'Close',
  },
  // 2026-05-10 (v1.2.29): generic "Couldn't parse: $x" SnackBar
  // shown when a reference parse fails. Used across 7 surfaces
  // (library / news_detail / evidence / evidence_detail /
  // bible_timeline / dashboard / person_detail_sheet). `{ref}`
  // placeholder gets the raw input that failed.
  'couldNotParseRef': {
    'zh-Hans': '无法解析引用：{ref}',
    'zh-Hant': '無法解析引用：{ref}',
    'en': "Couldn't parse reference: {ref}",
  },
  // 2026-05-10 (v1.2.29): rendered when a sermon's `body.txt` is
  // missing on disk. Keeps zh users from seeing the English
  // fallback string in `sermon_detail_page.dart`.
  'sermonNoBody': {
    'zh-Hans': '本篇讲道没有文字内容。',
    'zh-Hant': '本篇講道沒有文字內容。',
    'en': 'No body text available for this sermon.',
  },
  'loadErrorBody': {
    'zh-Hans': '无法加载圣经经文，请检查网络或重试。',
    'zh-Hant': '無法載入聖經經文，請檢查網絡或重試。',
    'en': 'Could not load Bible verses. Please check your connection and retry.',
  },
  // 2026-05-10 (v1.2.10): in-flight progress strings shown on the
  // splash while FetchVerses.execute() is retrying. Keeps users
  // from thinking the app is frozen during a slow first-load.
  // `{n}` and `{max}` are runtime-replaced with attempt index +
  // max attempts (e.g. "Retrying… (2/3)").
  'loadingVerses': {
    'zh-Hans': '正在加载经文…',
    'zh-Hant': '正在載入經文…',
    'en': 'Loading verses…',
  },
  // 2026-07-21: shown on LoadingPage's friendly "still booting"
  // scaffold — deliberately upbeat rather than a generic "loading",
  // since this replaces what used to be a false-positive "Failed to
  // load" flash on slow connections.
  'bootLoadingMessage': {
    'zh-Hans': '飞快加载中…',
    'zh-Hant': '飛快載入中…',
    'en': 'Loading fast…',
  },
  'retryingAttempt': {
    'zh-Hans': '重试中…（第 {n}/{max} 次）',
    'zh-Hant': '重試中…（第 {n}/{max} 次）',
    'en': 'Retrying… ({n}/{max})',
  },
  // 2026-05-10 (v1.2.18): user opted into eager pre-load of all
  // 13 Bible versions during boot ("反正第一次用才 load version,
  // 就全部 load 吧"). Splash now paints this subtitle while the
  // sequential parse runs — typically ~20–30 s on cold boot, less
  // on warm SW cache. After boot, every version + chapter switch
  // is a cache hit (instant, no overlay) for the rest of the
  // session.
  'loadingVersionsProgress': {
    'zh-Hans': '正在加载译本：{n}/{total}',
    'zh-Hant': '正在載入譯本：{n}/{total}',
    'en': 'Loading versions: {n}/{total}',
  },
  'retry': {
    'zh-Hans': '重试',
    'zh-Hant': '重試',
    'en': 'Retry',
  },
  // 2026-05-10 (v1.2.12): user reported v1.2.10's auto-retry still
  // showed "Failed to load" on first cold-start ("dev still failed
  // load 我重进才 load"). Root cause: Flutter web's rootBundle
  // memoises the in-flight Future per-asset, so v1.2.10's 3
  // retries collapsed into 1 effective fetch. Real fix lives in
  // fetch_verses.dart (rootBundle.clear before each retry +
  // 20 s timeout). The error scaffold below adds a second
  // escape-hatch button — if even the new retry can't recover
  // (e.g. a stale service-worker bundle baked from a prior
  // deploy), one tap nukes all SW + cache buckets and reloads the
  // page, no localStorage touched.
  'hardReloadPage': {
    'zh-Hans': '清除缓存并重新加载',
    'zh-Hant': '清除快取並重新載入',
    'en': 'Reload page (clear cache)',
  },
  'showDetails': {
    'zh-Hans': '显示详情',
    'zh-Hant': '顯示詳情',
    'en': 'Show details',
  },
  // Reload-from-anywhere action — surfaces in the floating-header
  // overflow menu and the empty-reader recovery screen so the user
  // always has a one-tap fix when verses fail to load mid-session
  // (instead of having to relaunch the app).
  'reload': {
    'zh-Hans': '重新加载',
    'zh-Hant': '重新載入',
    'en': 'Reload',
  },
  'reloading': {
    'zh-Hans': '正在重新加载…',
    'zh-Hant': '正在重新載入…',
    'en': 'Reloading…',
  },
  'reloaded': {
    'zh-Hans': '已重新加载',
    'zh-Hant': '已重新載入',
    'en': 'Reloaded',
  },
  // 2026-05-07 (v17): offlineMode / offlineModeSubtitle /
  // checkForUpdates / checkForUpdatesSubtitle / updatesAvailableTitle
  // / updatesAvailableBody were removed when the matching Settings
  // controls were deleted (the toggle was dead, the dialog was
  // theatre). The "Offline pack" card (kept) has its own strings.
  'chapters': {
    'zh-Hans': '章',
    'zh-Hant': '章',
    'en': 'ch',
  },
  'bible': {
    'zh-Hans': '圣经',
    'zh-Hant': '聖經',
    'en': 'Bible',
  },
  'readingMode': {
    'zh-Hans': '阅读模式',
    'zh-Hant': '閱讀模式',
    'en': 'Reading Mode',
  },
  'verseByVerse': {
    'zh-Hans': '逐节显示',
    'zh-Hant': '逐節顯示',
    'en': 'Verse by Verse',
  },
  'paragraphFlow': {
    'zh-Hans': '段落排版',
    'zh-Hant': '段落排版',
    'en': 'Paragraph Flow',
  },

  // ====== Illustrations (formerly "Maps" — now also covers parable
  // scenes, narrative paintings, prophecy imagery, etc.) ======
  'maps': {
    'zh-Hans': '插图',
    'zh-Hant': '插畫',
    'en': 'Illustrations',
  },
  'sermons': {
    'zh-Hans': '讲道',
    'zh-Hant': '講道',
    'en': 'Sermons',
  },
  'sermon': {
    'zh-Hans': '讲道',
    'zh-Hant': '講道',
    'en': 'Sermon',
  },
  'sermonsTagline': {
    'zh-Hans': '张熙和牧师讲道集',
    'zh-Hant': '張熙和牧師講道集',
    'en': "Pastor Eric Chang's sermon library",
  },
  'sermonSearchHint': {
    'zh-Hans': '按标题、经文或编号搜索讲道…',
    'zh-Hant': '按標題、經文或編號搜尋講道…',
    'en': 'Search sermons by title, passage or ID…',
  },
  'sermonCountTemplate': {
    'zh-Hans': '{count} 篇讲道,共 {topics} 个主题',
    'zh-Hant': '{count} 篇講道,共 {topics} 個主題',
    'en': '{count} sermons across {topics} topics',
  },
  'sermonGroupCount': {
    'zh-Hans': '{count} 篇',
    'zh-Hant': '{count} 篇',
    'en': '{count} sermon(s)',
  },
  'relatedSermons': {
    'zh-Hans': '相关讲道',
    'zh-Hant': '相關講道',
    'en': 'Related sermons',
  },
  'noRelatedSermons': {
    'zh-Hans': '没有讲道引用这些经文。',
    'zh-Hant': '沒有講道引用這些經文。',
    'en': 'No sermons reference these verses.',
  },
  'sermonFilterByPassage': {
    'zh-Hans': '按经文筛选',
    'zh-Hant': '按經文篩選',
    'en': 'Filter by passage',
  },
  'aiExplainHeader': {
    'zh-Hans': 'AI 释义',
    'zh-Hant': 'AI 釋義',
    'en': 'AI explanation',
  },
  'aiExplainButton': {
    'zh-Hans': '让 AI 解释此词在这节经文中的含义（仅供参考）',
    'zh-Hant': '讓 AI 解釋此詞在這節經文中的含義（僅供參考）',
    'en':
        'Let AI explain this word in this verse (reference only)',
  },
  // v1.3.x: reading-pane selection-bar AI verse explanation.
  'aiExplainVerse': {
    'zh-Hans': 'AI 解释经文',
    'zh-Hant': 'AI 解釋經文',
    'en': 'AI explain',
  },
  'aiExplainVerseDisclaimer': {
    'zh-Hans': 'AI 生成的解释，仅供参考；请以圣经原文为准。',
    'zh-Hant': 'AI 生成的解釋，僅供參考；請以聖經原文為準。',
    'en':
        'AI-generated; for reference only — let Scripture itself be the authority.',
  },
  'aiExplainError': {
    'zh-Hans': 'AI 解释暂时不可用，请稍后再试。',
    'zh-Hant': 'AI 解釋暫時不可用，請稍後再試。',
    'en': 'AI explanation is not available right now.',
  },
  // v1.3.68: optional "ask a question about this passage" box in the
  // reading-pane AI panel.
  'aiAskQuestionHint': {
    'zh-Hans': '想问关于这段经文的问题？（可选）',
    'zh-Hant': '想問關於這段經文的問題？（可選）',
    'en': 'Ask a question about this passage… (optional)',
  },
  'aiAskSend': {
    'zh-Hans': '提问',
    'zh-Hant': '提問',
    'en': 'Ask',
  },
  'aiAskYourQuestion': {
    'zh-Hans': '你的问题',
    'zh-Hant': '你的問題',
    'en': 'Your question',
  },
  'aiAskAnswering': {
    'zh-Hans': '正在回答你的问题…',
    'zh-Hant': '正在回答你的問題…',
    'en': 'Answering your question…',
  },
  'aiAskClear': {
    'zh-Hans': '返回经文解释',
    'zh-Hant': '返回經文解釋',
    'en': 'Back to explanation',
  },
  'aiExplainScriptureLabel': {
    'zh-Hans': '经文',
    'zh-Hant': '經文',
    'en': 'Scripture',
  },
  // v1.3.71: panel no longer auto-generates on open — the user confirms
  // first (empty question ⇒ explanation, with question ⇒ answer).
  'aiExplainIdleHint': {
    'zh-Hans': '可以直接生成这段经文的解释，或先输入你的问题再确认。',
    'zh-Hant': '可以直接生成這段經文的解釋，或先輸入你的問題再確認。',
    'en':
        'Generate an explanation of this passage, or type a question first and confirm.',
  },
  'aiExplainGenerate': {
    'zh-Hans': '解释这段经文',
    'zh-Hant': '解釋這段經文',
    'en': 'Explain this passage',
  },
  'aiExplainGenerating': {
    'zh-Hans': '正在生成解释…',
    'zh-Hant': '正在生成解釋…',
    'en': 'Generating explanation…',
  },
  // v1.3.73: multi-turn study chat — follow-ups, length controls,
  // save-to-note.
  'aiFollowUpHint': {
    'zh-Hans': '继续追问…',
    'zh-Hant': '繼續追問…',
    'en': 'Ask a follow-up…',
  },
  'aiMoreConcise': {
    'zh-Hans': '更简短',
    'zh-Hant': '更簡短',
    'en': 'More concise',
  },
  'aiMoreDetail': {
    'zh-Hans': '更详细',
    'zh-Hant': '更詳細',
    'en': 'More detail',
  },
  'aiSaveToNote': {
    'zh-Hans': '存入笔记',
    'zh-Hant': '存入筆記',
    'en': 'Save to note',
  },
  'aiNoteAttribution': {
    'zh-Hans': '——YsWords AI 生成，仅供参考',
    'zh-Hant': '——YsWords AI 生成，僅供參考',
    'en': '— generated by YsWords AI, for reference',
  },
  'aiExplainAsking': {
    'zh-Hans': 'AI 正在生成解释…',
    'zh-Hant': 'AI 正在生成解釋…',
    'en': 'AI is generating an explanation…',
  },
  'aiExplainRegenerate': {
    'zh-Hans': '重新生成',
    'zh-Hant': '重新生成',
    'en': 'Regenerate',
  },
  'aiExplainDisclaimer': {
    'zh-Hans': 'AI 生成内容仅供参考，如用于研经或教导请核对原始资料。',
    'zh-Hant': 'AI 生成內容僅供參考，如用於研經或教導請核對原始資料。',
    'en':
        'AI-generated content for reference only — verify with '
            'primary sources before using for study or teaching.',
  },
  'aiExplainTryAgain': {
    'zh-Hans': '重试',
    'zh-Hant': '重試',
    'en': 'Try again',
  },
  'aiExplainCopy': {
    'zh-Hans': '复制',
    'zh-Hant': '複製',
    'en': 'Copy',
  },
  'aiLengthLabel': {
    'zh-Hans': '长度',
    'zh-Hant': '長度',
    'en': 'Length',
  },
  'aiLengthConcise': {
    'zh-Hans': '更简短',
    'zh-Hant': '更簡短',
    'en': 'More concise',
  },
  'aiLengthLonger': {
    'zh-Hans': '更详细',
    'zh-Hant': '更詳細',
    'en': 'More detail',
  },
  'aiScopeLabel': {
    'zh-Hans': '范围',
    'zh-Hant': '範圍',
    'en': 'Scope',
  },
  'aiScopeVerse': {
    'zh-Hans': '本节经文',
    'zh-Hant': '本節經文',
    'en': 'In this verse',
  },
  'aiScopeChapter': {
    'zh-Hans': '本章',
    'zh-Hant': '本章',
    'en': 'In this chapter',
  },
  'aiScopeBook': {
    'zh-Hans': '本书卷',
    'zh-Hant': '本書卷',
    'en': 'In this book',
  },
  'aiScopeOtherChapters': {
    'zh-Hans': '其他章节',
    'zh-Hant': '其他章節',
    'en': 'Other chapters',
  },
  'aiScopeWholeBible': {
    'zh-Hans': '全本圣经',
    'zh-Hant': '全本聖經',
    'en': 'Whole Bible',
  },
  'aiScopeCrossTestament': {
    'zh-Hans': '跨新旧约',
    'zh-Hant': '跨新舊約',
    'en': 'Across testaments',
  },
  'aiScopeCrossTestamentNtToOt': {
    'zh-Hans': '旧约背景',
    'zh-Hant': '舊約背景',
    'en': 'OT background',
  },
  'aiScopeCrossTestamentOtToNt': {
    'zh-Hans': '新约对应',
    'zh-Hant': '新約對應',
    'en': 'NT echoes',
  },
  // 2026-05-07: BDAG-level deep exegesis chip — 5-section structured
  // analysis (lexical core / verse usage / cultural context /
  // canonical pattern / theological weight). Free-tier substitute
  // for what Logos+BDAG charges $200+ for.
  'aiScopeDeepExegesis': {
    'zh-Hans': '深度释经（BDAG 级 · YsWords 智能分析，仅供参考）',
    'zh-Hant': '深度釋經（BDAG 級 · YsWords 智慧分析，僅供參考）',
    'en': 'Deep exegesis (BDAG-level · YsWords AI, reference only)',
  },
  'familyTree': {
    'zh-Hans': '圣经家谱',
    'zh-Hant': '聖經家譜',
    'en': 'Family Tree',
  },
  'familyTreeSearchHint': {
    'zh-Hans': '按姓名或简介搜索…',
    'zh-Hant': '按姓名或簡介搜尋…',
    'en': 'Search by name or biography…',
  },
  'familyTreeFilterCount': {
    'zh-Hans': '匹配 {count} / 共 {total} 人',
    'zh-Hant': '匹配 {count} / 共 {total} 人',
    'en': '{count} of {total} people',
  },
  'familyTreeTotalCount': {
    'zh-Hans': '共 {total} 位人物',
    'zh-Hant': '共 {total} 位人物',
    'en': '{total} people',
  },
  'familyTreeNoMatches': {
    'zh-Hans': '没有匹配的人物',
    'zh-Hant': '沒有匹配的人物',
    'en': 'No one matches that search.',
  },
  'familyTreeParents': {
    'zh-Hans': '父母',
    'zh-Hant': '父母',
    'en': 'Parents',
  },
  'familyTreeFather': {
    'zh-Hans': '父',
    'zh-Hant': '父',
    'en': 'Father',
  },
  'familyTreeMother': {
    'zh-Hans': '母',
    'zh-Hant': '母',
    'en': 'Mother',
  },
  'familyTreeSpouse': {
    'zh-Hans': '配偶',
    'zh-Hant': '配偶',
    'en': 'Spouse',
  },
  'familyTreeSpouses': {
    'zh-Hans': '配偶',
    'zh-Hant': '配偶',
    'en': 'Spouses',
  },
  'familyTreeChildren': {
    'zh-Hans': '子女',
    'zh-Hant': '子女',
    'en': 'Children',
  },
  'familyTreeReferences': {
    'zh-Hans': '相关经文',
    'zh-Hant': '相關經文',
    'en': 'Verse references',
  },
  'familyTreeAncestry': {
    'zh-Hans': '父系家谱',
    'zh-Hant': '父系家譜',
    'en': 'Patrilineal ancestry',
  },
  'familyTreeViewList': {
    'zh-Hans': '列表视图',
    'zh-Hant': '列表檢視',
    'en': 'List view',
  },
  'familyTreeViewChart': {
    'zh-Hans': '图表视图',
    'zh-Hant': '圖表檢視',
    'en': 'Chart view',
  },
  'familyTreeLongPressRefocus': {
    'zh-Hans': '点击查看详情 · 长按聚焦此人',
    'zh-Hant': '點擊查看詳情 · 長按聚焦此人',
    'en': 'Tap for details · long-press to focus',
  },
  'familyTreeTapRefocus': {
    'zh-Hans': '点击展开此人 · 点击 ⓘ 查看详情',
    'zh-Hant': '點擊展開此人 · 點擊 ⓘ 查看詳情',
    'en': 'Tap to expand · ⓘ for details',
  },
  'familyTreeOpenDetails': {
    'zh-Hans': '查看详情',
    'zh-Hant': '查看詳情',
    'en': 'Details',
  },
  'familyTreeOrphanMatches': {
    'zh-Hans': '其他匹配（不在亚当谱系中）',
    'zh-Hant': '其他匹配（不在亞當譜系中）',
    'en': 'Other matches (not in the Adam lineage)',
  },
  'familyTreePrevMatch': {
    'zh-Hans': '上一个匹配',
    'zh-Hant': '上一個匹配',
    'en': 'Previous match',
  },
  'familyTreeNextMatch': {
    'zh-Hans': '下一个匹配',
    'zh-Hant': '下一個匹配',
    'en': 'Next match',
  },
  'familyTreeSiblings': {
    'zh-Hans': '兄弟姐妹',
    'zh-Hant': '兄弟姐妹',
    'en': 'Siblings',
  },
  'familyTreeTribeLine': {
    'zh-Hans': '所属支派 / 世系',
    'zh-Hant': '所屬支派 / 世系',
    'en': 'Tribe / line',
  },
  'familyTreeJumpAdam': {
    'zh-Hans': '亚当',
    'zh-Hant': '亞當',
    'en': 'Adam',
  },
  'familyTreeJumpNoah': {
    'zh-Hans': '挪亚',
    'zh-Hant': '挪亞',
    'en': 'Noah',
  },
  'familyTreeJumpAbraham': {
    'zh-Hans': '亚伯拉罕',
    'zh-Hant': '亞伯拉罕',
    'en': 'Abraham',
  },
  'familyTreeJumpMoses': {
    'zh-Hans': '摩西',
    'zh-Hant': '摩西',
    'en': 'Moses',
  },
  'familyTreeJumpDavid': {
    'zh-Hans': '大卫',
    'zh-Hant': '大衛',
    'en': 'David',
  },
  'familyTreeJumpExile': {
    'zh-Hans': '被掳',
    'zh-Hant': '被擄',
    'en': 'Exile',
  },
  'familyTreeJumpJesus': {
    'zh-Hans': '耶稣',
    'zh-Hant': '耶穌',
    'en': 'Jesus',
  },
  'familyTreeComparisonTitle': {
    'zh-Hans': '族谱对照表',
    'zh-Hant': '族譜對照表',
    'en': 'Comparison of genealogies',
  },
  'familyTreeComparisonSubtitle': {
    'zh-Hans': '亚当 → 耶稣，按经文出处对照',
    'zh-Hant': '亞當 → 耶穌，按經文出處對照',
    'en': 'Adam → Jesus by canonical Bible source',
  },
  'familyTreeColGen': {
    'zh-Hans': '世代',
    'zh-Hant': '世代',
    'en': 'Gen',
  },
  'familyTreeColName': {
    'zh-Hans': '姓名',
    'zh-Hant': '姓名',
    'en': 'Name',
  },
  'familyTreeColYears': {
    'zh-Hans': '年代',
    'zh-Hant': '年代',
    'en': 'Years',
  },
  'familyTreeColGen5': {
    'zh-Hans': '创 5',
    'zh-Hant': '創 5',
    'en': 'Gen 5',
  },
  'familyTreeColGen11': {
    'zh-Hans': '创 11',
    'zh-Hant': '創 11',
    'en': 'Gen 11',
  },
  'familyTreeColChron1': {
    'zh-Hans': '代上 1',
    'zh-Hant': '代上 1',
    'en': '1 Chr 1',
  },
  'familyTreeColRuth4': {
    'zh-Hans': '得 4',
    'zh-Hant': '得 4',
    'en': 'Ruth 4',
  },
  'familyTreeColMatt1': {
    'zh-Hans': '太 1',
    'zh-Hant': '太 1',
    'en': 'Matt 1',
  },
  'familyTreeColLuke3': {
    'zh-Hans': '路 3',
    'zh-Hant': '路 3',
    'en': 'Luke 3',
  },
  // Era subtitles — one short line of orientation per section
  // (description + date range), shown under the section header.
  'familyTreeEraSubAntediluvian': {
    'en': 'Ten generations from Adam to Noah · AM 0 – 1656',
    'zh-Hans': '从亚当到挪亚十代 · 创世以来 0 – 1656 年',
    'zh-Hant': '從亞當到挪亞十代 · 創世以來 0 – 1656 年',
  },
  'familyTreeEraSubPostFlood': {
    'en': 'Shem to Terah, post-Flood patriarchs · ~BC 2400 – 2000',
    'zh-Hans': '闪到他拉，洪水后的列祖 · 约公元前 2400 – 2000',
    'zh-Hant': '閃到他拉，洪水後的列祖 · 約公元前 2400 – 2000',
  },
  'familyTreeEraSubPatriarchs': {
    'en': 'Abraham, Isaac, Jacob & the twelve tribes · ~BC 2200 – 1700',
    'zh-Hans': '亚伯拉罕、以撒、雅各与十二支派 · 约公元前 2200 – 1700',
    'zh-Hant': '亞伯拉罕、以撒、雅各與十二支派 · 約公元前 2200 – 1700',
  },
  'familyTreeEraSubMosaic': {
    'en': 'Aaron the High Priest, Moses the Lawgiver & Miriam · ~BC 1500 – 1400',
    'zh-Hans': '大祭司亚伦、律法颁布者摩西、米利暗 · 约公元前 1500 – 1400',
    'zh-Hant': '大祭司亞倫、律法頒布者摩西、米利暗 · 約公元前 1500 – 1400',
  },
  'familyTreeEraSubDavidic': {
    'en': 'Perez through Boaz & Ruth to Jesse, father of David · ~BC 1900 – 1050',
    'zh-Hans': '法勒斯经波阿斯和路得到大卫之父耶西 · 约公元前 1900 – 1050',
    'zh-Hant': '法勒斯經波阿斯和路得到大衛之父耶西 · 約公元前 1900 – 1050',
  },
  'familyTreeEraSubKings': {
    'en': 'Kings of Judah from David to Jeconiah · BC 1010 – 586',
    'zh-Hans': '犹大列王，从大卫到耶哥尼雅 · 公元前 1010 – 586',
    'zh-Hant': '猶大列王，從大衛到耶哥尼雅 · 公元前 1010 – 586',
  },
  'familyTreeEraSubExile': {
    'en': 'Shealtiel through Matthan to Joseph (Matthew 1:13–16)',
    'zh-Hans': '撒拉铁经马但到约瑟（马太福音 1:13–16）',
    'zh-Hant': '撒拉鐵經馬但到約瑟（馬太福音 1:13–16）',
  },
  'familyTreeEraSubLukan': {
    'en': "Mary's lineage per Luke 3:23–31 (Nathan → … → Heli → Mary)",
    'zh-Hans': '路加福音 3:23–31 所记马利亚的家谱（拿单 → … → 希里 → 马利亚）',
    'zh-Hant': '路加福音 3:23–31 所記馬利亞的家譜（拿單 → … → 希里 → 馬利亞）',
  },
  'familyTreeEraSubNt': {
    'en': 'The earthly family of Jesus the Messiah · ~BC 5 – AD 30',
    'zh-Hans': '弥赛亚耶稣的地上家庭 · 约公元前 5 – 公元 30',
    'zh-Hant': '彌賽亞耶穌的地上家庭 · 約公元前 5 – 公元 30',
  },
  'familyTreeExpandAll': {
    'en': 'Expand all',
    'zh-Hans': '全部展开',
    'zh-Hant': '全部展開',
  },
  'familyTreeCollapseAll': {
    'en': 'Collapse all',
    'zh-Hans': '全部收起',
    'zh-Hant': '全部收起',
  },
  'familyTreeContinuesWith': {
    'en': 'Continues with',
    'zh-Hans': '下一位',
    'zh-Hant': '下一位',
  },
  'familyTreeCopyAll': {
    'en': 'Copy all info',
    'zh-Hans': '复制全部信息',
    'zh-Hant': '複製全部資訊',
  },
  'familyTreeCopiedToast': {
    'en': 'Copied to clipboard',
    'zh-Hans': '已复制到剪贴板',
    'zh-Hant': '已複製到剪貼簿',
  },
  'familyTreeCopyFailedToast': {
    'en': 'Copy failed — clipboard not available',
    'zh-Hans': '复制失败 — 剪贴板不可用',
    'zh-Hant': '複製失敗 — 剪貼簿不可用',
  },
  'familyTreeRole': {
    'en': 'Role',
    'zh-Hans': '身份',
    'zh-Hant': '身份',
  },
  // Bible timeline page
  'bibleTimeline': {
    'en': 'Bible Timeline',
    'zh-Hans': '圣经时间轴',
    'zh-Hant': '聖經時間軸',
  },
  'bibleTimelineSearchHint': {
    'en': 'Search events…',
    'zh-Hans': '搜索事件…',
    'zh-Hant': '搜尋事件…',
  },
  'bibleTimelineCount': {
    'en': '{count} events',
    'zh-Hans': '{count} 项事件',
    'zh-Hant': '{count} 項事件',
  },
  'bibleTimelineNoMatches': {
    'en': 'No events match.',
    'zh-Hans': '未找到符合的事件。',
    'zh-Hant': '未找到符合的事件。',
  },
  // Share-link toasts (sermons + bible verses)
  'shareLink': {
    'en': 'Share',
    'zh-Hans': '分享',
    'zh-Hant': '分享',
  },
  'shareLinkCopied': {
    'en': 'Share link copied',
    'zh-Hans': '分享链接已复制',
    'zh-Hant': '分享連結已複製',
  },
  'shareLinkFailed': {
    'en': 'Copy failed — clipboard unavailable',
    'zh-Hans': '复制失败 — 剪贴板不可用',
    'zh-Hant': '複製失敗 — 剪貼簿不可用',
  },
  // Sermon copy-all (full body + attribution footer)
  'sermonCopyAll': {
    'en': 'Copy sermon',
    'zh-Hans': '复制讲道',
    'zh-Hant': '複製講道',
  },
  'sermonCopied': {
    'en': 'Sermon copied to clipboard',
    'zh-Hans': '讲道已复制到剪贴板',
    'zh-Hant': '講道已複製到剪貼簿',
  },
  'sermonCopyEmpty': {
    'en': 'Sermon not loaded yet — wait for content to appear',
    'zh-Hans': '讲道尚未加载完成 — 请等待内容显示',
    'zh-Hant': '講道尚未載入完成 — 請等待內容顯示',
  },
  'sermonAttribution': {
    'en': "From YsWords (Yahweh's Words) — bilingual Bible app",
    'zh-Hans': '来自 YsWords 雅伟之言 — 双语圣经应用',
    'zh-Hant': '來自 YsWords 雅偉之言 — 雙語聖經應用',
  },
  // Verse popup sheet
  'versePopupExpand': {
    'en': 'Show full chapter',
    'zh-Hans': '展开整章',
    'zh-Hant': '展開整章',
  },
  'versePopupCollapse': {
    'en': 'Show only cited verses',
    'zh-Hans': '只显示引用的经文',
    'zh-Hant': '只顯示引用的經文',
  },
  'versePopupOpenReader': {
    'en': 'Open in reader',
    'zh-Hans': '在阅读器中打开',
    'zh-Hant': '在閱讀器中開啟',
  },
  'versePopupNotFound': {
    'en': 'Verse text not loaded — try "Open in reader".',
    'zh-Hans': '经文未加载 — 请尝试"在阅读器中打开"。',
    'zh-Hant': '經文未載入 — 請嘗試「在閱讀器中開啟」。',
  },
  'familyTreeMatchCount': {
    'zh-Hans': '第 {index}/{total} 个匹配',
    'zh-Hant': '第 {index}/{total} 個匹配',
    'en': 'Match {index} of {total}',
  },
  'familyTreeExpand': {
    'zh-Hans': '展开',
    'zh-Hant': '展開',
    'en': 'Expand',
  },
  'familyTreeCollapse': {
    'zh-Hans': '收起',
    'zh-Hant': '收起',
    'en': 'Collapse',
  },
  'familyTreeRootLabel': {
    'zh-Hans': '始祖',
    'zh-Hant': '始祖',
    'en': 'ROOT',
  },
  'familyTreeFocusLeaf': {
    'zh-Hans': '此人物在数据集中暂无后裔。',
    'zh-Hant': '此人物在資料集中暫無後裔。',
    'en': 'No descendants in this dataset.',
  },
  'sermonFilterBookLabel': {
    'zh-Hans': '书卷',
    'zh-Hant': '書卷',
    'en': 'Book',
  },
  'sermonFilterChapterLabel': {
    'zh-Hans': '章',
    'zh-Hant': '章',
    'en': 'Chapter',
  },
  'sermonFilterAllChapters': {
    'zh-Hans': '全部章节',
    'zh-Hant': '全部章節',
    'en': 'All chapters',
  },
  'sermonNoMatches': {
    'zh-Hans': '没有讲道符合当前筛选条件。',
    'zh-Hant': '沒有講道符合當前篩選條件。',
    'en': 'No sermons match your filters.',
  },
  'clearFilter': {
    'zh-Hans': '清除',
    'zh-Hant': '清除',
    'en': 'Clear',
  },
  'apply': {
    'zh-Hans': '应用',
    'zh-Hant': '套用',
    'en': 'Apply',
  },
  'viewMap': {
    'zh-Hans': '查看插图',
    'zh-Hant': '查看插畫',
    'en': 'View Illustration',
  },
  'noMapsForChapter': {
    'zh-Hans': '本章暂无插图',
    'zh-Hant': '本章暫無插畫',
    'en': 'No illustrations for this chapter',
  },
  'mapsForThisChapter': {
    'zh-Hans': '本章相关插图',
    'zh-Hant': '本章相關插畫',
    'en': 'For this chapter',
  },
  'mapsForThisBook': {
    'zh-Hans': '本卷相关插图',
    'zh-Hant': '本卷相關插畫',
    'en': 'For this book',
  },
  'mapsAll': {
    'zh-Hans': '全部插图',
    'zh-Hant': '全部插畫',
    'en': 'All illustrations',
  },
  'mapsRelated': {
    'zh-Hans': '相关插图',
    'zh-Hant': '相關插畫',
    'en': 'Related illustrations',
  },
  'mapsBrowseLibrary': {
    'zh-Hans': '浏览全部插图',
    'zh-Hant': '瀏覽全部插畫',
    'en': 'Browse all illustrations',
  },
  'mapsNoneForChapterFallback': {
    'zh-Hans': '本章无专属插图，以下是相关内容：',
    'zh-Hant': '本章無專屬插畫，以下是相關內容：',
    'en': 'No illustration specifically for this chapter — here are related ones:',
  },
  // Per-book group label in the All-illustrations tab. {book} is the
  // localized book name; {n} is the count.
  'illustrationsBookCount': {
    'zh-Hans': '{book}（{n} 张）',
    'zh-Hant': '{book}（{n} 張）',
    'en': '{book} ({n})',
  },
  'openSplitView': {
    'zh-Hans': '打开分屏阅读',
    'zh-Hant': '打開分屏閱讀',
    'en': 'Open Split View',
  },
  'closeSplitView': {
    'zh-Hans': '关闭分屏阅读',
    'zh-Hant': '關閉分屏閱讀',
    'en': 'Close Split View',
  },
  'searchHint': {
    'zh-Hans': '输入关键字开始搜索',
    'zh-Hant': '輸入關鍵字開始搜索',
    'en': 'Type a word or phrase to search',
  },
  'myHighlights': {
    'zh-Hans': '我的高亮',
    'zh-Hant': '我的高亮',
    'en': 'My Highlights',
  },
  'noHighlights': {
    'zh-Hans': '还没有高亮内容。\n选中经文，点击高亮按钮即可保存。',
    'zh-Hant': '還沒有高亮內容。\n選中經文，點擊高亮按鈕即可儲存。',
    'en': 'No highlights yet.\nSelect a verse and tap the highlight button to save.',
  },
  'highlightsVerseCount': {
    'zh-Hans': '{count} 节',
    'zh-Hant': '{count} 節',
    'en': '{count} verse',
  },
  'more': {
    'zh-Hans': '更多',
    'zh-Hant': '更多',
    'en': 'More',
  },
  'wordDistribution': {
    'zh-Hans': '分布',
    'zh-Hant': '分佈',
    'en': 'Distribution',
  },
  'topBooks': {
    'zh-Hans': '主要出处',
    'zh-Hant': '主要出處',
    'en': 'Top books',
  },
  'searchByStrongs': {
    'zh-Hans': '按 Strong\'s 编号搜索',
    'zh-Hant': '按 Strong\'s 編號搜尋',
    'en': 'Strong\'s number',
  },
  'interlinearHint': {
    'zh-Hans': '原文 · Strong\'s 中文释义',
    'zh-Hant': '原文 · Strong\'s 中文釋義',
    'en': 'Original · Strong\'s gloss',
  },
};
