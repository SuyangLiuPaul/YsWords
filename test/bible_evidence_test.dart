// Smoke tests for the BibleEvidence model + service. Catches schema
// drift between the curated assets/bible_evidence.json (209 entries)
// and the Flutter model.

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/bible_evidence.dart';

void main() {
  group('BibleEvidence.fromJson', () {
    test('parses a complete entry', () {
      final e = BibleEvidence.fromJson({
        'id': 'tel_dan_stele',
        'category': 'Archaeology',
        'bibleBooks': ['1 Kings', '2 Kings'],
        'timeline': '9th century BC',
        'discoveryDate': '1993',
        'location': 'Tel Dan, Israel',
        'scriptureReference': '1 Kings 15:20',
        'images': ['https://example.com/stele.jpg'],
        'academicSources': ['Biran & Naveh, 1995'],
        'confidenceLevel': 'Definitive',
        'icon': '🪨',
        'title': {
          'en': 'Tel Dan Stele',
          'zh-Hans': '但丘石碑',
          'zh-Hant': '但丘石碑',
        },
        'summary': {
          'en': 'Aramaic inscription mentioning the House of David.',
          'zh-Hans': '提到大卫家的亚兰文碑文。',
          'zh-Hant': '提到大衛家的亞蘭文碑文。',
        },
        'description': {'en': 'Long form...', 'zh-Hans': '长文...', 'zh-Hant': '長文...'},
        'scripturalCorrelation': {
          'en': 'Confirms the historical existence of David\'s dynasty.',
          'zh-Hans': '确认大卫王朝的历史存在。',
          'zh-Hant': '確認大衛王朝的歷史存在。',
        },
      });

      expect(e.id, 'tel_dan_stele');
      expect(e.category, 'Archaeology');
      expect(e.confidenceLevel, 'Definitive');
      expect(e.localizedTitle('en'), 'Tel Dan Stele');
      expect(e.localizedTitle('zh-Hans'), '但丘石碑');
      expect(e.bibleBooks, ['1 Kings', '2 Kings']);
    });

    test('falls back to en when locale missing', () {
      final e = BibleEvidence.fromJson({
        'id': 'x',
        'category': 'Manuscripts',
        'confidenceLevel': 'Strong',
        'icon': '📜',
        'title': {'en': 'Only English'},
        'summary': {'en': 'EN'},
        'description': {'en': 'EN'},
        'scripturalCorrelation': {'en': 'EN'},
      });
      expect(e.localizedTitle('zh-Hans'), 'Only English');
      expect(e.localizedSummary('zh-Hant'), 'EN');
    });

    test('survives missing fields without throwing', () {
      final e = BibleEvidence.fromJson({});
      expect(e.id, '');
      expect(e.category, '');
      expect(e.bibleBooks, isEmpty);
      expect(e.images, isEmpty);
    });
  });
}
