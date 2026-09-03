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
/// **The line was drawn in the wrong place first, and 2026-09-03 moved
/// it.** The original rule flagged only a maxHeight in fixed POINTS, on
/// the reasoning that a fraction of the viewport is how sheets are
/// sized and the scroll view under one is that sheet's only scrollable.
/// That reasoning was about sheets, and it was applied to SECTIONS of
/// sheets, where it is false. User, 2026-08-16: "很多时候这些框框都是上下
/// 滑动很多地方都是这样是不是全部要找出来fix" — and the sweep that answered
/// it found six more, every one a fraction:
///
///   * `songs_page.dart` capped the theme chips at 0.22 and the book
///     chips at 0.30 INSIDE the filter sheet's own scroll view — the
///     AI-panel defect exactly, invisible to the old rule;
///   * `sermons_page.dart` gave Book / Chapter / Verse 0.30 / 0.16 /
///     0.16, three regions scrolling by themselves in one sheet;
///   * `stats_page.dart` (0.55) and `bible_trivia_page.dart` (0.50)
///     each clipped 66 book chips into a box while the sheet around
///     them did not scroll at all.
///
/// The rule now: a vertical scroll view must not be the DIRECT child of
/// any height cap, fraction or not. Capping the SHEET is still fine and
/// is how all four of those now work — the cap wraps a `Padding` and a
/// `Column`, and the one scroll view inside is the sheet's own.
///
/// `Container(constraints: …)` is scanned too. The only one in `lib/` is
/// the export dialog's 280pt preview in `settings_page.dart`, whose
/// child is a `SelectableText` that owns its scroller with nothing
/// scrollable around it — not a scroll view by this check's list, so it
/// passes for the right reason rather than by exemption.
void main() {
  test('no vertical scroll view sits directly under a height cap', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty, reason: 'no sources found — wrong cwd?');

    final offenders = <String>[];
    for (final file in files) {
      final src = file.readAsStringSync();
      for (final match
          in RegExp(r'\b(ConstrainedBox|Container)\(').allMatches(src)) {
        final body = _balancedArgs(src, match.end - 1);
        if (body == null) continue;
        // Any cap at all now — `maxHeight: 320` and
        // `maxHeight: MediaQuery.of(context).size.height * 0.30` are
        // the same instruction to the reader's finger.
        if (!body.contains('maxHeight:')) continue;
        if (!_capsAScrollView(body)) continue;
        offenders.add('${file.path}:${_lineOf(src, match.start)}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'a scroll view directly under a height cap cannot be '
          'dragged once anything around it scrolls in the same axis — '
          'the outer scrollable takes the gesture and the content '
          'underneath never moves, behind a scrollbar that still '
          'renders. Let the content flow into the sheet instead, and '
          'cap the sheet: ${offenders.join(', ')}',
    );
  });
}

/// Whether the capped box's OWN child is a vertical scroll view.
///
/// Its own child, not any descendant: capping a sheet whose body
/// happens to contain a list is the shape every sheet in the app uses
/// and is not the defect. `Scrollbar` is stepped through because it is
/// decoration around the scroller, not a scroller. Horizontal scrollers
/// are skipped — a chip rail under a height cap scrolls ACROSS the
/// parent's axis, so no gesture is ambiguous.
bool _capsAScrollView(String constrainedBoxArgs) {
  var child = _topLevelChild(constrainedBoxArgs);
  for (var hop = 0; hop < 3 && child != null; hop++) {
    final open = child.indexOf('(');
    if (open < 0) return false;
    final name = child.substring(0, open).trim();
    final args = _balancedArgs(child, open) ?? '';
    if (const {
      'SingleChildScrollView',
      'ListView',
      'CustomScrollView',
      'GridView',
      'ReorderableListView',
    }.contains(name.split('.').first)) {
      return !args.contains('scrollDirection: Axis.horizontal');
    }
    if (name != 'Scrollbar' && name != 'RawScrollbar') return false;
    child = _topLevelChild(args);
  }
  return false;
}

/// The value of the depth-0 `child:` argument in [args], trimmed, or
/// null when there is none.
String? _topLevelChild(String args) {
  var depth = 0;
  for (var i = 0; i < args.length; i++) {
    final c = args[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (depth == 0 && args.startsWith('child:', i)) {
      return args.substring(i + 'child:'.length).trimLeft();
    }
  }
  return null;
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
