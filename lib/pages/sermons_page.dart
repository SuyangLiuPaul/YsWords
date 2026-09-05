import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/sermon_credit.dart';
import 'package:yswords/constants/motion.dart';
import 'package:yswords/constants/sermon_topics.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/widgets/press_scale.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/passage_filter.dart';
import 'package:yswords/models/sermon.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/pages/sermon_detail_page.dart';
import 'package:yswords/services/fetch_books.dart' show standardBookOrder;
import 'package:yswords/services/sermon_audio_service.dart';
import 'package:yswords/services/sermon_service.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/passage_localizer.dart' show localizePassage;
import 'package:yswords/utils/version_mapper.dart' show localeAwareBookName;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/widgets/scroll_to_top_on_status_bar_tap.dart';

/// Topic-grouped browser for the Pastor Eric sermon corpus.
///
/// Layout mirrors the illustrations page and Bible-evidence page so
/// the UX is consistent:
///   - sticky AppBar with search field
///   - Free-text search + structured book/chapter filter
///   - 20 collapsible topic groups (`ExpansionTile`)
///   - tap a sermon row → opens [SermonDetailPage] in the user's
///     preferred language (with cross-language fallback)
/// The clause that tells a reader this library is listenable, or null
/// when there is nothing honest to say.
///
/// 2026-09-05: the sermon list contained the string "audio" exactly
/// zero times. The player is docked on the detail page only
/// (`sermon_detail_page.dart`, `bottomNavigationBar: SermonAudioBar`),
/// so a reader browsing 289 sermons had no way to learn that any of
/// them could be played without opening one and looking.
///
/// **It is one clause in the header, not a badge on every row**, and
/// that is a deliberate reading of the same rule the AppBar byline
/// above follows. Every sermon has audio — all 289 ids in
/// `assets/sermons/index.json` have a non-empty entry in
/// `audio_index.json` — so a per-row mark would distinguish nothing.
/// A mark that is true of every row is decoration, and decoration is
/// what teaches a reader to stop seeing marks. What the list owes the
/// reader here is knowledge, and knowledge belongs in the header; the
/// affordance they act on is the play bar, and it is already on the
/// page where it can be acted on.
///
/// [total] and [playable] are both counted at runtime from the loaded
/// indexes. **Nothing here knows the number 289**, so the sentence
/// stays true if the corpus grows, shrinks, or stops being wholly
/// playable:
///
///   * not [configured] — no clause. `SermonAudioService`'s own
///     doc comment settles this: "A play button that 404s would be
///     worse than no play button." A claim about playability when
///     nothing can play is that same 404 in sentence form.
///   * [playable] is 0 (or the corpus is empty) — no clause, for the
///     same reason. This also covers the frame before the manifest
///     has loaded.
///   * [playable] >= [total] — the universal claim, "every one has a
///     recording". Worth saying because it is a capability the reader
///     can act on; "289 with recordings" is a statistic they cannot.
///   * anything in between — the count, which is what keeps the
///     universal claim from becoming a lie nobody can check.
///
/// Returned unjoined; the caller adds the ' · ' separator.
@visibleForTesting
String? sermonAudioClause({
  required bool configured,
  required int total,
  required int playable,
  required String locale,
}) {
  if (!configured) return null;
  if (total <= 0 || playable <= 0) return null;
  if (playable >= total) {
    return uiStrings['sermonAudioAll']?[locale] ?? 'every one has a recording';
  }
  final tmpl = uiStrings['sermonAudioSome']?[locale] ?? '{audioCount} with recordings';
  return tmpl.replaceAll('{audioCount}', playable.toString());
}

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
  /// The passage filter, or null for "no filter". Was two loose fields
  /// (`_filterBook` + `_filterChapter`); one value because it is now
  /// also handed to the sermon page so the same passage can be
  /// highlighted there, and passing three nullable arguments that only
  /// make sense together invites exactly the bug where one of them is
  /// forgotten.
  PassageFilter? _filter;

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
    await pushPage(
      SermonDetailPage(sermon: sermon, highlight: _filter),
      routeName: '/sermons/${sermon.id}',
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
    // The audio manifest, so the summary line can say the library is
    // listenable. `load()` is idempotent and cheap after the first
    // call (it returns early once `_index` is set), and awaiting it
    // here rather than listening to the service means the clause is
    // there on the first frame instead of appearing a beat later.
    final audio = SermonAudioService.instance;
    await audio.load();
    // Both counts DERIVED, never written down. `sermonCount` is the
    // size of the corpus this page actually loaded, not the 289 in
    // `sermon_credit.dart`; `playableCount` is the intersection of
    // that corpus with the audio manifest, so a sermon in one index
    // and not the other cannot inflate either side.
    final all = groups.values.expand((l) => l).toList();
    return _PageData(
      groups: groups,
      refs: refs,
      sermonCount: all.length,
      playableCount: all.where((s) => audio.hasAudio(s.id)).length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        // Title over a quiet byline. A reader opening this library had
        // no way to learn whose sermons these are — the name existed
        // only in strings nothing rendered. Attribution weight, on the
        // header alone: repeating it down 289 rows would be an advert,
        // not a credit.
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              uiStrings['sermons']?[locale] ?? 'Sermons',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              sermonPreacher(locale),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                // The AppBar's own foreground, not onSurfaceVariant.
                //
                // 2026-08-11, from the phone: "张牧师的名字很难看见".
                // onSurfaceVariant is the token for text on a SURFACE,
                // and this sits on the app bar, whose background is the
                // primary colour — a dark grey-blue on a dark blue bar,
                // which is close to invisible. 0.78 alpha keeps it
                // quieter than the title without hiding it.
                color: (Theme.of(context).appBarTheme.foregroundColor ??
                        scheme.onPrimary)
                    .withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
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
                    // 2026-08-02 (round 60): filled rounded "pill"
                    // search field, replacing the plain outlined box
                    // — matches the capsule language now used across
                    // Home / Search / the reading-pane toolbar
                    // instead of a generic Material outline.
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 20, color: scheme.onSurfaceVariant),
                          hintText:
                              uiStrings['sermonSearchHint']?[locale] ??
                                  'Search sermons by title or passage…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
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
                        _filter == null
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
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: const StadiumBorder(),
                        side: BorderSide(color: scheme.outlineVariant),
                        backgroundColor: _filter == null
                            ? null
                            : scheme.primaryContainer
                                .withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              if (_filter != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      avatar: Icon(Icons.bookmark, size: 16,
                          color: scheme.primary),
                      label: Text(_activeFilterLabel(locale)),
                      onDeleted: () => setState(() => _filter = null),
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
                      _summaryLine(groups, data, locale),
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
                    : ScrollToTopOnStatusBarTap(
                        controller: _scrollController,
                        child: ListView(
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
                      ),)
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
        if (_filter != null && !_passageMatches(s, data.refs)) {
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
    final f = _filter!;
    final list = refs.bySermon[s.id];
    if (list == null) return false;
    for (final ref in list) {
      if (f.matchesRefKey(ref)) return true;
    }
    return false;
  }

  String _summaryLine(
      Map<String, List<Sermon>> groups, _PageData data, String locale) {
    final n = groups.values.fold<int>(0, (a, b) => a + b.length);
    final t = groups.length;
    final tmpl = uiStrings['sermonCountTemplate']?[locale];
    final base = tmpl != null
        ? tmpl
            .replaceAll('{count}', n.toString())
            .replaceAll('{topics}', t.toString())
        : '$n sermons across $t topics';
    // The count clause is filtered and live; the audio clause is a
    // whole-library fact and stays put while the reader searches. See
    // [sermonAudioClause].
    final audio = sermonAudioClause(
      configured: SermonAudioService.isConfigured,
      total: data.sermonCount,
      playable: data.playableCount,
      locale: locale,
    );
    return audio == null ? base : '$base · $audio';
  }

  String _activeFilterLabel(String locale) {
    final f = _filter;
    if (f == null) return '';
    final book = _displayBookName(f.book, locale);
    if (f.chapter == null) return book;
    return f.verse == null
        ? '$book ${f.chapter}'
        : '$book ${f.chapter}:${f.verse}';
  }

  String _displayBookName(String englishBook, String locale) {
    return localeAwareBookName(englishBook, locale, '');
  }

  void _openFilterSheet(_PageData data, String locale) {
    // Pre-compute, for each canonical book, which chapters appear in
    // any sermon's refs — so the chapter chooser shows only chapters
    // that actually have sermons. Books with no sermons get dimmed
    // and become non-tappable.
    //
    // 2026-08-23: this now records the VERSES too, so the sheet can
    // offer a third step. Same principle as the chapter step — only
    // verses some sermon actually cites are offered, because a filter
    // that can be set to a passage nobody preached on is a filter that
    // can only disappoint. A `refs.json` key is "John 17" or
    // "John 17:3"; the whole-chapter form contributes a chapter and no
    // verse.
    final perBook = <String, Map<int, Set<int>>>{};
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
        final verses =
            perBook.putIfAbsent(book, () => <int, Set<int>>{})
                .putIfAbsent(ch, () => <int>{});
        if (colon != -1) {
          final v = int.tryParse(tail.substring(colon + 1).trim());
          if (v != null) verses.add(v);
        }
      }
    }
    showModalBottomSheet<void>(
      // useSafeArea: without it Flutter wraps the sheet in
      // MediaQuery.removePadding(removeTop: true), so any SafeArea
      // INSIDE the sheet sees padding.top == 0 and does nothing —
      // the header then draws under the clock and the notch.
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return _PassageFilterSheet(
          locale: locale,
          versesByBook: perBook,
          initial: _filter,
          onApply: (filter) {
            setState(() => _filter = filter);
            Navigator.of(sheetCtx).pop();
          },
          onClear: () {
            setState(() => _filter = null);
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

  /// Size of the whole corpus — the sum over [groups] before any
  /// filtering. Counted from the loaded index, so the summary line
  /// never has to be told how many sermons there are.
  final int sermonCount;

  /// How many of those [sermonCount] sermons resolve to at least one
  /// playable recording.
  final int playableCount;

  const _PageData({
    required this.groups,
    required this.refs,
    required this.sermonCount,
    required this.playableCount,
  });
}

class _PassageFilterSheet extends StatefulWidget {
  final String locale;

  /// book → chapter → the verses any sermon cites in that chapter.
  /// A chapter with an empty verse set is cited only as a whole.
  final Map<String, Map<int, Set<int>>> versesByBook;

  final PassageFilter? initial;
  final void Function(PassageFilter filter) onApply;
  final VoidCallback onClear;

  const _PassageFilterSheet({
    required this.locale,
    required this.versesByBook,
    required this.initial,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_PassageFilterSheet> createState() => _PassageFilterSheetState();
}

class _PassageFilterSheetState extends State<_PassageFilterSheet> {
  String? _selectedBook;
  int? _selectedChapter;
  int? _selectedVerse;

  @override
  void initState() {
    super.initState();
    _selectedBook = widget.initial?.book;
    _selectedChapter = widget.initial?.chapter;
    _selectedVerse = widget.initial?.verse;
  }

  List<int> get _chapters {
    final b = _selectedBook;
    if (b == null) return const [];
    return (widget.versesByBook[b]?.keys.toList() ?? <int>[])..sort();
  }

  List<int> get _verses {
    final b = _selectedBook, c = _selectedChapter;
    if (b == null || c == null) return const [];
    return (widget.versesByBook[b]?[c]?.toList() ?? <int>[])..sort();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
    final chapters = _chapters;
    final verses = _verses;
    // 2026-09-03: Book / Chapter / Verse each used to be its own
    // `ConstrainedBox → SingleChildScrollView` — 0.30, 0.16 and 0.16 of
    // the viewport — so this one sheet held THREE little regions that
    // scrolled by themselves while the sheet did not, and with all
    // three showing their fixed fractions plus labels and the Apply
    // button could push past the sheet's own height.
    //
    // User, 2026-08-16: "很多时候这些框框都是上下滑动很多地方都是这样是不是
    // 全部要找出来fix".
    //
    // The pattern applied here and in the other three filter sheets:
    // ONE scroll view per sheet. The header and the Apply button are
    // pinned, everything between them flows into a single scrollable,
    // and the only height cap is on the sheet as a whole — the same
    // 0.85 the song detail sheet uses. Sections then size to their
    // content instead of being clipped to a fraction nobody chose.
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
                  if (widget.initial != null)
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
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        uiStrings['sermonFilterBookLabel']?[locale] ?? 'Book',
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.65)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final book in standardBookOrder)
                            _BookChip(
                              book: book,
                              locale: locale,
                              hasSermons:
                                  widget.versesByBook.containsKey(book),
                              selected: _selectedBook == book,
                              onTap: () => setState(() {
                                if (_selectedBook == book) {
                                  _selectedBook = null;
                                } else {
                                  _selectedBook = book;
                                }
                                _selectedChapter = null;
                                _selectedVerse = null;
                              }),
                            ),
                        ],
                      ),
                      if (_selectedBook != null && chapters.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          uiStrings['sermonFilterChapterLabel']?[locale] ??
                              'Chapter',
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  scheme.onSurface.withValues(alpha: 0.65)),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ChoiceChip(
                              label: Text(
                                  uiStrings['sermonFilterAllChapters']
                                          ?[locale] ??
                                      'All'),
                              selected: _selectedChapter == null,
                              onSelected: (_) => setState(() {
                                _selectedChapter = null;
                                _selectedVerse = null;
                              }),
                            ),
                            for (final ch in chapters)
                              ChoiceChip(
                                label: Text('$ch'),
                                selected: _selectedChapter == ch,
                                onSelected: (_) => setState(() {
                                  _selectedChapter = ch;
                                  _selectedVerse = null;
                                }),
                              ),
                          ],
                        ),
                      ],
                      // 2026-08-23, from the user: "Right now, you only
                      // have the chapter. Wonder whether it is possible
                      // to have also the verses also."
                      //
                      // Only offered once a chapter is chosen, and only
                      // for chapters some sermon cites by verse. A
                      // chapter that is only ever cited whole — "he
                      // preached on John 17" — has no verses to choose
                      // between, and showing an empty row there would
                      // read as a loading failure.
                      if (_selectedChapter != null && verses.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          uiStrings['sermonFilterVerseLabel']?[locale] ??
                              'Verse',
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  scheme.onSurface.withValues(alpha: 0.65)),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ChoiceChip(
                              label: Text(
                                  uiStrings['sermonFilterAllVerses']
                                          ?[locale] ??
                                      'All'),
                              selected: _selectedVerse == null,
                              onSelected: (_) =>
                                  setState(() => _selectedVerse = null),
                            ),
                            for (final v in verses)
                              ChoiceChip(
                                label: Text('$v'),
                                selected: _selectedVerse == v,
                                onSelected: (_) =>
                                    setState(() => _selectedVerse = v),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _selectedBook == null
                    ? null
                    : () => widget.onApply(PassageFilter(
                          _selectedBook!,
                          chapter: _selectedChapter,
                          verse: _selectedVerse,
                        )),
                child: Text(uiStrings['apply']?[locale] ?? 'Apply'),
              ),
            ],
          ),
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

  // 2026-08-03 (v1.4.5): passive press-scale; the tap handler inside still
  // owns the gesture. See lib/widgets/press_scale.dart.
  @override
  Widget build(BuildContext context) => PressScale(child: _buildCard(context));

  Widget _buildCard(BuildContext context) {
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
        // 2026-08-02 (round 60): tinted icon avatar ahead of the
        // topic label, mirroring the icon-prefixed treatment given
        // to the Home dashboard and Settings section headers — one
        // consistent glyph (rather than a per-topic guess) since the
        // 20 sermon topics don't map cleanly to distinct icons.
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.campaign_outlined, size: 18, color: scheme.primary),
        ),
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
      duration: AppMotion.slow,
      curve: AppMotion.enter,
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
