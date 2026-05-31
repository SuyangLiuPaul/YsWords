import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/strongs.dart';

StrongsEntry _entry({
  String? definitionZh,
  String definition = 'english definition',
}) {
  return StrongsEntry(
    number: 'G302',
    lemma: 'ἄν',
    translit: 'an',
    pronunciation: '',
    gloss: 'a primary particle',
    definition: definition,
    definitionZh: definitionZh,
  );
}

void main() {
  group('cleanChineseDefinition (v1.3.x English-noise stripping)', () {
    test('strips Strong\'s-id header + "AV -" KJV block from defZh', () {
      // The real G302 shape: a Chinese sense ("虚词") buried in English.
      final e = _entry(
        definitionZh: '302 an {an}\n\n'
            '虚词\n\n'
            'AV - whosoever 35, whatsoever 7, whomsoever 5,\n'
            '     what things soever 1',
      );
      final out = e.cleanChineseDefinition('zh-Hans');
      expect(out.contains('虚词'), isTrue);
      expect(out.contains('{an}'), isFalse); // id header gone
      expect(out.contains('AV -'), isFalse); // KJV block header gone
      expect(out.contains('whosoever'), isFalse); // continuation gone
      expect(out.contains('what things soever'), isFalse);
    });

    test('leaves a clean Chinese numbered definition untouched', () {
      final e = _entry(
        definitionZh: '1) 使安静, 使安歇\n2) 停止活动, 休息 (#来 4:4,10|)',
      );
      final out = e.cleanChineseDefinition('zh-Hans');
      expect(out, contains('使安静'));
      expect(out, contains('停止活动'));
      // Verse-ref markers with ASCII inside CJK lines are preserved
      // (the line has CJK, so it's kept whole).
      expect(out, contains('休息'));
    });

    test('English locale returns the definition unchanged', () {
      final e = _entry(
        definition: 'from G2596 and G3973; to settle down',
        definitionZh: '1) 使安静',
      );
      expect(e.cleanChineseDefinition('en'),
          'from G2596 and G3973; to settle down');
    });

    test('never returns empty — falls back if every line was English', () {
      final e = _entry(definitionZh: 'AV - only english here\nmore english');
      final out = e.cleanChineseDefinition('zh-Hans');
      expect(out.isNotEmpty, isTrue);
    });

    test('collapses blank-line runs left by removals', () {
      final e = _entry(
        definitionZh: '302 an {an}\n\n\n\n虚词',
      );
      final out = e.cleanChineseDefinition('zh-Hans');
      expect(out.contains('\n\n\n'), isFalse);
      expect(out.trim(), '虚词');
    });
  });
}
