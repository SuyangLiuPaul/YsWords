// 2026-05-20 (v1.2.67): native no-op for `clearCacheAndReload`.
// Service workers + browser caches don't exist on iOS / Android /
// desktop builds, so this is a no-op. The "Reload page (clear
// cache)" button visible in the splash error scaffold + the
// About page diagnostic still renders on those platforms but
// has no effect — there's no SW cache to clear.

import 'package:flutter/foundation.dart';

void clearCacheAndReload() {
  debugPrint(
      '[clearCacheAndReload] no-op on native platform (no SW cache)');
}
