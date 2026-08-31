import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/services/profile_service.dart' show ProfileService;

/// Persistent (SharedPreferences, NOT sessionStorage) one-shot guard.
/// Unlike the boot-recovery latch in clear_cache_helper_web.dart, this
/// must never re-run on an origin — healthy or not — once it has made
/// its one decision, even across many separate tab sessions.
const String kLegacyReadingPositionQuarantineFlag =
    'yswords.legacyReadingPositionQuarantined';

const String _kProfileList = 'profile.list';

/// 2026-08-31: mitigation for the boot trap in the queue — an origin
/// whose *only* stored state is the unscoped `book` / `chapter` /
/// `version` reading-position keys (primary pane, no `profile.*` keys
/// at all) throws on every single boot and never recovers, because
/// the throw happens before ProfileService.init() gets a chance to
/// write anything, so the same trap shape is still there on the next
/// load. The one thing actually verified to get an origin out of this
/// is clearing those three keys by hand; this reproduces that
/// automatically the first time the splash's own auto-recovery has
/// decided the boot has genuinely failed (see loading_page.dart),
/// and — unlike the manual fix — keeps the reading position instead
/// of discarding it, by moving it under the guest profile namespace.
/// `MainProvider.restoreState` has a matching fallback tier that reads
/// it back from there.
///
/// Deliberately inert on a healthy origin: it only touches state when
/// `profile.list` is absent AND at least one of the three legacy keys
/// is present. That shape cannot occur once ProfileService.init() has
/// ever completed a single time, because init() unconditionally seeds
/// `profile.list` on its very first run — so no origin that has ever
/// booted successfully can match it.
///
/// Deliberately does NOT touch `profile.legacyMigrated` — that flag
/// belongs to `ProfileService._migrateLegacyIfNeeded` (a *different*
/// migration, of `highlights` / `verseNotes` / `bookmarks` / `plan.*`).
/// An earlier version of this helper set it as a "we've already done
/// the legacy migration" gesture, which actually made
/// `_migrateLegacyIfNeeded` skip itself on the very next boot —
/// permanently orphaning any of that other pre-profile data a trapped
/// origin happened to also be carrying.
Future<void> quarantineLegacyReadingPositionIfTrapped(
    SharedPreferences prefs) async {
  if (prefs.getBool(kLegacyReadingPositionQuarantineFlag) == true) return;

  if (prefs.containsKey(_kProfileList)) {
    // Not the trap shape. Record the decision so a healthy origin that
    // happens to hit a genuinely-failed boot for an unrelated reason
    // (a network blip) never re-runs this check on a future failure —
    // but there is nothing to migrate or retry, so it's safe to mark
    // done immediately.
    await prefs.setBool(kLegacyReadingPositionQuarantineFlag, true);
    return;
  }

  final book = prefs.getString('book');
  final chapter = prefs.getInt('chapter');
  final version = prefs.getString('version');
  if (book == null && chapter == null && version == null) {
    await prefs.setBool(kLegacyReadingPositionQuarantineFlag, true);
    return;
  }

  final guestId = ProfileService.guestId;
  // Don't clobber a real guest-profile value that (in theory) already
  // exists at the scoped key — mirrors the same guard
  // ProfileService._migrateLegacyIfNeeded uses for its own keys.
  if (book != null && prefs.getString('profile.$guestId.book') == null) {
    await prefs.setString('profile.$guestId.book', book);
  }
  if (chapter != null &&
      prefs.getInt('profile.$guestId.chapter') == null) {
    await prefs.setInt('profile.$guestId.chapter', chapter);
  }
  if (version != null &&
      prefs.getString('profile.$guestId.version') == null) {
    await prefs.setString('profile.$guestId.version', version);
  }
  await prefs.remove('book');
  await prefs.remove('chapter');
  await prefs.remove('version');
  // Only recorded once the trap shape has actually been broken — if
  // anything above throws first, the flag stays unset, so the next
  // genuinely-failed boot gets another attempt instead of being
  // permanently locked out of the one mitigation that exists.
  await prefs.setBool(kLegacyReadingPositionQuarantineFlag, true);
}
