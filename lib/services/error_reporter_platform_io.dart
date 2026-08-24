/// Native platform info for ErrorReporter — iOS / Android /
/// macOS / Linux / Windows. Selected via conditional import in
/// `error_reporter.dart`.
///
/// We deliberately avoid the `device_info_plus` plugin to keep
/// the dependency footprint small. The 3 fields we collect
/// (operating system name, OS version, locale-derived dpr) are
/// already exposed by `dart:io` + `dart:ui`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:yswords/utils/synthetic_device.dart';

String get platformName {
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  if (Platform.isWindows) return 'windows';
  if (Platform.isFuchsia) return 'fuchsia';
  return 'unknown';
}

Map<String, dynamic> collectDeviceInfo() {
  String screen = '';
  double? dpr;
  try {
    final view = ui.PlatformDispatcher.instance.views.first;
    final w = view.physicalSize.width / view.devicePixelRatio;
    final h = view.physicalSize.height / view.devicePixelRatio;
    screen = '${w.round()}x${h.round()}';
    dpr = view.devicePixelRatio;
  } catch (_) {/* ignore — screen info is best-effort */}
  return {
    'screen': screen,
    'os': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    'dpr': dpr,
    'ua': '', // native has no user-agent equivalent
  };
}

/// True on a developer emulator/simulator, false on a real device.
/// `ErrorReporter._send` drops reports when this is set — see
/// `utils/synthetic_device.dart` for why.
///
/// iOS and macOS: the Simulator is the only context that sets
/// `SIMULATOR_DEVICE_NAME`, and it is set for the whole process, so no
/// plugin is needed. Android: read off the build fingerprint.
bool get isSyntheticDevice {
  try {
    if (Platform.isIOS || Platform.isMacOS) {
      return Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');
    }
    if (Platform.isAndroid) {
      return isSyntheticAndroidOs(Platform.operatingSystemVersion);
    }
  } catch (_) {/* best-effort: if we cannot tell, assume real */}
  return false;
}
