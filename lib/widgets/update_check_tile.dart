// 2026-06-16 (v1.3.88): "Check for updates" button for the About page.
//
// Native-only (Android / Windows / macOS / Linux / iOS): asks GitHub for
// the latest release via [UpdateService], then shows a dialog — either
// "you're up to date" or "vX.Y.Z is available" with a Download button that
// opens the right release asset for this platform via [LinkOpener]. On web
// it renders nothing (the PWA is always current). Manages its own loading
// state; every context use after an await is `mounted`-guarded.
//
// 2026-09-08: this file now holds both halves of the About page's
// update controls — the manual button below and [AutoUpdateCheckToggle]
// at the bottom, which switches the once-a-day check on. They live
// together because they share one platform gate, and a reader must
// never see one without the other.
//
// 2026-09-09 (review finding 7): the in-app install flow lives here as
// TOP-LEVEL functions rather than as methods of the tile, because the
// tile is not where most readers meet an update. The dashboard's daily
// bar is, and it was still sending Android readers out to the browser
// while the About page offered a button that installs in place. One
// flow, two doors: [installUpdateInApp], [showUpdateAvailableDialog]
// and [buildUpdateAvailableBar] are called from both.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/app_update_installer.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/update_service.dart';

String _s(String locale, String key, String fallback) =>
    uiStrings[key]?[locale] ?? fallback;

/// Whether 「立即更新」 can honestly be offered for [info] on this build.
///
/// Three conditions and all are needed: the platform can install
/// (Android alone — see [AppUpdateInstaller]), the release actually has
/// an APK — see [UpdateInfo.hasApk] for the window in which the newest
/// release has only its own web page — AND that APK is an update to
/// THIS app rather than a different one.
///
/// 2026-09-09 (remediation): the third condition is why this is a
/// `Future`. `release-android.yml` attaches only the `intl` APK, and
/// the `cn` flavour runs as `com.example.yswords.cn`; installing the
/// one into the other is not an update but a second app on the home
/// screen. Only the platform side knows which build this is, so the
/// question costs one channel hop — asked once, before either door
/// opens, rather than in a `build` method.
Future<bool> canInstallInApp(UpdateInfo info) async {
  if (!AppUpdateInstaller.isSupported || !info.hasApk) return false;
  return AppUpdateInstaller.isReleasePackage();
}

/// True from the first tap of 「立即更新」 until the installer is in front
/// of the reader, the download failed, or they stopped it.
///
/// 2026-09-09 (review finding 2): the re-entrancy guard. A second tap
/// while this is set is a no-op — the dialog already on screen IS the
/// download — rather than a second `updateDir` call and a second write
/// stream on the same `update.apk`. It was reachable: Back used to
/// dismiss the progress dialog (finding 1) leaving the download
/// running, and both the About page and Settings mount a Check button.
/// A notifier rather than a bare bool so a button can grey itself out;
/// nothing listens yet.
///
/// 2026-09-09 (remediation, finding 1): because this latch is global
/// and there is no UI to clear it, the ONE thing that must never
/// happen is for it to stay true. It is cleared in a `finally`, so an
/// exception cannot strand it — but a `finally` only runs when the body
/// finishes, and the body used to `await` a platform round trip with no
/// bound: the reader went to the OS settings screen, Android destroyed
/// the Activity behind them, and the reply came back to nobody. Every
/// later 「立即更新」, on both surfaces, then did nothing at all, silently,
/// until the app was killed. See [AppUpdateInstaller.requestPermission]
/// and `MainActivity.answerPendingPermission` for the two halves of the
/// fix; the test is "the permission trip that never answers".
final ValueNotifier<bool> updateInstallInProgress = ValueNotifier<bool>(false);

