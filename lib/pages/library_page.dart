import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/note_reference_parser.dart';
import 'package:yswords/utils/reference_parser.dart' show BibleReference;
import 'package:yswords/widgets/verse_popup_sheet.dart' show showVersePopup;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

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

    // Resolve all IDs first, then apply the active scope filter on
    // the Verse list — comparing book names here works regardless of
    // version because both `entries` and `current` come from the same
    // MainProvider snapshot (same loaded version's labelling).
    final allEntries = _resolveAnnotations(mainProvider, notes.keys);
    final entries = _filterEntriesByScope(allEntries, current, _scope);
    final groups = _groupContiguousNotes(entries, notes);

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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
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
                  uiStrings['notesScopeChapter']?[locale] ?? 'This chapter',
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
          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
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
