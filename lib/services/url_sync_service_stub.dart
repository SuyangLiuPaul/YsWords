// Stub implementation of `UrlSyncService` for non-web targets.
// Native builds (Android / iOS / desktop) don't have a URL bar,
// so the URL sync layer is a no-op. Same public API as the web
// impl so the conditional import in `url_sync_service.dart`
// type-checks on every platform.

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';

Future<void> urlSyncInit({
  required MainProvider mainProvider,
  required AppSettings appSettings,
}) async {
  // Native targets: no URL bar, nothing to sync. Return immediately.
  return;
}

/// Native targets: no URL bar, nothing to capture.
void captureBootHash() {}

/// Native targets: boot deep links don't exist; never fires.
void setBootDeepLinkCallback(void Function() cb) {}

/// Native targets: no URL to restore.
void onRouteChanged() {}
