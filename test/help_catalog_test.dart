/// The Help page's guards — 2026-09-18.
///
/// A help page is only worth having while it is true, and every way it
/// can stop being true is silent: a menu item renamed while the help
/// still names the old label, a key rebound while the page prints the
/// old one, a feature added to the menu and never described. Each test
/// below closes one of those.
library;

import 'dart:io';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show SingleActivator;
import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_words/constants/help_topics.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/pages/help_page.dart';
import 'package:yahwehs_words/pages/projection_page.dart'
    show kProjectionKeymap;
import 'package:yahwehs_words/pages/settings_page.dart' show SettingsSection;
import 'package:yahwehs_words/utils/help_catalog.dart';
import 'package:yahwehs_words/utils/keyboard_shortcuts.dart';

const _locales = ['zh-Hans', 'zh-Hant', 'en'];

List<String> _ids(List<HelpHit> hits) => [for (final h in hits) h.topic.id];

/// Every simplified-Chinese word the help says, for "is this described".
String _helpText() => [
      for (final t in kHelpTopics) ...[
        t.title.hans,
        t.body.hans,
        for (final k in t.path) helpPathLabel(k, 'zh-Hans'),
      ],
    ].join('\n');

/// The labels a stretch of source passes as `label: uiStrings['…']`.
Set<String> _labelKeys(String src) => {
      for (final m
          in RegExp(r"label:\s*uiStrings\['(\w+)'\]").allMatches(src))
        m.group(1)!,
    };

List<String> _undescribed(Iterable<String> keys, {Set<String> skip = const {}}) {
  final hay = _helpText();
  return [
    for (final k in keys)
      if (!skip.contains(k))
        if (uiStrings[k]?['zh-Hans'] case final String label)
          if (!hay.contains(label.replaceAll('…', '').trim())) '$k ($label)',
  ];
}

