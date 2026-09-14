/// The line the dashboard shows when a newer version exists.
///
/// 2026-09-14, at the owner's request: 「如果有 upgrade available 应该在
/// home page 显示而不是最下面 popup」. This app had two of those popups, one
/// per channel, and both at the foot of the screen:
///
///   * a `SnackBar` on launch for a newer GitHub release (native builds),
///     six seconds and then gone, leaving nothing to come back to but a
///     tile on the About page;
///   * an app-wide strip along the bottom edge for a newer web build,
///     which stacked above the mini-player and competed with it for the
///     one place a thumb rests.
///
/// One banner at the top of the home screen replaces both. It states the
/// fact, carries the action, and stays until the reader acts on it or
/// waves it away. Modelled on the 雅伟的话 app's `UpdateBanner`, which the
/// owner named as the reference: one row, the version, one button, and a
/// 暂不 meaning "not this build" rather than "never again".
///
/// **Which channel wins when both have something to say.** The release
/// does. A web build is fetched by reloading the page and costs the reader
/// nothing to postpone; a release is an APK they have to install, and it
/// is also the one that cannot arrive on its own. In practice the two
/// never coincide — `UpdateService.isSupported` is false on the web and
/// `WebUpdateChecker` no-ops off it — but a banner that would show two
/// rows is a banner that has to choose, and choosing here beats finding
/// out later which one Flutter happened to lay out first.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/app_update_installer.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/update_service.dart';
import 'package:yswords/services/web_update_checker.dart';
import 'package:yswords/widgets/update_check_tile.dart';

class UpdateAvailableBanner extends StatefulWidget {
  const UpdateAvailableBanner({
    super.key,
    required this.locale,
    this.release,
    this.releaseInstallsInApp = false,
    this.client,
    this.permissionTimeout = AppUpdateInstaller.defaultPermissionTimeout,
  });

  /// The interface language, passed in the way every other control in
  /// `update_check_tile.dart` takes it rather than read from the provider:
  /// one of these banners is built by a page that already has it, and a
  /// widget that resolves its own locale is a widget a test cannot ask in
  /// English.
  final String locale;

  /// The newer GitHub release the periodic check found, or null. Passed in
  /// rather than fetched here: the check is scheduled, the schedule is the
  /// reader's setting, and the page that owns the launch sequence owns it.
  final UpdateInfo? release;

  /// Whether [release] can be installed without leaving the app —
  /// `canInstallInApp`, which is a `Future` because only the platform side
  /// knows whether the attached APK is an update to THIS build or a
  /// different app (the `cn` flavour runs under its own package id).
  ///
  /// Resolved by the caller, before the banner exists, for the reason the
  /// SnackBar this replaces resolved it before the bar existed: an action
  /// that settles a frame later is an action that changes under the
  /// reader's finger.
  final bool releaseInstallsInApp;

  /// Test seams, and nothing else: the first lets a test hold the download
  /// open long enough to look at the progress dialog, the second lets it
  /// reach the "the platform never answered" case in fifty milliseconds
  /// instead of three minutes. Both are passed straight through to
  /// [installUpdateInApp], which is where they are documented.
  @visibleForTesting
  final http.Client? client;

  @visibleForTesting
  final Duration permissionTimeout;

  @override
  State<UpdateAvailableBanner> createState() => _UpdateAvailableBannerState();
}

class _UpdateAvailableBannerState extends State<UpdateAvailableBanner> {
  /// The version string the reader waved away. In memory and not
  /// persisted, and per version rather than a flag: somebody who taps 暂不
  /// has said "not right now", not "never tell me again", so the banner
  /// returns for the next version published. State on this object rather
  /// than in the page, because a `State` survives the rebuilds a banner
  /// sitting in a dashboard list gets on every frame.
  String? _dismissed;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: WebUpdateChecker.instance.available,
      builder: (context, webVersion, _) {
        final release = widget.release;
        final version = release?.latestVersion ?? webVersion;
        if (version == null || version == _dismissed) {
          return const SizedBox.shrink();
        }
        return _Banner(
          locale: widget.locale,
          version: version,
          // Null for the web channel: reloading is the install there, and
          // `_Banner` reads that from the release being absent.
          release: release,
          installsInApp: widget.releaseInstallsInApp,
          client: widget.client,
          permissionTimeout: widget.permissionTimeout,
          onDismiss: () => setState(() => _dismissed = version),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.locale,
    required this.version,
    required this.release,
    required this.installsInApp,
    required this.client,
    required this.permissionTimeout,
    required this.onDismiss,
  });

  final String locale;
  final String version;
  final UpdateInfo? release;
  final bool installsInApp;
  final http.Client? client;
  final Duration permissionTimeout;
  final VoidCallback onDismiss;

  String _s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = release;
    final label = info != null
        ? _s('updateAvailableBar', 'Version v{new} is available')
            .replaceAll('{new}', version)
        : '${_s('updateAvailable', 'A new version is available')} · v$version';

    // Three actions, one per channel and platform: reload on the web,
    // the in-app install on Android with an APK, and the download page
    // where neither is possible. The last is still worth a banner — that
    // a newer version exists is the part a reader cannot otherwise learn.
    final Widget? action;
    if (info == null) {
      action = FilledButton(
        onPressed: WebUpdateChecker.instance.reloadNow,
        child: Text(_s('updateReloadNow', 'Update')),
      );
    } else if (installsInApp) {
      action = FilledButton(
        // The two seams are `@visibleForTesting` on the function they
        // belong to, and threading them through a second widget is a use
        // outside that library. Passed on rather than dropped because the
        // claim worth testing is that tapping THIS button runs the same
        // install as the About page — which a test can only watch if it
        // can hold the download open.
        onPressed: () => unawaited(installUpdateInApp(context, info,
            locale: locale,
            // ignore: invalid_use_of_visible_for_testing_member
            client: client,
            // ignore: invalid_use_of_visible_for_testing_member
            permissionTimeout: permissionTimeout)),
        child: Text(_s('updateInstallNow', 'Update now')),
      );
    } else if (LinkOpener.isAvailable) {
      action = FilledButton(
        onPressed: () => LinkOpener.openOrWarn(context, info.downloadUrl,
            locale: locale),
        child: Text(_s('updateDownload', 'Download')),
      );
    } else {
      action = null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Icon(Icons.system_update_alt_rounded,
                  size: 18, color: scheme.onPrimaryContainer),
              const SizedBox(width: 10),
              // Wrapping, not ellipsised. The strip this replaces cut its
              // own line to one, which on a 320px phone at the top of the
              // Menu Size slider is how 「雅伟版」 became 「雅…」 in the
              // header above it — the defect measured on the same day
              // this banner was written.
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: onDismiss,
                child: Text(
                  _s('updateBannerLater', 'Not now'),
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
              if (action != null) action,
            ],
          ),
        ),
      ),
    );
  }
}
