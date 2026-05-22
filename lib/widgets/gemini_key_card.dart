import 'dart:async' show TimeoutException;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:yswords/constants/build_flags.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/ai_bible_search_service.dart';
import 'package:yswords/services/api_base.dart';
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/utils/theme_color_helpers.dart';

/// Settings → AI → "Use my own Gemini API key" (BYOK) card.
///
/// Why this exists: AI explanations + AI search go through Gemini,
/// which is metered. The developer-shared key has limited free
/// quota; once exhausted everyone gets "AI explanation is not
/// available right now". Letting users paste their own key from
/// AI Studio (free, instant) gives each user their own 15 RPM /
/// 1500 RPD budget — way more than they'll ever hit, and it
/// removes the developer's cost ceiling.
///
/// Storage: SharedPreferences only — never transmitted off-device
/// except as a body field on the next AI request, which is a same-
/// origin POST to our Netlify function. The function uses the key
/// to call Gemini directly and never logs / persists it.
class GeminiKeyCard extends StatefulWidget {
  final AppSettings settings;
  final double s;
  const GeminiKeyCard({super.key, required this.settings, required this.s});

  @override
  State<GeminiKeyCard> createState() => GeminiKeyCardState();
}

/// Three-state result of a Test-key roundtrip. The card paints a
/// matching status row below the input so the user gets unambiguous
/// feedback without having to dive into the search page to validate
/// their paste.
enum _TestStatus { idle, testing, ok, fail }

class GeminiKeyCardState extends State<GeminiKeyCard> {
  late final TextEditingController _ctrl;
  bool _obscure = true;
  bool _saved = false;
  _TestStatus _testStatus = _TestStatus.idle;
  String? _testError;
  // 2026-05-09 (v1.2.8 audit): generation counter that lets an
  // in-flight `_test()` Future tell whether its result is still
  // wanted by the time it lands. Bumped on every test start AND on
  // every text-change (`_resetTestStatus`). Without this, a user
  // who pastes key A → taps Test → edits to key B → taps Test could
  // see key A's slow result briefly clobber key B's fast result.
  int _testGen = 0;

