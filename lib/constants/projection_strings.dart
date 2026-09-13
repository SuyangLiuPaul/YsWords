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
  'projectionSecondVersionChoose': {
    'zh-Hans': '选择第二个译本',
    'zh-Hant': '選擇第二個譯本',
    'en': 'Choose the second edition',
  },
  'projectionLeave': {
    'zh-Hans': '退出投影',
    'zh-Hant': '退出投影',
    'en': 'Leave projection',
  },

  // ── the ground ────────────────────────────────────────────────────
  // Every one of these is a DARK ground; see `projection_stage.dart`'s
  // library doc for why there is no light one and why there will not
  // be. The labels say what the operator will see on the wall rather
  // than naming the mechanism — 「主题深色」 and not 「seeded scheme」.
  'projectionGround': {
    'zh-Hans': '背景',
    'zh-Hant': '背景',
    'en': 'Background',
  },
  // Keys are composed as `projectionGround_<ProjectionGround.name>` by
  // `projectionGroundLabel`, so a ground added without a label here
  // falls back to its own enum name rather than to a blank row.
  'projectionGround_seeded': {
    'zh-Hans': '主题深色',
    'zh-Hant': '主題深色',
    'en': 'Theme dark',
  },
  'projectionGround_ink': {
    'zh-Hans': '中性墨黑',
    'zh-Hant': '中性墨黑',
    'en': 'Neutral ink',
  },
  'projectionGround_black': {
    'zh-Hans': '纯黑',
    'zh-Hant': '純黑',
    'en': 'Pure black',
  },
  'projectionGround_spotlight': {
    'zh-Hans': '聚光',
    'zh-Hant': '聚光',
    'en': 'Spotlight',
  },

  // ── the presets ───────────────────────────────────────────────────
  'projectionPresets': {
    'zh-Hans': '预设',
    'zh-Hant': '預設',
    'en': 'Presets',
  },
  'projectionPresetSave': {
    'zh-Hans': '保存当前设置',
    'zh-Hant': '儲存目前設定',
    'en': 'Save the current setup',
  },
  'projectionPresetName': {
    'zh-Hans': '预设名称',
    'zh-Hant': '預設名稱',
    'en': 'Preset name',
  },
  // An example rather than an instruction: what the operator needs is
  // permission to write 「主日崇拜」 rather than a rule about naming.
  'projectionPresetNameHint': {
    'zh-Hans': '例如：主日崇拜',
    'zh-Hant': '例如：主日崇拜',
    'en': 'e.g. Morning service',
  },
  'projectionPresetDelete': {
    'zh-Hans': '删除预设',
    'zh-Hant': '刪除預設',
    'en': 'Delete preset',
  },
  'projectionPresetsEmpty': {
    'zh-Hans': '还没有保存过设置',
    'zh-Hant': '還沒有儲存過設定',
    'en': 'Nothing saved yet',
  },
  'projectionClose': {
    'zh-Hans': '关闭',
    'zh-Hant': '關閉',
    'en': 'Close',
  },

  // ── the control strip's own scroll hints ──────────────────────────
  // The strip is a horizontal scroller (`OverflowHintScroll`) on a
  // window too narrow for every button, and these are what a screen
  // reader announces on its two chevrons.
  'projectionMoreControls': {
    'zh-Hans': '更多控制',
    'zh-Hant': '更多控制',
    'en': 'More controls',
  },
  'projectionBackControls': {
    'zh-Hans': '前面的控制',
    'zh-Hant': '前面的控制',
    'en': 'Previous controls',
  },

  // ── the two lines under the bar ───────────────────────────────────
  // 2026-09-09: this line grew by three keys when the setup controls
  // arrived. It was already the longest string the congregation can
  // see, and lengthening it was still right: a binding nobody is told
  // about is a binding that does not exist, and the alternative — a
  // second hint line — puts MORE chrome on the wall, not less. The
  // setup keys are grouped after the movement keys so an operator
  // scanning for the arrow keys mid-service still finds them first.
  'projectionKeysHint': {
    'zh-Hans': '方向键换节 · PageUp/PageDown 换章 · B 黑屏 · +/- 字号 · '
        'G 背景 · V 第二译本 · S 预设 · Esc 退出',
    'zh-Hant': '方向鍵換節 · PageUp/PageDown 換章 · B 黑屏 · +/- 字號 · '
        'G 背景 · V 第二譯本 · S 預設 · Esc 退出',
    'en': 'Arrows change verse · PageUp/PageDown change chapter · '
        'B blanks · +/- resize · G background · V second edition · '
        'S presets · Esc leaves',
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
  // 2026-09-13: the follower window. Web only.
  'projectionOpenStage': {
    'zh-Hans': '打开投影窗口（拖到投影仪屏幕上）',
    'zh-Hant': '開啟投影視窗（拖到投影機螢幕上）',
    'en': 'Open the projector window (drag it to the projector display)',
  },
};
