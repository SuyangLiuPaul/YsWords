import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/services/offline_pack_service.dart';

/// Guards two facts about the offline-download Settings screen:
/// every URL each category enumerates actually exists (or is genuinely
/// reachable), and the MB figure shown to the reader is close to the
/// real download size.
///
/// Both have been wrong before. `sermons` advertised 26 MB for a real
/// 34.9 MB download (fixed 2026-09-06/07) after the corpus grew
/// 289 -> 429 sermons and nobody re-measured. That fix touched one
/// category by hand; the other four had not been checked since their
/// "approximate as of 2026-05" comment was written, and `maps` turned
/// out to have its own, different defect: `_mapUrls()` enumerated all
/// 1192 `assets/maps_index.json` entries as local asset paths, but only
/// 55 of them (`source == 'asset'`) are actually bundled — the other
/// 1137 (`cdn` / `legacy_url`, the Doré/Tissot/etc. illustrations
/// merged into this same index file on 2026-09-06 for the
/// illustration-rights work) are meant to stream from
/// `yswords-data`/Wikimedia via `BibleMap.imageUrl`
/// (`lib/widgets/illustration_image.dart`). Downloading the "maps"
/// offline pack was silently attempting 1137 dead `assets/maps/<file>`
/// fetches every time.
///
/// `bibles` / `tools` / `originals` are built from `static const`
/// lists — their URLs are extracted from the real source text of
/// `offline_pack_service.dart` rather than copied here, so a change to
/// those lists can't silently drift out of sync with this test (the
/// precedent for this shape is `test/apk_freshness_guard_test.dart`).
///
/// `maps` / `sermons` are built at runtime from JSON indexes, with
/// enough branching logic (the asset/cdn/legacy_url split above; the
/// hasEn/hasZhCn/hasZhTw flags) that reimplementing it a second time
/// here would risk exactly the kind of drift this test exists to
/// catch — proven the hard way while writing it: an earlier draft
/// re-derived the `source == 'asset'` filter independently, and it
/// stayed green even with the real filter in `_mapUrls()` reverted,
/// because it was checking its own copy of the logic, not the
/// service's. So these two go through `OfflinePackService.debugUrlsFor`
/// (`@visibleForTesting`), which calls the exact same private
/// `_buildUrlList` the app uses to decide what to fetch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final source =
      File('lib/services/offline_pack_service.dart').readAsStringSync();

  // Plain exceptions rather than `expect(...)` below — this helper runs
  // at test-REGISTRATION time (building the lists that parameterise
  // `checkCategory` calls), outside any test body, where `expect` throws
  // `OutsideTestException` instead of a normal assertion failure.
  List<String> extractBetween(String startMarker, String endMarker) {
    final start = source.indexOf(startMarker);
    if (start == -1) {
      throw StateError('"$startMarker" not found — '
          'offline_pack_service.dart was restructured; update the marker '
          'this test looks for');
    }
    final end = source.indexOf(endMarker, start + startMarker.length);
    if (end <= start) {
      throw StateError('no closing "$endMarker" found after "$startMarker"');
    }
    final block = source.substring(start + startMarker.length, end);
    // Strip everything from `//` to end of line first — none of the
    // real asset paths in this file contain "//", so this can only
    // ever remove comment text, including the commented-out asset
    // paths (e.g. the removed NIV/CUV/CNV entries) that would
    // otherwise be picked up as if they were live.
    final withoutComments = block
        .split('\n')
        .map((line) {
          final i = line.indexOf('//');
          return i == -1 ? line : line.substring(0, i);
        })
        .join('\n');
    return RegExp("'([^']+)'")
        .allMatches(withoutComments)
        .map((m) => m.group(1)!)
        .toList();
  }

  int statedMbFor(String enumCaseName) {
    final marker = 'case OfflinePackCategory.$enumCaseName:';
    final caseStart = source.indexOf(marker);
    expect(caseStart, greaterThan(-1),
        reason: 'approximateMbFor has no case for $enumCaseName');
    final returnStart = source.indexOf('return', caseStart);
    final semi = source.indexOf(';', returnStart);
    final numMatch =
        RegExp(r'\d+').firstMatch(source.substring(returnStart, semi));
    expect(numMatch, isNotNull,
        reason: 'no integer literal in the $enumCaseName case of '
            'approximateMbFor');
    return int.parse(numMatch!.group(0)!);
  }

  /// Sums real on-disk bytes for [paths], collecting any that don't
  /// exist into [missing] instead of throwing — a missing file is the
  /// finding, not a test-harness error.
  int totalBytes(List<String> paths, List<String> missing) {
    var total = 0;
    for (final p in paths) {
      final f = File(p);
      if (!f.existsSync()) {
        missing.add(p);
        continue;
      }
      total += f.lengthSync();
    }
    return total;
  }

  void checkCategory(
    String label,
    String enumCaseName,
    List<String> Function() pathsOf,
  ) {
    test('$label: every enumerated path exists on disk', () {
      final missing = <String>[];
      totalBytes(pathsOf(), missing);
      expect(missing, isEmpty,
          reason: '$label enumerates ${missing.length} path(s) that are '
              'not in the bundle — every one of these is a silent dead '
              'fetch when a reader downloads this offline-pack category:\n'
              '${missing.take(10).join('\n')}'
              '${missing.length > 10 ? '\n...and ${missing.length - 10} more' : ''}');
    });

    test('$label: approximateMbFor is within tolerance of the real total', () {
      final missing = <String>[];
      final paths = pathsOf();
      final realBytes = totalBytes(paths, missing);
      final realMb = realBytes / (1024 * 1024);
      final statedMb = statedMbFor(enumCaseName);

      // Understating is the user-facing harm (a reader on mobile data
      // decides to download based on this number), so it gets the
      // tighter bound. Overstating just makes the pack look bigger
      // than it is.
      final minAcceptable = realMb * 0.90;
      final maxAcceptable = realMb * 1.25;
      expect(
        statedMb >= minAcceptable && statedMb <= maxAcceptable,
        isTrue,
        reason: '$label: approximateMbFor() says $statedMb MB but the '
            '${paths.length} files it enumerates are '
            '${realMb.toStringAsFixed(2)} MB on disk (acceptable range '
            '${minAcceptable.toStringAsFixed(2)}-'
            '${maxAcceptable.toStringAsFixed(2)} MB)',
      );
    });
  }

  final bibleUrls =
      extractBetween('static const List<String> _bibleUrls = [', '];');
  final toolsUrls =
      extractBetween('static const List<String> _toolsUrls = [', '];');
  final lexiconUrls = extractBetween('const lexicon = <String>[', '];');
  final bookNames = extractBetween('const books = <String>[', '];');
  final originalsUrls = [
    ...lexiconUrls,
    for (final b in bookNames) 'assets/originals/$b.json',
  ];

  late List<String> mapUrls;
  late List<String> sermonUrls;

  setUpAll(() async {
    final service = OfflinePackService.instance;
    mapUrls = await service.debugUrlsFor(OfflinePackCategory.maps);
    sermonUrls = await service.debugUrlsFor(OfflinePackCategory.sermons);
  });

  test('the extracted static lists are non-empty (extraction sanity check)',
      () {
    expect(bibleUrls, isNotEmpty);
    expect(toolsUrls, isNotEmpty);
    expect(lexiconUrls, hasLength(4));
    expect(bookNames, hasLength(66), reason: '39 OT + 27 NT books');
  });

  test('debugUrlsFor(maps) is non-empty and matches the source=="asset" '
      'count in maps_index.json', () {
    expect(mapUrls, isNotEmpty);
    expect(mapUrls, hasLength(55),
        reason: 'maps_index.json is documented to carry 55 bundled asset '
            'entries alongside the network-sourced illustrations; if this '
            'count changed, either a bundled map was added/removed (update '
            'this count) or _mapUrls() stopped filtering by source '
            '(regression)');
  });

  test('debugUrlsFor(sermons) is non-empty', () {
    expect(sermonUrls, isNotEmpty);
  });

  checkCategory('bibles', 'bibles', () => bibleUrls);
  checkCategory('tools', 'tools', () => toolsUrls);
  checkCategory('originals', 'originals', () => originalsUrls);
  checkCategory('maps', 'maps', () => mapUrls);
  checkCategory('sermons', 'sermons', () => sermonUrls);
}
