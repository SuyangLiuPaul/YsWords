// Prerender a crawlable, JavaScript-free copy of the Bible text into
// `build/web/read/`, plus the per-version sitemaps that `web/sitemap.xml`
// (a static sitemap INDEX) points at.
//
//     dart run tools/prerender_bible.dart --out build/web
//
// ── Why this exists ───────────────────────────────────────────────────
// The app renders through CanvasKit: every word of scripture is painted
// into a <canvas>, so a crawler fetching yahwehword.com sees a page with
// no text in it. On top of that the reader addresses chapters with a HASH
// route (`#/john/3`), and fragments are never sent to a server — Google
// retired the AJAX-crawling scheme in 2015 — so the entire app is ONE
// indexable URL. Meta tags and a share card (added 2026-08-31) fix how a
// link UNFURLS, but they cannot create pages that did not exist.
//
// This script creates them: real HTML at real paths, with the real verse
// text, no JavaScript required. They are not a cloaked doorway — they are
// a genuinely usable plain-text reader that links into the app. That
// distinction matters both ethically and to Google, which penalises pages
// that show a crawler something the reader never gets.
//
// ── What is deliberately NOT here ─────────────────────────────────────
// NASB and LEB are absent, and that is a licensing decision, not an
// oversight. `docs/autonomous-queue.md` records the user's position that
// NASB needs permission, and NIV was removed from the app outright in
// 2026-05 because Biblica/Zondervan retain commercial copyright on the
// text. Serving a full translation as static, crawlable, indexable pages
// is a far more exposed form of publication than bundling it in an app,
// so nothing lands here without a clear licence story:
//
//   kjv                    public domain (1611 / 1769 revision)
//   cuvs-yhwh(-tr)         和合本 1919 base is public domain; the 雅伟
//                          revision is this project's own work
//   biblexg-v2(-tr)        梁家铿译本 — authorised by the user 2026-08-31
//
// Adding a version means adding it to [prerenderVersions] AND being able
// to answer the licence question for it. `test/prerender_bible_test.dart`
// fails if NASB, LEB or NIV ever appear in that list.
//
// ── One name per language ─────────────────────────────────────────────
// The user's rule: English is "Yahweh's Words", Chinese is 雅伟之言 /
// 雅偉之言, and the two are never printed together. The share card could
// not honour that (one card, every reader, no JavaScript to pick with) —
// these pages can, because each page is already in exactly one language.
// [_siteName] is the only place the name is written; the test asserts an
// English page contains no Chinese name and vice versa.

import 'dart:convert';
import 'dart:io';

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/constants/book_name_mapping.dart';
import 'package:yswords/constants/book_slugs.dart';
import 'package:yswords/constants/canon_chapters.dart';
import 'package:yswords/constants/text_patterns.dart';

/// The public origin every absolute URL on these pages points at. The
/// cn-* Netlify sites serve the same files; their canonical still names
/// this origin, which is correct — they are mirrors, not separate works,
/// and pointing them here is what keeps them from competing as duplicates.
const kBase = 'https://yahwehword.com';

/// Versions with a licence story clear enough to publish as static pages.
/// See the header comment before touching this.
const prerenderVersions = <String>[
  'kjv',
  'cuvs-yhwh',
  'cuvs-yhwh-tr',
  'biblexg-v2',
  'biblexg-v2-tr',
];

/// Editions that are the same translation in the other script. Simplified
/// and Traditional Chinese are genuinely different documents to a search
/// engine (different characters, different queries), so these ARE valid
/// hreflang alternates — unlike the app root, which has one URL for all
/// three scripts and therefore carries no hreflang at all.
const scriptAlternates = <String, List<String>>{
  'cuvs-yhwh': ['cuvs-yhwh', 'cuvs-yhwh-tr'],
  'cuvs-yhwh-tr': ['cuvs-yhwh', 'cuvs-yhwh-tr'],
  'biblexg-v2': ['biblexg-v2', 'biblexg-v2-tr'],
  'biblexg-v2-tr': ['biblexg-v2', 'biblexg-v2-tr'],
};

// ── models ────────────────────────────────────────────────────────────

