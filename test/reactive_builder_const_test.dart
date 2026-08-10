import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A `const` widget returned from a reactive builder never rebuilds.
///
/// 2026-08-11, from an iPhone: "it is playing but the bottom is not
/// moving." The mini-player's elapsed time sat at 0:00 and its button
/// stayed ▶ while the row above showed ⏸ for the same song.
///
/// `global_mini_player.dart` did this:
///
///     ListenableBuilder(
///       listenable: player,
///       builder: (context, _) => const _Strip(),   // ← never updates
///     )
///
/// A const constructor call is canonicalised, so every rebuild hands
/// `Element.updateChild` the *identical* Widget object. Its
/// `child.widget == newWidget` fast path then returns without
/// rebuilding, which disables the surrounding builder completely. The
/// player was notifying correctly the whole time — nothing was
/// listening.
///
/// This is a source scan rather than a widget test on purpose: the
/// defect is a property of how the tree is *written*, it is invisible
/// to a rendering test that only pumps once, and the same two lines can
/// reappear anywhere. `prefer_const_constructors` actively pushes code
/// back toward it, so the guard has to be explicit.
///
/// Static widgets (`SizedBox`, `Divider`, a fixed `Text`) are exempt —
/// they genuinely do not depend on the notification.
void main() {
  const exempt = {
    'SizedBox', 'Spacer', 'Divider', 'Text', 'Icon', 'Padding', 'Center',
    'CircularProgressIndicator', 'LinearProgressIndicator', 'Placeholder',
  };
  final reactive = RegExp(
      r'(ListenableBuilder|AnimatedBuilder|ValueListenableBuilder|'
      r'StreamBuilder|Consumer<|Selector<)');
  final constReturn = RegExp(r'return\s+const\s+([A-Z_]\w*)\s*\(');

  test('no reactive builder returns a const non-static widget', () {
    final offenders = <String>[];

    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!reactive.hasMatch(lines[i])) continue;
        // The builder body follows within a few lines in this codebase.
        for (var j = i; j < i + 25 && j < lines.length; j++) {
          final m = constReturn.firstMatch(lines[j]);
          if (m == null) continue;
          if (exempt.contains(m.group(1))) continue;
          offenders.add('${f.path}:${j + 1}  '
              'returns `const ${m.group(1)}(` from the builder at '
              'line ${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'A const widget returned from a reactive builder is '
          'canonicalised, so Flutter skips the rebuild and the builder '
          'silently stops working. Drop the `const`.\n'
          '${offenders.join('\n')}',
    );
  });
}
