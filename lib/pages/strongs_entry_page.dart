import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/strongs.dart';
import 'package:yswords/services/concordance_service.dart';
import 'package:yswords/services/strongs_service.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/widgets/home_icon_button.dart';

/// Standalone page for viewing a single Strong's lexicon entry by its
/// number (e.g. "G25" / "H430"). Reachable from the search bar when
/// the user types a Strong's-shaped string. Lighter than the full
/// Originals sheet — no verse selection required, no LXX equivalents,
/// no per-word concordance browser. Just the entry, related words,
/// and a list of every verse it appears in (concordance), so the
/// user can pivot from "what does this lemma mean" to "where does
/// it occur" with one tap.
class StrongsEntryPage extends StatefulWidget {
  /// Normalized Strong's number with prefix (G or H) and digits.
  final String number;
  const StrongsEntryPage({super.key, required this.number});

  @override
  State<StrongsEntryPage> createState() => _StrongsEntryPageState();
}

class _StrongsEntryPageState extends State<StrongsEntryPage> {
  StrongsEntry? _entry;
  List<StrongsEntry> _family = const [];
  List<StrongsEntry> _compare = const [];
  ConcordanceResult? _concordance;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entry = await StrongsService.lookup(widget.number);
    if (entry == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notFound = true;
      });
      return;
    }
    final family = await StrongsService.wordFamily(widget.number);
    final compare = await StrongsService.compareWords(widget.number);
    final concordance =
        await ConcordanceService.lookup(widget.number);
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _family = family;
      _compare = compare;
      _concordance = concordance;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    return Scaffold(
      appBar: AppBar(
        leading: const HomeIconButton(),
        title: Text(widget.number),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notFound
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      uiStrings['strongsNotFound']?[locale] ??
                          'Strong\'s number not found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              : _buildEntry(context, scheme, locale, settings),
    );
  }

  Widget _buildEntry(BuildContext context, ColorScheme scheme, String locale,
      AppSettings settings) {
    final e = _entry!;
    final isGreek = e.number.startsWith('G');
    final lemmaFontSize = settings.fontSize + 8;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Lemma + transliteration row
        Card(
          color: scheme.primaryContainer.withValues(alpha: 0.30),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        e.number,
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isGreek ? 'Greek' : 'Hebrew',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      tooltip: uiStrings['copySelection']?[locale] ?? 'Copy',
                      onPressed: () {
                        ClipboardHelper.copyWithFeedback(
                          context,
                          '${e.number}: ${e.lemma} (${e.translit}) — '
                          '${e.localizedGloss(locale)}\n'
                          '${e.localizedDefinition(locale)}',
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  e.lemma,
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontSize: lemmaFontSize,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${e.translit} • ${e.pronunciation}',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if ((e.partOfSpeech ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    e.partOfSpeech!,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          e.localizedGloss(locale),
          style: TextStyle(
            fontSize: settings.fontSize + 2,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          e.localizedDefinition(locale),
          style: TextStyle(
            fontSize: settings.fontSize,
            color: scheme.onSurface,
            height: 1.5,
          ),
        ),
        if ((e.derivation ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${uiStrings['strongsDerivation']?[locale] ?? 'Derivation'}: ${e.derivation}',
              style: TextStyle(
                fontSize: settings.fontSize - 1,
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
        if (_family.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionTitle(uiStrings['strongsFamily']?[locale] ?? 'Word family',
              scheme, settings),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in _family)
                _RelatedChip(
                  entry: f,
                  locale: locale,
                  onTap: () => Get.to(
                        () => StrongsEntryPage(number: f.number),
                        transition: Transition.rightToLeft,
                      ),
                ),
            ],
          ),
        ],
        if (_compare.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionTitle(
              uiStrings['strongsCompare']?[locale] ?? 'Compare', scheme,
              settings),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in _compare)
                _RelatedChip(
                  entry: f,
                  locale: locale,
                  onTap: () => Get.to(
                        () => StrongsEntryPage(number: f.number),
                        transition: Transition.rightToLeft,
                      ),
                ),
            ],
          ),
        ],
        if (_concordance != null && _concordance!.refs.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionTitle(
              '${uiStrings['strongsOccurrences']?[locale] ?? 'Occurrences'} '
              '(${_concordance!.refs.length})',
              scheme,
              settings),
          const SizedBox(height: 8),
          for (final r in _concordance!.refs.take(200))
            ListTile(
              dense: true,
              leading: Icon(Icons.menu_book_outlined,
                  size: 16, color: scheme.outline),
              title: Text(
                '${r.englishBook} ${r.chapter}:${r.verse}',
                style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontSize: settings.fontSize - 1,
                    color: scheme.primary,
                    fontWeight: FontWeight.w600),
              ),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          if (_concordance!.refs.length > 200)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '… +${_concordance!.refs.length - 200}',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String label, ColorScheme scheme, AppSettings settings) {
    return Text(
      label,
      style: TextStyle(
        fontSize: settings.fontSize,
        fontWeight: FontWeight.w700,
        color: scheme.primary,
      ),
    );
  }
}

class _RelatedChip extends StatelessWidget {
  final StrongsEntry entry;
  final String locale;
  final VoidCallback onTap;
  const _RelatedChip({
    required this.entry,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${entry.number} ${entry.lemma}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              Text(
                entry.localizedGloss(locale),
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detect a Strong's-shaped query like "G25", "H430", "g 1234",
/// "h0001", "Strong G25". Returns a normalized number (uppercase
/// prefix + digits, leading zeros stripped) or null if no match.
String? parseStrongsNumber(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return null;
  // Allow optional "Strong's" / "Strong" prefix
  // Note: cannot use a raw string here because the regex contains an
  // apostrophe ("strong's"), which terminates Dart raw strings.
  final m = RegExp(
    "^(?:strong'?s?\\s+)?([gGhH])\\s*0*(\\d+)\$",
    caseSensitive: false,
  ).firstMatch(raw);
  if (m == null) return null;
  final prefix = m.group(1)!.toUpperCase();
  final digits = m.group(2)!;
  // Filter unrealistic ranges. Greek 1..5624, Hebrew 1..8674.
  final n = int.tryParse(digits);
  if (n == null) return null;
  if (prefix == 'G' && (n < 1 || n > 5700)) return null;
  if (prefix == 'H' && (n < 1 || n > 8700)) return null;
  return '$prefix$n';
}
