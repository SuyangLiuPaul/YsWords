import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/feedback_service.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// 2026-05-07 (v12): user-facing feedback form. The user
/// (paulsyliu@gmail.com) wanted a single place inside the app
/// where readers can report bugs, request features, or share
/// general thoughts. Submissions go via the device's default
/// `mailto:` handler -- no backend / no API key / no hosting
/// cost, the email lands directly in the developer's inbox.
///
/// Why mailto and not a web form / Netlify Function?
/// 1. Web form would need a transactional email service
///    (SendGrid / Resend / Mailgun) plus an API key in env, and
///    would silently lose feedback if the function errored.
///    mailto opens the user's mail client; if they hit Send,
///    the email is in OUR inbox the same way any direct email
///    would be -- no opaque middleware.
/// 2. Browser mailto support is universal (Gmail web, Apple
///    Mail, Outlook, etc.). On mobile most browsers prompt to
///    pick the mail app.
/// 3. The user keeps their privacy -- they can edit the body,
///    pick which mail account to send from, see the full
///    message before sending. No silent telemetry.
///
/// Auto-attached metadata (app version, locale, Bible version,
/// profile name) helps debug the report. Users can delete it
/// from the body before sending if they want.
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

enum _FeedbackCategory { bug, feature, general, content }

class _FeedbackPageState extends State<FeedbackPage> {
  static const String _devEmail = 'paulsyliu@gmail.com';

