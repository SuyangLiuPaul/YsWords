/// Web platform info for ErrorReporter. Selected via conditional
/// import in `error_reporter.dart`. Pulls user-agent + screen size
/// from the DOM via `package:web` (already a transitive dep — see
/// pubspec.yaml's `web: ^1.0.0` line).
library;

import 'package:web/web.dart' as web;

String get platformName => 'web';

Map<String, dynamic> collectDeviceInfo() {
  String screen = '';
  double? dpr;
  String ua = '';
  String os = '';
  try {
    final w = web.window.screen.width;
    final h = web.window.screen.height;
    screen = '${w}x$h';
  } catch (_) {/* ignore */}
  try {
    dpr = web.window.devicePixelRatio.toDouble();
  } catch (_) {/* ignore */}
  try {
    ua = web.window.navigator.userAgent;
    // Best-effort OS hint extracted from the UA string for skim-
    // ability; the full UA is still in the payload for precision.
    if (ua.contains('iPhone') || ua.contains('iPad')) {
      os = 'iOS';
    } else if (ua.contains('Mac OS X')) {
      os = 'macOS';
    } else if (ua.contains('Android')) {
      os = 'Android';
    } else if (ua.contains('Windows')) {
      os = 'Windows';
    } else if (ua.contains('Linux')) {
      os = 'Linux';
    }
  } catch (_) {/* ignore */}
  return {
    'screen': screen,
    'os': os,
    'dpr': dpr,
    'ua': ua,
  };
}
