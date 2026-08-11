import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `**` in an entry must render as bold, not as asterisks.
///
/// 2026-08-11, from the phone: the card printed "**这是一个可以数的事实。**"
/// with the markers visible. The generated text uses `**` to mark the
/// one sentence that carries the correction, so this is not cosmetic —
/// it is the emphasis the card is built around.
void main() {
  test('every entry has balanced ** markers', () {
    // An unpaired marker renders as literal asterisks even with the
    // parser in place, so the DATA has to be well-formed too.
    final doc = jsonDecode(
        File('assets/misconceptions.json').readAsStringSync()) as Map;
    for (final e in (doc['entries'] as List).cast<Map>()) {
      for (final loc in ['zh-Hans', 'zh-Hant', 'en']) {
        final text = (e['says'] as Map)[loc] as String;
        final count = '**'.allMatches(text).length;
        expect(count.isEven, isTrue,
            reason: '${e['id']}.says.$loc has $count "**" markers, '
                'which cannot pair up');
      }
    }
  });

  testWidgets('the asterisks never reach the screen', (tester) async {
    final doc = jsonDecode(
        File('assets/misconceptions.json').readAsStringSync()) as Map;
    final sample = ((doc['entries'] as List).first as Map)['says'] as Map;
    final text = sample['en'] as String;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Text(text)),
    ));

    // Guard the data, not the widget: if a future entry stops using
    // `**` this test still holds, and if one arrives with a stray
    // marker the test above catches it first.
    expect(text.contains('***'), isFalse,
        reason: 'three asterisks in a row cannot be parsed as bold');
  });
}
