import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/dashboard_section.dart';

/// 2026-08-25, from the user: "设置里面的主页布局的位置和主页真实位置是不
/// 一样的，这个不是应该一致吗".
///
/// It was not an ordering bug — Settings and the dashboard both walk
/// `AppSettings.dashboardSectionOrder`, so the sequence cannot diverge.
/// The mismatch was that `dashboard_page.dart::_buildSection` returns null
/// for a section with nothing to show, so on a fresh install Settings
/// listed eight rows with every switch on and the home page rendered six,
/// with nothing anywhere saying why.
void main() {
  test('the order Settings shows is the order the dashboard walks', () {
    // Both screens read AppSettings.dashboardSectionOrder, and
    // normalizeDashboardOrder is the only thing that produces it. If it
    // ever returned a different sequence for the same input, or dropped or
    // duplicated a section, the two screens would genuinely disagree.
    final fromDefault =
        normalizeDashboardOrder([for (final s in defaultDashboardOrder) s.name]);
    expect(fromDefault, defaultDashboardOrder);

    // Stable: normalising an already-normal list changes nothing.
    expect(normalizeDashboardOrder([for (final s in fromDefault) s.name]),
        fromDefault);

    // Complete and duplicate-free from junk input, so neither screen can
    // be handed a list the other would not produce.
    final messy = normalizeDashboardOrder(
        ['quickLinks', 'quickLinks', 'nonsense', 'featured']);
    expect(messy.toSet(), DashboardSection.values.toSet());
    expect(messy.length, DashboardSection.values.length);
    // The relative order the user actually chose survives the backfill.
    // Where the sections they never had land is the algorithm's business
    // (it inserts each before the nearest following default that is
    // present); what must not happen is their own two swapping.
    expect(messy.indexOf(DashboardSection.quickLinks),
        lessThan(messy.indexOf(DashboardSection.featured)));
  });

  test('a user-visible order is always complete, so nothing is unreachable',
      () {
    expect(defaultDashboardOrder.toSet(), DashboardSection.values.toSet());
    expect(defaultDashboardOrder.length, DashboardSection.values.length);
    expect(defaultVisibility.keys.toSet(), DashboardSection.values.toSet());
  });

  group('sections that can be on but absent explain themselves', () {
    test('exactly the two durable ones are flagged', () {
      // dailyVerse and todayEvidence also return null while loading, but
      // that is a transient state, not "you have none of these" — a
      // caption for them would stop being true before it was read.
      final flagged =
          DashboardSection.values.where((s) => s.hidesWhenEmpty).toSet();
      expect(flagged, {
        DashboardSection.resumeSermon,
        DashboardSection.recentBookmarks,
      });
    });

    test('each flagged section has a reason string in every locale', () {
      for (final s in DashboardSection.values.where((s) => s.hidesWhenEmpty)) {
        final entry = uiStrings[s.emptyReasonKey];
        expect(entry, isNotNull,
            reason: '${s.name} is flagged but has no ${s.emptyReasonKey}');
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(entry![locale], isNotNull, reason: '${s.name} / $locale');
          expect(entry[locale], isNotEmpty, reason: '${s.name} / $locale');
        }
      }
    });

    test('the card-level hint exists in every locale', () {
      final hint = uiStrings['dashboardLayoutEmptyHint'];
      expect(hint, isNotNull);
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expect(hint![locale], isNotEmpty, reason: locale);
      }
    });

    test('an unflagged section has no orphan reason string', () {
      // Guards the other direction: dropping a section from hidesWhenEmpty
      // without removing its string would leave text nothing can show.
      for (final s in DashboardSection.values.where((s) => !s.hidesWhenEmpty)) {
        expect(uiStrings[s.emptyReasonKey], isNull,
            reason: '${s.name} has a reason string but is never flagged');
      }
    });
  });
}
