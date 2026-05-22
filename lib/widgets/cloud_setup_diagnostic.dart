import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/api_base.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_database/firebase_database.dart';
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/utils/theme_color_helpers.dart';

/// Resolve a localised uiStrings entry, with a hardcoded English
/// fallback. Avoids null-bang access scattered through the probes.
String _l(String key, String locale, String fallback) =>
    uiStrings[key]?[locale] ?? uiStrings[key]?['en'] ?? fallback;

/// Self-test panel that probes each cloud-side dependency and tells
/// the developer (or curious user) exactly what's working.
///
/// **Critical UX fact this widget teaches**: end users never have to
/// enable any Google Cloud APIs. APIs are enabled at the project
/// level (the YsWords developer's `ysword` project), not per-user.
/// The probes here exist to give the *developer* a one-screen view
/// of "is the cloud setup done?" and direct deep-links to the Cloud
/// Console pages that fix any failure.
///
/// Probes (in order):
/// 1. Firebase Auth init       — checks `CloudAuthService.isConfigured`
/// 2. Signed-in user           — `auth.isSignedIn`
/// 3. Drive OAuth scope grant  — `auth.hasDriveAccessToken`
/// 4. Drive REST reachability  — actually lists files (catches "API
///    not enabled" / "scope not on consent screen" / "user revoked")
/// 5. AI proxy reachability    — pings the Netlify function (covers
///    the "Gemini API not enabled" + "no API key" cases — which both
///    surface as the same 503 from the function)
///
/// Each row shows ✅ / ❌ / ⚠️ plus an "Open Cloud Console" button
/// linking straight to the page that resolves the failure when it's
/// known. Failures aren't fatal — the app continues to work without
/// these (sync goes local-only, AI shows "not available").
class CloudSetupDiagnostic extends StatefulWidget {
  final String locale;
  const CloudSetupDiagnostic({super.key, required this.locale});

  @override
  State<CloudSetupDiagnostic> createState() => _CloudSetupDiagnosticState();
}

class _CloudSetupDiagnosticState extends State<CloudSetupDiagnostic> {
  /// Hard-coded against the Firebase project this build ships with.
  /// Update if the project ever changes.
  static const String _projectId = 'ysword';

  bool _running = false;
  final List<_ProbeResult> _results = [];

  Future<void> _runAll() async {
    setState(() {
      _running = true;
      _results.clear();
    });
    // 2026-05-06: dropped Drive scope + Drive REST probes when sync
    // moved off Drive onto Firebase Realtime Database. Added an RTDB
    // probe that does a 1-byte write/read to verify the database is
    // reachable + writable for the signed-in user.
    final probes = <_ProbeFn>[
      _probeFirebaseAuth,
      _probeSignedIn,
      _probeRealtimeDb,
      _probeAiProxy,
    ];
    for (final p in probes) {
      final r = await p();
      if (!mounted) return;
      setState(() => _results.add(r));
    }
    if (!mounted) return;
    setState(() => _running = false);
  }

  // ── Probes ────────────────────────────────────────────────────

  String get _loc => widget.locale;

  Future<_ProbeResult> _probeFirebaseAuth() async {
    final t = _l('cloudDiagFirebaseAuthTitle', _loc, 'Firebase Auth');
    final auth = CloudAuthService.instance;
    if (!auth.hasFirebaseCredentials) {
      return _ProbeResult.warning(
        title: t,
        message: _l(
            'cloudDiagFirebaseAuthPlaceholder',
            _loc,
            'firebase_options.dart still has placeholder values. '
                'Cloud sync + sign-in are disabled (local-only mode).'),
      );
    }
    if (!auth.isConfigured) {
      return _ProbeResult.fail(
        title: t,
        message: auth.initError ??
            _l('cloudDiagFirebaseAuthFailed', _loc,
                'Firebase init failed. Check console for [CloudAuthService] log.'),
      );
    }
    return _ProbeResult.ok(
        title: t, message: _l('cloudDiagFirebaseAuthOk', _loc, 'Configured.'));
  }

