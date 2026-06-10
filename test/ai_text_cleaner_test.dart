import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/ai_text_cleaner.dart';

/// Regression coverage for the AI verse-explanation cleanup — the
/// client-side defence behind the v1.3.55 → v1.3.57 "weird AI output"
/// bugs (leaked "快速思考：" preamble + markdown artifacts rendering as
/// literal symbols in the sheet).
void main() {
  group('cleanAiExplanation — thinking preamble', () {
    test('strips 快速思考 preamble up to the blank line', () {
      const raw = '快速思考：这节经文讲的是神的爱。\n\n'
          '约翰福音三章十六节是整本圣经的核心。';
      expect(cleanAiExplanation(raw), '约翰福音三章十六节是整本圣经的核心。');
    });

    test('strips English "Thinking:" preamble (case-insensitive)', () {
      const raw = 'thinking: outline the verse\n\nGod so loved the world.';
      expect(cleanAiExplanation(raw), 'God so loved the world.');
    });

    test('falls back to first newline when there is no blank line', () {
      const raw = '思考：先想一下\n这节经文的背景是旷野。';
      expect(cleanAiExplanation(raw), '这节经文的背景是旷野。');
    });

    test('keeps text intact when 思考 appears mid-prose, not as label', () {
      const raw = '我们可以思考：神为何如此爱世人？这值得深思。';
      // The label regex anchors at the START — mid-sentence usage must
      // survive. (It does start with 我们, so no match.)
      expect(cleanAiExplanation(raw), raw);
    });
  });

  group('cleanAiExplanation — markdown artifacts', () {
    test('strips a leading markdown heading marker', () {
      const raw = '### 约翰福音 3:16\n神爱世人……';
      expect(cleanAiExplanation(raw), '约翰福音 3:16\n神爱世人……');
    });

    test('removes stray bold markers', () {
      const raw = '这里的**爱**不是情感，而是**牺牲**。';
      expect(cleanAiExplanation(raw), '这里的爱不是情感，而是牺牲。');
    });

    test('preamble + heading + bold together', () {
      const raw = '快速思考：列大纲\n\n## 解释\n神的**独生子**赐给世人。';
      expect(cleanAiExplanation(raw), '解释\n神的独生子赐给世人。');
    });
  });

  group('cleanAiExplanation — clean prose is untouched', () {
    test('flowing Chinese prose passes through', () {
      const raw = '约翰福音第三章记载了耶稣与尼哥底母在夜间的谈话，'
          '这段经文是这段对话的高潮。';
      expect(cleanAiExplanation(raw), raw);
    });

    test('idempotent: cleaning twice equals cleaning once', () {
      const raw = '快速思考：xx\n\n### 标题\n正文**重点**。';
      final once = cleanAiExplanation(raw);
      expect(cleanAiExplanation(once), once);
    });

    test('whitespace-only input → empty string', () {
      expect(cleanAiExplanation('   \n  '), '');
    });
  });
}
