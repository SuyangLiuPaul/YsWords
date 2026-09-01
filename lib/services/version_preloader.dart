import 'package:yswords/constants/bible_versions.dart'
    show availableVersions;
import 'package:flutter/foundation.dart';
import 'package:yswords/providers/main_provider.dart';

/// 2026-05-10 (v1.2.25 — restored from v1.2.18): eager pre-load of ALL
/// Bible versions, so every version switch for the rest of the session
/// is instant. The user chose this trade ("反正第一次用才 load version")
/// after v1.2.22's hybrid was rejected.
///
/// 2026-08-12: it now waits for `MainProvider.splashDismissed` before
/// the first decode. Each version is a `json.decode` of a 2–9 MB string
/// on the main thread, and running those under the splash janked the
/// splash animation and delayed the very 3 s timer that dismisses it —
/// while a progress line said "Loading versions: 3/6" over assets that
/// on native are already in the bundle and are never downloaded at all.
/// The user reported that line twice from an iPhone.
///
/// Order: simplified Chinese staples (largest user base) → English →
/// traditional Chinese → LJK2 NT-only specialty. Most-likely-next picks
/// land in the LRU first, so even if the user force-quits mid-pre-load
/// the next session's first switches still hit the cache.
///
/// `isActive` is the caller's liveness check (`() => mounted` from a
/// State): the loop abandons the rest of the queue once it returns
/// false. `preloadVersion` is best-effort and swallows failures, so one
/// missing asset cannot stall the queue behind it.
Future<void> eagerPreloadAllVersions(
  MainProvider mainProvider, {
  required bool Function() isActive,
}) async {
  if (!isActive()) return;
  await mainProvider.splashDismissed;
  if (!isActive()) return;
  const candidates = <String>[
    // Simplified Chinese staple — largest user base.
    'cuvs-yhwh',
    // English flagships.
    'kjv',
    'nasb',
    'leb',
    // Traditional Chinese variant.
    'cuvs-yhwh-tr',
    // LJK2 — NT-only specialty translation.
    'biblexg-v2',
    'biblexg-v2-tr',
  ];
  // 2026-09-02: skip editions this build has no asset for — on web the
  // NASB and LEB files are stripped for licensing. preloadVersion
  // swallows the failure, so this is not a crash, but it is two
  // guaranteed 404s and two wasted round-trips on every cold boot.
  final available = availableVersions.map((v) => v.value).toSet();
  final toLoad = candidates
      .where((v) => v != mainProvider.currentVersion && available.contains(v))
      .toList();
  for (final version in toLoad) {
    if (!isActive()) return;
    // Yield once per iteration so the app repaints before the next
    // ~1 s json.decode hogs the main thread.
    await Future<void>.delayed(Duration.zero);
    await mainProvider.preloadVersion(version);
  }
  debugPrint('Eager pre-load complete: ${toLoad.length} versions');
}
