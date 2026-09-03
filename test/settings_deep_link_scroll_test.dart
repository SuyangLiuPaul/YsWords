import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/settings_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/widgets/gemini_key_card.dart';

/// Regression test for "`/settings/:section` is an alias for `/settings`"
/// (2026-09-03).
///
/// **What was wrong.** `/#/settings/ai` rendered byte-identically to bare
/// `/#/settings` — same screenshot hash, same accessibility-tree text —
/// so every `/settings/:section` deep link navigated, looked like it had
/// worked, and left the reader at the top of the page. Found by
/// `tools/web_verify_headless.mjs routes`, which cold-loads both and
/// compares.
///
/// **The mechanism, measured rather than assumed.** A `logDiag` probe in
/// `_SettingsPageBodyState`, in a real `flutter build web --release`
/// bundle driven by headless Chrome, printed
///
///     [PROBE] settings initState section=SettingsSection.ai target=true
///     [PROBE] postFrame ctx=false
///
/// The route → `initialSection` plumbing and the `GlobalKey` lookup were
/// both fine; the section had no *element*. `ListView(children: [...])`
/// builds lazily, and `_aiKey` is ~7 000 pt down the list — far outside
/// the viewport plus the default 250 pt cache extent — so the single
/// post-frame `Scrollable.ensureVisible` returned early on a null
/// context and nothing ever scrolled.
///
/// **Why the oracle below is `GeminiKeyCard` and not the word "AI".**
/// The AI section's own copy is the only thing that separates the two
/// pages; a case-insensitive match on "AI" hits "Available", "Main" and
/// half of Settings, and an oracle that passes whether or not the
/// feature works is not one. `GeminiKeyCard` is rendered only inside the
/// AI section, and (this is the load-bearing half) a lazy `ListView`
/// does not build it at all until the viewport reaches it — so
/// `findsOneWidget` here means the list really did scroll, not merely
/// that the widget exists somewhere in a tree.
void main() {
  Widget host(SettingsSection? section) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: MaterialApp(home: SettingsPage(initialSection: section)),
      );

  /// Pre-existing and unrelated: several `ListTile`s further down the
  /// settings page sit inside a decorated container, and Flutter's
  /// debug-only "background color or ink splashes may be invisible"
  /// assertion fires when they are laid out. It fires on `main` too — any
  /// reader who scrolls that far in a debug build trips it — and the only
  /// thing this change did was make those sections reachable from a
  /// widget test. Release builds compile the assertion out. Filtered here
  /// rather than fixed, so this file stays about the deep-link scroll;
  /// anything else still fails the test.
  ///
  /// Must be called from INSIDE the test body: `TestWidgetsFlutterBinding`
  /// installs its own `FlutterError.onError` when it starts running the
  /// body, so a `setUp` hook would be overwritten before the first pump.
  void ignoreKnownListTileInkWarning() {
    const known =
        'ListTile background color or ink splashes may be invisible.';
    final chained = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains(known)) return;
      chained?.call(details);
    };
  }

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('CONTROL — bare /settings opens at the top: the AI section '
      'is not built at all', (tester) async {
    ignoreKnownListTileInkWarning();
    await tester.pumpWidget(host(null));
    await tester.pumpAndSettle();

    expect(find.byType(GeminiKeyCard), findsNothing,
        reason: 'bare /settings must open at the top of the page — if the '
            'AI card is built here the control is meaningless and the '
            'deep-link assertion below proves nothing');
  });

  testWidgets('/settings/ai scrolls the AI section into view', (tester) async {
    ignoreKnownListTileInkWarning();
    await tester.pumpWidget(host(settingsSectionForSlug('ai')));
    await tester.pumpAndSettle();

    expect(find.byType(GeminiKeyCard), findsOneWidget,
        reason: 'the AI section never came into view — this is the exact '
            'failure the headless harness reported as "/settings/ai '
            'renders identically to /settings"');

    // On screen, not merely built: `ensureVisible` is supposed to land
    // the section header just below the AppBar, so the card under it has
    // to be inside the viewport.
    final card = tester.getRect(find.byType(GeminiKeyCard));
    final screen = tester.getRect(find.byType(MaterialApp));
    expect(card.top, lessThan(screen.bottom),
        reason: 'the AI card was built but sits below the fold');
    expect(card.bottom, greaterThan(screen.top),
        reason: 'the AI card was built but sits above the fold');
  });

  testWidgets('the widened cache extent is temporary — the list is lazy '
      'again once the deep-link scroll has landed', (tester) async {
    ignoreKnownListTileInkWarning();
    await tester.pumpWidget(host(settingsSectionForSlug('ai')));
    await tester.pumpAndSettle();

    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.scrollCacheExtent, isNull,
        reason: 'the whole-page cache extent is a one-shot for finding the '
            'deep-link target; leaving it on would keep every settings '
            'section laid out for the rest of the session');
  });

  testWidgets('every section slug actually reaches a scrollable target',
      (tester) async {
    ignoreKnownListTileInkWarning();
    // Not just `ai`. A section added later with a slug but no
    // `KeyedSubtree` would deep-link to nothing, and the bounded retry
    // in `_scrollToInitialSection` would (correctly) give up silently —
    // which is exactly the kind of silent wrongness this whole item is
    // about. Pumping each one and settling proves the callback
    // terminates for all of them; a missing key would show up as a
    // timeout in `pumpAndSettle`, not as a pass.
    for (final section in SettingsSection.values) {
      await tester.pumpWidget(host(section));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'section $section threw');
    }
  });
}
