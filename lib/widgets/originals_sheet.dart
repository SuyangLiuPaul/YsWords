import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/original_word.dart';
import 'package:yswords/models/strongs.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/services/concordance_service.dart';
import 'package:yswords/services/originals_service.dart';
import 'package:yswords/services/strongs_service.dart';
import 'package:yswords/utils/version_mapper.dart'
    show toEnglish, translateBookName;

/// Bottom sheet that shows the original Hebrew/Greek text for one or
/// more selected verses, with each word as a tappable chip linked to
/// its Strong's lexicon entry.
///
/// Pure data — no AI, no network. The sheet falls back to a friendly
/// "no original-language data for this verse yet" message when bundled
/// coverage is missing for the verse, so the affordance always opens.
///
/// `onNavigateRef` is invoked when the user taps a concordance entry
/// (e.g. "John 3:16"). The host widget is responsible for closing the
/// sheet, switching to that book/chapter, and scrolling to the verse —
/// the sheet stays presentation-only.
class OriginalsSheet extends StatefulWidget {
  final List<Verse> verses;
  final String locale;
  final String? currentVersion;
  final void Function(ConcordanceRef ref)? onNavigateRef;

  const OriginalsSheet({
    super.key,
    required this.verses,
    required this.locale,
    this.currentVersion,
    this.onNavigateRef,
  });

  @override
  State<OriginalsSheet> createState() => _OriginalsSheetState();
}

