import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/original_word.dart';
import 'package:yswords/models/strongs.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/services/originals_service.dart';
import 'package:yswords/services/strongs_service.dart';
import 'package:yswords/utils/version_mapper.dart' show toEnglish;

/// Bottom sheet that shows the original Hebrew/Greek text for one or
/// more selected verses, with each word as a tappable chip linked to
/// its Strong's lexicon entry.
///
/// Pure data — no AI, no network. The sheet falls back to a friendly
/// "no original-language data for this verse yet" message when bundled
/// coverage is missing for the verse, so the affordance always opens.
class OriginalsSheet extends StatefulWidget {
  final List<Verse> verses;
  final String locale;

  const OriginalsSheet({
    super.key,
    required this.verses,
    required this.locale,
  });

  @override
  State<OriginalsSheet> createState() => _OriginalsSheetState();
}

class _OriginalsSheetState extends State<OriginalsSheet> {
  late Future<List<_VerseOriginals>> _future;
  OriginalWord? _selectedWord;
  StrongsEntry? _selectedEntry;
  bool _loadingEntry = false;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
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
    setState(() {
      _selectedWord = w;
      _selectedEntry = null;
      _loadingEntry = true;
    });
    final entry = await StrongsService.lookup(w.strongs);
    if (!mounted) return;
    setState(() {
      _selectedEntry = entry;
      _loadingEntry = false;
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
    final entry = _selectedEntry;
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
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  w.strongs,
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
            if (entry.gloss.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.gloss,
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
            if (entry.definition.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                entry.definition,
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurface,
                  height: 1.45,
                ),
              ),
            ],
          ] else
            Text(
              uiStrings['strongsNotFound']?[locale] ??
                  'Lexicon entry not found for ${w.strongs}.',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
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
