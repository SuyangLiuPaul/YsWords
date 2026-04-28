import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/profile_service.dart';

/// Status surface for the Settings UI — lets the user see "Synced",
/// "Syncing...", or an error message at a glance.
enum CloudSyncStatus {
  /// Cloud sync isn't configured (no Firebase project) or the user
  /// isn't signed in. Local-only.
  disabled,

  /// Authenticated and idle — last upload + download both succeeded.
  synced,

  /// Currently uploading or downloading.
  syncing,

  /// Last sync attempt failed. [CloudSyncService.lastError] has the
  /// friendly message.
  error,
}

/// Mirrors profile-scoped local data to Firestore whenever the user
/// is authenticated. Bidirectional:
///   • on sign-in or remote change → pull cloud snapshot into local prefs
///   • on local change → push the affected key to Firestore
///
/// Conflict policy: last write wins, per top-level key. For personal
/// Bible study this is almost never a real conflict — the user only
/// edits one device at a time.
///
/// Storage layout in Firestore:
///   users/{uid}/profileData/main      — single document holding all
///                                       scoped keys for the active
///                                       cloud profile.
///
/// Why a single doc? Each highlight / bookmark change rewrites a
/// stringified JSON map, which is small (<10 KB even for power
/// users) and stays well under Firestore's 1 MB document cap. Keeps
/// the sync model simple and the read/write count low.
class CloudSyncService extends ChangeNotifier {
  static final CloudSyncService instance = CloudSyncService._();
  CloudSyncService._();

  CloudSyncStatus _status = CloudSyncStatus.disabled;
  String? _lastError;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;
  bool _suppressLocalListener = false;
  bool _initialized = false;
  DateTime? _lastSyncedAt;

  /// SharedPreferences key holding the ISO timestamp of the last
  /// successful sync (push or pull). Survives reload so the user
  /// sees "Synced 3 minutes ago" right after opening the app.
  static const String _kLastSyncedAt = 'cloudSync.lastSyncedAt';

  CloudSyncStatus get status => _status;
  String? get lastError => _lastError;

  /// Most recent successful sync, or null if the user hasn't yet
  /// completed one on this device. Used by the Settings UI to render
  /// "Synced N minutes ago".
  DateTime? get lastSyncedAt => _lastSyncedAt;

  // The keys this service syncs. Names match the unscoped base
  // names used in MainProvider / ReadingPlanService — the actual
  // SharedPreferences key lives at `profile.<id>.<base>` and is
  // built via ProfileService.scopedKey() at access time.
  static const _stringKeys = <String>[
    'highlights',
    'verseNotes',
    'plan.activeId',
  ];
  static const _stringListKeys = <String>[
    'bookmarks',
  ];
  static const _intKeys = <String>[
    'plan.startMs',
  ];
  static const _boolKeys = <String>[
    'plan.useDate',
  ];
  // plan.completed.* keys have a variable suffix per plan id, so
  // we collect them dynamically when uploading.

  /// Wire up auth + profile listeners. Call once at startup, after
  /// CloudAuthService.init().
  void init() {
    if (_initialized) return;
    _initialized = true;
    // Restore lastSyncedAt from prefs so the UI shows a real
    // timestamp on app launch instead of "never synced".
    // ignore: unawaited_futures
    _restoreLastSyncedAt();
    CloudAuthService.instance.addListener(_onAuthChanged);
    ProfileService.instance.addListener(_onProfileChanged);
    // Listen for local user-data changes (the set of keys above).
    // Both ChangeNotifiers fire after a write, but they don't tell
    // us *which* key changed — so on every fire we re-upload the
    // whole document. That's fine: it's a single small write to a
    // single doc.
    _onAuthChanged();
  }

