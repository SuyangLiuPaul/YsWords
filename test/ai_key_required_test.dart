/// AI runs on the reader's own Gemini key — 2026-09-18.
///
/// 「dev gemini token可以拿去了 如果他们要用 用的时候要提醒要绑定api 而且有
/// 清晰方法告诉他们」. Three things have to stay true, and each can stop
/// being true without anything visibly breaking:
///
///  * the server never reads the developer's key again (a revived
///    `process.env.GEMINI_API_KEY` would quietly start spending it);
///  * every AI entry point asks for the reader's key first (a new entry
///    point that forgets would send a keyless request and show the reader
///    a server error instead of the steps);
///  * the reminder actually carries the steps and the two doors.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/widgets/ai_key_required_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<bool?> ask(WidgetTester t, AppSettings settings) async {
    bool? answer;
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answer = await ensureGeminiKey(context),
            child: const Text('ask'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('ask'));
    await t.pumpAndSettle();
    return answer;
  }

  testWidgets('no key: the reader is told how, and nothing is sent',
      (t) async {
    final settings = AppSettings();
    var answer = await ask(t, settings);
    // The dialog is up; the answer arrives when it closes.
    expect(find.text('AI 需要你自己的密钥'), findsOneWidget);
    expect(find.textContaining('aistudio.google.com/apikey'), findsOneWidget);
    expect(find.textContaining('Create API key'), findsOneWidget);
    expect(find.textContaining('「设置」›「AI 释义」'), findsOneWidget);
    expect(find.text('去设置'), findsOneWidget);
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();
    answer = answer ?? false;
    expect(answer, isFalse);
  });

  testWidgets('a key: straight through, no dialog', (t) async {
    final settings = AppSettings();
    await settings.setGeminiApiKey('AIzaSyTESTTESTTESTTESTTESTTESTTESTTES');
    final answer = await ask(t, settings);
    expect(answer, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    await t.pump(const Duration(seconds: 1)); // settings' write debounce
  });

  test('every AI call in the app is behind the reminder', () {
    const calls = [
      'AiWordService.explain(',
      'AiWordService.explainVerse(',
      'AiSearchService.ask(',
      'AiBibleSearchService.ask(',
    ];
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains('/services/')) continue;
      final src = f.readAsStringSync();
      if (calls.any(src.contains) && !src.contains('ensureGeminiKey(')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('the server reads no developer key and answers byokRequired', () {
    for (final name in ['aiSearch', 'aiBibleSearch', 'aiExplainWord']) {
      final src = File('netlify/functions/$name.mjs').readAsStringSync();
      expect(src, isNot(contains('process.env.GEMINI_API_KEY')),
          reason: '$name reads the retired shared key');
      expect(src, isNot(contains('process.env[`GEMINI_API_KEY')),
          reason: '$name reads the retired backup keys');
      expect(src, contains('throw byokRequiredError(locale)'),
          reason: '$name must answer a keyless request with the steps');
    }
    final byok = File('netlify/functions/_byok.mjs').readAsStringSync();
    expect(byok, contains("err.code = 'byokRequired'"));
    expect(byok, contains('aistudio.google.com/apikey'));
  });
}
