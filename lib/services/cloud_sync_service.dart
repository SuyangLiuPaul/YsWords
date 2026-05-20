import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/profile_service.dart';
// 2026-05-20 (v1.2.67): isOnline lookup moved behind a
// conditional-export helper so this file compiles on iOS /
// Android. The web stub reads `navigator.onLine`; the native
// stub returns `true` (no real connectivity detection on
// native without adding `connectivity_plus`).
import 'package:yswords/utils/navigator_online_helper.dart'
    as netcheck;

bool get _isWebOnline {
  try {
    return netcheck.isOnline;
  } catch (_) {
    return true; // older browsers / unsupported runtimes — assume online
  }
}

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
  /// UID we currently have a Firestore subscription for. Used to
  /// dedupe `_onAuthChanged` calls — `CloudAuthService` fires
  /// `notifyListeners` on every Firebase `userChanges()` event,
  /// which includes silent token refreshes triggered by Firestore
  /// writes themselves. Without this guard each refresh tore down
  /// + rebuilt the subscription, re-armed the merge flag, and
  /// flashed `setStatus(syncing)`, producing the rapid-flash loop
  /// the user reported during "Sync now".
  String? _subscribedUid;
  bool _suppressLocalListener = false;
  bool _initialized = false;
  DateTime? _lastSyncedAt;

  /// True for the very first remote snapshot after sign-in. Used to
  /// switch _onRemoteSnapshot from "overwrite local" to "merge local
  /// + remote" so a user who built up bookmarks/highlights/notes
  /// locally and only later signs in doesn't lose any of it.
  /// Reset to true on every sign-in / profile switch.
  bool _firstPullAfterSignIn = true;

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
      _subscribedUid = null;
      return;
    }
    // Read currentUser once into a local + null-check, instead of
    // force-unwrapping. The cached _user inside CloudAuthService
    // can race with userChanges() events firing on background
    // token refreshes; pre-fix we were throwing 'Null check
    // operator used on a null value' from this exact line.
    final user = auth.currentUser;
    if (user == null) {
      _setStatus(CloudSyncStatus.disabled);
      return;
    }
    final uid = user.uid;
    // Dedupe re-fires for the same user. CloudAuthService notifies on
    // every userChanges() event from FirebaseAuth — that includes
    // silent token refreshes triggered by every Firestore write.
    // Re-subscribing on each one was making the merge guard rearm,
    // pushing setStatus(syncing) repeatedly and creating a visible
    // flash whenever the user did anything that wrote to Firestore.
    if (_subscribedUid == uid && _docSub != null) {
      return;
    }
    // Re-arm the merge guard so the next remote snapshot we receive
    // is treated as a "first pull" — and merges instead of overwrites.
    _firstPullAfterSignIn = true;
    _setStatus(CloudSyncStatus.syncing);
    try {
      // Subscribe to remote doc; first emission is the pull.
      _docSub?.cancel();
      _subscribedUid = uid;
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

  /// Apply a remote snapshot to local prefs.
  ///
  /// Three paths:
  ///   1. No cloud data yet → upload local as the seed.
  ///   2. First pull AFTER sign-in AND local has data → MERGE local
  ///      with remote (don't lose the user's pre-sign-in highlights
  ///      / notes / bookmarks), then push the merged result back.
  ///   3. Subsequent real-time pulls → write remote into local
  ///      verbatim (otherwise deletes from another device would never
  ///      propagate).
  Future<void> _onRemoteSnapshot(
      DocumentSnapshot<Map<String, dynamic>> snap) async {
    try {
      if (!snap.exists || (snap.data()?['data'] == null)) {
        // No cloud data yet — promote local to cloud as the seed.
        _firstPullAfterSignIn = false;
        await _uploadFromLocal();
        return;
      }
      final remote = (snap.data()!['data'] as Map).cast<String, dynamic>();

      if (_firstPullAfterSignIn) {
        _firstPullAfterSignIn = false;
        final local = await _snapshotLocal();
        if (_localHasUserData(local)) {
          // Both sides have data → merge instead of overwrite.
          final merged = _mergeSnapshots(local: local, remote: remote);
          await _applyRemoteSuppressed(merged);
          // Push the merged result back so cloud has it too.
          await _uploadFromLocal();
          await _stampSyncedNow();
          _setStatus(CloudSyncStatus.synced);
          return;
        }
        // Local has nothing → standard overwrite path below.
      }

      await _applyRemoteSuppressed(remote);
      await _stampSyncedNow();
      _setStatus(CloudSyncStatus.synced);
    } catch (e) {
      _lastError = e.toString();
      _setStatus(CloudSyncStatus.error);
    }
  }

  /// True if the local snapshot has any user-edited data we'd be
  /// embarrassed to lose. Empty bookmarks list / no highlights /
  /// no notes counts as "no data".
  bool _localHasUserData(Map<String, dynamic> local) {
    final bm = local['bookmarks'];
    if (bm is List && bm.isNotEmpty) return true;
    final hl = local['highlights'];
    if (hl is String && hl.isNotEmpty && hl != '{}') return true;
    final notes = local['verseNotes'];
    if (notes is String && notes.isNotEmpty && notes != '{}') return true;
    if (local.containsKey('plan.activeId')) return true;
    for (final k in local.keys) {
      if (k.startsWith('plan.completed.')) {
        final v = local[k];
        if (v is List && v.isNotEmpty) return true;
      }
    }
    return false;
  }

  /// Merge local and remote snapshots, never losing user data.
  ///
  /// Strategy per key:
  ///   bookmarks                — union of refs (deduped)
  ///   highlights / verseNotes  — JSON object key-merge; LOCAL wins
  ///                              on conflicting verse keys (the
  ///                              user just edited them seconds ago,
  ///                              cloud copy is stale)
  ///   plan.activeId / startMs / useDate
  ///                            — prefer LOCAL when set, else remote
  ///                              (a fresh pick on this device should
  ///                              not be reverted by a stale cloud
  ///                              value)
  ///   `plan.completed.<planId>`  — union of day indices
  Map<String, dynamic> _mergeSnapshots({
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
  }) {
    final out = <String, dynamic>{};

    // bookmarks: union
    final lbm = ((local['bookmarks'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final rbm = ((remote['bookmarks'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    if (lbm.isNotEmpty || rbm.isNotEmpty) {
      out['bookmarks'] = <String>{...lbm, ...rbm}.toList();
    }

    // highlights / verseNotes: JSON map merge, local wins
    for (final k in const ['highlights', 'verseNotes']) {
      final lm = _parseJsonMap(local[k]);
      final rm = _parseJsonMap(remote[k]);
      if (lm.isEmpty && rm.isEmpty) continue;
      // Spread remote first, then local — Dart map literal semantics
      // means local entries overwrite remote entries on key collision.
      final merged = {...rm, ...lm};
      out[k] = jsonEncode(merged);
    }

    // plan scalars: prefer local when present (fresh pick wins),
    // fall back to remote.
    for (final k in const ['plan.activeId', 'plan.startMs', 'plan.useDate']) {
      if (local.containsKey(k)) {
        out[k] = local[k];
      } else if (remote.containsKey(k)) {
        out[k] = remote[k];
      }
    }

    // plan.completed.<id>: union of day strings.
    final completedKeys = <String>{};
    for (final k in local.keys) {
      if (k.startsWith('plan.completed.')) completedKeys.add(k);
    }
    for (final k in remote.keys) {
      if (k.startsWith('plan.completed.')) completedKeys.add(k);
    }
    for (final k in completedKeys) {
      final ll = ((local[k] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      final rl = ((remote[k] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      final union = <String>{...ll, ...rl}.toList();
      if (union.isNotEmpty) out[k] = union;
    }

    return out;
  }

  /// Tolerant JSON-string → Map parser used by [_mergeSnapshots]
  /// for `highlights` and `verseNotes`, which are stored as
  /// stringified JSON in SharedPreferences.
  Map<String, dynamic> _parseJsonMap(dynamic raw) {
    if (raw == null) return const {};
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      if (raw.isEmpty) return const {};
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Corrupt JSON — treat as empty so a single bad write doesn't
        // wipe the merge.
      }
    }
    return const {};
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

  /// Apply [remote] to local prefs while suppressing the cloud
  /// upload listener so any fire-and-forget save kicked off by the
  /// downstream `ProfileService.notifyListeners` get absorbed.
  ///
  /// Note: the suppress flag is released as soon as the prefs writes
  /// finish. The downstream `requestUpload` debounce timer also
  /// re-checks the flag when it fires (see `requestUpload`), so even
  /// a save that lands just after the flag flips back to false will
  /// no-op if a fresh remote pull is in flight by then.
  Future<void> _applyRemoteSuppressed(Map<String, dynamic> remote) async {
    _suppressLocalListener = true;
    try {
      await _writeRemoteIntoLocal(remote);
    } finally {
      _suppressLocalListener = false;
    }
  }

  /// Push the current local snapshot up to Firestore as the source
  /// of truth. Called after sign-in (when remote was empty) and
  /// after every local change via [requestUpload].
  ///
  /// [bypassSuppress] — true for user-initiated `syncNow()`. The
  /// suppress-flag wait below was bailing out with "A pull is
  /// taking longer than expected" when a snapshot echo was still
  /// being processed from a recent successful upload. For a manual
  /// sync, the user wants the upload to happen regardless of
  /// background snapshot timing — pushing on top of the echo just
  /// re-uploads the data we already have, which is harmless.
  Future<void> _uploadFromLocal({bool bypassSuppress = false}) async {
    final auth = CloudAuthService.instance;
    if (!auth.isSignedIn) return;
    // Pin the user once at upload start. Same race-free pattern as
    // _onAuthChanged — currentUser can flip to null between the
    // isSignedIn check above and the .doc(uid) line below, e.g.
    // when a token refresh fails mid-sync.
    final user = auth.currentUser;
    if (user == null) return;
    final uid = user.uid;
    // Fast-fail when the browser already knows it has no network. The
    // 30 s Firestore timeout is helpful when the connection is just
    // slow — but pointless when the user is plain offline. The local
    // edits are already persisted to SharedPreferences; they'll
    // upload automatically the next time CloudSyncService notices
    // we're back online via the auto-debounce path.
    if (!_isWebOnline) {
      _lastError = 'Offline — sync will resume when your connection is back.';
      _setStatus(CloudSyncStatus.error);
      return;
    }
    if (!bypassSuppress && _suppressLocalListener) {
      // A remote pull is in flight. Don't push on top of it (would
      // overwrite the data we just received). The auto-debounce
      // path is fine to no-op silently — but a user-initiated
      // syncNow() should NOT look like a hang. Wait briefly for
      // the pull to finish, then proceed.
      //
      // Round 56: bumped pull-wait window from 3 s to 6 s (60 ticks
      // × 100 ms) so a slow network has the same headroom as the
      // upload itself before we surface the "pull taking longer"
      // error. The upload timeout is now 2 min — we don't want a
      // user-initiated Sync to fail at the pull-guard stage with a
      // shorter window than the upload would have allowed.
      for (var i = 0; i < 60 && _suppressLocalListener; i++) {
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
      // First attempt: trust Firestore's own token-management. With
      // `webExperimentalAutoDetectLongPolling: true` (see
      // CloudAuthService._doInit) the SDK refreshes tokens correctly
      // on its own under normal conditions.
      //
      // Round 56: bumped from 30 s to 2 min. User-reported case of a
      // sync visibly stalling on a slow corporate VPN; 30 s tripped
      // before the round-trip could finish. Two minutes is a
      // generous upper bound — Firestore writes that haven't gone
      // through by then are almost certainly a real connectivity
      // problem, not just a slow link.
      Future<void> doWrite() => FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('profileData')
              .doc('main')
              .set({
            'data': data,
            'updatedAt': FieldValue.serverTimestamp(),
          }).timeout(const Duration(minutes: 2));

      try {
        await doWrite();
      } on TimeoutException {
        // Round 56 follow-up: a single timeout no longer surfaces
        // straight to the user. Try one recovery cycle first —
        // force-refresh the auth token + re-establish the snapshot
        // subscription — then retry the write once. Many "always
        // times out" cases are caused by a stale ID token after the
        // tab has been backgrounded; one refresh + retry clears
        // them and the user never sees a failure.
        // ignore: avoid_print
        print('[CloudSync] upload timed out — attempting token refresh + retry');
        try {
          await user.getIdToken(true);
        } catch (_) {
          // Token refresh itself can fail (network); fall through to
          // the retry, which will surface a real error if the
          // problem is genuinely the network.
        }
        await doWrite();
      }
      await _stampSyncedNow();
      _setStatus(CloudSyncStatus.synced);
    } on TimeoutException {
      _lastError = 'Sync timed out after 2 minutes (twice). '
          'Your network may be blocking Firestore '
          '(*.firestore.googleapis.com). Try again on a different '
          'connection, sign out and back in, or use Settings → '
          'About → Clear cache.';
      // ignore: avoid_print
      print('[CloudSync] upload still timed out after retry');
      _setStatus(CloudSyncStatus.error);
    } on FirebaseException catch (e) {
      // Surface the Firebase code so security-rule denials etc. are
      // identifiable instead of looking like a generic timeout.
      _lastError = '[${e.code}] ${e.message ?? "Sync failed."}';
      // ignore: avoid_print
      print('[CloudSync] FirebaseException: ${e.code} :: ${e.message}');
      _setStatus(CloudSyncStatus.error);
    } catch (e) {
      _lastError = e.toString();
      // ignore: avoid_print
      print('[CloudSync] upload failed: $e');
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
    // bypassSuppress: a snapshot echo from a previous successful
    // upload may still be in flight. The wait+timeout guard inside
    // _uploadFromLocal would error out before the snapshot finishes
    // processing, which is exactly what users hit when clicking
    // Sync-now twice in a row. Skipping the guard for manual syncs
    // is safe — pushing on top of an echo just re-sends what we
    // already have.
    await _uploadFromLocal(bypassSuppress: true);
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
    // Re-check the suppress flag when the timer FIRES (not just when
    // requestUpload was called). Without this re-check, a save call
    // that arrives just after a remote-pull window opens — but
    // before the suppress flag is set — schedules a debounced upload
    // that fires AFTER the pull has completed, uploading data that's
    // identical to what we just received and triggering a redundant
    // round-trip. That's the syncing/synced flash loop the user saw
    // even after the migration-once guard landed.
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (_suppressLocalListener) return;
      _uploadFromLocal();
    });
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
