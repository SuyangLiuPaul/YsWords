// A phone can now keep the verse image, and the button says which way.
//
// 2026-09-15. 「另外saving image verse image可以有save to local image吗？」
// — it could not. `getDownloadsDirectory()` returns null on iOS and
// Android by path_provider's own contract, which was the whole native
// story, so the sheet swapped the Save button for "take a screenshot".
// Answered 「两个都加」: `gal` for the photo library, `share_plus` for the
// OS share sheet.
//
// What is asserted here is the CONTRACT between the outcomes and what
// the reader is told, plus the platform configuration that makes the
// save possible at all — because the iOS half of that configuration
// fails in a way no Dart test can see: a missing
// NSPhotoLibraryAddUsageDescription does not make the save fail, it
// makes iOS terminate the app.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/services/verse_card_export_types.dart';

const _locales = ['zh-Hans', 'zh-Hant', 'en'];

void main() {
  test('every outcome the reader can reach has words in all three '
      'locales', () {
    // The enum and the messages are in different files, so a new
    // outcome added without a string shows the reader an empty toast.
    const wording = <VerseCardDelivery, String?>{
      VerseCardDelivery.shared: 'verseCardShared',
      VerseCardDelivery.downloaded: 'verseCardDownloaded',
      VerseCardDelivery.openedInTab: 'verseCardOpenedInTab',
      VerseCardDelivery.savedToFile: 'verseCardSavedTo',
      VerseCardDelivery.savedToPhotos: 'verseCardSavedToPhotos',
      VerseCardDelivery.photosDenied: 'verseCardPhotosDenied',
      VerseCardDelivery.unavailable: 'verseCardScreenshotHint',
      VerseCardDelivery.failed: 'verseCardFailed',
      // The reader dismissed the share sheet. They know; saying so
      // would be the app talking about itself.
      VerseCardDelivery.cancelled: null,
    };

    expect(wording.keys.toSet(), VerseCardDelivery.values.toSet(),
        reason: 'an outcome was added or removed without deciding what '
            'the reader is told');

    for (final entry in wording.entries) {
      final key = entry.value;
      if (key == null) continue;
      final table = uiStrings[key];
      expect(table, isNotNull, reason: '${entry.key.name} → $key is missing');
      for (final locale in _locales) {
        expect((table![locale] ?? '').isNotEmpty, isTrue,
            reason: '${entry.key.name} → $key has no $locale');
      }
    }
  });

  test('saving to photos and saving to a file are told apart', () {
    // They must never be collapsed: one has a path to name and the
    // other does not, and a reader sent to Files for a picture that is
    // in Photos has been actively misled.
    for (final locale in _locales) {
      final photos = uiStrings['verseCardSavedToPhotos']![locale]!;
      final file = uiStrings['verseCardSavedTo']![locale]!;
      expect(photos, isNot(file));
      expect(file, contains('{path}'),
          reason: 'the file message names where it went');
      expect(photos, isNot(contains('{path}')),
          reason: 'there is no path for a photo-library save, and a '
              'placeholder left unfilled would print literally');
    }
  });

  test('the denial message sends the reader to the right place', () {
    // Permission is theirs to grant and the remedy is in the OS, not
    // in this app, so the wording has to point out of the app.
    for (final locale in _locales) {
      final text = uiStrings['verseCardPhotosDenied']![locale]!;
      final pointsOut = text.contains('设置') ||
          text.contains('設定') ||
          text.toLowerCase().contains('settings');
      expect(pointsOut, isTrue,
          reason: 'the $locale denial message does not tell the reader '
              'where to fix it: "$text"');
    }
  });

  group('the platform configuration the save depends on', () {
    test('iOS declares the ADD usage description, not just the read one',
        () {
      // Two different keys. iOS TERMINATES the app when the matching
      // one is absent rather than refusing the call, so this omission
      // would not look like a failed save — it would look like the app
      // vanishing the first time anyone tried.
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('NSPhotoLibraryAddUsageDescription'),
          reason: 'gal writes to the library and iOS will kill the app '
              'without this key');
      expect(plist, contains('NSPhotoLibraryUsageDescription'),
          reason: 'image_picker reads from it and still needs its own');
    });

    test('Android covers the releases below scoped storage, and only '
        'those', () {
      // API 29+ needs no permission. minSdk is 24, so 24-28 still do —
      // and `maxSdkVersion` is what stops a modern device being asked
      // for a broad storage grant, which would show up in the Play
      // listing for every user.
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('WRITE_EXTERNAL_STORAGE'));
      expect(
          RegExp(r'WRITE_EXTERNAL_STORAGE[\s\S]{0,120}maxSdkVersion="28"')
              .hasMatch(manifest),
          isTrue,
          reason: 'the write permission is not capped at 28, so every '
              'modern install asks for storage it does not need');
    });

    test('macOS targets at least what the plugins demand', () {
      // 2026-09-15: the v1.6.8 macOS release build failed on exactly
      // this. `gal` declares 11.0 and `pod install` refuses the whole
      // build rather than skipping the plugin — and nothing in Dart can
      // see it, so the first sign was a red release workflow AFTER the
      // tag had gone up and the other four platforms had shipped.
      //
      // Both files, because they disagree silently: the Podfile governs
      // pod resolution and the pbxproj governs the app target, and
      // raising one without the other fails later and less clearly.
      final podfile = File('macos/Podfile').readAsStringSync();
      final project =
          File('macos/Runner.xcodeproj/project.pbxproj').readAsStringSync();

      final pod =
          RegExp("platform :osx, '(\\d+)\\.(\\d+)'").firstMatch(podfile);
      expect(pod, isNotNull, reason: 'the Podfile names no macOS platform');
      expect(int.parse(pod!.group(1)!), greaterThanOrEqualTo(11),
          reason: 'gal needs macOS 11.0; pod install refuses the build '
              'below it');

      expect(project, isNot(contains('MACOSX_DEPLOYMENT_TARGET = 10.')),
          reason: 'the Xcode target still says 10.x while the Podfile '
              'says 11 — they have to move together');
      expect(project, contains('MACOSX_DEPLOYMENT_TARGET = 11.'),
          reason: 'the app target does not declare macOS 11');
    });

    test('both plugins are pinned in the lockfile', () {
      final lock = File('pubspec.lock').readAsStringSync();
      expect(lock, contains('  gal:'));
      expect(lock, contains('  share_plus:'));
    });
  });
}
