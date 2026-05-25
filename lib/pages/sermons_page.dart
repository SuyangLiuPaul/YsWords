import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/sermon_topics.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/sermon.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/pages/sermon_detail_page.dart';
import 'package:yswords/services/fetch_books.dart' show standardBookOrder;
import 'package:yswords/services/sermon_service.dart';
import 'package:yswords/utils/passage_localizer.dart' show localizePassage;
import 'package:yswords/utils/version_mapper.dart' show localeAwareBookName;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Topic-grouped browser for the Pastor Eric sermon corpus.
///
/// Layout mirrors the illustrations page and Bible-evidence page so
/// the UX is consistent:
///   - sticky AppBar with search field
///   - Free-text search + structured book/chapter filter
///   - 20 collapsible topic groups (`ExpansionTile`)
///   - tap a sermon row → opens [SermonDetailPage] in the user's
///     preferred language (with cross-language fallback)
class SermonsPage extends StatefulWidget {
  const SermonsPage({super.key});

  @override
  State<SermonsPage> createState() => _SermonsPageState();
}

class _SermonsPageState extends State<SermonsPage> {
  Future<_PageData>? _future;
  String _query = '';

  /// Currently-active passage filter. Both null = no filter; book set
  /// alone = filter to any sermon citing that book; book + chapter =
  /// filter to that specific chapter.
  String? _filterBook;
  int? _filterChapter;

  /// Last-read sermon id, loaded from SharedPreferences on init and
  /// re-fetched whenever this page becomes visible. Drives the
  /// "you were last reading this" flash highlight on the matching
  /// sermon tile so the user can find their place at a glance.
  String? _lastReadSermonId;
  Timer? _flashTimer;
  bool _flashActive = false;

