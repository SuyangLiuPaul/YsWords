/// The reader's own Gemini key is required for AI — 2026-09-18.
///
/// 「dev gemini token可以拿去了 如果他们要用 用的时候要提醒要绑定api 而且有
/// 清晰方法告诉他们」. The developer's shared key is retired (see
/// `netlify/functions/_byok.mjs`), so AI runs on the reader's key or not
/// at all. This is the reminder, shown at the moment they ask for AI —
/// not at launch, not in a banner — with the three steps written out and
/// the two places they need one tap away: the key page at Google, and
/// Settings › AI where it is pasted and tested.
///
/// Every AI entry point calls [ensureGeminiKey] first:
/// verse explain (reader), word explain (originals sheet), AI search
/// (search page) and Evidence's AI search. `test/ai_key_required_test.dart`
/// fails on an AI service call in `lib/` that is not preceded by it.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yahwehs_words/constants/build_flags.dart' show kChinaMode;
import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/settings_page.dart';
import 'package:yahwehs_words/services/link_opener.dart';
import 'package:yahwehs_words/utils/app_nav.dart';

const String kGeminiKeyPageUrl = 'https://aistudio.google.com/apikey';

/// True when the reader has a key and the AI call may go ahead. False
/// after telling them how to get one — the caller then does nothing.
Future<bool> ensureGeminiKey(BuildContext context) async {
  final settings = context.read<AppSettings>();
  if (settings.geminiApiKey.trim().isNotEmpty) return true;
  await showDialog<void>(
    context: context,
    builder: (_) => AiKeyRequiredDialog(locale: settings.locale),
  );
  return false;
}

class AiKeyRequiredDialog extends StatelessWidget {
  const AiKeyRequiredDialog({super.key, required this.locale});

  final String locale;

  String _s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = [
      _s('aiKeyStep1', 'Open aistudio.google.com/apikey and sign in with a Google account.'),
      _s('aiKeyStep2', 'Click "Create API key" and copy the key that starts with AIza.'),
      _s('aiKeyStep3', 'Come back to Settings › AI, paste it into "Use my own Gemini API key" and tap Test.'),
    ];
    return AlertDialog(
      icon: Icon(Icons.key_rounded, color: scheme.primary),
      title: Text(_s('aiKeyNeededTitle', 'AI needs your own key')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_s('aiKeyNeededBody',
                'AI features run on your own Google Gemini API key. It is free and takes about a minute:')),
            const SizedBox(height: 12),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: scheme.primaryContainer,
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(steps[i])),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _s('aiKeyNeededPrivacy',
                  'The key is kept on this device (and your own signed-in devices). It is sent only with your AI requests, never stored by us.'),
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            if (kChinaMode) ...[
              const SizedBox(height: 8),
              Text(
                _s('aiKeyNeededChina',
                    'Getting the key needs access to Google. Once saved, AI works from here as before.'),
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_s('cancel', 'Cancel')),
        ),
        if (LinkOpener.isAvailable)
          TextButton(
            onPressed: () =>
                LinkOpener.openOrWarn(context, kGeminiKeyPageUrl, locale: locale),
            child: Text(_s('aiByokGetKey', 'Get free key')),
          ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            pushPage(const SettingsPage(initialSection: SettingsSection.ai),
                routeName: '/settings');
          },
          child: Text(_s('aiKeyNeededOpenSettings', 'Open Settings')),
        ),
      ],
    );
  }
}
