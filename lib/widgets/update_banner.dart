import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/web_update_checker.dart';

/// App-wide "a new version is available" strip.
///
/// Wrapped around the whole app in main.dart, next to [GlobalMiniPlayer]
/// and for the same reason: a page added later cannot forget it.
///
/// Renders nothing at all unless the server is serving a different build
/// from the one this tab is running — which on native is never, because
/// [WebUpdateChecker] no-ops off the web.
///
/// Dismiss is per-version and in memory only. Somebody who taps 稍后 has
/// said "not right now", not "never tell me again": the strip comes back
/// on the next version the server publishes, and the resume-time automatic
/// reload is unaffected, since that path has its own latch and its own
/// conditions.
class UpdateBanner extends StatefulWidget {
  final Widget child;
  const UpdateBanner({super.key, required this.child});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  String? _dismissed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: widget.child),
        ValueListenableBuilder<String?>(
          valueListenable: WebUpdateChecker.instance.available,
          builder: (context, version, _) {
            if (version == null || version == _dismissed) {
              return const SizedBox.shrink();
            }
            return _Strip(
              version: version,
              onDismiss: () => setState(() => _dismissed = version),
            );
          },
        ),
      ],
    );
  }
}

class _Strip extends StatelessWidget {
  final String version;
  final VoidCallback onDismiss;
  const _Strip({required this.version, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = context.watch<AppSettings>().locale;
    final label = uiStrings['updateAvailable']?[locale] ??
        'A new version is available';
    return Material(
      color: scheme.primaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(Icons.system_update_alt_rounded,
                  size: 18, color: scheme.onPrimaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  // The version travels with the message so a report
                  // like "it still says there's an update" can be
                  // answered without guessing which build they mean.
                  '$label · v$version',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: onDismiss,
                child: Text(
                  uiStrings['updateDismiss']?[locale] ?? 'Later',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
              FilledButton(
                onPressed: WebUpdateChecker.instance.reloadNow,
                child: Text(
                    uiStrings['updateReloadNow']?[locale] ?? 'Update'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
