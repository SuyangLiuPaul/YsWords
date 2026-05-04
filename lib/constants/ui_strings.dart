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
    'zh-Hans': '圣经时间轴（97 个事件）、家谱（277 位人物）、圣经证据（225 项考古／抄本／科学发现）、双语每日新闻 + AI 选经文，都可在主页打开。',
    'zh-Hant': '聖經時間軸（97 個事件）、家譜（277 位人物）、聖經證據（225 項考古／抄本／科學發現）、雙語每日新聞 + AI 選經文，都可在主頁打開。',
    'en':
        'Bible Timeline (97 events), Family Tree (277 people), Bible Evidence (225 archaeology / manuscript / science finds), and bilingual Daily News with an AI-picked verse — all reachable from Home.',
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
    'zh-Hans': '圣经译本（共 14 部）',
    'zh-Hant': '聖經譯本（共 14 部）',
    'en': 'Bibles (14 translations)',
  },
  'offlinePackSermons': {
    'zh-Hans': '张熙和牧师讲道（587 篇 ×3 语）',
    'zh-Hant': '張熙和牧師講道（587 篇 ×3 語）',
    'en': "Pastor Eric's sermons (587 × 3 langs)",
  },
  'offlinePackTools': {
    'zh-Hans': '研经工具（家谱 / 时间轴 / 圣经证据 / 互参等）',
    'zh-Hant': '研經工具（家譜 / 時間軸 / 聖經證據 / 互參等）',
    'en': 'Tools & references (tree / timeline / evidence / cross-refs)',
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
    'zh-Hans': '下载中… {done} / {total}（{pct}%）',
    'zh-Hant': '下載中… {done} / {total}（{pct}%）',
    'en': 'Downloading… {done}/{total} ({pct}%)',
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
  'fontFamilyHint': {
    'zh-Hans': '"Roboto" 和 "微软雅黑" 是应用自带的字体，到处都能用。'
        '其他选项使用您设备上已安装的系统字体——中文用户推荐微软雅黑、苹方、思源黑体；'
        '英文用户推荐 Times New Roman、Georgia、Garamond（衬线）或 Helvetica、Arial（无衬线）。',
    'zh-Hant': '「Roboto」與「微軟雅黑」是應用內建字體，到處都能用。'
        '其他選項使用您裝置上已安裝的系統字體——中文使用者推薦微軟雅黑、蘋方、思源黑體；'
        '英文使用者推薦 Times New Roman、Georgia、Garamond（襯線）或 Helvetica、Arial（無襯線）。',
    'en':
        'Roboto and Microsoft YaHei are bundled with the app and always available. The other options use the system fonts installed on your device — for Chinese try Microsoft YaHei / PingFang SC / Source Han Sans; for English try Times New Roman / Georgia / Garamond (serif) or Helvetica / Arial (sans-serif).',
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
  'dashboardSection_todayHeadlines_label': {
    'zh-Hans': '今日头条',
    'zh-Hant': '今日頭條',
    'en': "Today's Headlines",
  },
  'dashboardSection_todayHeadlines_description': {
    'zh-Hans': '每日新闻每个分类的头条。',
    'zh-Hant': '每日新聞每個分類的頭條。',
    'en': 'Top story per section from Daily News.',
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
  'settingsShowDailyNewsHint': {
    'zh-Hans': '主页"今日头条"卡片与快捷入口。',
    'zh-Hant': '主頁「今日頭條」卡片與快捷入口。',
    'en': "Show Today's Headlines card and quick-link tile.",
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
  'newsRefreshed': {
    'zh-Hans': '今日头条已更新',
    'zh-Hant': '今日頭條已更新',
    'en': "Today's headlines updated.",
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
  'newsEmptyTitle': {
    'zh-Hans': '暂无新闻',
    'zh-Hant': '暫無新聞',
    'en': 'No news available',
  },
  'newsEmptyBody': {
    'zh-Hans': '可能是后台任务跳过了本时段。下拉或点击重试可重新拉取。',
    'zh-Hant': '可能是後台任務跳過了本時段。下拉或點擊重試可重新拉取。',
    'en': 'The cron may have skipped this window. Pull down or tap retry to fetch the latest.',
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
  // Daily News masthead — "last updated" line. {stamp} is the Sydney
  // local timestamp of the daily_news.json's generatedAt field.
  // Both the Flutter app and the Astro site at newsbible.netlify.app
  // pull from the same upstream source (yswords-data) so this matches
  // across surfaces.
  'dailyNewsLastUpdated': {
    'zh-Hans': '最近更新 {stamp} {tz} · 每小时自动刷新',
    'zh-Hant': '最近更新 {stamp} {tz} · 每小時自動重新整理',
    'en': 'Last updated {stamp} {tz} · refreshes hourly',
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
  // AI search (Round 39, Stage 4 — Cloud Functions Gemini proxy).
  'askAi': {
    'zh-Hans': 'AI 提问',
    'zh-Hant': 'AI 提問',
    'en': 'Ask AI',
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
  // Daily News (Round 40 — migrated from sibling DailyNews project).
  'dailyNews': {
    'zh-Hans': '每日新闻',
    'zh-Hant': '每日新聞',
    'en': 'Daily News',
  },
  'dailyNewsTagline': {
    'zh-Hans': '以圣经视角看新闻',
    'zh-Hant': '以聖經視角看新聞',
    'en': 'News through a biblical lens',
  },
  'todayHeadlines': {
    'zh-Hans': '今日头条',
    'zh-Hant': '今日頭條',
    'en': "Today's Headlines",
  },
  'bibleLens': {
    'zh-Hans': '圣经视角',
    'zh-Hant': '聖經視角',
    'en': 'Bible Lens',
  },
  'bibleReflection': {
    'zh-Hans': '圣经反思',
    'zh-Hant': '聖經反思',
    'en': 'Bible reflection',
  },
  'readFullStory': {
    'zh-Hans': '阅读全文',
    'zh-Hant': '閱讀全文',
    'en': 'Read full story',
  },
  'readOriginal': {
    'zh-Hans': '阅读 {source} 原文',
    'zh-Hant': '閱讀 {source} 原文',
    'en': 'Read original at {source}',
  },
  'openSource': {
    'zh-Hans': '打开原文',
    'zh-Hant': '打開原文',
    'en': 'Open original',
  },
  'newsSectionWorld': {
    'zh-Hans': '国际',
    'zh-Hant': '國際',
    'en': 'World',
  },
  'newsSectionChina': {
    'zh-Hans': '中国',
    'zh-Hant': '中國',
    'en': 'China',
  },
  'newsSectionAustralia': {
    'zh-Hans': '澳洲',
    'zh-Hant': '澳洲',
    'en': 'Australia',
  },
  'refresh': {
    'zh-Hans': '刷新',
    'zh-Hant': '重新整理',
    'en': 'Refresh',
  },
  'viewAll': {
    'zh-Hans': '查看全部',
    'zh-Hant': '查看全部',
    'en': 'View all',
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
  'cloudInitFailedTitle': {
    'zh-Hans': '云端登录暂时不可用',
    'zh-Hant': '雲端登入暫時無法使用',
    'en': 'Cloud sign-in temporarily unavailable',
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
    'zh-Hans': '让 AI 在这节经文中解释此词',
    'zh-Hant': '讓 AI 在這節經文中解釋此詞',
    'en': 'Explain in this verse with AI',
  },
  'aiExplainAsking': {
    'zh-Hans': '正在询问 Gemini…',
    'zh-Hant': '正在詢問 Gemini…',
    'en': 'Asking Gemini…',
  },
  'aiExplainRegenerate': {
    'zh-Hans': '重新生成',
    'zh-Hant': '重新生成',
    'en': 'Regenerate',
  },
  'aiExplainDisclaimer': {
    'zh-Hans': 'AI 生成内容,如用于研经或教导请核对原始资料。',
    'zh-Hant': 'AI 生成內容,如用於研經或教導請核對原始資料。',
    'en': 'AI-generated. Verify with primary sources for study or teaching use.',
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
