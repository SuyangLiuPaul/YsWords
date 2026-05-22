import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// Single source of truth for the "Made by Paul Liu · contact" line
/// shown across YsWords, DailyNews, bible-evidence redirect stub,
/// and SmartHome. Copy is unified so updates only need to happen in
/// one place per app surface.
///
/// On tap, opens `mailto:` in a new tab/window via [LinkOpener]. If
/// that fails (no mail app on web, popup blocker, etc.), falls back
/// to copying the email address to the clipboard so the user can
/// paste it elsewhere.
class ContactLine extends StatelessWidget {
  /// Email address — defaults to the canonical one but kept as a
  /// param so future changes only need to land here.
  final String email;

  /// Compact rendering for footers; expanded with a small "Contact"
  /// header for places like the Settings → About card.
  final bool compact;

  const ContactLine({
    super.key,
    this.email = 'paul.sy.liu@gmail.com',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final intro = uiStrings['contactIntro']?[locale] ??
        'Made by Paul Liu';
    final tail = uiStrings['contactTail']?[locale] ??
        'Questions, feedback, or anything else:';

    final body = Text.rich(
      TextSpan(
        style: TextStyle(
          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
          fontSize: (settings.fontSize - (compact ? 4 : 2))
              .clamp(11.0, 15.0)
              .toDouble(),
          color: scheme.onSurfaceVariant,
          height: 1.4,
        ),
        children: [
          TextSpan(text: '$intro  ·  $tail '),
          TextSpan(
            text: email,
            style: TextStyle(
              color: scheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: scheme.primary.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );

    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 6 : 10,
        ),
        child: body,
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final uri = 'mailto:$email?subject=YsWords%20feedback';
    if (LinkOpener.isAvailable) {
      final ok = await LinkOpener.open(uri);
      if (ok) return;
    }
    if (!context.mounted) return;
    await ClipboardHelper.copyWithFeedback(context, email);
  }
}
