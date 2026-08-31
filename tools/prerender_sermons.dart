// Prerender a crawlable, JavaScript-free copy of the sermon library into
// `build/web/sermons/`, plus the per-language sitemaps that
// `web/sitemap.xml` (a static sitemap INDEX) points at.
//
//     dart run tools/prerender_sermons.dart --out build/web
//
// ── Why this exists ───────────────────────────────────────────────────
// Same root cause as `tools/prerender_bible.dart`: the app paints every
// word through CanvasKit and addresses everything with a hash route, so
// a crawler sees one URL containing no text. That script fixed it for
// scripture. This one fixes it for the sermons, and the sermons are the
// more valuable half of the trade.
//
// Scripture text is the most duplicated content on the web — the same
// KJV verse sits on thousands of sites, and a new domain with no inbound
// links is the last copy anyone has a reason to rank. These 289 sermons
// are the opposite: expository preaching from 1979-1982, transcribed,
// and as far as the open web is concerned they exist nowhere else in
// this form. Unique text is the only thing this site has that others do
// not.
//
// ── Whose words these are ─────────────────────────────────────────────
// 张熙和牧师 / Pastor Eric H.H. Chang. The app already states the
// position in `uiStrings.sermonCredit` — "© {name} · used with
// permission" — and every page generated here carries that same line,
// composed from `lib/constants/sermon_credit.dart` rather than retyped,
// so the name cannot drift between the app and the web copy. This script
// does not make the permission claim; it propagates the one the project
// already makes.
//
// ── Never re-paragraph ────────────────────────────────────────────────
// `lib/pages/sermon_detail_page.dart` sets the rule and explains it:
// these are transcripts of speech, the median paragraph is 599
// characters, and "inserting breaks into another man's sermon is making
// an expressive decision he did not make". The app answers that with
// typography instead — a line measure, generous paragraph spacing, a
// taller line height — and [sermonsCss] reproduces the same three
// levers at the same measures (30em for CJK, 34em for English) so the
// static page reads the way the reader does. The TEXT is passed through
// untouched apart from HTML escaping.
//
// Two files (EC018, EC019) are raw speech recognition — EC019 is a
// single 18,205-character paragraph with one period in it. They are
// published as they are. Re-punctuating them here would be the same
// expressive decision under a different name, and `docs/
// autonomous-queue.md` already tracks finding better transcripts as the
// real fix.
//
// ── One name per language ─────────────────────────────────────────────
// The user's rule, carried over from the Bible pages: English is
// "Yahweh's Words", Chinese is 雅伟之言 / 雅偉之言, never both on one
// page. [siteName] is the only place the product name is written.

import 'dart:convert';
import 'dart:io';

import 'package:yswords/constants/book_slugs.dart';
import 'package:yswords/constants/canon_chapters.dart';
import 'package:yswords/constants/sermon_credit.dart';
import 'package:yswords/constants/sermon_topics.dart';
import 'package:yswords/utils/passage_localizer.dart';
import 'package:yswords/utils/version_mapper.dart';

/// The public origin every absolute URL on these pages points at. The
/// cn-* Netlify sites serve the same files; their canonical still names
/// this origin, because they are mirrors, not separate works.
const kBase = 'https://yahwehword.com';

/// The three languages every sermon exists in.
///
/// `dir` is the asset directory (`assets/sermons/<dir>/<id>.txt`) and is
/// the app's own vocabulary — see `SermonService.bodyFor`. `seg` is the
/// URL segment, lowercased so the paths are case-insensitive-safe.
/// `tag` is both the `lang` attribute and the `hreflang` value, and is
/// the app's locale code, which is what `localizedSermonTopic` expects.
///
/// All 289 sermons have all three (`hasEn`/`hasZhCn`/`hasZhTw` are true
/// for every entry in the index, asserted in the test), which is what
/// makes the hreflang cluster below honest: every alternate it names is
/// a page that really exists.
class SermonLang {
  final String dir;
  final String seg;
  final String tag;
  const SermonLang(this.dir, this.seg, this.tag);
}

const sermonLangs = <SermonLang>[
  SermonLang('en', 'en', 'en'),
  SermonLang('zh-CN', 'zh-hans', 'zh-Hans'),
  SermonLang('zh-TW', 'zh-hant', 'zh-Hant'),
];

class SermonMeta {
  final String id;
  final String topic;
  final String date;
  final String parts;
  final String passage;
  final String fallbackTitle;
  final Map<String, String> titles; // asset lang -> title

  SermonMeta({
    required this.id,
    required this.topic,
    required this.date,
    required this.parts,
    required this.passage,
    required this.fallbackTitle,
    required this.titles,
  });

  /// The title in [lang], falling back to the index's bare `title`.
  /// The `titles` map is keyed by ASSET language (`en`/`zh-CN`/`zh-TW`),
  /// not by locale tag.
  String titleFor(SermonLang lang) {
    final t = titles[lang.dir];
    if (t != null && t.trim().isNotEmpty) return t.trim();
    return fallbackTitle;
  }
}

