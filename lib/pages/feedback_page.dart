import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';
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
  final _replyToController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _replyToController.dispose();
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

  /// Build the email body: structured user input + auto-attached
  /// metadata. The metadata block is clearly delimited so the
  /// user can edit / strip it before sending if they prefer.
  String _composeBody({
    required AppSettings settings,
    required MainProvider mp,
  }) {
    final name = _nameController.text.trim();
    final replyTo = _replyToController.text.trim();
    final msg = _messageController.text.trim();

    final lines = <String>[];
    if (msg.isNotEmpty) {
      lines.add(msg);
      lines.add('');
    }
    lines.add('---');
    lines.add('Category: ${_categoryShort(_category)}');
    if (name.isNotEmpty) lines.add('Name: $name');
    if (replyTo.isNotEmpty) lines.add('Reply-to: $replyTo');
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

  Future<void> _submit() async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final mp = Provider.of<MainProvider>(context, listen: false);
    final locale = settings.locale;

    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(uiStrings['feedbackMessageRequired']?[locale] ??
            'Please write a message before sending.'),
        duration: const Duration(seconds: 2),
      ));
      return;
    }

    final subject = _composeSubject(locale);
    final body = _composeBody(settings: settings, mp: mp);
    final mailto =
        'mailto:$_devEmail?subject=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body)}';

    final ok = await LinkOpener.open(mailto);
    if (!mounted) return;
    if (!ok) {
      // Mail-client launch failed (rare on web — usually means
      // the browser had no protocol handler registered, or a
      // popup blocker fired). Fall back to clipboard so the
      // user can paste into webmail manually.
      await ClipboardHelper.copyWithFeedback(
        context,
        'To: $_devEmail\n'
        'Subject: $subject\n\n$body',
        messageOverride: uiStrings['feedbackCopiedFallback']?[locale] ??
            'Mail app unavailable — feedback copied to clipboard. '
                'Paste it into your email to $_devEmail.',
      );
      return;
    }
    // Show a "thanks" snackbar. The user still has to hit Send
    // in their mail client; we can't confirm delivery from here.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(uiStrings['feedbackOpenedMail']?[locale] ??
          'Mail app opened. Tap Send to deliver your feedback.'),
      duration: const Duration(seconds: 3),
    ));
    // Pop back so the user lands wherever they came from.
    Get.back();
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

              // Optional name + reply-to.
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
              TextField(
                controller: _replyToController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: uiStrings['feedbackReplyToLabel']?[locale] ??
                      'Reply-to email (optional)',
                  hintText: 'you@example.com',
                  border: const OutlineInputBorder(),
                  filled: true,
                ),
              ),
              const SizedBox(height: 22),

              // Send button.
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send_rounded),
                label: Text(
                  uiStrings['feedbackSend']?[locale] ?? 'Send via Email',
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
    );
  }
}
