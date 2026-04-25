import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/constants/text_patterns.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_books.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/version_mapper.dart' show toEnglish;
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/widgets/paragraph_group_widget.dart';
import 'package:yswords/widgets/verse_widget.dart';

/// A self-contained chapter reader rendered inside a single
/// [StackedCardScaffold] layer. Unlike the home page it does not mutate
/// the global current-book/current-chapter state — each card is locked
/// to the (book, chapter) it was opened with, so multiple cards can
/// stack and each shows its own chapter independently.
class ChapterReaderCard extends StatefulWidget {
  final String book;
  final int chapter;

  const ChapterReaderCard({
    super.key,
    required this.book,
    required this.chapter,
  });

  @override
  State<ChapterReaderCard> createState() => _ChapterReaderCardState();
}

class _ChapterReaderCardState extends State<ChapterReaderCard> {
  final ItemScrollController _scrollCtrl = ItemScrollController();

  @override
  Widget build(BuildContext context) {
    return Consumer2<MainProvider, AppSettings>(
      builder: (context, mainProvider, settings, _) {
        final verses = mainProvider.verses
            .where((v) => v.book == widget.book && v.chapter == widget.chapter)
            .toList()
          ..sort((a, b) => a.verse.compareTo(b.verse));
        final hasParagraphData =
            verses.any((v) => v.isParagraphStart == true);
        final groups = settings.paragraphMode
            ? _groupIntoParagraphs(verses)
            : verses.map((v) => [v]).toList();

        return Scaffold(
          appBar: AppBar(
            leading: const LocalizedBackButton(),
            title: Text(
              '${widget.book} ${widget.chapter}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Text(
                    shortBibleVersionLabel(mainProvider.currentVersion),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: verses.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            uiStrings['chapterUnavailable']?[settings.locale] ??
                                'This chapter is not available in the current version.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ScrollablePositionedList.builder(
                        itemScrollController: _scrollCtrl,
                        itemCount: groups.length + 1,
                        itemBuilder: (context, index) {
                          if (index >= groups.length) {
                            final bottomInset =
                                MediaQuery.of(context).padding.bottom;
                            final clearance =
                                mainProvider.selectedVerses.isEmpty ? 72 : 112;
                            return SizedBox(
                                height:
                                    bottomInset + clearance * settings.menuScale);
                          }
                          final group = groups[index];
                          int startIdx = 0;
                          for (int g = 0; g < index; g++) {
                            startIdx += groups[g].length;
                          }
                          final isFirst = index == 0;
                          if (group.length == 1) {
                            return VerseWidget(
                              verse: group.first,
                              index: startIdx,
                              hasParagraphData: hasParagraphData,
                              isFirst: isFirst,
                            );
                          }
                          return ParagraphGroupWidget(
                            group: group,
                            startVerseIndex: startIdx,
                            isFirst: isFirst,
                          );
                        },
                      ),
              ),
              if (mainProvider.selectedVerses.isNotEmpty)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _ChapterSelectionBar(
                    selected: mainProvider.selectedVerses,
                    anyHighlighted: mainProvider.selectedVerses
                        .any((v) => mainProvider.isVerseHighlighted(v)),
                    onClear: mainProvider.clearSelectedVerses,
                    onCopy: () => _copySelectedVerses(
                      context: context,
                      mainProvider: mainProvider,
                      settings: settings,
                    ),
                    onHighlight: (color) {
                      mainProvider.setHighlightsForVerses(
                        verses: mainProvider.selectedVerses,
                        color: color,
                      );
                      mainProvider.clearSelectedVerses();
                    },
                    onRemoveHighlight: () {
                      mainProvider.removeHighlightsForVerses(
                        verses: mainProvider.selectedVerses,
                      );
                      mainProvider.clearSelectedVerses();
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _copySelectedVerses({
    required BuildContext context,
    required MainProvider mainProvider,
    required AppSettings settings,
  }) async {
    final text = _formatSelectedVerses(
      verses: mainProvider.selectedVerses,
      copyFormat: settings.copyFormat,
    );
    if (text.isEmpty) return;
    await ClipboardHelper.copyText(text);
    mainProvider.clearSelectedVerses();
    if (!context.mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          uiStrings['copied']?[settings.locale] ?? 'Copied!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: scheme.primary.withValues(alpha: 0.86),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  static String _formatSelectedVerses({
    required List<Verse> verses,
    required String copyFormat,
  }) {
    if (verses.isEmpty) return '';

    int bookOrder(String book) {
      final en = toEnglish(book) ?? book;
      final idx = standardBookOrder.indexOf(en);
      return idx < 0 ? standardBookOrder.length : idx;
    }

    final sorted = [...verses]..sort((a, b) {
        final bookCmp = bookOrder(a.book).compareTo(bookOrder(b.book));
        if (bookCmp != 0) return bookCmp;
        if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
        return a.verse.compareTo(b.verse);
      });
    final first = sorted.first;

    switch (copyFormat) {
      case 'withRef':
        return sorted
            .map((v) =>
                '[${v.book} ${v.chapter}:${v.verseLabel}] ${sanitizeForSearch(v.text)}')
            .join('\n');
      case 'devotional':
        final body = sorted.map((v) => sanitizeForSearch(v.text)).join('\n');
        return '$body\n(${first.book} ${first.chapter}:${_formatVerseRangeLabels(sorted)})';
      case 'plain':
      default:
        final body = sorted
            .map((v) => '${v.verseLabel} ${sanitizeForSearch(v.text)}')
            .join('\n');
        return '${first.book} ${first.chapter}\n$body';
    }
  }

  static String _formatVerseRangeLabels(List<Verse> verses) {
    if (verses.isEmpty) return '';
    if (verses.any((v) => v.verseLabel != '${v.verse}')) {
      return verses.map((v) => v.verseLabel).join(', ');
    }
    return _formatVerseRange(verses.map((v) => v.verse).toList());
  }

  static String _formatVerseRange(List<int> nums) {
    if (nums.isEmpty) return '';
    final sorted = [...nums]..sort();
    final parts = <String>[];
    int start = sorted[0];
    int end = start;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] == end + 1) {
        end = sorted[i];
      } else {
        parts.add(start == end ? '$start' : '$start-$end');
        start = sorted[i];
        end = start;
      }
    }
    parts.add(start == end ? '$start' : '$start-$end');
    return parts.join(', ');
  }

  /// Same paragraph-grouping rule as `HomePage._groupIntoParagraphs`.
  static List<List<Verse>> _groupIntoParagraphs(List<Verse> verses) {
    if (verses.isEmpty) return [];
    final groups = <List<Verse>>[];
    List<Verse> current = [];
    for (final v in verses) {
      final startsNew = v.isParagraphStart || v.paragraphType == 'reference';
      if (startsNew && current.isNotEmpty) {
        groups.add(current);
        current = [];
      }
      current.add(v);
    }
    if (current.isNotEmpty) groups.add(current);
    return groups;
  }
}

class _ChapterSelectionBar extends StatelessWidget {
  final List<Verse> selected;
  final bool anyHighlighted;
  final VoidCallback onClear;
  final VoidCallback onCopy;
  final ValueChanged<int> onHighlight;
  final VoidCallback onRemoveHighlight;

  const _ChapterSelectionBar({
    required this.selected,
    required this.anyHighlighted,
    required this.onClear,
    required this.onCopy,
    required this.onHighlight,
    required this.onRemoveHighlight,
  });

  static const _highlightColors = <int>[
    0xFFFFF176,
    0xFFA5D6A7,
    0xFF90CAF9,
    0xFFF48FB1,
    0xFFFFCC80,
    0xFFCE93D8,
  ];

  void _showColorPicker(BuildContext context) {
    final settings = context.read<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16 * settings.menuScale),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                uiStrings['highlightColor']?[settings.locale] ??
                    'Highlight color',
                style: TextStyle(
                  fontSize: 16 * settings.menuScale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16 * settings.menuScale),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12 * settings.menuScale,
                runSpacing: 12 * settings.menuScale,
                children: _highlightColors.map((argb) {
                  return InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      Navigator.of(context).pop();
                      onHighlight(argb);
                    },
                    child: Container(
                      width: 44 * settings.menuScale,
                      height: 44 * settings.menuScale,
                      decoration: BoxDecoration(
                        color: Color(argb),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (anyHighlighted) ...[
                SizedBox(height: 12 * settings.menuScale),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onRemoveHighlight();
                  },
                  icon: const Icon(Icons.highlight_remove),
                  label: Text(
                    uiStrings['removeHighlight']?[settings.locale] ??
                        'Remove highlight',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final label =
        (uiStrings['selectedVerses']?[settings.locale] ?? '{count} selected')
            .replaceAll('{count}', '${selected.length}');
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: Material(
          color: scheme.surface.withValues(alpha: 0.94),
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 10 * settings.menuScale,
              vertical: 8 * settings.menuScale,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip:
                      uiStrings['clearSelection']?[settings.locale] ?? 'Clear',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: (settings.fontSize.clamp(11, 18) *
                              settings.menuScale)
                          .toDouble(),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip:
                      uiStrings['highlight']?[settings.locale] ?? 'Highlight',
                  onPressed: () => _showColorPicker(context),
                  icon: const Icon(Icons.format_color_fill),
                ),
                FilledButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(
                    uiStrings['copySelection']?[settings.locale] ?? 'Copy',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
