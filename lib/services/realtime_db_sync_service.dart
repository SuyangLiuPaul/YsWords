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
/// `verseNotes`, `bookmarks`, etc.) — so the
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
  /// 2026-05-07: small ring-buffer of `updatedAt` ISO strings from
  /// our recent uploads. Plural (not single) because rapid uploads
  /// can stack (T1 upload → echo of T1 still in flight → T2 upload).
  /// We need to recognise echoes of ANY recent write, not just the
  /// most recent. Capped at 8 entries — enough for any realistic
  /// burst, never grows unboundedly.
  final List<String> _ourRecentUploads = [];

  /// 2026-05-07: hash of the data we last uploaded. requestUpload
  /// computes a fresh hash on each call; if it matches, we skip the
  /// upload entirely (no point pushing identical data, especially
  /// when something in the listener cascade is firing requestUpload
  /// repeatedly without actual user edits).
  String? _lastUploadedDataHash;

  static const String _kLastSyncedAt = 'rtdbSync.lastSyncedAt';

  /// 2026-06-11 audit: upper bound for every awaited RTDB operation
  /// (`set` / `get` / `remove`). The Firebase SDK retries forever on a
  /// flaky connection, so an un-timed await could leave the sync
  /// status stuck on "syncing" indefinitely. 20 s is generous for the
  /// few-KB payloads involved; on expiry the existing catch blocks
  /// turn TimeoutException into the error status / null result.
  static const Duration _kRtdbOpTimeout = Duration(seconds: 20);

  CloudSyncStatus get status => _status;
  String? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  // The keys this service syncs. Same set as the previous services so
  // the upload / merge logic is identical — the only thing that
  // changes is the I/O layer (Firestore doc → Drive file → RTDB path).
  static const _stringKeys = <String>[
    'highlights',
    'verseNotes',
    // 2026-05-24 (v1.2.91): per-note optional user title, encoded
    // as a JSON {verseId: title} map. Same merge rules as
    // verseNotes (local wins on per-verse conflict). Older clients
    // ignore the key.
    'verseNoteTitles',
    // 2026-05-24 (v1.2.91): per-note epoch-ms timestamp map,
    // persisted as a JSON {verseId: ms} string (same encoding as
    // verseNotes). Older clients ignore unknown keys gracefully —
    // no migration step required, and any client without sort UI
    // simply re-uploads whatever it had (timestamps survive).
    'verseNoteTimestamps',
    // 2026-05-24 (v1.2.91): per-query epoch-ms timestamp map for
    // the recent-searches list (JSON {query: ms}). Same merge
    // semantics as verseNoteTimestamps — max-of-both per key —
    // ensures the most recent activity wins across devices.
    'recentSearchTimestamps',
    // 2026-05-24 (v1.2.94): Library → Notes sort mode
    // ('canonical' / 'recent' / 'oldest'). The v1.2.91 docstring
    // claimed this synced but it was missing from this list;
    // adding it now so the user's sort preference follows them
    // across devices, matching the documented behaviour.
    'notesSortMode',
    // 'plan.activeId' was here through v1.3.44. Removed 2026-05-25
    // (v1.3.45) — the reading-plan feature was deleted in v1.2.69
    // and the key contains a `.`, which RTDB forbids: "Keys must
    // be non-empty strings and can't contain '.', '#', '$', '/',
    // '[', or ']'." Legacy users with a stale `plan.activeId`
    // value in SharedPreferences (from before v1.2.69) saw EVERY
    // sync write get rejected as a result. Same removal below
    // for plan.startMs (_intKeys) and plan.useDate (_boolKeys),
    // plus the plan.completed.* prefix loop in _mergeSnapshots.
    // 2026-05-25 (v1.3.41): last-read position. JSON blob
    // `{"version": "nasb", "book": "John", "chapter": 3}` so reading
    // on phone resumes on iPad. Conflict resolution: newest
    // `lastReadTimestamp` wins (see _intKeys below + the merge rule
    // in _mergeSnapshots). Stored under the scoped `lastRead` key
    // in SharedPreferences; written/read by MainProvider via the
    // new lastRead helpers.
    'lastRead',
    // 2026-05-25 (v1.3.41): comprehensive user-prefs sync. JSON
    // blob containing AppSettings fields (locale, theme, font
    // family/size, primary color, paragraph mode, etc.). Conflict
    // resolution: newest `userPrefsTimestamp` wins (see _intKeys
    // + merge rule). geminiApiKey is intentionally NOT in this
    // blob — it has its own dedicated sync path
    // (`users/{uid}/account/geminiApiKey`) with bidirectional
    // streaming because it's security-sensitive.
    'userPrefs',
  ];
  static const _stringListKeys = <String>[
    'bookmarks',
    // 2026-05-24 (v1.2.91): user search history. Was local-only
    // for 5 months, which led to "搜索记录不见了" reports when
    // people opened the app on a different device. Now syncs as
    // a deduped union across devices, capped client-side at
    // RecentSearchesService.maxItems on next add/remove.
    'recentSearches',
  ];
  static const _intKeys = <String>[
    // 'plan.startMs' removed in v1.3.45 (see plan.activeId note above).
    // 2026-05-25 (v1.3.41): timestamps that drive newest-wins
    // conflict resolution for the two big JSON blobs above. Each
    // blob's write also stamps its companion timestamp so merge
    // can pick the more recent device's blob.
    'lastReadTimestamp',
    'userPrefsTimestamp',
  ];
  // 'plan.useDate' was here through v1.3.44; removed v1.3.45.
  static const _boolKeys = <String>[];

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
    // v1.3.48: suppress during remote-apply writes. Without this
    // guard, _writeRemoteIntoLocal → ProfileService.notifyListeners
    // → _onProfileChanged reset _firstPullAfterSignIn = true, and
    // the next RTDB echo took the merge+upload path → another echo
    // → infinite Syncing ↔ Synced flicker loop ("发疯了").
    if (_suppressLocalListener) return;
    if (CloudAuthService.instance.isSignedIn) {
      // Only re-subscribe if the profile actually changed (different
      // uid or no subscription). Don't reset _firstPullAfterSignIn —
      // that should only happen on genuine auth transitions, not on
      // data writes within the same profile.
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
      // Echo guard — if the snapshot's `updatedAt` matches ANY
      // timestamp from our recent uploads, this is RTDB echoing one
      // of our own writes back at us. No-op (don't apply, don't
      // re-stamp synced, don't re-fire listeners).
      //
      // Without this guard, every echo triggered a redundant prefs
      // write → ProfileService.notifyListeners → MainProvider
      // rebuild → some listener's data-changed-detection re-fired
      // requestUpload → visible flicker between Syncing and Synced.
      // Use a ring buffer (vs. just the latest timestamp) to handle
      // overlapping uploads where the echo of T1 arrives AFTER we've
      // already stamped T2.
      final remoteUpdatedAt = outer['updatedAt'];
      if (remoteUpdatedAt is String &&
          _ourRecentUploads.contains(remoteUpdatedAt)) {
        // Echo. Just confirm "synced" status (in case it was
        // mid-transition) and bail.
        _setStatus(CloudSyncStatus.synced);
        return;
      }
      final remote = _coerceMap(dataNode);

      if (_firstPullAfterSignIn) {
        _firstPullAfterSignIn = false;
        final local = await _snapshotLocal();
        if (_localHasUserData(local)) {
          final merged = _mergeSnapshots(local: local, remote: remote);
          await _applyRemoteSuppressed(merged);
          await _uploadFromLocal(data: merged);
          // _uploadFromLocal already updated _lastUploadedDataHash.
          await _stampSyncedNow();
          _setStatus(CloudSyncStatus.synced);
          return;
        }
      }

      await _applyRemoteSuppressed(remote);
      // 2026-05-07: mark the just-applied remote snapshot as our
      // "already synced" state. Without this, a subsequent
      // requestUpload (potentially triggered by the apply path's
      // ProfileService.notifyListeners cascade) would compute a
      // local hash differing from what we last uploaded → trigger
      // an unnecessary re-upload of data we literally just received.
      // That wasn't a flicker per se but a wasted round-trip and
      // possible feedback loop with another device.
      _lastUploadedDataHash = jsonEncode(remote);
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
  Future<void> _uploadFromLocal({Map<String, dynamic>? data}) async {
    if (!CloudAuthService.instance.isSignedIn) return;
    final user = CloudAuthService.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final payload = data ?? await _snapshotLocal();
    final stampedAt = DateTime.now().toUtc().toIso8601String();
    // 2026-05-07 race fix: record the timestamp in our recent-uploads
    // ring BEFORE awaiting the network write. RTDB's listener can
    // fire as soon as the server confirms the write — between the
    // await completing and the next statement running, the echo can
    // arrive. If we set _ourRecentUploads AFTER the await, the echo
    // sometimes hits _onRemoteSnapshot before we've registered the
    // timestamp → echo guard misses → apply path runs → visible
    // flicker.
    _ourRecentUploads.add(stampedAt);
    if (_ourRecentUploads.length > 8) {
      _ourRecentUploads.removeAt(0);
    }
    _setStatus(CloudSyncStatus.syncing);
    try {
      // v1.3.45: final-guard sanitiser — strip any key with
      // RTDB-forbidden characters (`.`, `#`, `$`, `/`, `[`, `]`)
      // before upload. The schema lists are already clean, but
      // this catches any future regression at the boundary instead
      // of failing the entire write at Firebase. The original
      // production bug had `plan.activeId` in `_stringKeys` and
      // EVERY sync write got rejected — defence-in-depth here.
      payload.removeWhere((k, _) => _isInvalidRtdbKey(k));
      final body = {
        'data': payload,
        'updatedAt': stampedAt,
      };
      // 2026-06-11 audit: bound every awaited RTDB op. On a flaky
      // network `set()`/`get()` can hang indefinitely — the catch
      // blocks below already map TimeoutException → error status, so
      // the UI recovers instead of spinning on "syncing" forever.
      await FirebaseDatabase.instance
          .ref('users/$uid/sync')
          .set(body)
          .timeout(_kRtdbOpTimeout);
      // Remember the data we successfully uploaded so requestUpload
      // can skip subsequent calls that don't actually change content.
      _lastUploadedDataHash = jsonEncode(payload);
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
  ///
  /// 2026-05-07: when the timer fires, snapshot local data and hash
  /// it. If the hash matches what we last uploaded, **skip the
  /// upload entirely** — no point pushing identical data, and this
  /// is the root fix for the visible "Synced ↔ Syncing" flicker.
  /// The cascade was:
  ///   1. user edit → requestUpload → upload → status syncing/synced
  ///   2. RTDB echo back → _onRemoteSnapshot writes prefs
  ///      (data didn't actually change) → ProfileService notifyListeners
  ///   3. some downstream listener fired requestUpload again
  ///   4. step 2's data wasn't a real change but the hash check now
  ///      catches that and stops the loop here at step 4.
  void requestUpload() {
    if (!CloudAuthService.instance.isSignedIn) return;
    if (_suppressLocalListener) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      if (_suppressLocalListener) return;
      // Hash the current snapshot. If it matches what we just
      // uploaded, no-op — saves a round-trip AND prevents the
      // status flicker for "uploads" that wouldn't have changed
      // anything.
      final data = await _snapshotLocal();
      final hash = jsonEncode(data);
      if (hash == _lastUploadedDataHash) {
        // Nothing actually changed; stay on whatever status we have.
        // ignore: avoid_print
        print('[RTDBSync] requestUpload skipped — data unchanged.');
        return;
      }
      _uploadFromLocal(data: data);
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
    // v1.3.45: plan.activeId / plan.completed.* checks removed —
    // the reading-plan feature is gone (v1.2.69).
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
    for (final k in const ['highlights', 'verseNotes', 'verseNoteTitles']) {
      final lm = _parseJsonMap(local[k]);
      final rm = _parseJsonMap(remote[k]);
      if (lm.isEmpty && rm.isEmpty) continue;
      // Local wins on per-verse key conflict — the user just
      // edited the local copy seconds ago.
      final merged = {...rm, ...lm};
      out[k] = jsonEncode(merged);
    }

    // 2026-05-25 (v1.3.41): merge lastRead + userPrefs as
    // single-blob newest-write-wins. Each blob has a paired
    // *Timestamp int key; whichever side has the newer stamp
    // contributes BOTH the blob and the timestamp. If only one
    // side has the blob, it wins by default (other side never
    // wrote one).
    for (final pair in const [
      ('lastRead', 'lastReadTimestamp'),
      ('userPrefs', 'userPrefsTimestamp'),
    ]) {
      final blobKey = pair.$1;
      final tsKey = pair.$2;
      final lBlob = local[blobKey];
      final rBlob = remote[blobKey];
      final lTs = (local[tsKey] is num) ? (local[tsKey] as num).toInt() : 0;
      final rTs = (remote[tsKey] is num) ? (remote[tsKey] as num).toInt() : 0;
      String? pickedBlob;
      int pickedTs = 0;
      if (lBlob is String && rBlob is String) {
        if (rTs > lTs) {
          pickedBlob = rBlob;
          pickedTs = rTs;
        } else {
          pickedBlob = lBlob;
          pickedTs = lTs;
        }
      } else if (lBlob is String) {
        pickedBlob = lBlob;
        pickedTs = lTs;
      } else if (rBlob is String) {
        pickedBlob = rBlob;
        pickedTs = rTs;
      }
      if (pickedBlob != null) {
        out[blobKey] = pickedBlob;
        if (pickedTs > 0) out[tsKey] = pickedTs;
      }
    }

    // 2026-05-24 (v1.2.91): merge verseNoteTimestamps + the
    // recentSearchTimestamps companion with max-of-both semantics
    // per key, because BOTH local and remote may have edits and
    // the one with the later epoch-ms is the more recent activity.
    // This avoids the "local wins" strategy stomping on a fresher
    // remote edit that happened to land first.
    for (final k in const [
      'verseNoteTimestamps',
      'recentSearchTimestamps',
    ]) {
      final lm = _parseJsonMap(local[k]);
      final rm = _parseJsonMap(remote[k]);
      if (lm.isNotEmpty || rm.isNotEmpty) {
        final merged = <String, int>{};
        for (final id in {...lm.keys, ...rm.keys}) {
          final lv = lm[id];
          final rv = rm[id];
          final li = (lv is num) ? lv.toInt() : 0;
          final ri = (rv is num) ? rv.toInt() : 0;
          final mx = li > ri ? li : ri;
          if (mx > 0) merged[id] = mx;
        }
        if (merged.isNotEmpty) {
          out[k] = jsonEncode(merged);
        }
      }
    }

    // 2026-05-24 (v1.2.91): merge recentSearches as a deduped
    // union, preferring the entries ordered by their corresponding
    // recentSearchTimestamps map (which we just merged above). Case-
    // insensitive dedup mirrors RecentSearchesService.add(). Cap
    // at RecentSearchesService.maxItems so the synced blob doesn't
    // grow unbounded across devices.
    {
      final lr =
          ((local['recentSearches'] as List?) ?? const []).map((e) => e.toString());
      final rr = ((remote['recentSearches'] as List?) ?? const [])
          .map((e) => e.toString());
      if (lr.isNotEmpty || rr.isNotEmpty) {
        final stamps = _parseJsonMap(out['recentSearchTimestamps']);
        final seen = <String>{};
        final union = <String>[];
        // Walk all entries from both sides, dedup case-insensitive,
        // preserve original casing on first encounter.
        for (final q in [...lr, ...rr]) {
          final k = q.toLowerCase();
          if (seen.add(k)) union.add(q);
        }
        // Sort by timestamp desc (newest first). Unknown stamps
        // sort as 0 — they fall to the bottom, which is fine for
        // legacy entries that hadn't been stamped before the sync.
        int stampFor(String q) {
          final v = stamps[q.toLowerCase()];
          return (v is num) ? v.toInt() : 0;
        }
        union.sort((a, b) => stampFor(b).compareTo(stampFor(a)));
        // Hardcoded cap matches RecentSearchesService.maxItems —
        // can't import from there (would create a cycle) but the
        // value rarely changes.
        const cap = 12;
        if (union.length > cap) union.removeRange(cap, union.length);
        if (union.isNotEmpty) out['recentSearches'] = union;
      }
    }
    // v1.3.45: plan.activeId / plan.startMs / plan.useDate merge
    // block + the plan.completed.* prefix loop removed. The
    // reading-plan feature was deleted in v1.2.69 and these dotted
    // keys were silently breaking ALL RTDB sync writes for users
    // whose SharedPreferences still had legacy plan.* values
    // (RTDB rejects keys containing `.`).
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
      } catch (e) {
        // 2026-05-10 (v1.2.20): was silent. If the cloud blob
        // is corrupt the user just saw an empty merge result
        // and no diagnostic. debugPrint surfaces the JSON
        // parse error to dev console without escalating to a
        // user-facing snackbar — corrupt remote payloads are
        // recoverable on the next push, no need to alarm.
        debugPrint('[RTDBSync] _parseJsonMap decode failed: $e');
      }
    }
    return const {};
  }

  // ── BYOK Gemini API key sync (v1.2.17) ──────────────────────────
  //
  // Stored at `users/{uid}/account/geminiApiKey` — separate from
  // the profile-scoped `users/{uid}/sync` blob because the BYOK key
  // is account-level (one Google sign-in = one Gemini key, regardless
  // of which YsWords profile is active).
  //
  // Firebase rules already enforce per-uid isolation, so the key is
  // only visible to the signed-in user themselves. But — fair warning
  // — it does leave the local device when synced. The China build
  // skips Firebase init at boot, so push/pull silently no-op for
  // those users; their key stays SharedPreferences-only forever.

  static const String _kByokKeyPath = 'account/geminiApiKey';

  /// Push the current user's Gemini API key to RTDB. Silently no-ops
  /// when not signed in or Firebase isn't configured (e.g. China
  /// build). Empty key → null write (clears cloud copy).
  Future<void> pushGeminiKey(String key) async {
    final auth = CloudAuthService.instance;
    if (!auth.isConfigured) {
      debugPrint('[RTDBSync] pushGeminiKey: not configured, skip');
      return;
    }
    if (!auth.isSignedIn) {
      debugPrint('[RTDBSync] pushGeminiKey: not signed in, skip');
      return;
    }
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('[RTDBSync] pushGeminiKey: uid null, skip');
      return;
    }
    final trimmed = key.trim();
    debugPrint('[RTDBSync] pushGeminiKey to users/$uid: '
        '${trimmed.isEmpty ? "<empty/clear>" : "${trimmed.substring(0, trimmed.length.clamp(0, 6))}…"}');
    try {
      final ref =
          FirebaseDatabase.instance.ref('users/$uid/$_kByokKeyPath');
      if (trimmed.isEmpty) {
        await ref.remove().timeout(_kRtdbOpTimeout);
        debugPrint('[RTDBSync] pushGeminiKey: removed (clear)');
      } else {
        await ref.set(trimmed).timeout(_kRtdbOpTimeout);
        debugPrint('[RTDBSync] pushGeminiKey: set OK');
      }
    } on FirebaseException catch (e) {
      debugPrint('[RTDBSync] pushGeminiKey FirebaseException: '
          '${e.code} :: ${e.message}');
    } catch (e) {
      debugPrint('[RTDBSync] pushGeminiKey failed: $e');
    }
  }

  /// Pull the current user's Gemini API key from RTDB. Returns:
  ///   • the stored key on hit
  ///   • empty string when the cloud has been explicitly cleared
  ///   • null on miss / not signed in / Firebase not configured /
  ///     network error — caller treats null as "no information,
  ///     keep local".
  Future<String?> pullGeminiKey() async {
    final auth = CloudAuthService.instance;
    if (!auth.isConfigured || !auth.isSignedIn) return null;
    final uid = auth.currentUser?.uid;
    if (uid == null) return null;
    try {
      final snap = await FirebaseDatabase.instance
          .ref('users/$uid/$_kByokKeyPath')
          .get()
          .timeout(_kRtdbOpTimeout);
      if (!snap.exists) return '';
      final v = snap.value;
      return v is String ? v : '';
    } on FirebaseException catch (e) {
      // ignore: avoid_print
      print('[RTDBSync] pullGeminiKey FirebaseException: '
          '${e.code} :: ${e.message}');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('[RTDBSync] pullGeminiKey failed: $e');
      return null;
    }
  }

  /// 2026-05-17 (v1.2.47): real-time listener for the BYOK Gemini
  /// key. Emits the current cloud value on subscribe and every
  /// time the cloud value changes after that:
  ///   • String value → key on cloud
  ///   • '' (empty string) → cloud explicitly cleared
  ///   • Stream completes when the user signs out / Firebase not
  ///     configured (caller resubscribes on next sign-in).
  ///
  /// Returns null instead of a stream when the user is not signed
  /// in or Firebase isn't configured — caller handles that by not
  /// subscribing at all.
  ///
  /// Why this matters: without it, a key pasted on device A only
  /// reaches device B on next boot or sign-in. With it, device B
  /// picks up the change live. Same source-of-truth (RTDB), same
  /// per-uid isolation (Firebase rules), same China-build skip.
  Stream<String?>? watchGeminiKey() {
    final auth = CloudAuthService.instance;
    if (!auth.isConfigured) {
      debugPrint('[RTDBSync] watchGeminiKey: not configured');
      return null;
    }
    if (!auth.isSignedIn) {
      debugPrint('[RTDBSync] watchGeminiKey: not signed in');
      return null;
    }
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('[RTDBSync] watchGeminiKey: uid null');
      return null;
    }
    debugPrint('[RTDBSync] watchGeminiKey: subscribing to users/$uid');
    try {
      final ref =
          FirebaseDatabase.instance.ref('users/$uid/$_kByokKeyPath');
      return ref.onValue.map((event) {
        if (!event.snapshot.exists) {
          debugPrint('[RTDBSync] watchGeminiKey: event with no snapshot (cloud-cleared)');
          return '';
        }
        final v = event.snapshot.value;
        final str = v is String ? v : '';
        debugPrint('[RTDBSync] watchGeminiKey: event with value '
            '${str.isEmpty ? "<empty>" : "${str.substring(0, str.length.clamp(0, 6))}…"}');
        return str;
      }).handleError((e) {
        debugPrint('[RTDBSync] watchGeminiKey stream error: $e');
      });
    } catch (e) {
      debugPrint('[RTDBSync] watchGeminiKey setup failed: $e');
      return null;
    }
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
    // v1.3.45: plan.completed.* prefix collection removed — feature
    // gone, keys forbidden by RTDB (contain `.`).
    // Defensive sanitiser: if any future schema bug puts a key with
    // RTDB-forbidden characters (`.`, `#`, `$`, `/`, `[`, `]`) into
    // the upload payload, drop it here so we never send a doomed
    // write to Firebase. The original v1.3.45 bug let `plan.activeId`
    // through and EVERY sync write got rejected — this guard means
    // a future regression at worst loses one key, not all sync.
    out.removeWhere((k, _) => _isInvalidRtdbKey(k));
    return out;
  }

  /// RTDB rejects keys with `.`, `#`, `$`, `/`, `[`, `]`. Same rule
  /// applies to merged snapshots before upload — so this is also
  /// called from _mergeSnapshots' callers if/when needed.
  static bool _isInvalidRtdbKey(String key) {
    if (key.isEmpty) return true;
    for (final ch in const ['.', '#', '\$', '/', '[', ']']) {
      if (key.contains(ch)) return true;
    }
    return false;
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
      // 2026-05-25 (v1.3.44): when delivering a new `lastRead`
      // blob, mirror the optional sermonId field to the unscoped
      // `sermons_last_read` prefs key the dashboard's
      // _loadResumeSermon helper reads from. Previously this
      // mirror only ran inside MainProvider.restoreState() at
      // app boot, which meant a sermon opened on Device A
      // didn't show up on Device B until Device B was restarted.
      // Doing it here makes the "继续讲道" card appear (or
      // disappear) on the receiving device as soon as RTDB
      // delivers the new blob.
      if (entry.key == 'lastRead' && v is String) {
        try {
          final m = jsonDecode(v) as Map<String, dynamic>;
          final sermonId = m['sermonId'];
          if (sermonId is String && sermonId.isNotEmpty) {
            await prefs.setString('sermons_last_read', sermonId);
          }
        } catch (_) {/* corrupt blob → leave unscoped key alone */}
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

  // ── @visibleForTesting — the conflict-resolution core is pure, so
  // it can be exercised without a Firebase backend. These wrappers
  // exist purely so the test library can reach the private methods.

  /// Newest-wins / union merge of a local + remote snapshot.
  @visibleForTesting
  Map<String, dynamic> mergeSnapshotsForTest({
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
  }) =>
      _mergeSnapshots(local: local, remote: remote);

  /// Whether a local snapshot carries user data worth seeding to cloud.
  @visibleForTesting
  bool localHasUserDataForTest(Map<String, dynamic> local) =>
      _localHasUserData(local);

  /// RTDB-key validity guard — rejects keys containing `.`, `#`, `$`,
  /// `/`, `[`, `]` (the v1.3.45 `plan.activeId` regression class).
  @visibleForTesting
  static bool isInvalidRtdbKeyForTest(String key) => _isInvalidRtdbKey(key);
}
