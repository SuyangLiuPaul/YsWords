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

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/app_update_installer.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/update_service.dart';

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

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    final info = await UpdateService.checkForUpdate();
    if (!mounted) return;
    setState(() => _checking = false);

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_s('updateCheckFailed', "Couldn't check for updates")),
        ),
      );
      return;
    }
    if (!info.updateAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (_s('updateUpToDate', "You're on the latest version (v{v})"))
                .replaceAll('{v}', info.currentVersion),
          ),
        ),
      );
      return;
    }
    _showUpdateDialog(info);
  }

  void _showUpdateDialog(UpdateInfo info) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_s('updateAvailableTitle', 'Update available')),
        content: Text(
          (_s(
            'updateAvailableBody',
            'Version v{new} is available (you have v{cur}). '
                'Download it from GitHub, then install: Android opens the '
                'APK; desktop unzips and runs. iOS uses the web app.',
          ))
              .replaceAll('{new}', info.latestVersion)
              .replaceAll('{cur}', info.currentVersion),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(_s('cancel', 'Cancel')),
          ),
          // The browser route stays, and on Android it becomes the
          // SECONDARY one rather than disappearing. It is the fallback
          // for a reader who will not grant "install unknown apps", and
          // the only route at all on iOS and the desktops.
          TextButton.icon(
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(
              AppUpdateInstaller.isSupported
                  ? _s('updateOpenInBrowser', 'Open in browser')
                  : _s('updateDownload', 'Download'),
            ),
            onPressed: () {
              // `context`, not `ctx`: the dialog is popped first, so
              // ctx's element is defunct by the time a failure would
              // need to show a SnackBar.
              final outer = context;
              Navigator.of(ctx).pop();
              if (LinkOpener.isAvailable) {
                LinkOpener.openOrWarn(outer, info.downloadUrl);
              }
            },
          ),
          if (AppUpdateInstaller.isSupported)
            FilledButton.icon(
              icon: const Icon(Icons.system_update_alt_rounded, size: 18),
              label: Text(_s('updateInstallNow', 'Update now')),
              onPressed: () {
                Navigator.of(ctx).pop();
                _installNow(info);
              },
            ),
        ],
      ),
    );
  }

  /// Download the APK and hand it to Android's installer, with a
  /// progress dialog the reader cannot dismiss by accident.
  ///
  /// `barrierDismissible: false` because the download is ~90 MB on a
  /// tablet's mobile data: a stray tap outside the dialog would hide
  /// the only indication that it is happening, and the reader would
  /// start it again. The dialog owns the progress value through a
  /// [ValueNotifier] rather than `setState` on this widget, so a
  /// progress tick repaints a bar and not the About page behind it.
  Future<void> _installNow(UpdateInfo info) async {
    final progress = ValueNotifier<double?>(null);
    var dialogOpen = true;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(_s('updateDownloading', 'Downloading update…')),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (_, value, __) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: value),
              const SizedBox(height: 12),
              Text(
                value == null
                    ? _s('updateDownloadingHint',
                        'Android will ask you to confirm the install.')
                    : '${(value * 100).round()}%',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => dialogOpen = false));

    final outcome = await AppUpdateInstaller.downloadAndInstall(
      info.downloadUrl,
      onProgress: (f) => progress.value = f,
    );
    progress.dispose();
    if (!mounted) return;
    if (dialogOpen) Navigator.of(context, rootNavigator: true).pop();

    switch (outcome) {
      case UpdateInstallOutcome.launched:
        // Nothing to say. Android's own installer is now in front of
        // the reader, and a toast under it would be talking over the
        // OS.
        break;
      case UpdateInstallOutcome.permissionNeeded:
        await _offerPermission();
      case UpdateInstallOutcome.downloadFailed:
      case UpdateInstallOutcome.unsupported:
        if (!mounted) return;
        _showFailed(info);
    }
  }

  /// Explain the OS switch rather than reporting a failure.
  ///
  /// "Install unknown apps" is off by default and is granted per app,
  /// so this is the ordinary first run, not an error — and a reader
  /// told "update failed" here would reasonably conclude the app is
  /// broken rather than that Android is doing its job.
  Future<void> _offerPermission() async {
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_s('updatePermissionTitle', 'Allow installing updates')),
        content: Text(_s(
          'updatePermissionBody',
          'Android asks each app separately before it may install one. '
              'Turn on "Install unknown apps" for this app, then press '
              'Update again.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(_s('cancel', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_s('updatePermissionOpen', 'Open settings')),
          ),
        ],
      ),
    );
    if (go == true) await AppUpdateInstaller.requestPermission();
  }

  /// A download that did not arrive, with the browser route offered as
  /// the way out rather than a bare apology.
  void _showFailed(UpdateInfo info) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_s('updateFailedTitle', "Couldn't download the update")),
        content: Text(_s(
          'updateFailedBody',
          'The download did not finish. You can try again, or get the '
              'file from the release page.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(_s('cancel', 'Cancel')),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(_s('updateOpenInBrowser', 'Open in browser')),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (LinkOpener.isAvailable) {
                LinkOpener.openOrWarn(context, info.releaseUrl);
              }
            },
          ),
        ],
      ),
    );
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
            ? _s('updateChecking', 'Checking…')
            : _s('checkForUpdates', 'Check for updates'),
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