// ── text ──────────────────────────────────────────────────────────────

String esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String escAttr(String s) => esc(s).replaceAll('"', '&quot;');

/// Split a transcript into (title, paragraphs), following
/// `_SermonBody.build` exactly: drop a leading `# ` line, skip the blank
/// lines after it, then split on blank lines. Nothing is merged, split
/// further, re-wrapped or re-punctuated.
({String? title, List<String> paragraphs}) parseTranscript(String raw) {
  final lines = raw.split('\n');
  var start = 0;
  String? title;
  if (lines.isNotEmpty && lines.first.startsWith('# ')) {
    title = lines.first.substring(2).trim();
    start = 1;
  }
  while (start < lines.length && lines[start].trim().isEmpty) {
    start++;
  }
  final body = lines.sublist(start).join('\n').trim();
  final paragraphs = body
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  return (title: title, paragraphs: paragraphs);
}

/// An editorial note the transcriber added, not something the preacher
/// said — `[注：这是…]` / `[Note: this is…]`. 89 of the 289 files open
/// with one. It is still shown (it is real context, and hiding it would
/// make the page disagree with the app), but it is skipped when picking
/// the meta description, which should describe the sermon rather than
/// the recording.
bool isEditorialNote(String p) =>
    p.startsWith('[') || p.startsWith('［') || p.startsWith('【');

/// First ~160 characters of the first paragraph that is actually the
/// sermon. Cut on a word boundary for English; CJK has none, so it is
/// cut on the character.
String describe(List<String> paragraphs, String fallback) {
  final first = paragraphs.firstWhere(
    (p) => !isEditorialNote(p),
    orElse: () => paragraphs.isEmpty ? '' : paragraphs.first,
  );
  final flat = first.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) return fallback;
  if (flat.length <= 160) return flat;
  final cut = flat.substring(0, 160);
  final sp = cut.lastIndexOf(' ');
  // Only honour a word boundary if there is one near the end — a CJK
  // paragraph may have a single stray space at character 3.
  return '${sp > 120 ? cut.substring(0, sp) : cut}…';
}

// ── language-dependent chrome ─────────────────────────────────────────

/// The ONLY place the product name is written. See the header comment.
String siteName(String tag) => switch (tag) {
      'zh-Hans' => '雅伟之言',
      'zh-Hant' => '雅偉之言',
      _ => "Yahweh's Words",
    };

/// What a language calls itself. Used by the hub's language chooser,
/// which must name all three without naming the product in all three.
String endonym(String tag) => switch (tag) {
      'zh-Hans' => '简体中文',
      'zh-Hant' => '繁體中文',
      _ => 'English',
    };

const _strings = <String, Map<String, String>>{
  'en': {
    'sermons': 'Sermons',
    'home': 'Home',
    'topics': 'Series',
    'passage': 'Passage',
    'date': 'Preached',
    'parts': 'Parts',
    'inThisSermon': 'Scripture in this sermon',
    'openApp': 'Open this sermon in the app',
    'otherLangs': 'This sermon in other languages',
    'prev': 'Previous in this series',
    'next': 'Next in this series',
    'allSermons': 'All series',
    'read': 'Read the Bible',
    'noJs': 'A plain-text copy that needs no JavaScript. The full '
        'library — search, the passages each sermon opens, audio, and '
        'the Bible alongside it — is in the app.',
    'intro': 'Expository sermons transcribed in full, in English, '
        'Simplified Chinese and Traditional Chinese.',
  },
  'zh-Hans': {
    'sermons': '讲道',
    'home': '首页',
    'topics': '系列',
    'passage': '经文',
    'date': '讲于',
    'parts': '分集',
    'inThisSermon': '本讲道涉及的经文',
    'openApp': '在应用中打开本篇',
    'otherLangs': '本篇的其他语言',
    'prev': '本系列上一篇',
    'next': '本系列下一篇',
    'allSermons': '全部系列',
    'read': '阅读圣经',
    'noJs': '这是无需 JavaScript 的纯文本页面。完整的讲道库'
        '（搜索、逐篇经文、录音与对照圣经）在应用中。',
    'intro': '释经讲道全文转录，备有英文、简体中文与繁体中文三种文本。',
  },
  'zh-Hant': {
    'sermons': '講道',
    'home': '首頁',
    'topics': '系列',
    'passage': '經文',
    'date': '講於',
    'parts': '分集',
    'inThisSermon': '本講道涉及的經文',
    'openApp': '在應用中打開本篇',
    'otherLangs': '本篇的其他語言',
    'prev': '本系列上一篇',
    'next': '本系列下一篇',
    'allSermons': '全部系列',
    'read': '閱讀聖經',
    'noJs': '這是無需 JavaScript 的純文本頁面。完整的講道庫'
        '（搜索、逐篇經文、錄音與對照聖經）在應用中。',
    'intro': '釋經講道全文轉錄，備有英文、簡體中文與繁體中文三種文本。',
  },
};

