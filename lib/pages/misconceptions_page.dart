import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/utils/jump_to_reference.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// 常見的聖經誤解 — what people repeat, and what the text actually says.
///
/// Requested 2026-08-11, with 「保羅其實是掃羅的羅馬名」 and 「希伯來書
/// 作者不是保羅」 as the examples.
///
/// **This is the most dangerous page in the app**, and it is worth
/// saying why in the code rather than only in a commit message. A page
/// that corrects other people's mistakes is read as authoritative; if it
/// is wrong, it is wrong in the most quotable way possible. That is
/// exactly the failure the project's standing rule names — an interface
/// that reads plausibly and is wrong gets believed and repeated.
///
/// Two defences, both structural rather than editorial:
///
///  1. Every citation is verified against the app's own `kjv.json` by
///     `scripts/build_misconceptions.py`, which refuses to write the
///     asset if a cited verse does not contain the words the entry
///     leans on.
///  2. Entries are categorised, and the category is shown. A `disputed`
///     entry is rendered as an open question, never as a correction —
///     presenting a live scholarly debate as settled would commit the
///     very error the page exists to point out.
class MisconceptionsPage extends StatefulWidget {
  const MisconceptionsPage({super.key});

  @override
  State<MisconceptionsPage> createState() => _MisconceptionsPageState();
}

class _MisconceptionsPageState extends State<MisconceptionsPage> {
  List<Map<String, dynamic>> _entries = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/misconceptions.json');
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _entries = [
            for (final e in (doc['entries'] as List? ?? []))
              e as Map<String, dynamic>,
          ]);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  String _pick(Map<String, dynamic>? m, String locale) {
    if (m == null) return '';
    return (m[locale] ?? m['zh-Hant'] ?? m['en'] ?? '') as String;
  }

  Future<void> _openRef(String label) async {
    final ref = parseReference(label);
    if (ref == null) return;
    final mp = context.read<MainProvider>();
    final result = await resolveAndPrepareJump(reference: ref, mp: mp);
    if (!mounted) return;
    final ok = await showJumpResultSnackBar(context, result);
    if (!ok || !mounted) return;
    pushPage(const HomePage());
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    final maxW = ResponsiveBreakpoints.settingsMaxWidth(
        ResponsiveBreakpoints.classOf(MediaQuery.of(context).size.width));

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['misconceptionsTitle']?[locale] ??
            'Common misunderstandings'),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: _error != null
              ? Center(child: Text('$_error'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _intro(scheme, locale),
                    const SizedBox(height: 14),
                    for (final e in _entries) ...[
                      _card(e, settings, locale, scheme),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _intro(ColorScheme scheme, String locale) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          uiStrings['misconceptionsIntro']?[locale] ??
              'What people often repeat, and what the passage actually '
                  'says. Every citation here is checked against the Bible '
                  'text this app ships. Where scholarship is genuinely '
                  'divided, the card says so instead of picking a side.',
          style: TextStyle(
              fontSize: 13, height: 1.6, color: scheme.onSurfaceVariant),
        ),
      );

  Widget _card(Map<String, dynamic> e, AppSettings settings, String locale,
      ColorScheme scheme) {
    final category = e['category'] as String? ?? 'text';
    final disputed = category == 'disputed';
    final refs = (e['refs'] as List? ?? []).cast<Map<String, dynamic>>();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        // A disputed entry is visibly a different kind of card, not a
        // correction with a caveat buried in its last line.
        border: disputed
            ? Border.all(color: scheme.tertiary.withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _categoryChip(category, locale, scheme),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(disputed ? Icons.help_outline_rounded : Icons.close_rounded,
                  size: 18,
                  color: disputed ? scheme.tertiary : scheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _pick(e['claim'] as Map<String, dynamic>?, locale),
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontFamilyFallback: kCjkFontFallback,
                    fontSize: (settings.fontSize - 1).clamp(14.0, 18.0),
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _pick(e['says'] as Map<String, dynamic>?, locale),
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontFamilyFallback: kCjkFontFallback,
              fontSize: (settings.fontSize - 2).clamp(13.0, 17.0),
              height: 1.75,
              color: scheme.onSurface,
            ),
          ),
          if (refs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in refs)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(Icons.menu_book_outlined,
                        size: 15, color: scheme.primary),
                    label: Text(
                      '${r['book']} ${r['chapter']}:${r['verse']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    // Every claim is one tap from the passage it rests
                    // on. A page like this has to be checkable, not
                    // merely trustworthy.
                    onPressed: () => _openRef(
                        '${r['book']} ${r['chapter']}:${r['verse']}'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryChip(String category, String locale, ColorScheme scheme) {
    const keys = {
      'text': 'misconceptionsCatText',
      'absent': 'misconceptionsCatAbsent',
      'tradition': 'misconceptionsCatTradition',
      'disputed': 'misconceptionsCatDisputed',
    };
    final color = switch (category) {
      'disputed' => scheme.tertiary,
      'absent' => scheme.error,
      _ => scheme.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        uiStrings[keys[category]]?[locale] ?? category,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
