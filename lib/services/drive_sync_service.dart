import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/cloud_sync_service.dart' show CloudSyncStatus;
import 'package:yswords/services/profile_service.dart';

/// Mirrors the user's profile-scoped local data to **the user's own
/// Google Drive** as a visible `YsWords.json` file at the root of
/// their My Drive. Replaces the previous Firestore path.
///
///   • The user owns the data and can SEE the file in their Drive —
///     they always know what the app is storing on their behalf.
///   • Plain HTTPS to drive.googleapis.com — works on networks that
///     block Firestore's WebChannel transport.
///   • No folder picker: file is created at the root of My Drive on
///     first sync; subsequent reads/writes find it by name.
///
/// Scope: `https://www.googleapis.com/auth/drive.file` is requested
/// at Google sign-in time. This is a **per-file** scope: the app can
/// only see files it created (or files the user opened via a Drive
/// picker UI). It cannot read arbitrary user files. Switched from
/// `drive.appdata` (hidden) to `drive.file` (visible) on 2026-05-06
/// at user request — they wanted "YsWords" visible in their Drive.
///
/// File layout in My Drive:
///   `/YsWords.json` → `{ "data": {...}, "updatedAt": "<iso>" }`
///   The same `data` map shape the previous Firestore document used,
///   so existing merge / conflict logic carries over byte-for-byte.
///
/// Status surface mirrors [CloudSyncService] (the Firestore-era
/// service this replaces). Existing UI code that reads
/// `CloudSyncStatus` keeps working.
class DriveSyncService extends ChangeNotifier {
  static final DriveSyncService instance = DriveSyncService._();
  DriveSyncService._();

  /// File name as it appears in the user's My Drive. Kept simple and
  /// obvious — `YsWords.json` matches the app name so the user knows
  /// what it is at a glance. Lives at the root of My Drive (no
  /// parents in the create call → Drive defaults to root).
  static const String _filename = 'YsWords.json';

  /// Last-known Drive file id, cached in memory so subsequent
  /// upload calls go straight to PATCH instead of re-listing.
  /// Reset on sign-out.
  String? _fileId;

  CloudSyncStatus _status = CloudSyncStatus.disabled;
  String? _lastError;
  bool _initialized = false;
  DateTime? _lastSyncedAt;
  bool _suppressLocalListener = false;
  bool _firstPullAfterSignIn = true;
  String? _subscribedUid;
  Timer? _debounce;

  /// True only when the in-memory access token is missing/expired and
  /// Drive sync needs the user to re-grant. UI surfaces a "Reconnect
  /// Google Drive" button keyed to this flag.
  bool _needsReconnect = false;
  bool get needsReconnect => _needsReconnect;

  static const String _kLastSyncedAt = 'driveSync.lastSyncedAt';