/// Download the APK and hand it to Android's installer, with a progress
/// dialog the reader cannot dismiss by accident but CAN stop.
///
/// The permission trip (finding 4) is handled here too: when the reader
/// comes back from the OS switch with it on, the download runs again
/// without another tap, because the button they would have pressed is
/// not on the screen they came back to.
///
/// [client] and [permissionTimeout] are test seams and nothing else:
/// the first lets a test hold the download open long enough to look at
/// the dialog, the second lets it reach the "the platform never
/// answered" case in fifty milliseconds instead of three minutes.
Future<void> installUpdateInApp(
  BuildContext context,
  UpdateInfo info, {
  required String locale,
  @visibleForTesting http.Client? client,
  @visibleForTesting
  Duration permissionTimeout = AppUpdateInstaller.defaultPermissionTimeout,
}) async {
  if (updateInstallInProgress.value) return;
  updateInstallInProgress.value = true;
  try {
    // The entry point's own guard. Every other context use below is
    // `mounted`-checked, as this file's header promises, and this one
    // was the exception: the dashboard bar's action lives on the
    // app-level ScaffoldMessenger and outlives route changes, so the
    // element it captured is not guaranteed alive by the time it is
    // pressed — and `showDialog` on a defunct element throws inside an
    // `unawaited`, which is an unhandled async error and a dead button.
    if (!context.mounted) return;
    var outcome = await _downloadWithDialog(context, info, locale, client);
    if (outcome == UpdateInstallOutcome.permissionNeeded) {
      if (!context.mounted) return;
      final granted =
          await _offerPermission(context, locale, permissionTimeout);
      if (!granted || !context.mounted) return;
      outcome = await _downloadWithDialog(context, info, locale, client);
    }
    if (!context.mounted) return;
    switch (outcome) {
      case UpdateInstallOutcome.launched:
        // Nothing to say. Android's own installer is now in front of
        // the reader, and a toast under it would be talking over the
        // OS.
        break;
      case UpdateInstallOutcome.cancelled:
        // They pressed 停止下载. They know.
        break;
      case UpdateInstallOutcome.permissionNeeded:
        // Back from settings with the switch still off: they decided,
        // and the permission dialog already said how to change it.
        break;
      case UpdateInstallOutcome.downloadFailed:
      case UpdateInstallOutcome.unsupported:
        _showFailed(context, info, locale);
    }
  } finally {
    updateInstallInProgress.value = false;
  }
}

/// One download attempt behind a modal progress dialog.
///
/// `barrierDismissible: false` because the download is ~90 MB on a
/// tablet's mobile data: a stray tap outside the dialog would hide the
/// only indication that it is happening, and the reader would start it
/// again. `PopScope(canPop: false)` (finding 1) because that flag says
/// nothing about the Android Back button, which used to close the
/// dialog and leave the download running unseen — on a dialog that had
/// no button of its own, so Back was the only way out of it at all.
/// Stop is now that way out, and it really stops: the token aborts the
/// read and the partial file is discarded.
///
/// The dialog owns the progress value through a [ValueNotifier] rather
/// than `setState` on the caller, so a progress tick repaints a bar and
/// not the page behind it.
Future<UpdateInstallOutcome> _downloadWithDialog(
  BuildContext context,
  UpdateInfo info,
  String locale,
  http.Client? client,
) async {
  final progress = ValueNotifier<double?>(null);
  final token = UpdateCancelToken();
  var dialogOpen = true;
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(_s(locale, 'updateDownloading', 'Downloading update…')),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (_, value, __) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: value),
              const SizedBox(height: 12),
              if (value != null)
                Text('${(value * 100).round()}%',
                    style: const TextStyle(fontSize: 12)),
              // Always, not only while the length is unknown (finding
              // 6): GitHub sends Content-Length on every release asset,
              // so the old "show it while value == null" branch was
              // shown to nobody — and the next thing on screen is an
              // Android system dialog that looks like an error to a
              // reader who was never told it was coming.
              Text(
                _s(locale, 'updateDownloadingHint',
                    'Android will ask you to confirm the install.'),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              token.cancel();
              dialogOpen = false;
              Navigator.of(ctx).pop();
            },
            child: Text(_s(locale, 'updateCancelDownload', 'Stop download')),
          ),
        ],
      ),
    ),
  ).then((_) => dialogOpen = false));

  final outcome = await AppUpdateInstaller.downloadAndInstall(
    info.downloadUrl,
    onProgress: (f) => progress.value = f,
    client: client,
    cancelToken: token,
  );
  progress.dispose();
  if (!context.mounted) return outcome;
  if (dialogOpen) Navigator.of(context, rootNavigator: true).pop();
  return outcome;
}

/// Explain the OS switch rather than reporting a failure, and say
/// whether the reader came back with it on.
///
/// "Install unknown apps" is off by default and is granted per app, so
/// this is the ordinary first run, not an error — and a reader told
/// "update failed" here would reasonably conclude the app is broken
/// rather than that Android is doing its job.
///
/// 2026-09-09 (review finding 4): [AppUpdateInstaller.requestPermission]
/// now returns when the settings screen closes, so the answer here is
/// the state of the switch AFTER the trip — re-checked through
/// [AppUpdateInstaller.canInstall] rather than trusted, because the
/// caller is about to write 90 MB on the strength of it.
Future<bool> _offerPermission(
  BuildContext context,
  String locale,
  Duration permissionTimeout,
) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title:
          Text(_s(locale, 'updatePermissionTitle', 'Allow installing updates')),
      content: Text(_s(
        locale,
        'updatePermissionBody',
        'Android asks each app separately before it may install one. '
            'Turn on "Install unknown apps" for this app; the update '
            'continues when you come back.',
      )),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(_s(locale, 'cancel', 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(_s(locale, 'updatePermissionOpen', 'Open settings')),
        ),
      ],
    ),
  );
  if (go != true) return false;
  final granted =
      await AppUpdateInstaller.requestPermission(timeout: permissionTimeout);
  return granted && await AppUpdateInstaller.canInstall();
}

