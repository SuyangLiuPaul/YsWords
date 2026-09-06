import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/about_page.dart';
import 'package:yswords/services/map_service.dart';

/// The pin a hardcoded credit cannot pass.
///
/// `illustration_attribution_render_test.dart` checks that the About
/// page renders everything CC BY-SA 3.0 asks for. Every one of those
/// assertions can also be satisfied by a page that simply prints the
/// Sweet Publishing credit from constants — which is precisely the
/// implementation that would go stale the first time an import brings
/// in a second licensed artist.
///
/// So this file serves the app a DIFFERENT index: two entries, one of
/// them a copyleft grouping (a different artist, a different holder, a
/// different licence, a different source) that exists nowhere in this
/// repository. The page must credit it without a code change.
///
/// It is a separate file on purpose. `MapService` memoises the load in
/// a private static that `clearCache()` does not reset, so the bundle
/// swap only takes effect in a process that has not already read the
/// real `assets/maps_index.json` — and `flutter test` gives each file
/// its own process.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const syntheticIndex = '''
[
  {
    "id": "synthetic_licensed_1",
    "kind": "scene",
    "title": {"en": "Synthetic", "zh-Hans": "合成", "zh-Hant": "合成"},
    "description": {"en": "", "zh-Hans": "", "zh-Hant": ""},
    "books": {"Ruth": [1, 1]},
    "file": "synthetic_licensed_1.jpg",
    "source": "cdn",
    "rights": {
      "title": "A Work Nobody Has Credited Yet",
      "author": "Ada Testwright",
      "holder": "Fictitious Press",
      "holderUrl": "https://example.invalid/holder",
      "year": "1979",
      "credit": "Illustration by Ada Testwright, courtesy of Fictitious Press. Copyright 1979.",
      "license": "CC BY-SA 4.0",
      "licenseFullName": "Attribution-ShareAlike 4.0 International",
      "licenseUrl": "https://example.invalid/licence/by-sa/4.0/",
      "attributionRequired": true,
      "shareAlike": true,
      "sourceUrl": "https://example.invalid/file/a-work-nobody-has-credited-yet",
      "modification": {
        "en": "Redistributed unmodified.",
        "zh-Hans": "未经修改分发。",
        "zh-Hant": "未經修改分發。"
      },
      "verified": "synthetic fixture, not a real licence record"
    }
  },
  {
    "id": "synthetic_unlicensed_1",
    "kind": "map",
    "title": {"en": "Plain", "zh-Hans": "普通", "zh-Hant": "普通"},
    "description": {"en": "", "zh-Hans": "", "zh-Hant": ""},
    "books": {"Ruth": [2, 2]},
    "file": "synthetic_unlicensed_1.jpg",
    "source": "cdn"
  }
]
''';

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key != 'assets/maps_index.json') return null;
      final bytes = Uint8List.fromList(utf8.encode(syntheticIndex));
      return ByteData.view(bytes.buffer);
    });
    // rootBundle caches by key, so evict before and after or the mock
    // is silently bypassed.
    rootBundle.evict('assets/maps_index.json');
    MapService.clearCache();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    rootBundle.evict('assets/maps_index.json');
    MapService.clearCache();
  });

  testWidgets('a licensed grouping the code has never seen is credited '
      'in full', (tester) async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 9000);
    addTearDown(tester.view.reset);
    // flutter_test draws every glyph as a square of the font size, so
    // the English section headers overflow the 520 px settings column
    // that real fonts fit comfortably — an artifact of the test font,
    // not of this page (`_SectionTitle`, untouched here, has done it
    // since before this work; the zh locales fit because their headers
    // are shorter). Shrink the scaler so a font artifact does not
    // masquerade as an attribution failure. Real overflow coverage
    // lives in `responsive_overflow_smoke_test.dart`.
    tester.platformDispatcher.textScaleFactorTestValue = 0.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.runAsync(MapService.loadMaps);
    final maps = MapService.cached;
    expect(maps.length, 2,
        reason: 'the synthetic index never reached MapService, so every '
            'assertion below would be vacuous');
    final r = maps.first.rights!;

    final settings = AppSettings();
    await tester.runAsync(() => settings.setLocale('en'));
    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettings>.value(
        value: settings,
        child: const MaterialApp(home: AboutPage()),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.tap(find.byKey(const ValueKey('mapRightsWorks')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    final page = <String>[];
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      final data = t.data;
      if (data != null) {
        page.add(data);
      } else if (t.textSpan != null) {
        page.add(t.textSpan!.toPlainText());
      }
    }
    bool shows(String needle) => page.any((s) => s.contains(needle));

    expect(shows(r.author), isTrue, reason: 'artist not credited');
    expect(shows(r.holder), isTrue, reason: 'rights holder not credited');
    expect(shows(r.credit), isTrue, reason: 'credit line not verbatim');
    expect(shows(r.license), isTrue, reason: 'licence not named');
    expect(shows(r.licenseFullName), isTrue,
        reason: 'licence full name not named');
    expect(shows(r.licenseUrl), isTrue, reason: 'licence URL not readable');
    expect(shows(r.title), isTrue, reason: 'work title not listed');
    expect(shows(r.localizedModification('en')), isTrue,
        reason: 'modification statement not rendered');
    expect(find.byKey(ValueKey('mapRightsCredit:${r.licenseUrl}')),
        findsOneWidget);
    expect(find.byKey(ValueKey('mapRightsWork:${r.sourceUrl}')),
        findsOneWidget);

    // The entry with no rights block is counted as unchecked, not
    // absorbed into the licensed set and not called public domain.
    expect(page.any((s) => s.contains('1') && s.contains('no licence claim')),
        isTrue,
        reason: 'the unlicensed sibling must be reported as unchecked');

    // Nothing from the real index leaks in — proof the assertions above
    // were met by the synthetic data rather than by the bundled Sweet
    // Publishing rows.
    expect(shows('Jim Padgett'), isFalse);
    expect(shows('Sweet Publishing'), isFalse);
  });
}
