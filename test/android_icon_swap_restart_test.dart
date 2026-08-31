// Changing the theme colour on Android silently costs the reader their
// place, and this is the flag that pays it back.
//
// The mechanism, measured on an Android 14 emulator 2026-08-31 rather
// than reasoned about: Android roots a task on the launcher component it
// was started from, and swapping the icon means disabling exactly that
// component, which finishes the task. Observed directly — pick red on
// the Settings page, press Home, and the task record disappears while
// the pid is unchanged (`DONT_KILL_APP` spares the process, not the
// task). Relaunching lands on the Dashboard; the reader was in Settings.
//
// The dangerous half of the fix is not the restore, it is the CLEARING.
// Android kills backgrounded apps routinely, so if this flag ever
// survived one restore, an ordinary launcher tap would start silently
// reopening a settings sub-page — a worse bug than the one being fixed,
// and one that would look like the app "randomly jumping to Settings".
// Hence the emphasis below on consume-exactly-once.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/services/app_icon_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a fresh install restores nothing', () async {
    expect(await consumeAndroidIconSwapPending(), isFalse,
        reason: 'with no flag set, a normal launch must land normally');
  });

  test('marking then consuming reports the restart exactly once', () async {
    await markAndroidIconSwapPending();

    expect(await consumeAndroidIconSwapPending(), isTrue,
        reason: 'the launch straight after a swap should restore');

    // THE assertion. A flag that survives turns every subsequent launcher
    // tap into a jump to Settings.
    expect(await consumeAndroidIconSwapPending(), isFalse,
        reason: 'the flag must clear itself — a second launch is ordinary');
    expect(await consumeAndroidIconSwapPending(), isFalse,
        reason: 'and so is every launch after that');
  });

  test('the key is actually removed from storage, not just read false',
      () async {
    await markAndroidIconSwapPending();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kAndroidIconSwapPendingKey), isTrue);

    await consumeAndroidIconSwapPending();
    expect(prefs.getBool(kAndroidIconSwapPendingKey), isNull,
        reason: 'leaving a stale false behind would be harmless today but '
            'invites a later `containsKey` check to read it as set');
  });

  test('a stale false left by an older build does not trigger a restore',
      () async {
    // Defensive: an explicit false must behave exactly like absent.
    SharedPreferences.setMockInitialValues(
        {kAndroidIconSwapPendingKey: false});
    expect(await consumeAndroidIconSwapPending(), isFalse);
  });

  test('marking twice before a launch still restores only once', () async {
    // Two colour changes without an intervening launch — the second swap
    // supersedes the first, and the reader still comes back once.
    await markAndroidIconSwapPending();
    await markAndroidIconSwapPending();
    expect(await consumeAndroidIconSwapPending(), isTrue);
    expect(await consumeAndroidIconSwapPending(), isFalse);
  });
}
