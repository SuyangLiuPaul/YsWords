// The prerendered, JavaScript-free sermon library under /sermons/ —
// tools/prerender_sermons.dart.
//
// 2026-08-31, from the user: 「第二个开做」 — go ahead with the sermon
// pages.
//
// Same machinery as the Bible pages, but the stakes are different in two
// directions at once.
//
// UPSIDE: this is the unique half. A KJV chapter sits on a thousand
// other sites and a new domain is the last copy anyone has a reason to
// rank; these 289 transcripts are published nowhere else in this form.
//
// DOWNSIDE: they are one man's words. 张熙和牧师 preached them, the
// project publishes them with permission, and everything that could go
// wrong here is a way of misrepresenting him:
//
//   * Losing the attribution line, or letting the spelling of his name
//     drift between the app and the web copy.
//   * Re-paragraphing a transcript. `sermon_detail_page.dart` states the
//     rule — "inserting breaks into another man's sermon is making an
//     expressive decision he did not make" — and a generator that
//     re-wraps text breaks it silently, on 867 pages, in a way no test
//     of the app would notice.
//   * hreflang between pages that do not all exist, which makes Google
//     pick one language and drop the others.
//   * A deep link in a grammar the app does not read, which looks like a
//     working link and goes nowhere.
//
// None of that shows up in a browser looking at the app.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tools/prerender_bible.dart' show prerenderVersions;
import '../tools/prerender_sermons.dart';
import 'support/mini_xml.dart';

const _prod = 'https://yahwehword.com';

SermonMeta _meta({
  String id = '004',
  String topic = 'Baptism',
  String date = '1979-04-08',
  String parts = 'A/B',
  String passage = 'Lk 4:5-13',
  String title = 'Temptation after baptism',
  Map<String, String>? titles,
}) =>
    SermonMeta(
      id: id,
      topic: topic,
      date: date,
      parts: parts,
      passage: passage,
      fallbackTitle: title,
      titles: titles ??
          const {
            'en': 'Temptation After Baptism',
            'zh-CN': '洗礼后的试探',
            'zh-TW': '洗禮後的試探',
          },
    );

SermonLang _lang(String seg) => sermonLangs.firstWhere((l) => l.seg == seg);

String _render(
  SermonLang lang, {
  String body = '# T\n\nFirst paragraph.\n\nSecond paragraph.',
  List<String> refs = const ['Luke 4:5'],
  SermonMeta? meta,
}) =>
    renderSermon(
      meta ?? _meta(),
      lang,
      body: body,
      refKeys: refs,
      prev: null,
      next: null,
    );