/// A download that did not arrive, with the browser route offered as
/// the way out rather than a bare apology.
void _showFailed(BuildContext context, UpdateInfo info, String locale) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title:
          Text(_s(locale, 'updateFailedTitle', "Couldn't download the update")),
      content: Text(_s(
        locale,
        'updateFailedBody',
        'The download did not finish. You can try again, or get the '
            'file from the release page.',
      )),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(_s(locale, 'cancel', 'Cancel')),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(_s(locale, 'updateOpenInBrowser', 'Open in browser')),
          onPressed: () {
            // `context`, not `ctx`: the dialog is popped first, so ctx's
            // element is defunct by the time a failure would need to
            // show a SnackBar.
            final outer = context;
            Navigator.of(ctx).pop();
            if (LinkOpener.isAvailable) {
              LinkOpener.openOrWarn(outer, info.releaseUrl, locale: locale);
            }
          },
        ),
      ],
    ),
  );
}

/// The "vX is available" dialog, with 「立即更新」 only where it works.
///
/// 2026-09-09 (review finding 5): when the in-app button is there, the
/// body above it says what that button does. It used to be the browser
/// paragraph — "download it from GitHub, then install: Android opens
/// the APK; desktop unzips and runs; iOS uses the web app" — printed
/// over a button that does none of those things, to a reader holding a
/// phone who was being told about desktops and iOS.
Future<void> showUpdateAvailableDialog(
  BuildContext context,
  UpdateInfo info, {
  required String locale,
}) async {
  final inApp = await canInstallInApp(info);
  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(_s(locale, 'updateAvailableTitle', 'Update available')),
      content: Text(
        (inApp
                ? _s(
                    locale,
                    'updateAvailableBodyAndroid',
                    'Version v{new} is available (you have v{cur}). '
                        '"Update now" downloads and installs it here; '
                        'Android will ask you to confirm.',
                  )
                : _s(
                    locale,
                    'updateAvailableBody',
                    'Version v{new} is available (you have v{cur}). '
                        'Download it from GitHub, then install: Android '
                        'opens the APK; desktop unzips and runs. iOS uses '
                        'the web app.',
                  ))
            .replaceAll('{new}', info.latestVersion)
            .replaceAll('{cur}', info.currentVersion),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(_s(locale, 'cancel', 'Cancel')),
        ),
        // The browser route stays, and where the in-app button is
        // beside it it becomes the SECONDARY one rather than
        // disappearing. It is the fallback for a reader who will not
        // grant "install unknown apps", and the only route at all on
        // iOS and the desktops.
        //
        // 2026-09-09 (remediation): labelled from `inApp`, not from
        // `AppUpdateInstaller.isSupported`. Those two differ in exactly
        // the window `hasApk` exists for — an Android reader in the
        // minutes before the APK is attached — and there this button
        // was calling itself "Open in browser", the name of a SECOND
        // choice, while being the only one on the dialog and while the
        // dashboard's bar called the identical state "Download".
        TextButton.icon(
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(
            inApp
                ? _s(locale, 'updateOpenInBrowser', 'Open in browser')
                : _s(locale, 'updateDownload', 'Download'),
          ),
          onPressed: () {
            // `context`, not `ctx`: see [_showFailed].
            final outer = context;
            Navigator.of(ctx).pop();
            if (LinkOpener.isAvailable) {
              LinkOpener.openOrWarn(outer, info.downloadUrl, locale: locale);
            }
          },
        ),
        if (inApp)
          FilledButton.icon(
            icon: const Icon(Icons.system_update_alt_rounded, size: 18),
            label: Text(_s(locale, 'updateInstallNow', 'Update now')),
            onPressed: () {
              final outer = context;
              Navigator.of(ctx).pop();
              unawaited(installUpdateInApp(outer, info, locale: locale));
            },
          ),
      ],
    ),
  );
}

