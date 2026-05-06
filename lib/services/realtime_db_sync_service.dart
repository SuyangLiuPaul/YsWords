import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/cloud_sync_service.dart' show CloudSyncStatus;
import 'package:yswords/services/profile_service.dart';

/// Replaces Drive sync (and the older Firestore-based CloudSyncService)
/// with Firebase Realtime Database. Why this is the right call for
/// YsWords:
///
///   • **No extra OAuth scope** — sign-in only needs `email + profile`.
///     Other users see a normal Google sign-in dialog, not the scary
///     "this app wants to manage files in your Drive" one.
///   • **Different transport from Firestore** — Realtime DB uses
///     WebSocket; the previous Firestore-based service used WebChannel
///     which gets blocked on some networks / browser extensions.
///   • **No Cloud Console scope verification** required for >100 users.
///     Drive's `drive.file` is a sensitive scope; Realtime DB needs
///     nothing beyond Firebase Auth.
///
/// Storage layout (one path per user):
///   `users/{uid}/sync = { data: {...}, updatedAt: ISO-8601 string }`
///
/// The `data` map shape is identical to the previous Drive /
/// Firestore versions — same scoped key set (`highlights`,
/// `verseNotes`, `bookmarks`, `plan.*`, `plan.completed.*`) — so the
/// merge logic carries over byte-for-byte and switching back to
/// Drive (if we ever want it as an opt-in for power users) just
/// means swapping the I/O layer.
///
/// Public API mirrors the previous services so call sites stay
/// identical: `requestUpload`, `syncNow`, `status`, `lastError`,
/// `lastSyncedAt`. Status enum is reused from CloudSyncService.
class RealtimeDbSyncService extends ChangeNotifier {
  static final RealtimeDbSyncService instance = RealtimeDbSyncService._();
  RealtimeDbSyncService._();

  CloudSyncStatus _status = CloudSyncStatus.disabled;
  String? _lastError;
  StreamSubscription<DatabaseEvent>? _docSub;
  String? _subscribedUid;
  bool _suppressLocalListener = false;
  bool _initialized = false;
  DateTime? _lastSyncedAt;
  bool _firstPullAfterSignIn = true;
  Timer? _debounce;

  static const String _kLastSyncedAt = 'rtdbSync.lastSyncedAt';

  CloudSyncStatus get status => _status;
  String? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  // The keys this service syncs. Same set as the previous services so
  // the upload / merge logic is identical — the only thing that
  // changes is the I/O layer (Firestore doc → Drive file → RTDB path).
  static const _stringKeys = <String>[
    'highlights',
    'verseNotes',
    'plan.activeId',
  ];
  static const _stringListKeys = <String>['bookmarks'];
  static const _intKeys = <String>['plan.startMs'];
  static const _boolKeys = <String>['plan.useDate'];

  /// Wire up auth + profile listeners. Call once at app startup
  /// after CloudAuthService.init() — same pattern as the previous
  /// services. Idempotent on repeat calls.
  void init() {
    if (_initialized) return;
    _initialized = true;
    // ignore: unawaited_futures
    _restoreLastSyncedAt();
    CloudAuthService.instance.addListener(_onAuthChanged);
    ProfileService.instance.addListener(_onProfileChanged);
    _onAuthChanged();
  }

