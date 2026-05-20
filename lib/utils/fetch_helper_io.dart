// 2026-05-20 (v1.2.67): native no-op for fetchUrl. No browser
// cache to warm on iOS / Android; the offline-pack UI is web-
// only (gated by `kIsWeb` in dashboard / settings), so this
// callsite is unreachable in practice. If somebody wires up
// an iOS offline-pack later, swap to `package:http` or
// `package:dio` here.

import 'package:flutter/foundation.dart';

Future<void> fetchUrl(String url) async {
  debugPrint(
      '[fetchUrl] no-op on native platform — offline-pack pre-warm '
      "skipped for $url");
}
