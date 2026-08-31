// Native no-op half of `page_reload.dart`.
//
// There is no page to reload on iOS / Android / desktop, and no
// sessionStorage to latch against. `updateReloadAlreadyTried` reports
// true — callers read that as "do not auto-reload", which is the
// correct native answer.

import 'package:flutter/foundation.dart';

void reloadPage() {
  debugPrint('[reloadPage] no-op on native platform');
}

bool updateReloadAlreadyTried(String version) => true;

void markUpdateReloadTried(String version) {}