  Future<void> _restoreLastSyncedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLastSyncedAt);
      if (raw == null || raw.isEmpty) return;
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return;
      _lastSyncedAt = parsed;
      notifyListeners();
    } catch (_) {
      // Corrupt prefs — non-fatal.
    }
  }

  Future<void> _stampSyncedNow() async {
    _lastSyncedAt = DateTime.now().toUtc();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastSyncedAt, _lastSyncedAt!.toIso8601String());
    } catch (_) {
      // Best-effort; in-memory copy is still updated.
    }
    notifyListeners();
  }

  /// Local prefs writer — wraps [SharedPreferences] writes from a
  /// remote pull and fires [_pushDocChanged] manually so the global
  /// listeners attached by callers (MainProvider etc.) don't bounce
  /// the same change back to Firestore.
  Future<void> _onAuthChanged() async {
    final auth = CloudAuthService.instance;
    if (!auth.isConfigured || !auth.isSignedIn) {
      _setStatus(CloudSyncStatus.disabled);
      _docSub?.cancel();
      _docSub = null;
      return;
    }
    final uid = auth.currentUser!.uid;
    _setStatus(CloudSyncStatus.syncing);
    try {
      // Subscribe to remote doc; first emission is the pull.
      _docSub?.cancel();
      _docSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profileData')
          .doc('main')
          .snapshots()
          .listen(_onRemoteSnapshot, onError: (e) {
        _lastError = e.toString();
        _setStatus(CloudSyncStatus.error);
      });
    } catch (e) {
      _lastError = e.toString();
      _setStatus(CloudSyncStatus.error);
    }
  }

  Future<void> _onProfileChanged() async {
    // Switching local profiles needs a re-sync: the new profile's
    // local data is what we should push, and the cloud doc may
    // need a fresh read too. Easiest: re-trigger the auth flow.
    if (CloudAuthService.instance.isSignedIn) {
      await _onAuthChanged();
    }
  }

  /// Apply a remote snapshot to local prefs. Treats a missing/empty
  /// doc as "first device for this user" and immediately uploads
  /// what's currently in local prefs.
  Future<void> _onRemoteSnapshot(
      DocumentSnapshot<Map<String, dynamic>> snap) async {
    try {
      if (!snap.exists || (snap.data()?['data'] == null)) {
        // No cloud data yet — promote local to cloud as the seed.
        await _uploadFromLocal();
        return;
      }
      final data = (snap.data()!['data'] as Map).cast<String, dynamic>();
      _suppressLocalListener = true;
      try {
        await _writeRemoteIntoLocal(data);
      } finally {
        _suppressLocalListener = false;
      }
      await _stampSyncedNow();
      _setStatus(CloudSyncStatus.synced);
    } catch (e) {
      _lastError = e.toString();
      _setStatus(CloudSyncStatus.error);
    }
  }

  /// Snapshot every tracked key from local prefs into a JSON map
  /// keyed by base-name (without the `profile.<id>.` prefix). The
  /// active local profile is the one whose data gets uploaded —
  /// switching profiles is the user's signal for "swap which set
  /// lives in the cloud".
  Future<Map<String, dynamic>> _snapshotLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, dynamic>{};
    for (final base in _stringKeys) {
      final v = prefs.getString(ProfileService.instance.scopedKey(base));
      if (v != null) out[base] = v;
    }
    for (final base in _stringListKeys) {
      final v =
          prefs.getStringList(ProfileService.instance.scopedKey(base));
      if (v != null) out[base] = v;
    }
    for (final base in _intKeys) {
      final scoped = ProfileService.instance.scopedKey(base);
      if (prefs.containsKey(scoped)) out[base] = prefs.getInt(scoped);
    }
    for (final base in _boolKeys) {
      final scoped = ProfileService.instance.scopedKey(base);
      if (prefs.containsKey(scoped)) out[base] = prefs.getBool(scoped);
    }
    // Walk all plan.completed.* keys for the active profile.
    final scopedPrefix =
        ProfileService.instance.scopedKey('plan.completed.');
    for (final k in prefs.getKeys()) {
      if (k.startsWith(scopedPrefix)) {
        final base = k.substring(
            'profile.${ProfileService.instance.currentId}.'.length);
        out[base] = prefs.getStringList(k);
      }
    }
    return out;
  }

  /// Apply the remote `data` map to local prefs, replacing per-key.
  /// Keys absent from the remote doc are left alone (so a remote
  /// "no notes" state doesn't wipe a verse note the user just made
  /// before the listener fired).
  Future<void> _writeRemoteIntoLocal(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in data.entries) {
      final scoped = ProfileService.instance.scopedKey(entry.key);
      final v = entry.value;
      if (v is String) {
        await prefs.setString(scoped, v);
      } else if (v is bool) {
        await prefs.setBool(scoped, v);
      } else if (v is int) {
        await prefs.setInt(scoped, v);
      } else if (v is List) {
        await prefs.setStringList(
            scoped, v.map((e) => e.toString()).toList());
      } else if (v == null) {
        await prefs.remove(scoped);
      }
    }
    // Notify the rest of the app so MainProvider / ReadingPlanService
    // listeners reload from the freshly-overwritten prefs.
    ProfileService.instance.notifyListeners();
  }

  /// Push the current local snapshot up to Firestore as the source
  /// of truth. Called after sign-in (when remote was empty) and
  /// after every local change via [requestUpload].
  ///
  /// Hard-cap at 15 seconds. Without this the Firestore set() can
  /// hang indefinitely on slow networks and the UI was reporting
  /// "Syncing now…" forever.
  Future<void> _uploadFromLocal() async {
    final auth = CloudAuthService.instance;
    if (!auth.isSignedIn) return;
    if (_suppressLocalListener) {
      // A remote pull is in flight. Don't push on top of it (would
      // overwrite the data we just received). The auto-debounce
      // path is fine to no-op silently — but a user-initiated
      // syncNow() should NOT look like a hang. Wait briefly for
      // the pull to finish, then proceed.
      for (var i = 0; i < 30 && _suppressLocalListener; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_suppressLocalListener) {
        _lastError = 'A pull is taking longer than expected. '
            'Try Sync now again in a moment.';
        _setStatus(CloudSyncStatus.error);
        return;
      }
    }
    _setStatus(CloudSyncStatus.syncing);
    try {
      final data = await _snapshotLocal();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('profileData')
          .doc('main')
          .set({
        'data': data,
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15));
      await _stampSyncedNow();
      _setStatus(CloudSyncStatus.synced);
    } on TimeoutException {
      _lastError = 'Sync timed out after 15 seconds. '
          'Check your internet connection.';
      _setStatus(CloudSyncStatus.error);
    } catch (e) {
      _lastError = e.toString();
      _setStatus(CloudSyncStatus.error);
    }
  }

  /// User-initiated "Sync now". Pushes the current local snapshot to
  /// Firestore and waits for the round-trip so the caller (Settings
  /// page) can show a clean "syncing" → "synced" transition. Returns
  /// true on success, false on any failure (status will reflect it).
  ///
  /// Cancels the auto-debounce so we don't double-push.
  Future<bool> syncNow() async {
    final auth = CloudAuthService.instance;
    if (!auth.isConfigured) {
      _lastError = 'Cloud sync not configured.';
      _setStatus(CloudSyncStatus.error);
      return false;
    }
    if (!auth.isSignedIn) {
      _lastError = 'Not signed in.';
      _setStatus(CloudSyncStatus.error);
      return false;
    }
    _debounce?.cancel();
    await _uploadFromLocal();
    return _status == CloudSyncStatus.synced;
  }

  /// Public API — MainProvider and ReadingPlanService call this
  /// after they persist a change locally. Debounced because a typical
  /// user action (e.g. selecting a multi-verse highlight color)
  /// fires several writes in quick succession; one combined upload
  /// is enough.
  Timer? _debounce;
  void requestUpload() {
    if (!CloudAuthService.instance.isSignedIn) return;
    if (_suppressLocalListener) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _uploadFromLocal);
  }

  void _setStatus(CloudSyncStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  /// JSON debug helper — dumps current local snapshot as a string.
  /// Useful for "Why isn't sync picking up X?" investigations.
  Future<String> dumpLocal() async => jsonEncode(await _snapshotLocal());
}
