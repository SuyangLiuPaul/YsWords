import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The forensic logging chains, audited as source.
///
/// **The defect this exists to prevent.** v1.2.50 added the
/// `[Yahweh's Words jump]` chain expressly "so users who still report
/// problems can paste the browser console output". It was written on
/// `debugPrint`. `lib/main.dart` no-ops `debugPrint` in every release
/// build (an intentional 2026-06-11 info-disclosure fix), so on the web
/// — the only platform this app's bug reports come from — the
/// instrument was mute from the day it shipped, and stayed mute for
/// months. It cost one debugging session four rebuild cycles: an empty
/// console was read as "this code never ran", when the code ran fine
/// and simply could not speak.
///
/// The reason it survived so long is that **nothing could see it**. A
/// silent instrument produces no failing test, no error, no symptom —
/// only the absence of output, which looks identical to "the feature
/// worked". So the guard has to be a lint over the source: the only
/// place the muteness is visible is in the call itself.
///
/// Reverting any one of these lines to `debugPrint` re-mutes that step
/// of the chain on the web, silently. That is what these tests refuse.
void main() {
  /// Every chain deliberately written to be read OUTSIDE the dev
  /// machine, as `(file, tag, atLeast)`.
  ///
  /// `atLeast` is the count measured 2026-09-03. It is a floor rather
  /// than an equality so that adding a step to a chain is free, while
  /// deleting one — the other way a chain goes quiet — still fails.
  const chains = <({String file, String tag, int atLeast})>[
    // The jump forensics: bail reasons and the attempt counter. The
    // chain the whole item is about.
    (
      file: 'lib/widgets/bible_reading_pane.dart',
      tag: "Yahweh's Words jump",
      atLeast: 12
    ),
    // Its other half — resolution and book-matching, upstream of the
    // scroll. Converted 2026-09-02.
    (
      file: 'lib/utils/jump_to_reference.dart',
      tag: "Yahweh's Words prepareJumpToVerse",
      atLeast: 4
    ),
    // Search. Its own comment used to end "(debugPrint outputs to
    // console.log on Flutter web)" — the exact false premise. The
    // chain was added because a user "kept seeing scanned 0 verses",
    // to be read by that user, in a browser.
    (
      file: 'lib/pages/search_page.dart',
      tag: "Yahweh's Words search",
      atLeast: 11
    ),
    // BYOK key sync, added against the user report "why some api for
    // gemini not synced". Narrates subscribe / emit / apply, which is
    // unobservable from the UI — the log IS the evidence.
    (
      file: 'lib/models/app_settings.dart',
      tag: "Yahweh's Words BYOK",
      atLeast: 10
    ),
    // Note reference taps. Its comment says it outright: added
    // v1.2.64 "so users reporting 'popup not opening' can paste the
    // browser console output". Found by the open-ended sweep below,
    // not by the file-by-file pass — which is the argument for
    // keeping that sweep.
    (
      file: 'lib/pages/library_page.dart',
      tag: "Yahweh's Words noteRefTap",
      atLeast: 4
    ),
    // Deep-link / URL sync. Web-only code, so in release these were
    // not merely quiet but structurally guaranteed dead. An open boot
    // investigation is stalled on exactly these lines: a `[UrlSync]`
    // failure and a clean run are currently indistinguishable, because
    // `_applyHashToState` throws into a local catch that reports only
    // through the silenced channel.
    (
      file: 'lib/services/url_sync_service_web.dart',
      tag: 'UrlSync',
      atLeast: 8
    ),
  ];

  /// A `debugPrint(` whose first argument is a string literal opening
  /// with `[<tag>]`. Tolerates a line break after the paren, which is
  /// how the longer calls are wrapped.
  RegExp muted(String tag) =>
      RegExp(r"\bdebugPrint\(\s*'\[" + RegExp.escape(tag).replaceAll("'", r"\\'"));

  RegExp routed(String tag) =>
      RegExp(r"\blogDiag\(\s*'\[" + RegExp.escape(tag).replaceAll("'", r"\\'"));

  test('there are still forensic chains to audit', () {
    // If this list is ever emptied the rest of the file passes
    // vacuously, which is the one way a lint test rots without going
    // red.
    expect(chains, isNotEmpty);
  });

  group('every forensic chain speaks in a release web build', () {
    for (final chain in chains) {
      test('[${chain.tag}] in ${chain.file.split('/').last}', () {
        final src = File(chain.file).readAsStringSync();

        expect(src, contains("import 'package:yswords/utils/log_diag.dart';"),
            reason: '${chain.file} logs forensics but does not import '
                'logDiag');

        final reverted = muted(chain.tag).allMatches(src).length;
        expect(reverted, 0,
            reason: 'a [${chain.tag}] line went back to debugPrint in '
                '${chain.file}. debugPrint is a global no-op in release '
                '(lib/main.dart), so that step is now invisible in the '
                'build users actually run — and invisibly so. Use '
                'logDiag.');

        expect(routed(chain.tag).allMatches(src).length,
            greaterThanOrEqualTo(chain.atLeast),
            reason: 'the [${chain.tag}] chain lost steps; a chain with '
                'holes in it reports a bail that never happened');
      });
    }
  });

  test('no branded forensic line anywhere is still on debugPrint', () {
    // The per-chain tests above are keyed to known files. This one is
    // open-ended: the `[Yahweh's Words ...]` prefix is the app's own
    // name, used so a non-technical user can find and copy the right
    // lines out of a console full of Firebase chatter. Anything
    // wearing it is by definition meant to be read by a user, wherever
    // it lives — including a file that does not exist yet.
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final f in files) {
      final src = f.readAsStringSync();
      for (final m
          in RegExp(r"\bdebugPrint\(\s*'\[Yahweh").allMatches(src)) {
        offenders.add(
            '${f.path}:${'\n'.allMatches(src.substring(0, m.start)).length + 1}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'these carry the user-facing prefix but are routed '
            'through the channel that is silenced in release');
  });

  test('the messages still say what they said', () {
    // The point of the item was emission, not wording: these strings
    // are the forensic record, and a support conversation matches
    // against them by eye. Pinning a few of the load-bearing ones so a
    // tidy-up of the logging cannot quietly reword the evidence.
    final pane =
        File('lib/widgets/bible_reading_pane.dart').readAsStringSync();
    for (final phrase in const [
      'post-frame bail',
      'gave up after 60 attempts',
      'controller never attached',
      'highlight set to',
      'scroll threw',
    ]) {
      expect(pane, contains(phrase),
          reason: 'the jump chain lost the phrase "$phrase"');
    }
  });

  test('logDiag is still necessary — main.dart still silences debugPrint',
      () {
    // This is the premise the whole helper rests on, and it is not
    // self-evident from reading log_diag.dart: `debugPrint` is not
    // stripped by the compiler, it is *reassigned* to an empty closure
    // at the top of main(). If that override is ever removed, logDiag's
    // reason for existing changes and every note in this repo about it
    // goes stale — so surface that as a red test rather than letting
    // the two drift apart. Removing the override is not forbidden;
    // it just may not be done silently.
    final src = File('lib/main.dart').readAsStringSync();
    expect(
        RegExp(r'debugPrint\s*=\s*\(String\?\s*message').hasMatch(src), isTrue,
        reason: 'lib/main.dart no longer no-ops debugPrint in release. If '
            'that is deliberate, re-read lib/utils/log_diag.dart: its doc '
            'comment, and the routing rule in diagShouldUsePrint, are '
            'both written on the assumption that it does.');
    expect(src, contains('kReleaseMode'),
        reason: 'the debugPrint override is no longer release-gated');
  });
}
