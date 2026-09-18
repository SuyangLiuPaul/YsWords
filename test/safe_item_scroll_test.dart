/// `Bad state: No element`, reported from the sibling app (Yahweh's
/// Sword 1.6.317 web), whose reader this app shares — reproduced here
/// against this app's copy of the package, then fixed. See
/// `lib/utils/safe_item_scroll.dart` for the diagnosis.
///
/// The sequence is the one the production stack describes: an animated
/// scroll is running, a second is requested (so the package parks it for
/// a frame), and in that frame the list goes away. In a debug build the
/// package's failure is the `ScrollController` "not attached" assertion;
/// in the release build readers run, the same line is `_positions.single`
/// on an empty list — "Bad state: No element".
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:yahwehs_words/utils/safe_item_scroll.dart';

class _Host extends StatefulWidget {
  const _Host({super.key, required this.controller});
  final ItemScrollController controller;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool show = true;
  void hide() => setState(() => show = false);
  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: show
              ? ScrollablePositionedList.builder(
                  itemScrollController: widget.controller,
                  itemCount: 500,
                  itemBuilder: (_, i) => SizedBox(height: 40, child: Text('$i')),
                )
              : const SizedBox.shrink(),
        ),
      );
}

/// Start a long scroll, request a second one mid-flight with [second],
/// then remove the list before the next frame. Returns every error the
/// sequence raised, caught or not.
Future<List<Object>> _runSequence(
  WidgetTester t,
  Future<void> Function(ItemScrollController c) first,
  Future<void> Function(ItemScrollController c) second,
) async {
  final c = ItemScrollController();
  final key = GlobalKey<_HostState>();
  await t.pumpWidget(_Host(key: key, controller: c));
  final errors = <Object>[];
  await runZonedGuarded(() async {
    unawaited(first(c));
    await t.pump(const Duration(milliseconds: 100)); // mid-animation
    unawaited(second(c));
    key.currentState!.hide(); // the chapter turns
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }, (e, _) => errors.add(e));
  final caught = t.takeException();
  if (caught != null) errors.add(caught);
  await t.pumpAndSettle();
  return errors;
}

void main() {
  testWidgets('the raw package call crashes exactly as production did',
      (t) async {
    // The reproduction. If this ever stops failing, the package has fixed
    // its post-frame callback and this whole helper can be reconsidered.
    final errors = await _runSequence(
      t,
      (c) => c.scrollTo(index: 400, duration: const Duration(seconds: 1)),
      (c) => c.scrollTo(index: 200, duration: const Duration(seconds: 1)),
    );
    expect(errors, isNotEmpty);
  });

  testWidgets('scrollToSafely survives the same sequence', (t) async {
    final errors = await _runSequence(
      t,
      (c) => scrollToSafely(c,
          index: 400, duration: const Duration(seconds: 1)),
      (c) => scrollToSafely(c,
          index: 200, duration: const Duration(seconds: 1)),
    );
    expect(errors, isEmpty);
  });

  testWidgets('a request mid-glide still lands, by jumping', (t) async {
    final c = ItemScrollController();
    final positions = ItemPositionsListener.create();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScrollablePositionedList.builder(
          itemScrollController: c,
          itemPositionsListener: positions,
          itemCount: 500,
          itemBuilder: (_, i) => SizedBox(height: 40, child: Text('$i')),
        ),
      ),
    ));
    unawaited(scrollToSafely(c,
        index: 400, duration: const Duration(seconds: 1)));
    await t.pump(const Duration(milliseconds: 100));
    unawaited(scrollToSafely(c,
        index: 200, duration: const Duration(seconds: 1)));
    await t.pumpAndSettle();
    final first = positions.itemPositions.value
        .where((p) => p.itemLeadingEdge >= 0)
        .map((p) => p.index)
        .reduce((a, b) => a < b ? a : b);
    expect(first, 200);
  });

  test('no raw scrollTo anywhere else in lib/', () {
    // The helper is only a fix while it is the only way in.
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('safe_item_scroll.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in RegExp(r'\.scrollTo\(').allMatches(src)) {
        offenders.add('${f.path}:${src.substring(0, m.start).split('\n').length}');
      }
    }
    expect(offenders, isEmpty);
  });
}
