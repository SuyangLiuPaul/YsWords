// Runs tools/test_release_scripts.py, which exercises the four release
// scripts for real against stub flutter / netlify / curl / gh binaries.
//
// Those scripts are bash and python, so their tests are too — and a test
// nothing runs is a failure mode this repo has already paid for twice.
// tools/audit_p0.py sat unwired for months (see flutter-ci.yml's step for
// it), and the release path itself shipped `&` + a bare `wait` for weeks,
// announcing "✓ deployed" over two silently failed deploys. Putting the
// python under `flutter test` is what makes the guard a guard.
//
// It shells out rather than reimplementing anything: the point is to run
// the ACTUAL scripts, in a temp directory, including the ones no unit
// test in Dart could reach.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tools/test_release_scripts.py passes', () async {
    final result = await Process.run(
      'python3',
      ['tools/test_release_scripts.py'],
      workingDirectory: Directory.current.path,
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
