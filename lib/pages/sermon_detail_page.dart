import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/sermon.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/sermon_service.dart';
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Reads one sermon body in the user's preferred language with a
/// language-toggle (EN / 简 / 繁) at the top.
///
/// The body is plain prose (Markdown H1 first line + paragraphs).
/// We render it with one Text widget per paragraph and the user's
/// reader font-size from AppSettings so it matches the Bible reader.
///
/// Phase-2 stub (TODO): once `assets/sermons/refs.json` ships, every
/// detected Bible reference in the body will be tappable. For now
/// the body is rendered as plain text.
class SermonDetailPage extends StatefulWidget {
  final Sermon sermon;
  const SermonDetailPage({super.key, required this.sermon});

  @override
  State<SermonDetailPage> createState() => _SermonDetailPageState();
}

class _SermonDetailPageState extends State<SermonDetailPage> {
  /// Currently-displayed body language code: 'en', 'zh-CN', 'zh-TW'.
  String? _lang;
  String? _body;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // First-load uses the user's UI locale to choose the best body.
    _loadForLocale();
  }

  Future<void> _loadForLocale() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final settings = context.read<AppSettings>();
    final loc = _localeToBodyLang(settings.locale);
    try {
      final res = await SermonService.instance.loadBestBody(
        sermon: widget.sermon,
        locale: loc,
      );
      if (!mounted) return;
      if (res == null) {
        setState(() {
          _loading = false;
          _error = 'No body text available for this sermon.';
        });
        return;
      }
      setState(() {
        _lang = res.lang;
        _body = res.body;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load: $e';
      });
    }
  }

  Future<void> _switchTo(String lang) async {
    if (lang == _lang) return;
    final has = lang == 'en'
        ? widget.sermon.hasEn
        : lang == 'zh-CN'
            ? widget.sermon.hasZhCn
            : widget.sermon.hasZhTw;
    if (!has) return;
    setState(() => _loading = true);
    final body = await SermonService.instance
        .loadBody(id: widget.sermon.id, lang: lang);
    if (!mounted) return;
    setState(() {
      _lang = lang;
      _body = body ?? '';
      _loading = false;
    });
  }

  String _localeToBodyLang(String appLocale) {
    switch (appLocale) {
      case 'zh-Hant':
        return 'zh-TW';
      case 'zh-Hans':
        return 'zh-CN';
      default:
        return 'en';
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final s = widget.sermon;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(
          uiStrings['sermon']?[settings.locale] ?? 'Sermon',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: const [HomeIconButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              s.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetaChip(label: '#${s.id}'),
                if (s.displayDate != '—') _MetaChip(label: s.displayDate),
                if (s.parts.isNotEmpty)
                  _MetaChip(label: '${s.parts} ${s.parts.contains('/') ? 'parts' : 'part'}'),
                if (s.passage.isNotEmpty)
                  _MetaChip(
                    label: s.passage,
                    color: scheme.primaryContainer,
                    fg: scheme.onPrimaryContainer,
                  ),
                _MetaChip(
                  label: s.topic,
                  color: scheme.surfaceContainerHigh,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _LanguageToggle(
              sermon: s,
              currentLang: _lang,
              onSelect: _switchTo,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              )
            else
              _SermonBody(text: _body ?? '', settings: settings),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? fg;
  const _MetaChip({required this.label, this.color, this.fg});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: fg ?? scheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final Sermon sermon;
  final String? currentLang;
  final void Function(String lang) onSelect;

  const _LanguageToggle({
    required this.sermon,
    required this.currentLang,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = <(String, String, bool)>[
      ('en', 'English', sermon.hasEn),
      ('zh-CN', '简体', sermon.hasZhCn),
      ('zh-TW', '繁體', sermon.hasZhTw),
    ];
    return Wrap(
      spacing: 8,
      children: [
        for (final (code, label, has) in entries)
          ChoiceChip(
            label: Text(label),
            selected: currentLang == code,
            onSelected: has ? (_) => onSelect(code) : null,
            backgroundColor:
                has ? null : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            disabledColor:
                scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            labelStyle: TextStyle(
              fontSize: 12.5,
              color: has
                  ? null
                  : scheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }
}

class _SermonBody extends StatelessWidget {
  final String text;
  final AppSettings settings;

  const _SermonBody({required this.text, required this.settings});

  /// Pattern for inline Bible references the body might mention.
  /// Conservative — book + chapter:verse(-verse?), so we don't
  /// underline numbers that aren't actually scripture refs.
  /// Built once per build instead of compiled each paragraph.
  static final RegExp _refPattern = RegExp(
    r'\b(?:[1-3]\s?)?'
    r'(?:Genesis|Exodus|Leviticus|Numbers|Deuteronomy|Joshua|Judges|Ruth|'
    r'Samuel|Kings|Chronicles|Ezra|Nehemiah|Esther|Job|Psalms?|Proverbs|'
    r'Ecclesiastes|Song(?:\s+of\s+(?:Solomon|Songs))?|Isaiah|Jeremiah|'
    r'Lamentations|Ezekiel|Daniel|Hosea|Joel|Amos|Obadiah|Jonah|Micah|'
    r'Nahum|Habakkuk|Zephaniah|Haggai|Zechariah|Malachi|Matthew|Mark|'
    r'Luke|John|Acts|Romans|Corinthians|Galatians|Ephesians|Philippians|'
    r'Colossians|Thessalonians|Timothy|Titus|Philemon|Hebrews|James|'
    r'Peter|Jude|Revelation|'
    r'Gen|Exo|Exod|Lev|Num|Deut|Josh|Judg|Ru|1Sam|2Sam|1Kgs|2Kgs|1Chr|'
    r'2Chr|Neh|Est|Ps|Prv|Prov|Eccl|Isa|Jer|Lam|Ezek|Eze|Dan|Hos|Jl|'
    r'Am|Obad|Jonah|Mic|Nah|Hab|Zeph|Hag|Zech|Mal|Matt|Mt|Mk|Lk|Jn|'
    r'Rom|Cor|Gal|Eph|Phil|Col|Thess|Tim|Heb|Pet|Rev)'
    r'\.?\s*\d+(?:\s*[:.]\s*\d+(?:\s*[-–]\s*\d+)?)?',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    // The first line is a Markdown H1 already shown in the page title.
    // Drop it from the body so we don't render the title twice.
    final lines = text.split('\n');
    var start = 0;
    if (lines.isNotEmpty && lines.first.startsWith('# ')) start = 1;
    // Skip blank lines after the title.
    while (start < lines.length && lines[start].trim().isEmpty) {
      start += 1;
    }
    final body = lines.sublist(start).join('\n').trim();

    // Split on blank lines for paragraph spacing.
    final paragraphs = body.split(RegExp(r'\n\s*\n'));
    final fontSize = settings.fontSize;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in paragraphs)
          if (p.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SelectableText.rich(
                _buildSpans(context, p.trim(), fontSize, scheme),
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.55,
                ),
              ),
            ),
      ],
    );
  }

  /// Build a [TextSpan] tree where every Bible-reference match
  /// becomes a tappable underlined span. Non-matching slices are
  /// plain text so the user can still select-and-copy normally.
  TextSpan _buildSpans(
    BuildContext context,
    String paragraph,
    double fontSize,
    ColorScheme scheme,
  ) {
    final spans = <InlineSpan>[];
    var idx = 0;
    for (final match in _refPattern.allMatches(paragraph)) {
      if (match.start > idx) {
        spans.add(TextSpan(text: paragraph.substring(idx, match.start)));
      }
      final matched = match.group(0)!;
      // Only treat as a link if our parser actually recognises it —
      // this filters out false positives like "Mark sat down" that
      // the regex catches but the alias index rejects.
      final parsed = parseReference(matched);
      if (parsed == null) {
        spans.add(TextSpan(text: matched));
      } else {
        spans.add(TextSpan(
          text: matched,
          style: TextStyle(
            color: scheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: scheme.primary.withValues(alpha: 0.4),
            decorationStyle: TextDecorationStyle.dotted,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _jumpToParsedRef(context, parsed),
        ));
      }
      idx = match.end;
    }
    if (idx < paragraph.length) {
      spans.add(TextSpan(text: paragraph.substring(idx)));
    }
    return TextSpan(children: spans);
  }

  Future<void> _jumpToParsedRef(
      BuildContext context, BibleReference ref) async {
    final mp = context.read<MainProvider>();
    final result = await jumper.resolveAndPrepareJump(reference: ref, mp: mp);
    if (!context.mounted) return;
    final ok = await jumper.showJumpResultSnackBar(context, result);
    if (!ok || !context.mounted) return;
    Get.to(
      () => const HomePage(),
      transition: Transition.rightToLeft,
    );
  }
}
