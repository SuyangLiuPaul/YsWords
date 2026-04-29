import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One stored profile — id is stable (used as the SharedPreferences
/// namespace); name is the human-friendly label shown in the UI.
///   • [avatarColorArgb] — optional color tile for the initial when
///     no photo is set. Falls back to scheme.primary.
///   • [photoDataUrl] — optional locally-uploaded avatar (JPEG data
///     URL, ~10-30 KB at 256×256). For Google-signed-in users the
///     Google profile photo wins; this acts as a fallback for
///     local users or when the Google photo fails to load.
class Profile {
  final String id;
  final String name;
  final int? avatarColorArgb;
  final String? photoDataUrl;
  const Profile({
    required this.id,
    required this.name,
    this.avatarColorArgb,
    this.photoDataUrl,
  });

  bool get isGuest => id == ProfileService.guestId;
}

/// Local-only "auth" surface: lets the user pick a profile name (or
/// continue as Guest) so notes / bookmarks / highlights / reading-
/// plan progress can be kept separate per-person on a shared device.
///
/// Why no real auth? YsWords ships as a static Flutter web bundle on
/// Netlify with no backend, so there is no server to verify a
/// password against. Profiles here are an organizational tool, not
/// a security boundary — anyone with access to the browser can pick
/// any profile. If we add a backend later, the same profile id can
/// become an account id and the migration is straightforward.
///
/// Storage layout:
///   `profile.current`        → currently active profile id
///   `profile.list`           → comma-separated list of profile ids
///   `profile.name.<id>`      → human-friendly display name
///   `profile.<id>.<key>`     → per-profile data (highlights, notes,
///                              bookmarks, plan.activeId, etc.)
class ProfileService extends ChangeNotifier {
  static const _kCurrent = 'profile.current';
  static const _kList = 'profile.list';
  static const _kNamePrefix = 'profile.name.';
  static const _kAvatarPrefix = 'profile.avatar.';
  static const _kPhotoPrefix = 'profile.photo.';
  static const _kSeenWelcome = 'profile.seenWelcome';

  /// The reserved "guest" profile id. Always exists, can't be
  /// renamed or deleted — it's the default when nobody has signed in.
  static const String guestId = 'guest';

  static final ProfileService instance = ProfileService._();
  ProfileService._();

  String _currentId = guestId;
  List<Profile> _profiles = const [];
  bool _seenWelcome = false;
  bool _initialized = false;

  String get currentId => _currentId;
  Profile get current => _profiles.firstWhere(
        (p) => p.id == _currentId,
        orElse: () => const Profile(id: guestId, name: 'Guest'),
      );
  List<Profile> get profiles => List.unmodifiable(_profiles);

  /// Whether the user has dismissed the welcome / sign-in gate at
  /// least once. The gate stays out of the way after that — the
  /// switcher is still reachable from Settings.
  bool get seenWelcome => _seenWelcome;
  bool get initialized => _initialized;

  /// One-time bootstrap. Reads the current profile id, ensures a
  /// Guest profile exists, and migrates any pre-profile keys
  /// (`highlights`, `verseNotes`, `bookmarks`, `plan.*`) into the
  /// guest namespace so existing users don't lose their data when
  /// this feature ships.
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _currentId = prefs.getString(_kCurrent) ?? guestId;
    _seenWelcome = prefs.getBool(_kSeenWelcome) ?? false;

    final ids = prefs.getStringList(_kList) ?? <String>[];
    if (!ids.contains(guestId)) {
      ids.insert(0, guestId);
      await prefs.setStringList(_kList, ids);
      await prefs.setString('$_kNamePrefix$guestId', 'Guest');
    }
    _profiles = ids
        .map((id) => Profile(
              id: id,
              name: prefs.getString('$_kNamePrefix$id') ??
                  (id == guestId ? 'Guest' : id),
              avatarColorArgb: prefs.getInt('$_kAvatarPrefix$id'),
              photoDataUrl: prefs.getString('$_kPhotoPrefix$id'),
            ))
        .toList();

    await _migrateLegacyIfNeeded(prefs);
    _initialized = true;
  }

  /// Move any unscoped keys from the pre-profile era under the
  /// guest namespace, but only on the very first launch with this
  /// feature — guarded by a one-shot flag so subsequent launches
  /// don't re-overwrite intentionally-cleared profile data.
  Future<void> _migrateLegacyIfNeeded(SharedPreferences prefs) async {
    const migratedFlag = 'profile.legacyMigrated';
    if (prefs.getBool(migratedFlag) == true) return;
    Future<void> moveString(String key) async {
      final v = prefs.getString(key);
      if (v == null) return;
      // Don't clobber an already-set profile-scoped value.
      final scoped = 'profile.$guestId.$key';
      if (prefs.getString(scoped) != null) return;
      await prefs.setString(scoped, v);
    }

    Future<void> moveStringList(String key) async {
      final v = prefs.getStringList(key);
      if (v == null) return;
      final scoped = 'profile.$guestId.$key';
      if (prefs.getStringList(scoped) != null) return;
      await prefs.setStringList(scoped, v);
    }

    Future<void> moveBool(String key) async {
      if (!prefs.containsKey(key)) return;
      final v = prefs.getBool(key);
      if (v == null) return;
      final scoped = 'profile.$guestId.$key';
      if (prefs.getBool(scoped) != null) return;
      await prefs.setBool(scoped, v);
    }

    Future<void> moveInt(String key) async {
      if (!prefs.containsKey(key)) return;
      final v = prefs.getInt(key);
      if (v == null) return;
      final scoped = 'profile.$guestId.$key';
      if (prefs.getInt(scoped) != null) return;
      await prefs.setInt(scoped, v);
    }

    await moveString('highlights');
    await moveString('verseNotes');
    await moveStringList('bookmarks');
    await moveString('plan.activeId');
    await moveInt('plan.startMs');
    await moveBool('plan.useDate');
    // Migrate plan.completed.<planId> keys.
    for (final k in prefs.getKeys()) {
      if (k.startsWith('plan.completed.')) {
        final list = prefs.getStringList(k);
        if (list == null) continue;
        final scoped = 'profile.$guestId.$k';
        if (prefs.getStringList(scoped) == null) {
          await prefs.setStringList(scoped, list);
        }
      }
    }

    await prefs.setBool(migratedFlag, true);
  }

  /// Returns the SharedPreferences key for [base] under the current
  /// profile. All user-data persistence in MainProvider /
  /// ReadingPlanService routes through this so switching profiles
  /// flips the entire dataset atomically.
  String scopedKey(String base) => 'profile.$_currentId.$base';

  /// Switch the active profile. Notifies listeners so UIs that watch
  /// profile-scoped data (e.g. MainProvider, today-reading card,
  /// library plan tab) can reload.
  Future<void> setCurrent(String id) async {
    if (_currentId == id) return;
    final prefs = await SharedPreferences.getInstance();
    _currentId = id;
    await prefs.setString(_kCurrent, id);
    notifyListeners();
  }

  /// Create a new named profile. The id is auto-derived from the
  /// name (lowercased, space → '-', non-alphanumerics stripped) and
  /// suffixed with a number if a collision exists.
  Future<Profile> create(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final base = name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
    var id = base.isEmpty ? 'user' : base;
    final ids = prefs.getStringList(_kList) ?? <String>[];
    var n = 2;
    while (ids.contains(id)) {
      id = '$base-$n';
      n++;
    }
    ids.add(id);
    await prefs.setStringList(_kList, ids);
    await prefs.setString('$_kNamePrefix$id', name.trim());
    final p = Profile(id: id, name: name.trim());
    _profiles = [..._profiles, p];
    notifyListeners();
    return p;
  }

  /// Delete a profile and all of its scoped data. Cannot delete the
  /// guest profile. If the deleted profile was active, falls back
  /// to guest.
  Future<void> delete(String id) async {
    if (id == guestId) return;
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_kList) ?? <String>[];
    ids.remove(id);
    await prefs.setStringList(_kList, ids);
    await prefs.remove('$_kNamePrefix$id');
    await prefs.remove('$_kAvatarPrefix$id');
    await prefs.remove('$_kPhotoPrefix$id');
    // Wipe scoped data — every key under profile.<id>.*
    final dead = prefs
        .getKeys()
        .where((k) => k.startsWith('profile.$id.'))
        .toList();
    for (final k in dead) {
      await prefs.remove(k);
    }
    _profiles = _profiles.where((p) => p.id != id).toList();
    if (_currentId == id) {
      _currentId = guestId;
      await prefs.setString(_kCurrent, guestId);
    }
    notifyListeners();
  }

  /// Mark the welcome gate as dismissed so it doesn't pop again on
  /// future launches.
  Future<void> markWelcomeSeen() async {
    if (_seenWelcome) return;
    final prefs = await SharedPreferences.getInstance();
    _seenWelcome = true;
    await prefs.setBool(_kSeenWelcome, true);
    notifyListeners();
  }

  /// Rename an existing profile in place. Guest is renamable in case
  /// the user wants to relabel it for a household.
  Future<void> rename(String id, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kNamePrefix$id', newName.trim());
    _profiles = _profiles
        .map((p) => p.id == id
            ? Profile(
                id: id,
                name: newName.trim(),
                avatarColorArgb: p.avatarColorArgb,
                photoDataUrl: p.photoDataUrl,
              )
            : p)
        .toList();
    notifyListeners();
  }

  /// Set (or clear) the profile's preferred avatar color tile.
  /// Used when the user doesn't have a Google profile photo or
  /// wants a custom-color initial.
  Future<void> setAvatarColor(String id, int? argb) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kAvatarPrefix$id';
    if (argb == null) {
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, argb);
    }
    _profiles = _profiles
        .map((p) => p.id == id
            ? Profile(
                id: id,
                name: p.name,
                avatarColorArgb: argb,
                photoDataUrl: p.photoDataUrl,
              )
            : p)
        .toList();
    notifyListeners();
  }

  /// Set (or clear) the profile's locally-uploaded avatar photo.
  /// [dataUrl] should be a base64 JPEG data URL (typically the
  /// 256×256 image returned by `AvatarPickerService.pickAvatar()`,
  /// ~10-30 KB). Stored at `profile.photo.<id>` — local-only, not
  /// synced to Firestore (per-device by design; matches how
  /// avatarColorArgb works).
  Future<void> setAvatarPhoto(String id, String? dataUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kPhotoPrefix$id';
    if (dataUrl == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, dataUrl);
    }
    _profiles = _profiles
        .map((p) => p.id == id
            ? Profile(
                id: id,
                name: p.name,
                avatarColorArgb: p.avatarColorArgb,
                photoDataUrl: dataUrl,
              )
            : p)
        .toList();
    notifyListeners();
  }
}