/// The daily check's bar, with the one action that fits this build.
///
/// A SnackBar rather than a dialog: see `_maybeOfferUpdate` in
/// `dashboard_page.dart`, which shows it and explains why the dashboard
/// must not raise a second modal on launch. 2026-09-09 (review finding
/// 7): on Android with an APK the action is now the in-app install —
/// the same [installUpdateInApp] the About page runs — where it used to
/// hand the URL to the browser, so the one surface most readers
/// actually meet was the one still asking them to go and find a file.
Future<SnackBar> buildUpdateAvailableBar(
  BuildContext context,
  UpdateInfo info, {
  required String locale,
  @visibleForTesting http.Client? client,
  @visibleForTesting
  Duration permissionTimeout = AppUpdateInstaller.defaultPermissionTimeout,
}) async {
  // Awaited (remediation): which of the two actions is honest depends
  // on which app this build is — see [canInstallInApp]. Resolved here,
  // before the bar exists, so the caller shows a finished SnackBar and
  // the action never has to change under the reader.
  final inApp = await canInstallInApp(info);
  final label =
      _s(locale, 'updateAvailableBar', 'Version v{new} is available')
          .replaceAll('{new}', info.latestVersion);
  final SnackBarAction? action;
  if (inApp) {
    action = SnackBarAction(
      label: _s(locale, 'updateInstallNow', 'Update now'),
      onPressed: () => unawaited(installUpdateInApp(context, info,
          locale: locale,
          client: client,
          permissionTimeout: permissionTimeout)),
    );
  } else if (LinkOpener.isAvailable) {
    action = SnackBarAction(
      label: _s(locale, 'updateDownload', 'Download'),
      onPressed: () => LinkOpener.openOrWarn(context, info.downloadUrl,
          locale: locale),
    );
  } else {
    action = null;
  }
  // Six seconds because it has a button, and the default four is not
  // long enough to read a sentence and decide.
  return SnackBar(
    content: Text(label),
    duration: const Duration(seconds: 6),
    action: action,
  );
}

class UpdateCheckTile extends StatefulWidget {
  final String locale;
  final ColorScheme scheme;
  const UpdateCheckTile({
    super.key,
    required this.locale,
    required this.scheme,
  });

  @override
  State<UpdateCheckTile> createState() => _UpdateCheckTileState();
}

class _UpdateCheckTileState extends State<UpdateCheckTile> {
  bool _checking = false;

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    final info = await UpdateService.checkForUpdate();
    if (!mounted) return;
    setState(() => _checking = false);

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_s(widget.locale, 'updateCheckFailed',
              "Couldn't check for updates")),
        ),
      );
      return;
    }
    if (!info.updateAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (_s(widget.locale, 'updateUpToDate',
                    "You're on the latest version (v{v})"))
                .replaceAll('{v}', info.currentVersion),
          ),
        ),
      );
      return;
    }
    await showUpdateAvailableDialog(context, info, locale: widget.locale);
  }

  @override
  Widget build(BuildContext context) {
    // Web (PWA) is always current — nothing to check.
    if (!UpdateService.isSupported) return const SizedBox.shrink();
    return TextButton.icon(
      icon: _checking
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(widget.scheme.primary),
              ),
            )
          : const Icon(Icons.system_update_alt_rounded, size: 16),
      label: Text(
        _checking
            ? _s(widget.locale, 'updateChecking', 'Checking…')
            : _s(widget.locale, 'checkForUpdates', 'Check for updates'),
      ),
      onPressed: _checking ? null : _check,
    );
  }
}

/// The automatic half of the same question, sitting directly under
/// [UpdateCheckTile].
///
/// Beside the manual button rather than in the Settings list on
/// purpose: this is the switch that decides whether the reader ever
/// has to press that button, and a control is easiest to understand
/// next to the thing it makes unnecessary. It shares the button's
/// platform gate — [UpdateService.isSupported] — so on the web both
/// vanish together and neither implies the other exists.
class AutoUpdateCheckToggle extends StatelessWidget {
  final String locale;
  const AutoUpdateCheckToggle({super.key, required this.locale});

  @override
  Widget build(BuildContext context) {
    if (!UpdateService.isSupported) return const SizedBox.shrink();
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: settings.autoCheckUpdates,
      onChanged: settings.setAutoCheckUpdates,
      title: Text(
        uiStrings['autoCheckUpdates']?[locale] ?? 'Check for updates daily',
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        uiStrings['autoCheckUpdatesHint']?[locale] ??
            'Asks GitHub at most once a day whether a newer release '
                'exists. You only hear about it when there is one.',
        style: TextStyle(
          fontSize: 11,
          color: scheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
