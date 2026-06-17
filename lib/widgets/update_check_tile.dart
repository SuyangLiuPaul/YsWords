// 2026-06-16 (v1.3.88): "Check for updates" button for the About page.
//
// Native-only (Android / Windows / macOS / Linux / iOS): asks GitHub for
// the latest release via [UpdateService], then shows a dialog — either
// "you're up to date" or "vX.Y.Z is available" with a Download button that
// opens the right release asset for this platform via [LinkOpener]. On web
// it renders nothing (the PWA is always current). Manages its own loading
// state; every context use after an await is `mounted`-guarded.

import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
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
          FilledButton.icon(
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(_s('updateDownload', 'Download')),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (LinkOpener.isAvailable) {
                LinkOpener.open(info.downloadUrl);
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
