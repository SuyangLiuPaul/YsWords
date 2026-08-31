import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/utils/legacy_reading_position_quarantine.dart';

/// 2026-08-31: coverage for the boot-trap mitigation described in the
/// queue — an origin whose only stored state is the unscoped `book` /
/// `chapter` / `version` reading-position keys, with no `profile.*`
/// keys at all, throws on every boot and never recovers on its own,
/// because the throw happens before ProfileService.init() gets to
/// write anything. `quarantineLegacyReadingPositionIfTrapped` is the
/// mitigation: it runs from the splash's automatic boot-recovery path
/// (loading_page.dart) right before the hard reload, and moves the
/// trap-shape data out of the way instead of just discarding it.
///
/// A widget/debug-mode test cannot reproduce the crash itself — the
/// queue records that a debug build in this exact stored-state shape
/// boots fine. This tests the quarantine logic in isolation, which is
/// deterministic and doesn't need the crash to reproduce.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('trap shape: unscoped triple present, profile.list absent', () async {
    SharedPreferences.setMockInitialValues({
      'book': 'John',
      'chapter': 3,
      'version': 'kjv',
    });
    final prefs = await SharedPreferences.getInstance();

    await quarantineLegacyReadingPositionIfTrapped(prefs);

    expect(prefs.containsKey('book'), isFalse,
        reason: 'the unscoped triple is exactly what keeps re-triggering '
            'the trap on every boot — it must be gone');
    expect(prefs.containsKey('chapter'), isFalse);
    expect(prefs.containsKey('version'), isFalse);

    expect(prefs.getString('profile.guest.book'), 'John',
        reason: 'the reading position must survive the quarantine, not '
            'just the crash');
    expect(prefs.getInt('profile.guest.chapter'), 3);
    expect(prefs.getString('profile.guest.version'), 'kjv');

    expect(prefs.getBool(kLegacyReadingPositionQuarantineFlag), isTrue);
    expect(prefs.getBool('profile.legacyMigrated'), isNull,
        reason: 'that flag belongs to a DIFFERENT migration '
            "(ProfileService._migrateLegacyIfNeeded, for highlights / "
            'notes / bookmarks / plan progress) — setting it here would '
            'make that migration skip itself on the very next boot and '
            'permanently orphan that data for a trapped origin that '
            'also happened to be carrying it');
  });

  test('does not clobber an already-set guest-scoped value', () async {
    SharedPreferences.setMockInitialValues({
      'book': 'John',
      'chapter': 3,
      'version': 'kjv',
      'profile.guest.book': 'Genesis',
    });
    final prefs = await SharedPreferences.getInstance();

    await quarantineLegacyReadingPositionIfTrapped(prefs);

    expect(prefs.getString('profile.guest.book'), 'Genesis',
        reason: 'a real pre-existing guest-scoped value must win over '
            'the legacy triple being quarantined');
    expect(prefs.getInt('profile.guest.chapter'), 3,
        reason: 'fields that had no pre-existing scoped value still '
            'migrate normally');
  });

  test('one-shot: a second call is a no-op even if the trap shape '
      'reappears', () async {
    SharedPreferences.setMockInitialValues({
      'book': 'John',
      'chapter': 3,
      'version': 'kjv',
    });
    final prefs = await SharedPreferences.getInstance();
    await quarantineLegacyReadingPositionIfTrapped(prefs);

    // Simulate the trap shape somehow reappearing (e.g. a stale sync
    // write) after the one-shot flag is already set.
    await prefs.setString('book', 'Genesis');
    await prefs.setInt('chapter', 1);
    await prefs.remove('profile.list');

    await quarantineLegacyReadingPositionIfTrapped(prefs);

    expect(prefs.getString('book'), 'Genesis',
        reason: 'the persistent flag must prevent a second run, even if '
            'the trap shape reappears — this must never fire twice on '
            'the same origin');
  });

  test('healthy origin (profile.list present) is left untouched', () async {
    SharedPreferences.setMockInitialValues({
      'book': 'John',
      'chapter': 3,
      'version': 'kjv',
      'profile.list': <String>['guest'],
    });
    final prefs = await SharedPreferences.getInstance();

    await quarantineLegacyReadingPositionIfTrapped(prefs);

    expect(prefs.getString('book'), 'John',
        reason: "a healthy origin's unscoped triple must survive "
            'byte-for-byte — this only fires in the trap shape');
    expect(prefs.getInt('chapter'), 3);
    expect(prefs.getString('version'), 'kjv');
    expect(prefs.containsKey('profile.guest.book'), isFalse);
    expect(prefs.getBool('profile.legacyMigrated'), isNull);
  });

  test('a fresh install (no triple, no profile.list) is a no-op', () async {
    final prefs = await SharedPreferences.getInstance();

    await quarantineLegacyReadingPositionIfTrapped(prefs);

    expect(prefs.containsKey('profile.guest.book'), isFalse);
    expect(prefs.getBool('profile.legacyMigrated'), isNull);
    expect(prefs.getBool(kLegacyReadingPositionQuarantineFlag), isTrue,
        reason: 'the one-shot flag is still recorded so this never '
            're-checks a settled origin');
  });
}
