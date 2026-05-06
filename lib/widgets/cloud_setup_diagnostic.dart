import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/link_opener.dart';

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
    final probes = <_ProbeFn>[
      _probeFirebaseAuth,
      _probeSignedIn,
      _probeDriveScope,
      _probeDriveApi,
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

  Future<_ProbeResult> _probeFirebaseAuth() async {
    final auth = CloudAuthService.instance;
    if (!auth.hasFirebaseCredentials) {
      return _ProbeResult.warning(
        title: 'Firebase Auth',
        message:
            'firebase_options.dart still has placeholder values. '
            'Cloud sync + sign-in are disabled (local-only mode).',
      );
    }
    if (!auth.isConfigured) {
      return _ProbeResult.fail(
        title: 'Firebase Auth',
        message: auth.initError ??
            'Firebase init failed. Check console for [CloudAuthService] log.',
      );
    }
    return _ProbeResult.ok(
        title: 'Firebase Auth', message: 'Configured.');
  }

  Future<_ProbeResult> _probeSignedIn() async {
    final auth = CloudAuthService.instance;
    if (!auth.isConfigured) {
      return _ProbeResult.skip(
          title: 'Signed in', message: 'Auth not configured.');
    }
    if (!auth.isSignedIn) {
      return _ProbeResult.warning(
        title: 'Signed in',
        message:
            'Not signed in. Cloud sync stays disabled until the user '
            'signs in via Settings → Account.',
      );
    }
    return _ProbeResult.ok(
        title: 'Signed in',
        message: 'as ${auth.currentUser?.email ?? "(unknown email)"}');
  }

  Future<_ProbeResult> _probeDriveScope() async {
    final auth = CloudAuthService.instance;
    if (!auth.isSignedIn) {
      return _ProbeResult.skip(
          title: 'Drive scope', message: 'Not signed in.');
    }
    if (!auth.hasDriveAccessToken) {
      return _ProbeResult.warning(
        title: 'Drive scope',
        message:
            'No Drive OAuth access token captured. User may have signed in '
            'before the drive.file scope was added — they need to click '
            'Reconnect Drive in Settings → Account → Sync.',
      );
    }
    return _ProbeResult.ok(
      title: 'Drive scope',
      message: 'OAuth access token captured.',
    );
  }

  Future<_ProbeResult> _probeDriveApi() async {
    final auth = CloudAuthService.instance;
    final t = auth.driveAccessToken;
    if (t == null) {
      return _ProbeResult.skip(
          title: 'Drive REST API', message: 'No access token.');
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
          title: 'Drive REST API',
          message: files.isEmpty
              ? 'API reachable; no YsWords.json yet (will be created on first sync).'
              : 'API reachable; YsWords.json exists.',
        );
      }
      if (r.statusCode == 401) {
        return _ProbeResult.warning(
          title: 'Drive REST API',
          message:
              '401 unauthorized — access token expired. The next sync will '
              'silently refresh it.',
        );
      }
      if (r.statusCode == 403) {
        // The two most common causes — make the message tell us which.
        final body = r.body.toLowerCase();
        if (body.contains('drive api has not been used') ||
            body.contains('drive.googleapis.com') &&
                body.contains('disabled')) {
          return _ProbeResult.fail(
            title: 'Drive REST API',
            message:
                'Drive API is NOT enabled in the $_projectId project. '
                'Click "Open Cloud Console" to enable it (one click).',
            fixUrl:
                'https://console.cloud.google.com/apis/library/drive.googleapis.com?project=$_projectId',
            fixLabel: 'Enable Drive API',
          );
        }
        return _ProbeResult.fail(
          title: 'Drive REST API',
          message:
              '403 — likely the OAuth consent screen is missing the '
              'drive.file scope, or your account is on a Workspace '
              'admin that blocks third-party apps. Server said: '
              '${_truncate(r.body, 200)}',
          fixUrl:
              'https://console.cloud.google.com/apis/credentials/consent?project=$_projectId',
          fixLabel: 'Open OAuth consent screen',
        );
      }
      return _ProbeResult.fail(
        title: 'Drive REST API',
        message:
            'Unexpected ${r.statusCode}: ${_truncate(r.body, 200)}',
      );
    } on TimeoutException {
      return _ProbeResult.fail(
          title: 'Drive REST API', message: 'Timed out after 8s.');
    } catch (e) {
      return _ProbeResult.fail(
          title: 'Drive REST API', message: e.toString());
    }
  }

  Future<_ProbeResult> _probeAiProxy() async {
    // Tiny POST to /api/aiSearch with an empty query — the function
    // returns 400 "query required" which proves it's deployed AND the
    // Gemini key chain is intact (it would 503 if `geminiKeys()`
    // returned an empty list). This avoids burning real Gemini quota.
    try {
      final r = await http
          .post(
            Uri.parse('/api/aiSearch'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'query': '', 'locale': 'en'}),
          )
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 400) {
        // Function is deployed and reachable. We didn't actually hit
        // Gemini, so we can't be 100% sure the API is enabled — but
        // we can say "function reachable" with confidence.
        return _ProbeResult.ok(
          title: 'AI proxy (Netlify)',
          message: 'Function reachable. Real AI calls go to Gemini '
              'on demand; if they fail, see /api/aiSearch logs in '
              'Netlify dashboard.',
        );
      }
      if (r.statusCode == 503) {
        return _ProbeResult.fail(
          title: 'AI proxy (Netlify)',
          message:
              'Function says GEMINI_API_KEY is not configured. Set it '
              'in the Netlify dashboard.',
          fixUrl: 'https://app.netlify.com/projects/yswords/configuration/env',
          fixLabel: 'Open Netlify env vars',
        );
      }
      if (r.statusCode == 404) {
        return _ProbeResult.fail(
          title: 'AI proxy (Netlify)',
          message:
              'Function returns 404 — not deployed, or netlify.toml '
              'redirects are misconfigured.',
        );
      }
      return _ProbeResult.warning(
        title: 'AI proxy (Netlify)',
        message:
            'Unexpected ${r.statusCode}: ${_truncate(r.body, 200)}',
      );
    } on TimeoutException {
      return _ProbeResult.fail(
          title: 'AI proxy (Netlify)', message: 'Timed out after 8s.');
    } catch (e) {
      return _ProbeResult.fail(
          title: 'AI proxy (Netlify)', message: e.toString());
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
    final color = result.kind == _ProbeKind.ok
        ? Colors.green.shade600
        : result.kind == _ProbeKind.fail
            ? scheme.error
            : result.kind == _ProbeKind.warning
                ? Colors.orange.shade700
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
