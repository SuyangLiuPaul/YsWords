/// Localized labels for the categories that group the 属灵伟人小传 /
/// Spiritual Giants list, plus the canonical display order.
///
/// The category id on each figure in `assets/spiritual_giants.json`
/// keys into [giantCategoryI18n]. [giantCategoryOrder] fixes the order
/// the groups render in (roughly chronological), independent of the
/// order figures happen to appear in the JSON.
///
/// Mirrors `sermon_topics.dart` so the Spiritual Giants list and the
/// Sermons list localize their group headings the same way.
library;

/// Category ids in the order their groups should appear in the list.
const List<String> giantCategoryOrder = <String>[
  'fathers',
  'reformers',
  'revival',
  'preachers',
  'missions',
  'deeper-life',
  'faith',
  'hymns',
  'chinese',
];

const Map<String, Map<String, String>> giantCategoryI18n = {
  'fathers': {
    'zh-Hans': '教父与先驱',
    'zh-Hant': '教父與先驅',
    'en': 'Fathers & Forerunners',
  },
  'reformers': {
    'zh-Hans': '改教家',
    'zh-Hant': '改教家',
    'en': 'Reformers',
  },
  'revival': {
    'zh-Hans': '奋兴与大觉醒',
    'zh-Hant': '奮興與大覺醒',
    'en': 'Revival & Awakening',
  },
  'preachers': {
    'zh-Hans': '讲道与牧养',
    'zh-Hant': '講道與牧養',
    'en': 'Preachers & Pastors',
  },
  'missions': {
    'zh-Hans': '宣教先锋',
    'zh-Hant': '宣教先鋒',
    'en': 'Missionary Pioneers',
  },
  'deeper-life': {
    'zh-Hans': '属灵生命',
    'zh-Hant': '屬靈生命',
    'en': 'Deeper Life & Devotion',
  },
  'faith': {
    'zh-Hans': '信心与怜悯',
    'zh-Hant': '信心與憐憫',
    'en': 'Faith & Compassion',
  },
  'hymns': {
    'zh-Hans': '圣诗作者',
    'zh-Hant': '聖詩作者',
    'en': 'Hymn Writers',
  },
  'chinese': {
    'zh-Hans': '华人教会',
    'zh-Hant': '華人教會',
    'en': 'Chinese Church',
  },
};

/// Localized category label, falling back to English then the raw id.
String localizedGiantCategory(String categoryId, String locale) {
  final entry = giantCategoryI18n[categoryId];
  if (entry == null) return categoryId;
  return entry[locale] ?? entry['en'] ?? categoryId;
}

/// A stable accent color seed (0xAARRGGBB-less hue index) per category,
/// used to tint the leading avatar in the list so each group reads at a
/// glance — a nod to the colored-circle grid in the source material.
/// Returns an index into a themed palette resolved at the widget layer.
int giantCategoryColorIndex(String categoryId) {
  final i = giantCategoryOrder.indexOf(categoryId);
  return i < 0 ? 0 : i;
}
