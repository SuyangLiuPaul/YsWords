// Smoke tests for the BibleEvidence model + service. Catches schema
// drift between the curated assets/bible_evidence.json and the
// Flutter model.

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/bible_evidence.dart';
import 'package:yswords/services/bible_evidence_service.dart';

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

    test('chaptersInReference parses common formats', () {
      // Single chapter:verse
      expect(BibleEvidenceService.chaptersInReference('Isaiah 40:8'), [40]);
      expect(BibleEvidenceService.chaptersInReference('John 9:7'), [9]);

      // Verse range within a single chapter (the dash is verses, NOT chapters)
      expect(
        BibleEvidenceService.chaptersInReference('2 Samuel 7:11-16'),
        [7],
      );
      expect(
        BibleEvidenceService.chaptersInReference('Numbers 6:24-26'),
        [6],
      );

      // Multi-chapter range with colons on both sides
      expect(
        BibleEvidenceService.chaptersInReference('Genesis 1:1-2:3'),
        [1, 2],
      );

      // Chapter-only or chapter range without verses
      expect(BibleEvidenceService.chaptersInReference('Leviticus 23'), [23]);
      expect(
        BibleEvidenceService.chaptersInReference('Numbers 22-24'),
        [22, 23, 24],
      );
      expect(
        BibleEvidenceService.chaptersInReference('Genesis 6-9'),
        [6, 7, 8, 9],
      );

      // Comma-separated verse spans within one chapter
      expect(
        BibleEvidenceService.chaptersInReference('John 18:31-33, 37-38'),
        [18],
      );
      expect(
        BibleEvidenceService.chaptersInReference('Acts 19:11-20, 23-41'),
        [19],
      );
      expect(
        BibleEvidenceService.chaptersInReference('1 Samuel 17:1-3, 52'),
        [17],
      );

      // Semicolon-separated cross-book references — the first colon
      // pair wins for the bibleBooks[0] context (the second book only
      // matches when the entry's bibleBooks lists it too).
      expect(
        BibleEvidenceService.chaptersInReference(
            'Exodus 14:21-22; 1 Kings 5-7'),
        [14],
      );

      // Unparseable references → empty (caller treats as book-wide match).
      expect(BibleEvidenceService.chaptersInReference(''), isEmpty);
      expect(
        BibleEvidenceService.chaptersInReference('Multiple Books'),
        isEmpty,
      );
      expect(
        BibleEvidenceService.chaptersInReference('Various NT references'),
        isEmpty,
      );
    });

    test('forChapter narrows to the specific chapter', () {
      final entries = [
        BibleEvidence.fromJson({
          'id': 'a',
          'category': 'Archaeology',
          'bibleBooks': ['Genesis'],
          'confidenceLevel': 'Strong',
          'icon': '🪨',
          'scriptureReference': 'Genesis 1:1',
          'title': {'en': 'A'},
          'summary': {'en': 'A'},
          'description': {'en': 'A'},
          'scripturalCorrelation': {'en': 'A'},
        }),
        BibleEvidence.fromJson({
          'id': 'b',
          'category': 'Archaeology',
          'bibleBooks': ['Genesis'],
          'confidenceLevel': 'Strong',
          'icon': '🪨',
          'scriptureReference': 'Genesis 37:28',
          'title': {'en': 'B'},
          'summary': {'en': 'B'},
          'description': {'en': 'B'},
          'scripturalCorrelation': {'en': 'B'},
        }),
        BibleEvidence.fromJson({
          'id': 'c',
          'category': 'Archaeology',
          'bibleBooks': ['Genesis'],
          'confidenceLevel': 'Strong',
          'icon': '🪨',
          'scriptureReference': 'Genesis 6-9',
          'title': {'en': 'C'},
          'summary': {'en': 'C'},
          'description': {'en': 'C'},
          'scripturalCorrelation': {'en': 'C'},
        }),
        BibleEvidence.fromJson({
          'id': 'd',
          'category': 'Manuscripts',
          'bibleBooks': ['Multiple Books'],
          'confidenceLevel': 'Definitive',
          'icon': '📜',
          'scriptureReference': 'Multiple Books',
          'title': {'en': 'D'},
          'summary': {'en': 'D'},
          'description': {'en': 'D'},
          'scripturalCorrelation': {'en': 'D'},
        }),
      ];

      // Reading Genesis 1: only the Genesis 1:1 entry should match;
      // entry "d" doesn't match because its bibleBooks is "Multiple
      // Books" (not "Genesis"), so it's filtered out at forBook stage.
      final ch1 = BibleEvidenceService.forChapter(entries, 'Genesis', 1)
          .map((e) => e.id)
          .toSet();
      expect(ch1, {'a'});

      // Reading Genesis 7: should pick up the chapter range "Genesis 6-9".
      final ch7 = BibleEvidenceService.forChapter(entries, 'Genesis', 7)
          .map((e) => e.id)
          .toSet();
      expect(ch7, {'c'});

      // Reading Genesis 37: just the Joseph entry.
      final ch37 = BibleEvidenceService.forChapter(entries, 'Genesis', 37)
          .map((e) => e.id)
          .toSet();
      expect(ch37, {'b'});

      // Reading Genesis 5 (no curated coverage): nothing matches.
      final ch5 = BibleEvidenceService.forChapter(entries, 'Genesis', 5);
      expect(ch5, isEmpty);
    });

    test('forChapter treats single-chapter book ranges as verses', () {
      // "Jude 14-15" syntactically looks like a chapter range, but
      // Jude has only one chapter — those are verses 14-15. Reading
      // chapter 1 of Jude must still surface the entry.
      final entries = [
        BibleEvidence.fromJson({
          'id': 'enoch_manuscripts',
          'category': 'Manuscripts',
          'bibleBooks': ['Jude'],
          'confidenceLevel': 'Strong',
          'icon': '📜',
          'scriptureReference': 'Jude 14-15',
          'title': {'en': 'Enoch'},
          'summary': {'en': 'E'},
          'description': {'en': 'E'},
          'scripturalCorrelation': {'en': 'E'},
        }),
      ];
      final ch1 = BibleEvidenceService.forChapter(entries, 'Jude', 1)
          .map((e) => e.id)
          .toSet();
      expect(ch1, {'enoch_manuscripts'});

      // Chapter 14 in a single-chapter book is bogus — should match nothing.
      final ch14 = BibleEvidenceService.forChapter(entries, 'Jude', 14);
      expect(ch14, isEmpty);
    });

    test('flattens paragraph arrays into double-newline strings', () {
      // Some entries (e.g. hazor_destruction) store long-form
      // description / scripturalCorrelation as List<String> per
      // locale instead of String. Pre-fix this rendered the literal
      // bracketed list to the user. Verify we now join paragraphs.
      final e = BibleEvidence.fromJson({
        'id': 'hazor_destruction',
        'category': 'Archaeology',
        'confidenceLevel': 'Strong',
        'icon': '🪨',
        'title': {'en': 'Hazor', 'zh-Hans': '夏琐', 'zh-Hant': '夏琐'},
        'summary': {'en': 's', 'zh-Hans': 's', 'zh-Hant': 's'},
        'description': {
          'en': ['Para one.', 'Para two.', 'Para three.'],
          'zh-Hans': '中文段落',
          'zh-Hant': '中文段落',
        },
        'scripturalCorrelation': {
          'en': ['Joshua 11.', 'Confirms.'],
          'zh-Hans': '关联',
          'zh-Hant': '關聯',
        },
      });
      expect(
        e.localizedDescription('en'),
        'Para one.\n\nPara two.\n\nPara three.',
      );
      expect(e.localizedCorrelation('en'), 'Joshua 11.\n\nConfirms.');
      expect(e.localizedDescription('zh-Hans'), '中文段落');
      // No leading "[" or trailing "]" — that was the pre-fix bug.
      expect(e.localizedDescription('en').startsWith('['), isFalse);
    });
  });
}
