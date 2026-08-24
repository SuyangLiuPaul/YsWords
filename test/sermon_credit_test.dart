import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/constants/sermon_credit.dart';
import 'package:yswords/constants/ui_strings.dart';

/// Guards the two facts the sermon module states about itself.
///
/// Both were wrong before this: the app claimed **587 sermons** when
/// there are 289 (587 was the sum of every sermon's parts, relabelled),
/// and the preacher's name appeared in three different spellings, none
/// of them on a screen a reader ever sees.
///
/// The name is the kind of detail that drifts back the moment someone
/// writes a new string, so it is checked rather than trusted.
void main() {
  test('the sermon count matches the actual index', () {
    final raw = File('assets/sermons/index.json').readAsStringSync();
    final decoded = json.decode(raw);
    final items = decoded is List
        ? decoded
        : (decoded['sermons'] ?? decoded['items']) as List;
    expect(sermonCount, items.length,
        reason: 'sermonCount is what the UI tells readers; it has to be '
            'the number of sermons that exist');
  });

  test('no uiStrings entry claims 587 sermons', () {
    final offenders = <String>[];
    uiStrings.forEach((key, byLocale) {
      byLocale.forEach((locale, value) {
        if (value.contains('587')) offenders.add('$key/$locale');
      });
    });
    expect(offenders, isEmpty,
        reason: '587 was the sum of sermon PARTS presented as a number '
            'of sermons. The count is $sermonCount: ${offenders.join(", ")}');
  });

  test('the preacher is spelled one way per language', () {
    // "H.H." is the form the user asked for, and what distinguishes him
    // from others surnamed Chang. A shortened rendering hardcoded into
    // a string is exactly how the three spellings arose.
    const forbidden = [
      "Pastor Eric Chang",
      "Pastor Eric's",
      'Eric Chang',
    ];
    final offenders = <String>[];
    uiStrings.forEach((key, byLocale) {
      byLocale.forEach((locale, value) {
        for (final bad in forbidden) {
          if (value.contains(bad)) offenders.add('$key/$locale: "$bad"');
        }
      });
    });
    expect(offenders, isEmpty,
        reason: 'compose the name from sermonPreacher() / the {name} '
            'template instead of hardcoding it: ${offenders.join(", ")}');
  });

  test('every language has a name, and English keeps H.H.', () {
    for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
      expect(sermonPreacher(locale), isNotEmpty);
    }
    expect(sermonPreacher('en'), contains('H.H.'));
    expect(sermonPreacher('zh-Hans'), '张熙和牧师');
    expect(sermonPreacher('zh-Hant'), '張熙和牧師');
  });

  test('withPreacher fills the template', () {
    expect(withPreacher('© {name} · used with permission.', 'en'),
        '© Pastor Eric H.H. Chang · used with permission.');
    expect(withPreacher('{name}讲道集', 'zh-Hans'), '张熙和牧师讲道集');
  });

  test('the sermons licence no longer credits the Bible translator', () {
    // 梁家铿 translates the biblexg Bible. He is a different person from
    // the preacher, confirmed with the user — his credit belongs on the
    // biblexg line, not on the sermons.
    final sermonLicence = uiStrings['aboutLicenseSermons']!;
    for (final entry in sermonLicence.entries) {
      expect(entry.value, isNot(contains('梁家铿')));
      expect(entry.value, isNot(contains('梁家鏗')));
      expect(entry.value, isNot(contains('Liang Jia-keng')));
      expect(entry.value, contains('{name}'),
          reason: 'the licence should compose the preacher, not name him '
              'inline');
    }
  });

  // b8258d5 stripped verse references out of every sermon title and left
  // the punctuation that had joined them: "Regeneration and Renewal — ;
  // Foundational Problems". Sixteen strings across six sermons read that
  // way on screen for four months, because nothing looks at a title once
  // it is written.
  //
  // This only sees STRANDED PUNCTUATION. The same pass also left bare
  // numerals ("— 3 —"), orphan 章 and stranded commas, which are ordinary
  // characters and invisible here; those are counted in the queue.
  test('no sermon title carries stranded ref-stripping punctuation', () {
    final debris = RegExp(r'[;；]\s*[:：]|—\s*[;；：:]|\s+[;；]|[（(]\s*[)）]');
    final offenders = <String>[];

    final decoded =
        json.decode(File('assets/sermons/index.json').readAsStringSync());
    final items = decoded is List
        ? decoded
        : (decoded['sermons'] ?? decoded['items']) as List;
    for (final s in items) {
      final titles = (s['titles'] as Map?) ?? const {};
      titles.forEach((locale, value) {
        if (debris.hasMatch(value as String)) {
          offenders.add('index.json ${s['id']}/$locale: $value');
        }
      });
    }

    for (final locale in const ['en', 'zh-CN', 'zh-TW']) {
      final dir = Directory('assets/sermons/$locale');
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync().whereType<File>()) {
        if (!f.path.endsWith('.txt')) continue;
        final first = f.readAsLinesSync().firstWhere((l) => l.isNotEmpty,
            orElse: () => '');
        if (first.startsWith('#') && debris.hasMatch(first)) {
          offenders.add('${f.path}: $first');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'a title reading "— ;" or "; :" lost a reference and kept '
            'its punctuation:\n${offenders.join("\n")}');
  });
}
