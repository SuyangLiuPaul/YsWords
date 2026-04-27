import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// "Library" — a single page with two tabs: Notes and Bookmarks.
/// Each tab shows the user's saved annotations for the current
/// loaded Bible version, sorted in canonical Bible order.
/// Tapping any item navigates to that verse.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const LocalizedBackButton(),
          title: Text(uiStrings['library']?[locale] ?? 'Library'),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.sticky_note_2_outlined),
                text: uiStrings['tabNotes']?[locale] ?? 'Notes',
              ),
              Tab(
                icon: const Icon(Icons.bookmark_outline_rounded),
                text: uiStrings['tabBookmarks']?[locale] ?? 'Bookmarks',
              ),
            ],
          ),
        ),
        body: Consumer<MainProvider>(
          builder: (context, mainProvider, _) {
            return TabBarView(
              children: [
                _NotesTab(mainProvider: mainProvider, locale: locale),
                _BookmarksTab(mainProvider: mainProvider, locale: locale),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotesTab extends StatelessWidget {
  final MainProvider mainProvider;
  final String locale;
  const _NotesTab({required this.mainProvider, required this.locale});

  @override
  Widget build(BuildContext context) {
    final notes = mainProvider.verseNotes;
    if (notes.isEmpty) {
      return _emptyState(
        context,
        Icons.sticky_note_2_outlined,
        uiStrings['libraryEmptyNotes']?[locale] ??
            'No notes yet. Long-press a verse and tap the note icon to add one.',
      );
    }
    final entries = _resolveAnnotations(mainProvider, notes.keys);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final v = entries[i];
        final note = notes[v.id] ?? '';
        return _AnnotationTile(
          verse: v,
          locale: locale,
          mainProvider: mainProvider,
          extra: note,
          onCopy: () => ClipboardHelper.copyWithFeedback(
            context,
            '[${v.book} ${v.chapter}:${v.verseLabel}] '
            '${sanitizeForSearch(v.text)}\n\n$note',
          ),
        );
      },
    );
  }
}

class _BookmarksTab extends StatelessWidget {
  final MainProvider mainProvider;
  final String locale;
  const _BookmarksTab({required this.mainProvider, required this.locale});

  @override
  Widget build(BuildContext context) {
    final ids = mainProvider.bookmarks;
    if (ids.isEmpty) {
      return _emptyState(
        context,
        Icons.bookmark_outline_rounded,
        uiStrings['libraryEmptyBookmarks']?[locale] ??
            'No bookmarks yet. Long-press a verse and tap the bookmark icon.',
      );
    }
    final entries = _resolveAnnotations(mainProvider, ids);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final v = entries[i];
        return _AnnotationTile(
          verse: v,
          locale: locale,
          mainProvider: mainProvider,
          extra: null,
          onCopy: () => ClipboardHelper.copyWithFeedback(
            context,
            '[${v.book} ${v.chapter}:${v.verseLabel}] '
            '${sanitizeForSearch(v.text)}',
          ),
        );
      },
    );
  }
}

class _AnnotationTile extends StatelessWidget {
  final Verse verse;
  final String locale;
  final MainProvider mainProvider;
  /// Extra text shown below the verse preview (e.g. the note body).
  /// Null hides the section.
  final String? extra;
  final VoidCallback onCopy;

  const _AnnotationTile({
    required this.verse,
    required this.locale,
    required this.mainProvider,
    required this.extra,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final ref = '${verse.book} ${verse.chapter}:${verse.verseLabel}';
    final preview = sanitizeForSearch(verse.text);
    return ListTile(
      onTap: () => _navigateToVerse(verse, mainProvider),
      title: Text(
        ref,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: scheme.primary,
          fontFamily: settings.fontFamily,
          fontSize: settings.fontSize,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface,
              fontFamily: settings.fontFamily,
              fontSize: settings.fontSize - 2,
              height: 1.4,
            ),
          ),
          if (extra != null && extra!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: scheme.primary, width: 2),
                ),
              ),
              child: Text(
                extra!,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontFamily: settings.fontFamily,
                  fontSize: settings.fontSize - 2,
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (action) {
          switch (action) {
            case 'copy':
              onCopy();
              break;
            case 'delete':
              if (extra != null) {
                mainProvider.clearVerseNote(verse: verse);
              } else {
                if (mainProvider.isBookmarked(verse)) {
                  mainProvider.toggleBookmark(verse: verse);
                }
              }
              break;
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'copy',
            child: Row(
              children: [
                const Icon(Icons.copy_outlined, size: 18),
                const SizedBox(width: 8),
                Text(uiStrings['copySelection']?[locale] ?? 'Copy'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline,
                    size: 18, color: scheme.error),
                const SizedBox(width: 8),
                Text(
                  uiStrings['noteDelete']?[locale] ?? 'Delete',
                  style: TextStyle(color: scheme.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Resolve verse IDs back to the actual [Verse] objects in the
/// loaded Bible version, keeping only the ones present (skipping
/// orphaned annotations from versions that aren't loaded). Sorted
/// in canonical Bible order — same order verses are stored in
/// MainProvider.verses.
List<Verse> _resolveAnnotations(MainProvider mp, Iterable<String> ids) {
  final byId = {for (final v in mp.verses) v.id: v};
  final out = <Verse>[];
  for (final id in ids) {
    final v = byId[id];
    if (v != null) out.add(v);
  }
  // Stable canonical order: rely on the order in mp.verses (already
  // canonical) by using its index.
  final indexById = <String, int>{
    for (int i = 0; i < mp.verses.length; i++) mp.verses[i].id: i,
  };
  out.sort((a, b) =>
      (indexById[a.id] ?? 0).compareTo(indexById[b.id] ?? 0));
  return out;
}

void _navigateToVerse(Verse v, MainProvider mp) {
  mp.setCurrentChapter(book: v.book, chapter: v.chapter);
  mp.updateCurrentVerse(verse: v);
  Get.back();
  Future.delayed(const Duration(milliseconds: 300), () {
    final chapterVerses = mp.verses
        .where((x) => x.book == v.book && x.chapter == v.chapter)
        .toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
    final relIdx = chapterVerses.indexWhere((x) => x.verse == v.verse);
    if (relIdx < 0) return;
    mp.jumpToIndex(index: relIdx);
    mp.setHighlightIndex(relIdx);
    Future.delayed(const Duration(milliseconds: 800), () {
      mp.clearHighlightIndex();
    });
  });
}

Widget _emptyState(BuildContext context, IconData icon, String text) {
  final scheme = Theme.of(context).colorScheme;
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    ),
  );
}