  Future<_ProbeResult> _probeSignedIn() async {
    final t = _l('cloudDiagSignedInTitle', _loc, 'Signed in');
    final auth = CloudAuthService.instance;
    if (!auth.isConfigured) {
      return _ProbeResult.skip(
          title: t,
          message: _l('cloudDiagSignedInSkip', _loc, 'Auth not configured.'));
    }
    if (!auth.isSignedIn) {
      return _ProbeResult.warning(
        title: t,
        message: _l(
            'cloudDiagSignedInWarning',
            _loc,
            'Not signed in. Cloud sync stays disabled until the user '
                'signs in via Settings → Account.'),
      );
    }
    final email = auth.currentUser?.email ??
        _l('cloudDiagUnknownEmail', _loc, '(unknown email)');
    return _ProbeResult.ok(
      title: t,
      message: _l('cloudDiagSignedInOk', _loc, 'as {email}')
          .replaceAll('{email}', email),
    );
  }

  /// Verify Firebase Realtime Database is enabled + the signed-in
  /// user can read & write their own `users/{uid}/sync` path. Does a
  /// 1-byte ping write and reads it back, then leaves the existing
  /// data alone (we write to a sentinel `__diag` field, not the
  /// `data` map RealtimeDbSyncService manages).
  Future<_ProbeResult> _probeRealtimeDb() async {
    final tt = _l('cloudDiagRtdbTitle', _loc, 'Realtime Database');
    final auth = CloudAuthService.instance;
    if (!auth.isSignedIn) {
      return _ProbeResult.skip(
          title: tt,
          message: _l(
              'cloudDiagRtdbSkip', _loc, 'Not signed in.'));
    }
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      return _ProbeResult.skip(
          title: tt,
          message: _l(
              'cloudDiagRtdbSkipNoUid', _loc, 'No uid.'));
    }
    try {
      // 2026-05-07: write to users/$uid/__diag (sibling of /sync),
      // NOT users/$uid/sync/__diag. The previous path was a child of
      // /sync where RealtimeDbSyncService keeps a live listener — its
      // _onRemoteSnapshot fired the moment we wrote the probe value,
      // pulled the snapshot, then overwrote /sync entirely with the
      // local data map (which doesn't contain __diag), wiping our
      // probe before readback. Result: the readback got a different
      // value than what we wrote and we surfaced a confusing "stale
      // listener" warning even though sync was actually fine.
      // Sibling path bypasses the listener entirely.
      final ref = FirebaseDatabase.instance
          .ref('users/$uid/__diag');
      final stamp = DateTime.now().toUtc().toIso8601String();
      await ref.set(stamp).timeout(const Duration(seconds: 8));
      final readback = await ref.get().timeout(const Duration(seconds: 8));
      if (readback.value == stamp) {
        // Show the actual URL we connected to so the developer can
        // double-check it matches what Firebase Console says — a URL
        // / region mismatch is one of the more confusing failure modes
        // and the OK case is a good place to surface it for review.
        final url = FirebaseDatabase.instance.databaseURL ?? '(default)';
        return _ProbeResult.ok(
          title: tt,
          message: _l(
                  'cloudDiagRtdbOkWithUrl',
                  _loc,
                  'Read + write OK at {url}. Sync data lives at '
                      'users/{uid}/sync.')
              .replaceAll('{url}', url)
              .replaceAll('{uid}', uid),
        );
      }
      return _ProbeResult.warning(
        title: tt,
        message: _l(
            'cloudDiagRtdbReadback',
            _loc,
            'Wrote a probe value but readback returned a different '
                'value. Could be a stale listener or rules denying read.'),
      );
    } on FirebaseException catch (e) {
      // Most common failure: Realtime Database not enabled in the
      // Firebase project, or rules deny access.
      final msg = (e.message ?? '').toLowerCase();
      if (e.code == 'permission-denied' ||
          msg.contains('permission_denied')) {
        return _ProbeResult.fail(
          title: tt,
          message: _l(
              'cloudDiagRtdbPermissionDenied',
              _loc,
              'Permission denied. Open Firebase Console → Realtime '
                  'Database → Rules and ensure authenticated users '
                  'can read/write their own users/<uid>/* path.'),
          fixUrl:
              'https://console.firebase.google.com/project/$_projectId/database/$_projectId-default-rtdb/rules',
          fixLabel: _l('cloudDiagRtdbOpenRules', _loc, 'Open RTDB rules'),
        );
      }
      if (e.code == 'database/database-disabled' ||
          msg.contains('not been enabled') ||
          msg.contains('not exist') ||
          msg.contains('database-disabled')) {
        return _ProbeResult.fail(
          title: tt,
          message: _l(
              'cloudDiagRtdbNotEnabled',
              _loc,
              "Realtime Database isn't enabled yet for this project. "
                  'Open Firebase Console and click "Create Database" '
                  'on the Realtime Database tab.'),
          fixUrl:
              'https://console.firebase.google.com/project/$_projectId/database',
          fixLabel: _l(
              'cloudDiagRtdbOpenConsole', _loc, 'Open RTDB console'),
        );
      }
      return _ProbeResult.fail(
        title: tt,
        message: '[${e.code}] ${e.message ?? ""}',
      );
    } on TimeoutException {
      return _ProbeResult.fail(
          title: tt,
          message: _l('cloudDiagTimeout', _loc, 'Timed out after 8s.'));
    } catch (e) {
      return _ProbeResult.fail(title: tt, message: e.toString());
    }
  }

  // Drive-specific probes kept here as private helpers in case we
  // ever re-enable Drive as an opt-in advanced sync path. Not invoked
  // by the default probe list.
  // ignore: unused_element
  Future<_ProbeResult> _probeDriveScope() async {
    final t = _l('cloudDiagDriveScopeTitle', _loc, 'Drive scope');
    final auth = CloudAuthService.instance;
    if (!auth.isSignedIn) {
      return _ProbeResult.skip(
          title: t,
          message: _l('cloudDiagDriveScopeSkip', _loc, 'Not signed in.'));
    }
    if (!auth.hasDriveAccessToken) {
      return _ProbeResult.warning(
        title: t,
        message: _l(
            'cloudDiagDriveScopeWarning',
            _loc,
            'No Drive OAuth access token captured. User may have signed in '
                'before the drive.file scope was added — they need to click '
                'Reconnect Drive in Settings → Account → Sync.'),
      );
    }
    return _ProbeResult.ok(
      title: t,
      message: _l(
          'cloudDiagDriveScopeOk', _loc, 'OAuth access token captured.'),
    );
  }

  // ignore: unused_element
  Future<_ProbeResult> _probeDriveApi() async {
    final tt = _l('cloudDiagDriveApiTitle', _loc, 'Drive REST API');
    final auth = CloudAuthService.instance;
    final t = auth.driveAccessToken;
    if (t == null) {
      return _ProbeResult.skip(
          title: tt,
          message: _l('cloudDiagDriveApiSkip', _loc, 'No access token.'));
    }
    try {
      final r = await http
          .get(
            Uri.parse(
              'https://www.googleapis.com/drive/v3/files'
              '?q=${Uri.encodeQueryComponent("name='YsWords.json'")}'
              '&fields=files(id,name)',
            ),
            headers: {'Authorization': 'Bearer $t'},
          )
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        final files = (j['files'] as List?) ?? const [];
        return _ProbeResult.ok(
          title: tt,
          message: files.isEmpty
              ? _l(
                  'cloudDiagDriveApiOkEmpty',
                  _loc,
                  'API reachable; no YsWords.json yet (will be created on first sync).')
              : _l('cloudDiagDriveApiOkExists', _loc,
                  'API reachable; YsWords.json exists.'),
        );
      }
      if (r.statusCode == 401) {
        return _ProbeResult.warning(
          title: tt,
          message: _l(
              'cloudDiagDriveApi401',
              _loc,
              '401 unauthorized — access token expired. The next sync will '
                  'silently refresh it.'),
        );
      }
      if (r.statusCode == 403) {
        final body = r.body.toLowerCase();
        if (body.contains('drive api has not been used') ||
            body.contains('drive.googleapis.com') &&
                body.contains('disabled')) {
          return _ProbeResult.fail(
            title: tt,
            message: _l(
                'cloudDiagDriveApiNotEnabled',
                _loc,
                'Drive API is NOT enabled in the ysword project. '
                    'Click "Open Cloud Console" to enable it (one click).'),
            fixUrl:
                'https://console.cloud.google.com/apis/library/drive.googleapis.com?project=$_projectId',
            fixLabel: _l('setupStep1OpenLabel', _loc, 'Enable Drive API'),
          );
        }
        return _ProbeResult.fail(
          title: tt,
          message: _l(
                  'cloudDiagDriveApi403Other',
                  _loc,
                  '403 — likely the OAuth consent screen is missing the '
                      'drive.file scope. Server said: {body}')
              .replaceAll('{body}', _truncate(r.body, 200)),
          fixUrl:
              'https://console.cloud.google.com/apis/credentials/consent?project=$_projectId',
          fixLabel:
              _l('setupStep3OpenLabel', _loc, 'Open OAuth consent screen'),
        );
      }
      return _ProbeResult.fail(
        title: tt,
        message: 'Unexpected ${r.statusCode}: ${_truncate(r.body, 200)}',
      );
    } on TimeoutException {
      // 2026-05-06 (later same day): the channel-error symptom got
      // fixed by registering FirebaseDatabaseWeb explicitly, but
      // users started seeing this 8s timeout instead. The MOST likely
      // cause is "the database hasn't actually been created yet in
      // Firebase Console" — RTDB SDK silently retries connections
      // forever to a non-existent endpoint, and we time out at 8s.
      // Surface that hypothesis directly + show the URL we tried so
      // the user can verify it matches what Console shows.
      final url = FirebaseDatabase.instance.databaseURL ?? '(default)';
      return _ProbeResult.fail(
        title: tt,
        message: _l(
                'cloudDiagRtdbTimeoutDetail',
                _loc,
                'Timed out after 8s connecting to {url}. The most '
                    'likely cause is that the database has not been '
                    'created yet in the Firebase Console — open the '
                    'RTDB tab and click "Create Database". Other '
                    'possibilities: the URL\'s region does not match '
                    'where your database lives, or your network is '
                    'blocking firebaseio.com.')
            .replaceAll('{url}', url),
        fixUrl:
            'https://console.firebase.google.com/project/$_projectId/database',
        fixLabel: _l('cloudDiagRtdbOpenConsole', _loc, 'Open RTDB console'),
      );
    } catch (e) {
      return _ProbeResult.fail(title: tt, message: e.toString());
    }
  }

  Future<_ProbeResult> _probeAiProxy() async {
    final tt = _l('cloudDiagAiProxyTitle', _loc, 'AI proxy (Netlify)');
    try {
      final r = await http
          .post(
            Uri.parse(resolveApiUrl('/api/aiSearch')),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'query': '', 'locale': 'en'}),
          )
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 400) {
        return _ProbeResult.ok(
          title: tt,
          message: _l(
              'cloudDiagAiProxyOk',
              _loc,
              'Function reachable. Real AI calls go to Gemini on demand; '
                  'if they fail, see /api/aiSearch logs in Netlify dashboard.'),
        );
      }
      if (r.statusCode == 503) {
        return _ProbeResult.fail(
          title: tt,
          message: _l(
              'cloudDiagAiProxy503',
              _loc,
              'Function says GEMINI_API_KEY is not configured. Set it in '
                  'the Netlify dashboard.'),
          fixUrl: 'https://app.netlify.com/projects/yswords/configuration/env',
          fixLabel:
              _l('setupStep5OpenLabel', _loc, 'Open Netlify env vars'),
        );
      }
      if (r.statusCode == 404) {
        return _ProbeResult.fail(
          title: tt,
          message: _l(
              'cloudDiagAiProxy404',
              _loc,
              'Function returns 404 — not deployed, or netlify.toml '
                  'redirects are misconfigured.'),
        );
      }
      return _ProbeResult.warning(
        title: tt,
        message: 'Unexpected ${r.statusCode}: ${_truncate(r.body, 200)}',
      );
    } on TimeoutException {
      return _ProbeResult.fail(
          title: tt,
          message: _l('cloudDiagTimeout', _loc, 'Timed out after 8s.'));
    } catch (e) {
      return _ProbeResult.fail(title: tt, message: e.toString());
    }
  }

  static String _truncate(String s, int n) =>
      s.length > n ? '${s.substring(0, n)}…' : s;

  // ── UI ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report_outlined,
                    size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    uiStrings['cloudDiagTitle']?[widget.locale] ??
                        'Cloud setup diagnostic',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                if (!_running)
                  TextButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: Text(_results.isEmpty
                        ? (uiStrings['cloudDiagRun']?[widget.locale] ??
                            'Run check')
                        : (uiStrings['cloudDiagRerun']?[widget.locale] ??
                            'Re-run')),
                    onPressed: _runAll,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              uiStrings['cloudDiagBody']?[widget.locale] ??
                  'Probes Firebase Auth, Drive REST, and the AI proxy. '
                      'End users never need to enable anything — these '
                      'are developer-side checks for the YsWords '
                      'project. Failures here are fixable in Cloud '
                      'Console; the app keeps working in degraded '
                      'mode either way (sync goes local-only, AI shows '
                      '"not available").',
              style: TextStyle(
                fontSize: 11.5,
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            if (_running) ...[
              const SizedBox(height: 4),
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 8),
            ],
            for (final r in _results) ...[
              _ProbeRow(result: r),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProbeRow extends StatelessWidget {
  final _ProbeResult result;
  const _ProbeRow({required this.result});

  Future<void> _open(String url) async {
    if (!LinkOpener.isAvailable) return;
    await LinkOpener.open(url);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Theme-aware status colors — paletteAccent gives shade300 in
    // dark mode (vivid against dark surface) and shade700 in light
    // mode (deep on light surface) so the ✅/❌/⚠️ indicators stay
    // legible everywhere.
    final color = result.kind == _ProbeKind.ok
        ? paletteAccent(context, Colors.green)
        : result.kind == _ProbeKind.fail
            ? scheme.error
            : result.kind == _ProbeKind.warning
                ? paletteAccent(context, Colors.orange)
                : scheme.onSurfaceVariant;
    final icon = result.kind == _ProbeKind.ok
        ? Icons.check_circle_outline_rounded
        : result.kind == _ProbeKind.fail
            ? Icons.error_outline_rounded
            : result.kind == _ProbeKind.warning
                ? Icons.warning_amber_rounded
                : Icons.remove_circle_outline_rounded;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.message,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (result.fixUrl != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: Text(result.fixLabel ?? 'Open Cloud Console',
                    style: const TextStyle(fontSize: 11)),
                onPressed: () => _open(result.fixUrl!),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _ProbeKind { ok, fail, warning, skip }

class _ProbeResult {
  final String title;
  final String message;
  final _ProbeKind kind;
  /// Optional one-click "open the fix" URL, e.g. a Cloud Console
  /// page that turns the failure into a success.
  final String? fixUrl;
  final String? fixLabel;

  const _ProbeResult._(
      {required this.title,
      required this.message,
      required this.kind,
      this.fixUrl,
      this.fixLabel});

  factory _ProbeResult.ok({required String title, required String message}) =>
      _ProbeResult._(title: title, message: message, kind: _ProbeKind.ok);
  factory _ProbeResult.warning(
          {required String title, required String message}) =>
      _ProbeResult._(title: title, message: message, kind: _ProbeKind.warning);
  factory _ProbeResult.fail(
          {required String title,
          required String message,
          String? fixUrl,
          String? fixLabel}) =>
      _ProbeResult._(
          title: title,
          message: message,
          kind: _ProbeKind.fail,
          fixUrl: fixUrl,
          fixLabel: fixLabel);
  factory _ProbeResult.skip(
          {required String title, required String message}) =>
      _ProbeResult._(title: title, message: message, kind: _ProbeKind.skip);
}

typedef _ProbeFn = Future<_ProbeResult> Function();
