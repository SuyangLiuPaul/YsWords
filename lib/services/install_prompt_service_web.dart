/// Web implementation of the install-prompt service. Reads
/// `window.yswordsInstall` (set up by `web/index.html`) to detect
/// whether the user is already installed AND whether Chrome /
/// Edge has fired `beforeinstallprompt`.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'package:yswords/services/install_prompt_service.dart';

@JS('yswordsInstall')
external _YsInstall? get _yswordsInstall;

@JS()
@staticInterop
class _YsInstall {}

extension _YsInstallExt on _YsInstall {
  external bool get available;
  external bool get isStandalone;
  external JSPromise<JSString> show();
}

InstallFlowKind detect() {
  final bridge = _yswordsInstall;
  if (bridge != null && bridge.isStandalone) {
    return InstallFlowKind.alreadyInstalled;
  }
  if (bridge != null && bridge.available) {
    return InstallFlowKind.nativePrompt;
  }
  // Decide between iOS Safari and other web by sniffing the UA.
  // `beforeinstallprompt` never fires on iOS Safari — we have to
  // tell the user to use the Share sheet.
  String ua = '';
  try {
    ua = web.window.navigator.userAgent;
  } catch (_) {/* ignore */}
  final isIos = ua.contains('iPhone') ||
      ua.contains('iPad') ||
      ua.contains('iPod') ||
      // iPadOS 13+ identifies as Mac with touch support.
      (ua.contains('Macintosh') && _hasTouch());
  if (isIos) return InstallFlowKind.iosManual;
  return InstallFlowKind.desktopManual;
}

bool _hasTouch() {
  try {
    return web.window.navigator.maxTouchPoints > 0;
  } catch (_) {
    return false;
  }
}

Future<String> show() async {
  final bridge = _yswordsInstall;
  if (bridge == null) return 'unavailable';
  try {
    final result = await bridge.show().toDart;
    return result.toDart;
  } catch (_) {
    return 'dismissed';
  }
}
