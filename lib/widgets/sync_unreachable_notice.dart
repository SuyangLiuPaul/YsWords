// The honest half of the 2026-09-06 sync ruling.
//
// When a signed-in reader's network cannot reach the sync server, the
// app must not fall silent and it must not imply sync is working. It
// says what happened, says the local data is safe, says they are still
// signed in, and offers Retry.
//
// This is the expected everyday state for a mainland-China reader:
// `identitytoolkit.googleapis.com` (Auth) and `firebaseio.com` (RTDB)
// are different host families, so email sign-in working is evidence
// about Auth and about nothing else. Local storage stays the source of
// truth — a sync failure never blocks or discards a local write, and
// this widget is deliberately inert: it renders a sentence and a
// button, and touches no data.

import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

class SyncUnreachableNotice extends StatelessWidget {
  final String locale;
  final String? fontFamily;
  final double fontSize;
  final VoidCallback onRetry;

  const SyncUnreachableNotice({
    super.key,
    required this.locale,
    required this.onRetry,
    this.fontFamily,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.cloud_off_outlined,
            size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            key: const Key('sync.unreachable'),
            uiStrings['syncUnreachable']?[locale] ??
                "Couldn't reach the sync server from your network. Your "
                    'highlights, notes and bookmarks are safe on this '
                    "device. You're still signed in.",
            style: TextStyle(
              fontFamily: fontFamily,
              fontFamilyFallback: kCjkFontFallback,
              fontSize: (fontSize - 6).clamp(11.0, 14.0).toDouble(),
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          key: const Key('sync.unreachableRetry'),
          onPressed: onRetry,
          child: Text(uiStrings['retry']?[locale] ?? 'Retry'),
        ),
      ],
    );
  }
}
