// The prerendered, JavaScript-free Bible under /read/ —
// tools/prerender_bible.dart.
//
// 2026-08-31, from the user: 「可以然后再加上梁本」 — go ahead with the
// static pages, and include 梁家铿译本.
//
// These pages are the only crawlable text the site has: the app paints
// scripture into a CanvasKit <canvas> and addresses chapters with hash
// routes, so before this existed there was one indexable URL with no
// words in it. That makes the failure modes here quiet and expensive:
//
//   * A licence mistake publishes a copyrighted translation as ~1,200
//     static, indexable, permanently-archived pages. Far worse than
//     bundling it in an app, and not undoable by deleting files.
//   * A wrong <link rel="canonical"> or a stray hreflang makes 4,300
//     pages compete with each other instead of ranking.
//   * An unescaped verse breaks the markup on exactly the chapters
//     whose text happens to contain `&` or `<`.
//   * The generator silently not running leaves web/sitemap.xml (a
//     static INDEX) pointing at five children that 404.
//
// None of that shows up in a browser looking at the app.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/bible_versions.dart';

import '../tools/prerender_bible.dart';
import 'support/mini_xml.dart';

const _prod = 'https://yahwehword.com';

PrerenderChapter _chapter(
  String version,
  String book,
  int number,
  List<String> verses,
) =>
    PrerenderChapter(
      version: version,
      englishBook: book,
      chapter: number,
      verses: [
        for (var i = 0; i < verses.length; i++)
          PrerenderVerse(
            label: '${i + 1}',
            anchor: '${i + 1}',
            html: verseHtml(verses[i]),
            plain: versePlain(verses[i]),
          ),
      ],
    );

/// A stand-in edition that claims to hold exactly the chapters listed.
/// Enough for the cross-version and hreflang links, without reading
/// 30 MB of JSON.
PrerenderEdition _edition(String version, Map<String, List<int>> books) =>
    PrerenderEdition(
      version: version,
      books: books.keys.toList(),
      chapters: {
        for (final e in books.entries)
          e.key: [
            for (final n in e.value)
              PrerenderChapter(
                  version: version, englishBook: e.key, chapter: n, verses: []),
          ],
      },
    );