String t(String tag, String key) =>
    _strings[tag]?[key] ?? _strings['en']![key]!;

/// `© 张熙和牧师 · 经授权使用。` — composed from
/// [sermonPreacher] so the app and these pages cannot disagree about the
/// spelling of his name. Mirrors `uiStrings.sermonCredit`.
String credit(String tag) => switch (tag) {
      'zh-Hans' => '© ${sermonPreacher('zh-Hans')} · 经授权使用。',
      'zh-Hant' => '© ${sermonPreacher('zh-Hant')} · 經授權使用。',
      _ => '© ${sermonPreacher('en')} · used with permission.',
    };

// ── urls ──────────────────────────────────────────────────────────────

const sermonsRoot = '/sermons/';

String langPath(SermonLang l) => '/sermons/${l.seg}/';
String topicPath(SermonLang l, String topic) =>
    '/sermons/${l.seg}/series/${topicSlug(topic)}/';
String sermonPath(SermonLang l, String id) => '/sermons/${l.seg}/$id/';

/// The app's own deep link for a sermon.
///
/// `?sermon=<id>` — a real QUERY parameter, not a fragment. `_handleDeepLink`
/// in `lib/main.dart` reads `Uri.base.queryParameters['sermon']`, so a
/// `#/sermons/<id>` link (the shape the Bible pages use for chapters,
/// and the shape this originally had) reaches the app and is silently
/// ignored. The test pins the grammar against main.dart rather than
/// against this comment.
String appLink(String id) => '$kBase/?sermon=${Uri.encodeComponent(id)}';

/// A URL-safe slug for a topic.
///
/// The index ships `topicSlug` already, but it is a FILESYSTEM-safe name
/// rather than a URL one: it contains spaces and commas, and writes an
/// apostrophe as an underscore (`The Lord_s Vision for the Church`).
/// Putting that in a path would percent-encode the spaces and leave the
/// underscore reading as a typo, so the slug is derived from the topic
/// itself here.
String topicSlug(String topic) {
  final s = topic
      .toLowerCase()
      .replaceAll("'", '')
      .replaceAll('’', '')
      // `_s` is how the index spells `'s`; collapse it the same way the
      // apostrophe is collapsed, so both spellings slug identically.
      .replaceAll('_s ', 's ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (s.isEmpty) {
    throw StateError('Topic "$topic" slugs to nothing');
  }
  return s;
}

// ── scripture references ──────────────────────────────────────────────

/// A reference key from `assets/sermons/refs.json`, resolved to a
/// chapter page under `/read/`.
///
/// Keys look like `Luke 4:5`, `1 Corinthians 10`, `Psalms 91`. Only the
/// book and chapter are used: the `/read/` pages are per-chapter, and a
/// verse anchor would multiply near-identical links across a sermon that
/// cites fifteen verses of one chapter.
class ScriptureLink {
  /// Always the canonical ENGLISH book name — it is the key every
  /// mapping table is written against. What a reader sees goes through
  /// [label].
  final String book;
  final int chapter;
  final String slug;
  const ScriptureLink(this.book, this.chapter, this.slug);

  /// The book in the page's own language, via the app's own table, so a
  /// Chinese page says 路加福音 4 and not `Luke 4`. `localeAwareBookName`
  /// resolves 'zh-Hant' through the Traditional map and every other
  /// `zh*` through the Simplified one.
  String label(String tag) => '${localeAwareBookName(book, tag)} $chapter';
  String path(String version) => '/read/$version/$slug/$chapter/';
}

final _refKey = RegExp(r'^(.+?)\s+(\d+)(?::\d+.*)?$');

/// Which prerendered edition a language reads. These are the editions
/// `tools/prerender_bible.dart` actually publishes, so every link this
/// produces lands on a page that exists — the test asserts it against
/// that tool's own list rather than trusting this comment.
String editionFor(SermonLang l) => switch (l.tag) {
      'zh-Hans' => 'cuvs-yhwh',
      'zh-Hant' => 'cuvs-yhwh-tr',
      _ => 'kjv',
    };

/// Parse and validate one ref key. Returns null when the key names a
/// book or chapter that is not in the canon — the reference index is
/// generated by a Python script over free prose, so it is not a
/// guaranteed-clean source, and a link to a page that does not exist is
/// worse than no link.
ScriptureLink? resolveRef(String key) {
  final m = _refKey.firstMatch(key.trim());
  if (m == null) return null;
  final book = m.group(1)!.trim();
  final chapter = int.tryParse(m.group(2)!);
  if (chapter == null || chapter < 1) return null;
  final last = canonLastChapter[book];
  if (last == null || chapter > last) return null;
  final slug = slugForBook(book);
  if (slug == null) return null;
  return ScriptureLink(book, chapter, slug);
}