  CloudSyncStatus get status => _status;
  String? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  // Same key set as the previous Firestore service — see
  // CloudSyncService for the rationale on why each is its own type.
  static const _stringKeys = <String>['highlights', 'verseNotes', 'plan.activeId'];
  static const _stringListKeys = <String>['bookmarks'];
  static const _intKeys = <String>['plan.startMs'];
  static const _boolKeys = <String>['plan.useDate'];

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
      _subscribedUid = null;
      _fileId = null;
      _needsReconnect = false;
      return;
    }
    final user = auth.currentUser;
    if (user == null) {
      _setStatus(CloudSyncStatus.disabled);
      return;
    }
    final uid = user.uid;
    if (_subscribedUid == uid) return;
    _subscribedUid = uid;
    _firstPullAfterSignIn = true;
    _fileId = null; // re-discover on next call
    // ignore: unawaited_futures
    _initialPull();
  }

  Future<void> _onProfileChanged() async {
    if (CloudAuthService.instance.isSignedIn) {
      // Active profile changed — re-pull cloud doc into the new
      // profile's scope, then push the merged result.
      _firstPullAfterSignIn = true;
      await _initialPull();
    }
  }

  /// First-pull semantics on sign-in / profile-switch — same shape
  /// as the previous CloudSyncService logic:
  /// 1. Cloud has no data       → upload local as the seed
  /// 2. Local has data + cloud  → merge; don't lose pre-sign-in edits
  /// 3. Cloud has data + empty local → write cloud into local
  Future<void> _initialPull() async {
    if (!_ensureToken()) {
      // 2026-05 fix: silently try a token refresh before giving up.
      // Two cases this handles:
      //   1. User signed in BEFORE the Drive scope was added — their
      //      cached Firebase session has no Drive permission. Silent
      //      refresh re-runs sign-in with the new scope; if Google's
      //      OAuth state still has them logged into the same account,
      //      the popup closes near-instantly without showing UI.
      //   2. Page reloaded — token was in memory only, so _ensureToken
      //      returns false even though the user has previously
      //      consented. Silent refresh re-acquires it.
      // Falls back to the "Reconnect" UI only if even silent fails.
      final ok = await CloudAuthService.instance
          .refreshDriveAccessToken(interactive: false);
      if (!ok) {
        _needsReconnect = true;
        _setStatus(CloudSyncStatus.error);
        _lastError =
            'Reconnect Google Drive to enable cloud sync.';
        return;
      }
    }
    _setStatus(CloudSyncStatus.syncing);
    try {
      final remote = await _fetchRemoteSnapshot();
      if (remote == null) {
        _firstPullAfterSignIn = false;
        await _uploadFromLocal();
        return;
      }
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
    }
  }

  bool _ensureToken() {
    return CloudAuthService.instance.hasDriveAccessToken;
  }

  /// Drive REST: list files in `appDataFolder` matching our filename.
  /// Returns the file id when present, else null.
  Future<String?> _findFileId({String? token}) async {
    final t = token ?? CloudAuthService.instance.driveAccessToken;
    if (t == null) return null;
    // List files visible to this OAuth client (drive.file scope —
    // returns only files the app created, regardless of where they
    // sit in the user's Drive). No `spaces` parameter so we look in
    // My Drive (not appDataFolder, which we no longer use).
    final uri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files'
      '?q=${Uri.encodeQueryComponent("name='$_filename' and trashed=false")}'
      '&fields=files(id,modifiedTime)',
    );
    final r = await http.get(uri, headers: {'Authorization': 'Bearer $t'});
    if (r.statusCode == 401) throw _DriveAuthException();
    if (r.statusCode == 403) {
      // 403 most commonly means "Drive API not enabled in the GCP
      // project" or "OAuth consent screen doesn't include the
      // drive.file scope". Surface a hint so the developer can
      // act, rather than the generic "Drive list failed" string.
      // The Cloud Setup Diagnostic widget on AboutPage runs the
      // same probe and shows a clickable Cloud Console link, but
      // we surface the URL inline here too for users who hit the
      // failure outside that widget.
      final body = r.body.toLowerCase();
      if (body.contains('has not been used') ||
          body.contains('drive.googleapis.com') &&
              body.contains('disabled')) {
        throw "Drive API isn't enabled in the YsWords Cloud project. "
            'Open Settings → About → "Run check" to fix in one click, '
            'or go to '
            'https://console.cloud.google.com/apis/library/drive.googleapis.com?project=ysword';
      }
      throw 'Drive API access denied (403). Likely the OAuth consent '
          "screen is missing the drive.file scope, or your account is "
          'on a Google Workspace that blocks third-party apps. '
          'Server said: ${r.body}';
    }
    if (r.statusCode != 200) {
      throw 'Drive list failed (${r.statusCode}): ${r.body}';
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final files = (j['files'] as List?) ?? const [];
    if (files.isEmpty) return null;
    return (files.first as Map)['id'] as String?;
  }

  /// Read the current sync blob. Returns the inner `data` map, or
  /// null if the file doesn't exist yet.
  Future<Map<String, dynamic>?> _fetchRemoteSnapshot() async {
    return _withTokenRefresh(() async {
      final fileId = _fileId ??= await _findFileId();
      if (fileId == null) return null;
      final t = CloudAuthService.instance.driveAccessToken!;
      final r = await http.get(
        Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
        headers: {'Authorization': 'Bearer $t'},
      );
      if (r.statusCode == 401) throw _DriveAuthException();
      if (r.statusCode == 404) {
        // File deleted on the server side — drop cached id and act
        // like a first sync.
        _fileId = null;
        return null;
      }
      if (r.statusCode != 200) {
        throw 'Drive read failed (${r.statusCode}): ${r.body}';
      }
      final j = jsonDecode(r.body);
      if (j is Map && j['data'] is Map) {
        return Map<String, dynamic>.from(j['data'] as Map);
      }
      return null;
    });
  }

  /// Push the current local snapshot up to Drive. Creates the file
  /// the first time, PATCH-updates thereafter.
  Future<void> _uploadFromLocal() async {
    if (!CloudAuthService.instance.isSignedIn) return;
    if (!_ensureToken()) {
      // Same silent-refresh fallback as _initialPull. Important for
      // the requestUpload path — every local edit (highlight, note,
      // bookmark) calls it, so if the in-memory token expires while
      // the user is reading, we want the next save to silently
      // re-acquire instead of stamping the whole sync as broken.
      final ok = await CloudAuthService.instance
          .refreshDriveAccessToken(interactive: false);
      if (!ok) {
        _needsReconnect = true;
        _setStatus(CloudSyncStatus.error);
        _lastError = 'Reconnect Google Drive to resume sync.';
        return;
      }
    }
    _setStatus(CloudSyncStatus.syncing);
    try {
      final data = await _snapshotLocal();
      final body = jsonEncode({
        'data': data,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
      await _withTokenRefresh(() async {
        final fileId = _fileId ??= await _findFileId();
        if (fileId == null) {
          await _createFile(body);
        } else {
          await _updateFile(fileId, body);
        }
        return true;
      });
      await _stampSyncedNow();
      _setStatus(CloudSyncStatus.synced);
    } catch (e) {
      _lastError = e.toString();
      _setStatus(CloudSyncStatus.error);
    }
  }

  /// Multipart create — first request gets metadata + body in a
  /// single round-trip. No `parents` field so the file lands at the
  /// **root of My Drive** — visible to the user in drive.google.com.
  /// (Drive defaults to root when `parents` is omitted.)
  Future<void> _createFile(String body) async {
    final t = CloudAuthService.instance.driveAccessToken!;
    const boundary = 'yswords_drive_boundary';
    final metadata = jsonEncode({
      'name': _filename,
      // No 'parents' key — file is created at root of My Drive,
      // visible alongside the user's other files. Drive API treats
      // the absence of `parents` as "put in My Drive root".
    });
    final multipart =
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$body\r\n'
        '--$boundary--';
    final r = await http.post(
      Uri.parse(
          'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: multipart,
    );
    if (r.statusCode == 401) throw _DriveAuthException();
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw 'Drive create failed (${r.statusCode}): ${r.body}';
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    _fileId = j['id'] as String?;
  }

  /// PATCH-style update — body replaces the file content; metadata
  /// (name / parents) stays as-is.
  Future<void> _updateFile(String fileId, String body) async {
    final t = CloudAuthService.instance.driveAccessToken!;
    final r = await http.patch(
      Uri.parse(
          'https://www.googleapis.com/upload/drive/v3/files/$fileId?uploadType=media'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: body,
    );
    if (r.statusCode == 401) throw _DriveAuthException();
    if (r.statusCode == 404) {
      // File was deleted between list and patch — recreate.
      _fileId = null;
      await _createFile(body);
      return;
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw 'Drive update failed (${r.statusCode}): ${r.body}';
    }
  }

  /// Wrap a Drive call so that a 401 triggers a silent token refresh
  /// + one retry. After the second 401, surface a "reconnect"
  /// status.
  Future<T> _withTokenRefresh<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on _DriveAuthException {
      final ok = await CloudAuthService.instance
          .refreshDriveAccessToken(interactive: false);
      if (!ok) {
        _needsReconnect = true;
        rethrow;
      }
      _needsReconnect = false;
      return await op();
    }
  }

  // ── Local snapshot helpers (parity with CloudSyncService) ────────

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

  // ── Public API parity with CloudSyncService ──────────────────────

  /// User-initiated "Sync now". Pushes current local snapshot to
  /// Drive, returns true on success.
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

  /// Debounced auto-upload — same pattern as CloudSyncService so
  /// callers in MainProvider / ReadingPlanService just keep working.
  void requestUpload() {
    if (!CloudAuthService.instance.isSignedIn) return;
    if (_suppressLocalListener) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (_suppressLocalListener) return;
      _uploadFromLocal();
    });
  }

  /// User-facing "Reconnect Drive" path — interactive, shows the
  /// consent screen so the user can re-grant the AppData scope if
  /// they previously revoked it.
  Future<bool> reconnect() async {
    final ok = await CloudAuthService.instance
        .refreshDriveAccessToken(interactive: true);
    if (ok) {
      _needsReconnect = false;
      await _initialPull();
    }
    return ok;
  }

  /// Debug helper — JSON dump of the current local snapshot.
  Future<String> dumpLocal() async => jsonEncode(await _snapshotLocal());
}

/// Internal sentinel used by `_withTokenRefresh` to distinguish a
/// 401 (recoverable via silent refresh) from a generic Drive error.
class _DriveAuthException implements Exception {
  const _DriveAuthException();
}
