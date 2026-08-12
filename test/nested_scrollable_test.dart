import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-08-12. The AI exegesis panel in the Originals sheet capped its
/// answer at `maxHeight: 320` inside its own `SingleChildScrollView`,
/// and that box sat inside the sheet's outer `ListView`. Two scrollables
/// in one axis: the sheet took every drag, so the inner region never
/// moved while its scrollbar rendered as though it would. A reader on
/// 創世紀 36:3 saw the answer cut mid-sentence with no way to reach the
/// rest of it.
///
/// A widget test would have to pump that one panel in that one state,
/// and would not cover the next bounded scrollable somebody nests. The
/// defect is a SHAPE, so the check is on the shape.
///
/// **The line drawn, after reading all 14 bounded scroll views in
/// `lib/`:** a maxHeight expressed as a fraction of the viewport
/// (`MediaQuery.of(context).size.height * 0.35`) is how every sheet and
/// dialog in this app is sized, and the scroll view under it is that
/// sheet's only scrollable — 13 sites, all working, none flagged. A
/// maxHeight in fixed points says something different: "clip this
/// region and scroll it by itself", which holds only if nothing around
/// it scrolls in the same axis. Inside a sheet or a page, something
/// always does.
void main() {
  test('no vertical scroll view sits under a fixed-point height cap', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty, reason: 'no sources found — wrong cwd?');

    // A vertical scroll view reached from the cap through nothing but
    // decoration. Deeper nesting is out of scope on purpose: a
    // `PageView` of independently scrolling slides under a 240pt cap
    // (onboarding_dialog.dart) scrolls across the parent's axis, not
    // against it.
    final direct = RegExp(
      r'child:\s*(Scrollbar\([^()]*child:\s*)?'
      r'(SingleChildScrollView|ListView|CustomScrollView)\s*[.(]',
    );

    final offenders = <String>[];
    for (final file in files) {
      final src = file.readAsStringSync();
      for (final match in RegExp(r'\bConstrainedBox\(').allMatches(src)) {
        final body = _balancedArgs(src, match.end - 1);
        if (body == null) continue;
        // A number, not an expression: `maxHeight: 320` / `320.0`.
        if (!RegExp(r'maxHeight:\s*[\d.]+\s*[,)]').hasMatch(body)) continue;
        if (body.contains('scrollDirection: Axis.horizontal')) continue;
        if (!direct.hasMatch(body)) continue;
        offenders.add('${file.path}:${_lineOf(src, match.start)}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'a scroll view under a fixed-point height cap cannot be '
          'dragged once anything around it scrolls in the same axis — '
          'the outer scrollable takes the gesture and the content '
          'underneath never moves, behind a scrollbar that still '
          'renders: ${offenders.join(', ')}',
    );
  });
}

/// The source between the parenthesis at [open] and its match, or null
/// if they do not balance. Quotes and comments are not interpreted;
/// no widget argument list in `lib/` carries an unbalanced parenthesis
/// inside a string.
String? _balancedArgs(String src, int open) {
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    final c = src[i];
    if (c == '(') depth++;
    if (c == ')') {
      depth--;
      if (depth == 0) return src.substring(open + 1, i);
    }
  }
  return null;
}

int _lineOf(String src, int index) =>
    '\n'.allMatches(src.substring(0, index)).length + 1;