/// Distinct chapters a sermon touches, in first-appearance order, so the
/// list reads in the order the preacher used them rather than
/// alphabetically.
List<ScriptureLink> chaptersOf(List<String> refKeys) {
  final seen = <String>{};
  final out = <ScriptureLink>[];
  for (final k in refKeys) {
    final link = resolveRef(k);
    if (link == null) continue;
    final id = '${link.book}|${link.chapter}';
    if (seen.add(id)) out.add(link);
  }
  return out;
}

// ── page shell ────────────────────────────────────────────────────────

String _head({
  required String tag,
  required String title,
  required String description,
  required String path,
  List<String> alternates = const [],
  String? jsonLd,
}) {
  final buf = StringBuffer()
    ..writeln('<!doctype html>')
    ..writeln('<html lang="$tag">')
    ..writeln('<head>')
    ..writeln('<meta charset="utf-8">')
    ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1">')
    ..writeln('<title>${esc(title)}</title>')
    ..writeln('<meta name="description" content="${escAttr(description)}">')
    ..writeln('<link rel="canonical" href="$kBase$path">');
  for (final alt in alternates) {
    buf.writeln(alt);
  }
  buf
    ..writeln('<link rel="stylesheet" href="/sermons/sermons.css">')
    ..writeln('<link rel="icon" href="/icons/Icon-192.png">')
    ..writeln('<meta property="og:type" content="article">')
    ..writeln('<meta property="og:title" content="${escAttr(title)}">')
    ..writeln(
        '<meta property="og:description" content="${escAttr(description)}">')
    ..writeln('<meta property="og:url" content="$kBase$path">')
    ..writeln('<meta property="og:image" content="$kBase/og-card.png">');
  if (jsonLd != null) {
    buf.writeln('<script type="application/ld+json">$jsonLd</script>');
  }
  buf
    ..writeln('</head>')
    ..writeln('<body>');
  return buf.toString();
}

/// hreflang for a page that exists in all three languages.
///
/// Valid here precisely because the three ARE distinct URLs holding the
/// same work — which is what hreflang is for, and why the Bible pages
/// only get it between 简/繁 pairs of one edition and never on
/// `index.html`.
List<String> _alternates(String Function(SermonLang) pathOf) {
  final out = <String>[];
  for (final l in sermonLangs) {
    out.add('<link rel="alternate" hreflang="${l.tag}" '
        'href="$kBase${pathOf(l)}">');
  }
  out.add('<link rel="alternate" hreflang="x-default" '
      'href="$kBase${pathOf(sermonLangs.first)}">');
  return out;
}

String _footer(String tag) => '''
<footer>
<p class="credit">${esc(credit(tag))}</p>
<p>${esc(t(tag, 'noJs'))}</p>
<p><a href="/">${esc(siteName(tag))}</a> · <a href="$sermonsRoot">${esc(t(tag, 'sermons'))}</a> · <a href="/read/">${esc(t(tag, 'read'))}</a></p>
</footer>
</body>
</html>
''';

String _breadcrumbJson(List<MapEntry<String, String>> trail) {
  final items = <Map<String, Object>>[];
  for (var i = 0; i < trail.length; i++) {
    items.add({
      '@type': 'ListItem',
      'position': i + 1,
      'name': trail[i].key,
      'item': '$kBase${trail[i].value}',
    });
  }
  return jsonEncode({
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    'itemListElement': items,
  });
}

String _crumbs(List<MapEntry<String, String>> trail, String current) {
  final buf = StringBuffer('<nav class="crumb">');
  for (final step in trail) {
    buf.write('<a href="${step.value}">${esc(step.key)}</a> › ');
  }
  buf.write('${esc(current)}</nav>');
  return buf.toString();
}

// ── pages ─────────────────────────────────────────────────────────────

