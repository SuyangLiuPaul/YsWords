// 2026-05-21 (v1.2.69): centralised base-URL resolution for the
// Netlify Functions API (/api/*).
//
// Why: on web the app is served from yswords.netlify.app, so the
// relative path `/api/aiSearch` resolves same-origin and avoids CORS
// preflight. On native (iOS / Android / macOS) there's no origin —
// `Uri.parse('/api/aiSearch')` produces a hostless URI that http.post
// can't dial. We resolve to the absolute production URL on native.
//
// Override via `--dart-define=YSWORDS_BASE_URL=https://...` for
// staging / dev / local netlify-dev (e.g.
// `--dart-define=YSWORDS_BASE_URL=http://localhost:8888`).

import 'package:flutter/foundation.dart' show kIsWeb;

/// Production base URL. Native builds prepend this to relative
/// `/api/...` paths; web builds keep paths relative (same-origin).
const String kYswordsBaseUrl = String.fromEnvironment(
  'YSWORDS_BASE_URL',
  defaultValue: 'https://yswords.netlify.app',
);

/// Resolves an API path to a full URL.
///   • If [path] already starts with `http`, return it unchanged.
///   • Else on web: return [path] as-is (same-origin).
///   • Else (native): prepend [kYswordsBaseUrl].
String resolveApiUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  if (kIsWeb) return path;
  return '$kYswordsBaseUrl$path';
}
