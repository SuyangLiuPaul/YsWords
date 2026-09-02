import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/log_diag.dart';

/// `debugPrint` emits nothing from a release web build.
///
/// Measured 2026-09-02 with a single-build control — two adjacent
/// statements in `BibleReadingPane`'s builder, same frame, same bundle:
///
///     [log] [CONTROL-print] this line uses print()     ← appeared
///           [CONTROL-debugPrint] ...                    ← ABSENT
///
/// The strings were in `main.dart.js` and the code demonstrably ran, so
/// this is neither tree-shaking nor a dead branch. It matters because
/// v1.2.50 added the `[Yahweh's Words jump]` chain expressly so users
/// could paste console output, and the web is where the reports come
/// from — the instrument had never worked on the platform it was for.
void main() {
  group('the routing rule', () {
    test('release web is the only case that needs print', () {
      expect(diagShouldUsePrint(isWeb: true, isRelease: true), isTrue);
    });

    test('debug web keeps debugPrint — it already prints there', () {
      expect(diagShouldUsePrint(isWeb: false, isRelease: true), isFalse);
      expect(diagShouldUsePrint(isWeb: true, isRelease: false), isFalse);
      expect(diagShouldUsePrint(isWeb: false, isRelease: false), isFalse);
    });
  });

  group('the chains written to be read by users', () {
    test('prepareJumpToVerse logs through logDiag, not debugPrint', () {
      // This is the whole point: a jump forensic that cannot be read on
      // the web is not a forensic. If someone reverts one of these to
      // debugPrint the chain goes silent again on the only platform
      // that reports bugs, and silently — which is how it went unnoticed
      // for months.
      final src = File('lib/utils/jump_to_reference.dart').readAsStringSync();
      expect(src, contains("import 'package:yswords/utils/log_diag.dart';"));
      expect(RegExp(r"debugPrint\('\[Yahweh").hasMatch(src), isFalse,
          reason: 'use logDiag for the user-facing jump chain');
      expect(RegExp(r"logDiag\('\[Yahweh").allMatches(src).length, 4);
    });
  });

  group('what this is deliberately NOT', () {
    test('the app has not been bulk-converted', () {
      // Converting every debugPrint would ship developer noise to a
      // release console, drown the lines support actually needs, and
      // cost paint time in hot paths. If this count ever collapses
      // toward zero, someone has run a global find-and-replace and the
      // judgement in log_diag.dart's doc comment was lost.
      final lib = Directory('lib');
      var debugPrints = 0;
      for (final f in lib.listSync(recursive: true)) {
        if (f is File && f.path.endsWith('.dart')) {
          debugPrints += RegExp(r'\bdebugPrint\(')
              .allMatches(f.readAsStringSync())
              .length;
        }
      }
      expect(debugPrints, greaterThan(50),
          reason: 'most debugPrints are developer noise and should stay '
              'debugPrint — see the doc comment in log_diag.dart');
    });
  });
}
