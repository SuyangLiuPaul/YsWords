import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/ui_strings.dart';

/// The reading-plan feature is gone; nothing may promise it again.
///
/// It was deleted in v1.2.69 (2026-05-21) — `assets/reading_plans.json`
/// and `lib/services/reading_plan_service.dart` both went in the same
/// commit. What did NOT go was everything that pointed at them: 22
/// translated strings with no caller, a "Pick a reading plan" sentence
/// in the live onboarding tour, a `featureList` entry in the landing
/// page's JSON-LD, a profile-delete dialog offering to erase reading
/// progress, and a build-flag doc telling China-build readers that
/// reading plans worked 100% offline. Four months of readers were told
/// about a feature that no build of the app has ever shipped since.
///
/// That gap existed because the removal was reviewed as a diff — the
/// deleted files were obviously gone — rather than as a question about
/// what the app still says. This test asks the second question, and it
/// is a source scan rather than a widget test on purpose: the defect
/// was never in behaviour, it was in text that had no code path left to
/// reach.
///
/// Comment lines are deliberately exempt. The comments that survive the
/// cleanup are the record of WHY these things are absent, and a guard
/// that forbade the word everywhere would make the removal
/// undocumentable.
void main() {
  // Every spelling a promise has actually taken in this tree, plus the
  // two plan names the old copy advertised by name.
  final promises = <RegExp>[
    RegExp(r'reading[ \-]?plan', caseSensitive: false),
    RegExp('读经计划'),
    RegExp('讀經計劃'),
    RegExp('读经进度'),
    RegExp('讀經進度'),
    RegExp(r'plan\.completed'),
    RegExp('McCheyne', caseSensitive: false),
    RegExp('麦琴'),
    RegExp('麥琴'),
  ];

  /// Drop whole-line Dart comments. Only leading `//` counts, so a
  /// `https://` inside a string literal is still scanned.
  String stripDartComments(String source) => source
      .split('\n')
      .map((line) => line.trimLeft().startsWith('//') ? '' : line)
      .join('\n');

  String stripHtmlComments(String source) =>
      source.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  String? firstPromiseIn(String text) {
    for (final line in text.split('\n')) {
      for (final p in promises) {
        if (p.hasMatch(line)) return line.trim();
      }
    }
    return null;
  }

  test('no Dart source outside comments mentions a reading plan', () {
    final offenders = <String, String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final hit = firstPromiseIn(stripDartComments(entity.readAsStringSync()));
      if (hit != null) offenders[entity.path] = hit;
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Reading plans were removed in v1.2.69. A live string, '
          'identifier or key naming them means the app is describing a '
          'feature a reader cannot reach. If this is a deliberate '
          'rebuild, delete this test in the same change that restores '
          'the service — do not silence it.',
    );
  });

  test('the landing page does not advertise reading plans', () {
    // web/index.html carries the JSON-LD `featureList` that search
    // engines quote, so a stale entry here is read by people who have
    // not installed the app at all.
    final hit = firstPromiseIn(
        stripHtmlComments(File('web/index.html').readAsStringSync()));
    expect(hit, isNull,
        reason: 'The landing page and its structured data list what the '
            'app can do; reading plans are not on that list.');
  });

  test('the deleted reading-plan translation keys are still deleted', () {
    // The Round 26 block plus the four strays that outlived their own
    // call sites. Named individually rather than matched by prefix so a
    // re-add cannot slip in under a different naming scheme and still
    // pass.
    const deleted = <String>[
      'tabPlan',
      'readingPlans',
      'todayReading',
      'planDayLabel',
      'planChooseActive',
      'planNoActive',
      'planActive',
      'planStartDate',
      'planUseCalendarDate',
      'planUseCalendarDateSub',
      'planResetProgress',
      'planResetProgressConfirm',
      'planMarkDone',
      'planMarkUndone',
      'planJumpToToday',
      'planProgress',
      'planNone',
      'planLibraryEmpty',
      'planHomeHint',
      'planHomeHintSub',
      'settingsSectionPlan',
      'settingsShowPlanHint',
      'onboardPlansTitle',
      'onboardPlansBody',
      'dashboardSection_todayReading_label',
      'dashboardSection_todayReading_description',
    ];
    expect(deleted.where(uiStrings.containsKey), isEmpty,
        reason: 'These keys had zero callers for four months while '
            'reading as shipped copy. Re-adding one means the tour, the '
            'Settings list or the dashboard editor is about to offer a '
            'plan again.');
  });

  test('no sync layer still carries a plan key across the wire', () {
    // Both sync services used to list `plan.activeId` / `plan.startMs`
    // / `plan.useDate` and sweep `plan.completed.*`. RealtimeDbSync
    // dropped them in v1.3.45 — its dotted key names were rejected
    // outright by RTDB, which broke EVERY sync write for anyone who
    // still had a stale value. CloudSyncService (Firestore, no longer
    // init'd) kept them until 2026-09-08 because that fix was scoped to
    // the service the bug bit. One test now covers both.
    for (final path in const [
      'lib/services/cloud_sync_service.dart',
      'lib/services/realtime_db_sync_service.dart',
    ]) {
      final source = stripDartComments(File(path).readAsStringSync());
      expect(RegExp(r"'plan\.").hasMatch(source), isFalse,
          reason: '$path names a plan.* key outside a comment. Nothing '
              'writes those keys any more, and a dotted key is invalid '
              'in RTDB.');
    }
  });
}