class PrerenderVerse {
  /// What the edition itself calls this verse. `verseLabel` when the
  /// asset carries one (the 梁家铿 editions merge verses and label them
  /// "1-2"), otherwise the plain verse number.
  final String label;

  /// Anchor id — always the raw verse number, so `#v16` resolves the same
  /// way in every edition even when the visible label is a range.
  final String anchor;

  /// Verse text, already sanitised and HTML-escaped; may contain `<br>`.
  final String html;

  /// Verse text, sanitised but NOT escaped — for the meta description.
  final String plain;

  const PrerenderVerse({
    required this.label,
    required this.anchor,
    required this.html,
    required this.plain,
  });
}

class PrerenderChapter {
  final String version;
  final String englishBook;
  final int chapter;
  final List<PrerenderVerse> verses;

  const PrerenderChapter({
    required this.version,
    required this.englishBook,
    required this.chapter,
    required this.verses,
  });
}

/// One edition's parsed contents: canonical-order books, each with its
/// chapters in numeric order.
class PrerenderEdition {
  final String version;
  final List<String> books; // canonical English names, canonical order
  final Map<String, List<PrerenderChapter>> chapters;

  const PrerenderEdition({
    required this.version,
    required this.books,
    required this.chapters,
  });

  bool has(String englishBook, int chapter) =>
      chapters[englishBook]?.any((c) => c.chapter == chapter) ?? false;
}

// ── text ──────────────────────────────────────────────────────────────

String esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String escAttr(String s) => esc(s).replaceAll('"', '&quot;');

/// The app's own pipeline, in the app's own order, so a static page and
/// the reader show the same words:
///   1. `collapseAnnotationSpacing` — kills the ASCII space the CUVS
///      asset leaves between CJK text and a `[…]` marker.
///   2. `sanitizeForSearch` — strips `<note:…>` popups, unwraps
///      `{clarification}` braces, drops pilcrows, and normalises the
///      divine name (LORD → Yahweh, 耶和华 → 雅伟).
/// Line breaks survive both steps and become `<br>`, which is what makes
/// the poetry books read as poetry instead of one run-on paragraph.
String verseHtml(String raw) =>
    esc(sanitizeForSearch(collapseAnnotationSpacing(raw)))
        .replaceAll('\n', '<br>');

String versePlain(String raw) =>
    sanitizeForSearch(collapseAnnotationSpacing(raw)).replaceAll('\n', ' ');

// ── language-dependent chrome ─────────────────────────────────────────

/// The ONLY place the product name is written. See the header comment.
String siteName(String lang) => switch (lang) {
      'zh-Hans' => '雅伟之言',
      'zh-Hant' => '雅偉之言',
      _ => "Yahweh's Words",
    };

const _strings = <String, Map<String, String>>{
  'en': {
    'read': 'Read',
    'chapter': 'Chapter',
    'prev': 'Previous chapter',
    'next': 'Next chapter',
    'openApp': 'Open this chapter in the app',
    'otherVersions': 'This chapter in other versions',
    'books': 'Books',
    'chapters': 'Chapters',
    'allVersions': 'Bible versions',
    'noJs': 'A plain-text copy that needs no JavaScript. '
        'The full reader — search, cross-references, original Greek and '
        'Hebrew, sermons and hymns — is in the app.',
    'home': 'Home',
    'ot': 'Old Testament',
    'nt': 'New Testament',
  },
  'zh-Hans': {
    'read': '阅读',
    'chapter': '章',
    'prev': '上一章',
    'next': '下一章',
    'openApp': '在应用中打开本章',
    'otherVersions': '本章的其他版本',
    'books': '书卷',
    'chapters': '章目',
    'allVersions': '圣经版本',
    'noJs': '这是无需 JavaScript 的纯文本页面。完整的阅读器'
        '（搜索、串珠、原文对照、讲道与诗歌）在应用中。',
    'home': '首页',
    'ot': '旧约',
    'nt': '新约',
  },
  'zh-Hant': {
    'read': '閱讀',
    'chapter': '章',
    'prev': '上一章',
    'next': '下一章',
    'openApp': '在應用中打開本章',
    'otherVersions': '本章的其他版本',
    'books': '書卷',
    'chapters': '章目',
    'allVersions': '聖經版本',
    'noJs': '這是無需 JavaScript 的純文字頁面。完整的閱讀器'
        '（搜尋、串珠、原文對照、講道與詩歌）在應用中。',
    'home': '首頁',
    'ot': '舊約',
    'nt': '新約',
  },
};

