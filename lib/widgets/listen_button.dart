// 2026-05-23 (v1.2.86): single Listen / 朗读 button used by all three
// AI-TTS surfaces (Bible reading, sermon detail, evidence detail).
// Click → calls AiTtsService.speak() with the user's voice prefs from
// AppSettings, swaps the icon to a Stop while playing, restores on
// completion or error. Errors surface via SnackBar so the user
// understands when TTS is unavailable instead of silently doing
// nothing.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/ai_tts_service.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

class ListenButton extends StatefulWidget {
  /// The text to speak. Auto-chunked to fit the 5000-char limit per
  /// API call when longer.
  final String text;

  /// Optional override for the speak rate. Default 1.0.
  final double speakingRate;

  /// Whether the button uses the compact (icon-only) style.
  /// `false` shows "朗读" / "Listen" label too.
  final bool compact;

  /// Optional tooltip override.
  final String? tooltip;

  /// Style nudge — pick a smaller fontSize for in-line uses.
  final double? iconSize;

  const ListenButton({
    super.key,
    required this.text,
    this.speakingRate = 1.0,
    this.compact = false,
    this.tooltip,
    this.iconSize,
  });

  @override
  State<ListenButton> createState() => _ListenButtonState();
}

class _ListenButtonState extends State<ListenButton> {
  bool _playing = false;
  bool _loading = false;

  Future<void> _toggle() async {
    if (_playing || AiTtsService.speaking) {
      await AiTtsService.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    final settings = context.read<AppSettings>();
    final text = widget.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);

    final byok = settings.geminiApiKey.trim();
    await AiTtsService.speak(
      text: text,
      locale: settings.locale,
      gender: settings.ttsVoiceGender,
      tier: settings.ttsVoiceTier,
      speakingRate: widget.speakingRate,
      // BYOK: reuse the gemini key field for now — server can take
      // either a Google Cloud key (Gemini) or a Google Cloud TTS key.
      // If they differ in user setups, we'll add a dedicated TTS-key
      // field. For dev release we keep the existing single-field UX.
      userApiKey: byok.isEmpty ? null : byok,
      onChunkStart: (i, n) {
        if (!mounted) return;
        setState(() {
          _playing = true;
          _loading = false;
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _playing = false;
          _loading = false;
        });
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(err, style: const TextStyle(fontFamilyFallback: kCjkFontFallback)),
            duration: const Duration(seconds: 4),
          ),
        );
      },
    );
    // speak() awaits all chunks; falling through means playback
    // either completed naturally or was stopped externally.
    if (mounted) {
      setState(() {
        _playing = false;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    // Don't auto-stop in dispose — the button can rebuild during
    // page navigation. Caller is responsible for explicit stops on
    // route pop if they want playback to halt.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final scheme = Theme.of(context).colorScheme;
    final label = _playing
        ? (uiStrings['ttsStop']?[locale] ?? 'Stop')
        : (uiStrings['ttsListen']?[locale] ?? 'Listen');
    final icon = _loading
        ? SizedBox(
            width: widget.iconSize ?? 18,
            height: widget.iconSize ?? 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(scheme.primary),
            ),
          )
        : Icon(
            _playing ? Icons.stop_rounded : Icons.volume_up_rounded,
            size: widget.iconSize ?? 18,
          );
    final tooltip = widget.tooltip ??
        (_playing
            ? (uiStrings['ttsStop']?[locale] ?? 'Stop')
            : (uiStrings['ttsListen']?[locale] ?? 'Listen'));

    if (widget.compact) {
      return IconButton(
        tooltip: tooltip,
        onPressed: _toggle,
        icon: icon,
      );
    }
    return OutlinedButton.icon(
      onPressed: _toggle,
      icon: icon,
      label: Text(
        label,
        style: const TextStyle(fontFamilyFallback: kCjkFontFallback),
      ),
    );
  }
}
