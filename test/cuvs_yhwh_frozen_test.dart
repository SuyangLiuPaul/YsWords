import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// 和合本雅偉版 is frozen. The publisher declined our corrections
/// (user, 2026-09-02: 「cuvs yhwh这个不用管 因为出版方说这个不要」), so the
/// two assets are read-only from here on.
///
/// This test exists because the queue had **25 open items proposing edits to
/// these files**, several of them with a ready-to-run repair script sitting
/// beside them in `tools/`. Deleting the items removes the instruction; it
/// does not remove the scripts, and it does not stop an audit from finding
/// 0 蹟 / 103 跡 all over again next month and "fixing" it. A hash is the
/// only guard that survives a rediscovery.
///
/// **If this test fails, the answer is almost never to update the hash.**
/// It means something edited a text we do not own. Revert the asset. The
/// hash changes only when the publisher ships us a new module — and then
/// the commit that updates it should say so and nothing else.
///
/// Scope, so nobody over-reads the freeze: the *reading assets* are frozen.
/// The word-tap corpus, the Strong's tagging, the lexicon and every line of
/// rendering code are ours and stay open — including the editorial brackets
/// this app renders around `[雅偉]`, which are a rendering decision about
/// the publisher's own notation, not an edit to it.
void main() {
  const frozen = <String, String>{
    'assets/cuvs-yhwh.json':
        '5e18b8b18d502a8cbfa7bbbcbf79e58921f5a05be6e64834d83f1039306d5494',
    'assets/cuvs-yhwh-tr.json':
        'd28897b6643841067f1ef763a8cf5da3c135b03f6dff0935557da3029e824771',
  };

  frozen.forEach((path, expected) {
    test('$path is unchanged since the publisher declined our corrections',
        () {
      final file = File(path);
      expect(file.existsSync(), isTrue,
          reason: '$path is a shipped reading asset; it should not vanish');
      final actual = sha256.convert(file.readAsBytesSync()).toString();
      expect(actual, expected,
          reason: 'CHANGED. 和合本雅偉版 is not ours to edit — see the '
              'FROZEN block at the top of docs/autonomous-queue.md. '
              'Revert the asset rather than updating this hash, unless '
              'the publisher has sent a new module.');
    });
  });

  test('the frozen assets still parse and still hold 31,102 verses', () {
    // A hash catches an edit; it does not catch a file that was replaced
    // wholesale by something else and then had its hash "fixed". This is
    // the cheap second opinion.
    for (final path in frozen.keys) {
      final verses = json.decode(File(path).readAsStringSync()) as List;
      expect(verses, hasLength(31102), reason: '$path lost or gained verses');
    }
  });
}