String t(String lang, String key) =>
    _strings[lang]?[key] ?? _strings['en']![key]!;

/// "John 3" in English, "约翰福音 3 章" in Chinese — the chapter number
/// takes a trailing 章 in Chinese and none in English, which is the
/// difference between reading naturally and reading like a translation.
String chapterTitle(String lang, String book, int chapter) =>
    lang == 'en' ? '$book $chapter' : '$book $chapter${t(lang, 'chapter')}';

String versionMenuLabel(String version) => bibleVersions
    .firstWhere((v) => v.value == version,
        orElse: () => BibleVersionInfo(
            value: version,
            shortLabel: version,
            menuLabel: version,
            language: 'zh-Hans'))
    .menuLabel;

// ── url helpers ───────────────────────────────────────────────────────

String readIndexPath() => '/read/';
String versionPath(String version) => '/read/$version/';
String bookPath(String version, String slug) => '/read/$version/$slug/';
String chapterPath(String version, String slug, int chapter) =>
    '/read/$version/$slug/$chapter/';

/// Deep link back into the app. The query lives INSIDE the fragment —
/// see the URL grammar documented in lib/services/url_sync_service_web.dart.
String appLink(String version, String slug, int chapter) =>
    '$kBase/#/$slug/$chapter?v=$version';

String slugOf(String englishBook) {
  final slug = slugForBook(englishBook);
  if (slug == null) {
    throw StateError(
        'No URL slug for "$englishBook" — add it to lib/constants/book_slugs.dart');
  }
  return slug;
}

// ── page shell ────────────────────────────────────────────────────────

