import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/clipboard_helper.dart';

/// Regression tests for the 2026-07-10 prod crash
/// `PlatformException(copy_fail, Clipboard.setData failed.)` (iOS
/// Safari rejecting the async Clipboard API). The contract under test:
/// [ClipboardHelper.copyText] NEVER throws — it returns false when the
/// platform clipboard write fails (on VM there is no web fallback), so
/// no copy path can escalate to the Zone error handler again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('copyText returns true when the platform accepts the write',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    expect(await ClipboardHelper.copyText('hello'), isTrue);
  });

  test(
      'copyText returns false (does NOT throw) when the platform '
      'rejects the write — the iOS Safari copy_fail crash class',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(
            code: 'copy_fail', message: 'Clipboard.setData failed.');
      }
      return null;
    });
    // Must complete with false — an unhandled throw here fails the test.
    expect(await ClipboardHelper.copyText('hello'), isFalse);
  });
}
