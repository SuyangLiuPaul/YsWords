import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart'
    show notePattern, bracePattern, squarePattern;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/strongs.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/concordance_service.dart';
import 'package:yswords/services/strongs_service.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/jump_to_reference.dart' show prepareJumpToVerse;
import 'package:yswords/utils/version_mapper.dart'
    show translateBookName, localeAwareBookName, toEnglish;
import 'package:yswords/widgets/collapsible_english_ref.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// Collapses runs of 2+ spaces left after stripping inline annotations
/// from a verse-text preview. Module-level so it compiles once.
final RegExp _kMultiSpaceRe = RegExp(r' {2,}');

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

  // 2026-06-18 (v1.3.90): cached English-keyed verse-text index for the
  // current Bible version, so the Occurrences list can show a preview of
  // each verse and tap-to-jump. Rebuilds only when the loaded verses or
  // version identity changes (mirrors SearchPage._getVerseIndex).
  Map<String, String>? _verseIndexCache;
  Object? _verseIndexForVerses;
  String? _verseIndexForVersion;

  Map<String, String> _verseIndex(MainProvider mp) {
    if (identical(_verseIndexForVerses, mp.verses) &&
        _verseIndexForVersion == mp.currentVersion &&
        _verseIndexCache != null) {
      return _verseIndexCache!;
    }
    _verseIndexForVerses = mp.verses;
    _verseIndexForVersion = mp.currentVersion;
    _verseIndexCache = <String, String>{
      for (final v in mp.verses)
        '${toEnglish(v.book) ?? v.book}-${v.chapter}-${v.verse}': v.text,
    };
    return _verseIndexCache!;
  }

  /// Tap handler for an occurrence: jump to that verse in the reader.
  /// If the verse isn't present in the user's current Bible version
  /// (e.g. a NT Greek word while reading an OT-only version), show a
  /// gentle notice instead of silently doing nothing.
  void _navigateToOccurrence(
      ConcordanceRef ref, MainProvider mp, String locale) {
    final localBook = translateBookName(ref.englishBook, mp.currentVersion);
    final match = mp.verses.where((v) =>
        v.book == localBook && v.chapter == ref.chapter && v.verse == ref.verse);
    if (match.isEmpty) {
      if (!mounted) return;
      final msg = uiStrings['strongsRefNotInVersion']?[locale] ??
          'This verse isn\'t in your current Bible version.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    prepareJumpToVerse(match.first, mp);
    // Replace this page with HomePage so the pendingJump lands the user
    // on the verse regardless of how the lexicon was reached.
    Get.off(() => const HomePage(), transition: Transition.rightToLeft);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(widget.number),
        actions: const [HomeIconButton()],
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
    // 2026-06-18 (v1.3.90): used by the Occurrences list to render a verse
    // preview and jump to the verse on tap.
    final mainProv = context.read<MainProvider>();
    final verseIndex = _verseIndex(mainProv);
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
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
          // v1.3.x: strip English-only CBOL noise in Chinese locale.
          e.cleanChineseDefinition(locale),
          style: TextStyle(
            fontSize: settings.fontSize,
            color: scheme.onSurface,
            height: 1.5,
          ),
        ),
        if ((e.derivation ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          // v1.3.x: derivation/etymology is English-only — collapse it
          // behind "英文参考" for Chinese readers; inline for English.
          if (locale.startsWith('zh'))
            CollapsibleEnglishRef(
              title: uiStrings['englishReference']?[locale] ??
                  'English reference',
              child: _derivationBox(e, scheme, locale, settings),
            )
          else
            _derivationBox(e, scheme, locale, settings),
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
                        // v1.3.91: a StrongsEntryPage → StrongsEntryPage push
                        // has the same GetX route name, so without this the
                        // navigation is silently blocked (preventDuplicates)
                        // and tapping a related/root word does nothing.
                        preventDuplicates: false,
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
                        // v1.3.91: a StrongsEntryPage → StrongsEntryPage push
                        // has the same GetX route name, so without this the
                        // navigation is silently blocked (preventDuplicates)
                        // and tapping a related/root word does nothing.
                        preventDuplicates: false,
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
          // 2026-06-18 (v1.3.90): each occurrence now shows the verse text
          // (from the loaded version) and is tappable to jump to that verse.
          for (final r in _concordance!.refs.take(200))
            Builder(builder: (context) {
              final displayBook = localeAwareBookName(
                  r.englishBook, locale, mainProv.currentVersion);
              final preview = verseIndex['${r.englishBook}-${r.chapter}-${r.verse}']
                  ?.replaceAll('\n', ' ')
                  .replaceAll(notePattern, '')
                  .replaceAllMapped(bracePattern, (m) => m.group(1) ?? '')
                  .replaceAllMapped(squarePattern, (m) => m.group(1) ?? '')
                  .replaceAll(_kMultiSpaceRe, ' ')
                  .trim();
              return ListTile(
                dense: true,
                leading: Icon(Icons.menu_book_outlined,
                    size: 16, color: scheme.outline),
                title: Text(
                  '$displayBook ${r.chapter}:${r.verse}',
                  style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize: settings.fontSize - 1,
                      color: scheme.primary,
                      fontWeight: FontWeight.w600),
                ),
                subtitle: (preview != null && preview.isNotEmpty)
                    ? Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontFamilyFallback: kCjkFontFallback,
                          fontSize: settings.fontSize - 3,
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    : null,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onTap: () => _navigateToOccurrence(r, mainProv, locale),
                // v1.3.94: long-press to copy this occurrence verse.
                onLongPress: () => ClipboardHelper.copyWithFeedback(
                  context,
                  (preview != null && preview.isNotEmpty)
                      ? '$displayBook ${r.chapter}:${r.verse}  $preview'
                      : '$displayBook ${r.chapter}:${r.verse}',
                ),
              );
            }),
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

  /// The derivation/etymology card (English). Built once and either
  /// shown inline (EN) or wrapped in a collapsible "英文参考" (ZH).
  Widget _derivationBox(StrongsEntry e, ColorScheme scheme, String locale,
      AppSettings settings) {
    final baseStyle = TextStyle(
      fontSize: settings.fontSize - 1,
      color: scheme.onSurfaceVariant,
      height: 1.4,
    );
    final label = uiStrings['strongsDerivation']?[locale] ?? 'Derivation';
    final text = e.derivation ?? '';
    // 2026-06-18 (v1.3.91): linkify the root references (e.g. "from G1537",
    // "Compare H10") inside the etymology so tapping a root opens that
    // root's own lexicon+occurrences page — the same view as the current
    // word. Uses a WidgetSpan per link (no TapGestureRecognizer to dispose).
    final spans = <InlineSpan>[TextSpan(text: '$label: ')];
    final re = RegExp(r'[GHgh]\d{1,5}');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final token = m.group(0)!;
      final num = parseStrongsNumber(token);
      if (num != null && num != e.number) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => Get.to(
              () => StrongsEntryPage(number: num),
              transition: Transition.rightToLeft,
              preventDuplicates: false,
            ),
            child: Text(
              token,
              style: baseStyle.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ));
      } else {
        spans.add(TextSpan(text: token));
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(TextSpan(style: baseStyle, children: spans)),
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
