import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/services/reading_plan_service.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/note_reference_parser.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/version_mapper.dart' show translateBookName;
import 'package:yswords/widgets/verse_popup_sheet.dart' show showVersePopup;
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
    // 2026-05-19 (v1.2.60): group consecutive verses with identical
    // note text into one tile — collapses WeDevote-style "passage
    // notes" (where the user selected a range + wrote one note that
    // got saved to each verse in the range) back into a single row
    // labelled "Book Ch:V-V". Single-verse notes (the most common
    // case) stay as one tile, one verse — same as before.
    final entries = _resolveAnnotations(mainProvider, notes.keys);
    final groups = _groupContiguousNotes(entries, notes);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final group = groups[i];
        final headVerse = group.verses.first;
        final note = group.text;
        // Range label: "Genesis 1:16-18" for multi; "Genesis 1:16"
        // for single. Falls back to single when verses.length == 1.
        final rangeLabel = group.verses.length == 1
            ? '${headVerse.book} ${headVerse.chapter}:${headVerse.verseLabel}'
            : '${headVerse.book} ${headVerse.chapter}:'
                '${headVerse.verseLabel}-${group.verses.last.verseLabel}';
        return _AnnotationTile(
          verse: headVerse,
          rangeLabelOverride: rangeLabel,
          locale: locale,
          mainProvider: mainProvider,
          extra: note,
          onCopy: () => ClipboardHelper.copyWithFeedback(
            context,
            '[$rangeLabel] '
            '${sanitizeForSearch(headVerse.text)}\n\n$note',
          ),
          onDeleteAll: () {
            for (final v in group.verses) {
              mainProvider.clearVerseNote(verse: v);
            }
          },
        );
      },
    );
  }
}

/// 2026-05-19 (v1.2.60): a logical "passage note" — one note text
/// shared by N consecutive verses in the same book + chapter.
class _NoteGroup {
  final List<Verse> verses;
  final String text;
  const _NoteGroup({required this.verses, required this.text});
}

