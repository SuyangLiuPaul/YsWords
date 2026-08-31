// The discovery / sharing layer: robots.txt, sitemap.xml, the Open
// Graph card, and the JSON-LD in web/index.html.
//
// 2026-08-31, from the user: 「另一个是SEO，你可以帮忙推广这个app」.
//
// Every assertion here exists because the corresponding mistake is
// INVISIBLE in normal use. The app looks identical whether og:image is
// absolute or relative; you only find out when someone pastes the link
// into WeChat and it unfurls blank. Nothing in a browser tells you the
// sitemap stopped being XML. `flutter test` can, so it does.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _prod = 'https://yahwehword.com';

void main() {
  final html = File('web/index.html').readAsStringSync();
  // Assertions about what the page DECLARES must not be satisfied — or
  // broken — by prose. index.html is heavily commented on purpose, and
  // several of those comments name the very tags checked below: one
  // explains why there is no hreflang, another QUOTES the old
  // side-by-side name pair while recording the day it was dropped.
  // Both are documentation of a decision, not the decision itself.
  //
  // Two comment syntaxes live in this file — <!-- --> around markup and
  // // inside the boot <script>s — so both come out. A `//` is only
  // treated as a comment when it opens the line, which keeps every
  // `https://` in the file intact.
  final markup = html
      .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  String? metaContent(String attr, String key) {
    // Tolerant of attribute order: the tag is authored `property=…
    // content=…` today, but a reformat that flips them must not turn
    // these tests red for no reason.
    final a = RegExp('<meta[^>]*$attr="$key"[^>]*content="([^"]*)"')
        .firstMatch(markup);
    if (a != null) return a.group(1);
    final b = RegExp('<meta[^>]*content="([^"]*)"[^>]*$attr="$key"')
        .firstMatch(markup);
    return b?.group(1);
  }

  group('index.html head', () {
    test('declares one canonical home, and it is prod', () {
      final m = RegExp(r'<link rel="canonical" href="([^"]*)"').firstMatch(markup);
      expect(m, isNotNull, reason: 'no canonical — dev, qat and the two '
          '*.netlify.app hostnames serve identical HTML and compete with '
          'prod as duplicates');
      expect(m!.group(1), '$_prod/');
      expect(RegExp(r'rel="canonical"').allMatches(markup).length, 1,
          reason: 'two canonicals is the same as none — crawlers ignore '
              'the pair');
    });

    test('og:image and twitter:image are ABSOLUTE urls', () {
      // The one that bites in practice. A relative og:image renders fine
      // in every validator that resolves it against the page, and shows
      // nothing at all in WeChat — which is where this app is shared.
      for (final pair in [
        ('property', 'og:image'),
        ('name', 'twitter:image'),
      ]) {
        final v = metaContent(pair.$1, pair.$2);
        expect(v, isNotNull, reason: '${pair.$2} is missing');
        expect(v, startsWith('https://'),
            reason: '${pair.$2} must be absolute; WeChat and several '
                'other unfurlers will not resolve a relative one');
      }
    });

    test('the card the tags point at exists and is really 1200x630', () {
      final url = metaContent('property', 'og:image')!;
      final path = 'web${url.substring(_prod.length)}';
      final file = File(path);
      expect(file.existsSync(), isTrue,
          reason: '$path is missing — every share unfurls with no image. '
              'Regenerate with `python3 tools/make_og_card.py`');

      // Read the dimensions out of the PNG IHDR rather than trusting the
      // meta tags, so swapping in a square icon (the tempting shortcut)
      // fails here instead of silently shipping a cropped card.
      final b = file.readAsBytesSync();
      expect(b.length, greaterThan(24), reason: 'not a PNG');
      int be32(int o) =>
          (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
      final w = be32(16), h = be32(20);
      expect([w, h], [1200, 630],
          reason: 'og-card.png is ${w}x$h. 1200x630 is the 1.91:1 ratio '
              'every major unfurler crops to');
      expect(metaContent('property', 'og:image:width'), '$w');
      expect(metaContent('property', 'og:image:height'), '$h');

      // WeChat drops images past roughly 300 KB.
      expect(b.length, lessThan(300 * 1024),
          reason: 'og-card.png is ${(b.length / 1024).round()} KB; large '
              'cards get skipped by some unfurlers');
    });

    test('description exists and is a sentence, not a stub', () {
      final d = metaContent('name', 'description');
      expect(d, isNotNull);
      expect(d!.length, greaterThan(60));
      // Google truncates the SNIPPET but does not penalise length; this
      // ceiling is only here to catch a paragraph pasted in by mistake.
      expect(d.length, lessThan(320));
      expect(d, contains('雅伟'),
          reason: 'the Chinese name is the most winnable query this app '
              'has; it belongs in the description');
    });

    test('structured data parses, and claims nothing it cannot back', () {
      final m = RegExp(
              r'<script type="application/ld\+json">([\s\S]*?)</script>')
          .firstMatch(markup);
      expect(m, isNotNull, reason: 'JSON-LD block is gone');

      // A JSON-LD block that does not parse is worse than none: Search
      // Console reports it as an error against the page.
      final decoded = jsonDecode(m!.group(1)!) as Map<String, dynamic>;
      final graph = (decoded['@graph'] as List).cast<Map<String, dynamic>>();
      expect(graph.map((n) => n['@type']),
          containsAll(<String>['WebSite', 'WebApplication']));

      final raw = m.group(1)!;
      // Invented ratings are the fastest route to a manual action, and
      // they are exactly what an "improve the SEO" edit tends to add.
      for (final banned in ['aggregateRating', 'reviewCount', 'ratingValue']) {
        expect(raw, isNot(contains(banned)),
            reason: '$banned appears in the structured data. There are no '
                'real ratings to report; fabricating them risks a manual '
                'action against the whole site');
      }
    });

    test('never prints the two names side by side', () {
      // The user's rule, given 2026-08-30 and restated 2026-08-31:
      // English is "Yahweh's Words", Chinese is 雅伟之言, and no screen
      // shows the pair. The app honours it by reading the reader's own
      // language — but OG tags and the share card are STATIC (unfurlers
      // do not run JavaScript), so the pair is exactly what a
      // well-meaning edit reaches for when one tag has to serve both
      // audiences. It got in once already, in the first version of this
      // very block.
      //
      // The rule is about the NAME. Describing the app in both languages
      // is fine and deliberate; what must not happen is the two names
      // rendered as a single label.
      final pair = RegExp(
          "(Yahweh's Words\\s*[·・|/,、_—–-]?\\s*雅[伟偉]之言)"
          "|(雅[伟偉]之言\\s*[·・|/,、_—–-]?\\s*Yahweh's Words)");
      final hit = pair.firstMatch(markup);
      expect(hit, isNull,
          reason: 'the two names appear together as "${hit?.group(0)}". '
              'One name per language: English text says '
              "Yahweh's Words, Chinese text says 雅伟之言.");
    });

    test('no hreflang, because there are no per-language urls', () {
      // Three scripts, one URL. hreflang REQUIRES a distinct URL per
      // language; pointing all three at "/" is a self-contradiction that
      // Search Console flags. If per-language paths ever ship, this test
      // is the place to invert.
      expect(markup, isNot(contains('hreflang=')));
    });
  });

  group('the version count the copy advertises', () {
    // The user caught "7 translations" by eye (2026-08-31: 「7
    // translation有那么多吗？」) and then fixed the word as well
    // (「应该叫做7 versions吧不然以为7个语言」). Both halves are pinned
    // here, because marketing copy is exactly the kind of text that
    // nothing else in the build ever re-reads.
    final src = File('lib/constants/bible_versions.dart').readAsStringSync();
    final list = src.substring(
      src.indexOf('const bibleVersions ='),
      src.indexOf('\n];', src.indexOf('const bibleVersions =')),
    );
    // Comments out first: this file carries long ones, several of which
    // quote `value:` while explaining a past change.
    final entries = RegExp(r"value:\s*'([^']+)'")
        .allMatches(list.replaceAll(RegExp(r'//[^\n]*'), ''))
        .map((m) => m.group(1)!)
        .toList();
    // Python `#` comments come out for the same reason the HTML and JS
    // ones do: make_og_card.py documents this very decision by QUOTING
    // the wording that was rejected. Stripping is per-language on
    // purpose — blanket-removing `#` lines from index.html would eat
    // `#ys-boot { … }`, which is a CSS selector another test depends on.
    final card = File('tools/make_og_card.py')
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('#'))
        .join('\n');

    test('matches what the picker actually offers', () {
      expect(entries.length, 7,
          reason: 'the version list changed — the share card and the '
              'JSON-LD featureList both advertise a count and neither '
              'is derived at build time');
      for (final text in [card, markup]) {
        expect(text, contains('${entries.length} versions'));
      }
    });

    test('says "versions", never "N translations"', () {
      // 7 versions is 5 translations: 和合本雅伟版 and 梁家铿译本 each
      // ship 简体 and 繁體 of the SAME translation, converted
      // script-wise. Calling the 7 "translations" implies seven
      // languages, which is the overclaim the user rejected.
      final distinct =
          entries.map((v) => v.replaceAll(RegExp(r'-tr$'), '')).toSet();
      expect(distinct.length, lessThan(entries.length),
          reason: 'if 简/繁 pairs ever stop existing, this whole '
              'distinction — and this test — should be revisited');

      final overclaim = RegExp(r'\d+\s+translations|[Ss]even\s+translations');
      for (final entry in {'tools/make_og_card.py': card, 'web/index.html': markup}.entries) {
        final hit = overclaim.firstMatch(entry.value);
        expect(hit, isNull,
            reason: '${entry.key} claims "${hit?.group(0)}". There are '
                '${entries.length} VERSIONS but only ${distinct.length} '
                'translations; "translations" reads as that many '
                'languages. Use "versions".');
      }
    });
  });

  group('no-JavaScript visitors', () {
    test('get real content instead of a splash frozen forever', () {
      final ns = RegExp(r'<noscript>([\s\S]*?)</noscript>').firstMatch(markup);
      expect(ns, isNotNull);
      final body = ns!.group(1)!;
      // #ys-boot is fixed/inset-0 at a near-maximum z-index and only the
      // Dart bundle removes it, so without this rule the content below
      // is unreachable — the visitor stares at a progress bar that can
      // never advance.
      expect(body, contains('#ys-boot { display: none !important; }'),
          reason: 'the noscript content renders BEHIND the boot splash');
      expect(body, contains('雅伟之言'));
      expect(body, contains("Yahweh's Words"));
    });
  });

  group('robots.txt', () {
    final robots = File('web/robots.txt');

    test('exists as a real file', () {
      // Without it, /robots.txt falls through the SPA catch-all and
      // answers with HTML under content-type: text/html.
      expect(robots.existsSync(), isTrue);
    });

    test('points at the sitemap', () {
      expect(robots.readAsStringSync(), contains('Sitemap: $_prod/sitemap.xml'));
    });

    test('never blocks what the renderer needs', () {
      // The silent, total failure: a crawler that cannot fetch the Dart
      // bundle or the assets renders an empty canvas and indexes a blank
      // page. Nothing about the site looks wrong when this happens.
      final lines = robots
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.toLowerCase().startsWith('disallow:'))
          .map((l) => l.split(':').sublist(1).join(':').trim())
          .where((l) => l.isNotEmpty)
          .toList();
      for (final critical in [
        '/main.dart.js',
        '/flutter_bootstrap.js',
        '/assets/anything.json',
        '/canvaskit/canvaskit.wasm',
        '/',
      ]) {
        for (final rule in lines) {
          expect(critical.startsWith(rule), isFalse,
              reason: '`Disallow: $rule` blocks $critical — the crawler '
                  'would see an empty canvas');
        }
      }
    });
  });

  group('sitemap.xml', () {
    final sitemap = File('web/sitemap.xml');

    test('exists and is well-formed XML', () {
      expect(sitemap.existsSync(), isTrue);
      // Parsing rather than substring-matching: a sitemap that is not
      // valid XML is rejected wholesale by Search Console.
      final doc = XmlDocument.parse(sitemap.readAsStringSync());
      expect(doc.rootName, 'urlset');
    });

    test('lists only urls that are actually distinct documents', () {
      final doc = XmlDocument.parse(sitemap.readAsStringSync());
      final locs = doc.findAll('loc');
      expect(locs, isNotEmpty);
      expect(locs.first, '$_prod/');
      // Hash routes are one document to a crawler, and the `?verse=` /
      // `?sermon=` links all return byte-identical HTML. Listing either
      // submits duplicates of the home page.
      for (final loc in locs) {
        expect(loc, isNot(contains('#')),
            reason: 'hash routes are not separately indexable');
        expect(loc, isNot(contains('?')),
            reason: 'every query-param url returns identical HTML — '
                'listing them submits duplicates of the home page');
      }
    });
  });
}

