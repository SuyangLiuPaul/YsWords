import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/synthetic_device.dart';

void main() {
  group('isSyntheticAndroidOs', () {
    // The exact string off the emulator that mailed the user four
    // SQLITE_BUSY reports on 2026-08-24/25. If this one ever stops
    // matching, the inbox floods again.
    const theEmulatorThatSpammedUs =
        'android sdk_phone64_arm64-userdebug 14 UE1A.230829.036.A1 112288';

    test('the emulator that actually mailed the user is caught', () {
      expect(isSyntheticAndroidOs(theEmulatorThatSpammedUs), isTrue);
    });

    test('other developer builds are caught', () {
      for (final os in const [
        'android sdk_gphone64_arm64-userdebug 14 UE1A.230829.036 1',
        'android generic_x86_64-eng 13 TP1A.220624.014 eng.build',
        'android emulator64_arm64-userdebug 12 SP1A.210812.016 7550983',
        'ANDROID SDK_PHONE_X86-USERDEBUG 11 RSR1.201013.001 1',
      ]) {
        expect(isSyntheticAndroidOs(os), isTrue, reason: os);
      }
    });

    test('real shipping devices are NOT caught', () {
      // -user (not -userdebug) is the shipping build type. These are the
      // devices the user actually reports from; a false positive here
      // silences a real crash, which is the expensive direction.
      for (final os in const [
        // Xiaomi Pad 7 Ultra — the Mi Pad in the bug reports.
        'android aristotle-user 15 AQ3A.240912.001 V816.0.11.0.WOACNXM',
        'android raven-user 14 UP1A.231005.007 10754064',
        'android beyond1lte-user 12 SP1A.210812.016 G973FXXUEFVK1',
        'android sunfish-user 13 TQ3A.230805.001 10316531',
      ]) {
        expect(isSyntheticAndroidOs(os), isFalse, reason: os);
      }
    });

    test('a device whose model merely contains "user" is not caught', () {
      expect(isSyntheticAndroidOs('android userland-user 14 X 1'), isFalse);
    });

    test('empty and junk input is treated as a real device', () {
      // If we cannot tell, mail the report: a missed test report costs
      // one email, a missed real report costs a user's crash.
      expect(isSyntheticAndroidOs(''), isFalse);
      expect(isSyntheticAndroidOs('unknown'), isFalse);
    });
  });
}
