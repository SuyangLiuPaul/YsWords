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
  'bookmark': {'zh-Hans': '书签', 'zh-Hant': '書籤', 'en': 'Bookmark'},
  'library': {'zh-Hans': '我的标记', 'zh-Hant': '我的標記', 'en': 'Library'},
  'statistics': {'zh-Hans': '统计分析', 'zh-Hant': '統計分析', 'en': 'Statistics'},
  'statsOverview':
      {'zh-Hans': '总览', 'zh-Hant': '總覽', 'en': 'Overview'},
  'statsBooks': {'zh-Hans': '书卷', 'zh-Hant': '書卷', 'en': 'Books'},
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
    'zh-Hans': '继续阅读',
    'zh-Hant': '繼續閱讀',
    'en': 'Continue reading',
  },
  'dailyVerse': {
    'zh-Hans': '每日金句',
    'zh-Hant': '每日金句',
    'en': 'Verse of the Day',
  },
  // ── Onboarding tour (Round 34) ──────────────────────────────────
  'skip': {'zh-Hans': '跳过', 'zh-Hant': '跳過', 'en': 'Skip'},
  'next': {'zh-Hans': '下一步', 'zh-Hant': '下一步', 'en': 'Next'},
  'getStarted': {
    'zh-Hans': '开始使用',
    'zh-Hant': '開始使用',
    'en': 'Get started',
  },
  'onboardWelcomeTitle': {
    'zh-Hans': '欢迎使用 YsWords',
    'zh-Hant': '歡迎使用 YsWords',
    'en': 'Welcome to YsWords',
  },
  'onboardWelcomeBody': {
    'zh-Hans': '双语圣经阅读应用。随时点击「继续阅读」可打开经文列表、侧栏、搜索、原文和相互参照。',
    'zh-Hant': '雙語聖經閱讀應用。隨時點擊「繼續閱讀」可打開經文列表、側欄、搜索、原文和相互參照。',
    'en':
        'A bilingual Bible reader. Tap "Continue reading" any time to open the verse list with sidebar, search, originals, and cross-references.',
  },
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
    'zh-Hans': '长按经文可添加笔记、书签或彩色高亮，可在「我的标记」和「高亮」中查找。',
    'zh-Hant': '長按經文可添加筆記、書籤或彩色高亮，可在「我的標記」和「高亮」中查找。',
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
  'recentSearches': {
    'zh-Hans': '最近搜索',
    'zh-Hant': '最近搜索',
    'en': 'Recent',
  },
  'clear': {'zh-Hans': '清除', 'zh-Hant': '清除', 'en': 'Clear'},
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
  // ── Verse audio (Round 27D) ─────────────────────────────────────
  'ttsListen': {
    'zh-Hans': '朗读本章',
    'zh-Hant': '朗讀本章',
    'en': 'Listen to chapter',
  },
  'ttsStop': {
    'zh-Hans': '停止朗读',
    'zh-Hant': '停止朗讀',
    'en': 'Stop reading',
  },
  // ── Keyboard shortcuts (Round 27E) ──────────────────────────────
  'shortcutsHelp': {
    'zh-Hans': '键盘快捷键',
    'zh-Hant': '鍵盤快捷鍵',
    'en': 'Keyboard shortcuts',
  },
  // ── Profiles / sign-in (Round 28) ──────────────────────────────
  'welcomeTagline': {
    'zh-Hans': '随身的个人圣经研读工具。',
    'zh-Hant': '隨身的個人聖經研讀工具。',
    'en': 'Personal Bible study, on every device.',
  },
  'welcomeChooseHowToUse': {
    'zh-Hans': '请选择使用方式',
    'zh-Hant': '請選擇使用方式',
    'en': 'How would you like to use YsWords?',
  },
  'welcomeSignIn': {
    'zh-Hans': '登录',
    'zh-Hant': '登入',
    'en': 'Sign in',
  },
  'welcomeContinueGuest': {
    'zh-Hans': '以访客身份继续',
    'zh-Hant': '以訪客身份繼續',
    'en': 'Continue as guest',
  },
  'welcomeLocalOnlyNotice': {
    'zh-Hans': '账号仅保存在本设备，不需要密码、不上传服务器。',
    'zh-Hant': '帳號僅保存在本裝置，不需要密碼、不上傳伺服器。',
    'en':
        'Profiles are stored only on this device. No password, no server.',
  },
  'welcomeNamePrompt': {
    'zh-Hans': '请输入您的称呼',
    'zh-Hant': '請輸入您的稱呼',
    'en': "What should we call you?",
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
  'welcomeSignInGoogle': {
    'zh-Hans': '使用 Google 登录',
    'zh-Hant': '使用 Google 登入',
    'en': 'Sign in with Google',
  },
  'cloudSignInGoogle': {
    'zh-Hans': '使用 Google 登录（多设备同步）',
    'zh-Hant': '使用 Google 登入（多裝置同步）',
    'en': 'Sign in with Google',
  },
  'welcomeLocalProfile': {
    'zh-Hans': '本地账号（仅限本设备）',
    'zh-Hant': '本地帳號（僅限本裝置）',
    'en': 'Local profile (this device only)',
  },
  'welcomeCloudNotice': {
    'zh-Hans': '登录后笔记、书签、读经进度可在所有设备同步；也可继续使用本地账号或访客模式。',
    'zh-Hant': '登入後筆記、書籤、讀經進度可在所有裝置同步；也可繼續使用本地帳號或訪客模式。',
    'en':
        'Sign in to sync across devices, or use a local profile / guest if you prefer to keep everything on this device.',
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
  'loadErrorBody': {
    'zh-Hans': '无法加载圣经经文，请检查网络或重试。',
    'zh-Hant': '無法載入聖經經文，請檢查網絡或重試。',
    'en': 'Could not load Bible verses. Please check your connection and retry.',
  },
  'retry': {
    'zh-Hans': '重试',
    'zh-Hant': '重試',
    'en': 'Retry',
  },
  'offlineMode': {
    'zh-Hans': '离线模式',
    'zh-Hant': '離線模式',
    'en': 'Offline Mode',
  },
  'chapters': {
    'zh-Hans': '章',
    'zh-Hant': '章',
    'en': 'ch',
  },
  'checkForUpdates': {
    'zh-Hans': '检查更新',
    'zh-Hant': '檢查更新',
    'en': 'Check for Updates',
  },
  'checkForUpdatesSubtitle': {
    'zh-Hans': '重新加载内置圣经数据。',
    'zh-Hant': '重新載入內建聖經數據。',
    'en': 'Refresh bundled Bible data and reload app.',
  },
  'updatesAvailableTitle': {
    'zh-Hans': '已是最新版本',
    'zh-Hant': '已是最新版本',
    'en': 'You\'re up to date',
  },
  'updatesAvailableBody': {
    'zh-Hans': '所有圣经版本均已内置，数据已从本地重新加载。',
    'zh-Hant': '所有聖經版本均已內建，數據已從本機重新載入。',
    'en': 'All Bible versions are bundled with the app. Data reloaded from local assets.',
  },
  'offlineModeSubtitle': {
    'zh-Hans': '所有圣经数据均已内置，无需联网即可阅读。',
    'zh-Hant': '所有聖經數據均已內置，無需聯網即可閱讀。',
    'en': 'All Bible data is bundled. No network connection required.',
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
  'viewMap': {
    'zh-Hans': '查看插图',
    'zh-Hant': '查看插畫',
    'en': 'View Illustration',
  },
  'noMapsForChapter': {
    'zh-Hans': '本章暂无插图',
    'zh-Hant': '本章暫無地圖',
    'en': 'No maps for this chapter',
  },
  'mapsForThisChapter': {
    'zh-Hans': '本章相关地图',
    'zh-Hant': '本章相關地圖',
    'en': 'For this chapter',
  },
  'mapsForThisBook': {
    'zh-Hans': '本卷相关地图',
    'zh-Hant': '本卷相關地圖',
    'en': 'For this book',
  },
  'mapsAll': {
    'zh-Hans': '全部地图',
    'zh-Hant': '全部地圖',
    'en': 'All maps',
  },
  'mapsRelated': {
    'zh-Hans': '相关地图',
    'zh-Hant': '相關地圖',
    'en': 'Related maps',
  },
  'mapsBrowseLibrary': {
    'zh-Hans': '浏览全部地图',
    'zh-Hant': '瀏覽全部地圖',
    'en': 'Browse all maps',
  },
  'mapsNoneForChapterFallback': {
    'zh-Hans': '本章无专属地图，以下是相关地图：',
    'zh-Hant': '本章無專屬地圖，以下是相關地圖：',
    'en': 'No map specifically for this chapter — here are related maps:',
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