/// Minimal XML reader — enough to prove the sitemap parses and to pull
/// `<loc>` values out of it. `package:xml` is not a dependency of this
/// app and one test does not justify adding it to the shipped
/// dependency tree.
class XmlDocument {
  final String _src;
  const XmlDocument._(this._src);

  static XmlDocument parse(String rawSrc) {
    if (!rawSrc.trimLeft().startsWith('<?xml')) {
      throw FormatException('missing XML declaration');
    }
    // Comments first, exactly as a real parser does. The sitemap's own
    // comment explains why it holds one <url>, and mentioning the tag
    // name in prose must not read as an unclosed element.
    final src = rawSrc.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    // Tag balance: catches a truncated file or an unclosed element,
    // which is the realistic way this file breaks.
    final opens = RegExp(r'<([a-zA-Z][\w:-]*)(\s[^>]*)?>').allMatches(src);
    final stack = <String>[];
    for (final m in opens) {
      final full = m.group(0)!;
      if (full.endsWith('/>')) continue;
      stack.add(m.group(1)!);
    }
    for (final m in RegExp(r'</([a-zA-Z][\w:-]*)>').allMatches(src)) {
      final name = m.group(1)!;
      if (!stack.contains(name)) {
        throw FormatException('closing tag </$name> was never opened');
      }
      stack.remove(name);
    }
    if (stack.isNotEmpty) {
      throw FormatException('unclosed tag(s): ${stack.join(', ')}');
    }
    return XmlDocument._(src);
  }

  /// Name of the first real element. A String, not a wrapper type:
  /// returning a private class from a public getter trips
  /// `library_private_types_in_public_api`, and one name is all any
  /// assertion here needs.
  String get rootName {
    final m = RegExp(r'<([a-zA-Z][\w:-]*)').firstMatch(_src);
    if (m == null) throw FormatException('no root element');
    return m.group(1)!;
  }

  List<String> findAll(String tag) => RegExp('<$tag>\\s*([^<]*?)\\s*</$tag>')
      .allMatches(_src)
      .map((m) => m.group(1)!)
      .toList();
}