void main() {
  group('whose words these are', () {
    test('every page carries the credit, in its own language', () {
      expect(_render(_lang('en')), contains('used with permission'));
      expect(_render(_lang('zh-hans')), contains('经授权使用'));
      expect(_render(_lang('zh-hant')), contains('經授權使用'));
    });

    test('the name comes from sermon_credit.dart, never retyped here', () {
      // "H.H." is not decoration — sermon_credit.dart records that it is
      // the form the user asked for and the one that distinguishes him
      // from others surnamed Chang. A generator that shortened it would
      // be wrong on 289 pages.
      expect(_render(_lang('en')), contains('Pastor Eric H.H. Chang'));
      expect(_render(_lang('zh-hans')), contains('张熙和牧师'));
      expect(_render(_lang('zh-hant')), contains('張熙和牧師'));

      // Strip `//` lines first. The generator's header explains WHOSE
      // words these are and names him to do it, and an assertion about
      // what code does must not be satisfied — or broken — by what it
      // says about itself.
      final code = File('tools/prerender_sermons.dart')
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      for (final spelling in ['Eric H.H. Chang', '张熙和牧师', '張熙和牧師']) {
        expect(code, isNot(contains(spelling)),
            reason: 'the preacher\'s name must come from sermonPreacher(), '
                'not a literal in the generator — three drifting spellings '
                'in uiStrings is exactly why sermon_credit.dart exists');
      }
    });

    test('the author is stated as structured data too', () {
      final html = _render(_lang('en'));
      expect(html, contains('"@type":"Person","name":"Pastor Eric H.H. Chang"'));
    });

    test('it does not claim audio it does not publish', () {
      // Sermon audio hosting is deprioritised — nothing is served. A
      // schema.org/SermonAudio or an AudioObject here would be a
      // structured-data claim about a file that does not exist.
      final html = _render(_lang('en'));
      expect(html, contains('"@type":"Article"'));
      expect(html, isNot(contains('AudioObject')));
      expect(html, isNot(contains('SermonAudio')));
    });
  });

  group('the transcript is passed through, never rewritten', () {
    test('paragraphs are split only on blank lines', () {
      final r = parseTranscript('# Title\n\nOne.\n\nTwo.\n\n\nThree.');
      expect(r.title, 'Title');
      expect(r.paragraphs, ['One.', 'Two.', 'Three.']);
    });

    test('a single newline inside a paragraph is NOT a paragraph break', () {
      // This is the whole rule in miniature. Treating a soft line break
      // as a paragraph would silently re-paragraph the corpus.
      final r = parseTranscript('# T\n\nline one\nline two\n\nnext');
      expect(r.paragraphs, ['line one\nline two', 'next']);
    });

    test('a very long paragraph is emitted whole', () {
      // EC019 is a single 18,205-character paragraph of raw speech
      // recognition. Publishing it as-is is the correct behaviour: the
      // fix for it is a better transcript, not punctuation invented here.
      final long = 'x' * 18205;
      final html = _render(_lang('en'), body: '# T\n\n$long');
      expect(html, contains('<p>$long</p>'));
    });

    test('the generator has no re-wrapping machinery in it at all', () {
      // A cheap structural guard on the rule above: none of the ways
      // one would go about re-flowing prose appear in the file. The
      // behavioural tests are the real check; this one is what notices
      // if someone adds a "tidy up the long paragraphs" helper later.
      final src = File('tools/prerender_sermons.dart').readAsStringSync();
      for (final banned in ['wordWrap', 'splitMapJoin', 'padRight']) {
        expect(src, isNot(contains(banned)),
            reason: '"$banned" suggests the transcript is being reflowed');
      }
    });

    test('text that would break the markup is escaped', () {
      final html = _render(_lang('en'), body: '# T\n\n5 < 6 & "quoted"');
      expect(html, contains('5 &lt; 6 &amp; "quoted"'));
      expect(html, isNot(contains('<p>5 < 6')));
    });

    test('an editorial note is shown, but is not the description', () {
      // 89 of the 289 files open with a transcriber's note. It is real
      // context so it stays on the page — but a description reading
      // "[Note: this is part A of a recording…]" describes the tape,
      // not the sermon.
      const body = '# T\n\n[注：这是A部分。]\n\n真正的开头。';
      final html = _render(_lang('zh-hans'), body: body);
      expect(html, contains('[注：这是A部分。]'));
      expect(html, contains('class="note"'));
      final desc = RegExp(r'<meta name="description" content="([^"]*)"')
          .firstMatch(html)!
          .group(1)!;
      expect(desc, startsWith('真正的开头'));
    });
  });

  group('hreflang is only claimed where the pages exist', () {
    test('a sermon names all three languages and an x-default', () {
      final html = _render(_lang('zh-hans'));
      for (final tag in ['en', 'zh-Hans', 'zh-Hant', 'x-default']) {
        expect(html, contains('hreflang="$tag"'),
            reason: 'missing the $tag alternate');
      }
    });

    test('every alternate points at this same sermon', () {
      final html = _render(_lang('en'), meta: _meta(id: '207'));
      for (final seg in ['en', 'zh-hans', 'zh-hant']) {
        expect(html, contains('href="$_prod/sermons/$seg/207/"'));
      }
    });

    test('x-default is the English page', () {
      final html = _render(_lang('zh-hant'), meta: _meta(id: '207'));
      expect(
          html,
          contains('hreflang="x-default" '
              'href="$_prod/sermons/en/207/"'));
    });

    test('the claim rests on all three languages really existing', () {
      // hreflang between a page and one that 404s makes Google distrust
      // the whole cluster. The generator emits three alternates for
      // every sermon unconditionally, which is only honest because the
      // index says all 289 have all three.
      final rows =
          (File('assets/sermons/index.json').readAsStringSync()).isNotEmpty;
      expect(rows, isTrue);
      final metas = loadIndex(File('assets/sermons/index.json'));
      for (final m in metas) {
        for (final l in sermonLangs) {
          expect(File('assets/sermons/${l.dir}/${m.id}.txt').existsSync(),
              isTrue,
              reason: 'sermon ${m.id} has no ${l.dir} transcript, so the '
                  'hreflang cluster on its pages names a url that 404s');
        }
      }
    });

    test('canonical is self-referential, never cross-language', () {
      final html = _render(_lang('zh-hans'), meta: _meta(id: '210'));
      expect(html, contains('<link rel="canonical" '
          'href="$_prod/sermons/zh-hans/210/">'));
    });
  });

  group('one name per language', () {
    test('an English page carries no Chinese product name', () {
      final html = _render(_lang('en'));
      expect(html, contains("Yahweh's Words"));
      expect(html, isNot(contains('雅伟之言')));
      expect(html, isNot(contains('雅偉之言')));
    });

    test('a Chinese page carries no English product name', () {
      final hans = _render(_lang('zh-hans'));
      expect(hans, contains('雅伟之言'));
      expect(hans, isNot(contains("Yahweh's Words")));
      expect(hans, isNot(contains('雅偉之言')));

      final hant = _render(_lang('zh-hant'));
      expect(hant, contains('雅偉之言'));
      expect(hant, isNot(contains("Yahweh's Words")));
      expect(hant, isNot(contains('雅伟之言')));
    });

    test('the hub names languages, not three products', () {
      // It is the one page that must mention all three languages. It
      // does that with endonyms — English / 简体中文 / 繁體中文 — because
      // listing the product name in all three is exactly what the rule
      // forbids.
      final hub = renderHub(289);
      expect(hub, contains('English'));
      expect(hub, contains('简体中文'));
      expect(hub, contains('繁體中文'));
      expect(hub, contains("Yahweh's Words"));
      expect(hub, isNot(contains('雅伟之言')));
      expect(hub, isNot(contains('雅偉之言')));
    });
  });

  group('links into the app and the Bible', () {
    test('the app deep link uses the query grammar main.dart reads', () {
      // `_handleDeepLink` reads Uri.base.queryParameters['sermon']. A
      // `#/sermons/<id>` link — the shape the Bible pages use for
      // chapters, and the shape this generator had first — reaches the
      // app and is silently ignored.
      expect(appLink('004'), '$_prod/?sermon=004');
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains("params['sermon']"),
          reason: 'main.dart no longer reads ?sermon= — the deep links on '
              '867 pages just became dead');
      expect(appLink('004'), isNot(contains('#')));
    });

    test('an id needing encoding is encoded', () {
      // 18 of the 289 ids are neither plain numbers nor EC-codes
      // (`196-1`, `196-2`, …), so this is not hypothetical.
      expect(appLink('196-1'), '$_prod/?sermon=196-1');
    });

    test('scripture links go to editions that are really prerendered', () {
      for (final l in sermonLangs) {
        expect(prerenderVersions, contains(editionFor(l)),
            reason: '${l.seg} links at ${editionFor(l)}, which '
                'prerender_bible.dart does not publish — every one of '
                'those links would 404');
      }
    });

    test('each language links into its own script', () {
      expect(editionFor(_lang('en')), 'kjv');
      expect(editionFor(_lang('zh-hans')), 'cuvs-yhwh');
      expect(editionFor(_lang('zh-hant')), 'cuvs-yhwh-tr');
    });

    test('a reference outside the canon produces no link at all', () {
      // refs.json is generated by a Python script over free prose, so it
      // is not a guaranteed-clean source. A link to a chapter that does
      // not exist is worse than no link.
      expect(resolveRef('John 99'), isNull);
      expect(resolveRef('Book of Nonsense 3'), isNull);
      expect(resolveRef('John 0'), isNull);
      expect(resolveRef('gibberish'), isNull);
      expect(resolveRef('John 3')!.chapter, 3);
      expect(resolveRef('1 Corinthians 10:12')!.chapter, 10);
    });

    test('a chapter cited many times is linked once', () {
      final links = chaptersOf(
          ['John 3:1', 'John 3:16', 'John 3', 'Luke 4:5', 'John 99']);
      expect(links.map((l) => l.label('en')).toList(), ['John 3', 'Luke 4']);
    });

    test('book names are localized on Chinese pages', () {
      // The whole reason `localeAwareBookName` is used rather than the
      // raw key: the refs index and the canon tables are both keyed in
      // English, and printing that key is the default failure.
      final html = _render(_lang('zh-hans'), refs: ['Luke 4:5']);
      expect(html, contains('路加福音 4'));
      expect(html, isNot(contains('>Luke 4<')));

      final hant = _render(_lang('zh-hant'), refs: ['Luke 4:5']);
      expect(hant, contains('路加福音 4'));
      expect(hant, contains('/read/cuvs-yhwh-tr/luke/4/'));
    });

    test('the passage line is localized too', () {
      final html = _render(_lang('zh-hans'), meta: _meta(passage: 'Lk 4:5-13'));
      expect(html, contains('路加福音 4:5-13'));
      expect(html, isNot(contains('Lk 4:5-13')));
    });

    test('an English page keeps English book names', () {
      final html = _render(_lang('en'), refs: ['Luke 4:5']);
      expect(html, contains('>Luke 4<'));
      expect(html, contains('/read/kjv/luke/4/'));
    });
  });

  group('urls', () {
    test('topic slugs are url-safe', () {
      for (final topic in [
        'Matthew and parallels in Luke and Mark',
        "The Lord's Vision for the Church",
        'Spiritual Experience, Knowing God',
      ]) {
        final slug = topicSlug(topic);
        expect(RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(slug), isTrue,
            reason: '"$topic" slugs to "$slug", which is not a clean path '
                'segment');
      }
    });

    test("the index's underscore-for-apostrophe spelling slugs the same", () {
      // index.json writes `The Lord_s Vision for the Church` — a
      // FILESYSTEM-safe name, not a url one. Both spellings have to
      // reach the same page or the topic index links nowhere.
      expect(topicSlug('The Lord_s Vision for the Church'),
          topicSlug("The Lord's Vision for the Church"));
      expect(topicSlug("The Lord's Vision for the Church"),
          'the-lords-vision-for-the-church');
    });

    test('no two real topics collide', () {
      final metas = loadIndex(File('assets/sermons/index.json'));
      final bySlug = <String, String>{};
      for (final m in metas) {
        final slug = topicSlug(m.topic);
        final prior = bySlug[slug];
        expect(prior == null || prior == m.topic, isTrue,
            reason: '"$prior" and "${m.topic}" both slug to "$slug" — one '
                'series would overwrite the other');
        bySlug[slug] = m.topic;
      }
    });

    test('language segments are lowercase, and every path ends in a slash',
        () {
      // The lang segment is lowercased on purpose: the app's own locale
      // codes are `zh-Hans`/`zh-Hant`, and a mixed-case path segment is
      // a case-sensitivity bug waiting for the first host that differs
      // from Netlify.
      for (final l in sermonLangs) {
        expect(l.seg, l.seg.toLowerCase());
        expect(langPath(l), '/sermons/${l.seg}/');
        expect(topicPath(l, 'Baptism'), endsWith('/'));
      }
    });

    test('every generated path is lowercase, because Netlify 301s if not',
        () {
      // Found on prod, 2026-09-01, not by any local check:
      // /sermons/en/EC019/ answered 301 -> /sermons/en/ec019/ -> 200.
      // 22 of the 289 ids carry uppercase, so 66 pages shipped with a
      // <link rel="canonical"> naming a url that redirects — which is a
      // standard reason for Google to drop a page — plus hreflang
      // alternates and sitemap entries doing the same.
      final metas = loadIndex(File('assets/sermons/index.json'));
      final upper = metas.where((m) => m.id != m.id.toLowerCase()).toList();
      expect(upper, isNotEmpty,
          reason: 'if no id has uppercase any more this test proves '
              'nothing — check whether the ids were renamed');
      for (final l in sermonLangs) {
        for (final m in metas) {
          final p = sermonPath(l, m.id);
          expect(p, p.toLowerCase(), reason: 'sermon ${m.id} in ${l.seg}');
        }
      }
    });

    test('lower-casing an id cannot merge two sermons into one page', () {
      final metas = loadIndex(File('assets/sermons/index.json'));
      final seen = <String, String>{};
      for (final m in metas) {
        final p = sermonPath(sermonLangs.first, m.id);
        final clash = seen[p];
        expect(clash, isNull,
            reason: 'sermons $clash and ${m.id} both resolve to $p — one '
                'would silently overwrite the other');
        seen[p] = m.id;
      }
    });

    test('the app link keeps the real id, which is matched case-sensitively',
        () {
      // The path is lowercased; `?sermon=` must NOT be. main.dart
      // compares it against `c.id` from index.json with ==.
      expect(appLink('EC019'), endsWith('?sermon=EC019'));
      expect(sermonPath(sermonLangs.first, 'EC019'), '/sermons/en/ec019/');
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('c.id == sermonId'),
          reason: 'if the app stopped comparing ids exactly, this '
              'asymmetry needs rechecking');
    });
  });

  group('sitemaps', () {
    final index = XmlDocument.parse(File('web/sitemap.xml').readAsStringSync());
    final children = index.findAll('loc');

    test('the static index names one child per sermon language', () {
      for (final l in sermonLangs) {
        expect(children, contains('$_prod/sitemap-sermons-${l.seg}.xml'),
            reason: 'the generator writes sitemap-sermons-${l.seg}.xml but '
                'nothing indexes it, so Google never reads it');
      }
    });

    test('every child named is one something actually writes', () {
      // The reverse direction: a name here that no generator produces is
      // a child sitemap that 404s in Search Console.
      final produced = <String>{
        'sitemap-home.xml',
        for (final v in prerenderVersions) 'sitemap-$v.xml',
        for (final l in sermonLangs) 'sitemap-sermons-${l.seg}.xml',
      };
      for (final c in children) {
        expect(produced, contains(c.substring('$_prod/'.length)));
      }
    });

    test('the /sermons/ hub is listed, because no generated child holds it',
        () {
      // Exactly the gap /read/ fell into: each generated sermon sitemap
      // starts at /sermons/<language>/, so the language chooser belongs
      // to none of them.
      final home =
          XmlDocument.parse(File('web/sitemap-home.xml').readAsStringSync());
      expect(home.findAll('loc'), contains('$_prod/sermons/'));
    });

    test('generated sitemaps hold absolute prod urls only', () {
      final doc =
          XmlDocument.parse(renderSitemap(['/sermons/en/', '/sermons/en/004/']));
      expect(doc.rootName, 'urlset');
      expect(doc.findAll('loc'),
          ['$_prod/sermons/en/', '$_prod/sermons/en/004/']);
    });

    test('IndexNow submits the sermon sitemaps too', () {
      // The submitter holds its own literal list because it talks to the
      // live site. That independence is the point, and also exactly how
      // it goes stale.
      final src = File('tools/indexnow_submit.dart').readAsStringSync();
      for (final l in sermonLangs) {
        expect(src, contains("'sitemap-sermons-${l.seg}.xml'"),
            reason: '930 sermon urls would never be pushed to Bing');
      }
    });
  });

  group('the release actually runs the generator', () {
    // Assertions about what a script DOES must not be satisfied by what
    // it SAYS — release_web.sh names this generator in prose, including
    // in the comment explaining this very rule.
    final commands = File('tools/release_web.sh')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('#'))
        .toList();

    test('the sermon generator is invoked', () {
      expect(commands.any((l) => l.contains('tools/prerender_sermons.dart')),
          isTrue,
          reason: 'web/sitemap.xml names three sermon children; without '
              'this step all three 404 on every deploy');
    });

    test('it runs in the same pass as the Bible generator', () {
      // Both live inside prerender(), which is called once per build.
      // If the sermon call were outside it, the CHINA_MODE build would
      // overwrite build/web and drop the sermon pages.
      final start =
          commands.indexWhere((l) => l.trim().startsWith('prerender()'));
      expect(start, isNot(-1));
      final end = commands.indexWhere((l) => l.trim() == '}', start);
      final body = commands.sublist(start, end).join('\n');
      expect(body, contains('tools/prerender_bible.dart'));
      expect(body, contains('tools/prerender_sermons.dart'));
    });
  });

  group('a bad /sermons/ url answers 404, not 200', () {
    // The ids are short and mostly numeric, so /sermons/en/999/ is a url
    // a crawler will try unprompted. Without the rule it answers 200
    // with the Flutter shell and Google banks an unbounded supply of
    // duplicates of the home page.
    final toml = File('netlify.toml').readAsLinesSync();
    int ruleLine(String from) =>
        toml.indexWhere((l) => l.trim() == 'from = "$from"');

    test('the rule exists and sits above the SPA catch-all', () {
      final sermons = ruleLine('/sermons/*');
      final spa = ruleLine('/*');
      expect(sermons, isNot(-1), reason: 'the /sermons/* 404 rule is gone');
      expect(spa, isNot(-1));
      expect(sermons, lessThan(spa),
          reason: 'below the catch-all it can never match — first match wins');
    });

    test('it is a real 404 and is not forced', () {
      final line = ruleLine('/sermons/*');
      final block = toml.sublist(line, line + 3).join('\n');
      expect(block, contains('status = 404'));
      expect(block, isNot(contains('force')),
          reason: 'forcing it would shadow all 930 real pages');
    });

    test('the body names no product, because it cannot know the language',
        () {
      final body = renderNotFound();
      expect(body, contains('Sermon not found'));
      expect(body, contains('讲道不存在'));
      expect(body, isNot(contains("Yahweh's Words")));
      expect(body, isNot(contains('雅伟之言')));
    });
  });

  group('against the real assets', () {
    final metas = loadIndex(File('assets/sermons/index.json'));

    test('the index and the count the app advertises agree', () {
      // sermonCount is what the app tells users. If they disagree, one
      // of the two screens is lying.
      expect(metas.length, 289);
    });

    test('every sermon has a title in every language', () {
      for (final m in metas) {
        for (final l in sermonLangs) {
          expect(m.titleFor(l).trim(), isNotEmpty,
              reason: 'sermon ${m.id} has no ${l.dir} title, so its page '
                  'would render an empty <h1>');
        }
      }
    });

    test('a real transcript renders with its real paragraphs', () {
      final raw = File('assets/sermons/zh-CN/004.txt').readAsStringSync();
      final parsed = parseTranscript(raw);
      expect(parsed.title, isNotNull);
      expect(parsed.paragraphs.length, greaterThan(5));
      // The count must equal a plain blank-line split of the body —
      // nothing added, nothing merged.
      final manual = raw
          .split('\n')
          .skip(1)
          .join('\n')
          .trim()
          .split(RegExp(r'\n\s*\n'))
          .where((p) => p.trim().isNotEmpty)
          .length;
      expect(parsed.paragraphs.length, manual);
    });

    test('the raw-ASR files are published whole, not repunctuated', () {
      for (final id in ['EC018', 'EC019']) {
        final raw = File('assets/sermons/en/$id.txt').readAsStringSync();
        final parsed = parseTranscript(raw);
        final joined = parsed.paragraphs.join('\n\n');
        // Every non-whitespace character survives.
        expect(joined.replaceAll(RegExp(r'\s'), '').length,
            raw.split('\n').skip(1).join('\n').replaceAll(RegExp(r'\s'), '')
                .length,
            reason: '$id lost or gained characters on the way to the page');
      }
    });
  });
}
