// 2026-09-14 (accessibility pass): WCAG 2.3.3, motion from interaction.
//
// The platform switch a reader flips to say "less movement, please" —
// Reduce Motion on iOS/macOS, Remove animations on Android,
// `prefers-reduced-motion: reduce` in a browser — reaches Flutter as
// `MediaQueryData.disableAnimations`. Nothing in the framework applies it
// to an implicit animation on your behalf: `AnimatedSlide` travels for
// exactly as long as you tell it to. Two widgets in this app read the
// flag; the rest did not, including the two chrome bars that slide 1.4x
// their own height every time the reader taps to hide the chrome.
//
// So this has two halves, and the source half is the one that will still
// be working in a year: a behaviour test proves the bars are still when
// asked, and the inventory proves the NEXT movement animation someone
// writes has to decide the question.
//
// Fades are deliberately out of scope. 2.3.3 is about motion — travel,
// scale, spin — and a 150 ms crossfade is not motion. Zeroing every
// AnimatedSwitcher would turn a label change into a jump cut for the
// reader who asked for calm, which is not calmer.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/constants/motion.dart';

/// The widgets whose whole job is to MOVE something.
const List<String> _movers = <String>[
  'AnimatedSlide',
  'AnimatedScale',
  'AnimatedRotation',
  'AnimatedSize',
  // This app also slides the whole reading column and the sidebar.
  'AnimatedPadding',
  'AnimatedPositioned',
];

/// Sites that answer the question somewhere other than in `duration:`.
const Map<String, String> _answeredElsewhere = <String, String>{
  // Returns the bare child before it ever builds the AnimatedScale, so
  // there is no duration to gate — a stronger form of the same answer.
  'lib/widgets/press_scale.dart':
      'early-returns the unanimated child when disableAnimations is set',
  // Chooses between an unanimated surface and the AnimatedScale on the
  // same flag, a few lines above the site this rule would flag.
  'lib/widgets/liquid_glass.dart':
      'branches on mq.disableAnimations before building the AnimatedScale',
};

const _bar = Key('reduced-motion-probe-bar');

void main() {
  group('reduced motion', () {
    testWidgets('AppMotion.duration collapses to nothing when asked, and '
        'only then', (tester) async {
      const d = Duration(milliseconds: 320);

      for (final entry in {true: Duration.zero, false: d}.entries) {
        late Duration seen;
        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(disableAnimations: entry.key),
          child: Builder(builder: (context) {
            seen = AppMotion.duration(context, d);
            return const SizedBox.shrink();
          }),
        ));
        expect(seen, entry.value,
            reason: 'disableAnimations: ${entry.key}');
      }
    });

    testWidgets('with no MediaQuery at all the animation still plays',
        (tester) async {
      // The fallback matters: `maybeOf` returning null must mean "the
      // reader has not asked for less motion", not "no animations". A
      // widget built outside a MediaQuery — a test, a raw overlay —
      // should look like the app, not like Reduce Motion is on.
      late Duration seen;
      await tester.pumpWidget(Builder(builder: (context) {
        seen = AppMotion.duration(context, AppMotion.standard);
        return const SizedBox.shrink();
      }));
      expect(seen, AppMotion.standard);
    });

    testWidgets('a bar built this way is already there on the first frame',
        (tester) async {
      // The claim the helper makes, tested through a real AnimatedSlide
      // rather than only through the Duration it hands back: with reduced
      // motion on, the bar is at its destination after ONE frame; with it
      // off, one frame in it is still on the way.
      //
      // Compared against the SETTLED position rather than a computed
      // pixel value — the destination is the thing being asserted, and a
      // number worked out from the box height and the 1.4 offset would
      // only be re-deriving the framework's arithmetic in the test.
      Widget bar({required bool reduce, required Offset offset}) => MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: Builder(builder: (context) {
                  return AnimatedSlide(
                    offset: offset,
                    duration: AppMotion.duration(
                        context, const Duration(milliseconds: 320)),
                    child: const SizedBox(width: 100, height: 40, key: _bar),
                  );
                }),
              ),
            ),
          );

      Future<Offset> afterOneFrame({required bool reduce}) async {
        // Settle at rest FIRST. Without this the bar is still wherever
        // the previous phase left it, the new target equals that
        // position, and a one-frame read looks like an instant move for
        // the wrong reason — which is how the first draft of this test
        // passed its reduced-motion half and failed its control.
        await tester.pumpWidget(bar(reduce: reduce, offset: Offset.zero));
        await tester.pumpAndSettle();
        await tester.pumpWidget(
            bar(reduce: reduce, offset: const Offset(0, 1.4)));
        await tester.pump(const Duration(milliseconds: 16));
        return tester.getTopLeft(find.byKey(_bar));
      }

      // Where the bar ends up once any animation has finished.
      await tester.pumpWidget(bar(reduce: false, offset: Offset.zero));
      await tester.pumpAndSettle();
      await tester.pumpWidget(bar(reduce: false, offset: const Offset(0, 1.4)));
      await tester.pumpAndSettle();
      final settled = tester.getTopLeft(find.byKey(_bar));

      expect((await afterOneFrame(reduce: true)).dy, settled.dy,
          reason: 'with reduced motion the bar must be gone in one frame, '
              'not travelling');
      expect((await afterOneFrame(reduce: false)).dy, lessThan(settled.dy),
          reason: 'and without it the animation must still animate — a '
              'helper that always returned zero would pass the assertion '
              'above and flatten the app');
    });

    test('every widget that MOVES something asks first', () {
      final offences = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (_answeredElsewhere.containsKey(entity.path)) continue;
        final src = entity.readAsStringSync();

        for (final mover in _movers) {
          var from = 0;
          while (true) {
            final at = src.indexOf('$mover(', from);
            if (at == -1) break;
            from = at + 1;
            // Comments and doc references name these widgets too.
            final lineStart = src.lastIndexOf('\n', at) + 1;
            final prefix = src.substring(lineStart, at).trimLeft();
            if (prefix.startsWith('//') || prefix.startsWith('///')) continue;

            // The constructor's own argument list, no further: a mover
            // can hold another animated widget as its child.
            final end = _closingParen(src, at + mover.length);
            final args = src.substring(at, end);
            if (!args.contains('duration:')) continue;
            if (args.contains('AppMotion.duration(')) continue;
            offences.add('${entity.path}:'
                '${src.substring(0, at).split('\n').length} — $mover');
          }
        }
      }

      expect(
        offences,
        isEmpty,
        reason: 'These animations move something on screen for a fixed '
            'duration no matter what the reader has asked for. Wrap the '
            'duration in `AppMotion.duration(context, …)`, which returns '
            'Duration.zero when the platform reports reduced motion. If '
            'the site genuinely answers the question another way, add it '
            'to _answeredElsewhere with the reason:\n  '
            '${offences.join('\n  ')}',
      );
    });

    test('the exemption list still describes real files', () {
      // An exemption that outlives its file is an exemption nobody is
      // reading — and it would silently cover a path someone later
      // creates with that name.
      for (final path in _answeredElsewhere.keys) {
        expect(File(path).existsSync(), isTrue,
            reason: '$path is exempt from the rule above but does not '
                'exist. Remove the entry.');
      }
    });
  });
}

/// Index just past the `(` … `)` that starts at [open].
int _closingParen(String src, int open) {
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == '(') depth++;
    if (src[i] == ')') {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return src.length;
}