  Future<void> _restoreLastSyncedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLastSyncedAt);
      if (raw == null || raw.isEmpty) return;
      _lastSyncedAt = DateTime.tryParse(raw);
      notifyListeners();
    } catch (_) {/* corrupt prefs — non-fatal */}
  }

  Future<void> _stampSyncedNow() async {
    _lastSyncedAt = DateTime.now().toUtc();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastSyncedAt, _lastSyncedAt!.toIso8601String());
    } catch (_) {}
    notifyListeners();
  }

  void _setStatus(CloudSyncStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  Future<void> _onAuthChanged() async {
    final auth = CloudAuthService.instance;
    if (!auth.isConfigured || !auth.isSignedIn) {
      _setStatus(CloudSyncStatus.disabled);
      _docSub?.cancel();
      _docSub = null;
      _subscribedUid = null;
      return;
    }
    final user = auth.currentUser;
    if (user == null) {
      _setStatus(CloudSyncStatus.disabled);
      return;
    }
    final uid = user.uid;
    // Dedupe re-fires for the same user — Firebase Auth's
    // userChanges() stream emits on every silent token refresh.
    // Without this, every refresh tore down + rebuilt the listener.
    if (_subscribedUid == uid && _docSub != null) return;
    _firstPullAfterSignIn = true;
    _setStatus(CloudSyncStatus.syncing);
    try {
      _docSub?.cancel();
      _subscribedUid = uid;
      // Subscribe to realtime updates at users/{uid}/sync. First
      // emission is the initial pull; subsequent emissions reflect
      // changes pushed from another device.
      _docSub = FirebaseDatabase.instance
          .ref('users/$uid/sync')
          .onValue
          .listen(_onRemoteSnapshot, onError: (Object e) {
        _lastError = e.toString();
        _setStatus(CloudSyncStatus.error);
        // ignore: avoid_print
        print('[RTDBSync] subscription error: $e');
      });
    } catch (e) {
      _lastError = e.toString();
      _setStatus(CloudSyncStatus.error);
    }
  }

  Future<void> _onProfileChanged() async {
    if (CloudAuthService.instance.isSignedIn) {
      _firstPullAfterSignIn = true;
      await _onAuthChanged();
    }
  }

  /// Apply a remote snapshot to local prefs.
  /// Three paths — same shape as the previous services:
  ///   1. Cloud has no data       → upload local as the seed.
  ///   2. First pull AFTER sign-in AND local has data → merge,
  ///      then push the merged result back so cloud catches up.
  ///   3. Subsequent real-time pulls → write remote into local
  ///      verbatim (otherwise deletes from another device would
  ///      never propagate here).
  Future<void> _onRemoteSnapshot(DatabaseEvent event) async {
    try {
      final raw = event.snapshot.value;
      if (raw == null) {
        // No cloud data yet — promote local to cloud as the seed.
        _firstPullAfterSignIn = false;
        await _uploadFromLocal();
        return;
      }
      // RTDB returns deeply-nested LinkedHashMap<dynamic, dynamic>
      // when the JSON value is an object. Convert to String-keyed
      // map and pull out the `data` field where we keep the actual
      // sync state (versus the metadata `updatedAt`).
      if (raw is! Map) {
        // Unexpected shape (someone wrote a non-object?). Treat as
        // no-data and let the upload path overwrite it.
        _firstPullAfterSignIn = false;
        await _uploadFromLocal();
        return;
      }
      final outer = Map<String, dynamic>.from(raw);
      final dataNode = outer['data'];
      if (dataNode is! Map) {
        _firstPullAfterSignIn = false;
        await _uploadFromLocal();
        return;
      }
      final remote = _coerceMap(dataNode);

      if (_firstPullAfterSignIn) {
        _firstPullAfterSignIn = false;
        final local = await _snapshotLocal();
        if (_localHasUserData(local)) {
          final merged = _mergeSnapshots(local: local, remote: remote);
          await _applyRemoteSuppressed(merged);
          await _uploadFromLocal();
          await _stampSyncedNow();
          _setStatus(CloudSyncStatus.synced);
          return;
        }
      }

      await _applyRemoteSuppressed(remote);
      await _stampSyncedNow();
      _setStatus(CloudSyncStatus.synced);
    } catch (e) {
      _lastError = e.toString();
      _setStatus(CloudSyncStatus.error);
      // ignore: avoid_print
      print('[RTDBSync] remote snapshot processing failed: $e');
    }
  }

  /// Coerce RTDB's `LinkedHashMap` tree into a `Map<String, dynamic>`
  /// with proper Dart types. RTDB hands back nested map / list
  /// values; we only need shallow string-keying for the top level +
  /// best-effort list-element type fixes.
  Map<String, dynamic> _coerceMap(dynamic node) {
    if (node is Map) {
      return node.map((k, v) {
        if (v is List) {
          return MapEntry(k.toString(), v.map((e) => e).toList());
        }
        return MapEntry(k.toString(), v);
      });
    }
    return const {};
  }

  /// Push the current local snapshot up to RTDB. `set` (not
  /// `update`) is used so deletes propagate cleanly — if the user
  /// removes a highlight on Device A, the absence of that key in
  /// the upload signals the deletion to Device B.
  Future<void> _uploadFromLocal() async {
    if (!CloudAuthService.instance.isSignedIn) return;
    final user = CloudAuthService.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    _setStatus(CloudSyncStatus.syncing);
    try {
      final data = await _snapshotLocal();
      final body = {
        'data': data,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await FirebaseDatabase.instance.ref('users/$uid/sync').set(body);
      await _stampSyncedNow();
      _setStatus(CloudSyncStatus.synced);
    } on FirebaseException catch (e) {
      _lastError = '[${e.code}] ${e.message ?? "Sync failed."}';
      _setStatus(CloudSyncStatus.error);
      // ignore: avoid_print
      print('[RTDBSync] upload FirebaseException: ${e.code} :: ${e.message}');
    } catch (e) {
      _lastError = e.toString();
      _setStatus(CloudSyncStatus.error);
      // ignore: avoid_print
      print('[RTDBSync] upload failed: $e');
    }
  }

  /// User-initiated "Sync now". Pushes local snapshot + waits for
  /// the round-trip so the caller (Settings page) can show a clean
  /// "syncing → synced" transition. Returns true on success.
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

  /// Public API for MainProvider / ReadingPlanService — debounced
  /// auto-upload after a local change. 600 ms gives a typical multi-
  /// verse highlight stroke time to coalesce into a single upload.
  void requestUpload() {
    if (!CloudAuthService.instance.isSignedIn) return;
    if (_suppressLocalListener) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (_suppressLocalListener) return;
      _uploadFromLocal();
    });
  }

  // ── Local snapshot helpers (parity with the previous services) ───

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

  Map<String, dynamic> _mergeSnapshots({
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
  }) {
    final out = <String, dynamic>{};
    final lbm = ((local['bookmarks'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final rbm = ((remote['bookmarks'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    if (lbm.isNotEmpty || rbm.isNotEmpty) {
      out['bookmarks'] = <String>{...lbm, ...rbm}.toList();
    }
    for (final k in const ['highlights', 'verseNotes']) {
      final lm = _parseJsonMap(local[k]);
      final rm = _parseJsonMap(remote[k]);
      if (lm.isEmpty && rm.isEmpty) continue;
      // Local wins on per-verse key conflict — the user just
      // edited the local copy seconds ago.
      final merged = {...rm, ...lm};
      out[k] = jsonEncode(merged);
    }
    for (final k in const ['plan.activeId', 'plan.startMs', 'plan.useDate']) {
      if (local.containsKey(k)) {
        out[k] = local[k];
      } else if (remote.containsKey(k)) {
        out[k] = remote[k];
      }
    }
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

  Map<String, dynamic> _parseJsonMap(dynamic raw) {
    if (raw == null) return const {};
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      if (raw.isEmpty) return const {};
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return const {};
  }

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
    ProfileService.instance.notifyListeners();
  }

  Future<void> _applyRemoteSuppressed(Map<String, dynamic> remote) async {
    _suppressLocalListener = true;
    try {
      await _writeRemoteIntoLocal(remote);
    } finally {
      _suppressLocalListener = false;
    }
  }

  /// Debug helper — JSON dump of the current local snapshot.
  Future<String> dumpLocal() async => jsonEncode(await _snapshotLocal());
}
