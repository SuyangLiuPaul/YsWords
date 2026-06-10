import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_verses.dart';

/// 2026-06-11: coverage for `FetchVerses.execute` — the cold-load
/// retry/timeout pipeline. Listed as an open coverage gap in
/// docs/priorities.md since v1.3.23. The retry semantics carry real
/// history: v1.2.10's "3 attempts" collapsed into 1 because Flutter
/// web memoises the in-flight rootBundle future (fixed in v1.2.12 via
/// per-asset evict). These tests pin the OBSERVABLE contract:
/// attempt count, onAttempt callback sequence, rethrow-after-final,
/// and the happy path against a real bundled asset.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('happy path: loads a real bundled version end-to-end and '
      'fires onAttempt exactly once', () async {
    final mp = MainProvider();
    mp.currentVersion = 'biblexg'; // smallest real bundle (NT only)

    final attempts = <(int, Object?)>[];
    await FetchVerses.execute(
      mainProvider: mp,
      onAttempt: (a, err) => attempts.add((a, err)),
    );

    expect(mp.verses, isNotEmpty,
        reason: 'biblexg.json must parse into verses');
    expect(mp.versesInChapter('馬太福音', 1).isNotEmpty ||
        mp.versesInChapter('马太福音', 1).isNotEmpty ||
        mp.verses.first.book.isNotEmpty, isTrue);
    expect(attempts, [(1, null)],
        reason: 'success on attempt 1 → no retries, no lastError');
  });

  test('missing asset: retries maxAttempts times with lastError '
      'threaded into onAttempt, then rethrows', () async {
    final mp = MainProvider();
    mp.currentVersion = 'no-such-version';

    final attempts = <(int, bool)>[]; // (attempt, hadLastError)
    Object? thrown;
    try {
      await FetchVerses.execute(
        mainProvider: mp,
        maxAttempts: 3,
        timeoutPerAttempt: const Duration(seconds: 5),
        onAttempt: (a, err) => attempts.add((a, err != null)),
      );
    } catch (e) {
      thrown = e;
    }

    expect(thrown, isNotNull,
        reason: 'execute must rethrow after the final attempt');
    expect(attempts, [(1, false), (2, true), (3, true)],
        reason: 'first attempt has no lastError; retries carry the '
            'previous failure');
    expect(mp.verses, isEmpty,
        reason: 'a failed load must not leave partial verses behind');
  });

  test('maxAttempts is honored (2 attempts → 2 onAttempt calls)',
      () async {
    final mp = MainProvider();
    mp.currentVersion = 'still-missing';

    var calls = 0;
    await expectLater(
      FetchVerses.execute(
        mainProvider: mp,
        maxAttempts: 2,
        timeoutPerAttempt: const Duration(seconds: 5),
        onAttempt: (_, __) => calls++,
      ),
      throwsA(anything),
    );
    expect(calls, 2);
  });
}