void main() {
  group('every topic is complete', () {
    test('ids are unique', () {
      final ids = [for (final t in kHelpTopics) t.id];
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('title and body in all three locales', () {
      for (final t in kHelpTopics) {
        for (final s in [...t.title.all, ...t.body.all]) {
          expect(s.trim(), isNotEmpty, reason: t.id);
        }
        expect(t.title.hant, isNot(t.title.en), reason: t.id);
      }
    });

    test('every section has something in it', () {
      for (final s in HelpSection.values) {
        if (s == HelpSection.shortcuts) continue; // printed from tables
        expect(kHelpTopics.where((t) => t.section == s), isNotEmpty,
            reason: s.name);
        expect(kHelpSectionNames[s], isNotNull, reason: s.name);
      }
    });

    test('the 繁體 uses this app\'s own labels, not OpenCC\'s', () {
      // 繁體 was generated with OpenCC and then corrected where the app
      // already says it differently. These are the four it got wrong;
      // a regenerated file that lost the corrections fails here.
      final hant = [for (final t in kHelpTopics) t.body.hant].join('\n');
      for (final wrong in ['意見反饋', '靈脩', '開啟分屏閱讀']) {
        expect(hant, isNot(contains(wrong)), reason: wrong);
      }
    });
  });

  group('the help names things the way the app does', () {
    test('every path segment is a real label', () {
      for (final t in kHelpTopics) {
        for (final k in t.path) {
          final m = uiStrings[k] ?? kHelpExtraLabels[k];
          expect(m, isNotNull, reason: '${t.id}: $k');
          for (final l in _locales) {
            expect(m![l], isNotNull, reason: '${t.id}: $k [$l]');
          }
        }
      }
    });

    test("every item in the reader's ⋯ menu is described", () {
      final src =
          File('lib/widgets/bible_reading_pane.dart').readAsStringSync();
      final start = src.indexOf("case 'settings':\n                            onSettings();");
      expect(start, isNot(-1), reason: 'the ⋯ menu moved; re-anchor this');
      final from = src.indexOf('itemBuilder: (context) {', start);
      final end = src.indexOf('return items;', from);
      final keys = _labelKeys(src.substring(from, end));
      expect(keys.length, greaterThan(6),
          reason: 'the parse found too little to prove anything');
      // Home is the app's own front door, not a feature to explain.
      expect(_undescribed(keys, skip: {'home'}), isEmpty);
    });

    test('every tile on the home page is described', () {
      final src = File('lib/pages/dashboard_page.dart').readAsStringSync();
      final keys = {
        for (final m in RegExp(r"_LinkTile\(\s*icon:[^,]+,\s*label:\s*uiStrings\['(\w+)'\]")
            .allMatches(src))
          m.group(1)!,
      };
      expect(keys.length, greaterThan(8));
      expect(_undescribed(keys), isEmpty);
    });

    test('every settings section is described', () {
      final src = File('lib/pages/settings_page.dart').readAsStringSync();
      final keys = {
        for (final m in RegExp(r"uiStrings\['(settingsSection\w+)'\]")
            .allMatches(src))
          m.group(1)!,
      };
      expect(keys.length, greaterThan(6));
      expect(_undescribed(keys), isEmpty);
    });

    test('a settings topic lands on its own section', () {
      HelpTopic t(String id) => kHelpTopics.firstWhere((x) => x.id == id);
      expect(helpSettingsSectionFor(t('ai-explain')), SettingsSection.ai);
      expect(helpSettingsSectionFor(t('sync')), SettingsSection.account);
      expect(helpSettingsSectionFor(t('notifications')),
          SettingsSection.notifications);
      expect(helpSettingsSectionFor(t('dashboard-layout')),
          SettingsSection.dashboardLayout);
      expect(helpSettingsSectionFor(t('copy-format')), SettingsSection.display);
    });
  });

  group('the keys the page prints are the keys that work', () {
    test('every label the key tables name exists in all locales', () {
      final labels = <String>{
        for (final k in kReaderShortcuts) k.labelKey,
        for (final (_, _, l) in kProjectionKeymap) l,
      };
      for (final l in labels) {
        for (final loc in _locales) {
          expect(uiStrings[l]?[loc], isNotNull, reason: '$l [$loc]');
        }
      }
      for (final g in helpKeyGroups(apple: false)) {
        expect(kHelpKeyGroupTitles[g.titleKey], isNotNull, reason: g.titleKey);
      }
      expect(kHelpKeyGroupTitles['keysTouch'], isNotNull);
    });

    test('the reading column still binds exactly what it bound before', () {
      // The ten bindings that were typed into its CallbackShortcuts until
      // today, now built from the table.
      final before = <SingleActivator>{
        const SingleActivator(LogicalKeyboardKey.bracketLeft),
        const SingleActivator(LogicalKeyboardKey.bracketRight),
        const SingleActivator(LogicalKeyboardKey.slash),
        const SingleActivator(LogicalKeyboardKey.question, shift: true),
        const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true),
        const SingleActivator(LogicalKeyboardKey.bracketRight, meta: true),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
        const SingleActivator(LogicalKeyboardKey.comma, meta: true),
        const SingleActivator(LogicalKeyboardKey.bracketLeft, control: true),
        const SingleActivator(LogicalKeyboardKey.bracketRight, control: true),
      };
      String sig(SingleActivator a) =>
          '${a.trigger.keyId}/${a.meta}/${a.control}/${a.shift}';
      expect({for (final k in kReaderShortcuts) sig(k.chord.activator)},
          {for (final a in before) sig(a)});
    });

    test('every projection key is printed, once, S being saved setups', () {
      final rows = helpKeyGroups(apple: false)
          .firstWhere((g) => g.titleKey == 'keysProjection')
          .rows;
      expect(rows, hasLength(kProjectionKeymap.length));
      expect(rows.first.keys, '→ · ↓ · Space · Enter');
      expect(rows.firstWhere((r) => r.labelKey == 'projKeyPresets').keys, 'S');
      expect(rows.firstWhere((r) => r.labelKey == 'projKeyBigger').keys, '+');
    });

    test('a Mac is shown ⌘, a PC is shown Ctrl, neither both', () {
      String reader({required bool apple}) => helpKeyGroups(apple: apple)
          .firstWhere((g) => g.titleKey == 'keysReader')
          .rows
          .map((r) => r.keys)
          .join(' ');
      expect(reader(apple: true), contains('⌘['));
      expect(reader(apple: true), isNot(contains('Ctrl')));
      expect(reader(apple: false), contains('Ctrl+['));
      expect(reader(apple: false), isNot(contains('⌘')));
    });

    test('the projection topic teaches the keys the projection answers', () {
      // The one topic that restates keys in prose. S, not R, is this
      // app's saved-setups key — the sibling app uses R — so a copy of
      // the sibling's paragraph would teach a key that does nothing.
      final body = kHelpTopics.firstWhere((t) => t.id == 'projection').body;
      expect(body.hans, contains('S 调出存好的设置'));
      expect(body.hans, isNot(contains('R 调出')));
    });
  });

  group('search', () {
    test('finds a feature in any language, from either interface', () {
      expect(_ids(searchHelp('分屏', kHelpTopics)).first, 'split');
      expect(_ids(searchHelp('split', kHelpTopics)).first, 'split');
      expect(_ids(searchHelp('字体', kHelpTopics)), contains('appearance'));
      expect(_ids(searchHelp('字體', kHelpTopics)), contains('appearance'));
      expect(_ids(searchHelp('投影', kHelpTopics)).first, 'projection');
      expect(_ids(searchHelp('sync', kHelpTopics)).first, 'sync');
      expect(_ids(searchHelp('同步', kHelpTopics)).first, 'sync');
    });

    test('the words people actually use for a thing', () {
      expect(_ids(searchHelp('字太小', kHelpTopics)), contains('appearance'));
      expect(_ids(searchHelp('夜间', kHelpTopics)), contains('appearance'));
      expect(_ids(searchHelp('串珠', kHelpTopics)), contains('cross-refs'));
      expect(_ids(searchHelp('没网', kHelpTopics)), contains('offline'));
      expect(_ids(searchHelp('换手机', kHelpTopics)), contains('export'));
    });

    test('several words narrow rather than widen', () {
      final one = searchHelp('设置', kHelpTopics).length;
      final two = searchHelp('设置 通知', kHelpTopics).length;
      expect(two, lessThan(one));
    });

    test('nothing for nonsense, and nothing for blank', () {
      expect(searchHelp('qqzzxx', kHelpTopics), isEmpty);
      expect(searchHelp('   ', kHelpTopics), isEmpty);
    });
  });

  group('platforms', () {
    test('a topic for one platform is hidden on the others', () {
      final offline = kHelpTopics.firstWhere((t) => t.id == 'offline');
      expect(offline.appliesTo(HelpPlatform.web), isTrue);
      expect(offline.appliesTo(HelpPlatform.ios), isFalse);
    });

    test('every platform has its own page', () {
      for (final p in HelpPlatform.values) {
        expect(
            kHelpTopics.where((t) =>
                t.section == HelpSection.platforms && t.appliesTo(p)),
            hasLength(1),
            reason: p.name);
        expect(kHelpPlatformNames[p], isNotNull, reason: p.name);
      }
    });
  });
}
