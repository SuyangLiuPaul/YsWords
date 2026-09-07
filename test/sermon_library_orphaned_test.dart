import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/services/sermon_library_service.dart';

/// The 福音电台 sermon library cluster (`SermonLibraryPage` and its two
/// children, the chrome widget, the model and the service) has no
/// route and no dashboard tile — the tile was deliberately removed in
/// v1.5.0, and `dashboard_page.dart:876-894` records why. Nothing else
/// was removed: the six files still ship, still compile, and are
/// reachable only from `test/`.
///
/// That is a state worth pinning, not just noting. `SermonLibraryPage`
/// pushes `SermonLibrarySpeakerPage` and that pushes
/// `SermonLibrarySermonPage`, and if any of the three regains a
/// caller outside the cluster — a route, a dashboard tile, a debug
/// menu entry — it goes live again with **zero CI coverage**: all
/// three `hasCorpus`-gated suites in this directory skip on the
/// runner, because `assets/sermon_library/` is gitignored staging
/// that only exists on a Mac that has run the fetcher. A silent
/// re-entry would ship straight to `SermonLibraryService.load()`
/// throwing on the runner's missing `index.json` — the exact error
/// page dev/qat readers hit before the tile was pulled.
///
/// This suite runs unconditionally, corpus or not — it never touches
/// `assets/sermon_library/`, only source text and a fake loader — so
/// a re-entry fails here on every runner, not just on this Mac.
void main() {
  group('the sermon library cluster stays quarantined', () {
    // The three page classes' own files, plus the widget/model/service
    // they depend on. Not scanned: a file in this list may freely
    // construct another file in this list.
    const clusterFiles = {
      'lib/pages/sermon_library_page.dart',
      'lib/pages/sermon_library_speaker_page.dart',
      'lib/pages/sermon_library_sermon_page.dart',
      'lib/widgets/sermon_library_chrome.dart',
      'lib/models/library_sermon.dart',
      'lib/services/sermon_library_service.dart',
    };

    const guardedConstructors = [
      'SermonLibraryPage(',
      'SermonLibrarySpeakerPage(',
      'SermonLibrarySermonPage(',
    ];

    test(
        'no file under lib/ outside the cluster constructs '
        'SermonLibraryPage, SermonLibrarySpeakerPage or '
        'SermonLibrarySermonPage', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalized = entity.path.replaceAll('\\', '/');
        if (clusterFiles.any((f) => normalized.endsWith(f))) continue;
        final content = entity.readAsStringSync();
        for (final ctor in guardedConstructors) {
          if (content.contains(ctor)) {
            offenders.add('${entity.path} constructs $ctor');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'these files reach into the quarantined sermon library '
              'cluster, which currently has no route and no CI coverage: '
              '$offenders. If this is a deliberate re-entry, the '
              'hasCorpus-gated suites in test/sermon_library_*_test.dart '
              'need to stop skipping on CI before it ships.');
    });

    // The other half of "quarantined, not broken": the service must
    // keep refusing to pretend an absent corpus is an empty one. See
    // SermonLibraryService.load's doc comment for why that is
    // deliberate — a degrade-to-empty here is indistinguishable from
    // a forgotten pubspec.yaml entry from the reader's side.
    test(
        'SermonLibraryService.load throws rather than returning an '
        'empty library when index.json is missing', () async {
      final svc = SermonLibraryService.instance;
      addTearDown(svc.resetForTest);
      svc.useLoader((path) async => throw const FileSystemException(
          'no such asset', 'assets/sermon_library/index.json'));
      await expectLater(svc.load(), throwsA(anything));
    });
  });
}
