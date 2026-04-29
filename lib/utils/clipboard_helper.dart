import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/share_service.dart';

abstract class ClipboardHelper {
  static Future<void> copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Copy [text] AND show a clear floating "Copied!" snackbar with a
  /// check icon. Use this instead of [copyText] + manual snackbar for
  /// every copy action so feedback is consistent across the app.
  ///
  /// The [context] must be a descendant of a [ScaffoldMessenger]. Modal
  /// bottom sheets that want feedback should wrap their body in a
  /// local [Scaffold] (which provides its own messenger) — otherwise
  /// the snackbar anchors to the root scaffold and is hidden behind
  /// the modal.
  static Future<void> copyWithFeedback(
    BuildContext context,
    String text, {
    String? messageOverride,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final locale = _localeFor(context);
    final message =
        messageOverride ?? (uiStrings['copied']?[locale] ?? 'Copied!');
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                color: scheme.onInverseSurface, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  color: scheme.onInverseSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        duration: const Duration(milliseconds: 1800),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// Share-first with copy-as-fallback. On platforms with the Web
  /// Share API (most mobile browsers + recent desktop Chrome/Edge),
  /// opens the system share sheet so users can post to Messages /
  /// Mail / Twitter / etc. Falls back to clipboard copy + the same
  /// "Copied!" snackbar when sharing isn't available or the user
  /// cancels the share dialog.
  static Future<void> shareOrCopy(
    BuildContext context,
    String text, {
    String? title,
  }) async {
    if (ShareService.isAvailable) {
      final shared = await ShareService.shareText(
        text: text,
        title: title,
      );
      if (shared) return;
    }
    if (!context.mounted) return;
    await copyWithFeedback(context, text);
  }

  static String _localeFor(BuildContext context) {
    // Best-effort locale read; ui_strings keys fall back to English.
    final l = Localizations.maybeLocaleOf(context);
    if (l == null) return 'en';
    if (l.languageCode == 'zh') {
      return l.scriptCode == 'Hant' ? 'zh-Hant' : 'zh-Hans';
    }
    return 'en';
  }
}
