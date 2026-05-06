import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/utils/theme_color_helpers.dart';

/// Settings → AI → "Use my own Gemini API key" (BYOK) card.
///
/// Why this exists: AI explanations + AI search go through Gemini,
/// which is metered. The developer-shared key has limited free
/// quota; once exhausted everyone gets "AI explanation is not
/// available right now". Letting users paste their own key from
/// AI Studio (free, instant) gives each user their own 15 RPM /
/// 1500 RPD budget — way more than they'll ever hit, and it
/// removes the developer's cost ceiling.
///
/// Storage: SharedPreferences only — never transmitted off-device
/// except as a body field on the next AI request, which is a same-
/// origin POST to our Netlify function. The function uses the key
/// to call Gemini directly and never logs / persists it.
class GeminiKeyCard extends StatefulWidget {
  final AppSettings settings;
  final double s;
  const GeminiKeyCard({super.key, required this.settings, required this.s});

  @override
  State<GeminiKeyCard> createState() => GeminiKeyCardState();
}

class GeminiKeyCardState extends State<GeminiKeyCard> {
  late final TextEditingController _ctrl;
  bool _obscure = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.settings.geminiApiKey);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.settings.setGeminiApiKey(_ctrl.text);
    if (!mounted) return;
    setState(() => _saved = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Future<void> _openAiStudio() async {
    if (!LinkOpener.isAvailable) return;
    await LinkOpener.open('https://aistudio.google.com/apikey');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.settings.locale;
    final s = widget.s;
    final hasKey = widget.settings.hasUserGeminiKey;
    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(14 * s, 12 * s, 14 * s, 12 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy_outlined,
                    size: 18, color: scheme.primary),
                SizedBox(width: 8 * s),
                Text(
                  uiStrings['aiByokTitle']?[locale] ??
                      'Use my own Gemini API key',
                  style: TextStyle(
                    fontFamily: widget.settings.fontFamily,
                    fontSize: (widget.settings.fontSize - 1)
                        .clamp(13.0, 16.0),
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (hasKey)
                  Icon(Icons.check_circle_outline_rounded,
                      size: 18, color: paletteAccent(context, Colors.green)),
              ],
            ),
            SizedBox(height: 6 * s),
            Text(
              uiStrings['aiByokBody']?[locale] ??
                  'Paste your free Gemini API key from AI Studio so AI '
                      'features use your own quota (15 requests / minute, '
                      '1500 / day). Without one, you share the developer '
                      'pool — when it runs out, AI features pause for '
                      'everyone. The key stays on this device only.',
              style: TextStyle(
                fontFamily: widget.settings.fontFamily,
                fontSize: (widget.settings.fontSize - 4)
                    .clamp(11.0, 13.0),
                color: scheme.onSurface.withValues(alpha: 0.78),
                height: 1.5,
              ),
            ),
            SizedBox(height: 8 * s),
            TextField(
              controller: _ctrl,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: 'AIza…',
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscure
                      ? (uiStrings['show']?[locale] ?? 'Show')
                      : (uiStrings['hide']?[locale] ?? 'Hide'),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: (widget.settings.fontSize - 3)
                    .clamp(12.0, 14.0),
              ),
            ),
            SizedBox(height: 8 * s),
            Row(
              children: [
                FilledButton.icon(
                  icon: Icon(
                    _saved ? Icons.check_rounded : Icons.save_outlined,
                    size: 16,
                  ),
                  label: Text(
                    _saved
                        ? (uiStrings['saved']?[locale] ?? 'Saved')
                        : (uiStrings['save']?[locale] ?? 'Save'),
                  ),
                  onPressed: _save,
                ),
                SizedBox(width: 8 * s),
                if (hasKey)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16),
                    label: Text(uiStrings['clear']?[locale] ?? 'Clear'),
                    onPressed: () async {
                      _ctrl.clear();
                      await widget.settings.setGeminiApiKey('');
                      if (mounted) setState(() {});
                    },
                  ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(
                    uiStrings['aiByokGetKey']?[locale] ??
                        'Get free key',
                  ),
                  onPressed: _openAiStudio,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
