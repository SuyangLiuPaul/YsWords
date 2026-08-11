import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/dashboard_section.dart';

/// A section shipped after the user already has a saved layout must
/// land where the default order says, not at the bottom.
///
/// 2026-08-11. `featured` was added above `todayEvidence` in
/// [defaultDashboardOrder] and the user asked, correctly, to confirm
/// that is where it appears. On a fresh install it was. On theirs it
/// would not have been: `normalizeDashboardOrder` appended anything
/// missing to the END, so every existing user would have found the new
/// block under the quick links at the very bottom — and the stated
/// default would have described nobody who had opened the app before.
void main() {
  test('a fresh install gets the default order verbatim', () {
    expect(normalizeDashboardOrder(const []), defaultDashboardOrder);
  });

  test('a new section lands above the block it precedes by default', () {
    // A layout saved before `featured` existed.
    final stored = [
      for (final s in defaultDashboardOrder)
        if (s != DashboardSection.featured) s.name,
    ];
    final out = normalizeDashboardOrder(stored);

    expect(out.indexOf(DashboardSection.featured),
        lessThan(out.indexOf(DashboardSection.todayEvidence)),
        reason: 'featured must sit above Today\'s Evidence, which is the '
            'position that was promised');
    expect(out.last, isNot(DashboardSection.featured),
        reason: 'appending to the end is the bug this pins');
  });

  test("a user's own reordering is preserved when sections are merged in",
      () {
    // The guarantee is RELATIVE order among the sections the user
    // actually arranged — not their absolute positions. A merged-in
    // section anchors to its default neighbours, so it can land above
    // something the user had moved up; what must never happen is their
    // sequence being reshuffled or a section going missing.
    final stored = [
      DashboardSection.todayEvidence.name,
      DashboardSection.readBible.name,
      DashboardSection.dailyVerse.name,
    ];
    final out = normalizeDashboardOrder(stored);

    expect(out.indexOf(DashboardSection.todayEvidence),
        lessThan(out.indexOf(DashboardSection.readBible)));
    expect(out.indexOf(DashboardSection.readBible),
        lessThan(out.indexOf(DashboardSection.dailyVerse)));
    expect(out.toSet(), DashboardSection.values.toSet(),
        reason: 'every section must appear exactly once');
    expect(out.length, DashboardSection.values.length);
  });

  test('unknown and duplicate stored names are dropped', () {
    final out = normalizeDashboardOrder([
      'readBible',
      'readBible',
      'aSectionWeRemovedInSomeOldRelease',
    ]);
    expect(out.first, DashboardSection.readBible);
    expect(out.length, DashboardSection.values.length);
    expect(out.toSet().length, out.length);
  });

  test('every section has a default visibility entry', () {
    // Step 6 of the checklist in dashboard_section.dart — easy to skip,
    // and the fallback would silently decide it for you.
    for (final s in DashboardSection.values) {
      expect(defaultVisibility.containsKey(s), isTrue,
          reason: '${s.name} has no defaultVisibility entry');
    }
  });
}
