/// Localized labels for the 20 topic series in the Pastor Eric sermon
/// corpus. The topic strings on the right come from SERMON_INDEX.md
/// (which is English-only), so without this map the SermonsPage and
/// related-sermons sheet would render the topic chip in English even
/// for users on a Chinese app locale.
///
/// Translations are by-hand (these aren't auto-translated; they
/// follow the conventional Chinese labels Pastor Eric's church uses
/// in published materials). Add a new entry here whenever a new
/// topic appears in the corpus index.
const Map<String, Map<String, String>> sermonTopicI18n = {
  'Baptism': {
    'zh-Hans': '洗礼',
    'zh-Hant': '洗禮',
    'en': 'Baptism',
  },
  'Christians Relating to Others': {
    'zh-Hans': '基督徒与他人的关系',
    'zh-Hant': '基督徒與他人的關係',
    'en': 'Christians Relating to Others',
  },
  'Death and Resurrection of Christ': {
    'zh-Hans': '基督的死与复活',
    'zh-Hant': '基督的死與復活',
    'en': 'Death and Resurrection of Christ',
  },
  'Eschatology': {
    'zh-Hans': '末世论',
    'zh-Hant': '末世論',
    'en': 'Eschatology',
  },
  "Hasten the Lord's coming": {
    'zh-Hans': '加速主的再来',
    'zh-Hant': '加速主的再來',
    'en': "Hasten the Lord's Coming",
  },
  'Life Quality': {
    'zh-Hans': '生命品质',
    'zh-Hant': '生命品質',
    'en': 'Life Quality',
  },
  'Matthew and parallels in Luke and Mark': {
    'zh-Hans': '马太福音及路加马可平行经文',
    'zh-Hant': '馬太福音及路加馬可平行經文',
    'en': 'Matthew (parallels in Luke & Mark)',
  },
  "Pastor Eric's Testimony": {
    'zh-Hans': '张熙和牧师见证',
    'zh-Hant': '張熙和牧師見證',
    'en': "Pastor Eric's Testimony",
  },
  'Regeneration and Renewal': {
    'zh-Hans': '重生与更新',
    'zh-Hant': '重生與更新',
    'en': 'Regeneration and Renewal',
  },
  'Sermon on the Mount': {
    'zh-Hans': '登山宝训',
    'zh-Hant': '登山寶訓',
    'en': 'Sermon on the Mount',
  },
  'Spiritual Direction': {
    'zh-Hans': '属灵引导',
    'zh-Hant': '屬靈引導',
    'en': 'Spiritual Direction',
  },
  'Spiritual Experience, Knowing God': {
    'zh-Hans': '属灵经历:认识神',
    'zh-Hant': '屬靈經歷:認識神',
    'en': 'Spiritual Experience: Knowing God',
  },
  'Spiritual Mission': {
    'zh-Hans': '属灵使命',
    'zh-Hant': '屬靈使命',
    'en': 'Spiritual Mission',
  },
  'Spiritual Vision': {
    'zh-Hans': '属灵异象',
    'zh-Hant': '屬靈異象',
    'en': 'Spiritual Vision',
  },
  'Survey of 2 Timothy': {
    'zh-Hans': '提摩太后书概览',
    'zh-Hant': '提摩太後書概覽',
    'en': 'Survey of 2 Timothy',
  },
  'The Antichrist': {
    'zh-Hans': '敌基督',
    'zh-Hant': '敵基督',
    'en': 'The Antichrist',
  },
  'The Beatitudes': {
    'zh-Hans': '八福',
    'zh-Hant': '八福',
    'en': 'The Beatitudes',
  },
  "The Lord's Vision for the Church": {
    'zh-Hans': '主对教会的异象',
    'zh-Hant': '主對教會的異象',
    'en': "The Lord's Vision for the Church",
  },
  'The Parables of Jesus': {
    'zh-Hans': '耶稣的比喻',
    'zh-Hant': '耶穌的比喻',
    'en': 'The Parables of Jesus',
  },
  "Understanding the Truth of God's Word": {
    'zh-Hans': '明白神话语的真理',
    'zh-Hant': '明白神話語的真理',
    'en': "Understanding the Truth of God's Word",
  },
};

/// Look up the localized label for [topic] given the user's app
/// [locale]. Falls back to the original English topic string when
/// the topic isn't in the i18n map (so a future SERMON_INDEX.md
/// addition still renders something while we add the translation).
String localizedSermonTopic(String topic, String locale) {
  final entry = sermonTopicI18n[topic];
  if (entry == null) return topic;
  return entry[locale] ?? entry['en'] ?? topic;
}