/// Walks the (already sorted) [entries] and merges adjacent verses
/// in the same book + chapter that share identical note text into
/// one [_NoteGroup]. Verses with different text — or any verse that
/// isn't immediately consecutive in the chapter — start a fresh
/// group.
List<_NoteGroup> _groupContiguousNotes(
    List<Verse> entries, Map<String, String> notes) {
  final groups = <_NoteGroup>[];
  for (final v in entries) {
    final txt = notes[v.id] ?? '';
    if (groups.isNotEmpty) {
      final last = groups.last;
      final lastVerse = last.verses.last;
      if (last.text == txt &&
          lastVerse.book == v.book &&
          lastVerse.chapter == v.chapter &&
          lastVerse.verse + 1 == v.verse) {
        last.verses.add(v);
        continue;
      }
    }
    groups.add(_NoteGroup(verses: [v], text: txt));
  }
  return groups;
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

  /// 2026-05-19 (v1.2.60): when set, overrides the header label to
  /// show a verse range ("Genesis 1:16-18") for multi-verse "passage
  /// notes". When null, the tile shows just the single verse's
  /// reference, same as before.
  final String? rangeLabelOverride;

  /// 2026-05-19 (v1.2.60): when set, the "Delete" menu item clears
  /// notes from EVERY verse in the multi-verse passage note rather
  /// than just the head verse. Single-verse tiles leave this null
  /// and use the legacy single-verse `clearVerseNote(verse: this.verse)`.
  final VoidCallback? onDeleteAll;

  const _AnnotationTile({
    required this.verse,
    required this.locale,
    required this.mainProvider,
    required this.extra,
    required this.onCopy,
    this.rangeLabelOverride,
    this.onDeleteAll,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final ref = rangeLabelOverride ??
        '${verse.book} ${verse.chapter}:${verse.verseLabel}';
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
              // 2026-05-19 (v1.2.59): notes with `[Book Ch:V]`
              // references render those as tappable links. Tapping
              // resolves the canonical book through the parser,
              // synthesises a target Verse against the current
              // version (or any available version that has it),
              // and runs the standard pendingJump flow into the
              // reader.
              child: RichText(
                text: TextSpan(
                  children: buildNoteSpans(
                    noteText: extra!,
                    baseStyle: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontFamily: settings.fontFamily,
                      fontSize: settings.fontSize - 2,
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                    refColor: scheme.primary,
                    // 2026-05-20 (v1.2.62): unified on the sermon
                    // page's `VersePopupSheet` — same widget the
                    // user already knows from "sermon embedded
                    // verse" popups. Convert NoteReferenceMatch →
                    // BibleReference, preserving the full comma-
                    // list verses (e.g. `[1 Kings 15:1,3-4]`) via
                    // the new optional `verses` field on
                    // BibleReference. One popup, one truth.
                    //
                    // 2026-05-20 (v1.2.64): added forensic
                    // `debugPrint` chain so users reporting "popup
                    // not opening" can paste the browser console
                    // output to point at the failing step.
                    onRefTap: (ref) {
                      debugPrint(
                          '[YsWords noteRefTap] tapped '
                          '${ref.englishBook} ${ref.chapter}:'
                          '${ref.verses.join(',')} '
                          '(start=${ref.verseStart} '
                          'end=${ref.verseEnd})');
                      final bibleRef = BibleReference(
                        englishBook: ref.englishBook,
                        chapter: ref.chapter,
                        verseStart: ref.verseStart,
                        verseEnd: ref.verseEnd,
                        verses: ref.verses,
                      );
                      try {
                        showVersePopup(context, bibleRef).then((_) {
                          debugPrint(
                              '[YsWords noteRefTap] popup closed');
                        });
                        debugPrint(
                            '[YsWords noteRefTap] showVersePopup called');
                      } catch (e, st) {
                        debugPrint(
                            '[YsWords noteRefTap] showVersePopup '
                            'threw: $e\n$st');
                      }
                    },
                  ),
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
                // 2026-05-19 (v1.2.60): if this tile represents a
                // multi-verse passage note, clear the note from every
                // verse in the range; otherwise fall back to the
                // legacy single-verse clear.
                if (onDeleteAll != null) {
                  onDeleteAll!();
                } else {
                  mainProvider.clearVerseNote(verse: verse);
                }
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
  // pendingJump handshake — see lib/utils/jump_to_reference.dart for
  // the rationale.
  jumper.prepareJumpToVerse(v, mp);
  // `Get.off(HomePage)` replaces the current Library route with the
  // bible reader. Critical because Library can be reached from EITHER
  // the dashboard (most common) OR the reader's overflow menu — and
  // we want the user to land in the reader at the verse in both
  // cases. Previous `Get.back()` only worked from the reader path; it
  // sent the user back to the dashboard from the dashboard path,
  // which the user reported as "clicking the verse goes back to home
  // page instead of the bible reader".
  Get.off(
    () => const HomePage(),
    transition: Transition.rightToLeft,
  );
}

// 2026-05-19 (v1.2.61): the v1.2.59 `_navigateToReference` helper
// is gone. Tapping a ref in a note now opens
// `showNoteReferencePreviewSheet` which has its own resolve +
// navigate path (via the "Open in Reader" button). Keeping this
// comment so future readers don't go hunting for it.

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

  Future<void> _jumpToReading(String canonical) async {
    final ref = parseReference(canonical);
    if (ref == null) {
      if (!mounted) return;
      final locale = context.read<AppSettings>().locale;
      final msg = (uiStrings['couldNotParseRef']?[locale] ??
              "Couldn't parse reference: {ref}")
          .replaceFirst('{ref}', canonical);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    final result = await jumper.resolveAndPrepareJump(
      reference: ref,
      mp: widget.mainProvider,
    );
    if (!mounted) return;
    final ok = await jumper.showJumpResultSnackBar(context, result);
    if (!ok) return;
    // Replace Library with the reader so the user lands at the verse
    // regardless of whether Library was opened from the dashboard or
    // from the reader's own overflow menu (see _navigateToVerse).
    Get.off(
      () => const HomePage(),
      transition: Transition.rightToLeft,
    );
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
    final settings = context.watch<AppSettings>();
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
                          fontFamily: settings.fontFamily,
                          fontSize: (settings.fontSize - 7)
                              .clamp(12.0, 15.0).toDouble(),
                          color: scheme.onSurfaceVariant),
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
                      style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: (settings.fontSize - 6)
                              .clamp(12.0, 15.0).toDouble()),
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
                                fontFamily: settings.fontFamily,
                                fontSize: (settings.fontSize - 6)
                                    .clamp(12.0, 16.0).toDouble(),
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

// Removed: _navigateToReference. Replaced by `_jumpToReading` which
// uses the shared `resolveAndPrepareJump` helper from
// `lib/utils/jump_to_reference.dart` so the OT-fallback (CUVS-YHWH on
// LJK1/LJK2) is consistent with the other cross-link surfaces.

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
