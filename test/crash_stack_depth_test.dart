// A crash report is only as useful as the frames it carries.
//
// BUGS #1 (`Invalid argument: 0`, web release) has now cost ~13
// forensic passes trying to work out WHICH `.clamp()` call inverted.
// It is unidentifiable from the top frame by construction: dart2js
// compiles ONE `num.clamp()` for the whole program — every call in the
// app, in Flutter, and in every package lands on the same line. The
// caller frame is the entire diagnostic value of the report.
//
// Measured 2026-09-02 with dart2js -O4 (the release configuration), a
// 24-deep call chain throwing an inverted clamp:
//
//     default (V8 Error.stackTraceLimit = 10) → 10 frames
//     Error.stackTraceLimit = 50              → 47 frames
//
// Two of those ten are the throw helper and clamp itself, so a throw
// deep inside Flutter's boot can spend the whole budget before reaching
// any line we wrote. Hence the bump in index.html.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final html = File('web/index.html').readAsStringSync();

  test('the stack-frame budget is raised before anything can throw', () {
    expect(html, contains('Error.stackTraceLimit = 50'),
        reason: 'without this a crash report is capped at 10 frames and '
            'a boot-time throw may not reach our own code at all');
  });

  test('it is set before the engine bootstrap tag', () {
    // A limit raised after the engine starts is a limit raised too late
    // for exactly the crash it exists to diagnose. Anchor on the real
    // <script src> tag: the string "main.dart.js" appears in prose
    // comments long before anything loads, and a first draft of this
    // test passed on one of those instead.
    final limitAt = html.indexOf('Error.stackTraceLimit');
    final bootAt = html.indexOf('<script src="flutter_bootstrap.js"');
    expect(limitAt, greaterThan(-1));
    expect(bootAt, greaterThan(-1),
        reason: 'the engine bootstrap tag moved or was renamed');
    expect(limitAt, lessThan(bootAt),
        reason: 'the assignment must precede the engine bootstrap');
  });

  test('it cannot throw in a browser that has no such property', () {
    // Firefox and Safari have fixed internal limits and no knob. The
    // assignment is harmless there, but only because it is guarded.
    final at = html.indexOf('Error.stackTraceLimit');
    final window = html.substring((at - 200).clamp(0, at), at + 120);
    expect(window, contains('try {'),
        reason: 'the assignment must be inside a try/catch');
  });

  test('the reporter still sends enough of the stack to hold them', () {
    // 50 frames of minified dart2js is well under this cap, but if the
    // cap ever drops below what the frames need, the bump above buys
    // nothing.
    final reporter =
        File('lib/services/error_reporter.dart').readAsStringSync();
    expect(reporter, contains("_trim(stack, 8000)"),
        reason: 'stack payload cap changed — re-check it against 50 '
            'frames of minified dart2js before lowering it');
  });
}
