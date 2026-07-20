import 'package:flutter/material.dart';
// 2026-05-24 (v1.3.7): get no longer used directly here —
// navigateToReader encapsulates the push logic.
// import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
// 2026-05-24 (v1.3.7): home_page direct import gone — navigateToReader
// helper owns the HomePage construction.
// import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/navigate_to_reader.dart';
import 'package:yswords/utils/note_reference_parser.dart';
import 'package:yswords/utils/reference_parser.dart' show BibleReference;
import 'package:yswords/widgets/verse_popup_sheet.dart' show showVersePopup;
import 'package:yswords/widgets/left_accent_card.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/utils/relative_time.dart' show relativeTime;
import 'package:yswords/widgets/bible_reading_pane.dart' show showNoteEditor;

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
    // 2026-05-21 (v1.2.69): Plan tab removed along with the rest of
    // the reading-plan feature (crashed iOS, low usage). Library is
    // now Notes + Bookmarks.
    return DefaultTabController(
      length: 2,
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

/// 2026-05-21 (v1.2.70): scope filter for the notes view. WeDevote-
/// style — readers usually want "what did I write about THIS chapter"
/// while studying, and a separate "all notes ever" view for review.
enum _NotesScope { all, chapter, book }

/// 2026-05-24 (v1.2.91): sort order for the notes view. Persisted in
/// AppSettings.notesSortMode so the user's preference survives app
/// restart and cloud-sync.
///   canonical → Genesis → Revelation (verse index in mp.verses)
///   recent    → most recently created/edited first
///   oldest    → oldest first
enum _NotesSort { canonical, recent, oldest }

_NotesSort _sortFromString(String s) {
  switch (s) {
    case 'recent':
      return _NotesSort.recent;
    case 'oldest':
      return _NotesSort.oldest;
    case 'canonical':
    default:
      return _NotesSort.canonical;
  }
}

String _sortToString(_NotesSort s) {
  switch (s) {
    case _NotesSort.recent:
      return 'recent';
    case _NotesSort.oldest:
      return 'oldest';
    case _NotesSort.canonical:
      return 'canonical';
  }
}

class _NotesTab extends StatefulWidget {
  final MainProvider mainProvider;
  final String locale;
  const _NotesTab({required this.mainProvider, required this.locale});

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab>
    with AutomaticKeepAliveClientMixin<_NotesTab> {
  _NotesScope _scope = _NotesScope.all;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final mainProvider = widget.mainProvider;
    final locale = widget.locale;
    final notes = mainProvider.verseNotes;
    final current = mainProvider.currentVerse;
    // 2026-05-24 (v1.2.91): user-selected sort mode, read from
    // AppSettings so the choice persists + syncs across devices.
    final settings = context.watch<AppSettings>();
    final sort = _sortFromString(settings.notesSortMode);

    // Resolve all IDs first, then apply the active scope filter on
    // the Verse list — comparing book names here works regardless of
    // version because both `entries` and `current` come from the same
    // MainProvider snapshot (same loaded version's labelling).
    final allEntries = _resolveAnnotations(mainProvider, notes.keys);
    final entries = _filterEntriesByScope(allEntries, current, _scope);
    // Always group on the canonical-ordered entries so multi-verse
    // passage notes (Genesis 1:16-18 sharing one note) stay merged.
    // The chosen sort is applied AFTER grouping — see _sortGroups.
    final canonicalGroups = _groupContiguousNotes(entries, notes);
    final groups = _sortGroups(
        canonicalGroups, sort, mainProvider.verseNoteTimestamps);

    // The segmented control header is always visible. When the user
    // has zero notes overall we'd hide it, but that would mean the
    // user can't even SEE the filter exists. Showing it (even when
    // every list is empty) helps discoverability.
    Widget body;
    if (notes.isEmpty) {
      body = _emptyState(
        context,
        Icons.sticky_note_2_outlined,
        uiStrings['libraryEmptyNotes']?[locale] ??
            'No notes yet. Long-press a verse and tap the note icon to add one.',
      );
    } else if (_scope != _NotesScope.all && current == null) {
      body = _emptyState(
        context,
        Icons.menu_book_outlined,
        uiStrings['notesScopeNeedsLocation']?[locale] ??
            'Open the Bible first to see notes for this chapter / book.',
      );
    } else if (groups.isEmpty) {
      // The user has notes elsewhere but none matching this scope.
      String key;
      String fallback;
      switch (_scope) {
        case _NotesScope.chapter:
          key = 'notesScopeChapterEmpty';
          fallback = 'No notes in this chapter yet.';
          break;
        case _NotesScope.book:
          key = 'notesScopeBookEmpty';
          fallback = 'No notes in this book yet.';
          break;
        case _NotesScope.all:
          key = 'libraryEmptyNotes';
          fallback = 'No notes yet.';
          break;
      }
      body = _emptyState(
        context,
        Icons.sticky_note_2_outlined,
        uiStrings[key]?[locale] ?? fallback,
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final group = groups[i];
          final headVerse = group.verses.first;
          final note = group.text;
          final rangeLabel = group.verses.length == 1
              ? '${headVerse.book} ${headVerse.chapter}:${headVerse.verseLabel}'
              : '${headVerse.book} ${headVerse.chapter}:'
                  '${headVerse.verseLabel}-${group.verses.last.verseLabel}';
          // 2026-05-24 (v1.2.91): pull the title from the head verse.
          // All verses in a passage note share the same title (set
          // together by setVerseNote in a single Save), so the head
          // is canonical.
          final title = mainProvider.getVerseNoteTitle(headVerse.id);
          return _AnnotationTile(
            verse: headVerse,
            rangeLabelOverride: rangeLabel,
            titleOverride: title,
            locale: locale,
            mainProvider: mainProvider,
            extra: note,
            // 2026-05-24 (v1.2.95): tapping the tile body opens the
            // note editor for ALL verses in the passage. Tapping
            // just the verse-ref text (handled inside the tile)
            // jumps to that verse — matches user expectation
            // "按了应该打开笔记本而不是跳到那个经文章节".
            onOpenEditor: () => showNoteEditor(
              context: context,
              verses: group.verses,
              locale: locale,
              mainProvider: mainProvider,
            ),
            onCopy: () => ClipboardHelper.copyWithFeedback(
              context,
              // Title goes first in the copied text so pasted notes
              // are self-describing — useful when sharing into chat
              // apps or sermon prep docs.
              '${title != null ? "$title\n" : ""}[$rangeLabel] '
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<_NotesScope>(
                  segments: [
                    ButtonSegment(
                      value: _NotesScope.all,
                      label: Text(
                        uiStrings['notesScopeAll']?[locale] ?? 'All',
                      ),
                    ),
                    ButtonSegment(
                      value: _NotesScope.chapter,
                      label: Text(
                        uiStrings['notesScopeChapter']?[locale] ??
                            'This chapter',
                      ),
                    ),
                    ButtonSegment(
                      value: _NotesScope.book,
                      label: Text(
                        uiStrings['notesScopeBook']?[locale] ?? 'This book',
                      ),
                    ),
                  ],
                  selected: {_scope},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _scope = s.first),
                ),
              ),
              const SizedBox(width: 8),
              // 2026-05-24 (v1.2.91): sort-order picker. Three modes
              // (canonical / recent / oldest) live in a compact
              // PopupMenuButton next to the scope segmented control —
              // discoverable but not in-the-way for the common
              // canonical-order case. The current mode is rendered
              // as a check next to its menu entry. Choice is
              // persisted in AppSettings (also synced across devices
              // via RTDB).
              PopupMenuButton<_NotesSort>(
                tooltip: uiStrings['notesSortLabel']?[locale] ?? 'Sort',
                icon: const Icon(Icons.sort),
                onSelected: (s) {
                  // Fire-and-forget — setNotesSortMode persists +
                  // notifies, the context.watch above re-runs build.
                  // ignore: discarded_futures
                  settings.setNotesSortMode(_sortToString(s));
                },
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(
                    value: _NotesSort.canonical,
                    checked: sort == _NotesSort.canonical,
                    child: Text(
                      uiStrings['notesSortCanonical']?[locale] ??
                          'Bible order',
                    ),
                  ),
                  CheckedPopupMenuItem(
                    value: _NotesSort.recent,
                    checked: sort == _NotesSort.recent,
                    child: Text(
                      uiStrings['notesSortRecent']?[locale] ??
                          'Recently updated',
                    ),
                  ),
                  CheckedPopupMenuItem(
                    value: _NotesSort.oldest,
                    checked: sort == _NotesSort.oldest,
                    child: Text(
                      uiStrings['notesSortOldest']?[locale] ?? 'Oldest first',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  /// Filter resolved Verse entries by the active scope. Chapter/book
  /// scopes require a known [current] location; otherwise we return
  /// empty and the view shows the "open the Bible first" empty state.
  List<Verse> _filterEntriesByScope(
      List<Verse> entries, Verse? current, _NotesScope scope) {
    if (scope == _NotesScope.all) return entries;
    if (current == null) return const [];
    return entries.where((v) {
      if (v.book != current.book) return false;
      if (scope == _NotesScope.book) return true;
      return v.chapter == current.chapter; // chapter scope
    }).toList();
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

/// 2026-05-24 (v1.2.91): re-order an already-grouped list by the
/// user's chosen sort mode. Canonical returns the input unchanged
/// (it was built from the canonical-ordered entry list). Recent /
/// oldest use the MAX timestamp across the verses in each group
/// (so a multi-verse passage note's most recent edit drives its
/// position — matches the user mental model of "when did I last
/// touch this note").
///
/// Verses with no recorded timestamp (defensive — the loader
/// migrates them on app start) fall back to 0 → they bubble to the
/// "oldest" end whichever direction the sort runs.
List<_NoteGroup> _sortGroups(
  List<_NoteGroup> input,
  _NotesSort sort,
  Map<String, int> timestamps,
) {
  if (sort == _NotesSort.canonical) return input;
  int groupTs(_NoteGroup g) {
    var mx = 0;
    for (final v in g.verses) {
      final ts = timestamps[v.id] ?? 0;
      if (ts > mx) mx = ts;
    }
    return mx;
  }
  final out = List<_NoteGroup>.of(input);
  out.sort((a, b) {
    final ta = groupTs(a);
    final tb = groupTs(b);
    return sort == _NotesSort.recent
        ? tb.compareTo(ta) // newest first
        : ta.compareTo(tb); // oldest first
  });
  return out;
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

  /// 2026-05-24 (v1.2.91): user-supplied title. When non-null, the
  /// title is rendered as the bold primary header at the top of the
  /// tile, and the verse range is demoted to a smaller secondary
  /// label below it. When null (no title set), the tile falls back
  /// to the previous behaviour — verse range as the primary header.
  final String? titleOverride;

  /// 2026-05-19 (v1.2.60): when set, the "Delete" menu item clears
  /// notes from EVERY verse in the multi-verse passage note rather
  /// than just the head verse. Single-verse tiles leave this null
  /// and use the legacy single-verse `clearVerseNote(verse: this.verse)`.
  final VoidCallback? onDeleteAll;

  /// 2026-05-24 (v1.2.95): when set, tapping the tile BODY opens
  /// the note editor instead of navigating to the verse. Tapping
  /// the verse-ref text inside the tile still navigates (the
  /// "verse-ref → jump" affordance). Null = legacy behaviour
  /// (whole tile taps navigate to the verse — used by the Bookmarks
  /// tab which has no editor concept).
  final VoidCallback? onOpenEditor;

  const _AnnotationTile({
    required this.verse,
    required this.locale,
    required this.mainProvider,
    required this.extra,
    required this.onCopy,
    this.rangeLabelOverride,
    this.titleOverride,
    this.onDeleteAll,
    this.onOpenEditor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // PERF: scoped select instead of full watch<AppSettings>() — this
    // tile is instantiated per note/bookmark/highlight in a
    // ListView.separated, which can grow unboundedly for a heavy
    // user. An unrelated settings change would otherwise rebuild
    // every mounted tile. Same pattern as VerseWidget /
    // ParagraphGroupWidget in bible_reading_pane.
    context.select<AppSettings, (String, double)>(
        (s) => (s.fontFamily, s.fontSize));
    final settings = context.read<AppSettings>();
    final ref = rangeLabelOverride ??
        '${verse.book} ${verse.chapter}:${verse.verseLabel}';
    final preview = sanitizeForSearch(verse.text);
    // 2026-05-24 (v1.2.91): when the user typed a title, surface it
    // as the bold primary header and demote the verse ref to a
    // smaller secondary line — same pattern Apple Notes / Google
    // Keep / WeDevote use. When no title, fall back to the
    // verse-ref-as-header layout (no visual change for existing
    // notes after upgrade).
    final hasTitle = titleOverride != null && titleOverride!.isNotEmpty;
    // 2026-05-24 (v1.2.95): when this tile represents a NOTE
    // (`onOpenEditor` non-null), the primary tap opens the editor
    // — matching user expectation that "tapping a note opens the
    // note". Tapping the verse-ref text inside the tile still
    // navigates (separate GestureDetector below). When this tile
    // represents a BOOKMARK (`onOpenEditor` null), the legacy
    // whole-tile navigate behaviour is preserved.
    final tilePrimaryAction = onOpenEditor ?? () => _navigateToVerse(context, verse, mainProvider);
    // Verse-ref text — for notes, always jumps. For bookmarks
    // (no editor), the outer tap already jumps so the inner tap
    // would be redundant but harmless.
    final verseRefTextStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: scheme.primary,
      fontFamily: settings.fontFamily,
      fontFamilyFallback: kCjkFontFallback,
      decoration: onOpenEditor != null
          ? TextDecoration.underline
          : TextDecoration.none,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: scheme.primary.withValues(alpha: 0.6),
      fontSize: hasTitle
          ? (settings.fontSize - 3).clamp(11.0, 14.0)
          : settings.fontSize,
    );
    // Reusable tappable ref widget. HitTestBehavior.opaque consumes
    // the tap so the outer ListTile.onTap doesn't ALSO fire — keeps
    // the two intents (open editor / jump to verse) strictly
    // separated. Adds a tiny link icon hint when in note mode.
    final verseRefWidget = onOpenEditor != null
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _navigateToVerse(context, verse, mainProvider),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      ref,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: verseRefTextStyle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new_rounded,
                      size: 13, color: scheme.primary.withValues(alpha: 0.7)),
                ],
              ),
            ),
          )
        : Text(
            ref,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: verseRefTextStyle,
          );
    return ListTile(
      onTap: tilePrimaryAction,
      title: hasTitle
          ? Text(
              titleOverride!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: settings.fontSize,
              ),
            )
          // No user title: the verse-ref takes the title slot AND
          // it's tappable to jump (the verseRefWidget already wraps
          // the GestureDetector).
          : verseRefWidget,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTitle) ...[
            const SizedBox(height: 2),
            // Verse ref as a secondary line under the title. In
            // note-mode it's now a tappable + underlined chip; in
            // bookmark-mode it stays plain text (whole tile is the
            // tap target).
            verseRefWidget,
          ],
          const SizedBox(height: 4),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface,
              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
              fontSize: settings.fontSize - 2,
              height: 1.4,
            ),
          ),
          if (extra != null && extra!.isNotEmpty) ...[
            const SizedBox(height: 6),
            // 2026-05-24 (v1.2.92): show "Edited 5 分钟前" tag above
            // the note bubble. Reads the per-verse epoch-ms timestamp
            // (set by setVerseNote, see MainProvider). Uses the
            // existing relativeTime() helper that the search-history
            // rows already use. Hidden when no timestamp is recorded
            // (defensive — _loadNotes migrates everyone on load).
            Builder(builder: (_) {
              final ts = mainProvider.getVerseNoteTimestamp(verse.id);
              // 2026-05-25 (v1.3.39): treat 0 as "unknown" (legacy
              // note without a recorded timestamp). Was rendering
              // as "刚刚 / just now" because the v1.2.91 migration
              // stamped unknown timestamps with DateTime.now() — a
              // lie. Now both null AND 0 skip the label entirely;
              // the user sees no time at all rather than a fake
              // "edited just now" for a note last touched months
              // ago.
              if (ts == null || ts <= 0) {
                return const SizedBox.shrink();
              }
              final when = DateTime.fromMillisecondsSinceEpoch(ts);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4, top: 2),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded,
                        size: 11,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      relativeTime(when, locale),
                      style: TextStyle(
                        fontSize: (settings.fontSize - 5)
                            .clamp(10.0, 13.0),
                        color: scheme.onSurfaceVariant
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              );
            }),
            LeftAccentCard(
              // v1.3.x: was Container(BoxDecoration(border:
              // Border(left:...), borderRadius:...)) — non-uniform
              // border + radius throws in Border.paint.
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              background: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              accentColor: scheme.primary,
              accentWidth: 2,
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
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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

void _navigateToVerse(BuildContext context, Verse v, MainProvider mp) {
  // pendingJump handshake — see lib/utils/jump_to_reference.dart for
  // the rationale.
  jumper.prepareJumpToVerse(v, mp);
  // 2026-05-24 (v1.3.7): use the shared `navigateToReader` helper.
  // Previous Get.off(HomePage) replaced only the TOP route (Library)
  // — if the user was reading in the Bible Reader before opening
  // Library, the existing HomePage(reader) stayed at position [1]
  // in the stack and the new HomePage ended up at [2], producing
  // the duplicate the user reported as "notes对应verse的经文 …
  // bible duplicate了".
  //
  // navigateToReader walks down the stack searching for an
  // existing HomePage by route name; if found, pops every route
  // above it and pendingJump fires on the SAME reader instance.
  // If no HomePage exists in the stack (e.g. user reached Library
  // directly from Dashboard with no prior reader push), it pushes
  // a fresh one on top.
  navigateToReader(context);
}

// 2026-05-19 (v1.2.61): the v1.2.59 `_navigateToReference` helper
// is gone. Tapping a ref in a note now opens
// `showNoteReferencePreviewSheet` which has its own resolve +
// navigate path (via the "Open in Reader" button). Keeping this
// comment so future readers don't go hunting for it.


/// Generic empty-state widget used by both library tabs when the user
/// has no notes / no bookmarks yet. Centered icon + italic hint text.
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
