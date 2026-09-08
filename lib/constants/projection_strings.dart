/// The 投影 view's own strings, kept out of `ui_strings.dart`.
///
/// Same shape as `uiStrings` — key → locale → string, with all three of
/// `zh-Hans` / `zh-Hant` / `en` on every key — and looked up through the
/// same `?[locale] ?? ?['en']` idiom. A separate map rather than fifteen
/// more entries in a 9,000-line file because every one of these belongs
/// to one page and nothing else will ever read them; when the page goes,
/// the file goes with it.
///
/// The two hint lines are the only strings here the CONGREGATION could
/// end up reading (the control strip is on the wall too — see
/// `projection_page.dart`'s library doc on why this is one window), so
/// they are written to be brief rather than instructive. Everything else
/// is a tooltip only the operator sees.
library;

const projectionStrings = <String, Map<String, String>>{
  // The name of the page, for the one door that leads to it. Added
  // 2026-09-09: this page had a route and no door, so `#/project` was
  // typeable on the web and unreachable on iOS and Android — which have
  // no address bar. On the two platforms a Sunday service is most
  // likely to be driven from, the feature did not exist.
  'projectionTitle': {
    'zh-Hans': '投影',
    'zh-Hant': '投影',
    'en': 'Projection',
  },

  // ── the wall ──────────────────────────────────────────────────────
  'projectionNoPassage': {
    'zh-Hans': '尚未打开经文',
    'zh-Hant': '尚未打開經文',
    'en': 'No passage is open',
  },
  'projectionSecondVersionLoading': {
    'zh-Hans': '正在载入第二个译本',
    'zh-Hant': '正在載入第二個譯本',
    'en': 'Loading the second edition',
  },
  // Deliberately not "missing" or "error": a partial-canon edition (the
  // LJK2 New Testament, say) having no Genesis is the edition being
  // what it is, not a fault, and a room does not need to be told about
  // the app's internals.
  'projectionSecondVersionMissing': {
    'zh-Hans': '此译本在这里没有经文',
    'zh-Hant': '此譯本在這裡沒有經文',
    'en': 'This edition has no text here',
  },

  // ── the operator's buttons ────────────────────────────────────────
  'projectionPreviousChapter': {
    'zh-Hans': '上一章',
    'zh-Hant': '上一章',
    'en': 'Previous chapter',
  },
  'projectionPreviousVerse': {
    'zh-Hans': '上一节',
    'zh-Hant': '上一節',
    'en': 'Previous verse',
  },
  'projectionNextVerse': {
    'zh-Hans': '下一节',
    'zh-Hant': '下一節',
    'en': 'Next verse',
  },
  'projectionNextChapter': {
    'zh-Hans': '下一章',
    'zh-Hant': '下一章',
    'en': 'Next chapter',
  },
  'projectionBlank': {
    'zh-Hans': '黑屏',
    'zh-Hant': '黑屏',
    'en': 'Black out',
  },
  'projectionUnblank': {
    'zh-Hans': '显示经文',
    'zh-Hant': '顯示經文',
    'en': 'Show the passage',
  },
  'projectionTypeSmaller': {
    'zh-Hans': '缩小字号',
    'zh-Hant': '縮小字號',
    'en': 'Smaller type',
  },
  'projectionTypeBigger': {
    'zh-Hans': '放大字号',
    'zh-Hant': '放大字號',
    'en': 'Larger type',
  },
  'projectionSecondVersionShow': {
    'zh-Hans': '加上第二个译本',
    'zh-Hant': '加上第二個譯本',
    'en': 'Add a second edition',
  },
  'projectionSecondVersionHide': {
    'zh-Hans': '只显示一个译本',
    'zh-Hant': '只顯示一個譯本',
    'en': 'One edition only',
  },
  'projectionLeave': {
    'zh-Hans': '退出投影',
    'zh-Hant': '退出投影',
    'en': 'Leave projection',
  },

  // ── the two lines under the bar ───────────────────────────────────
  'projectionKeysHint': {
    'zh-Hans': '方向键换节 · PageUp/PageDown 换章 · B 黑屏 · +/- 字号 · Esc 退出',
    'zh-Hant': '方向鍵換節 · PageUp/PageDown 換章 · B 黑屏 · +/- 字號 · Esc 退出',
    'en': 'Arrows change verse · PageUp/PageDown change chapter · '
        'B blanks · +/- resize · Esc leaves',
  },
  // The answer to the question the operator is about to ask, said
  // before they ask it. See `projection_page.dart`'s library doc for
  // why a second window was investigated and declined; a design
  // decision nobody is told about reads as a missing feature.
  'projectionOneWindowNote': {
    'zh-Hans': '单窗口：请把本窗口拖到投影屏幕上。',
    'zh-Hant': '單窗口：請把本視窗拖到投影螢幕上。',
    'en': 'One window: put this window on the projector display.',
  },
};