String renderSermon(
  SermonMeta s,
  SermonLang lang, {
  required String body,
  required List<String> refKeys,
  required SermonMeta? prev,
  required SermonMeta? next,
}) {
  final tag = lang.tag;
  final parsed = parseTranscript(body);
  final title = s.titleFor(lang);
  final topicLabel = localizedSermonTopic(s.topic, tag);
  final desc = describe(parsed.paragraphs, '$title — ${sermonPreacher(tag)}');
  final path = sermonPath(lang, s.id);

  // Article, not the more tempting schema.org/SermonAudio: no audio is
  // published here (hosting is deprioritised — see the queue), and
  // claiming a media object that does not exist is exactly the kind of
  // structured-data lie Google issues manual actions for.
  final article = jsonEncode({
    '@context': 'https://schema.org',
    '@type': 'Article',
    'headline': title,
    'inLanguage': tag,
    'author': {'@type': 'Person', 'name': sermonPreacher(tag)},
    'isPartOf': {'@type': 'CreativeWorkSeries', 'name': topicLabel},
    if (s.date.trim().isNotEmpty) 'datePublished': s.date.trim(),
    'mainEntityOfPage': '$kBase$path',
  });

  final buf = StringBuffer(_head(
    tag: tag,
    title: '$title · ${sermonPreacher(tag)} · ${siteName(tag)}',
    description: desc,
    path: path,
    alternates: _alternates((l) => sermonPath(l, s.id)),
    jsonLd: article,
  ));

  buf.writeln(_crumbs([
    MapEntry(t(tag, 'sermons'), langPath(lang)),
    MapEntry(topicLabel, topicPath(lang, s.topic)),
  ], title));

  buf
    ..writeln('<main>')
    ..writeln('<h1>${esc(title)}</h1>');

  // The metadata line. Every field is optional in the index, so each is
  // emitted only when it has a value — an empty `Passage: ` reads like a
  // bug and there are 124 entries with no passage at all.
  final bits = <String>['<span class="who">${esc(sermonPreacher(tag))}</span>'];
  if (s.date.trim().isNotEmpty) {
    bits.add('${esc(t(tag, 'date'))} '
        '<time datetime="${escAttr(s.date.trim())}">${esc(s.date.trim())}</time>');
  }
  if (s.passage.trim().isNotEmpty) {
    // The index writes passages in English abbreviations (`Mt 7:21-27`,
    // `1Cor 6:17`). `localizePassage` is the app's own rewriter: it
    // expands each detected reference into the reader's language and
    // leaves everything between references alone. It returns the input
    // unchanged for English.
    bits.add('${esc(t(tag, 'passage'))} '
        '${esc(localizePassage(s.passage.trim(), tag))}');
  }
  if (s.parts.trim().isNotEmpty) {
    bits.add('${esc(t(tag, 'parts'))} ${esc(s.parts.trim())}');
  }
  buf.writeln('<p class="meta">${bits.join(' · ')}</p>');

  buf.writeln('<article>');
  for (final p in parsed.paragraphs) {
    final cls = isEditorialNote(p) ? ' class="note"' : '';
    // Single newlines inside a paragraph are the transcriber's own line
    // breaks; the app keeps them, so keep them.
    buf.writeln('<p$cls>${esc(p).replaceAll('\n', '<br>')}</p>');
  }
  buf.writeln('</article>');

  // Scripture links. This is what makes a sermon page part of the site
  // rather than an island: it points at the prerendered chapter pages,
  // which are otherwise reachable only from the /read/ indexes.
  final chapters = chaptersOf(refKeys);
  if (chapters.isNotEmpty) {
    final ed = editionFor(lang);
    buf
      ..writeln('<section class="refs">')
      ..writeln('<h2>${esc(t(tag, 'inThisSermon'))}</h2>')
      ..writeln('<ul class="chips">');
    for (final c in chapters) {
      buf.writeln('<li><a href="${c.path(ed)}">${esc(c.label(tag))}</a></li>');
    }
    buf
      ..writeln('</ul>')
      ..writeln('</section>');
  }

  buf
    ..writeln('<section class="langs">')
    ..writeln('<h2>${esc(t(tag, 'otherLangs'))}</h2>')
    ..writeln('<ul class="chips">');
  for (final l in sermonLangs) {
    if (l.seg == lang.seg) continue;
    buf.writeln('<li><a href="${sermonPath(l, s.id)}" hreflang="${l.tag}" '
        'lang="${l.tag}">${esc(s.titleFor(l))}</a></li>');
  }
  buf
    ..writeln('</ul>')
    ..writeln('</section>');

  buf.writeln('<nav class="pager">');
  if (prev != null) {
    buf.writeln('<a class="prev" href="${sermonPath(lang, prev.id)}">'
        '← ${esc(t(tag, 'prev'))}</a>');
  }
  if (next != null) {
    buf.writeln('<a class="next" href="${sermonPath(lang, next.id)}">'
        '${esc(t(tag, 'next'))} →</a>');
  }
  buf.writeln('</nav>');

  buf
    ..writeln('<p class="app"><a href="${appLink(s.id)}">'
        '${esc(t(tag, 'openApp'))} →</a></p>')
    ..writeln('</main>')
    ..write(_footer(tag));
  return buf.toString();
}

