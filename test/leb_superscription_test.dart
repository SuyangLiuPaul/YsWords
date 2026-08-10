import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/widgets/superscription_line.dart';

/// The LEB prints an unnumbered heading above 116 psalms — "A psalm of
/// David at his fleeing from the presence of Absalom, his son." — and
/// `assets/leb.json` has always shipped them, as rows with
/// `verse: "title"`. The reader threw all 116 away: the decoder drops
/// any row whose verse number will not parse as an integer, which is
/// the right rule for junk and the wrong rule for these.
///
/// Nothing was untrue on screen, so no audit caught it; the app was
/// simply showing less scripture than it had. This test reads the real
/// asset through the real decoder, so it fails if the rows stop being
/// carried, if the decoder goes back to discarding them, or if someone
/// promotes them to verses — which would be its own falsehood, because
/// the LEB does not number them.
void main() {
  late final List<Verse> leb;
  late final List<Map<String, dynamic>> raw;

  setUpAll(() {
    final decoded = json.decode(File('assets/leb.json').readAsStringSync());
    raw = List<Map<String, dynamic>>.from(decoded as List);
    leb = FetchVerses.decodeVerses(decoded);
  });

  test('every superscription in the asset reaches a verse', () {
    final titles = raw
        .where((r) => r['verse']?.toString() == 'title')
        .map((r) => '${r['book']}|${r['chapter']}')
        .toList();

    // Pins the asset itself: silent loss upstream is the failure mode
    // this whole exercise exists to catch.
    expect(titles.length, 116);
    expect(titles.toSet().length, titles.length,
        reason: 'two superscriptions for one chapter');

    final carried = leb
        .where((v) => v.superscription.isNotEmpty)
        .map((v) => '${v.book}|${v.chapter}')
        .toList();
    expect(carried.toSet(), titles.toSet());
    expect(carried.length, titles.length,
        reason: 'a superscription was attached to more than one verse');
  });

  test('a superscription is carried by verse 1 and is not itself a verse', () {
    for (final v in leb.where((v) => v.superscription.isNotEmpty)) {
      expect(v.verse, 1, reason: 'superscription attached to ${v.id}');
    }
    // No pseudo-verse leaked into the list. A superscription with an id
    // would collide across versions — `Psalms-3-title` is not a place
    // any other translation has, and a highlight there could never
    // follow the reader from the LEB to the KJV.
    expect(leb.where((v) => v.verseLabel == 'title'), isEmpty);
    expect(leb.where((v) => v.verseLabel.trim().isEmpty), isEmpty);
  });

  test('the superscription text is the asset text, unedited', () {
    final byChapter = {
      for (final v in leb.where((v) => v.superscription.isNotEmpty))
        '${v.book}|${v.chapter}': v.superscription,
    };
    for (final r in raw.where((r) => r['verse']?.toString() == 'title')) {
      expect(byChapter['${r['book']}|${r['chapter']}'],
          r['text'].toString().trim());
    }

    // Psalm 3's heading, spelled out, so a silent content change in the
    // asset is visible in the diff of a failing test rather than only
    // in a count.
    expect(
      byChapter['Psalms|3'],
      startsWith('A psalm of David at his fleeing from the presence of '
          'Absalom, his son.'),
    );
  });

  test('no other version grows a superscription', () {
    for (final name in const [
      'kjv',
      'nasb',
      'cuvs-yhwh',
      'cuvs-yhwh-tr',
      'biblexg-v2',
      'biblexg-v2-tr',
    ]) {
      final verses = FetchVerses.decodeVerses(
          json.decode(File('assets/$name.json').readAsStringSync()));
      expect(verses.where((v) => v.superscription.isNotEmpty), isEmpty,
          reason: '$name unexpectedly carries a superscription');
    }
  });

  testWidgets('the heading renders without a verse number', (tester) async {
    final psalm3 = leb.firstWhere((v) =>
        v.book == 'Psalms' && v.chapter == 3 && v.verse == 1);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SuperscriptionLine(
          verse: psalm3,
          settings: AppSettings(),
          locale: 'en',
        ),
      ),
    ));

    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final rendered = rich.text.toPlainText(includePlaceholders: false);
    expect(rendered, contains('A psalm of David at his fleeing'));
    // The number the LEB does not print must not appear, and neither
    // must the verse text it sits above.
    expect(rendered, isNot(contains('1')));
    expect(rendered, isNot(contains('Yahweh, how many are my foes')));
  });
}
