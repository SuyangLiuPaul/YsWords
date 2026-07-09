import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/bible_map.dart';
import 'package:yswords/services/fetch_books.dart' show standardBookOrder;
import 'package:yswords/utils/illustration_grouping.dart';

/// Regression tests for the browse-all illustrations grouping.
///
/// v1.3.118's primary-book-only de-dup silently EMPTIED 13 NT books
/// (Romans, Ephesians, Philemon, …) from the catalogue: every
/// illustration touching them also touched an earlier canonical book,
/// the whole group ended up empty, and empty groups don't render — so
/// browsing or searching those books showed nothing. These tests run
/// the REAL grouping over the REAL bundled index so any future
/// grouping change that hides a book fails CI.
void main() {
  late List<BibleMap> all;

  setUpAll(() {
    final raw =
        File('assets/maps_index.json').readAsStringSync();
    final decoded = json.decode(raw);
    final list = decoded is Map<String, dynamic>
        ? (decoded['maps'] as List<dynamic>? ?? const [])
        : decoded as List<dynamic>;
    all = list
        .whereType<Map<String, dynamic>>()
        .map(BibleMap.fromJson)
        .toList();
  });

  test('every book referenced by any illustration has a non-empty group',
      () {
    final groups = groupIllustrationsByBook(all, standardBookOrder);
    final referenced = <String>{
      for (final m in all)
        for (final b in m.books.keys)
          if (standardBookOrder.contains(b)) b,
    };
    final emptied = [
      for (final b in referenced)
        if ((groups[b] ?? const []).isEmpty) b,
    ];
    expect(emptied, isEmpty,
        reason: 'books with illustrations that vanished from browse: '
            '$emptied');
  });

  test('wide survey maps are de-duplicated (listed once, not per book)',
      () {
    final groups = groupIllustrationsByBook(all, standardBookOrder);
    // Total tiles must stay well below the pre-v1.3.118 duplicate-spam
    // level (1940 for 1192 illustrations) — the de-dup must survive.
    final tiles =
        groups.values.fold<int>(0, (a, b) => a + b.length);
    expect(all.length, greaterThan(1000),
        reason: 'sanity: real index loaded');
    expect(tiles, lessThan(all.length * 1.5),
        reason: 'grouping re-introduced duplicate spam: '
            '$tiles tiles for ${all.length} illustrations');
  });

  test('small-span illustrations appear under every tagged book', () {
    final groups = groupIllustrationsByBook(all, standardBookOrder);
    // "Paul leaves Ephesus" spans Acts + Ephesians only — it must be
    // visible under BOTH (the v1.3.118 bug hid it from Ephesians).
    final ephesians = groups['Ephesians'] ?? const [];
    expect(
      ephesians.any((m) => m.id == 'illus_schnorr_234_paul_leaves_ephesus'),
      isTrue,
      reason: 'a 2-book illustration must list under its second book too',
    );
  });
}
