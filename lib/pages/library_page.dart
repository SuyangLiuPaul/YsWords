import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/services/reading_plan_service.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/version_mapper.dart' show translateBookName;
import 'package:yswords/widgets/home_icon_button.dart';
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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: const LocalizedBackButton(),
          title: Text(uiStrings['library']?[locale] ?? 'Library'),
          actions: const [HomeIconButton()],
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
              Tab(
                icon: const Icon(Icons.menu_book_outlined),
                text: uiStrings['tabPlan']?[locale] ?? 'Plan',
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
                _PlanTab(mainProvider: mainProvider, locale: locale),
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

// ── Plan tab ───────────────────────────────────────────────────────

/// Library tab showing the active reading plan day-by-day. Each day
/// is a row with chips for the day's readings + a checkbox to mark
/// the day complete. Today is highlighted and auto-scrolled to.
class _PlanTab extends StatefulWidget {
  final MainProvider mainProvider;
  final String locale;
  const _PlanTab({required this.mainProvider, required this.locale});

  @override
  State<_PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends State<_PlanTab> {
  ReadingPlan? _plan;
  int _today = 1;
  Set<int> _done = {};
  bool _loaded = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _refresh();
    // Refresh when active profile changes — keeps the displayed
    // plan + progress synced with whichever account is signed in.
    ProfileService.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    ProfileService.instance.removeListener(_refresh);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final id = await ReadingPlanService.activeId();
    if (id == null) {
      if (!mounted) return;
      setState(() {
        _plan = null;
        _loaded = true;
      });
      return;
    }
    final plan = await ReadingPlanService.byId(id);
    if (plan == null) {
      if (!mounted) return;
      setState(() {
        _plan = null;
        _loaded = true;
      });
      return;
    }
    final today = await ReadingPlanService.todayOfPlan(plan);
    final done = await ReadingPlanService.completedDays(plan.id);
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _today = today;
      _done = done;
      _loaded = true;
    });
    // Scroll to today on the next frame so the user lands on what
    // matters first. ~76 dp per row is empirical (rows have wrapping
    // chips so it varies, but it lands close).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final offset = ((today - 3).clamp(0, plan.days)) * 76.0;
      _scrollController.jumpTo(
          offset.clamp(0, _scrollController.position.maxScrollExtent));
    });
  }

  Future<void> _toggleDay(int day) async {
    final plan = _plan;
    if (plan == null) return;
    final wasDone = _done.contains(day);
    await ReadingPlanService.setDayCompleted(plan.id, day, !wasDone);
    final done = await ReadingPlanService.completedDays(plan.id);
    if (!mounted) return;
    setState(() => _done = done);
  }

  void _jumpToReading(String canonical) {
    final ref = parseReference(canonical);
    if (ref == null) return;
    _navigateToReference(widget.mainProvider, ref);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_plan == null) {
      return _emptyState(
        context,
        Icons.menu_book_outlined,
        uiStrings['planLibraryEmpty']?[widget.locale] ??
            'No reading plan selected. Pick one from Settings.',
      );
    }
    final plan = _plan!;
    final scheme = Theme.of(context).colorScheme;
    final percent = plan.days == 0
        ? 0
        : (100 * _done.length / plan.days).round();
    final progressLabel = (uiStrings['planProgress']?[widget.locale] ??
            'Progress: {done} / {total} ({percent}%)')
        .replaceAll('{done}', _done.length.toString())
        .replaceAll('{total}', plan.days.toString())
        .replaceAll('{percent}', percent.toString());

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: scheme.surfaceContainerLow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.localizedName(widget.locale),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: plan.days == 0 ? 0 : _done.length / plan.days,
                  minHeight: 6,
                  backgroundColor:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      progressLabel,
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!_scrollController.hasClients) return;
                        final offset = ((_today - 3).clamp(0, plan.days))
                            .toDouble() * 76.0;
                        _scrollController.animateTo(
                          offset.clamp(
                              0, _scrollController.position.maxScrollExtent),
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOutCubic,
                        );
                      });
                    },
                    icon: const Icon(Icons.today_outlined, size: 16),
                    label: Text(
                      uiStrings['planJumpToToday']?[widget.locale] ??
                          'Jump to today',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            itemCount: plan.days,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final day = i + 1;
              final entry = plan.dayOf(day)!;
              final isToday = day == _today;
              final done = _done.contains(day);
              return Container(
                color: isToday
                    ? scheme.primaryContainer.withValues(alpha: 0.25)
                    : null,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: done,
                      onChanged: (_) => _toggleDay(day),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 4),
                            child: Text(
                              isToday
                                  ? '${(uiStrings['planDayLabel']?[widget.locale] ?? 'Day {day} of {total}').replaceAll('{day}', day.toString()).replaceAll('{total}', plan.days.toString())}  •  ★'
                                  : 'Day $day',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isToday
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isToday
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final r in entry.readings)
                                  _PlanReadingChip(
                                    label: _localizeChip(
                                        r,
                                        widget.mainProvider.currentVersion),
                                    done: done,
                                    onTap: () => _jumpToReading(r),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _localizeChip(String canonical, String currentVersion) {
    final ref = parseReference(canonical);
    if (ref == null) return canonical;
    final localBook = translateBookName(ref.englishBook, currentVersion);
    return '$localBook ${ref.chapter}';
  }
}

class _PlanReadingChip extends StatelessWidget {
  final String label;
  final bool done;
  final VoidCallback onTap;
  const _PlanReadingChip({
    required this.label,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = done ? scheme.outline : scheme.primary;
    return Material(
      color: scheme.primary.withValues(alpha: done ? 0.04 : 0.10),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: fg,
              decoration: done ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ),
    );
  }
}

void _navigateToReference(MainProvider mp, BibleReference ref) {
  final localBook = translateBookName(ref.englishBook, mp.currentVersion);
  final matches = mp.verses
      .where((v) => v.book == localBook && v.chapter == ref.chapter)
      .toList()
    ..sort((a, b) => a.verse.compareTo(b.verse));
  if (matches.isEmpty) return;
  final targetVerse = ref.verseStart ?? matches.first.verse;
  final hit = matches.firstWhere(
    (v) => v.verse == targetVerse,
    orElse: () => matches.first,
  );
  mp.setCurrentChapter(book: hit.book, chapter: hit.chapter);
  mp.updateCurrentVerse(verse: hit);
  Get.back();
  Future.delayed(const Duration(milliseconds: 300), () {
    final relIdx = matches.indexWhere((v) => v.verse == hit.verse);
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
