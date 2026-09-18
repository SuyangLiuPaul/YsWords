/// The Help page's model and its search — no Flutter in it.
///
/// 2026-09-18. 「sword所有的shortcut和一些help doc是不是应该有一个page教我们
/// 怎么用 words也是 不知道可以在那里找 而且需要有search功能找相关功能」,
/// then 「要详细」「功能和shortcut之类以及介绍」「不同platform之类的」.
/// The sibling app has the same page; the two share this model and
/// differ in their words, their sections and their destinations.
///
/// Four requirements, and each one decided a piece of the shape:
///
///  * **Where to find it.** A topic's [HelpTopic.path] is a list of
///    `ui_strings` KEYS, not prose. The page prints the menu's own labels
///    in the reader's locale, so "Tools › Word List" cannot say one thing
///    while the menu says another, and a renamed menu item renames the
///    help with it. `test/help_catalog_test.dart` fails on a key that does
///    not exist.
///  * **Shortcuts and gestures.** Keys are not written here at all. The
///    page prints them from the tables the handlers dispatch from
///    (`keyboard_shortcuts.dart`, `kProjectionKeymap`), so a key on the
///    Help page is a key that works.
///  * **Search.** Every language at once: a reader in the Chinese
///    interface who types `split`, or 繁體 字體 in the simplified one,
///    still finds it. See [searchHelp].
///  * **Platforms.** The same feature has a different door on an iPad
///    than on a Mac, and some exist on one only. [HelpTopic.only] hides a
///    topic that cannot apply; [HelpTopic.notes] says what differs.
library;

import 'package:yahwehs_words/constants/ui_strings.dart';

/// One piece of text in the app's three locales.
///
/// A class rather than a map so a topic cannot compile with a locale
/// missing — the drift `ui_strings` guards with a test, prevented here by
/// the constructor.
class HelpText {
  const HelpText(this.hans, this.hant, this.en);

  final String hans;
  final String hant;
  final String en;

  String of(String locale) => switch (locale) {
        'zh-Hans' => hans,
        'zh-Hant' => hant,
        _ => en,
      };

  List<String> get all => [hans, hant, en];
}

/// Where a feature is used. The web is its own platform because what
/// differs there is not the OS — updates arrive by reloading, the browser
/// owns some keys, and the site can be installed to a home screen.
enum HelpPlatform { web, ios, android, macos, windows, linux }

const Map<HelpPlatform, HelpText> kHelpPlatformNames = {
  HelpPlatform.web: HelpText('网页版', '網頁版', 'Web'),
  HelpPlatform.ios: HelpText('iPhone / iPad', 'iPhone / iPad', 'iPhone / iPad'),
  HelpPlatform.android: HelpText('Android', 'Android', 'Android'),
  HelpPlatform.macos: HelpText('Mac', 'Mac', 'Mac'),
  HelpPlatform.windows: HelpText('Windows', 'Windows', 'Windows'),
  HelpPlatform.linux: HelpText('Linux', 'Linux', 'Linux'),
};

/// Whether a platform has a hardware keyboard to print keys for, as
/// opposed to a touch screen that may or may not have one attached.
bool helpPlatformIsTouch(HelpPlatform p) =>
    p == HelpPlatform.ios || p == HelpPlatform.android;

enum HelpSection {
  start,
  reading,
  study,
  search,
  personal,
  media,
  explore,
  settings,
  platforms,
  shortcuts,
}

const Map<HelpSection, HelpText> kHelpSectionNames = {
  HelpSection.start: HelpText('入门', '入門', 'Getting started'),
  HelpSection.reading: HelpText('阅读', '閱讀', 'Reading'),
  HelpSection.study: HelpText('研读与原文', '研讀與原文', 'Study & the original'),
  HelpSection.search: HelpText('搜索', '搜尋', 'Search'),
  HelpSection.personal: HelpText('笔记、收藏与同步', '筆記、收藏與同步', 'Notes, saving & sync'),
  HelpSection.media: HelpText('讲道、诗歌、影片与投影', '講道、詩歌、影片與投影', 'Sermons, songs, video & projection'),
  HelpSection.explore: HelpText('更多探索', '更多探索', 'Explore more'),
  HelpSection.settings: HelpText('设置与更新', '設定與更新', 'Settings & updates'),
  HelpSection.platforms: HelpText('各平台', '各平台', 'Platforms'),
  HelpSection.shortcuts: HelpText('手势与快捷键', '手勢與快捷鍵', 'Gestures & shortcuts'),
};

/// Somewhere the Help page can take the reader. Every one is a page, and
/// `help_page.dart` opens them in one exhaustive switch, so a new door
/// does not compile until something opens it.
enum HelpDestination {
  settings,
  profiles,
  about,
  search,
  library,
  sermons,
  songs,
  videos,
  projection,
  statistics,
  readingStats,
  evidence,
  familyTree,
  timeline,
  trivia,
  misconceptions,
  feedback,
}