  /// Sermons-list scroll controller. Scroll offset is persisted to
  /// SharedPreferences as the user scrolls (debounced) and restored
  /// in initState so re-opening the list lands them where they were.
  late final ScrollController _scrollController;
  Timer? _scrollPersistTimer;
  static const String _kListScrollKey = 'sermons_list_scroll';
  static const String _kLastReadKey = 'sermons_last_read';

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
    _scrollController = ScrollController()..addListener(_onScroll);
    _restoreState();
  }

  @override
  void dispose() {
    _scrollPersistTimer?.cancel();
    _flashTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString(_kLastReadKey);
    final savedOffset = prefs.getDouble(_kListScrollKey);
    if (!mounted) return;
    setState(() {
      _lastReadSermonId = lastId;
      _flashActive = lastId != null;
    });
    if (lastId != null) {
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _flashActive = false);
      });
    }
    // Wait for the list to render, then restore scroll position.
    if (savedOffset != null && savedOffset > 0) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(savedOffset.clamp(0.0, max));
    }
  }

  void _onScroll() {
    // Coalesce frequent scroll events into one SharedPreferences
    // write per ~600 ms so we don't thrash on every pixel.
    _scrollPersistTimer?.cancel();
    _scrollPersistTimer =
        Timer(const Duration(milliseconds: 600), _persistScroll);
  }

  Future<void> _persistScroll() async {
    if (!_scrollController.hasClients) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
        _kListScrollKey, _scrollController.position.pixels);
  }

  /// Called when the user taps a sermon tile — navigates to the
  /// detail page AND records the chosen id so the next time this
  /// page rebuilds we know which row to flash.
  Future<void> _openSermon(Sermon sermon) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastReadKey, sermon.id);
    if (!mounted) return;
    // 2026-05-25 (v1.3.44): trigger the synced `lastRead` blob to
    // re-write with the new sermonId. v1.3.43 added the sermonId
    // field to the blob but `saveCurrentState()` only fires on
    // Bible state changes — opening a sermon without re-entering
    // the reader left RTDB with a sermonId-less blob, so Device B
    // never saw the "继续讲道" card. Calling saveCurrentState
    // here makes the upload happen at the moment the user actually
    // opens the sermon.
    // ignore: unawaited_futures
    context.read<MainProvider>().saveCurrentState();
    setState(() {
      _lastReadSermonId = sermon.id;
      _flashActive = false; // Don't flash the tile they're leaving
    });
    await Get.to(
      () => SermonDetailPage(sermon: sermon),
      transition: Transition.rightToLeft,
    );
    // Returned from detail — re-arm the flash for THIS sermon's row
    // so the user immediately sees where they were.
    if (!mounted) return;
    setState(() => _flashActive = true);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _flashActive = false);
    });
    // Also restore scroll position after returning from detail.
    final savedOffset =
        (await SharedPreferences.getInstance()).getDouble(_kListScrollKey);
    if (!mounted ||
        savedOffset == null ||
        !_scrollController.hasClients) {
      return;
    }
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(savedOffset.clamp(0.0, max));
  }

  Future<_PageData> _loadAll() async {
    final svc = SermonService.instance;
    // Parallel: refs.json is independent of index.json
    final groups = await svc.loadByTopic();
    final refs = await svc.loadRefs();
    return _PageData(groups: groups, refs: refs);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(
          uiStrings['sermons']?[locale] ?? 'Sermons',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: const [HomeIconButton()],
      ),
      body: FutureBuilder<_PageData>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                // 2026-05-10 (v1.2.21): localised. Sermons-specific
                // wording falls back to the shared `loadErrorTitle`
                // if the dedicated ui-string isn't set.
                child: Text(
                  '${uiStrings['loadErrorTitle']?[locale] ?? 'Failed to load'}: ${snap.error}',
                  style: TextStyle(color: scheme.error),
                ),
              ),
            );
          }
          final data = snap.data!;
          final groups = _filtered(data, _query, locale);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          hintText:
                              uiStrings['sermonSearchHint']?[locale] ??
                                  'Search sermons by title or passage…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (v) =>
                            setState(() => _query = v.trim()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openFilterSheet(data, locale),
                      icon: Icon(
                        _filterBook == null
                            ? Icons.filter_list
                            : Icons.filter_list_alt,
                        size: 18,
                      ),
                      label: Text(
                        uiStrings['sermonFilterByPassage']?[locale] ??
                            'Filter',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        backgroundColor: _filterBook == null
                            ? null
                            : scheme.primaryContainer
                                .withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              if (_filterBook != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      avatar: Icon(Icons.bookmark, size: 16,
                          color: scheme.primary),
                      label: Text(_activeFilterLabel(locale)),
                      onDeleted: () => setState(() {
                        _filterBook = null;
                        _filterChapter = null;
                      }),
                      backgroundColor:
                          scheme.primaryContainer.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Text(
                      _summaryLine(groups, locale),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: groups.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            uiStrings['sermonNoMatches']?[locale] ??
                                'No sermons match your filters.',
                            style: TextStyle(
                                color: scheme.onSurface
                                    .withValues(alpha: 0.6)),
                          ),
                        ),
                      )
                    : ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          for (final entry in groups.entries)
                            _TopicGroup(
                                topic: entry.key,
                                sermons: entry.value,
                                lastReadId: _lastReadSermonId,
                                flashActive: _flashActive,
                                onSermonTap: _openSermon),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Apply both the free-text query and the active passage filter.
  /// Filters interact via AND (sermon must match both).
  Map<String, List<Sermon>> _filtered(
      _PageData data, String query, String locale) {
    final out = <String, List<Sermon>>{};
    final q = query.toLowerCase();
    for (final e in data.groups.entries) {
      final hits = e.value.where((s) {
        // Passage filter (refs index lookup)
        if (_filterBook != null && !_passageMatches(s, data.refs)) {
          return false;
        }
        // Free-text query
        if (q.isEmpty) return true;
        if (s.title.toLowerCase().contains(q)) return true;
        if (s.passage.toLowerCase().contains(q)) return true;
        if (s.id.toLowerCase().contains(q)) return true;
        for (final t in s.titles.values) {
          if (t.toLowerCase().contains(q)) return true;
        }
        return false;
      }).toList();
      if (hits.isNotEmpty) out[e.key] = hits;
    }
    return out;
  }

  bool _passageMatches(Sermon s, SermonRefs refs) {
    final book = _filterBook!;
    final ch = _filterChapter;
    final list = refs.bySermon[s.id];
    if (list == null) return false;
    for (final ref in list) {
      // refs are "Book chapter" or "Book chapter:verse"
      if (!ref.startsWith('$book ')) continue;
      if (ch == null) return true;
      final tail = ref.substring(book.length + 1);
      // tail is "<chapter>" or "<chapter>:<verse>"
      final colonIdx = tail.indexOf(':');
      final chPart = colonIdx == -1 ? tail : tail.substring(0, colonIdx);
      if (int.tryParse(chPart.trim()) == ch) return true;
    }
    return false;
  }

  String _summaryLine(Map<String, List<Sermon>> groups, String locale) {
    final n = groups.values.fold<int>(0, (a, b) => a + b.length);
    final t = groups.length;
    final tmpl = uiStrings['sermonCountTemplate']?[locale];
    if (tmpl != null) {
      return tmpl
          .replaceAll('{count}', n.toString())
          .replaceAll('{topics}', t.toString());
    }
    return '$n sermons across $t topics';
  }

  String _activeFilterLabel(String locale) {
    final book = _filterBook;
    if (book == null) return '';
    final localBook = _displayBookName(book, locale);
    return _filterChapter == null
        ? localBook
        : '$localBook $_filterChapter';
  }

  String _displayBookName(String englishBook, String locale) {
    return localeAwareBookName(englishBook, locale, '');
  }

  void _openFilterSheet(_PageData data, String locale) {
    // Pre-compute, for each canonical book, which chapters appear in
    // any sermon's refs — so the chapter chooser shows only chapters
    // that actually have sermons. Books with no sermons get dimmed
    // and become non-tappable.
    final perBook = <String, Set<int>>{};
    for (final refs in data.refs.bySermon.values) {
      for (final ref in refs) {
        final spaceIdx = ref.lastIndexOf(' ');
        if (spaceIdx == -1) continue;
        final book = ref.substring(0, spaceIdx);
        final tail = ref.substring(spaceIdx + 1);
        final colon = tail.indexOf(':');
        final chStr = colon == -1 ? tail : tail.substring(0, colon);
        final ch = int.tryParse(chStr);
        if (ch == null) continue;
        perBook.putIfAbsent(book, () => <int>{}).add(ch);
      }
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return _PassageFilterSheet(
          locale: locale,
          chaptersByBook: perBook,
          initialBook: _filterBook,
          initialChapter: _filterChapter,
          onApply: (book, chapter) {
            setState(() {
              _filterBook = book;
              _filterChapter = chapter;
            });
            Navigator.of(sheetCtx).pop();
          },
          onClear: () {
            setState(() {
              _filterBook = null;
              _filterChapter = null;
            });
            Navigator.of(sheetCtx).pop();
          },
        );
      },
    );
  }
}