String _head({
  required String lang,
  required String title,
  required String description,
  required String path,
  List<String> alternates = const [],
  String? jsonLd,
}) {
  final buf = StringBuffer()
    ..writeln('<!doctype html>')
    ..writeln('<html lang="$lang">')
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
    ..writeln('<link rel="stylesheet" href="/read/read.css">')
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

String _footer(String lang) => '''
<footer>
<p>${esc(t(lang, 'noJs'))}</p>
<p><a href="/">${esc(siteName(lang))}</a> · <a href="$readIndexPathConst">${esc(t(lang, 'read'))}</a></p>
</footer>
</body>
</html>
''';

const readIndexPathConst = '/read/';

/// Breadcrumbs are the one piece of structured data these pages earn
/// honestly: the trail is real, every level is a page that exists, and
/// Google renders it in the result instead of a bare URL.
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

String renderChapter(
  PrerenderChapter ch, {
  required Map<String, PrerenderEdition> editions,
  required int lastChapterInBook,
}) {
  final lang = bibleVersionLanguage(ch.version);
  final slug = slugOf(ch.englishBook);
  final localBook = toLocale(ch.englishBook, ch.version);
  final vLabel = versionMenuLabel(ch.version);
  final heading = chapterTitle(lang, localBook, ch.chapter);
  final path = chapterPath(ch.version, slug, ch.chapter);

  // "约翰福音 3章 — 和合本雅伟版(简体) | 雅伟之言". The edition is in the
  // title because it is what separates this page from the four others
  // carrying the same chapter; without it they compete for one query.
  final title = '$heading — $vLabel | ${siteName(lang)}';

  // A real excerpt, not boilerplate: the opening verses, cut at 150-odd
  // characters. Google rewrites descriptions it finds useless, and
  // nothing is less useful than the same sentence on 4,000 pages.
  final excerpt = StringBuffer();
  for (final v in ch.verses) {
    if (excerpt.length > 150) break;
    if (excerpt.isNotEmpty) excerpt.write(' ');
    excerpt.write(v.plain);
  }
  var description = excerpt.toString();
  if (description.length > 160) {
    description = '${description.substring(0, 157)}…';
  }
  if (description.isEmpty) description = '$heading — $vLabel';

  final alternates = <String>[];
  for (final alt in scriptAlternates[ch.version] ?? const <String>[]) {
    if (editions[alt]?.has(ch.englishBook, ch.chapter) ?? false) {
      alternates.add('<link rel="alternate" '
          'hreflang="${bibleVersionLanguage(alt)}" '
          'href="$kBase${chapterPath(alt, slug, ch.chapter)}">');
    }
  }

  final trail = [
    MapEntry(t(lang, 'read'), readIndexPath()),
    MapEntry(vLabel, versionPath(ch.version)),
    MapEntry(localBook, bookPath(ch.version, slug)),
  ];

  final buf = StringBuffer(_head(
    lang: lang,
    title: title,
    description: description,
    path: path,
    alternates: alternates,
    jsonLd: _breadcrumbJson([...trail, MapEntry(heading, path)]),
  ));

  buf
    ..writeln('<header class="hd">')
    ..writeln('<a class="brand" href="/">${esc(siteName(lang))}</a>')
    ..writeln(_crumbs(trail, heading))
    ..writeln('</header>')
    ..writeln('<main>')
    ..writeln('<h1>${esc(heading)}</h1>')
    ..writeln('<p class="ver">${esc(vLabel)}</p>')
    ..writeln('<div class="verses">');

  for (final v in ch.verses) {
    buf.writeln('<p id="v${v.anchor}">'
        '<a class="n" href="#v${v.anchor}">${esc(v.label)}</a>'
        '${v.html}</p>');
  }

  buf
    ..writeln('</div>')
    ..writeln('<p class="app"><a href="${escAttr(appLink(ch.version, slug, ch.chapter))}">'
        '${esc(t(lang, 'openApp'))} →</a></p>');

  // Prev/next. Absent at the canon edges rather than wrapping — a link
  // from Revelation 22 to Genesis 1 is a lie about what comes next.
  buf.writeln('<nav class="pn">');
  if (ch.chapter > 1) {
    buf.writeln('<a rel="prev" href="${chapterPath(ch.version, slug, ch.chapter - 1)}">'
        '← ${esc(t(lang, 'prev'))}</a>');
  }
  if (ch.chapter < lastChapterInBook) {
    buf.writeln('<a rel="next" href="${chapterPath(ch.version, slug, ch.chapter + 1)}">'
        '${esc(t(lang, 'next'))} →</a>');
  }
  buf.writeln('</nav>');

  // Cross-edition links. These are what give the site an internal link
  // graph at all: without them every chapter page is a leaf reachable
  // only from its own book index.
  final others = prerenderVersions
      .where((v) => v != ch.version)
      .where((v) => editions[v]?.has(ch.englishBook, ch.chapter) ?? false)
      .toList();
  if (others.isNotEmpty) {
    buf
      ..writeln('<section class="alt">')
      ..writeln('<h2>${esc(t(lang, 'otherVersions'))}</h2>')
      ..writeln('<ul>');
    for (final v in others) {
      final otherLang = bibleVersionLanguage(v);
      buf.writeln('<li lang="$otherLang"><a href="${chapterPath(v, slug, ch.chapter)}">'
          '${esc(versionMenuLabel(v))} — '
          '${esc(chapterTitle(otherLang, toLocale(ch.englishBook, v), ch.chapter))}'
          '</a></li>');
    }
    buf
      ..writeln('</ul>')
      ..writeln('</section>');
  }

  buf.writeln('</main>');
  buf.write(_footer(lang));
  return buf.toString();
}

String renderBookIndex(
  String version,
  String englishBook,
  List<int> chapters,
) {
  final lang = bibleVersionLanguage(version);
  final slug = slugOf(englishBook);
  final localBook = toLocale(englishBook, version);
  final vLabel = versionMenuLabel(version);
  final path = bookPath(version, slug);
  final title = '$localBook — $vLabel | ${siteName(lang)}';
  final description = lang == 'en'
      ? '$localBook in the $vLabel — all ${chapters.length} chapters, '
          'as plain text.'
      : '$vLabel《$localBook》共 ${chapters.length} 章，纯文本阅读。';

  final trail = [
    MapEntry(t(lang, 'read'), readIndexPath()),
    MapEntry(vLabel, versionPath(version)),
  ];

  final buf = StringBuffer(_head(
    lang: lang,
    title: title,
    description: description,
    path: path,
    jsonLd: _breadcrumbJson([...trail, MapEntry(localBook, path)]),
  ))
    ..writeln('<header class="hd">')
    ..writeln('<a class="brand" href="/">${esc(siteName(lang))}</a>')
    ..writeln(_crumbs(trail, localBook))
    ..writeln('</header>')
    ..writeln('<main>')
    ..writeln('<h1>${esc(localBook)}</h1>')
    ..writeln('<p class="ver">${esc(vLabel)}</p>')
    ..writeln('<h2>${esc(t(lang, 'chapters'))}</h2>')
    ..writeln('<ul class="grid">');
  for (final c in chapters) {
    buf.writeln('<li><a href="${chapterPath(version, slug, c)}">$c</a></li>');
  }
  buf
    ..writeln('</ul>')
    ..writeln('</main>');
  buf.write(_footer(lang));
  return buf.toString();
}

String renderVersionIndex(PrerenderEdition ed) {
  final lang = bibleVersionLanguage(ed.version);
  final vLabel = versionMenuLabel(ed.version);
  final path = versionPath(ed.version);
  final title = '$vLabel | ${siteName(lang)}';
  final description = lang == 'en'
      ? '$vLabel — every book and chapter as plain, readable text.'
      : '$vLabel — 全部书卷与章节，纯文本阅读。';

  // The 梁家铿 editions carry only the New Testament (the translator's
  // Old Testament work is not published), so the split is derived from
  // what the asset actually holds, never assumed.
  const firstNt = 'Matthew';
  final ntStart = canonLastChapter.keys.toList().indexOf(firstNt);
  final ot = <String>[];
  final nt = <String>[];
  for (final b in ed.books) {
    final i = canonLastChapter.keys.toList().indexOf(b);
    (i >= ntStart ? nt : ot).add(b);
  }

  final trail = [MapEntry(t(lang, 'read'), readIndexPath())];
  final buf = StringBuffer(_head(
    lang: lang,
    title: title,
    description: description,
    path: path,
    jsonLd: _breadcrumbJson([...trail, MapEntry(vLabel, path)]),
  ))
    ..writeln('<header class="hd">')
    ..writeln('<a class="brand" href="/">${esc(siteName(lang))}</a>')
    ..writeln(_crumbs(trail, vLabel))
    ..writeln('</header>')
    ..writeln('<main>')
    ..writeln('<h1>${esc(vLabel)}</h1>');

  void section(String heading, List<String> books) {
    if (books.isEmpty) return;
    buf
      ..writeln('<h2>${esc(heading)}</h2>')
      ..writeln('<ul class="books">');
    for (final b in books) {
      buf.writeln('<li><a href="${bookPath(ed.version, slugOf(b))}">'
          '${esc(toLocale(b, ed.version))}</a></li>');
    }
    buf.writeln('</ul>');
  }

  section(t(lang, 'ot'), ot);
  section(t(lang, 'nt'), nt);

  buf.writeln('</main>');
  buf.write(_footer(lang));
  return buf.toString();
}

/// The hub. English, matching the site's own static index.html — one
/// language, one name, per the rule.
String renderReadIndex(Map<String, PrerenderEdition> editions) {
  const lang = 'en';
  const path = '/read/';
  final title = 'Read the Bible online — ${siteName(lang)}';
  const description =
      'The Bible as plain, readable text — King James Version, '
      '和合本雅伟版 and 梁家铿译本, in Simplified and Traditional Chinese. '
      'No JavaScript required.';

  final buf = StringBuffer(_head(
    lang: lang,
    title: title,
    description: description,
    path: path,
    jsonLd: _breadcrumbJson([MapEntry('Read', path)]),
  ))
    ..writeln('<header class="hd">')
    ..writeln('<a class="brand" href="/">${esc(siteName(lang))}</a>')
    ..writeln('</header>')
    ..writeln('<main>')
    ..writeln('<h1>Read the Bible</h1>')
    ..writeln('<p>${esc(description)}</p>')
    ..writeln('<h2>${esc(t(lang, 'allVersions'))}</h2>')
    ..writeln('<ul class="books">');
  for (final v in prerenderVersions) {
    final ed = editions[v];
    if (ed == null) continue;
    final chapters =
        ed.chapters.values.fold<int>(0, (n, list) => n + list.length);
    buf.writeln('<li lang="${bibleVersionLanguage(v)}">'
        '<a href="${versionPath(v)}">${esc(versionMenuLabel(v))}</a> '
        '<span class="muted">${ed.books.length} books · $chapters chapters</span>'
        '</li>');
  }
  buf
    ..writeln('</ul>')
    ..writeln('</main>');
  buf.write(_footer(lang));
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

/// Maps whatever the asset calls a book to the canonical English name.
/// English assets already use it; Chinese assets go through the app's own
/// `zhToEn`, which knows both scripts and the alias table.
String canonicalBookName(String assetBook) {
  if (canonLastChapter.containsKey(assetBook)) return assetBook;
  final en = zhToEn(assetBook);
  if (en != null && canonLastChapter.containsKey(en)) return en;
  throw StateError('Unrecognised book name in asset: "$assetBook"');
}

PrerenderEdition loadEdition(String version, File assetFile) {
  final rows = jsonDecode(assetFile.readAsStringSync()) as List;

  // book → chapter → verses, all in first-appearance order; the assets
  // ship in canonical order and the canonical-order check below proves it.
  final byBook = <String, Map<int, List<PrerenderVerse>>>{};
  for (final row in rows.cast<Map<String, dynamic>>()) {
    final book = canonicalBookName(row['book'] as String);
    final chapter = int.parse((row['chapter'] as String).trim());
    final verse = (row['verse'] as String).trim();
    final label = ((row['verseLabel'] as String?)?.trim().isNotEmpty ?? false)
        ? (row['verseLabel'] as String).trim()
        : verse;
    final text = row['text'] as String;
    final html = verseHtml(text);
    if (html.trim().isEmpty) continue;
    byBook
        .putIfAbsent(book, () => <int, List<PrerenderVerse>>{})
        .putIfAbsent(chapter, () => <PrerenderVerse>[])
        .add(PrerenderVerse(
          label: label,
          anchor: verse,
          html: html,
          plain: versePlain(text),
        ));
  }

  // Canonical order comes from canonLastChapter's key order (the 66-book
  // table the canon tests already pin), filtered to what this edition
  // actually ships — which is how the NT-only 梁家铿 editions fall out
  // correctly without a special case.
  final books =
      canonLastChapter.keys.where(byBook.containsKey).toList(growable: false);
  if (books.length != byBook.length) {
    final unknown = byBook.keys.toSet()..removeAll(books);
    throw StateError('$version has books outside the canon table: $unknown');
  }

  final chapters = <String, List<PrerenderChapter>>{};
  for (final book in books) {
    final nums = byBook[book]!.keys.toList()..sort();
    chapters[book] = [
      for (final n in nums)
        PrerenderChapter(
          version: version,
          englishBook: book,
          chapter: n,
          verses: byBook[book]![n]!,
        ),
    ];
  }

  return PrerenderEdition(version: version, books: books, chapters: chapters);
}

// ── css ───────────────────────────────────────────────────────────────

/// One stylesheet for every generated page. External rather than inlined:
/// inlining ~1.5 KB into 4,000-odd pages is 6 MB of identical bytes on
/// the wire and in the deploy, for no benefit a single cached request
/// does not already give.
const readCss = r'''
:root {
  color-scheme: light dark;
  --bg: #fafdff; --fg: #1e2b36; --muted: #5b7488;
  --rule: #d3e4f0; --link: #1c5f95; --card: #ffffff;
}
@media (prefers-color-scheme: dark) {
  :root { --bg: #10171d; --fg: #dde7ef; --muted: #91a7b8;
          --rule: #253544; --link: #79bdf0; --card: #161f27; }
}
* { box-sizing: border-box; }
body {
  margin: 0; background: var(--bg); color: var(--fg);
  font: 17px/1.75 -apple-system, BlinkMacSystemFont, "Segoe UI",
        "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif;
}
a { color: var(--link); text-decoration: none; }
a:hover { text-decoration: underline; }
.hd {
  border-bottom: 1px solid var(--rule); padding: 14px 20px;
  display: flex; flex-wrap: wrap; gap: 6px 16px; align-items: baseline;
}
.brand { font-weight: 700; font-size: 18px; color: var(--fg); }
.crumb { color: var(--muted); font-size: 14px; }
main { max-width: 44rem; margin: 0 auto; padding: 24px 20px 8px; }
h1 { font-size: 28px; margin: 0 0 4px; }
h2 { font-size: 18px; margin: 32px 0 10px; color: var(--muted);
     font-weight: 600; }
.ver { color: var(--muted); margin: 0 0 24px; }
.muted { color: var(--muted); font-size: 14px; }
.verses p { margin: 0 0 14px; }
.verses .n {
  display: inline-block; min-width: 2.1em; margin-right: 2px;
  color: var(--muted); font-size: 13px; font-weight: 600;
  vertical-align: 2px; text-align: right;
}
.verses p:target { background: rgba(120,180,240,.18); border-radius: 4px; }
.app { margin: 32px 0 0; }
.app a {
  display: inline-block; padding: 10px 18px; border-radius: 999px;
  border: 1px solid var(--rule); background: var(--card);
}
.pn {
  display: flex; justify-content: space-between; gap: 16px;
  margin: 28px 0 0; padding-top: 18px; border-top: 1px solid var(--rule);
}
.pn a:only-child:last-child { margin-left: auto; }
.alt ul, .books { list-style: none; padding: 0; margin: 0; }
.alt li, .books li { margin: 0 0 8px; }
.grid {
  list-style: none; padding: 0; margin: 0;
  display: grid; gap: 8px;
  grid-template-columns: repeat(auto-fill, minmax(3.2rem, 1fr));
}
.grid a {
  display: block; text-align: center; padding: 9px 0;
  border: 1px solid var(--rule); border-radius: 8px; background: var(--card);
}
footer {
  max-width: 44rem; margin: 40px auto 0; padding: 20px;
  border-top: 1px solid var(--rule); color: var(--muted); font-size: 14px;
}
''';

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

  final outDir = Directory(out);
  if (!outDir.existsSync()) {
    stderr.writeln('FATAL: --out directory $out does not exist. '
        'Run `flutter build web` first, or pass an explicit --out.');
    exit(1);
  }

  final editions = <String, PrerenderEdition>{};
  for (final v in prerenderVersions) {
    final f = File('$assetsDir/$v.json');
    if (!f.existsSync()) {
      stderr.writeln('FATAL: missing asset ${f.path}');
      exit(1);
    }
    editions[v] = loadEdition(v, f);
  }

  _write(File('$out/read/read.css'), readCss);
  _write(File('$out/read/index.html'), renderReadIndex(editions));

  var pages = 2;
  final sitemapNames = <String>[];

  for (final v in prerenderVersions) {
    final ed = editions[v]!;
    final paths = <String>[versionPath(v)];
    _write(File('$out${versionPath(v)}index.html'), renderVersionIndex(ed));
    pages++;

    for (final book in ed.books) {
      final slug = slugOf(book);
      final chapters = ed.chapters[book]!;
      final nums = chapters.map((c) => c.chapter).toList();
      _write(File('$out${bookPath(v, slug)}index.html'),
          renderBookIndex(v, book, nums));
      paths.add(bookPath(v, slug));
      pages++;

      final last = nums.last;
      for (final ch in chapters) {
        _write(
          File('$out${chapterPath(v, slug, ch.chapter)}index.html'),
          renderChapter(ch, editions: editions, lastChapterInBook: last),
        );
        paths.add(chapterPath(v, slug, ch.chapter));
        pages++;
      }
    }

    final name = 'sitemap-$v.xml';
    _write(File('$out/$name'), renderSitemap(paths));
    sitemapNames.add(name);
    stdout.writeln('  $v — ${ed.books.length} books, ${paths.length} urls');
  }

  // web/sitemap.xml is a STATIC sitemap index that names these children.
  // If this list and that file ever disagree, Google reports a missing
  // child sitemap — loud, not silent. test/prerender_bible_test.dart
  // pins them to each other so it does not get that far.
  stdout.writeln('==> prerendered $pages pages into $out/read/');
  stdout.writeln('    sitemaps: ${sitemapNames.join(', ')}');
}
