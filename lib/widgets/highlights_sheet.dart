import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/utils/version_mapper.dart'
    show localeAwareBookName;

/// A parsed verse reference recovered from a stored highlight ID.
/// ID format: "EnglishBook-chapter-verseLabel"
/// e.g. "Genesis-1-1", "1 Samuel-3-16"
class _HighlightRef {
  final String id;
  final String book;
  final int chapter;
  final String verseLabel;
  final int color;

  const _HighlightRef({
    required this.id,
    required this.book,
    required this.chapter,
    required this.verseLabel,
    required this.color,
  });

  static _HighlightRef? tryParse(String id, int color) {
    // Split from the right so book names containing spaces work fine.
    final lastDash = id.lastIndexOf('-');
    if (lastDash < 0) return null;
    final verseLabel = id.substring(lastDash + 1);
    final rest = id.substring(0, lastDash);
    final prevDash = rest.lastIndexOf('-');
    if (prevDash < 0) return null;
    final chapterStr = rest.substring(prevDash + 1);
    final book = rest.substring(0, prevDash);
    final chapter = int.tryParse(chapterStr);
    if (chapter == null || book.isEmpty || verseLabel.isEmpty) return null;
    return _HighlightRef(
      id: id,
      book: book,
      chapter: chapter,
      verseLabel: verseLabel,
      color: color,
    );
  }

  String get label => '$book $chapter:$verseLabel';
}

/// Bottom sheet that lists all saved highlights grouped by color.
/// Each row is tappable; [onNavigate] receives the English book name,
/// chapter, and verse number so the host can close the sheet and jump.
///
/// Highlight IDs are stored with English book names (e.g.
/// "1 Chronicles-3-19") for cross-version persistence. The display
/// label translates the book name to [currentVersion]'s naming via
/// `translateBookName` so a CUVS reader sees "马可福音 4:7" rather
/// than "Mark 4:7".
class HighlightsSheet extends StatelessWidget {
  final Map<String, int> highlights;
  final String locale;
  final String? currentVersion;
  final void Function(String englishBook, int chapter, int verse)? onNavigate;

  const HighlightsSheet({
    super.key,
    required this.highlights,
    required this.locale,
    this.currentVersion,
    this.onNavigate,
  });

  // The 6 fixed highlight colors in the app, in display order.
  static const _palette = <int>[
    0xFFFFF176, // yellow
    0xFFA5D6A7, // green
    0xFF90CAF9, // blue
    0xFFF48FB1, // pink
    0xFFFFCC80, // orange
    0xFFCE93D8, // purple
  ];

  static const _colorLabels = <int, Map<String, String>>{
    0xFFFFF176: {'en': 'Yellow', 'zh-Hans': '黄色', 'zh-Hant': '黃色'},
    0xFFA5D6A7: {'en': 'Green',  'zh-Hans': '绿色', 'zh-Hant': '綠色'},
    0xFF90CAF9: {'en': 'Blue',   'zh-Hans': '蓝色', 'zh-Hant': '藍色'},
    0xFFF48FB1: {'en': 'Pink',   'zh-Hans': '粉色', 'zh-Hant': '粉色'},
    0xFFFFCC80: {'en': 'Orange', 'zh-Hans': '橙色', 'zh-Hant': '橙色'},
    0xFFCE93D8: {'en': 'Purple', 'zh-Hans': '紫色', 'zh-Hant': '紫色'},
  };

  String _colorLabel(int argb) {
    final map = _colorLabels[argb];
    if (map == null) return '';
    return map[locale] ?? map['en'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = uiStrings['myHighlights']?[locale] ?? 'My Highlights';

    // Parse and group by color, maintaining palette order.
    final grouped = <int, List<_HighlightRef>>{};
    for (final entry in highlights.entries) {
      final ref = _HighlightRef.tryParse(entry.key, entry.value);
      if (ref == null) continue;
      grouped.putIfAbsent(entry.value, () => []).add(ref);
    }
    // Sort each group canonically (book order is implicit in palette; within
    // a color sort by book name then chapter then verse label).
    for (final list in grouped.values) {
      list.sort((a, b) {
        final bc = a.book.compareTo(b.book);
        if (bc != 0) return bc;
        final cc = a.chapter.compareTo(b.chapter);
        if (cc != 0) return cc;
        final av = int.tryParse(a.verseLabel) ?? 0;
        final bv = int.tryParse(b.verseLabel) ?? 0;
        return av.compareTo(bv);
      });
    }

    final hasAny = grouped.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
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
                  Icon(Icons.bookmark_rounded,
                      color: scheme.primary, size: 20),
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
              child: hasAny
                  ? ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                      children: [
                        for (final argb in _palette)
                          if (grouped.containsKey(argb))
                            _ColorSection(
                              argb: argb,
                              label: _colorLabel(argb),
                              refs: grouped[argb]!,
                              scheme: scheme,
                              locale: locale,
                              currentVersion: currentVersion,
                              onNavigate: onNavigate,
                            ),
                      ],
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          uiStrings['noHighlights']?[locale] ??
                              'No highlights yet.\nSelect a verse and tap the highlight button to save.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: scheme.onSurfaceVariant,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ColorSection extends StatefulWidget {
  final int argb;
  final String label;
  final List<_HighlightRef> refs;
  final ColorScheme scheme;
  final String locale;
  final String? currentVersion;
  final void Function(String, int, int)? onNavigate;

  const _ColorSection({
    required this.argb,
    required this.label,
    required this.refs,
    required this.scheme,
    required this.locale,
    required this.currentVersion,
    required this.onNavigate,
  });

  @override
  State<_ColorSection> createState() => _ColorSectionState();
}

class _ColorSectionState extends State<_ColorSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final count = widget.refs.length;
    final countLabel = count.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Color(widget.argb),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    countLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          for (final ref in widget.refs)
            _RefRow(
              ref: ref,
              argb: widget.argb,
              scheme: scheme,
              locale: widget.locale,
              currentVersion: widget.currentVersion,
              onNavigate: widget.onNavigate,
            ),
        const Divider(height: 1, indent: 20, endIndent: 20),
      ],
    );
  }
}

class _RefRow extends StatelessWidget {
  final _HighlightRef ref;
  final int argb;
  final ColorScheme scheme;
  final String locale;
  final String? currentVersion;
  final void Function(String, int, int)? onNavigate;

  const _RefRow({
    required this.ref,
    required this.argb,
    required this.scheme,
    required this.locale,
    required this.currentVersion,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final canNav = onNavigate != null;
    final displayBook = localeAwareBookName(ref.book, locale, currentVersion);
    final displayLabel = '$displayBook ${ref.chapter}:${ref.verseLabel}';
    return InkWell(
      onTap: canNav
          ? () {
              final verse = int.tryParse(ref.verseLabel) ?? 1;
              onNavigate!(ref.book, ref.chapter, verse);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                color: Color(argb),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                displayLabel,
                style: TextStyle(
                  fontSize: 14,
                  color: canNav ? scheme.primary : scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (canNav)
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: scheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}
