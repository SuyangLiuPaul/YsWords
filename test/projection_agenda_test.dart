import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/projection_agenda.dart';

/// The order of service: what goes on the wall, in order, prepared
/// before the room fills.
///
/// The projection could only follow the reader — right for a study,
/// wrong for a service, where the passages are settled days earlier and
/// the person driving should not be hunting for 以賽亞書 53 while the
/// congregation waits.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const passage = AgendaItem(
    kind: AgendaKind.passage,
    book: '以赛亚书',
    chapter: 53,
    verse: 4,
    count: 3,
  );

  group('a row', () {
    test('labels a range with its real end, not a count', () {
      expect(passage.label, '以赛亚书 53:4–6');
      expect(
          const AgendaItem(
                  kind: AgendaKind.passage, book: '约翰福音', chapter: 3, verse: 16)
              .label,
          '约翰福音 3:16');
    });

    test("the operator's note rides along, and a blank can be only a note",
        () {
      expect(passage.copyWith(note: '讲道经文').label, '以赛亚书 53:4–6 · 讲道经文');
      expect(const AgendaItem.blank().label, '—');
      expect(const AgendaItem.blank(note: '祷告').label, '祷告');
    });

    test('round-trips through JSON', () {
      final back = AgendaItem.fromJson(
          jsonDecode(jsonEncode(passage.toJson())) as Map<String, dynamic>);
      expect(back, passage);
      const blank = AgendaItem.blank(note: '回应诗');
      expect(
          AgendaItem.fromJson(
              jsonDecode(jsonEncode(blank.toJson())) as Map<String, dynamic>),
          blank);
    });
  });

  group('decoding is forgiving', () {
    test('one bad row does not cost the rest of the order', () {
      final items = decodeAgenda([
        passage.toJson(),
        {'kind': 'passage', 'book': '', 'chapter': 1, 'verse': 1},
        {'kind': 'passage', 'book': '路加福音', 'chapter': 0, 'verse': 1},
        'not a map',
        const AgendaItem.blank().toJson(),
      ]);
      expect(items, [passage, const AgendaItem.blank()]);
    });

    test('a count below one is read as one, not as a wall of nothing', () {
      final item = AgendaItem.fromJson({
        'kind': 'passage',
        'book': '诗篇',
        'chapter': 23,
        'verse': 1,
        'count': 0,
      });
      expect(item!.count, 1);
    });

    test('anything that is not a list decodes to an empty order', () {
      expect(decodeAgenda(null), isEmpty);
      expect(decodeAgenda('nonsense'), isEmpty);
      expect(decodeAgenda(<Object?>{}), isEmpty);
    });
  });

  group('the setting', () {
    test('is empty by default and survives a restart in order', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      await s.loadSettings();
      expect(s.projectionAgenda, isEmpty,
          reason: 'the ordinary projection simply follows the reader');

      await s.setProjectionAgenda([
        passage.copyWith(note: '讲道经文'),
        const AgendaItem.blank(),
        const AgendaItem(
            kind: AgendaKind.passage, book: '诗篇', chapter: 23, verse: 1),
      ]);

      final again = AppSettings();
      await again.loadSettings();
      expect(again.projectionAgenda.length, 3);
      expect(again.projectionAgenda.first.note, '讲道经文');
      expect(again.projectionAgenda.last.book, '诗篇',
          reason: 'order is the whole point of an order of service');
    });

    test('a corrupt stored blob yields an empty order, not a crash',
        () async {
      SharedPreferences.setMockInitialValues(
          {'projectionAgenda': 'not json at all'});
      final s = AppSettings();
      await s.loadSettings();
      expect(s.projectionAgenda, isEmpty);
    });
  });

  group('the operator reads one ahead', () {
    // VideoPsalm calls its version a stage view. The cheap honest form
    // here is the control strip saying what `]` will do — before this,
    // the only way to find out was to press it in front of everybody.
    test('the strip names the next row, and says when there is not one',
        () {
      final page = File('lib/pages/projection_page.dart').readAsStringSync();
      expect(page.contains("String? _nextAgendaLabel(String locale)"), isTrue);
      expect(page.contains("'projectionAgendaEnd'"), isTrue,
          reason: 'the last row must not look like a missing one');
      // From nowhere `]` starts at the top, so the hint must name the
      // FIRST row — it describes the key, not the list.
      expect(page.contains('final next = at == null ? 0 : at + 1;'), isTrue);
      // And nothing is shown when there is no order of service, so an
      // ordinary projection is unchanged.
      expect(page.contains("if (_nextAgendaLabel(locale) != null)"), isTrue);
    });
  });

  group('the wiring', () {
    test('the page steps with the bracket keys and never on a chord', () {
      final page = File('lib/pages/projection_page.dart').readAsStringSync();
      expect(page.contains('LogicalKeyboardKey.bracketRight'), isTrue);
      expect(page.contains('LogicalKeyboardKey.bracketLeft'), isTrue);
      expect(page.contains('ProjectionCommand.agendaNext'), isTrue);
      // Agenda rows name a verse by its printed number; resolving by
      // position would put a different verse up the moment an edition
      // merges two.
      expect(page.contains('verses.indexWhere((v) => v.verse == item.verse)'),
          isTrue,
          reason: 'by printed number, not by index');
    });

    test('the place in the list is not persisted, only the list', () {
      final page = File('lib/pages/projection_page.dart').readAsStringSync();
      expect(page.contains('int? _agendaAt;'), isTrue);
      expect(page.contains('setProjectionAgenda(_agendaAt'), isFalse,
          reason: 'an order of service survives the week; the place you '
              'had reached in it is this morning\'s');
    });
  });
}