  _FeedbackCategory _category = _FeedbackCategory.general;
  final _nameController = TextEditingController();
  // Used by both code paths:
  //   - Signed-in: prefilled (read-only) with the user's auth email,
  //     visible only when the "Send me a copy" checkbox is ticked.
  //   - Guest: editable optional email; if non-empty we treat it as
  //     "user wants a copy at this address".
  final _copyEmailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _submitting = false;
  /// 2026-05-07 (v15): "send me a copy" -- only meaningful for the
  /// signed-in path. Guests have a plain email field instead and
  /// we infer "wants copy" from `copyEmailController.text.isNotEmpty`.
  bool _wantCopySignedIn = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the copy-email field with the signed-in email so the
    // user doesn't retype it. Read-only for the signed-in path; the
    // guest path leaves it empty and lets them type.
    final user = CloudAuthService.instance.currentUser;
    final email = user?.email;
    if (email != null && email.isNotEmpty) {
      _copyEmailController.text = email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _copyEmailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String _categoryLabel(_FeedbackCategory cat, String locale) {
    switch (cat) {
      case _FeedbackCategory.bug:
        return uiStrings['feedbackCategoryBug']?[locale] ?? 'Bug report';
      case _FeedbackCategory.feature:
        return uiStrings['feedbackCategoryFeature']?[locale] ??
            'Feature request';
      case _FeedbackCategory.general:
        return uiStrings['feedbackCategoryGeneral']?[locale] ??
            'General feedback';
      case _FeedbackCategory.content:
        return uiStrings['feedbackCategoryContent']?[locale] ??
            'Content / translation';
    }
  }

  String _categoryShort(_FeedbackCategory cat) {
    switch (cat) {
      case _FeedbackCategory.bug:
        return 'Bug';
      case _FeedbackCategory.feature:
        return 'Feature';
      case _FeedbackCategory.general:
        return 'General';
      case _FeedbackCategory.content:
        return 'Content';
    }
  }

  /// Resolve the user's email + whether they want a copy. Returns
  /// `(email, wantsCopy)`. Signed-in users use the auth email; the
  /// boolean tracks the checkbox. Guests rely on the typed email --
  /// non-empty implies "send me a copy at this address". Always
  /// returns the auth email (when present) so it can be attached
  /// to the diagnostic block regardless of the copy preference.
  ({String email, bool wantsCopy, String authEmail}) _resolveCopyEmail() {
    final user = CloudAuthService.instance.currentUser;
    final authEmail = user?.email ?? '';
    if (authEmail.isNotEmpty) {
      return (
        email: authEmail,
        wantsCopy: _wantCopySignedIn,
        authEmail: authEmail,
      );
    }
    final typed = _copyEmailController.text.trim();
    return (
      email: typed,
      wantsCopy: typed.isNotEmpty,
      authEmail: '',
    );
  }

  /// Build the email body: structured user input + auto-attached
  /// metadata. Used for the mailto: fallback only -- the server-side
  /// path builds its own (richer) body in submitFeedback.mjs.
  String _composeBody({
    required AppSettings settings,
    required MainProvider mp,
  }) {
    final name = _nameController.text.trim();
    final copy = _resolveCopyEmail();
    final msg = _messageController.text.trim();

    final lines = <String>[];
    if (msg.isNotEmpty) {
      lines.add(msg);
      lines.add('');
    }
    lines.add('---');
    lines.add('Category: ${_categoryShort(_category)}');
    if (name.isNotEmpty) lines.add('Name: $name');
    if (copy.authEmail.isNotEmpty) {
      lines.add('Signed-in: ${copy.authEmail}');
    }
    if (copy.wantsCopy && copy.email.isNotEmpty) {
      lines.add('Copy-to: ${copy.email}');
    }
    lines.add('Locale: ${settings.locale}');
    lines.add('Bible version: ${mp.currentVersion}');
    if (mp.currentBook != null && mp.currentChapter != null) {
      lines.add('Last position: ${mp.currentBook} ${mp.currentChapter}');
    }
    lines.add('App: YsWords (web)');
    return lines.join('\n');
  }

  String _composeSubject(String locale) {
    final tag = _categoryShort(_category);
    return 'YsWords feedback [$tag]';
  }

  /// Compose a position-line metadata snippet ("创世纪 1") for the
  /// service payload + mailto fallback body.
  String _positionLine(MainProvider mp) {
    if (mp.currentBook != null && mp.currentChapter != null) {
      return '${mp.currentBook} ${mp.currentChapter}';
    }
    return '';
  }

  Future<void> _submit() async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final mp = Provider.of<MainProvider>(context, listen: false);
    final locale = settings.locale;
    final messenger = ScaffoldMessenger.of(context);

    if (_messageController.text.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text(uiStrings['feedbackMessageRequired']?[locale] ??
            'Please write a message before sending.'),
        duration: const Duration(seconds: 2),
      ));
      return;
    }

    setState(() => _submitting = true);

    // 2026-05-07 (v15): resolve the copy-email + signed-in state
    // ONCE here, then pass to both the service call and the
    // mailto: fallback so they agree on what to attach.
    final copy = _resolveCopyEmail();

    // 2026-05-07 (v13/v14): POST first to /api/submitFeedback
    // (Netlify Function backed by Resend). This sends the email
    // server-side -- no extra tab, no mail app, the user just sees
    // a "thanks" and gets popped back. Fall back to mailto: only
    // if the function isn't configured (no RESEND_API_KEY) or
    // returns 404, so feedback is never silently lost. v14 also
    // bundles client-side diagnostic info (screen / theme / TZ /
    // browser) for easier troubleshooting. v15 adds signed-in
    // email + opt-in copy-to-user.
    final result = await FeedbackService.submit(
      context: context,
      category: _categoryShort(_category),
      message: _messageController.text.trim(),
      name: _nameController.text.trim(),
      // replyTo + copy-CC use the same address. The server-side
      // function only attempts CC when wantsCopy is true.
      replyTo: copy.email,
      copyEmail: copy.email,
      wantsCopy: copy.wantsCopy,
      authEmail: copy.authEmail,
      appLocale: settings.locale,
      bibleVersion: mp.currentVersion,
      position: _positionLine(mp),
    );
    if (!mounted) return;

    if (result.ok) {
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(
        content: Text(uiStrings['feedbackSent']?[locale] ??
            'Feedback sent. Thank you!'),
        duration: const Duration(seconds: 3),
      ));
      Get.back();
      return;
    }

    if (result.unconfigured) {
      // Backend not yet wired (no RESEND_API_KEY in Netlify env).
      // Fall back to mailto so feedback still reaches the developer.
      final subject = _composeSubject(locale);
      final body = _composeBody(settings: settings, mp: mp);
      final mailto =
          'mailto:$_devEmail?subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body)}';
      final opened = await LinkOpener.open(mailto);
      if (!mounted) return;
      setState(() => _submitting = false);
      if (!opened) {
        await ClipboardHelper.copyWithFeedback(
          context,
          'To: $_devEmail\n'
          'Subject: $subject\n\n$body',
          messageOverride:
              uiStrings['feedbackCopiedFallback']?[locale] ??
                  'Mail app unavailable — feedback copied to clipboard. '
                      'Paste it into your email to $_devEmail.',
        );
        return;
      }
      messenger.showSnackBar(SnackBar(
        content: Text(uiStrings['feedbackOpenedMail']?[locale] ??
            'Mail app opened. Tap Send to deliver your feedback.'),
        duration: const Duration(seconds: 3),
      ));
      Get.back();
      return;
    }

    // Genuine error (network down, Resend rejected, etc.). Show
    // the message inline; let the user retry without losing what
    // they typed.
    setState(() => _submitting = false);
    messenger.showSnackBar(SnackBar(
      content: Text(
        (uiStrings['feedbackErrorPrefix']?[locale] ??
                'Could not send feedback: ') +
            (result.errorMessage ?? 'Unknown error'),
      ),
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final fs = settings.fontSize;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['feedback']?[locale] ?? 'Feedback'),
        actions: const [HomeIconButton()],
      ),
      body: SafeArea(
        // 2026-05-07 (v14): center + cap the form width on wide
        // monitors. Without this, every TextField stretched to the
        // full viewport (~1900 px on a desktop) which is unreadable
        // and looks unfinished. 600 px matches the comfortable
        // line-length used on the Welcome page and the auth flow.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // Intro / framing — sets the expectation that this
              // goes directly to the developer's inbox via the
              // user's mail client.
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.mail_outline_rounded,
                        size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        uiStrings['feedbackIntro']?[locale] ??
                            'Tap "Send via Email" and your default mail app will open with this message ready for you to send to the developer.',
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: (fs - 3).clamp(11.0, 14.0).toDouble(),
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Category picker — chip row.
              Text(
                uiStrings['feedbackCategoryLabel']?[locale] ??
                    'What is this about?',
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontSize: (fs - 2).clamp(12.0, 15.0).toDouble(),
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cat in _FeedbackCategory.values)
                    ChoiceChip(
                      label: Text(_categoryLabel(cat, locale)),
                      selected: _category == cat,
                      onSelected: (_) =>
                          setState(() => _category = cat),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // Required message field.
              Text(
                uiStrings['feedbackMessageLabel']?[locale] ??
                    'Your message *',
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontSize: (fs - 2).clamp(12.0, 15.0).toDouble(),
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _messageController,
                minLines: 5,
                maxLines: 12,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: uiStrings['feedbackMessageHint']?[locale] ??
                      'Describe the bug / feature / thought.',
                  border: const OutlineInputBorder(),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),

              // Optional name.
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: uiStrings['feedbackNameLabel']?[locale] ??
                      'Your name (optional)',
                  border: const OutlineInputBorder(),
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),

              // 2026-05-07 (v15): "send me a copy" affordance, two
              // shapes depending on sign-in state:
              //   - Signed in -> a checkbox showing the auth email
              //     (we know it; user just ticks to opt in).
              //   - Guest    -> an editable email field; non-empty
              //     means "send me a copy here".
              // Both feed into the same submit-time fields
              // (`replyTo` + `copyEmail`) so the rest of the
              // pipeline doesn't care which case fired.
              Builder(builder: (_) {
                final user = CloudAuthService.instance.currentUser;
                final signedInEmail = user?.email ?? '';
                final isSignedIn = signedInEmail.isNotEmpty;
                if (isSignedIn) {
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _wantCopySignedIn,
                    onChanged: (v) =>
                        setState(() => _wantCopySignedIn = v ?? false),
                    title: Text(
                      uiStrings['feedbackCopyToMe']?[locale] ??
                          'Send a copy to me',
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontSize: (fs - 2).clamp(12.0, 15.0).toDouble(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      signedInEmail,
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontSize: (fs - 3).clamp(11.0, 13.0).toDouble(),
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                // Guest path: editable email field; whatever they
                // type is treated as "send me a copy here".
                return TextField(
                  controller: _copyEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: uiStrings['feedbackCopyEmailLabel']?[locale] ??
                        'Your email (optional — we will send you a copy)',
                    hintText: 'you@example.com',
                    border: const OutlineInputBorder(),
                    filled: true,
                  ),
                );
              }),
              const SizedBox(height: 22),

              // Send button.
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _submitting
                      ? (uiStrings['feedbackSending']?[locale] ?? 'Sending…')
                      : (uiStrings['feedbackSend']?[locale] ?? 'Send'),
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontSize: (fs - 1).clamp(13.0, 16.0).toDouble(),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                uiStrings['feedbackPrivacyNote']?[locale] ??
                    'No data is sent automatically. Pressing the button '
                        'just opens your mail app with this content '
                        'pre-filled — you choose whether to hit Send.',
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontSize: (fs - 4).clamp(10.0, 12.0).toDouble(),
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }
}
