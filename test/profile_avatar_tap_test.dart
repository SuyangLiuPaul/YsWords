// 2026-09-03: "The profile photo: should it be tappable?"
//
// User, 2026-08-16, asking for an opinion as much as a feature. The
// answer taken: tappable everywhere, opening the profile — and for a
// Google-account photo, say where it comes from and link out rather
// than pretending it can be changed in-app.
//
// These tests pin both halves, and they pin them at the real call
// sites, because the failure mode being fixed was never "the avatar
// widget can't be tapped" — it was "nobody wrapped it".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/dashboard_page.dart';
import 'package:yswords/pages/profile_edit_page.dart';
import 'package:yswords/pages/profiles_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/widgets/profile_avatar.dart';

Widget _wrap(Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: GetMaterialApp(
        home: home,
        // pushPage routes '/profiles' through Get.toNamed because it is
        // in kRegisteredRoutePaths, so the table has to exist here for
        // the dashboard tap to land anywhere.
        getPages: [
          GetPage(name: '/profiles', page: () => const ProfilesPage()),
        ],
      ),
    );

/// Frames rather than pumpAndSettle: these pages kick off async prefs
/// and asset loads that would keep pumpAndSettle waiting forever.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

/// The locale the widget under [finder] actually rendered in.
String _localeOf(WidgetTester tester, Finder finder) =>
    Provider.of<AppSettings>(tester.element(finder), listen: false).locale;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileAvatar carries the affordance', () {
    testWidgets('with onTap it is a labelled button that fires', (tester) async {
      var taps = 0;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: ProfileAvatar(
              photoUrl: null,
              name: 'Peter',
              tapLabel: 'Open profile',
              onTap: () => taps++,
            ),
          ),
        ),
      ));

      expect(find.byType(InkWell), findsOneWidget);
      // A RegExp, not the bare string: the avatar's own initial merges
      // into the same semantics node, so the announced label is
      // "Open profile" plus the letter. Containment is the property
      // that matters — the control is named.
      expect(
        find.bySemanticsLabel(RegExp('Open profile')),
        findsOneWidget,
        reason: 'the circle has no text of its own — without a label a '
            'screen reader announces an unnamed button',
      );

      await tester.tap(find.byType(ProfileAvatar));
      await tester.pump();
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('without onTap it stays inert and unannounced',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(child: ProfileAvatar(photoUrl: null, name: 'Peter')),
        ),
      ));
      expect(find.byType(InkWell), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Open profile')), findsNothing);
      handle.dispose();
    });
  });

  group('tapping the avatar opens the profile, at every site', () {
    testWidgets('Dashboard greeting avatar → Profiles', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'onboarding.seen.v3': true,
      });
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      addTearDown(Get.reset);

      await tester.pumpWidget(_wrap(const DashboardPage()));
      await _settle(tester);

      expect(find.byType(ProfilesPage), findsNothing);

      final avatar = find.byType(ProfileAvatar);
      expect(avatar, findsOneWidget,
          reason: 'the dashboard greeting avatar is the site this change '
              'exists for — it was the one that did nothing');
      await tester.tap(avatar);
      await _settle(tester);

      expect(find.byType(ProfilesPage), findsOneWidget);
    });

    testWidgets('Profiles row avatar → that profile\'s editor',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await ProfileService.instance.init();
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      addTearDown(Get.reset);

      await tester.pumpWidget(_wrap(const ProfilesPage()));
      await _settle(tester);

      expect(find.byType(ProfileEditPage), findsNothing);

      // The ACTIVE row is the one whose ListTile.onTap is null — the
      // face most likely to be tapped was the one guaranteed to do
      // nothing. Its avatar must now go somewhere.
      final avatar = find.descendant(
        of: find.byType(ListTile).first,
        matching: find.byType(CircleAvatar),
      );
      expect(avatar, findsOneWidget);
      await tester.tap(avatar);
      await _settle(tester);

      expect(find.byType(ProfileEditPage), findsOneWidget);
    });
  });

  group('a Google photo explains itself instead of faking an edit', () {
    testWidgets('provenance and an outbound link, and no photo editor',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await ProfileService.instance.init();
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const ProfileEditPage(
        debugGooglePhotoUrl: 'https://example.invalid/photo.jpg',
      )));
      await _settle(tester);

      // Assert against the strings for whatever locale the page
      // actually rendered in, rather than assuming English — the app
      // defaults to zh-Hans and this behaviour has to hold in all
      // three locales, not just the one the assertion was written in.
      final locale = _localeOf(tester, find.byType(ProfileEditPage));
      String s(String key) => uiStrings[key]![locale]!;

      // Where it comes from.
      expect(find.text(s('photoFromGoogle')), findsOneWidget);
      // Why it isn't editable here, and what to do instead.
      expect(find.text(s('photoFromGoogleDetail')), findsOneWidget);
      // The way out.
      expect(find.text(s('photoChangeInGoogle')), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);

      // And crucially NOT an edit affordance for a photo this app
      // cannot touch. A control that looks editable and is not is
      // worse than one that explains itself.
      expect(find.text(s('setPhoto')), findsNothing);
      expect(find.text(s('changePhoto')), findsNothing);
      expect(find.text(s('removePhoto')), findsNothing);
    });

    testWidgets('a local photo keeps the local controls and gains no notice',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await ProfileService.instance.init();
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const ProfileEditPage()));
      await _settle(tester);

      final locale = _localeOf(tester, find.byType(ProfileEditPage));
      expect(find.text(uiStrings['photoFromGoogle']![locale]!), findsNothing);
      expect(
          find.text(uiStrings['photoChangeInGoogle']![locale]!), findsNothing);
    });
  });
}
