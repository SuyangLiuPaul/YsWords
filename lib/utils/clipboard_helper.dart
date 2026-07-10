import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/share_service.dart';
import 'package:yswords/utils/clipboard_fallback_stub.dart'
    if (dart.library.js_interop) 'package:yswords/utils/clipboard_fallback_web.dart';

abstract class ClipboardHelper {
  /// Copy [text] to the system clipboard. Returns whether the copy
  /// SUCCEEDED — and, critically, NEVER throws.
  ///
  /// 2026-07-10 (prod crash report, iOS 18.7 Safari, zh-Hant):
  /// `PlatformException(copy_fail, Clipboard.setData failed.)` escaped
  /// to the Zone handler because several call sites awaited
  /// `Clipboard.setData` unguarded. Safari rejects the async Clipboard
  /// API outside a user-activation window / without clipboard
  /// permission. Now every failure is caught here, a synchronous
  /// legacy `execCommand('copy')` fallback is attempted on web (it
  /// works in exactly the situations where Safari rejects the async
  /// API), and callers get a plain bool to drive success/failure
  /// feedback. All app copy paths must go through this method —
  /// direct `Clipboard.setData` calls re-introduce the crash class.
  static Future<bool> copyText(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (_) {
      return legacyClipboardCopy(text);
    }
  }

  /// Copy [text] AND show a clear floating snackbar — a check-icon
  /// "Copied!" on success, an error-styled "Copy failed — clipboard
  /// unavailable" on failure. Use this instead of [copyText] + manual
  /// snackbar for every copy action so feedback is consistent across
  /// the app. Never throws.
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
    final ok = await copyText(text);
    if (!context.mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final locale = _localeFor(context);
    final message = ok
        ? (messageOverride ?? (uiStrings['copied']?[locale] ?? 'Copied!'))
        : (uiStrings['shareLinkFailed']?[locale] ??
            'Copy failed — clipboard unavailable');
    final fg = ok ? scheme.onInverseSurface : scheme.onError;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: fg,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? scheme.inverseSurface : scheme.error,
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