class _PageData {
  final Map<String, List<Sermon>> groups;
  final SermonRefs refs;
  const _PageData({required this.groups, required this.refs});
}

class _PassageFilterSheet extends StatefulWidget {
  final String locale;
  final Map<String, Set<int>> chaptersByBook;
  final String? initialBook;
  final int? initialChapter;
  final void Function(String book, int? chapter) onApply;
  final VoidCallback onClear;

  const _PassageFilterSheet({
    required this.locale,
    required this.chaptersByBook,
    required this.initialBook,
    required this.initialChapter,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_PassageFilterSheet> createState() => _PassageFilterSheetState();
}

class _PassageFilterSheetState extends State<_PassageFilterSheet> {
  String? _selectedBook;
  int? _selectedChapter;

  @override
  void initState() {
    super.initState();
    _selectedBook = widget.initialBook;
    _selectedChapter = widget.initialChapter;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    final chapters = _selectedBook == null
        ? <int>[]
        : (widget.chaptersByBook[_selectedBook!]?.toList() ?? <int>[])
      ..sort();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.bookmark, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  uiStrings['sermonFilterByPassage']?[locale] ??
                      'Filter by passage',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (widget.initialBook != null)
                  TextButton(
                    onPressed: widget.onClear,
                    child: Text(
                        uiStrings['clearFilter']?[locale] ?? 'Clear'),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              uiStrings['sermonFilterBookLabel']?[locale] ?? 'Book',
              style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.35,
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final book in standardBookOrder)
                      _BookChip(
                        book: book,
                        locale: locale,
                        hasSermons:
                            widget.chaptersByBook.containsKey(book),
                        selected: _selectedBook == book,
                        onTap: () => setState(() {
                          if (_selectedBook == book) {
                            _selectedBook = null;
                            _selectedChapter = null;
                          } else {
                            _selectedBook = book;
                            _selectedChapter = null;
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ),
            if (_selectedBook != null && chapters.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                uiStrings['sermonFilterChapterLabel']?[locale] ?? 'Chapter',
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.18,
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(
                            uiStrings['sermonFilterAllChapters']?[locale] ??
                                'All'),
                        selected: _selectedChapter == null,
                        onSelected: (_) =>
                            setState(() => _selectedChapter = null),
                      ),
                      for (final ch in chapters)
                        ChoiceChip(
                          label: Text('$ch'),
                          selected: _selectedChapter == ch,
                          onSelected: (_) =>
                              setState(() => _selectedChapter = ch),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _selectedBook == null
                  ? null
                  : () => widget.onApply(_selectedBook!, _selectedChapter),
              child: Text(uiStrings['apply']?[locale] ?? 'Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookChip extends StatelessWidget {
  final String book;
  final String locale;
  final bool hasSermons;
  final bool selected;
  final VoidCallback onTap;

  const _BookChip({
    required this.book,
    required this.locale,
    required this.hasSermons,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final localized = localeAwareBookName(book, locale, '');
    return ChoiceChip(
      label: Text(localized,
          style: TextStyle(
            fontSize: 13,
            color: hasSermons ? null : Theme.of(context).disabledColor,
          )),
      selected: selected,
      onSelected: hasSermons ? (_) => onTap() : null,
    );
  }
}

class _TopicGroup extends StatelessWidget {
  final String topic;
  final List<Sermon> sermons;
  final String? lastReadId;
  final bool flashActive;
  final Future<void> Function(Sermon) onSermonTap;

  const _TopicGroup({
    required this.topic,
    required this.sermons,
    required this.lastReadId,
    required this.flashActive,
    required this.onSermonTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = context.watch<AppSettings>().locale;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(bottom: 4),
        title: Text(
          localizedSermonTopic(topic, locale),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _subtitle(sermons.length, locale),
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        // Auto-expand when one of OUR sermons matches lastReadId so
        // the flash-highlighted tile is visible without an extra tap.
        initiallyExpanded:
            lastReadId != null && sermons.any((s) => s.id == lastReadId),
        children: [
          for (final s in sermons)
            _SermonRow(
              sermon: s,
              isLastRead: s.id == lastReadId,
              flashActive: flashActive,
              onTap: () => onSermonTap(s),
            ),
        ],
      ),
    );
  }

  String _subtitle(int n, String locale) {
    final tmpl = uiStrings['sermonGroupCount']?[locale];
    if (tmpl != null) return tmpl.replaceAll('{count}', '$n');
    return '$n sermon${n == 1 ? '' : 's'}';
  }
}

/// Split a multi-citation sermon passage on the join words/punct
/// commonly used in the index ("and", "&", "; ", " 和 ", "；"). One
/// shared helper across the list page + detail page so they always
/// chunk the same way. (The detail page has its own copy named
/// _splitPassageSegments — same logic, kept private to that file
/// because it lives on a stateful widget.)
List<String> _splitSermonPassage(String passage) {
  if (passage.trim().isEmpty) return const [];
  final pat = RegExp(
    r'\s+and\s+|\s+&\s+|\s*;\s*|\s+和\s+|\s+與\s+|\s*；\s*',
    caseSensitive: false,
  );
  return [
    for (final p in passage.split(pat))
      if (p.trim().isNotEmpty) p.trim(),
  ];
}

class _SermonRow extends StatelessWidget {
  final Sermon sermon;
  final bool isLastRead;
  final bool flashActive;
  final VoidCallback onTap;

  const _SermonRow({
    required this.sermon,
    required this.isLastRead,
    required this.flashActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showFlash = isLastRead && flashActive;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: showFlash
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : Colors.transparent,
        border: showFlash
            ? Border.all(
                color: scheme.primary.withValues(alpha: 0.6),
                width: 1.5,
              )
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      title: Builder(
        builder: (ctx) {
          final locale = ctx.watch<AppSettings>().locale;
          return Text(
            sermon.localizedTitle(locale),
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          );
        },
      ),
      subtitle: Builder(
        builder: (ctx) {
          final locale = ctx.watch<AppSettings>().locale;
          return Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '#${sermon.id}',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (sermon.displayDate != '—')
                  Text(
                    sermon.displayDate,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                // Multi-passage sermons (e.g. "Mt 3:15 and Mt 4:17")
                // render as one badge per ref so each reads cleanly
                // and the user isn't confused by an "and" tag.
                for (final seg in _splitSermonPassage(sermon.passage))
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      localizePassage(seg, locale),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
        trailing: Icon(Icons.chevron_right,
            size: 20, color: scheme.onSurface.withValues(alpha: 0.4)),
        onTap: onTap,
      ),
    );
  }
}