  // 2026-05-17 (v1.2.47): track the last value pushed into `_ctrl`
  // by the settings listener. Used to distinguish "cloud-driven
  // change while the user wasn't typing" (safe to mirror into the
  // text field) from "user edited the field locally" (must NOT
  // clobber). Compared against `_ctrl.text` at every listener fire.
  String _lastSyncedKey = '';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.settings.geminiApiKey);
    _lastSyncedKey = widget.settings.geminiApiKey;
    _ctrl.addListener(_resetTestStatus);
    // 2026-05-10 (v1.2.17) + 2026-05-17 (v1.2.47): keep the text
    // field in lockstep with `settings.geminiApiKey`. Covers two
    // flows:
    //   (a) the one-shot cloud pull on boot / sign-in
    //   (b) the v1.2.47 real-time listener — when another device
    //       pastes / clears the key, we want the change to land
    //       in this device's input without a reboot.
    // The `_lastSyncedKey` guard preserves any unsaved typing on
    // this device.
    widget.settings.addListener(_onSettingsKeyChanged);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsKeyChanged);
    _ctrl.removeListener(_resetTestStatus);
    _ctrl.dispose();
    super.dispose();
  }

  void _onSettingsKeyChanged() {
    if (!mounted) return;
    final remote = widget.settings.geminiApiKey;
    if (_ctrl.text == remote) {
      // Save-echo case OR already in sync — just record the new
      // baseline so future cloud changes are picked up correctly.
      _lastSyncedKey = remote;
      return;
    }
    if (_ctrl.text != _lastSyncedKey) {
      // The user has typed something different from what we last
      // synced — they're mid-edit. Don't clobber their work.
      return;
    }
    // Genuine cloud-driven update (paste / clear on another
    // device). Mirror it into the text field — including the
    // clear case where `remote` is empty.
    _ctrl.text = remote;
    _lastSyncedKey = remote;
    // _resetTestStatus fires automatically via the controller
    // listener; keep the panel clean.
  }

  void _resetTestStatus() {
    // Any edit invalidates the previous test result — the user is
    // now looking at a new key string. Avoids a stale "Key works ✓"
    // message lingering after a paste-replace.
    if (_testStatus != _TestStatus.idle) {
      // Also bump the generation counter so any in-flight Future
      // from a previous _test() call won't land setState on the
      // freshly-cleared _testStatus.
      _testGen++;
      setState(() {
        _testStatus = _TestStatus.idle;
        _testError = null;
      });
    }
  }

  Future<void> _save() async {
    await widget.settings.setGeminiApiKey(_ctrl.text);
    if (!mounted) return;
    setState(() => _saved = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  /// Test the user's key against the live AI Bible Search endpoint
  /// without saving it first. Lets the user paste, verify, and only
  /// commit if it actually works.
  ///
  /// Implementation note: passing `userApiKey` to the Netlify
  /// function disables the dev-shared-key fallback chain
  /// (`callGemini` uses ONLY the override key when present), so a
  /// 200 response here is conclusive proof the user's key
  /// authenticated against Gemini — not just that the developer's
  /// shared pool happened to have quota.
  Future<void> _test() async {
    // Snapshot a generation tag for this Future. Compared against
    // _testGen at every setState to detect "stale" landings (the
    // user has since edited the field or fired a newer test).
    final myGen = ++_testGen;
    final raw = _ctrl.text.trim();
    // 1. Local shape validation. Same regex the Netlify function
    //    uses to reject garbage before forwarding to Gemini. This
    //    block is sync — no race possible — so we don't bother with
    //    a generation check.
    if (!RegExp(r'^AIza[A-Za-z0-9_-]{20,80}$').hasMatch(raw)) {
      setState(() {
        _testStatus = _TestStatus.fail;
        _testError = uiStrings['aiByokTestInvalidShape']
                ?[widget.settings.locale] ??
            "Doesn't look like a Gemini API key. It should start with "
                'AIza… (you can copy one from aistudio.google.com/apikey).';
      });
      return;
    }
    setState(() {
      _testStatus = _TestStatus.testing;
      _testError = null;
    });
    try {
      final resp = await http
          .post(
            Uri.parse(resolveApiUrl(AiBibleSearchService.endpoint)),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': 'love',
              'locale': widget.settings.locale,
              'userApiKey': raw,
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (!mounted || myGen != _testGen) return;
      if (resp.statusCode == 200) {
        // 2026-05-09 (v1.2.8 audit): wrap jsonDecode in a try/catch
        // so a malformed-but-200 body (rare CDN slicing / mid-stream
        // truncation) shows the localised "Unexpected response"
        // message instead of leaking a raw `FormatException: …` to
        // the user.
        dynamic body;
        try {
          body = jsonDecode(resp.body);
        } catch (_) {
          if (myGen != _testGen) return;
          setState(() {
            _testStatus = _TestStatus.fail;
            _testError = uiStrings['aiByokTestUnexpected']
                    ?[widget.settings.locale] ??
                'Unexpected response from the AI service.';
          });
          return;
        }
        if (body is Map &&
            body['refs'] is List &&
            (body['refs'] as List).isNotEmpty) {
          if (myGen != _testGen) return;
          setState(() {
            _testStatus = _TestStatus.ok;
            _testError = null;
          });
          return;
        }
        if (myGen != _testGen) return;
        setState(() {
          _testStatus = _TestStatus.fail;
          _testError = uiStrings['aiByokTestUnexpected']
                  ?[widget.settings.locale] ??
              'Unexpected response from the AI service.';
        });
        return;
      }
      String msg = 'HTTP ${resp.statusCode}';
      try {
        final j = jsonDecode(resp.body);
        if (j is Map && j['error'] is String) {
          msg = (j['error'] as String).trim();
        }
      } catch (_) {/* fall through to status-code message */}
      if (myGen != _testGen) return;
      setState(() {
        _testStatus = _TestStatus.fail;
        _testError = msg;
      });
    } on TimeoutException {
      if (!mounted || myGen != _testGen) return;
      setState(() {
        _testStatus = _TestStatus.fail;
        _testError = uiStrings['aiByokTestTimeout']
                ?[widget.settings.locale] ??
            'The AI service did not respond in time. Try again.';
      });
    } catch (e) {
      if (!mounted || myGen != _testGen) return;
      setState(() {
        _testStatus = _TestStatus.fail;
        _testError = e.toString();
      });
    }
  }

  Future<void> _openAiStudio() async {
    if (!LinkOpener.isAvailable) return;
    await LinkOpener.open('https://aistudio.google.com/apikey');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.settings.locale;
    final s = widget.s;
    final hasKey = widget.settings.hasUserGeminiKey;
    return Card(
      child: Padding(
        // 2026-05-10 (v1.2.23): standardised to 16/14 to match
        // the rest of the Settings page surfaces. Was 14/12 — looked
        // visibly tighter than its neighbours.
        padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 14 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy_outlined,
                    size: 18, color: scheme.primary),
                SizedBox(width: 8 * s),
                Text(
                  uiStrings['aiByokTitle']?[locale] ??
                      'Use my own Gemini API key',
                  style: TextStyle(
                    fontFamily: widget.settings.fontFamily,
                    fontSize: (widget.settings.fontSize - 1)
                        .clamp(13.0, 16.0),
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (hasKey)
                  Icon(Icons.check_circle_outline_rounded,
                      size: 18, color: paletteAccent(context, Colors.green)),
              ],
            ),
            SizedBox(height: 6 * s),
            Text(
              uiStrings['aiByokBody']?[locale] ??
                  'Paste your free Gemini API key from AI Studio so AI '
                      'features use your own quota (15 requests / minute, '
                      '1500 / day). Without one, you share the developer '
                      'pool — when it runs out, AI features pause for '
                      'everyone. The key stays on this device only.',
              style: TextStyle(
                fontFamily: widget.settings.fontFamily,
                fontSize: (widget.settings.fontSize - 4)
                    .clamp(11.0, 13.0),
                color: scheme.onSurface.withValues(alpha: 0.78),
                height: 1.5,
              ),
            ),
            SizedBox(height: 8 * s),
            TextField(
              controller: _ctrl,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: 'AIza…',
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscure
                      ? (uiStrings['show']?[locale] ?? 'Show')
                      : (uiStrings['hide']?[locale] ?? 'Hide'),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: (widget.settings.fontSize - 3)
                    .clamp(12.0, 14.0),
              ),
            ),
            // 2026-05-10 (v1.2.17): cloud-sync disclosure. Only
            // shows when (a) we're not in the China build (Firebase
            // skipped there), (b) the user is signed in, and (c)
            // they have a key set — so the line is informative,
            // not aspirational. Auth-state changes trigger a
            // rebuild via the AppSettings listener already wired in
            // initState.
            if (!kChinaMode &&
                CloudAuthService.instance.isSignedIn &&
                hasKey) ...[
              SizedBox(height: 6 * s),
              Row(
                children: [
                  Icon(
                    Icons.cloud_done_outlined,
                    size: 14,
                    color: paletteAccent(context, Colors.blue),
                  ),
                  SizedBox(width: 6 * s),
                  Expanded(
                    child: Text(
                      uiStrings['aiByokSyncedNote']?[locale] ??
                          'Signed in — the key will auto-sync to your other signed-in devices.',
                      style: TextStyle(
                        fontFamily: widget.settings.fontFamily,
                        fontSize: (widget.settings.fontSize - 5)
                            .clamp(10.0, 12.0),
                        color: paletteAccent(context, Colors.blue),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 8 * s),
            Wrap(
              spacing: 8 * s,
              runSpacing: 6 * s,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  icon: Icon(
                    _saved ? Icons.check_rounded : Icons.save_outlined,
                    size: 16,
                  ),
                  label: Text(
                    _saved
                        ? (uiStrings['saved']?[locale] ?? 'Saved')
                        : (uiStrings['save']?[locale] ?? 'Save'),
                  ),
                  onPressed: _save,
                ),
                // 2026-05-09 (v1.2.7): Test button — sends a tiny
                // probe to /api/aiBibleSearch with the current input
                // (NOT the saved value), waits for a 200 response,
                // and paints a status row below. Disabled while a
                // probe is in flight.
                OutlinedButton.icon(
                  icon: _testStatus == _TestStatus.testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt_outlined, size: 16),
                  label: Text(
                    _testStatus == _TestStatus.testing
                        ? (uiStrings['aiByokTesting']?[locale] ??
                            'Testing…')
                        : (uiStrings['aiByokTest']?[locale] ?? 'Test'),
                  ),
                  onPressed:
                      _testStatus == _TestStatus.testing ? null : _test,
                ),
                if (hasKey)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16),
                    label: Text(uiStrings['clear']?[locale] ?? 'Clear'),
                    onPressed: () async {
                      _ctrl.clear();
                      await widget.settings.setGeminiApiKey('');
                      if (mounted) {
                        setState(() {
                          _testStatus = _TestStatus.idle;
                          _testError = null;
                        });
                      }
                    },
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(
                    uiStrings['aiByokGetKey']?[locale] ??
                        'Get free key',
                  ),
                  onPressed: _openAiStudio,
                ),
              ],
            ),
            // Status row below the buttons. Uses paletteAccent so
            // the success / failure colours match the rest of the
            // settings page on every theme.
            if (_testStatus == _TestStatus.ok ||
                _testStatus == _TestStatus.fail) ...[
              SizedBox(height: 8 * s),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _testStatus == _TestStatus.ok
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    size: 16,
                    color: _testStatus == _TestStatus.ok
                        ? paletteAccent(context, Colors.green)
                        : paletteAccent(context, Colors.red),
                  ),
                  SizedBox(width: 6 * s),
                  Expanded(
                    child: Text(
                      _testStatus == _TestStatus.ok
                          ? (uiStrings['aiByokTestOk']?[locale] ??
                              'Key works! AI features will use your quota.')
                          : (_testError ??
                              (uiStrings['aiByokTestFailed']?[locale] ??
                                  'Test failed.')),
                      style: TextStyle(
                        fontFamily: widget.settings.fontFamily,
                        fontSize: (widget.settings.fontSize - 4)
                            .clamp(11.0, 13.0),
                        color: _testStatus == _TestStatus.ok
                            ? paletteAccent(context, Colors.green)
                            : paletteAccent(context, Colors.red),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
