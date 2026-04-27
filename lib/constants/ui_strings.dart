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
