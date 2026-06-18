// 2026-06-18 (v1.3.91): tests for the boolean Strong's-search logic.
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/strongs_boolean_search.dart';

void main() {
  group('parseStrongsBoolean', () {
    test('single plain number is NOT boolean (null → single-entry path)', () {
      expect(parseStrongsBoolean('G2664'), isNull);
      expect(parseStrongsBoolean('  H7225 '), isNull);
    });

    test('single wildcard term parses', () {
      final q = parseStrongsBoolean('G25*')!;
      expect(q.terms.length, 1);
      expect(q.terms.first.wildcard, true);
      expect(q.terms.first.number, 'G25');
      expect(q.ops, isEmpty);
    });

    test('explicit AND', () {
      final q = parseStrongsBoolean('G25 AND G26')!;
      expect(q.terms.map((t) => t.number).toList(), ['G25', 'G26']);
      expect(q.ops, [StrongsOp.and]);
    });

    test('explicit OR, case-insensitive', () {
      final q = parseStrongsBoolean('g25 or H7225')!;
      expect(q.terms.map((t) => t.number).toList(), ['G25', 'H7225']);
      expect(q.ops, [StrongsOp.or]);
    });

    test('adjacent terms imply AND', () {
      final q = parseStrongsBoolean('G25 G26 G27')!;
      expect(q.terms.length, 3);
      expect(q.ops, [StrongsOp.and, StrongsOp.and]);
    });

    test('symbol operators & | + /', () {
      expect(parseStrongsBoolean('G25 & G26')!.ops, [StrongsOp.and]);
      expect(parseStrongsBoolean('G25 | G26')!.ops, [StrongsOp.or]);
      expect(parseStrongsBoolean('G25 + G26')!.ops, [StrongsOp.and]);
      expect(parseStrongsBoolean('G25 / G26')!.ops, [StrongsOp.or]);
    });

    test('leading zeros stripped', () {
      expect(parseStrongsBoolean('G0025 AND G0026')!.terms.first.number, 'G25');
    });

    test('mixed AND/OR keeps order for left-to-right eval', () {
      final q = parseStrongsBoolean('G25 AND G26 OR G27')!;
      expect(q.ops, [StrongsOp.and, StrongsOp.or]);
    });

    test('non-Strong text aborts (→ null, falls back to text search)', () {
      expect(parseStrongsBoolean('love AND faith'), isNull);
      expect(parseStrongsBoolean('G25 AND love'), isNull);
      expect(parseStrongsBoolean('John 3:16'), isNull);
    });

    test('trailing / dangling operator is invalid', () {
      expect(parseStrongsBoolean('G25 AND'), isNull);
      expect(parseStrongsBoolean('AND G25'), isNull);
    });

    test('out-of-range numbers rejected', () {
      expect(parseStrongsBoolean('G99999 AND G26'), isNull);
      expect(parseStrongsBoolean('H99999 OR H1'), isNull);
    });
  });

  group('evaluateStrongsBoolean (set algebra)', () {
    // Stub occurrence sets per term.
    final data = {
      'G25': {'John 3:16', 'Romans 5:8', '1 John 4:8'},
      'G26': {'Romans 5:8', '1 John 4:8', 'John 13:35'},
      'G27': {'1 John 4:8'},
    };
    Set<String> refsFor(StrongsTerm t) => {...?data[t.number]};

    test('AND = intersection', () {
      final q = parseStrongsBoolean('G25 AND G26')!;
      expect(evaluateStrongsBoolean(q, refsFor),
          {'Romans 5:8', '1 John 4:8'});
    });

    test('OR = union', () {
      final q = parseStrongsBoolean('G25 OR G26')!;
      expect(evaluateStrongsBoolean(q, refsFor), {
        'John 3:16',
        'Romans 5:8',
        '1 John 4:8',
        'John 13:35',
      });
    });

    test('three-way AND', () {
      final q = parseStrongsBoolean('G25 G26 G27')!;
      expect(evaluateStrongsBoolean(q, refsFor), {'1 John 4:8'});
    });

    test('left-to-right: (G25 AND G26) OR G27', () {
      final q = parseStrongsBoolean('G25 AND G26 OR G27')!;
      // (G25 ∩ G26) = {Romans 5:8, 1 John 4:8}; ∪ G27 {1 John 4:8}
      expect(evaluateStrongsBoolean(q, refsFor),
          {'Romans 5:8', '1 John 4:8'});
    });

    test('empty term set yields empty AND result', () {
      final q = parseStrongsBoolean('G25 AND H7225')!; // H7225 absent in stub
      expect(evaluateStrongsBoolean(q, refsFor), isEmpty);
    });
  });
}
