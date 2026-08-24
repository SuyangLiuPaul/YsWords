import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-08-24: on Android the app was booting TWICE.
///
/// `AudioServicePlugin.onAttachedToActivity` calls
/// `getFlutterEngine(activity)`, which looks the engine up in
/// `FlutterEngineCache` under `"audio_service_engine"` and, on a miss,
/// builds a new `FlutterEngine` and calls
/// `executeDartEntrypoint(DartEntrypoint.createDefault())` — i.e. runs
/// `main()` again in a second isolate. `AudioServiceActivity` is the
/// FlutterActivity subclass whose `provideFlutterEngine` returns that
/// cached engine; a plain `FlutterActivity` provides its own, so the
/// cache is always empty and the second engine is always created.
///
/// Measured on an emulator with a marker at the top of `main()`, before
/// the fix: two boot lines from ONE pid (isolates 117306759 and
/// 118841876), plus
/// `IllegalStateException: The Activity class declared in your
/// AndroidManifest.xml is wrong or has not provided the correct
/// FlutterEngine` at `AudioServicePlugin.java:460` and
/// `[SongPlayerService] media session unavailable: PlatformException(...)`.
/// After it: one boot line and no exception.
///
/// So the defect cost two things at once — a whole duplicate app boot,
/// and the Android media session, which is the entire reason
/// audio_service was added ("listen while driving": lock-screen controls
/// and a foreground service that survives backgrounding).
///
/// This is pinned by reading the source because no Dart test can
/// exercise Kotlin. The property that matters is the superclass.
void main() {
  final mainActivity = File(
    'android/app/src/main/kotlin/com/example/yswords/MainActivity.kt',
  );

  test('MainActivity extends AudioServiceActivity, not FlutterActivity',
      () async {
    expect(mainActivity.existsSync(), isTrue,
        reason: 'MainActivity.kt moved — update this guard');
    final src = await mainActivity.readAsString();

    expect(
      RegExp(r'class\s+MainActivity\s*:\s*AudioServiceActivity\s*\(')
          .hasMatch(src),
      isTrue,
      reason: 'A plain FlutterActivity makes audio_service build a second '
          'FlutterEngine and run main() again in a second isolate.',
    );
    expect(
      src.contains('com.ryanheise.audioservice.AudioServiceActivity'),
      isTrue,
      reason: 'the superclass must be imported by its full package name '
          'so this guard cannot pass on a same-named local class',
    );
    expect(
      RegExp(r'class\s+MainActivity\s*:\s*FlutterActivity').hasMatch(src),
      isFalse,
    );
  });

  test('the AudioService service is still declared in the manifest', () async {
    // Without the <service> element audio_service reports a different
    // failure ("Unable to bind to AudioService"), which would look like
    // this defect coming back while having a different cause.
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest.contains('com.ryanheise.audioservice.AudioService'), isTrue);
    expect(manifest.contains('android:foregroundServiceType="mediaPlayback"'),
        isTrue);
  });

  test('no android:process splits the app across OS processes', () async {
    // Two OS processes would put two sqlite connections on
    // audio_service's artwork cache db for real, which is a separate way
    // to get the SQLITE_BUSY the user reported.
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest.contains('android:process'), isFalse);
  });
}