String renderTopicIndex(
  String topic,
  SermonLang lang,
  List<SermonMeta> sermons,
) {
  final tag = lang.tag;
  final label = localizedSermonTopic(topic, tag);
  final path = topicPath(lang, topic);
  final desc = '${sermons.length} · $label · ${sermonPreacher(tag)}';

  final buf = StringBuffer(_head(
    tag: tag,
    title: '$label · ${t(tag, 'sermons')} · ${siteName(tag)}',
    description: desc,
    path: path,
    alternates: _alternates((l) => topicPath(l, topic)),
    jsonLd: _breadcrumbJson([
      MapEntry(t(tag, 'sermons'), langPath(lang)),
      MapEntry(label, path),
    ]),
  ))
    ..writeln(_crumbs([
      MapEntry(t(tag, 'sermons'), langPath(lang)),
    ], label))
    ..writeln('<main>')
    ..writeln('<h1>${esc(label)}</h1>')
    ..writeln('<p class="meta">${esc(sermonPreacher(tag))} · '
        '${sermons.length}</p>')
    ..writeln('<ol class="sermons">');
  for (final s in sermons) {
    buf.write('<li><a href="${sermonPath(lang, s.id)}">'
        '${esc(s.titleFor(lang))}</a>');
    final sub = <String>[];
    if (s.date.trim().isNotEmpty) sub.add(esc(s.date.trim()));
    if (s.passage.trim().isNotEmpty) {
      sub.add(esc(localizePassage(s.passage.trim(), tag)));
    }
    if (sub.isNotEmpty) buf.write('<span class="sub">${sub.join(' · ')}</span>');
    buf.writeln('</li>');
  }
  buf
    ..writeln('</ol>')
    ..writeln('<p class="app"><a href="${langPath(lang)}">'
        '${esc(t(tag, 'allSermons'))} →</a></p>')
    ..writeln('</main>')
    ..write(_footer(tag));
  return buf.toString();
}

String renderLangIndex(
  SermonLang lang,
  List<String> topics,
  Map<String, List<SermonMeta>> byTopic,
) {
  final tag = lang.tag;
  final path = langPath(lang);
  final total = byTopic.values.fold<int>(0, (a, b) => a + b.length);

  final buf = StringBuffer(_head(
    tag: tag,
    title: '${t(tag, 'sermons')} · ${sermonPreacher(tag)} · ${siteName(tag)}',
    description: '$total · ${sermonPreacher(tag)} · ${t(tag, 'intro')}',
    path: path,
    alternates: _alternates(langPath),
    jsonLd: _breadcrumbJson([MapEntry(t(tag, 'sermons'), path)]),
  ))
    ..writeln(_crumbs([
      MapEntry(siteName(tag), '/'),
    ], t(tag, 'sermons')))
    ..writeln('<main>')
    ..writeln('<h1>${esc(t(tag, 'sermons'))}</h1>')
    ..writeln('<p class="meta">${esc(sermonPreacher(tag))} · $total</p>')
    ..writeln('<p class="intro">${esc(t(tag, 'intro'))}</p>')
    ..writeln('<h2>${esc(t(tag, 'topics'))}</h2>')
    ..writeln('<ul class="topics">');
  for (final topic in topics) {
    final n = byTopic[topic]!.length;
    buf.writeln('<li><a href="${topicPath(lang, topic)}">'
        '${esc(localizedSermonTopic(topic, tag))}</a>'
        '<span class="sub">$n</span></li>');
  }
  buf
    ..writeln('</ul>')
    ..writeln('</main>')
    ..write(_footer(tag));
  return buf.toString();
}

/// The `/sermons/` hub. English, and it names the three languages by
/// THEIR OWN names — `English` / `简体中文` / `繁體中文` — never by the
/// product name in each.
///
/// That distinction is the one-name rule: a language chooser has to
/// mention all three languages, and writing "雅伟之言 / 雅偉之言 /
/// Yahweh's Words" down one list is precisely the thing the rule
/// forbids. `/read/` solves the same problem the same way — it lists
/// 和合本雅伟版 and 梁家铿译本, which are the names of WORKS, and says
/// "Yahweh's Words" exactly once. The 404 page goes further and carries
/// no product name at all, because it cannot know which language its
/// reader wanted.
String renderHub(int total) {
  final buf = StringBuffer(_head(
    tag: 'en',
    title: "Sermons · ${sermonPreacher('en')} · ${siteName('en')}",
    description: '$total expository sermons by ${sermonPreacher('en')}, '
        'transcribed in full in English, Simplified Chinese and '
        'Traditional Chinese.',
    path: sermonsRoot,
    alternates: _alternates(langPath),
    jsonLd: _breadcrumbJson([const MapEntry('Sermons', sermonsRoot)]),
  ))
    ..writeln('<main>')
    ..writeln('<h1>Sermons</h1>')
    ..writeln('<p class="meta">${esc(sermonPreacher('en'))} · $total</p>')
    ..writeln('<ul class="topics">');
  for (final l in sermonLangs) {
    buf.writeln('<li><a href="${langPath(l)}" hreflang="${l.tag}" '
        'lang="${l.tag}">${esc(endonym(l.tag))}</a>'
        '<span class="sub">${esc(t(l.tag, 'sermons'))}</span></li>');
  }
  buf
    ..writeln('</ul>')
    ..writeln('</main>')
    ..write(_footer('en'));
  return buf.toString();
}

