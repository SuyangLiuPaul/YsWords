import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/feedback_service.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/utils/jump_to_reference.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/utils/version_mapper.dart'
    show localizedReferenceLabel;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import '../constants/contact.dart';

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
  /// Where reader suggestions go when the mail function is not
  /// configured. Same address the Feedback page uses.
  static const String _devEmail = kSupportEmail;

  List<Map<String, dynamic>> _entries = const [];
  Object? _error;

  /// 'all' or one of the topic tags on the entries.
  String _topic = 'all';

  /// 'all' or one of text / absent / tradition / disputed.
  String _category = 'all';

  bool _filtersOpen = false;

  List<Map<String, dynamic>> get _filtered => [
        for (final e in _entries)
          if ((_topic == 'all' || e['topic'] == _topic) &&
              (_category == 'all' || e['category'] == _category))
            e,
      ];

  List<String> get _topics {
    final out = <String>[];
    for (final e in _entries) {
      final t = e['topic'] as String?;
      if (t != null && !out.contains(t)) out.add(t);
    }
    return out;
  }

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
    pushPage(const HomePage(), routeName: '/HomePage');
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
                    const SizedBox(height: 12),
                    _filterBar(scheme, locale),
                    const SizedBox(height: 14),
                    for (final e in _filtered) ...[
                      _card(e, settings, locale, scheme),
                      const SizedBox(height: 12),
                    ],
                    if (_filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: Text(
                          uiStrings['misconceptionsNoMatch']?[locale] ??
                              'Nothing matches those filters.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
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

  /// Collapsed by default: this is a reference list people read
  /// top-to-bottom, and a permanent double row of chips would push the
  /// first card off a phone screen. The count is shown on the toggle so
  /// an active filter is never invisible.
  Widget _filterBar(ColorScheme scheme, String locale) {
    const topicKeys = {
      'people': 'misconceptionsTopicPeople',
      'sayings': 'misconceptionsTopicSayings',
      'events': 'misconceptionsTopicEvents',
      'translation': 'misconceptionsTopicTranslation',
      'authorship': 'misconceptionsTopicAuthorship',
      'canon': 'misconceptionsTopicCanon',
    };
    const catKeys = {
      'text': 'misconceptionsCatText',
      'absent': 'misconceptionsCatAbsent',
      'tradition': 'misconceptionsCatTradition',
      'disputed': 'misconceptionsCatDisputed',
    };
    final active = _topic != 'all' || _category != 'all';
    final all = uiStrings['statsOriginalsAll']?[locale] ?? 'All';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _filtersOpen = !_filtersOpen),
                icon: Icon(active ? Icons.filter_list_alt : Icons.filter_list,
                    size: 18),
                label: Text(
                  active
                      ? '${uiStrings['songsFilterTitle']?[locale] ?? 'Filter'}'
                          ' · ${_filtered.length}/${_entries.length}'
                      : (uiStrings['songsFilterTitle']?[locale] ?? 'Filter'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // The submission form lives here, next to the filter, where
            // the user asked for it — someone who has just read the list
            // is exactly the person who knows what is missing from it.
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _openSubmitSheet(locale),
                icon: const Icon(Icons.add_comment_outlined, size: 18),
                label: Text(
                  uiStrings['misconceptionsSubmit']?[locale] ?? 'Suggest one',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        if (_filtersOpen) ...[
          const SizedBox(height: 10),
          Text(uiStrings['misconceptionsTopic']?[locale] ?? 'Topic',
              style: TextStyle(
                  fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            ChoiceChip(
              selected: _topic == 'all',
              label: Text(all, style: const TextStyle(fontSize: 12)),
              onSelected: (_) => setState(() => _topic = 'all'),
            ),
            for (final t in _topics)
              ChoiceChip(
                selected: _topic == t,
                label: Text(uiStrings[topicKeys[t]]?[locale] ?? t,
                    style: const TextStyle(fontSize: 12)),
                onSelected: (_) => setState(() => _topic = t),
              ),
          ]),
          const SizedBox(height: 10),
          Text(uiStrings['misconceptionsCategory']?[locale] ?? 'Kind',
              style: TextStyle(
                  fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            ChoiceChip(
              selected: _category == 'all',
              label: Text(all, style: const TextStyle(fontSize: 12)),
              onSelected: (_) => setState(() => _category = 'all'),
            ),
            for (final c in catKeys.keys)
              ChoiceChip(
                selected: _category == c,
                label: Text(uiStrings[catKeys[c]]?[locale] ?? c,
                    style: const TextStyle(fontSize: 12)),
                onSelected: (_) => setState(() => _category = c),
              ),
          ]),
        ],
      ],
    );
  }

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
          Text.rich(
            _bold(
              _pick(e['says'] as Map<String, dynamic>?, locale),
              TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: (settings.fontSize - 2).clamp(13.0, 17.0),
                height: 1.75,
                color: scheme.onSurface,
              ),
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
                    // Localised, like every other reference in the app.
                    // The stored citation is English because that is what
                    // kjv.json is keyed by and what the build script
                    // verifies against — but showing "Acts 13:9" on a page
                    // written in Chinese made the app look like it was
                    // quoting a different book from the one it opens.
                    label: Text(
                      localizedReferenceLabel(
                          '${r['book']} ${r['chapter']}:${r['verse']}',
                          locale),
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

  /// Reader submissions. Goes through the same `FeedbackService` the
  /// Feedback page uses — a Netlify function that emails the
  /// maintainer, falling back to the user's mail client when the
  /// function is unconfigured, so a suggestion is never silently lost.
  ///
  /// Tagged `misconception` in the category field so these arrive
  /// separable from ordinary feedback.
  Future<void> _openSubmitSheet(String locale) async {
    final claimCtl = TextEditingController();
    final whyCtl = TextEditingController();
    final refCtl = TextEditingController();
    final contactCtl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // useSafeArea: without it Flutter removes the top padding and a
      // full-height sheet draws under the clock.
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
        ),
        child: _SubmitForm(
          locale: locale,
          claimCtl: claimCtl,
          whyCtl: whyCtl,
          refCtl: refCtl,
          contactCtl: contactCtl,
          onSend: () => _send(sheetCtx, locale, claimCtl.text, whyCtl.text,
              refCtl.text, contactCtl.text),
        ),
      ),
    );
  }

  Future<void> _send(BuildContext sheetCtx, String locale, String claim,
      String why, String refs, String contact) async {
    if (claim.trim().isEmpty) return;
    final settings = context.read<AppSettings>();
    final mp = context.read<MainProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final body = StringBuffer()
      ..writeln('常见说法 / The claim:')
      ..writeln(claim.trim())
      ..writeln()
      ..writeln('经文实际说什么 / What the text says:')
      ..writeln(why.trim().isEmpty ? '(not given)' : why.trim())
      ..writeln()
      ..writeln('经文出处 / Suggested references:')
      ..writeln(refs.trim().isEmpty ? '(not given)' : refs.trim());

    final result = await FeedbackService.submit(
      context: sheetCtx,
      category: 'misconception',
      message: body.toString(),
      replyTo: contact.trim().isEmpty ? null : contact.trim(),
      appLocale: settings.locale,
      bibleVersion: mp.currentVersion,
    );
    if (!mounted) return;

    if (result.ok) {
      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
      messenger.showSnackBar(SnackBar(
        content: Text(uiStrings['misconceptionsThanks']?[locale] ??
            'Thank you. It will be checked against scripture before it is '
                'added.'),
        duration: const Duration(seconds: 4),
      ));
      return;
    }

    // Same fallback ladder as the Feedback page: if the mail function
    // is not configured, hand the text to the mail client, and if
    // there is no mail client, to the clipboard. A suggestion the
    // reader took the trouble to type must not evaporate.
    if (result.unconfigured) {
      final subject = 'yswords · misconception suggestion';
      final mailto = 'mailto:$_devEmail'
          '?subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body.toString())}';
      final opened = await LinkOpener.open(mailto);
      if (!mounted) return;
      if (!opened) {
        await ClipboardHelper.copyWithFeedback(
          context,
          'To: $_devEmail\nSubject: $subject\n\n$body',
          messageOverride: uiStrings['feedbackCopiedFallback']?[locale] ??
              'Mail app unavailable - copied to the clipboard instead.',
        );
        return;
      }
      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
      messenger.showSnackBar(SnackBar(
        content: Text(uiStrings['feedbackOpenedMail']?[locale] ??
            'Mail app opened. Tap Send to deliver your suggestion.'),
      ));
      return;
    }

    // A real failure. Leave the sheet open so what they typed is
    // still there to retry.
    messenger.showSnackBar(SnackBar(
      content: Text(result.errorMessage ??
          uiStrings['feedbackFailure']?[locale] ??
          'Could not send. Please try again.'),
    ));
  }

  /// Render `**...**` as actual bold instead of printing the asterisks.
  ///
  /// The entry text marks its key sentence — "四福音里一次也没有", "但数
  /// 一句话不等于解决一个问题" — and a plain [Text] showed the markers
  /// raw: "**这是一个可以数的事实。**". Reported from the phone with a
  /// screenshot, 2026-08-11.
  ///
  /// A deliberately small parser, not a Markdown package: the only
  /// syntax the generated text uses is `**`. An unpaired `**` is left
  /// as literal text rather than swallowing the rest of the card.
  static TextSpan _bold(String text, TextStyle base) {
    final spans = <TextSpan>[];
    final strong = base.copyWith(fontWeight: FontWeight.w700);
    var i = 0;
    while (i < text.length) {
      final open = text.indexOf('**', i);
      if (open < 0) {
        spans.add(TextSpan(text: text.substring(i), style: base));
        break;
      }
      final close = text.indexOf('**', open + 2);
      if (close < 0) {
        // Unpaired — show what is there rather than guessing.
        spans.add(TextSpan(text: text.substring(i), style: base));
        break;
      }
      if (open > i) {
        spans.add(TextSpan(text: text.substring(i, open), style: base));
      }
      spans.add(TextSpan(
          text: text.substring(open + 2, close), style: strong));
      i = close + 2;
    }
    return TextSpan(children: spans, style: base);
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

/// The suggestion form. Four fields, and the second one is the point:
/// asking "what does the passage actually say" up front sets the
/// standard this module is held to, and gives whoever reviews the
/// submission something to verify rather than an opinion to weigh.
class _SubmitForm extends StatefulWidget {
  final String locale;
  final TextEditingController claimCtl;
  final TextEditingController whyCtl;
  final TextEditingController refCtl;
  final TextEditingController contactCtl;
  final Future<void> Function() onSend;
  const _SubmitForm({
    required this.locale,
    required this.claimCtl,
    required this.whyCtl,
    required this.refCtl,
    required this.contactCtl,
    required this.onSend,
  });

  @override
  State<_SubmitForm> createState() => _SubmitFormState();
}

class _SubmitFormState extends State<_SubmitForm> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = widget.locale;
    InputDecoration deco(String label, String hint) => InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        );

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.add_comment_outlined, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  uiStrings['misconceptionsSubmitTitle']?[l] ??
                      'Suggest a misunderstanding',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            uiStrings['misconceptionsSubmitNote']?[l] ??
                'Everything added here is checked against the Bible text '
                    'this app ships before it appears. A reference makes '
                    'that possible — without one it may not be usable.',
            style: TextStyle(
                fontSize: 12, height: 1.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: widget.claimCtl,
            maxLines: 2,
            decoration: deco(
              uiStrings['misconceptionsFieldClaim']?[l] ?? 'The common claim',
              uiStrings['misconceptionsFieldClaimHint']?[l] ??
                  'e.g. Paul was renamed from Saul',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.whyCtl,
            maxLines: 3,
            decoration: deco(
              uiStrings['misconceptionsFieldWhy']?[l] ??
                  'What the text actually says',
              '',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.refCtl,
            decoration: deco(
              uiStrings['misconceptionsFieldRefs']?[l] ?? 'References',
              // Run through the app's own book-name mapping rather than
              // hard-coded English. A Chinese reader typing into a
              // Chinese form was being shown "Acts 13:9" as the model
              // answer — reported 2026-08-11: "feedback里面提示acts
              // 如果中文也要变吧". The example should be in the same
              // language as the form asking for it.
              localizedReferenceLabel('Acts 13:9; Acts 22:28', l),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.contactCtl,
            keyboardType: TextInputType.emailAddress,
            decoration: deco(
              uiStrings['misconceptionsFieldContact']?[l] ??
                  'Your email (optional)',
              '',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _sending
                ? null
                : () async {
                    setState(() => _sending = true);
                    await widget.onSend();
                    if (mounted) setState(() => _sending = false);
                  },
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(uiStrings['feedbackSend']?[l] ?? 'Send'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
