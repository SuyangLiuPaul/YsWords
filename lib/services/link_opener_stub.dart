// Native implementation: iOS / Android / macOS / Windows / Linux.
//
// 2026-08-11: this file used to be a genuine stub —
//
//     bool openIsAvailable() => false;
//     Future<bool> openUrl(String url) async => false;
//
// with a comment saying "the Flutter app today only ships web". That
// stopped being true a long time ago, and the stub went with it: on the
// iPhone, "Original page" did nothing at all, and so did every other
// external link in the app — 24 call sites across 10 files, including
// Feedback, About, the update check and the Gemini key help. Every one
// of them failed silently, because the contract is `Future<bool>` and
// `false` looks exactly like a user cancelling.
//
// `url_launcher` is now a declared dependency (it also arrived
// transitively with pdfrx; depending on that by accident would have
// been fragile, so it is declared explicitly in pubspec.yaml).

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:url_launcher/url_launcher.dart';

bool openIsAvailable() => true;

Future<bool> openUrl(String url) async {
  if (url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    debugPrint('[LinkOpener] not a usable URL: "$url"');
    return false;
  }
  try {
    // externalApplication, not the default platformDefault: the point
    // of "Original page" is the church's own site in a real browser
    // with an address bar and history. platformDefault can route to an
    // in-app SFSafariViewController, which on iOS leaves the user
    // inside YsWords looking at someone else's page — the same trap the
    // web implementation documents for `_blank` inside a standalone
    // PWA.
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok) return true;
    // Some Android setups have no activity that answers the external
    // intent while the in-app browser is perfectly available, so a
    // refusal is worth one retry on the default route before reporting
    // failure to the user.
    debugPrint('[LinkOpener] external launch refused $uri — '
        'retrying with the platform default');
    return await launchUrl(uri);
  } catch (e) {
    // Thrown rather than returned when no handler exists at all.
    debugPrint('[LinkOpener] could not open $uri: $e');
    return false;
  }
}