String renderNotFound() {
  final buf = StringBuffer(_head(
    tag: 'en',
    title: 'Sermon not found · 讲道不存在',
    description: 'No sermon is published at that address.',
    path: '/sermons/404.html',
  ))
    ..writeln('<main>')
    ..writeln('<h1>Sermon not found</h1>')
    ..writeln('<p>No sermon is published at that address.</p>')
    ..writeln('<p lang="zh-Hans">这个地址下没有对应的讲道。</p>')
    ..writeln('<p class="app"><a href="/sermons/">'
        'All sermons · 全部讲道 →</a></p>')
    ..writeln('</main>')
    ..writeln('<footer>')
    ..writeln('<p><a href="/">yahwehword.com</a> · '
        '<a href="/sermons/">Sermons · 讲道</a></p>')
    ..writeln('</footer>')
    ..writeln('</body>')
    ..writeln('</html>');
  return buf.toString();
}

// ── sitemaps ──────────────────────────────────────────────────────────

String renderSitemap(List<String> paths) {
  final buf = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
  for (final p in paths) {
    buf.writeln('  <url><loc>$kBase$p</loc></url>');
  }
  buf.writeln('</urlset>');
  return buf.toString();
}

// ── loading ───────────────────────────────────────────────────────────

List<SermonMeta> loadIndex(File f) {
  final rows = jsonDecode(f.readAsStringSync()) as List;
  final out = <SermonMeta>[];
  for (final row in rows.cast<Map<String, dynamic>>()) {
    final titles = <String, String>{};
    final raw = row['titles'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is String) titles['$k'] = v;
      });
    }
    out.add(SermonMeta(
      id: row['id'] as String,
      topic: row['topic'] as String,
      date: (row['date'] as String?) ?? '',
      parts: (row['parts'] as String?) ?? '',
      passage: (row['passage'] as String?) ?? '',
      fallbackTitle: (row['title'] as String?) ?? '',
      titles: titles,
    ));
  }
  return out;
}

// ── main ──────────────────────────────────────────────────────────────

void _write(File f, String body) {
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(body);
}

void main(List<String> args) {
  var out = 'build/web';
  var assetsDir = 'assets';
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--out') out = args[i + 1];
    if (args[i] == '--assets') assetsDir = args[i + 1];
  }

  if (!Directory(out).existsSync()) {
    stderr.writeln('FATAL: --out directory $out does not exist. '
        'Run `flutter build web` first, or pass an explicit --out.');
    exit(1);
  }

  final indexFile = File('$assetsDir/sermons/index.json');
  final refsFile = File('$assetsDir/sermons/refs.json');
  for (final f in [indexFile, refsFile]) {
    if (!f.existsSync()) {
      stderr.writeln('FATAL: missing asset ${f.path}');
      exit(1);
    }
  }

  final sermons = loadIndex(indexFile);
  if (sermons.length != sermonCount) {
    // sermonCount is what the APP tells users. If the asset and the
    // constant disagree, one of the two screens is lying, and this is
    // the cheapest place to find out.
    stderr.writeln('FATAL: index.json holds ${sermons.length} sermons but '
        'lib/constants/sermon_credit.dart says $sermonCount.');
    exit(1);
  }

  final refs = (jsonDecode(refsFile.readAsStringSync())
      as Map<String, dynamic>)['bySermon'] as Map<String, dynamic>;

  // Topics in corpus order, largest first, so the index leads with the
  // series someone is most likely to have come for.
  final byTopic = <String, List<SermonMeta>>{};
  for (final s in sermons) {
    byTopic.putIfAbsent(s.topic, () => []).add(s);
  }
  for (final list in byTopic.values) {
    list.sort((a, b) {
      final d = a.date.compareTo(b.date);
      return d != 0 ? d : a.id.compareTo(b.id);
    });
  }
  final topics = byTopic.keys.toList()
    ..sort((a, b) {
      final n = byTopic[b]!.length.compareTo(byTopic[a]!.length);
      return n != 0 ? n : a.compareTo(b);
    });

  // Slug collisions would silently overwrite one series with another.
  final slugs = <String, String>{};
  for (final topic in topics) {
    final slug = topicSlug(topic);
    final clash = slugs[slug];
    if (clash != null) {
      stderr.writeln('FATAL: topics "$clash" and "$topic" both slug to '
          '"$slug" — one would overwrite the other.');
      exit(1);
    }
    slugs[slug] = topic;
  }

  _write(File('$out/sermons/sermons.css'), sermonsCss);
  _write(File('$out/sermons/index.html'), renderHub(sermons.length));
  // Deliberately NOT in any sitemap: it is the answer to a bad url.
  _write(File('$out/sermons/404.html'), renderNotFound());

  var pages = 2;
  final sitemapNames = <String>[];

  for (final lang in sermonLangs) {
    final paths = <String>[langPath(lang)];
    _write(File('$out${langPath(lang)}index.html'),
        renderLangIndex(lang, topics, byTopic));
    pages++;

    for (final topic in topics) {
      final list = byTopic[topic]!;
      _write(File('$out${topicPath(lang, topic)}index.html'),
          renderTopicIndex(topic, lang, list));
      paths.add(topicPath(lang, topic));
      pages++;

      for (var i = 0; i < list.length; i++) {
        final s = list[i];
        final bodyFile = File('$assetsDir/sermons/${lang.dir}/${s.id}.txt');
        if (!bodyFile.existsSync()) {
          stderr.writeln('FATAL: missing transcript ${bodyFile.path}');
          exit(1);
        }
        _write(
          File('$out${sermonPath(lang, s.id)}index.html'),
          renderSermon(
            s,
            lang,
            body: bodyFile.readAsStringSync(),
            refKeys: ((refs[s.id] as List?) ?? const [])
                .map((e) => '$e')
                .toList(),
            prev: i > 0 ? list[i - 1] : null,
            next: i < list.length - 1 ? list[i + 1] : null,
          ),
        );
        paths.add(sermonPath(lang, s.id));
        pages++;
      }
    }

    final name = 'sitemap-sermons-${lang.seg}.xml';
    _write(File('$out/$name'), renderSitemap(paths));
    sitemapNames.add(name);
    stdout.writeln('  ${lang.seg} — ${topics.length} series, '
        '${paths.length} urls');
  }

  stdout.writeln('==> prerendered $pages pages into $out/sermons/');
  stdout.writeln('    sitemaps: ${sitemapNames.join(', ')}');
}

