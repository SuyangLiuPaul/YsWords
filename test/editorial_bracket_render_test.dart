import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/text_patterns.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/utils/build_verse_content_spans.dart';

/// The brackets in 和合本雅伟版 are the edition's own notation for an
/// editorial insertion, and the reader has to be able to see them.
///
/// Matthew 1:20 in Greek is `ἄγγελος κυρίου` — "an angel of the Lord".
/// The edition supplies the divine name and marks that it did so:
/// `有主[雅偉]的使者`. Until 2026-09-01 the reader rendered the bracketed
/// word in the theme accent and DROPPED the brackets, so the line read
/// `有主雅偉的使者` with 雅偉 merely coloured. Colour cannot say
/// "supplied by the editor" — the user reported that readers would take
/// the word for original text, which is exactly what it looks like.
///
/// Three surfaces disagreed about the same verse, which is how this was
/// found: the asset ships `[雅偉]`, the prerendered /read/ page prints
/// `[雅偉]`, and only the Flutter reader stripped them.
///
/// The scope is version-gated because `[...]` does NOT mean the same
/// thing in every edition — see [kBracketPreservingVersions]. These
/// tests pin the measurements that decided the gate, so that if an asset
/// is ever re-imported with different conventions the gate is revisited
/// rather than silently wrong.
void main() {
  List<Map<String, dynamic>> load(String path) =>
      (json.decode(File(path).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  final square = RegExp(r'\[([^\]]+)\]');

  group('the allowlist matches what the assets actually contain', () {
    test('cuvs-yhwh brackets are exactly the two referent insertions', () {
      for (final code in kBracketPreservingVersions) {
        final verses = load('assets/$code.json');
        final found = <String, int>{};
        for (final v in verses) {
          for (final m in square.allMatches(v['text'] as String)) {
            found.update(m.group(1)!, (n) => n + 1, ifAbsent: () => 1);
          }
        }
        // Three distinct inserts, all three names, nothing else.
        //
        // This said TWO until 2026-09-02, and it did exactly the job it
        // was written for: the third marker landed and this stopped the
        // build so a person looked before brackets started printing at
        // readers. The edition always had three — `主[雅偉]` Yahweh,
        // `主#` 基督, `主*` 耶穌 — and the asterisk had been deleted as
        // importer noise, twice, by people who never asked what the
        // publisher's convention was. Restored on the user's
        // instruction; see test/cuv_three_referent_markers_test.dart.
        //
        // A FOURTH should still stop the build. That is the point.
        expect(found.keys.toSet(), hasLength(3),
            reason: '$code should bracket exactly three distinct strings, '
                'got ${found.keys.toList()}');
        final isTrad = code.endsWith('-tr');
        expect(found.keys, contains(isTrad ? '雅偉' : '雅伟'));
        expect(found.keys, contains('基督'));
        expect(found.keys, contains(isTrad ? '耶穌' : '耶稣'));
      }
    });

    test('Matthew 1:20 still ships the brackets this feature renders', () {
      for (final code in kBracketPreservingVersions) {
        final isTrad = code.endsWith('-tr');
        final name = isTrad ? '雅偉' : '雅伟';
        final book = isTrad ? '馬太福音' : '马太福音';
        final v = load('assets/$code.json').firstWhere(
          (e) =>
              e['book'] == book && e['chapter'] == '1' && e['verse'] == '20',
        );
        expect(v['text'], contains('[$name]'),
            reason: 'the asset is the source of the brackets; if this '
                'fails the render change has nothing to render');
      }
    });
  });

  group('editions deliberately left OUT of the allowlist', () {
    test('LEB is excluded — its brackets are supplied function words', () {
      expect(kBracketPreservingVersions, isNot(contains('leb')));
      final verses = load('assets/leb.json');
      var n = 0;
      for (final v in verses) {
        n += square.allMatches(v['text'] as String).length;
      }
      // Measured 29,652 on 2026-09-01. The exact number will drift if
      // the asset is re-imported; the POINT is the order of magnitude —
      // bracketing these would bracket a third of the New Testament,
      // which is why LEB is not on the list.
      expect(n, greaterThan(10000),
          reason: 'if LEB\'s bracket count has collapsed, its convention '
              'changed and the exclusion should be re-examined');
    });

    test('NASB and KJV are excluded', () {
      expect(kBracketPreservingVersions, isNot(contains('nasb')));
      expect(kBracketPreservingVersions, isNot(contains('kjv')));
    });
  });

  group('what actually reaches the screen', () {
    /// Renders one verse through the real span builder and returns the
    /// plain text a reader would see. This is the assertion that matters
    /// — the allowlist tests above prove the DATA has brackets, this
    /// proves the reader stops eating them.
    Future<String> render(
      WidgetTester tester,
      String text, {
      String? versionCode,
    }) async {
      late List<InlineSpan> spans;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            spans = buildVerseContentSpans(
              verse: Verse(
                book: '馬太福音',
                chapter: 1,
                verse: 20,
                verseLabel: '20',
                text: text,
              ),
              context: context,
              settings: AppSettings(),
              locale: 'zh-Hant',
              isSelected: false,
              versionCode: versionCode,
            );
            return RichText(text: TextSpan(children: spans));
          }),
        ),
      ));
      final rich = tester.widget<RichText>(find.byType(RichText).first);
      return rich.text.toPlainText(includePlaceholders: false);
    }

    testWidgets('雅偉版 keeps the brackets a reader needs to see',
        (tester) async {
      final out = await render(
        tester,
        '正思念這事的時候，有主[雅偉]的使者向他夢中顯現，',
        versionCode: 'cuvs-yhwh-tr',
      );
      expect(out, contains('主[雅偉]的使者'),
          reason: 'the brackets mark 雅偉 as supplied by the editor; '
              'without them the reader cannot tell it is not in the Greek');
    });

    testWidgets('the simplified edition behaves identically', (tester) async {
      final out = await render(
        tester,
        '正思念这事的时候，有主[雅伟]的使者向他梦中显现，',
        versionCode: 'cuvs-yhwh',
      );
      expect(out, contains('主[雅伟]的使者'));
    });

    testWidgets('[基督] is bracketed too — same edition, same notation',
        (tester) async {
      final out =
          await render(tester, '主[基督]的道', versionCode: 'cuvs-yhwh');
      expect(out, contains('主[基督]的道'));
    });

    testWidgets('[耶稣] reaches the screen — the marker restored 2026-09-02',
        (tester) async {
      // The classification is pinned in cuv_three_referent_markers_test;
      // this is the other half, that it actually renders. 約翰福音 4:1 is
      // the verse the user reported, and it is the one a reader opens.
      final out = await render(
        tester,
        '主[耶稣]知道法利赛人听见他收门徒，施洗，比约翰还多，',
        versionCode: 'cuvs-yhwh',
      );
      expect(out, contains('主[耶稣]知道法利赛人'));
    });

    testWidgets('[耶穌] renders in the traditional edition too',
        (tester) async {
      final out = await render(
        tester,
        '主[耶穌]知道法利賽人聽見他收門徒，施洗，比約翰還多，',
        versionCode: 'cuvs-yhwh-tr',
      );
      expect(out, contains('主[耶穌]知道法利賽人'));
    });

    testWidgets('LEB is untouched — supplied words stay unbracketed',
        (tester) async {
      final out = await render(
        tester,
        'Now [the] angel of [the] Lord appeared',
        versionCode: 'leb',
      );
      expect(out, 'Now the angel of the Lord appeared',
          reason: 'LEB has ~30k of these; bracketing them would bracket '
              'a third of the New Testament');
    });

    testWidgets('an unknown/null version falls back to the old behaviour',
        (tester) async {
      final out = await render(tester, '有主[雅偉]的使者');
      expect(out, contains('有主雅偉的使者'));
      expect(out, isNot(contains('[')));
    });
  });

  test('the allowlist names only editions that ship', () {
    for (final code in kBracketPreservingVersions) {
      expect(File('assets/$code.json').existsSync(), isTrue,
          reason: '$code is on the bracket allowlist but has no asset');
      expect(File('pubspec.yaml').readAsStringSync(),
          contains('assets/$code.json'),
          reason: '$code must be declared in pubspec to ship at all');
    }
  });
}