void main() {
  group('which translations may be published as static pages', () {
    // The single most consequential line in the generator. Publishing a
    // licensed translation as thousands of crawlable pages is a
    // different act from bundling it in an app, and it is not undone by
    // deleting the files afterwards — they get archived and cached.
    test('no translation the project cannot redistribute', () {
      for (final banned in ['nasb', 'leb', 'niv']) {
        expect(prerenderVersions, isNot(contains(banned)),
            reason: '$banned is not cleared for redistribution. '
                'NIV was removed from the app outright in 2026-05 '
                '(Biblica/Zondervan), and docs/autonomous-queue.md '
                'records the user\'s position that NASB needs '
                'permission. Do not add either here without a licence.');
      }
    });

    test('every prerendered version is a real edition of this app', () {
      final known = bibleVersions.map((v) => v.value).toSet();
      for (final v in prerenderVersions) {
        expect(known, contains(v));
        expect(File('assets/$v.json').existsSync(), isTrue,
            reason: 'assets/$v.json must exist for the generator to read');
      }
    });
  });

  group('the static sitemap index and the generator agree', () {
    // web/sitemap.xml is committed; the children it names are generated
    // at release time. Nothing at runtime reconciles them — a mismatch
    // surfaces only as a "couldn't fetch" row in Search Console, weeks
    // later.
    final doc = XmlDocument.parse(File('web/sitemap.xml').readAsStringSync());
    final children = doc.findAll('loc');

    test('names exactly one child per prerendered edition, plus home', () {
      final expected = <String>{
        '$_prod/sitemap-home.xml',
        for (final v in prerenderVersions) '$_prod/sitemap-$v.xml',
      };
      expect(children.toSet(), expected);
    });

    test('the static home child is committed, not generated', () {
      expect(File('web/sitemap-home.xml').existsSync(), isTrue);
    });

    test('every generated page is reachable from some sitemap', () {
      // Found by counting, 2026-08-31: the five generated sitemaps start
      // at /read/<edition>/ and sitemap-home.xml held only `/`, so the
      // ONE page that links all five editions together — the /read/ hub
      // — was in no sitemap at all. 4,344 edition urls + 1 home against
      // 4,346 generated pages. It was still reachable (every one of
      // those pages footers back to it), but the entry point to the
      // whole tree should not depend on a footer link being followed.
      final home =
          XmlDocument.parse(File('web/sitemap-home.xml').readAsStringSync())
              .findAll('loc');
      expect(home, contains('$_prod${readIndexPath()}'),
          reason: 'the /read/ hub belongs to no generated sitemap, so it '
              'has to be listed here');
    });
  });

  group('the release actually runs the generator', () {
    // Assertions about what a script DOES must not be satisfied by what
    // it SAYS. release_web.sh is heavily commented and several of those
    // comments name `flutter build web` and the prerender step in prose
    // — including the one explaining this very rule. Strip `#` lines
    // first, exactly as the sibling SEO test strips `<!-- -->` and `//`.
    final commands = File('tools/release_web.sh')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('#'))
        .toList();

    test('both bundles prerender before they deploy', () {
      // Two builds (international, then CHINA_MODE), each overwriting
      // build/web in place. A prerender that ran only once would ship
      // pages on one bundle and 404s on the other.
      final builds =
          commands.where((l) => l.contains(r'$FLUTTER" build web')).length;
      final calls = commands.where((l) => l.trim() == 'prerender').length;
      expect(builds, 2,
          reason: 'expected the international and CHINA_MODE builds');
      expect(calls, greaterThanOrEqualTo(builds),
          reason: 'every build needs its own prerender pass — the second '
              'build overwrites the first one\'s output');
    });

    test('the generator it calls is the one this test checks', () {
      expect(commands.any((l) => l.contains('tools/prerender_bible.dart')),
          isTrue);
    });
  });

  group('a bad /read/ url answers 404, not 200', () {
    // Measured on qat 2026-08-31, before the rule existed: every path
    // under /read/ that did not resolve to a generated file fell through
    // the SPA catch-all and answered 200 with the Flutter shell —
    // /read/kjv/john/999/, /read/totally-made-up/, and worst of all
    // /read/nasb/john/3/, naming a translation the project has no
    // licence to publish. Google indexes those as an unbounded supply of
    // duplicates of the home page.
    //
    // Netlify matches redirects top-to-bottom, first match wins, so the
    // whole fix is ordering. Reordering this file would restore the bug
    // silently — nothing in the app changes, and only a crawler notices.
    final toml = File('netlify.toml').readAsLinesSync();
    int ruleLine(String from) =>
        toml.indexWhere((l) => l.trim() == 'from = "$from"');

    test('the /read/ rule exists and sits above the SPA catch-all', () {
      final read = ruleLine('/read/*');
      final spa = ruleLine('/*');
      expect(read, isNot(-1), reason: 'the /read/* 404 rule is gone');
      expect(spa, isNot(-1));
      expect(read, lessThan(spa),
          reason: 'below the catch-all it can never match — first match wins');
    });

    test('it is a real 404 and is not forced', () {
      final read = ruleLine('/read/*');
      final block = toml.sublist(read, read + 3).join('\n');
      expect(block, contains('status = 404'),
          reason: 'a 200 here is the soft-404 this rule exists to remove');
      expect(block, isNot(contains('force')),
          reason: 'forcing it would shadow all 4,300 real pages under /read/');
    });

    test('the body it serves is generated', () {
      final body = renderNotFound();
      expect(body, contains('<html lang="en">'));
      expect(body, contains('Page not found'));
      expect(body, contains('页面不存在'));
      // It cannot know which language the reader wanted — the url was
      // not a page — so it names no product at all rather than guessing.
      expect(body, isNot(contains("Yahweh's Words")));
      expect(body, isNot(contains('雅伟之言')));
    });
  });

  group('verse text', () {
    test('strips <note:> popups completely', () {
      // The marker is not inline text — it renders as a popup in the app
      // and would otherwise appear as literal "&lt;note:...&gt;" on the
      // page, on the ~1,100 chapters per edition that carry one.
      final out = verseHtml('亚伯拉罕的后裔<note:参路3.23-38。>的家谱：');
      expect(out, isNot(contains('note:')));
      expect(out, '亚伯拉罕的后裔的家谱：');
    });

    test('escapes characters that would break the markup', () {
      final out = verseHtml('Shadrach & <Meshach> "Abednego"');
      expect(out, contains('&amp;'));
      expect(out, contains('&lt;Meshach&gt;'));
      expect(out, isNot(matches(RegExp(r'<(?!br>)'))),
          reason: 'nothing but <br> may survive as a real tag');
    });

    test('keeps line breaks as <br>, so poetry stays poetry', () {
      expect(verseHtml('line one\nline two'), 'line one<br>line two');
    });

    test('normalises the divine name the way the app does', () {
      // The app renders LORD → Yahweh and 耶和华 → 雅伟 at the view layer.
      // A static page that skipped this would publish a different Bible
      // from the one the reader sees.
      expect(verseHtml('the LORD is my shepherd'), startsWith('Yahweh'));
      expect(verseHtml('耶和华是我的牧者'), startsWith('雅伟'));
    });

    test('the meta-description form carries no markup at all', () {
      final out = versePlain('a<note:x>b\nc');
      expect(out, 'ab c');
    });
  });

  group('chapter page', () {
    final editions = {
      'kjv': _edition('kjv', {
        'Genesis': [1, 2],
        'John': [3]
      }),
      'cuvs-yhwh': _edition('cuvs-yhwh', {
        'Genesis': [1, 2],
        'John': [3]
      }),
      'cuvs-yhwh-tr': _edition('cuvs-yhwh-tr', {
        'Genesis': [1, 2],
        'John': [3]
      }),
      'biblexg-v2': _edition('biblexg-v2', {
        'John': [3]
      }),
      'biblexg-v2-tr': _edition('biblexg-v2-tr', {
        'John': [3]
      }),
    };

    String render(String version, String book, int n, int last,
            [List<String> verses = const ['In the beginning.']]) =>
        renderChapter(_chapter(version, book, n, verses),
            editions: editions, lastChapterInBook: last);

    test('declares its own url as canonical', () {
      expect(render('kjv', 'John', 3, 21),
          contains('<link rel="canonical" href="$_prod/read/kjv/john/3/">'));
    });

    test('declares the language it is actually written in', () {
      expect(render('kjv', 'John', 3, 21), contains('<html lang="en">'));
      expect(
          render('cuvs-yhwh', 'John', 3, 21), contains('<html lang="zh-Hans">'));
      expect(render('cuvs-yhwh-tr', 'John', 3, 21),
          contains('<html lang="zh-Hant">'));
    });

    test('one name per language, never the pair', () {
      // The user's rule, restated 2026-08-31. The share card could not
      // honour it (one card, every reader, no JS to choose with); these
      // pages can, because each is already in exactly one language.
      final en = render('kjv', 'John', 3, 21);
      expect(en, contains("Yahweh's Words"));
      expect(en, isNot(contains('雅伟之言')));
      expect(en, isNot(contains('雅偉之言')));

      final hans = render('cuvs-yhwh', 'John', 3, 21);
      expect(hans, contains('雅伟之言'));
      expect(hans, isNot(contains("Yahweh's Words")));

      final hant = render('cuvs-yhwh-tr', 'John', 3, 21);
      expect(hant, contains('雅偉之言'));
      expect(hant, isNot(contains("Yahweh's Words")));
    });

    test('the edition is in the title, so five pages do not compete', () {
      // Five editions carry John 3. Without the edition in the <title>
      // they are five near-identical pages fighting over one query.
      expect(render('kjv', 'John', 3, 21),
          contains('<title>John 3 — King James Version'));
      expect(render('biblexg-v2', 'John', 3, 21),
          contains('<title>约翰福音 3章 — 梁家铿译本(简体)'));
    });

    test('no prev link on the first chapter, no next on the last', () {
      final first = render('kjv', 'Genesis', 1, 50);
      expect(first, isNot(contains('rel="prev"')));
      expect(first, contains('rel="next"'));

      // Wrapping Revelation 22 round to Genesis 1 would be a lie about
      // what comes next, so the link is simply absent.
      final last = render('kjv', 'Genesis', 50, 50);
      expect(last, contains('rel="prev"'));
      expect(last, isNot(contains('rel="next"')));
    });

    test('hreflang pairs only the two scripts of the SAME translation', () {
      final page = render('cuvs-yhwh', 'John', 3, 21);
      expect(page,
          contains('hreflang="zh-Hant" href="$_prod/read/cuvs-yhwh-tr/john/3/"'));
      expect(page,
          contains('hreflang="zh-Hans" href="$_prod/read/cuvs-yhwh/john/3/"'));
      // KJV and 梁家铿 are different works, not translations of this page.
      expect(page, isNot(contains('hreflang="en"')));
      expect(page, isNot(contains('hreflang="zh-Hans" href="$_prod/read/biblexg')));
    });

    test('an edition with no script twin declares no hreflang', () {
      expect(render('kjv', 'John', 3, 21), isNot(contains('hreflang=')));
    });

    test('cross-links only to editions that really have the chapter', () {
      // 梁家铿 is New Testament only. Linking Genesis 1 to it would send
      // both readers and crawlers to a page that was never generated.
      final gen = render('kjv', 'Genesis', 1, 50);
      expect(gen, isNot(contains('/read/biblexg-v2/genesis/')));
      expect(gen, contains('/read/cuvs-yhwh/genesis/1/'));

      final john = render('kjv', 'John', 3, 21);
      expect(john, contains('/read/biblexg-v2/john/3/'));
    });

    test('links back into the app with the app\'s own url grammar', () {
      // The query lives INSIDE the fragment — see
      // lib/services/url_sync_service_web.dart. `?v=` before the `#`
      // would silently open the reader on the wrong edition.
      expect(render('cuvs-yhwh', 'John', 3, 21),
          contains('href="$_prod/#/john/3?v=cuvs-yhwh"'));
    });

    test('every verse is addressable by its own anchor', () {
      final page = render('kjv', 'John', 3, 21, ['one', 'two', 'three']);
      expect(page, contains('<p id="v2">'));
      expect(page, contains('href="#v2"'));
    });

    test('the description is the real opening text, not boilerplate', () {
      final page = render('kjv', 'John', 3, 21, ['There was a man.']);
      expect(page,
          contains('<meta name="description" content="There was a man.">'));
    });
  });

  group('index pages', () {
    test('the /read/ hub is English, per the one-name rule', () {
      final hub = renderReadIndex({
        'kjv': _edition('kjv', {
          'Genesis': [1]
        }),
      });
      expect(hub, contains('<html lang="en">'));
      expect(hub, contains("Yahweh's Words"));
      expect(hub, isNot(contains('雅伟之言')));
      expect(hub, contains('<link rel="canonical" href="$_prod/read/">'));
    });

    test('a book index links every chapter it was given', () {
      final page = renderBookIndex('kjv', 'John', [1, 2, 3]);
      expect(page, contains('<link rel="canonical" href="$_prod/read/kjv/john/">'));
      for (final c in [1, 2, 3]) {
        expect(page, contains('href="/read/kjv/john/$c/"'));
      }
    });

    test('a version index separates the testaments it actually ships', () {
      // 梁家铿 has no Old Testament, so that heading must not appear at
      // all — an empty "旧约" section reads as missing data.
      final nt = renderVersionIndex(_edition('biblexg-v2', {
        'Matthew': [1],
        'Revelation': [1],
      }));
      expect(nt, contains('新约'));
      expect(nt, isNot(contains('旧约')));

      final full = renderVersionIndex(_edition('kjv', {
        'Genesis': [1],
        'Matthew': [1],
      }));
      expect(full, contains('Old Testament'));
      expect(full, contains('New Testament'));
    });
  });

  group('generated sitemaps', () {
    test('are well-formed and hold only absolute prod urls', () {
      final xml = renderSitemap(['/read/', '/read/kjv/john/3/']);
      final doc = XmlDocument.parse(xml);
      expect(doc.rootName, 'urlset');
      expect(doc.findAll('loc'),
          ['$_prod/read/', '$_prod/read/kjv/john/3/']);
    });
  });

  group('against the real asset', () {
    // One edition, loaded for real. The synthetic tests above prove the
    // rendering rules; this proves the loader survives the actual data —
    // merged verse labels, `<note:>` markers, and a canon that stops at
    // Matthew.
    test('梁家铿译本 loads as New Testament only, with notes stripped', () {
      final ed = loadEdition('biblexg-v2', File('assets/biblexg-v2.json'));
      expect(ed.books.first, 'Matthew');
      expect(ed.books.last, 'Revelation');
      expect(ed.books.length, 27);
      expect(ed.has('Genesis', 1), isFalse);
      expect(ed.has('John', 3), isTrue);

      for (final chapters in ed.chapters.values) {
        for (final ch in chapters) {
          for (final v in ch.verses) {
            expect(v.html, isNot(contains('note:')));
          }
        }
      }
    });

    test('every book in every edition has a url slug', () {
      // A book with no slug throws at generation time; catching it here
      // means the release does not fail halfway through writing 4,000
      // files.
      for (final v in prerenderVersions) {
        final ed = loadEdition(v, File('assets/$v.json'));
        for (final book in ed.books) {
          expect(() => slugOf(book), returnsNormally, reason: '$v / $book');
        }
      }
    });
  });
}