// ── style ─────────────────────────────────────────────────────────────

/// Deliberately its own stylesheet rather than a reuse of
/// `/read/read.css`: the two generators are independent, and a sermon
/// page needs the reading-measure rules that a verse-numbered chapter
/// page does not.
///
/// The three levers come straight from `_SermonBody` — see the header.
const sermonsCss = r'''
:root {
  --ink: #1b1b1b;
  --muted: #666;
  --rule: #e2e2e2;
  --link: #0b5cad;
  --bg: #fff;
  --note-bg: #f6f6f4;
}
@media (prefers-color-scheme: dark) {
  :root {
    --ink: #e8e8e8;
    --muted: #a0a0a0;
    --rule: #333;
    --link: #7fb4ee;
    --bg: #131313;
    --note-bg: #1d1d1d;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0;
  padding: 1.25rem 1rem 3rem;
  background: var(--bg);
  color: var(--ink);
  font: 1rem/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
        "Helvetica Neue", "PingFang SC", "Microsoft YaHei", sans-serif;
}
main, footer, .crumb { max-width: 34em; margin: 0 auto; }
html[lang^="zh"] main,
html[lang^="zh"] footer,
html[lang^="zh"] .crumb { max-width: 30em; }
a { color: var(--link); }
h1 { font-size: 1.5rem; line-height: 1.3; margin: .4em 0 .3em; }
h2 { font-size: 1.05rem; margin: 2em 0 .6em; color: var(--muted);
     font-weight: 600; }
.crumb { font-size: .82rem; color: var(--muted); margin-bottom: .6em; }
.crumb a { color: var(--muted); }
.meta { font-size: .85rem; color: var(--muted); margin: 0 0 1.4em; }
.meta .who { color: var(--ink); font-weight: 600; }
.intro { color: var(--muted); }

/* The reading levers. Paragraphs are the transcriber's, never ours:
   more space BETWEEN them than within, and a taller line height, which
   is what buys the most inside a 599-character block. */
article p {
  margin: 0 0 1.5em;
  line-height: 1.85;
  text-align: left;
}
article p.note {
  background: var(--note-bg);
  border-left: 3px solid var(--rule);
  padding: .7em .9em;
  font-size: .92rem;
  color: var(--muted);
  line-height: 1.7;
}

.chips { list-style: none; padding: 0; margin: 0;
         display: flex; flex-wrap: wrap; gap: .4em; }
.chips li a {
  display: inline-block;
  border: 1px solid var(--rule);
  border-radius: 999px;
  padding: .2em .7em;
  font-size: .85rem;
  text-decoration: none;
}
ol.sermons, ul.topics { padding-left: 0; list-style: none; margin: 0; }
ol.sermons li, ul.topics li {
  padding: .55em 0; border-bottom: 1px solid var(--rule);
}
.sub { display: block; font-size: .8rem; color: var(--muted); }
ul.topics .sub { display: inline; margin-left: .5em; }
.pager { display: flex; justify-content: space-between; gap: 1em;
         margin: 2.5em 0 0; font-size: .9rem; }
.pager .next { margin-left: auto; text-align: right; }
.app { margin: 2em 0 0; }
footer {
  margin-top: 3em; padding-top: 1em;
  border-top: 1px solid var(--rule);
  font-size: .82rem; color: var(--muted);
}
footer .credit { color: var(--ink); }
''';