class _OriginalsSheetState extends State<OriginalsSheet> {
  late Future<List<_VerseOriginals>> _future;
  OriginalWord? _selectedWord;
  StrongsEntry? _selectedEntry;
  ConcordanceResult? _selectedConcordance;
  // When non-null, the user is browsing a root entry instead of the
  // word entry. Back button reverts to the word entry.
  StrongsEntry? _rootEntry;
  ConcordanceResult? _rootConcordance;
  bool _loadingEntry = false;
  // TapGestureRecognizers for inline derivation links — disposed on change.
  final _tapRecognizers = <TapGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
  }

  @override
  void dispose() {
    _clearTapRecognizers();
    super.dispose();
  }

  void _clearTapRecognizers() {
    for (final r in _tapRecognizers) {
      r.dispose();
    }
    _tapRecognizers.clear();
  }

  Future<List<_VerseOriginals>> _loadAll() async {
    final results = <_VerseOriginals>[];
    for (final v in widget.verses) {
      final english = toEnglish(v.book) ?? v.book;
      final words = await OriginalsService.forVerse(english, v.chapter, v.verse);
      results.add(_VerseOriginals(verse: v, words: words));
    }
    return results;
  }

  Future<void> _onWordTap(OriginalWord w) async {
    _clearTapRecognizers();
    setState(() {
      _selectedWord = w;
      _selectedEntry = null;
      _selectedConcordance = null;
      _rootEntry = null;
      _rootConcordance = null;
      _loadingEntry = true;
    });
    // Fire both lookups in parallel — Strong's entry is per-language,
    // concordance is a single shared file that gets warmed by the
    // first lookup of the session.
    final entryFuture = StrongsService.lookup(w.strongs);
    final concordanceFuture = ConcordanceService.lookup(w.strongs);
    final entry = await entryFuture;
    final concordance = await concordanceFuture;
    if (!mounted) return;
    _clearTapRecognizers();
    setState(() {
      _selectedEntry = entry;
      _selectedConcordance = concordance;
      _loadingEntry = false;
    });
  }

  Future<void> _loadRootEntry(String strongsNumber) async {
    _clearTapRecognizers();
    setState(() { _loadingEntry = true; });
    final entryFuture = StrongsService.lookup(strongsNumber);
    final concordanceFuture = ConcordanceService.lookup(strongsNumber);
    final entry = await entryFuture;
    final concordance = await concordanceFuture;
    if (!mounted) return;
    _clearTapRecognizers();
    setState(() {
      _rootEntry = entry;
      _rootConcordance = concordance;
      _loadingEntry = false;
    });
  }

  void _clearRoot() {
    _clearTapRecognizers();
    setState(() {
      _rootEntry = null;
      _rootConcordance = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    final title = uiStrings['originalText']?[locale] ?? 'Original Text';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.translate, color: scheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<_VerseOriginals>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snap.data ?? const [];
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      for (final vo in data) _buildVerseBlock(vo, scheme),
                      if (_selectedWord != null) ...[
                        const SizedBox(height: 16),
                        _buildEntryCard(scheme, locale),
                      ] else ...[
                        const SizedBox(height: 16),
                        _buildHint(scheme, locale),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVerseBlock(_VerseOriginals vo, ColorScheme scheme) {
    final ref = '${vo.verse.book} ${vo.verse.chapter}:${vo.verse.verse}';
    final isHebrew = (vo.words ?? const []).isNotEmpty &&
        vo.words!.first.strongs.startsWith('H');
    final words = vo.words;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ref,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          if (words == null || words.isEmpty)
            Text(
              uiStrings['originalNotAvailable']?[widget.locale] ??
                  'Original-language data not available for this verse yet.',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Directionality(
              textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
              child: Wrap(
                spacing: 6,
                runSpacing: 8,
                alignment: isHebrew ? WrapAlignment.end : WrapAlignment.start,
                children: [
                  for (final w in words) _wordChip(w, scheme),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _wordChip(OriginalWord w, ColorScheme scheme) {
    final isSelected = _selectedWord?.strongs == w.strongs &&
        _selectedWord?.text == w.text;
    return InkWell(
      onTap: () => _onWordTap(w),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? scheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              w.text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            if (w.translit != null && w.translit!.isNotEmpty)
              Text(
                w.translit!,
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(ColorScheme scheme, String locale) {
    final w = _selectedWord!;
    if (_loadingEntry) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // When the user has tapped a root link, show that entry instead.
    final isBrowsingRoot = _rootEntry != null;
    final entry = isBrowsingRoot ? _rootEntry : _selectedEntry;
    final concordance = isBrowsingRoot ? _rootConcordance : _selectedConcordance;
    // The displayed number: root number when browsing, otherwise the word's.
    final displayNumber = entry?.number ?? w.strongs;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isBrowsingRoot) ...[
                InkWell(
                  onTap: _clearRoot,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.arrow_back,
                        size: 18, color: scheme.primary),
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  displayNumber,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry?.lemma ?? w.text,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (entry != null) ...[
            if (entry.translit.isNotEmpty || entry.pronunciation.isNotEmpty)
              Text(
                [
                  if (entry.translit.isNotEmpty) entry.translit,
                  if (entry.pronunciation.isNotEmpty) '/${entry.pronunciation}/',
                ].join('  '),
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            // Headline gloss and full definition follow the user's
            // current locale: Chinese for zh-Hans / zh-Hant when CBOL
            // has data, English fallback otherwise.
            if (entry.localizedGloss(locale).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.localizedGloss(locale),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
            if (entry.partOfSpeech != null &&
                entry.partOfSpeech!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.partOfSpeech!,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
            ],
            if (entry.localizedDefinition(locale).isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                entry.localizedDefinition(locale),
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurface,
                  height: 1.45,
                ),
              ),
              if (locale.startsWith('zh') &&
                  (entry.definitionZh ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  // CC-BY-NC-SA 4.0 attribution required by the source.
                  '中文释义来源：CBOL · bible.fhl.net (CC-BY-NC-SA 4.0)',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
            // Derivation / etymology line with tappable Strong's refs.
            if ((entry.derivation ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildDerivationRich(entry.derivation!, scheme),
            ],
          ] else
            Text(
              uiStrings['strongsNotFound']?[locale] ??
                  'Lexicon entry not found for $displayNumber.',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (concordance != null && concordance.refs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(
                height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            _buildConcordance(scheme, locale, concordance),
          ],
        ],
      ),
    );
  }

  /// Renders [text] with any Strong's refs ([GH]\d+) as tappable blue links.
  /// Recognizers are tracked in [_tapRecognizers] and disposed on state change.
  Widget _buildDerivationRich(String text, ColorScheme scheme) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'([GH]\d+)');
    int last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final num = m.group(1)!;
      final rec = TapGestureRecognizer()
        ..onTap = () => _loadRootEntry(num);
      _tapRecognizers.add(rec);
      spans.add(TextSpan(
        text: num,
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: scheme.primary.withValues(alpha: 0.6),
        ),
        recognizer: rec,
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 12,
          color: scheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
          height: 1.45,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildConcordance(
      ColorScheme scheme, String locale, ConcordanceResult cr) {
    final usedTemplate = uiStrings['concordanceUsed']?[locale] ??
        'Used {count} times';
    final usedLabel =
        usedTemplate.replaceAll('{count}', cr.total.toString());
    final shown = cr.refs.length;
    final showingFirst = shown < cr.total
        ? (uiStrings['concordanceShowingFirst']?[locale] ??
                'showing first {shown} of {total}')
            .replaceAll('{shown}', shown.toString())
            .replaceAll('{total}', cr.total.toString())
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.menu_book_outlined,
                size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                usedLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        if (showingFirst != null) ...[
          const SizedBox(height: 2),
          Text(
            showingFirst,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in cr.refs) _refChip(r, scheme),
          ],
        ),
      ],
    );
  }

  String _localizedRefLabel(ConcordanceRef r) {
    // Translate the English book name to the current version's
    // book naming so a reader of CUVS sees "约翰福音 3:16" rather
    // than "John 3:16". `translateBookName` falls back to the
    // English name when no mapping exists.
    final v = widget.currentVersion;
    if (v == null) return r.label;
    final localBook = translateBookName(r.englishBook, v);
    return '$localBook ${r.chapter}:${r.verse}';
  }

  Widget _refChip(ConcordanceRef r, ColorScheme scheme) {
    final canNavigate = widget.onNavigateRef != null;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: canNavigate ? () => widget.onNavigateRef!(r) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            _localizedRefLabel(r),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: canNavigate
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHint(ColorScheme scheme, String locale) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined,
              color: scheme.onSurfaceVariant, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              uiStrings['originalHint']?[locale] ??
                  'Tap a word to see its Strong\'s entry.',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerseOriginals {
  final Verse verse;
  final List<OriginalWord>? words;
  _VerseOriginals({required this.verse, required this.words});
}