class HelpTopic {
  const HelpTopic({
    required this.id,
    required this.section,
    required this.title,
    required this.body,
    this.path = const [],
    this.keywords = const [],
    this.only,
    this.notes = const {},
    this.open,
  });

  /// Stable, for tests and deep links. Never shown.
  final String id;
  final HelpSection section;
  final HelpText title;

  /// Paragraphs separated by a blank line; a line starting `• ` is a
  /// bullet.
  final HelpText body;

  /// `ui_strings` keys for the menu path, outermost first — or one of
  /// [kHelpExtraLabels]' keys for a label that lives outside `ui_strings`.
  final List<String> path;

  /// Extra words a reader might search with — synonyms, the English name
  /// in a Chinese topic and the other way round, the BibleWorks term.
  final List<String> keywords;

  /// Null: everywhere. Otherwise the only platforms this applies to.
  final Set<HelpPlatform>? only;

  /// What differs on a particular platform.
  final Map<HelpPlatform, HelpText> notes;

  final HelpDestination? open;

  bool appliesTo(HelpPlatform p) => only == null || only!.contains(p);
}

/// Menu labels that do not live in `ui_strings`, so a [HelpTopic.path]
/// can still name them. Filled by the page at startup from the maps the
/// menu itself reads (`kStripPageTitle`, `projectionStrings`, …) — see
/// `help_page.dart` — so the label is still the menu's own.
final Map<String, Map<String, String>> kHelpExtraLabels = {};

/// The label for one path segment in [locale].
String helpPathLabel(String key, String locale) {
  final m = uiStrings[key] ?? kHelpExtraLabels[key];
  if (m == null) return key;
  return m[locale] ?? m['en'] ?? key;
}

/// Every locale's spelling of a path, for searching.
Iterable<String> _pathAllLocales(List<String> path) sync* {
  for (final key in path) {
    final m = uiStrings[key] ?? kHelpExtraLabels[key];
    if (m == null) continue;
    yield* m.values;
  }
}

// ── Search ──────────────────────────────────────────────────────────

/// Lower-cased, with full-width ASCII folded to half-width, so `Ｆ２` and
/// `F2` are one query. Chinese needs nothing more: every locale's text
/// is searched, so a simplified query finds a topic through its
/// simplified spelling even while the interface is traditional.
String normalizeHelpQuery(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0xFF01 && r <= 0xFF5E) {
      b.writeCharCode(r - 0xFEE0);
    } else if (r == 0x3000) {
      b.write(' ');
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString().toLowerCase().trim();
}

class HelpHit {
  const HelpHit(this.topic, this.score);
  final HelpTopic topic;
  final int score;
}

/// Topics matching [query], best first.
///
/// Whitespace splits the query into terms and EVERY term must match
/// somewhere in the topic — `复制 格式` narrows, it does not widen. A term
/// scores by where it matched: the title most, then the reader's own
/// search words, then the menu path, then the prose. Ties keep catalogue
/// order, which is the order the page lists them in.
///
/// [extra] lets the caller add text a topic is findable by that is not
/// stored on it.
List<HelpHit> searchHelp(
  String query,
  Iterable<HelpTopic> topics, {
  Iterable<String> Function(HelpTopic)? extra,
}) {
  final terms = normalizeHelpQuery(query)
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (terms.isEmpty) return const [];

  final hits = <HelpHit>[];
  var order = 0;
  final orderOf = <HelpTopic, int>{};
  for (final t in topics) {
    orderOf[t] = order++;
    final title = t.title.all.map(normalizeHelpQuery).join('\n');
    final words = [
      ...t.keywords,
      if (extra != null) ...extra(t),
    ].map(normalizeHelpQuery).join('\n');
    final path = _pathAllLocales(t.path).map(normalizeHelpQuery).join('\n');
    final prose = [
      ...t.body.all,
      for (final n in t.notes.values) ...n.all,
    ].map(normalizeHelpQuery).join('\n');

    var score = 0;
    var all = true;
    for (final term in terms) {
      final s = title.contains(term)
          ? 100
          : words.contains(term)
              ? 60
              : path.contains(term)
                  ? 40
                  : prose.contains(term)
                      ? 10
                      : 0;
      if (s == 0) {
        all = false;
        break;
      }
      score += s;
    }
    if (all) hits.add(HelpHit(t, score));
  }
  hits.sort((a, b) {
    final c = b.score.compareTo(a.score);
    return c != 0 ? c : orderOf[a.topic]!.compareTo(orderOf[b.topic]!);
  });
  return hits;
}
