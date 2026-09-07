import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/constants/ui_strings.dart';

/// Guards the two counts the first-run onboarding "Discover" and
/// "Sermons" slides state about themselves.
///
/// Both went stale independently. The Bible Timeline gained a 98th
/// event in `fb977915` (2026-05-04, "add Book of Job") without the copy
/// ever being told, so every onboarding string still said "97 events"
/// four months later even after `358fca60` (2026-09-04) fixed the
/// asset's own `_meta.count`. Separately, the sermon library grew
/// 289 -> 429 (the 福音電台 merge) and the fix that followed updated
/// `onboardSermonsBody` in `ui_strings.dart` but missed the `?? '...'`
/// fallback one widget away in `onboarding_dialog.dart` — a fallback
/// only ever renders when a locale is missing from the map, so nobody
/// saw it drift. `sermon_credit_test.dart` already guards the map; this
/// adds the widget's hardcoded fallback string, which that test never
/// looked at, and the timeline count, which no test covered at all.
void main() {
  final events = (json.decode(File('assets/bible_timeline.json')
          .readAsStringSync()) as Map)['events'] as List;
  final timelineMeta = (json.decode(File('assets/bible_timeline.json')
      .readAsStringSync()) as Map)['_meta'] as Map?;
  final people = (json.decode(
          File('assets/family_tree.json').readAsStringSync()) as Map)['people']
      as List;
  final evidences = (json.decode(File('assets/bible_evidence.json')
          .readAsStringSync()) as Map)['evidences'] as List;
  final sermons =
      json.decode(File('assets/sermons/index.json').readAsStringSync())
          as List;
  final sermonTotal = sermons.length;
  final sermonTrilingual =
      sermons.where((s) => (s as Map)['hasEn'] == true).length;
  final sermonZhOnly = sermonTotal - sermonTrilingual;

  final dialogSource =
      File('lib/widgets/onboarding_dialog.dart').readAsStringSync();

  List<int> numbersIn(String s) => RegExp(r'\d+')
      .allMatches(s)
      .map((m) => int.parse(m.group(0)!))
      .toList();

  String fallbackFor(String key) {
    final match = RegExp(
            "uiStrings\\['$key'\\]\\?\\[locale\\] \\?\\?\\s*\\n\\s*'([^']+)'")
        .firstMatch(dialogSource);
    expect(match, isNotNull,
        reason: 'could not find the $key fallback literal in '
            'onboarding_dialog.dart — did its formatting change?');
    return match!.group(1)!;
  }

  test('bible_timeline _meta.count matches the real event count', () {
    expect(timelineMeta?['count'], events.length);
  });

  test('onboardDiscoverBody states the real timeline/family-tree/evidence '
      'counts in every locale', () {
    for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
      final body = uiStrings['onboardDiscoverBody']![locale]!;
      expect(
        numbersIn(body),
        [events.length, people.length, evidences.length],
        reason: 'onboardDiscoverBody/$locale',
      );
    }
  });

  test('the onboarding_dialog.dart Discover fallback matches the real '
      'counts', () {
    expect(
      numbersIn(fallbackFor('onboardDiscoverBody')),
      [events.length, people.length, evidences.length],
    );
  });

  test('onboardSermonsBody states the real sermon counts in every locale',
      () {
    for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
      final body = uiStrings['onboardSermonsBody']![locale]!;
      expect(
        numbersIn(body),
        [sermonTotal, sermonTrilingual, sermonZhOnly],
        reason: 'onboardSermonsBody/$locale',
      );
    }
  });

  test('the onboarding_dialog.dart Sermons fallback matches the real '
      'sermon counts', () {
    expect(
      numbersIn(fallbackFor('onboardSermonsBody')),
      [sermonTotal, sermonTrilingual, sermonZhOnly],
    );
  });
}
