import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two places where a short label was given less width than it needed
/// and wrapped instead of shrinking. Reported 2026-08-23 from an iPad
/// and from dev web.
///
/// **These are source-contract tests, not render tests.** Both widgets
/// are private (`_VersePickerChip`, `_SelectionActionBar`) and the real
/// layouts need a loaded `MainProvider` behind a two-step navigation, so
/// what is pinned here is the *decision* in each case — which is exactly
/// what regressed. A render test would be better and is worth writing if
/// either widget is ever lifted out of its file.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('verse picker chips', () {
    // 詩篇 119 has 176 verses, so the grid is full of three-character
    // labels. The chip sits in a SizedBox of an exact `tileW`, so a
    // label wider than the tile wrapped one character per line: "125"
    // came out as 1/2/5 down a column, and on the iPad even two-digit
    // numbers split in half.
    late final String source = read('lib/widgets/book_chapter_picker.dart');

    test('the chip label is told not to wrap', () {
      final chip = source.substring(source.indexOf('class _VersePickerChip'));
      expect(chip, contains('maxLines: 1'),
          reason: 'a verse number must occupy exactly one line');
      expect(chip, contains('softWrap: false'),
          reason: 'without this the Text still breaks between digits');
    });

    test('and is shrunk to fit rather than truncated', () {
      final chip = source.substring(source.indexOf('class _VersePickerChip'));
      expect(chip, contains('BoxFit.scaleDown'),
          reason: 'ellipsising a verse number would render "1…", which '
              'is worse than a small "176" — the number IS the content');
    });
  });

  group('selection action bar', () {
    // The bar lays out on one row when it fits and two when it does not.
    // The threshold was the literal 560, chosen when the action row held
    // five icons; related-sermons and AI-explain later made it seven and
    // the literal did not move. At an iPad split-view width the fixed
    // children consumed the row, and the two flexible ones — the count
    // and the Copy button — were left splitting what was left. The count
    // ellipsised to "已选择 …" and Copy lost its word entirely, leaving a
    // bare icon with no way to know what it did.
    late final String source = read('lib/widgets/bible_reading_pane.dart');

    test('the one-row threshold is derived from the row, not hard-coded',
        () {
      final marker = source.indexOf('final isNarrow =');
      expect(marker, greaterThan(-1), reason: 'the branch was renamed');
      final line = source.substring(marker, source.indexOf(';', marker));

      expect(line, isNot(matches(RegExp(r'<\s*\d'))),
          reason: 'a literal width here rots the next time an icon is '
              'added to the row — that is how this defect happened');
      expect(line, contains('oneRowNeeds'));

      final formula = source.substring(
          source.indexOf('final oneRowNeeds ='), marker);
      expect(formula, contains('actionButtons.length'),
          reason: 'the threshold must track the number of action icons');
    });

    test('the count and Copy both get a width floor in that formula', () {
      expect(source, contains('copyButtonMinWidth'));
      expect(source, contains('countLabelMinWidth'));
    });
  });
}
