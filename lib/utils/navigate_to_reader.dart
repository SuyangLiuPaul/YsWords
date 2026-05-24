// 2026-05-24 (v1.3.7): single canonical helper for navigating to the
// Bible Reader (HomePage) from anywhere in the app.
//
// Why a helper: navigation to the reader happens from 5+ different
// places (Library tile, verse-ref popup "Open in Reader", trivia
// answer link, timeline event link, deep-link URL handler, ...).
// All of them MUST avoid creating a duplicate HomePage in the
// navigator stack — the previous bug was Library tile tap →
// `Get.off(HomePage)` only replaced Library and left a stale
// HomePage(reader) underneath, so backing out of the new HomePage
// surfaced the original one. User reported "bible duplicate了".
//
// The helper:
//   1. Pops EVERY route above an existing HomePage (if one exists
//      in the stack — identified by route.settings.name ==
//      '/HomePage'; that name is set explicitly by every push site
//      in v1.3.6).
//   2. If an existing HomePage is found, pendingJump (set by the
//      caller via jumper.prepareJumpToVerse / resolveAndPrepareJump
//      etc.) fires on it during the next build.
//   3. If no HomePage is in the stack at all, popUntil stops at
//      root (Dashboard) and a fresh HomePage is Get.to'd on top.
//
// Either way the stack ends with EXACTLY ONE HomePage.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yswords/pages/home_page.dart';

/// The canonical route name for HomePage. All Get.to / Get.off
/// pushes of HomePage MUST pass this as `routeName:` so popUntil
/// can detect existing instances reliably.
const String kHomePageRouteName = '/HomePage';

/// Navigate to the Bible Reader, re-using an existing HomePage
/// instance if one is already in the navigator stack; otherwise
/// push a fresh one. Idempotent — calling multiple times in a row
/// never produces duplicates.
///
/// Callers are responsible for setting `mainProvider.pendingJump`
/// (or equivalent) BEFORE invoking this helper. The reader's
/// build sees the jump request and scrolls + highlights the
/// target verse on its next frame.
void navigateToReader(BuildContext context) {
  final navigator = Navigator.of(context, rootNavigator: true);
  bool foundExistingHome = false;
  navigator.popUntil((route) {
    final name = route.settings.name ?? '';
    // Match the canonical name AND any future variant ending in
    // "HomePage" (defensive — if some future push site forgets the
    // explicit routeName and Get happens to produce something
    // ending in HomePage, we still detect it).
    if (name == kHomePageRouteName || name.endsWith('HomePage')) {
      foundExistingHome = true;
      return true;
    }
    if (route.isFirst) return true; // root (Dashboard) reached
    return false;
  });
  if (!foundExistingHome) {
    Get.to(() => const HomePage(),
        routeName: kHomePageRouteName,
        transition: Transition.rightToLeft);
  }
}
