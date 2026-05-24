import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_books.dart' show standardBookOrder;
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/utils/version_mapper.dart' show localeAwareBookName;
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// Curated catalogue of "Bible trivia" / 冷知识 — patterns and
/// hidden structures most readers don't notice unless someone
/// points them out. Round 56 starter set; expanded over time.
///
/// Each entry has a localized title + body + an optional
/// reference (`Psalm 119`, `Ruth 2:4`) that the page will
/// resolve and link to so the user can jump straight to the
/// passage and read it themselves.
///
/// Phase 1 (this round): hand-curated entries focused on
/// well-known acrostics, hidden Tetragrammaton patterns, and
/// numerical structures.
///
/// To add a new entry: append to `bibleTriviaEntries` below with
/// the same shape. No code changes required elsewhere.
class BibleTriviaPage extends StatefulWidget {
  const BibleTriviaPage({super.key});

  @override
  State<BibleTriviaPage> createState() => _BibleTriviaPageState();
}

/// Round 56 (continued): user feedback "冷知识 also need to have
/// filter just like scroll bar make sure folter should be applied
/// to all those necessary tabs". Stateful now so we can host:
///   • a tag filter (All / Acrostic / Author / Canon / Narrative …)
///   • OT/NT toggle (derived from each entry's parsed reference)
///   • a free-text search box
///   • a free-text query
///   • an always-visible Scrollbar
class _BibleTriviaPageState extends State<BibleTriviaPage> {
  final ScrollController _scrollCtrl = ScrollController();
  // 'all' | one of the canonical English tag values defined in the
  // catalogue (ACROSTIC, AUTHOR, CANON, LANGUAGE, NARRATIVE, NT QUOTE,
  // POETRY, PROPHECY, STRUCTURE, VISION, WORDPLAY).
  String _tagFilter = 'all';
  // 'all' | 'ot' | 'nt' — uses the parsed reference's englishBook to
  // bucket. Entries with no parseable reference fall through to 'all'.
  String _testamentFilter = 'all';
  // 'all' | English book name (e.g. 'Psalms', 'Genesis'). Round 56
  // user feedback: "冷知识需要有book filter related". Filter chips
  // surface every book referenced by at least one entry, sorted in
  // canonical Bible order. Display labels are localized via
  // [localeAwareBookName] so 'Psalms' renders as '诗篇' / '詩篇' /
  // 'Psalms' to match the user's language setting.
  String _bookFilter = 'all';
  String _query = '';

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Pull every distinct English tag from the catalogue so the chip
  /// row stays in sync as new entries are added without code changes.
  List<String> get _availableTags {
    final set = <String>{};
    for (final e in bibleTriviaEntries) {
      final t = e.tag['en'];
      if (t != null && t.trim().isNotEmpty) set.add(t.trim());
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Pull every distinct English book referenced by an entry's
  /// `reference` field, in canonical Bible order. Used by the book
  /// filter chip row.
  List<String> get _availableBooks {
    final set = <String>{};
    for (final e in bibleTriviaEntries) {
      final ref = e.reference;
      if (ref == null || ref.trim().isEmpty) continue;
      final parsed = parseReference(ref);
      if (parsed == null) continue;
      set.add(parsed.englishBook);
    }
    final list = set.toList();
    list.sort((a, b) {
      final ai = _canonicalBookOrder.indexOf(a);
      final bi = _canonicalBookOrder.indexOf(b);
      if (ai == -1 && bi == -1) return a.compareTo(b);
      if (ai == -1) return 1;
      if (bi == -1) return -1;
      return ai.compareTo(bi);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    final dc = ResponsiveBreakpoints.classOf(
        MediaQuery.of(context).size.width);
    final maxW = ResponsiveBreakpoints.settingsMaxWidth(dc);

    final entries = _filterEntries(bibleTriviaEntries, locale);

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['bibleTrivia']?[locale] ?? 'Bible Trivia'),
        actions: const [HomeIconButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Scrollbar(
            controller: _scrollCtrl,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: entries.length + 2,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _IntroCard(settings: settings, scheme: scheme);
                }
                if (i == 1) {
                  return _TriviaFilterBar(
                    locale: locale,
                    settings: settings,
                    scheme: scheme,
                    availableTags: _availableTags,
                    availableBooks: _availableBooks,
                    tagFilter: _tagFilter,
                    testamentFilter: _testamentFilter,
                    bookFilter: _bookFilter,
                    query: _query,
                    matchCount: entries.length,
                    totalCount: bibleTriviaEntries.length,
                    onTagChanged: (v) =>
                        setState(() => _tagFilter = v),
                    onTestamentChanged: (v) => setState(() {
                      _testamentFilter = v;
                      // Switching testament invalidates the book
                      // filter if it sits on the other testament,
                      // so reset to 'all' to avoid an empty list.
                      if (_bookFilter != 'all') {
                        final isOt = _isOtBook(_bookFilter);
                        if (v == 'ot' && !isOt) _bookFilter = 'all';
                        if (v == 'nt' && isOt) _bookFilter = 'all';
                      }
                    }),
                    onBookChanged: (v) =>
                        setState(() => _bookFilter = v),
                    onQueryChanged: (v) => setState(() => _query = v),
                  );
                }
                return _TriviaTile(
                  entry: entries[i - 2],
                  settings: settings,
                  scheme: scheme,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<BibleTriviaEntry> _filterEntries(
      List<BibleTriviaEntry> all, String locale) {
    Iterable<BibleTriviaEntry> out = all;
    if (_tagFilter != 'all') {
      out = out.where((e) =>
          (e.tag['en'] ?? '').trim().toUpperCase() ==
          _tagFilter.toUpperCase());
    }
    if (_testamentFilter != 'all') {
      out = out.where((e) {
        final ref = e.reference;
        if (ref == null) return false;
        final parsed = parseReference(ref);
        if (parsed == null) return false;
        final isOt = _isOtBook(parsed.englishBook);
        return _testamentFilter == 'ot' ? isOt : !isOt;
      });
    }
    if (_bookFilter != 'all') {
      out = out.where((e) {
        final ref = e.reference;
        if (ref == null) return false;
        final parsed = parseReference(ref);
        if (parsed == null) return false;
        return parsed.englishBook == _bookFilter;
      });
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((e) {
        bool matches(String? s) =>
            s != null && s.toLowerCase().contains(q);
        return matches(e.title[locale]) ||
            matches(e.title['en']) ||
            matches(e.body[locale]) ||
            matches(e.body['en']) ||
            matches(e.tag[locale]) ||
            matches(e.tag['en']) ||
            matches(e.reference);
      });
    }
    // Round 56 (continued — day 3): user feedback "sort 也应该根据
    // bible order". The catalogue source order is topical (acrostics
    // first, etc.), but readers expect Bible order — Genesis first,
    // Revelation last. Sort by (book index, chapter, verseStart),
    // with reference-less entries appended at the end (they have no
    // canonical position) keeping their original relative order so
    // the rare entry without a reference still surfaces predictably.
    final indexed = out.toList().asMap().entries.toList();
    indexed.sort((a, b) {
      final ka = _canonicalSortKey(a.value);
      final kb = _canonicalSortKey(b.value);
      // Reference-less entries (sortKey null) sink to the bottom.
      if (ka == null && kb == null) return a.key.compareTo(b.key);
      if (ka == null) return 1;
      if (kb == null) return -1;
      final cmp = _compareKey(ka, kb);
      if (cmp != 0) return cmp;
      // Stable within the same (book, chapter, verse) — preserve
      // catalogue order so multiple entries on the same passage
      // appear in the order they were authored.
      return a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList();
  }

  /// (bookIndex, chapter, verseStart) tuple for canonical sort.
  /// Returns null when the entry has no parseable reference, so the
  /// caller can sink those to the end without crashing.
  static List<int>? _canonicalSortKey(BibleTriviaEntry e) {
    final ref = e.reference;
    if (ref == null || ref.trim().isEmpty) return null;
    final parsed = parseReference(ref);
    if (parsed == null) return null;
    final bookIdx = _canonicalBookOrder.indexOf(parsed.englishBook);
    if (bookIdx < 0) return null;
    return [bookIdx, parsed.chapter, parsed.verseStart ?? 0];
  }

  static int _compareKey(List<int> a, List<int> b) {
    for (int i = 0; i < a.length && i < b.length; i++) {
      final c = a[i].compareTo(b[i]);
      if (c != 0) return c;
    }
    return 0;
  }
}

/// Round 56 (continued): localized labels for the 11 canonical tag
/// values. Without this, the filter chips on the trivia page rendered
/// the raw English uppercase tags (ACROSTIC, AUTHOR, …) even when the
/// user's locale was Chinese — user feedback: "冷知识 and so many more
/// havent applied language setting". Each entry has its own per-locale
/// tag (with subject-specific phrasing like "诗篇结构"), so we can't
/// just reuse one entry's tag map for the whole filter row. This
/// const map gives a single canonical localized chip label per
/// English tag.
const Map<String, Map<String, String>> _tagDisplayLabels = {
  'ACROSTIC': {
    'en': 'Acrostic',
    'zh-Hans': '离合体',
    'zh-Hant': '離合體',
  },
  'AUTHOR': {
    'en': 'Author',
    'zh-Hans': '作者',
    'zh-Hant': '作者',
  },
  'CANON': {
    'en': 'Canon',
    'zh-Hans': '正典',
    'zh-Hant': '正典',
  },
  'LANGUAGE': {
    'en': 'Language',
    'zh-Hans': '语言',
    'zh-Hant': '語言',
  },
  'NARRATIVE': {
    'en': 'Narrative',
    'zh-Hans': '叙事',
    'zh-Hant': '敘事',
  },
  'NT QUOTE': {
    'en': 'NT Quote',
    'zh-Hans': '新约引用',
    'zh-Hant': '新約引用',
  },
  'POETRY': {
    'en': 'Poetry',
    'zh-Hans': '诗体',
    'zh-Hant': '詩體',
  },
  'PROPHECY': {
    'en': 'Prophecy',
    'zh-Hans': '预言',
    'zh-Hant': '預言',
  },
  'STRUCTURE': {
    'en': 'Structure',
    'zh-Hans': '结构',
    'zh-Hant': '結構',
  },
  'VISION': {
    'en': 'Vision',
    'zh-Hans': '异象',
    'zh-Hant': '異象',
  },
  'WORDPLAY': {
    'en': 'Wordplay',
    'zh-Hans': '文字游戏',
    'zh-Hant': '文字遊戲',
  },
};

String _localizedTagLabel(String englishTag, String locale) {
  final m = _tagDisplayLabels[englishTag.trim().toUpperCase()];
  if (m == null) return englishTag;
  return m[locale] ?? m['en'] ?? englishTag;
}

/// Full canonical Bible book order — used to sort the book filter
/// chips so Genesis comes first and Revelation last, regardless of
/// the order entries appear in the catalogue.
const List<String> _canonicalBookOrder = [
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
  'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
  '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
  'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah',
  'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
  'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah',
  'Haggai', 'Zechariah', 'Malachi',
  'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans', '1 Corinthians',
  '2 Corinthians', 'Galatians', 'Ephesians', 'Philippians', 'Colossians',
  '1 Thessalonians', '2 Thessalonians', '1 Timothy', '2 Timothy',
  'Titus', 'Philemon', 'Hebrews', 'James', '1 Peter', '2 Peter',
  '1 John', '2 John', '3 John', 'Jude', 'Revelation',
];

/// Canonical OT book set used by the testament filter. Keeping it
/// inline (not pulling from MainProvider) so the trivia page works
/// without bible data loaded.
const Set<String> _otBookSet = {
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
  'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
  '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
  'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah',
  'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
  'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah',
  'Haggai', 'Zechariah', 'Malachi',
};

bool _isOtBook(String englishBook) => _otBookSet.contains(englishBook);

/// Filter row for [BibleTriviaPage]: search field + tag chips +
/// OT/NT toggle. Sits above the trivia tiles inside the same ListView
/// so it scrolls with the content rather than pinning to the top.
class _TriviaFilterBar extends StatelessWidget {
  final String locale;
  final AppSettings settings;
  final ColorScheme scheme;
  final List<String> availableTags;
  final List<String> availableBooks;
  final String tagFilter;
  final String testamentFilter;
  final String bookFilter;
  final String query;
  final int matchCount;
  final int totalCount;
  final ValueChanged<String> onTagChanged;
  final ValueChanged<String> onTestamentChanged;
  final ValueChanged<String> onBookChanged;
  final ValueChanged<String> onQueryChanged;

  const _TriviaFilterBar({
    required this.locale,
    required this.settings,
    required this.scheme,
    required this.availableTags,
    required this.availableBooks,
    required this.tagFilter,
    required this.testamentFilter,
    required this.bookFilter,
    required this.query,
    required this.matchCount,
    required this.totalCount,
    required this.onTagChanged,
    required this.onTestamentChanged,
    required this.onBookChanged,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final searchHint =
        uiStrings['bibleTriviaSearchHint']?[locale] ??
            'Search trivia…';
    final allLabel = uiStrings['statsOriginalsAll']?[locale] ?? 'All';
    final otLabel = uiStrings['statsBooksOT']?[locale] ?? 'OT';
    final ntLabel = uiStrings['statsBooksNT']?[locale] ?? 'NT';
    final filterLabel =
        uiStrings['sermonFilterByPassage']?[locale] ?? 'Filter';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Round 56 (continued): book filter aligned with the sermons
        // page pattern. User feedback "bible trivia filter by book
        // should learn from sermon and others. all the filter should
        // be aligned and standard". Search field + Filter button
        // sits inline; tapping Filter opens a modal sheet that lists
        // every book in canonical order, dimming books that have no
        // entries (same affordance as sermons_page._BookChip).
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: searchHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: onQueryChanged,
                style: TextStyle(
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontSize: (settings.fontSize - 1).clamp(13.0, 17.0),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _openBookFilterSheet(context),
              icon: Icon(
                bookFilter == 'all'
                    ? Icons.filter_list
                    : Icons.filter_list_alt,
                size: 18,
              ),
              label: Text(
                filterLabel,
                style: const TextStyle(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                backgroundColor: bookFilter == 'all'
                    ? null
                    : scheme.primaryContainer.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        if (bookFilter != 'all') ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              avatar:
                  Icon(Icons.bookmark, size: 16, color: scheme.primary),
              label: Text(localeAwareBookName(bookFilter, locale)),
              onDeleted: () => onBookChanged('all'),
              backgroundColor:
                  scheme.primaryContainer.withValues(alpha: 0.5),
            ),
          ),
        ],
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'all', label: Text(allLabel)),
            ButtonSegment(value: 'ot', label: Text(otLabel)),
            ButtonSegment(value: 'nt', label: Text(ntLabel)),
          ],
          selected: {testamentFilter},
          onSelectionChanged: (s) => onTestamentChanged(s.first),
          multiSelectionEnabled: false,
          showSelectedIcon: false,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _TagChip(
                label: allLabel,
                selected: tagFilter == 'all',
                onTap: () => onTagChanged('all'),
                scheme: scheme,
              ),
              for (final t in availableTags)
                _TagChip(
                  label: _localizedTagLabel(t, locale),
                  selected: tagFilter == t,
                  onTap: () => onTagChanged(t),
                  scheme: scheme,
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$matchCount / $totalCount',
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  /// Open the modal sheet that mirrors the sermons-page pattern
  /// (`_PassageFilterSheet`): all 66 books in canonical order, books
  /// without trivia entries dimmed, single-select, Apply / Clear /
  /// Close. Keeps trivia and sermons feeling consistent so muscle
  /// memory carries between the two pages.
  void _openBookFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return _TriviaBookFilterSheet(
          locale: locale,
          availableBooks: availableBooks.toSet(),
          initialBook: bookFilter == 'all' ? null : bookFilter,
          onApply: (book) {
            onBookChanged(book ?? 'all');
            Navigator.of(sheetCtx).pop();
          },
          onClear: () {
            onBookChanged('all');
            Navigator.of(sheetCtx).pop();
          },
        );
      },
    );
  }
}

/// Modal book-filter sheet for the trivia page — mirrors
/// `_PassageFilterSheet` in sermons_page.dart so the experience is
/// consistent across pages. Differences from sermons:
///   • Trivia has no chapter granularity (entries reference whole
///     chapters or whole books) so the chapter row is omitted.
///   • Books without any trivia entry are dimmed (cannot be tapped),
///     same affordance as sermons.
class _TriviaBookFilterSheet extends StatefulWidget {
  final String locale;
  final Set<String> availableBooks;
  final String? initialBook;
  final void Function(String? book) onApply;
  final VoidCallback onClear;

  const _TriviaBookFilterSheet({
    required this.locale,
    required this.availableBooks,
    required this.initialBook,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_TriviaBookFilterSheet> createState() =>
      _TriviaBookFilterSheetState();
}

class _TriviaBookFilterSheetState extends State<_TriviaBookFilterSheet> {
  String? _selectedBook;

  @override
  void initState() {
    super.initState();
    _selectedBook = widget.initialBook;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.locale;
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
                maxHeight: MediaQuery.of(context).size.height * 0.50,
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final book in standardBookOrder)
                      _TriviaBookChip(
                        book: book,
                        locale: locale,
                        hasEntries: widget.availableBooks.contains(book),
                        selected: _selectedBook == book,
                        onTap: () => setState(() {
                          _selectedBook =
                              _selectedBook == book ? null : book;
                        }),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => widget.onApply(_selectedBook),
              child: Text(uiStrings['apply']?[locale] ?? 'Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TriviaBookChip extends StatelessWidget {
  final String book;
  final String locale;
  final bool hasEntries;
  final bool selected;
  final VoidCallback onTap;

  const _TriviaBookChip({
    required this.book,
    required this.locale,
    required this.hasEntries,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final localized = localeAwareBookName(book, locale, '');
    return ChoiceChip(
      label: Text(
        localized,
        style: TextStyle(
          fontSize: 13,
          color: hasEntries ? null : Theme.of(context).disabledColor,
        ),
      ),
      selected: selected,
      onSelected: hasEntries ? (_) => onTap() : null,
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.scheme,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final AppSettings settings;
  final ColorScheme scheme;
  const _IntroCard({required this.settings, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final locale = settings.locale;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.3),
          width: 0.6,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: scheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              uiStrings['bibleTriviaIntro']?[locale] ??
                  'Hidden patterns, acrostics, and numerical structures '
                      'most readers miss. Tap any entry to read the '
                      'related passage in the reader.',
              style: TextStyle(
                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                fontSize: (settings.fontSize - 2).clamp(12.0, 16.0),
                color: scheme.onSurface.withValues(alpha: 0.85),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TriviaTile extends StatefulWidget {
  final BibleTriviaEntry entry;
  final AppSettings settings;
  final ColorScheme scheme;
  const _TriviaTile({
    required this.entry,
    required this.settings,
    required this.scheme,
  });

  @override
  State<_TriviaTile> createState() => _TriviaTileState();
}

class _TriviaTileState extends State<_TriviaTile> {
  bool _expanded = false;

  Future<void> _openReference(BuildContext context) async {
    final ref = widget.entry.reference;
    if (ref == null || ref.isEmpty) return;
    final parsed = parseReference(ref);
    if (parsed == null) return;
    final mp = context.read<MainProvider>();
    final result = await jumper.resolveAndPrepareJump(
      reference: parsed,
      mp: mp,
    );
    if (!context.mounted) return;
    final ok = await jumper.showJumpResultSnackBar(context, result);
    if (!ok || !context.mounted) return;
    // 2026-05-24 (v1.3.6): explicit routeName — see main.dart for
    // the duplicate-HomePage-detection rationale.
    Get.to(() => const HomePage(),
        routeName: '/HomePage',
        transition: Transition.rightToLeft);
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.settings.locale;
    final entry = widget.entry;
    final scheme = widget.scheme;
    final settings = widget.settings;
    final title = entry.title[locale] ?? entry.title['en'] ?? '';
    final body = entry.body[locale] ?? entry.body['en'] ?? '';
    final tag = entry.tag[locale] ?? entry.tag['en'] ?? '';
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize:
                            (settings.fontSize - 5).clamp(10.0, 12.0),
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (entry.reference != null)
                    Text(
                      entry.reference!,
                      style: TextStyle(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize:
                            (settings.fontSize - 5).clamp(10.0, 12.0),
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontSize: (settings.fontSize + 1).clamp(14.0, 19.0),
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Round 56 (continued — day 3): if the entry
                      // ships a schematic diagram (Hebrew alphabet
                      // grid, chapter-counts bar chart, threefold
                      // sequence, numbered word list), render it
                      // above the body text so the visual primes the
                      // reader for the explanation.
                      if (entry.diagram != null) ...[
                        _TriviaDiagramView(
                          diagram: entry.diagram!,
                          locale: locale,
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Round 56 (continued): user feedback "format
                      // for 冷知识 is like ** ** and not be applied
                      // properly". Many entries have markdown-style
                      // **bold** in their body (e.g. **YHWH**,
                      // **22 sections**); previously they rendered as
                      // literal asterisks. Now parsed into TextSpans.
                      Text.rich(
                        TextSpan(
                          children: _parseInlineMarkdown(
                            body,
                            base: TextStyle(
                              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                              fontSize: (settings.fontSize - 1)
                                  .clamp(12.0, 17.0),
                              color: scheme.onSurface
                                  .withValues(alpha: 0.85),
                              height: 1.55,
                            ),
                            scheme: scheme,
                          ),
                        ),
                      ),
                      if (entry.reference != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.menu_book_rounded, size: 18),
                          label: Text(
                            uiStrings['bibleTriviaOpenRef']?[locale] ??
                                'Read in Bible',
                          ),
                          onPressed: () => _openReference(context),
                        ),
                      ],
                    ],
                  ),
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round 56 (continued): parse minimal inline markdown — currently
/// just `**bold**` segments — into TextSpans so trivia bodies render
/// the way they were authored. Anything else passes through verbatim.
///
/// Why so small: the trivia bodies are short, and the only marker
/// that's visibly broken in the UI today is paired `**`. We
/// deliberately do NOT try to handle full Markdown (links, italics,
/// lists) — that would warrant pulling in a `flutter_markdown` style
/// dependency.
List<TextSpan> _parseInlineMarkdown(
  String input, {
  required TextStyle base,
  required ColorScheme scheme,
}) {
  final spans = <TextSpan>[];
  final boldStyle = base.copyWith(
    fontWeight: FontWeight.w800,
    color: base.color != null
        ? base.color!.withValues(alpha: 1.0)
        : scheme.onSurface,
  );
  final pattern = RegExp(r'\*\*([^*]+)\*\*');
  int idx = 0;
  for (final m in pattern.allMatches(input)) {
    if (m.start > idx) {
      spans.add(TextSpan(
        text: input.substring(idx, m.start),
        style: base,
      ));
    }
    spans.add(TextSpan(text: m.group(1) ?? '', style: boldStyle));
    idx = m.end;
  }
  if (idx < input.length) {
    spans.add(TextSpan(text: input.substring(idx), style: base));
  }
  return spans;
}

/// Renders a [TriviaDiagram] inline above the trivia body. Switches
/// on diagram subtype and dispatches to the corresponding builder.
/// Each builder is intentionally small (under 50 lines) so the visual
/// stays readable inside the trivia tile without requiring its own
/// dedicated page.
class _TriviaDiagramView extends StatelessWidget {
  final TriviaDiagram diagram;
  final String locale;
  const _TriviaDiagramView({required this.diagram, required this.locale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = diagram;
    if (d is HebrewAlphabetDiagram) {
      return _buildHebrewAlphabet(d, scheme);
    }
    if (d is ChapterVerseCountsDiagram) {
      return _buildChapterCounts(d, scheme);
    }
    if (d is SequenceDiagram) {
      return _buildSequence(d, scheme);
    }
    if (d is NumberedWordsDiagram) {
      return _buildNumberedWords(d, scheme);
    }
    return const SizedBox.shrink();
  }

  Widget _wrapper(ColorScheme scheme, Widget child, {String? caption}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          child,
          if (caption != null && caption.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                height: 1.35,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHebrewAlphabet(
      HebrewAlphabetDiagram d, ColorScheme scheme) {
    // Hebrew alphabet — 22 consonants. Letter glyph + romanised name.
    const letters = <List<String>>[
      ['א', 'Aleph'], ['ב', 'Beth'], ['ג', 'Gimel'], ['ד', 'Daleth'],
      ['ה', 'He'], ['ו', 'Waw'], ['ז', 'Zayin'], ['ח', 'Heth'],
      ['ט', 'Teth'], ['י', 'Yod'], ['כ', 'Kaph'], ['ל', 'Lamed'],
      ['מ', 'Mem'], ['נ', 'Nun'], ['ס', 'Samek'], ['ע', 'Ayin'],
      ['פ', 'Pe'], ['צ', 'Tsade'], ['ק', 'Qoph'], ['ר', 'Resh'],
      ['ש', 'Shin'], ['ת', 'Tav'],
    ];
    final children = [
      for (final pair in letters)
        Container(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pair[0],
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                  height: 1.0,
                ),
              ),
              if (d.showLetterNames) ...[
                const SizedBox(height: 2),
                Text(
                  pair[1],
                  style: TextStyle(
                    fontSize: 8,
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
    ];
    final caption = uiStrings['triviaAlphabetCaption']?[locale] ?? '';
    final formula = d.versesPerLetter > 1
        ? '$caption · ${d.versesPerLetter} × 22 = ${d.versesPerLetter * 22}'
        : caption;
    return _wrapper(
      scheme,
      Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: children,
      ),
      caption: formula,
    );
  }

  Widget _buildChapterCounts(
      ChapterVerseCountsDiagram d, ColorScheme scheme) {
    final maxCount = d.chapters.fold<int>(0, (m, c) => c > m ? c : m);
    const barAreaHeight = 96.0;
    final bars = <Widget>[];
    for (int i = 0; i < d.chapters.length; i++) {
      final count = d.chapters[i];
      final isBroken = d.brokenChapters.contains(i + 1);
      final barH = maxCount == 0 ? 0.0 : (count / maxCount) * barAreaHeight;
      bars.add(Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isBroken
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: barH,
                decoration: BoxDecoration(
                  color: isBroken
                      ? scheme.error.withValues(alpha: 0.55)
                      : scheme.primary.withValues(alpha: 0.65),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ));
    }
    final caption = uiStrings['triviaChapterCountsCaption']?[locale] ?? '';
    return _wrapper(
      scheme,
      SizedBox(
        height: barAreaHeight + 36,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: bars,
        ),
      ),
      caption: caption,
    );
  }

  Widget _buildSequence(SequenceDiagram d, ColorScheme scheme) {
    final cells = <Widget>[];
    for (int i = 0; i < d.segments.length; i++) {
      final s = d.segments[i];
      final label = uiStrings[s.labelKey]?[locale] ?? s.labelKey;
      final caption = uiStrings[s.captionKey]?[locale] ?? s.captionKey;
      cells.add(Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ));
      if (i < d.segments.length - 1) {
        cells.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.arrow_forward_rounded,
              size: 16, color: scheme.onSurfaceVariant),
        ));
      }
    }
    return _wrapper(
      scheme,
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: cells),
    );
  }

  Widget _buildNumberedWords(
      NumberedWordsDiagram d, ColorScheme scheme) {
    final rows = <Widget>[];
    for (int i = 0; i < d.words.length; i++) {
      final w = d.words[i];
      final gloss = uiStrings[w.glossKey]?[locale] ?? w.glossKey;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Hebrew/Greek glyph — RTL-safe via Directionality at the
            // wrapper level isn't needed here because the glyph cluster
            // renders in its native script regardless of surrounding
            // direction. Bump font-size for legibility.
            Text(
              w.original,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${w.translit} · $gloss',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ));
    }
    return _wrapper(
      scheme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

/// One Bible-trivia entry. Localized in 3 languages.
class BibleTriviaEntry {
  final Map<String, String> tag;
  final Map<String, String> title;
  final Map<String, String> body;
  final String? reference;
  /// Round 56 (continued — day 3): user feedback "圣经里冷知识能不能
  /// 更加能够明白方式类似于图片或者画出来的". When set, the trivia tile
  /// renders a small schematic diagram above the body text inside the
  /// expanded section. The diagrams visualise structural patterns the
  /// body describes — Hebrew alphabet acrostics, broken-acrostic verse
  /// counts, threefold genealogies, numbered word sequences, etc.
  ///
  /// We deliberately draw with Flutter widgets rather than ship raster
  /// images: copyright-safe (no external artwork to license), works
  /// offline, scales with the user's font/theme, and stays trilingual.
  final TriviaDiagram? diagram;
  const BibleTriviaEntry({
    required this.tag,
    required this.title,
    required this.body,
    this.reference,
    this.diagram,
  });
}

// ── Trivia diagrams ──────────────────────────────────────────────
//
// Inline schematic diagrams that visualize the patterns described in
// trivia bodies. All concrete diagrams have const constructors so the
// surrounding `bibleTriviaEntries` const list keeps compiling.
//
// Adding a new diagram type:
//   1. Subclass [TriviaDiagram] with a const constructor.
//   2. Add a render branch in [_TriviaDiagramView.build].
//   3. Attach it to a `BibleTriviaEntry(diagram: ...)` call.

/// Marker base class for diagram payloads attached to a
/// [BibleTriviaEntry]. Subclasses are pure data — rendering happens
/// in [_TriviaDiagramView].
abstract class TriviaDiagram {
  const TriviaDiagram();
}

/// 22-cell Hebrew-alphabet grid. Used by Psalm 119, Proverbs 31:10-31,
/// Lamentations 1/2/4. Each cell shows the Hebrew letter and (if
/// [showLetterNames] is true) its romanised name.
///
/// [versesPerLetter] renders as a small annotation under the grid so
/// the reader sees at a glance how the section is structured —
/// "8 verses per letter × 22 letters = 176 verses" for Psalm 119, or
/// "1 verse per letter × 22 letters = 22 verses" for Lamentations 1.
class HebrewAlphabetDiagram extends TriviaDiagram {
  final int versesPerLetter;
  final bool showLetterNames;
  const HebrewAlphabetDiagram({
    this.versesPerLetter = 1,
    this.showLetterNames = false,
  });
}

/// Bar-chart of verse counts per chapter. Highlights chapters whose
/// index is in [brokenChapters] with a slashed/dimmed bar so the
/// reader sees at a glance how Lamentations 5 abandons the acrostic.
class ChapterVerseCountsDiagram extends TriviaDiagram {
  final List<int> chapters;
  /// 1-indexed chapter numbers to mark as "structure broken".
  final List<int> brokenChapters;
  const ChapterVerseCountsDiagram({
    required this.chapters,
    this.brokenChapters = const [],
  });
}

/// Three (or more) sequential boxes laid out left-to-right, each
/// labelled. Used for Matthew 1:17's three groups of 14 generations,
/// or any other "A → B → C" pattern.
class SequenceDiagram extends TriviaDiagram {
  /// Each segment carries two short label keys so we can localise.
  final List<SequenceSegment> segments;
  const SequenceDiagram({required this.segments});
}

class SequenceSegment {
  /// uiStrings key for the headline label (e.g. 'triviaMatt117GroupA').
  final String labelKey;
  /// uiStrings key for the small caption underneath (e.g. '14 generations').
  final String captionKey;
  const SequenceSegment({required this.labelKey, required this.captionKey});
}

/// Numbered word/term list — e.g. Genesis 1:1's 7 Hebrew words, the
/// 12 tribes, the 7 churches in Revelation. Renders as a vertical
/// numbered column with the original-language form on top and the
/// gloss below in the user's locale.
class NumberedWordsDiagram extends TriviaDiagram {
  /// Each item: original-language form (already locale-neutral) +
  /// gloss key (resolved per-locale). The original form is shown as-
  /// is in every locale because Hebrew/Greek script reads the same
  /// way regardless of UI language.
  final List<NumberedWord> words;
  const NumberedWordsDiagram({required this.words});
}

class NumberedWord {
  final String original;
  final String translit;
  final String glossKey;
  const NumberedWord({
    required this.original,
    required this.translit,
    required this.glossKey,
  });
}

/// Round 56: filter the catalogue to entries that reference a
/// specific English book + chapter. Used by the reader's "Trivia
/// for this chapter" sheet.
///
/// An entry is considered relevant when its parsed reference's
/// englishBook matches AND either:
///   - the parsed chapter equals [chapter], OR
///   - the parsed reference is book-only (no chapter info — treat
///     as applying to every chapter of that book)
List<BibleTriviaEntry> triviaForChapter({
  required String englishBook,
  required int chapter,
}) {
  final result = <BibleTriviaEntry>[];
  for (final e in bibleTriviaEntries) {
    final ref = e.reference;
    if (ref == null || ref.trim().isEmpty) continue;
    final parsed = parseReference(ref);
    if (parsed == null) continue;
    if (parsed.englishBook != englishBook) continue;
    // chapter == 0 means parser couldn't extract a chapter — apply
    // to all chapters of the book. Otherwise only match if the
    // reference's chapter == the requested chapter.
    if (parsed.chapter == 0 || parsed.chapter == chapter) {
      result.add(e);
    }
  }
  return result;
}

/// Round 56: show a bottom sheet of trivia entries relevant to
/// the current book/chapter. Used from the reader's floating-
/// header overflow menu. When no entries match, shows a "no
/// trivia for this chapter — view all" link to the full
/// [BibleTriviaPage].
Future<void> showBibleTriviaSheet({
  required BuildContext context,
  required String englishBook,
  required int chapter,
  required String locale,
  required AppSettings settings,
}) {
  final entries =
      triviaForChapter(englishBook: englishBook, chapter: chapter);
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: scheme.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              uiStrings['bibleTrivia']?[locale] ??
                                  'Bible Trivia',
                              style: TextStyle(
                                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                            Text(
                              '$englishBook  $chapter',
                              style: TextStyle(
                                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () =>
                            Navigator.of(sheetCtx).maybePop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: entries.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 36,
                                color: scheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                uiStrings['bibleTriviaNoneForChapter']
                                        ?[locale] ??
                                    'No trivia entries for this chapter yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                  fontSize: 13,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                icon: const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 18),
                                label: Text(
                                  uiStrings['bibleTriviaViewAll']
                                          ?[locale] ??
                                      'View all trivia',
                                ),
                                onPressed: () {
                                  Navigator.of(sheetCtx).maybePop();
                                  Get.to(
                                    () => const BibleTriviaPage(),
                                    transition: Transition.rightToLeft,
                                  );
                                },
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                              16, 12, 16, 16),
                          itemCount: entries.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            if (i == entries.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Center(
                                  child: TextButton.icon(
                                    icon: const Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 18),
                                    label: Text(
                                      uiStrings['bibleTriviaViewAll']
                                              ?[locale] ??
                                          'View all trivia',
                                    ),
                                    onPressed: () {
                                      Navigator.of(sheetCtx)
                                          .maybePop();
                                      Get.to(
                                        () => const BibleTriviaPage(),
                                        transition:
                                            Transition.rightToLeft,
                                      );
                                    },
                                  ),
                                ),
                              );
                            }
                            return _TriviaTile(
                              entry: entries[i],
                              settings: settings,
                              scheme: scheme,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Phase-1 starter set. Add more entries here over time — they
/// auto-render in the page in declaration order.
const List<BibleTriviaEntry> bibleTriviaEntries = [
  // ── Acrostics ────────────────────────────────────────────────
  BibleTriviaEntry(
    tag: {
      'en': 'ACROSTIC',
      'zh-Hans': '离合体',
      'zh-Hant': '離合體',
    },
    title: {
      'en': 'Psalm 119: A Hebrew alphabet acrostic',
      'zh-Hans': '诗篇 119：希伯来字母离合体',
      'zh-Hant': '詩篇 119：希伯來字母離合體',
    },
    body: {
      'en':
          'The longest chapter in the Bible (176 verses) is built around '
              'the 22 letters of the Hebrew alphabet. The 176 verses are '
              'organized into 22 sections of 8 verses each. Every verse in '
              'a section begins with the same Hebrew letter — section 1 '
              'all start with Aleph (א), section 2 all with Beth (ב), and '
              'so on through Tav (ת). The structure is impossible to see '
              'in translation, but the original Hebrew form is a tightly '
              'engineered praise of God\'s word — the entire chapter is '
              'about Scripture itself.',
      'zh-Hans': '圣经最长的一章（176 节）是按希伯来字母 22 个字母编排的离合体。'
          '176 节经文分成 22 段，每段 8 节，每段经文的第一个希伯来字母完全相同——'
          '第 1 段全部以 Aleph（א）开头，第 2 段全部以 Beth（ב）开头，'
          '一直到最后的 Tav（ת）。译文中完全看不出这个结构，'
          '但原文形式上是一部精密构思的颂赞，主题贯穿始终都是神的话语——整章都在讲"圣经"本身。',
      'zh-Hant': '聖經最長的一章（176 節）是按希伯來字母 22 個字母編排的離合體。'
          '176 節經文分成 22 段，每段 8 節，每段經文的第一個希伯來字母完全相同——'
          '第 1 段全部以 Aleph（א）開頭，第 2 段全部以 Beth（ב）開頭，'
          '一直到最後的 Tav（ת）。譯文中完全看不出這個結構，'
          '但原文形式上是一部精密構思的頌讚，主題貫穿始終都是神的話語——整章都在講「聖經」本身。',
    },
    reference: 'Psalm 119',
    diagram: HebrewAlphabetDiagram(versesPerLetter: 8, showLetterNames: true),
  ),
  BibleTriviaEntry(
    tag: {
      'en': 'ACROSTIC',
      'zh-Hans': '离合体',
      'zh-Hant': '離合體',
    },
    title: {
      'en': 'Lamentations: Five poems, four are alphabetic acrostics',
      'zh-Hans': '耶利米哀歌：五首哀歌，前四首都是字母离合体',
      'zh-Hant': '耶利米哀歌：五首哀歌，前四首都是字母離合體',
    },
    body: {
      'en':
          'Lamentations 1, 2, and 4 each have 22 verses — one per Hebrew '
              'letter. Chapter 3 has 66 verses (22 × 3): three verses for '
              'each letter in turn. Chapter 5, the final one, has 22 '
              'verses but BREAKS the acrostic — the structure has '
              'collapsed, mirroring the destruction the prophet is '
              'lamenting. Form following content.',
      'zh-Hans': '哀歌第 1、2、4 章各有 22 节——每节对应希伯来字母表的一个字母。'
          '第 3 章有 66 节（22 × 3），每个字母对应连续三节。'
          '最后的第 5 章虽然也有 22 节，却**打破了**离合体结构——形式本身崩塌，'
          '与先知所哀叹的"耶路撒冷的毁灭"相呼应。这是一种"形式呼应内容"的修辞。',
      'zh-Hant': '哀歌第 1、2、4 章各有 22 節——每節對應希伯來字母表的一個字母。'
          '第 3 章有 66 節（22 × 3），每個字母對應連續三節。'
          '最後的第 5 章雖然也有 22 節，卻**打破了**離合體結構——形式本身崩塌，'
          '與先知所哀嘆的「耶路撒冷的毀滅」相呼應。這是一種「形式呼應內容」的修辭。',
    },
    reference: 'Lamentations 3',
    diagram: ChapterVerseCountsDiagram(
      chapters: [22, 22, 66, 22, 22],
      brokenChapters: [5],
    ),
  ),
  BibleTriviaEntry(
    tag: {
      'en': 'ACROSTIC',
      'zh-Hans': '离合体',
      'zh-Hant': '離合體',
    },
    title: {
      'en': 'Proverbs 31: The wife of noble character is alphabetic',
      'zh-Hans': '箴言 31 章：才德的妇人是字母离合体',
      'zh-Hant': '箴言 31 章：才德的婦人是字母離合體',
    },
    body: {
      'en':
          'The famous "wife of noble character" passage (Proverbs '
              '31:10–31) has exactly 22 verses, and each begins with the '
              'next letter of the Hebrew alphabet in order — a complete '
              'A-to-Z portrait of a virtuous woman. The acrostic structure '
              'signals "this is the comprehensive description, the full '
              'spectrum of virtue."',
      'zh-Hans': '著名的"才德的妇人"段落（箴言 31:10–31）正好 22 节，'
          '每一节按希伯来字母表的顺序开头——一份"从 A 到 Z"全面描绘贤德女子的画像。'
          '这个离合体结构的修辞意义是："这是完整的、囊括方方面面的描述"。',
      'zh-Hant': '著名的「才德的婦人」段落（箴言 31:10–31）正好 22 節，'
          '每一節按希伯來字母表的順序開頭——一份「從 A 到 Z」全面描繪賢德女子的畫像。'
          '這個離合體結構的修辭意義是：「這是完整的、囊括方方面面的描述」。',
    },
    reference: 'Proverbs 31:10',
    diagram: HebrewAlphabetDiagram(versesPerLetter: 1, showLetterNames: true),
  ),

  // ── YHWH name patterns ───────────────────────────────────────
  BibleTriviaEntry(
    tag: {
      'en': 'YHWH PATTERN',
      'zh-Hans': '神名暗藏',
      'zh-Hant': '神名暗藏',
    },
    title: {
      'en': 'Esther: God\'s name hidden 4 times in acrostic',
      'zh-Hans': '以斯帖记：神的名（YHWH）以离合形式暗藏 4 次',
      'zh-Hant': '以斯帖記：神的名（YHWH）以離合形式暗藏 4 次',
    },
    body: {
      'en':
          'The book of Esther never explicitly mentions God by name — '
              'striking for a Hebrew Scripture. But ancient scribes noted '
              'that the Tetragrammaton (YHWH, יהוה) appears 4 times as an '
              'ACROSTIC, formed by the first or last letters of '
              'consecutive words in 4 carefully-positioned verses '
              '(1:20, 5:4, 5:13, 7:7). The pattern alternates forward and '
              'reversed direction, marking moments where God\'s hidden '
              'providence breaks through the narrative.',
      'zh-Hans': '以斯帖记从头到尾**没有一次明确出现"神"或"雅伟"这个词**——'
          '这在整本希伯来圣经里非常罕见。但古代抄经士指出，'
          '神的四字圣名（YHWH，יהוה）以**离合形式暗藏 4 次**：'
          '在 1:20、5:4、5:13、7:7 这四节经文的连续词语首字母或末字母处依次出现，'
          '方向交替正读 / 倒读。这四处被认为是神隐藏护理在叙事中悄悄"显现"的关键时刻。',
      'zh-Hant': '以斯帖記從頭到尾**沒有一次明確出現「神」或「雅偉」這個詞**——'
          '這在整本希伯來聖經裡非常罕見。但古代抄經士指出，'
          '神的四字聖名（YHWH，יהוה）以**離合形式暗藏 4 次**：'
          '在 1:20、5:4、5:13、7:7 這四節經文的連續詞語首字母或末字母處依次出現，'
          '方向交替正讀 / 倒讀。這四處被認為是神隱藏護理在敘事中悄悄「顯現」的關鍵時刻。',
    },
    reference: 'Esther 5:4',
  ),
  BibleTriviaEntry(
    tag: {
      'en': 'YHWH PATTERN',
      'zh-Hans': '神名暗藏',
      'zh-Hant': '神名暗藏',
    },
    title: {
      'en': 'Ruth: Boaz greets the workers with Yahweh\'s name',
      'zh-Hans': '路得记：波阿斯一句问安，连读神名两次',
      'zh-Hant': '路得記：波阿斯一句問安，連讀神名兩次',
    },
    body: {
      'en':
          'Ruth 2:4 — "Boaz arrived from Bethlehem and said to the '
              'harvesters, \'Yahweh be with you!\' \'Yahweh bless '
              'you!\' they answered." In Hebrew, the Tetragrammaton '
              '(YHWH, יהוה) appears TWICE in the same verse — Boaz\'s '
              'greeting and the workers\' response. In ancient Near East '
              'employer-worker relationships this was extraordinary: a '
              'wealthy landowner invoking God\'s name on his hired '
              'harvesters, who reply in kind. A small textual moment, a '
              'huge theological statement about godly leadership.',
      'zh-Hans': '路得记 2:4 ——"波阿斯从伯利恒来，对收割的人说：『愿雅伟与你们同在！』'
          '他们回答说：『愿雅伟赐福与你！』"原文希伯来文里，**神的圣名（YHWH，יהוה）'
          '在同一节经文里出现两次**——波阿斯打的招呼，以及工人的回应。'
          '古代近东主仆关系中这极为罕见：富有的地主直接以神的名向雇工问安，'
          '雇工也以神的名回应。一节经文中的小细节，'
          '却**蕴含整个旧约对"敬虔领导力"的神学**。',
      'zh-Hant': '路得記 2:4 ——「波阿斯從伯利恆來，對收割的人說：『願雅偉與你們同在！』'
          '他們回答說：『願雅偉賜福與你！』」原文希伯來文裡，**神的聖名（YHWH，יהוה）'
          '在同一節經文裡出現兩次**——波阿斯打的招呼，以及工人的回應。'
          '古代近東主僕關係中這極為罕見：富有的地主直接以神的名向雇工問安，'
          '雇工也以神的名回應。一節經文中的小細節，'
          '卻**蘊含整個舊約對「敬虔領導力」的神學**。',
    },
    reference: 'Ruth 2:4',
  ),

  // ── Numerical structures ─────────────────────────────────────
  BibleTriviaEntry(
    tag: {
      'en': 'STRUCTURE',
      'zh-Hans': '数字结构',
      'zh-Hant': '數字結構',
    },
    title: {
      'en': 'Genesis 1: Seven appears in Hebrew as a structural code',
      'zh-Hans': '创世记 1 章：希伯来原文中"七"是结构密码',
      'zh-Hant': '創世記 1 章：希伯來原文中「七」是結構密碼',
    },
    body: {
      'en':
          'In the Hebrew text of Genesis 1:1, there are exactly 7 words '
              'and 28 (= 7×4) Hebrew letters. The opening verse alone '
              'contains: 7 words, 28 letters, 14 letters in the divine '
              'subject phrase, 14 in the cosmic-object phrase. The number '
              '7 (completion / divine perfection in Hebrew thought) '
              'recurs throughout: "and God said" appears 7 times, "good" '
              'appears 7 times, the seventh day is set apart. The whole '
              'chapter is a literary tabernacle built on sevens.',
      'zh-Hans': '创世记 1:1 在希伯来原文中**正好 7 个单词、28（= 7×4）个字母**。'
          '仅这一节经文里就有：7 个词、28 个字母，主词短语 14 个字母，'
          '宾语短语也是 14 个字母。"七"（在希伯来思想中代表完整 / 神圣的完美）'
          '贯穿整章——"神说"出现 7 次，"好"出现 7 次，第七日被分别为圣。'
          '整章经文就是以"七"为支柱搭建起来的文学会幕。',
      'zh-Hant': '創世記 1:1 在希伯來原文中**正好 7 個單詞、28（= 7×4）個字母**。'
          '僅這一節經文裡就有：7 個詞、28 個字母，主詞短語 14 個字母，'
          '賓語短語也是 14 個字母。「七」（在希伯來思想中代表完整 / 神聖的完美）'
          '貫穿整章——「神說」出現 7 次，「好」出現 7 次，第七日被分別為聖。'
          '整章經文就是以「七」為支柱搭建起來的文學會幕。',
    },
    reference: 'Genesis 1:1',
    diagram: NumberedWordsDiagram(words: [
      NumberedWord(
          original: 'בְּרֵאשִׁית',
          translit: 'bereshit',
          glossKey: 'triviaGen11Word1'),
      NumberedWord(
          original: 'בָּרָא',
          translit: 'bara',
          glossKey: 'triviaGen11Word2'),
      NumberedWord(
          original: 'אֱלֹהִים',
          translit: 'Elohim',
          glossKey: 'triviaGen11Word3'),
      NumberedWord(
          original: 'אֵת',
          translit: 'et',
          glossKey: 'triviaGen11Word4'),
      NumberedWord(
          original: 'הַשָּׁמַיִם',
          translit: 'hashamayim',
          glossKey: 'triviaGen11Word5'),
      NumberedWord(
          original: 'וְאֵת',
          translit: 'we-et',
          glossKey: 'triviaGen11Word6'),
      NumberedWord(
          original: 'הָאָרֶץ',
          translit: 'ha-aretz',
          glossKey: 'triviaGen11Word7'),
    ]),
  ),
  BibleTriviaEntry(
    tag: {
      'en': 'STRUCTURE',
      'zh-Hans': '数字结构',
      'zh-Hant': '數字結構',
    },
    title: {
      'en': 'Matthew 1: Jesus\'s genealogy is built around 14 (= David)',
      'zh-Hans': '马太福音 1 章：耶稣家谱以 14（= 大卫之名数值）为单位编排',
      'zh-Hant': '馬太福音 1 章：耶穌家譜以 14（= 大衛之名數值）為單位編排',
    },
    body: {
      'en':
          'Matthew explicitly lays out Jesus\'s genealogy in three '
              'sections of 14 generations each: Abraham → David, David → '
              'exile, exile → Christ (Matt 1:17). Why 14? In Hebrew '
              'numerology, the letters of "David" (דוד) sum to 14 '
              '(D=4, V=6, D=4). The whole genealogy is structured around '
              'David\'s name, hammering home Matthew\'s central claim: '
              'Jesus is the long-promised Davidic king.',
      'zh-Hans': '马太福音明确把耶稣家谱分成三段，每段 14 代：'
          '亚伯拉罕→大卫，大卫→被掳，被掳→基督（马太福音 1:17）。'
          '为什么是 14？希伯来字母数值学中，"大卫"（דוד）三个字母之和是 14'
          '（D=4，V=6，D=4）。整个家谱以**大卫的名字**为编排单位，'
          '反复强调马太福音的核心主张：**耶稣就是应许已久的大卫王**。',
      'zh-Hant': '馬太福音明確把耶穌家譜分成三段，每段 14 代：'
          '亞伯拉罕→大衛，大衛→被擄，被擄→基督（馬太福音 1:17）。'
          '為什麼是 14？希伯來字母數值學中，「大衛」（דוד）三個字母之和是 14'
          '（D=4，V=6，D=4）。整個家譜以**大衛的名字**為編排單位，'
          '反覆強調馬太福音的核心主張：**耶穌就是應許已久的大衛王**。',
    },
    reference: 'Matthew 1:17',
    diagram: SequenceDiagram(segments: [
      SequenceSegment(
          labelKey: 'triviaMatt117GroupA',
          captionKey: 'triviaMatt117Generations'),
      SequenceSegment(
          labelKey: 'triviaMatt117GroupB',
          captionKey: 'triviaMatt117Generations'),
      SequenceSegment(
          labelKey: 'triviaMatt117GroupC',
          captionKey: 'triviaMatt117Generations'),
    ]),
  ),

  // ── Linguistic curiosities ───────────────────────────────────
  BibleTriviaEntry(
    tag: {
      'en': 'WORDPLAY',
      'zh-Hans': '原文双关',
      'zh-Hant': '原文雙關',
    },
    title: {
      'en': 'Jeremiah\'s almond branch: a Hebrew pun for "watching"',
      'zh-Hans': '耶利米的杏树枝：希伯来文中"杏树"与"留意"是同根字',
      'zh-Hant': '耶利米的杏樹枝：希伯來文中「杏樹」與「留意」是同根字',
    },
    body: {
      'en':
          'In Jeremiah 1:11–12, God shows the prophet "an almond branch" '
              '(Hebrew: שָׁקֵד / shaqed). God then says, "I am watching '
              '(שֹׁקֵד / shoqed) over my word to perform it." The two '
              'words sound nearly identical — a wordplay impossible to '
              'render in translation. The vision is a memorable mnemonic: '
              'every almond branch reminds the prophet that God is '
              'shaqed/shoqed — alert, attentive, ready to act on his '
              'word.',
      'zh-Hans': '耶利米书 1:11–12 中，神让先知看见"一根杏树枝"'
          '（希伯来文：שָׁקֵד，shaqed），随后说："我留意（שֹׁקֵד，shoqed）保守我的话，'
          '使得成就。"两个词**发音几乎一致**——这种双关在翻译中不可能呈现。'
          '这个异象是一份可记可念的备忘录：先知每看见一棵杏树，'
          '就提醒自己神是 shaqed/shoqed——警醒、专注，必要成全祂的话。',
      'zh-Hant': '耶利米書 1:11–12 中，神讓先知看見「一根杏樹枝」'
          '（希伯來文：שָׁקֵד，shaqed），隨後說：「我留意（שֹׁקֵד，shoqed）保守我的話，'
          '使得成就。」兩個詞**發音幾乎一致**——這種雙關在翻譯中不可能呈現。'
          '這個異象是一份可記可念的備忘錄：先知每看見一棵杏樹，'
          '就提醒自己神是 shaqed/shoqed——警醒、專注，必要成全祂的話。',
    },
    reference: 'Jeremiah 1:11',
  ),
  BibleTriviaEntry(
    tag: {
      'en': 'WORDPLAY',
      'zh-Hans': '原文双关',
      'zh-Hant': '原文雙關',
    },
    title: {
      'en': 'Adam and adamah: man and ground share one root',
      'zh-Hans': '亚当与土地：希伯来原文中"人"和"地"是同一字根',
      'zh-Hant': '亞當與土地：希伯來原文中「人」和「地」是同一字根',
    },
    body: {
      'en':
          'In Genesis 2:7, God forms "the man" (אָדָם / adam) from "the '
              'ground" (אֲדָמָה / adamah). The two words share the same '
              'root — they\'re a built-in pun. The English equivalent '
              'might be "human from humus." Genesis 3 then deepens the '
              'pun when the curse sends Adam back to adamah: "for you are '
              'dust, and to dust you shall return." Body, ground, and '
              'mortality are bound by a single Hebrew root.',
      'zh-Hans': '创世记 2:7：神用"地上的尘土"（אֲדָמָה，adamah）造"人"（אָדָם，adam）。'
          '这两个词在希伯来原文中**同根**——是一个内建的双关。'
          '中文里勉强可以说"人取自土"。到创世记 3 章，咒诅把亚当送回 adamah："'
          '你本是尘土，仍要归于尘土。"**身体、土地、必死性**在希伯来原文中由同一字根串起。',
      'zh-Hant': '創世記 2:7：神用「地上的塵土」（אֲדָמָה，adamah）造「人」（אָדָם，adam）。'
          '這兩個詞在希伯來原文中**同根**——是一個內建的雙關。'
          '中文裡勉強可以說「人取自土」。到創世記 3 章，咒詛把亞當送回 adamah：「'
          '你本是塵土，仍要歸於塵土。」**身體、土地、必死性**在希伯來原文中由同一字根串起。',
    },
    reference: 'Genesis 2:7',
  ),

  // ────────────────────────────────────────────────────────────
  // PER-BOOK ENTRIES — Round 56 expansion to all 66 books.
  // Curated facts, one per book (where the book wasn't already
  // covered by a cross-cutting entry above). Kept concise (3-5
  // sentences per language) so the catalogue stays readable.
  // ────────────────────────────────────────────────────────────

  // ── Old Testament ────────────────────────────────────────────

  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '数字结构', 'zh-Hant': '數字結構'},
    title: {
      'en': 'Exodus: 7 chapters of tabernacle, mirroring 7 days of creation',
      'zh-Hans': '出埃及记：建造会幕用 7 章经文，呼应创世 7 日',
      'zh-Hant': '出埃及記：建造會幕用 7 章經文，呼應創世 7 日',
    },
    body: {
      'en':
          'God\'s instructions for the tabernacle (Ex 25–31) span 7 speeches. The 7th speech is about the Sabbath — exactly mirroring the creation account where the 7th day is set apart. The tabernacle is presented as a "miniature creation," and humanity\'s building of it parallels God\'s building of the cosmos.',
      'zh-Hans':
          '神关于建造会幕的指示（出埃及记 25–31 章）正好分成 7 篇讲话。第 7 篇讲话讲的是安息日——'
              '与创世记中"第七日被分别为圣"的结构完全对应。会幕被呈现为"微缩的创造"，人建造会幕就如神建造宇宙。',
      'zh-Hant':
          '神關於建造會幕的指示（出埃及記 25–31 章）正好分成 7 篇講話。第 7 篇講話講的是安息日——'
              '與創世記中「第七日被分別為聖」的結構完全對應。會幕被呈現為「微縮的創造」，人建造會幕就如神建造宇宙。',
    },
    reference: 'Exodus 31:12',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '结构对称', 'zh-Hant': '結構對稱'},
    title: {
      'en': 'Leviticus: A chiasm centered on the Day of Atonement',
      'zh-Hans': '利未记：以"赎罪日"为中心的对称结构',
      'zh-Hant': '利未記：以「贖罪日」為中心的對稱結構',
    },
    body: {
      'en':
          'Leviticus is structured as a giant chiasm. Chapters 1–7 (offerings) mirror 24–27 (laws on offerings/holiness); chapters 8–10 (priests) mirror 21–22; chapters 11–15 (uncleanness) mirror 17–20. At the very center: chapter 16, the Day of Atonement. The book\'s heart is mercy.',
      'zh-Hans':
          '利未记整体是个大型同心对称结构（chiasm）。1–7 章（祭物）与 24–27 章（祭物 / 圣洁律法）对应；'
              '8–10 章（祭司）与 21–22 章对应；11–15 章（不洁）与 17–20 章对应。**核心正中：第 16 章——赎罪日**。'
              '整卷书的中心是怜悯。',
      'zh-Hant':
          '利未記整體是個大型同心對稱結構（chiasm）。1–7 章（祭物）與 24–27 章（祭物／聖潔律法）對應；'
              '8–10 章（祭司）與 21–22 章對應；11–15 章（不潔）與 17–20 章對應。**核心正中：第 16 章——贖罪日**。'
              '整卷書的中心是憐憫。',
    },
    reference: 'Leviticus 16',
  ),
  BibleTriviaEntry(
    tag: {'en': 'WORDPLAY', 'zh-Hans': '原文双关', 'zh-Hant': '原文雙關'},
    title: {
      'en': 'Numbers: Aaronic blessing — increasing letter count, 3-5-7',
      'zh-Hans': '民数记：亚伦祝福语原文 3 行，字数 3–5–7 递增',
      'zh-Hant': '民數記：亞倫祝福語原文 3 行，字數 3–5–7 遞增',
    },
    body: {
      'en':
          'The famous Aaronic blessing (Numbers 6:24–26) has 3 lines. In Hebrew the lines have 3, 5, and 7 words respectively, and 15, 20, and 25 letters — a careful escalation that swells like a wave. The Hebrew name (YHWH) appears once per line.',
      'zh-Hans':
          '著名的亚伦祝福语（民数记 6:24–26）共三行。希伯来原文中三行的字数依次是 **3、5、7**，'
              '字母数是 **15、20、25**——精心设计的递增结构，如同祝福层层涌起。神的圣名（YHWH）每行出现一次。',
      'zh-Hant':
          '著名的亞倫祝福語（民數記 6:24–26）共三行。希伯來原文中三行的字數依次是 **3、5、7**，'
              '字母數是 **15、20、25**——精心設計的遞增結構，如同祝福層層湧起。神的聖名（YHWH）每行出現一次。',
    },
    reference: 'Numbers 6:24',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '主题数据', 'zh-Hant': '主題數據'},
    title: {
      'en': 'Deuteronomy: "Hear, O Israel" 30+ times — a sermon in form',
      'zh-Hans': '申命记："以色列啊，你要听" 30+ 次 —— 形式上是一篇讲章',
      'zh-Hant': '申命記：「以色列啊，你要聽」30+ 次 —— 形式上是一篇講章',
    },
    body: {
      'en':
          'Deuteronomy is structured as Moses\'s farewell sermon at the Jordan. The imperative "hear" (שְׁמַע / shema) appears over 30 times. The book\'s name in Hebrew is Devarim ("words") — Moses\'s words. The Shema (6:4) has been the central daily prayer of Judaism for 3,000+ years.',
      'zh-Hans':
          '申命记结构上是摩西在约旦河边的"告别讲章"。命令式动词"听"（שְׁמַע，shema）出现 30 多次。'
              '希伯来书名 Devarim 意为"话语"——即摩西的话。申命记 6:4 的"以色列啊，你要听"（Shema）'
              '至今仍是犹太教 3000 多年来每日核心的祷告文。',
      'zh-Hant':
          '申命記結構上是摩西在約旦河邊的「告別講章」。命令式動詞「聽」（שְׁמַע，shema）出現 30 多次。'
              '希伯來書名 Devarim 意為「話語」——即摩西的話。申命記 6:4 的「以色列啊，你要聽」（Shema）'
              '至今仍是猶太教 3000 多年來每日核心的禱告文。',
    },
    reference: 'Deuteronomy 6:4',
  ),
  BibleTriviaEntry(
    tag: {'en': 'WORDPLAY', 'zh-Hans': '神名暗藏', 'zh-Hant': '神名暗藏'},
    title: {
      'en': 'Joshua: His Hebrew name = "Yeshua" = "Jesus"',
      'zh-Hans': '约书亚：希伯来名 "Yeshua" 与"耶稣"是同一名字',
      'zh-Hant': '約書亞：希伯來名「Yeshua」與「耶穌」是同一名字',
    },
    body: {
      'en':
          'The book\'s hero, Joshua (יְהוֹשֻׁעַ / Yehoshua), means "YHWH saves." His shortened name is Yeshua — the same Hebrew name later borne by Jesus Christ. Joshua leading Israel into the Promised Land is the OT type that the NT applies to Jesus leading believers into eternal rest (Hebrews 4:8).',
      'zh-Hans':
          '约书亚（יְהוֹשֻׁעַ，Yehoshua）希伯来名意为"雅伟是拯救"。这个名字的简写形式 **Yeshua**'
              '——正是后来耶稣基督在世时所用的希伯来名。**约书亚**带领以色列人进入应许之地，是新约中**耶稣**带领信徒'
              '进入永远安息的预表（希伯来书 4:8）。',
      'zh-Hant':
          '約書亞（יְהוֹשֻׁעַ，Yehoshua）希伯來名意為「雅偉是拯救」。這個名字的簡寫形式 **Yeshua**'
              '——正是後來耶穌基督在世時所用的希伯來名。**約書亞**帶領以色列人進入應許之地，是新約中**耶穌**帶領信徒'
              '進入永遠安息的預表（希伯來書 4:8）。',
    },
    reference: 'Joshua 1:1',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '主题数据', 'zh-Hant': '主題數據'},
    title: {
      'en': 'Judges: A repeating cycle of sin → oppression → cry → deliverance',
      'zh-Hans': '士师记：罪→压迫→呼求→拯救的螺旋循环',
      'zh-Hant': '士師記：罪→壓迫→呼求→拯救的螺旋循環',
    },
    body: {
      'en':
          'The book of Judges narrates 6 major cycles, each following the same 4-stage pattern: Israel sins, God hands them over, Israel cries out, God raises a deliverer. Each cycle ends slightly worse than the last — it\'s a downward spiral. The book\'s repeated refrain: "everyone did what was right in his own eyes."',
      'zh-Hans':
          '士师记叙述了 6 个主要循环，每个都遵循相同的 4 阶段模式：以色列犯罪 → 神交付他们 →'
              ' 以色列呼求 → 神兴起拯救者。但每个循环结束时**都比上一个更糟**——是向下的螺旋。'
              '全书反复出现的句子："那时以色列中没有王，各人任意而行。"',
      'zh-Hant':
          '士師記敘述了 6 個主要循環，每個都遵循相同的 4 階段模式：以色列犯罪 → 神交付他們 →'
              ' 以色列呼求 → 神興起拯救者。但每個循環結束時**都比上一個更糟**——是向下的螺旋。'
              '全書反覆出現的句子：「那時以色列中沒有王，各人任意而行。」',
    },
    reference: 'Judges 21:25',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '叙事呼应', 'zh-Hant': '敘事呼應'},
    title: {
      'en': '1 Samuel: Hannah\'s prayer is a template for Mary\'s Magnificat',
      'zh-Hans': '撒母耳记上：哈拿的祷告是马利亚尊主颂的原型',
      'zh-Hant': '撒母耳記上：哈拿的禱告是馬利亞尊主頌的原型',
    },
    body: {
      'en':
          'Hannah\'s prayer (1 Sam 2:1–10) celebrates God reversing the fortunes of the lowly and the proud. A thousand years later Mary, pregnant with Jesus, sings the Magnificat (Luke 1:46–55) using nearly identical language and themes — the same God still reversing the world\'s order through an unlikely mother and her promised son.',
      'zh-Hans':
          '哈拿的祷告（撒上 2:1–10）庆贺神把卑微的升高、把骄傲的降下。一千年后，怀着耶稣的马利亚唱出"尊主颂"'
              '（路加福音 1:46–55），措辞和主题几乎与哈拿的祷告**一模一样**——同一位神，借着同样不被看好的母亲和她应许之子，'
              '继续颠覆这世界的秩序。',
      'zh-Hant':
          '哈拿的禱告（撒上 2:1–10）慶賀神把卑微的升高、把驕傲的降下。一千年後，懷著耶穌的馬利亞唱出「尊主頌」'
              '（路加福音 1:46–55），措辭和主題幾乎與哈拿的禱告**一模一樣**——同一位神，藉著同樣不被看好的母親和她應許之子，'
              '繼續顛覆這世界的秩序。',
    },
    reference: '1 Samuel 2:1',
  ),
  BibleTriviaEntry(
    tag: {'en': 'POETRY', 'zh-Hans': '诗歌挽歌', 'zh-Hant': '詩歌輓歌'},
    title: {
      'en': '2 Samuel: David\'s lament has refrain "How the mighty have fallen"',
      'zh-Hans': '撒母耳记下：大卫挽歌"英雄何竟仆倒"作叠句出现 3 次',
      'zh-Hant': '撒母耳記下：大衛輓歌「英雄何竟仆倒」作疊句出現 3 次',
    },
    body: {
      'en':
          'David\'s lament for Saul and Jonathan (2 Sam 1:19–27) is one of the oldest poems in the Bible. The refrain "How the mighty have fallen!" repeats 3 times — opening, middle, closing — bracketing the whole elegy. David refuses to mock the dead king who tried to kill him; the poem is a model of grace toward enemies.',
      'zh-Hans':
          '大卫为扫罗和约拿单作的挽歌（撒下 1:19–27）是圣经中最古老的诗篇之一。叠句"英雄何竟仆倒"'
              '出现 **3 次**——开头、中间、结尾，把整首挽歌框起来。大卫拒绝嘲讽这位曾要杀他的死王，'
              '整首诗示范了"如何对敌人有恩典"。',
      'zh-Hant':
          '大衛為掃羅和約拿單作的輓歌（撒下 1:19–27）是聖經中最古老的詩篇之一。疊句「英雄何竟仆倒」'
              '出現 **3 次**——開頭、中間、結尾，把整首輓歌框起來。大衛拒絕嘲諷這位曾要殺他的死王，'
              '整首詩示範了「如何對敵人有恩典」。',
    },
    reference: '2 Samuel 1:19',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '建筑神学', 'zh-Hant': '建築神學'},
    title: {
      'en': '1 Kings: Solomon\'s temple has 3-zone structure (court / holy / most holy)',
      'zh-Hans': '列王纪上：所罗门圣殿三重区域，与希伯来人观对应',
      'zh-Hant': '列王紀上：所羅門聖殿三重區域，與希伯來人觀對應',
    },
    body: {
      'en':
          'Solomon\'s temple (1 Kings 6) has three concentric zones: outer court (open to all), Holy Place (priests only), Most Holy Place (high priest, once a year). Many ancient writers saw this as mirroring humanity: body, soul, spirit. The structure also mirrored creation\'s 3 zones: sea/sky/land, with the Most Holy Place as Eden restored.',
      'zh-Hans':
          '所罗门圣殿（王上 6 章）由三重同心区组成：外院（人人可进）、圣所（只有祭司可入）、'
              '至圣所（大祭司每年一次）。许多古代作者认为这呼应人观——**身体、魂、灵**。也呼应创造的三层——'
              '海、天、陆，至圣所即"恢复的伊甸园"。',
      'zh-Hant':
          '所羅門聖殿（王上 6 章）由三重同心區組成：外院（人人可進）、聖所（只有祭司可入）、'
              '至聖所（大祭司每年一次）。許多古代作者認為這呼應人觀——**身體、魂、靈**。也呼應創造的三層——'
              '海、天、陸，至聖所即「恢復的伊甸園」。',
    },
    reference: '1 Kings 6',
  ),
  BibleTriviaEntry(
    tag: {'en': 'NARRATIVE', 'zh-Hans': '叙事呼应', 'zh-Hant': '敘事呼應'},
    title: {
      'en': '2 Kings: Elisha\'s "double portion" of Elijah\'s spirit',
      'zh-Hans': '列王纪下：以利沙获得以利亚"双倍"的灵 —— 神迹也几乎双倍',
      'zh-Hant': '列王紀下：以利沙獲得以利亞「雙倍」的靈 —— 神蹟也幾乎雙倍',
    },
    body: {
      'en':
          'Elisha asked for a "double portion" of Elijah\'s spirit (2 Ki 2:9). The narrative bears it out — Elisha performs roughly twice as many recorded miracles as Elijah (≈ 16 vs 8). The "double portion" was inheritance language for the firstborn son\'s share — Elisha was claiming spiritual son-status from his master.',
      'zh-Hans':
          '以利沙向以利亚求"双倍的灵"（王下 2:9）。叙事中果然印证——以利沙记载的神迹数量约为以利亚的两倍'
              '（约 16 vs 8）。"双倍"在希伯来文化中是**长子继承的份额**——以利沙是在以"属灵长子"的身份'
              '向他的师父提出继承请求。',
      'zh-Hant':
          '以利沙向以利亞求「雙倍的靈」（王下 2:9）。敘事中果然印證——以利沙記載的神蹟數量約為以利亞的兩倍'
              '（約 16 vs 8）。「雙倍」在希伯來文化中是**長子繼承的份額**——以利沙是在以「屬靈長子」的身份'
              '向他的師父提出繼承請求。',
    },
    reference: '2 Kings 2:9',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '族谱奇观', 'zh-Hant': '族譜奇觀'},
    title: {
      'en': '1 Chronicles: 9 chapters of genealogies — longest in the Bible',
      'zh-Hans': '历代志上：开篇 9 章族谱 —— 圣经最长',
      'zh-Hant': '歷代志上：開篇 9 章族譜 —— 聖經最長',
    },
    body: {
      'en':
          '1 Chronicles starts with 9 unbroken chapters of names — Adam through David — covering ~3,500 years. It\'s the longest sustained genealogy in Scripture. To the post-exilic readers it answered a desperate question: after Babylon, are we still THE people? The names say yes — God\'s line is unbroken.',
      'zh-Hans':
          '历代志上开篇是连续 9 章名字——从亚当到大卫，跨越约 3500 年。这是圣经中**最长**的连续族谱。'
              '对被掳归回后的读者，它回答一个迫切的问题："巴比伦之后，我们还是那群被拣选的子民吗？"'
              '——名字宣告：是的，神的线没有断。',
      'zh-Hant':
          '歷代志上開篇是連續 9 章名字——從亞當到大衛，跨越約 3500 年。這是聖經中**最長**的連續族譜。'
              '對被擄歸回後的讀者，它回答一個迫切的問題：「巴比倫之後，我們還是那群被揀選的子民嗎？」'
              '——名字宣告：是的，神的線沒有斷。',
    },
    reference: '1 Chronicles 1:1',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '书卷连接', 'zh-Hant': '書卷連接'},
    title: {
      'en': '2 Chronicles ends with the same words Ezra begins with',
      'zh-Hans': '历代志下结尾与以斯拉记开篇文字几乎一致',
      'zh-Hant': '歷代志下結尾與以斯拉記開篇文字幾乎一致',
    },
    body: {
      'en':
          '2 Chronicles ends with Cyrus\'s decree allowing the exiles to return and rebuild (36:22–23). Ezra opens with the same decree (1:1–3). The two books were once a single scroll — Chronicles ends a half-sentence early and Ezra picks up exactly where it left off. A literary handshake across the seam.',
      'zh-Hans':
          '历代志下以"古列谕令"释放被掳之民归回重建（36:22–23）作结。以斯拉记**以同一谕令**开篇（1:1–3）。'
              '两卷书曾是同一书卷——历代志结尾恰好停在半句话上，以斯拉记从断点续接。一种跨书卷的文学握手。',
      'zh-Hant':
          '歷代志下以「古列諭令」釋放被擄之民歸回重建（36:22–23）作結。以斯拉記**以同一諭令**開篇（1:1–3）。'
              '兩卷書曾是同一書卷——歷代志結尾恰好停在半句話上，以斯拉記從斷點續接。一種跨書卷的文學握手。',
    },
    reference: '2 Chronicles 36:22',
  ),
  BibleTriviaEntry(
    tag: {'en': 'LANGUAGE', 'zh-Hans': '语言切换', 'zh-Hant': '語言切換'},
    title: {
      'en': 'Ezra: Mid-book switches from Hebrew to Aramaic',
      'zh-Hans': '以斯拉记：书中段从希伯来文切换到亚兰文',
      'zh-Hant': '以斯拉記：書中段從希伯來文切換到亞蘭文',
    },
    body: {
      'en':
          'Ezra is one of only two books in the Hebrew Bible (with Daniel) that switches language mid-narrative. From 4:8 to 6:18 and 7:12–26 the text is in Aramaic — the official correspondence language of the Persian Empire. The shift signals "this is real Persian-administration documentation."',
      'zh-Hans':
          '以斯拉记是希伯来圣经中**只有两卷**（连同但以理书）中途切换语言的书。'
              '4:8–6:18 和 7:12–26 是用**亚兰文**写的——波斯帝国的官方公文语言。'
              '语言切换是在告诉读者：**这就是当时波斯朝廷的真实档案**。',
      'zh-Hant':
          '以斯拉記是希伯來聖經中**只有兩卷**（連同但以理書）中途切換語言的書。'
              '4:8–6:18 和 7:12–26 是用**亞蘭文**寫的——波斯帝國的官方公文語言。'
              '語言切換是在告訴讀者：**這就是當時波斯朝廷的真實檔案**。',
    },
    reference: 'Ezra 4:8',
  ),
  BibleTriviaEntry(
    tag: {'en': 'NARRATIVE', 'zh-Hans': '结尾意味深长', 'zh-Hant': '結尾意味深長'},
    title: {
      'en': 'Nehemiah: Last words are "Remember me, O my God, for good"',
      'zh-Hans': '尼希米记：全书末句"我的神啊，求你记念我，施恩与我"',
      'zh-Hant': '尼希米記：全書末句「我的神啊，求你記念我，施恩與我」',
    },
    body: {
      'en':
          'Nehemiah ends abruptly: "Remember me, O my God, for good." It\'s a personal prayer with no triumphant conclusion. After all the wall-rebuilding and reform, the leader\'s final word is fragile self-commendation to God. The OT closes with a whispered prayer for grace.',
      'zh-Hans':
          '尼希米记的末句很意味深长："我的神啊，求你记念我，施恩与我。"全书没有凯旋式的结尾，'
              '只有一句私人祷告。在所有的城墙修建和改革之后，领袖的最后一句话是**脆弱地把自己交托给神**。'
              '旧约（在希伯来正典顺序中）以一声轻轻的求恩祷告作结。',
      'zh-Hant':
          '尼希米記的末句很意味深長：「我的神啊，求你記念我，施恩與我。」全書沒有凱旋式的結尾，'
              '只有一句私人禱告。在所有的城牆修建和改革之後，領袖的最後一句話是**脆弱地把自己交託給神**。'
              '舊約（在希伯來正典順序中）以一聲輕輕的求恩禱告作結。',
    },
    reference: 'Nehemiah 13:31',
  ),
  BibleTriviaEntry(
    tag: {'en': 'AUTHOR', 'zh-Hans': '成书时代', 'zh-Hant': '成書時代'},
    title: {
      'en': 'Job: Possibly the oldest book in the Bible',
      'zh-Hans': '约伯记：可能是圣经中最古老的书',
      'zh-Hant': '約伯記：可能是聖經中最古老的書',
    },
    body: {
      'en':
          'Job has no mention of Mosaic law, the Tabernacle, or Israel as a nation. Job offers sacrifices as the family head (1:5) the way Abraham did. Wealth is measured in livestock and Job lives 140 more years after his trials — patriarchal-era markers. Many scholars place the events ~2000 BC, making Job possibly the OLDEST recorded narrative in the Bible.',
      'zh-Hans':
          '约伯记完全不提摩西律法、会幕或以色列作为一个民族。约伯像亚伯拉罕那样以家长身份献祭（1:5）。'
              '财富以牲畜衡量，受难后约伯又活了 140 年——这些都是族长时代的标志。'
              '许多学者把约伯的故事时代定在公元前 2000 年左右——这样**约伯记可能是圣经中最古老的叙事**。',
      'zh-Hant':
          '約伯記完全不提摩西律法、會幕或以色列作為一個民族。約伯像亞伯拉罕那樣以家長身份獻祭（1:5）。'
              '財富以牲畜衡量，受難後約伯又活了 140 年——這些都是族長時代的標誌。'
              '許多學者把約伯的故事時代定在公元前 2000 年左右——這樣**約伯記可能是聖經中最古老的敘事**。',
    },
    reference: 'Job 1:5',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '五卷结构', 'zh-Hant': '五卷結構'},
    title: {
      'en': 'Psalms: 5 books mirror the 5 books of Moses',
      'zh-Hans': '诗篇：分为 5 卷，对应摩西五经',
      'zh-Hant': '詩篇：分為 5 卷，對應摩西五經',
    },
    body: {
      'en':
          'Psalms is divided into 5 books — Book I (1–41), II (42–72), III (73–89), IV (90–106), V (107–150). The ancient rabbis saw this as deliberately mirroring the 5 books of Moses. Each book ends with a doxology, and the whole collection ends with Psalms 146–150 — a 5-psalm crescendo of "Hallelujah."',
      'zh-Hans':
          '诗篇分为 **5 卷**——第一卷（1–41）、第二卷（42–72）、第三卷（73–89）、第四卷（90–106）、第五卷（107–150）。'
              '古代拉比把这视为有意呼应**摩西五经**。每卷以颂赞结尾，整本以诗篇 146–150 五首"哈利路亚"高潮收束。',
      'zh-Hant':
          '詩篇分為 **5 卷**——第一卷（1–41）、第二卷（42–72）、第三卷（73–89）、第四卷（90–106）、第五卷（107–150）。'
              '古代拉比把這視為有意呼應**摩西五經**。每卷以頌讚結尾，整本以詩篇 146–150 五首「哈利路亞」高潮收束。',
    },
    reference: 'Psalm 1',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '主题数据', 'zh-Hant': '主題數據'},
    title: {
      'en': 'Ecclesiastes: "Vanity" appears 38 times',
      'zh-Hans': '传道书："虚空"原文出现 38 次',
      'zh-Hant': '傳道書：「虛空」原文出現 38 次',
    },
    body: {
      'en':
          'The Hebrew word hevel (הֶבֶל / "vapor, breath, vanity") appears 38 times across the 12 chapters of Ecclesiastes — far more than any other OT book. The same word is the name "Abel" (Cain\'s brother). The Preacher\'s thesis: life "under the sun" is fleeting like a breath. Yet the book ends with "fear God."',
      'zh-Hans':
          '希伯来文 hevel（הֶבֶל，"气、雾气、虚空"）在传道书 12 章中出现 **38 次**——远超旧约任何其他书。'
              '同样这个词是"亚伯"（该隐之弟）的名字。**传道者**的论点：日光之下的生命如同一口气般短暂。'
              '但全书结尾是"敬畏神"。',
      'zh-Hant':
          '希伯來文 hevel（הֶבֶל，「氣、霧氣、虛空」）在傳道書 12 章中出現 **38 次**——遠超舊約任何其他書。'
              '同樣這個詞是「亞伯」（該隱之弟）的名字。**傳道者**的論點：日光之下的生命如同一口氣般短暫。'
              '但全書結尾是「敬畏神」。',
    },
    reference: 'Ecclesiastes 1:2',
  ),
  BibleTriviaEntry(
    tag: {'en': 'NARRATIVE', 'zh-Hans': '神名缺席', 'zh-Hant': '神名缺席'},
    title: {
      'en': 'Song of Solomon: God is never mentioned by name',
      'zh-Hans': '雅歌：全书没有提及"神"的名字',
      'zh-Hant': '雅歌：全書沒有提及「神」的名字',
    },
    body: {
      'en':
          'The Song never names God explicitly (the closest mention is a "flame of YHWH" wordplay in 8:6, debated). Yet Jewish and Christian tradition has read the Song as the most intimate picture of divine love — God\'s pursuit of Israel, Christ\'s love for the church. God\'s presence is felt without being named.',
      'zh-Hans':
          '雅歌全书从未明确提到神的名字（最接近的是 8:6 中可能的"雅伟的烈焰"双关，至今有争议）。'
              '但犹太和基督教传统都把雅歌读作神圣之爱**最亲密的画像**——神追求以色列，'
              '基督爱教会。**神的同在被感受到，但名字未被说出**。',
      'zh-Hant':
          '雅歌全書從未明確提到神的名字（最接近的是 8:6 中可能的「雅偉的烈焰」雙關，至今有爭議）。'
              '但猶太和基督教傳統都把雅歌讀作神聖之愛**最親密的畫像**——神追求以色列，'
              '基督愛教會。**神的同在被感受到，但名字未被說出**。',
    },
    reference: 'Song of Solomon 8:6',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '镜像结构', 'zh-Hant': '鏡像結構'},
    title: {
      'en': 'Isaiah: 66 chapters mirror the 66 books of the Bible',
      'zh-Hans': '以赛亚书：66 章呼应圣经 66 卷',
      'zh-Hant': '以賽亞書：66 章呼應聖經 66 卷',
    },
    body: {
      'en':
          'A popular observation: Isaiah has 66 chapters and is sometimes called "the Bible in miniature." Chapters 1–39 (judgment, like the OT\'s 39 books) followed by 40–66 (comfort and salvation, like the NT\'s 27 books). Chapter 40 begins, "Comfort, comfort my people." This is widely cited though scholars debate the formal weight.',
      'zh-Hans':
          '一个流传很广的观察：以赛亚书有 **66 章**，被称为"小圣经"。第 1–39 章（审判，对应旧约 39 卷书）；'
              '第 40–66 章（安慰救赎，对应新约 27 卷书）。第 40 章以"安慰，安慰我的百姓"开篇——结构上完美呼应。'
              '虽然学者对这种"刻意安排"是否真的成立有争议，但作为通俗类比非常出名。',
      'zh-Hant':
          '一個流傳很廣的觀察：以賽亞書有 **66 章**，被稱為「小聖經」。第 1–39 章（審判，對應舊約 39 卷書）；'
              '第 40–66 章（安慰救贖，對應新約 27 卷書）。第 40 章以「安慰，安慰我的百姓」開篇——結構上完美呼應。'
              '雖然學者對這種「刻意安排」是否真的成立有爭議，但作為通俗類比非常出名。',
    },
    reference: 'Isaiah 40:1',
  ),
  BibleTriviaEntry(
    tag: {'en': 'VISION', 'zh-Hans': '异象奇观', 'zh-Hant': '異象奇觀'},
    title: {
      'en': 'Ezekiel: Begins with the most elaborate vision in the OT',
      'zh-Hans': '以西结书：旧约最复杂的异象开篇',
      'zh-Hant': '以西結書：舊約最複雜的異象開篇',
    },
    body: {
      'en':
          'Ezekiel 1\'s "wheels within wheels" vision — four living creatures, rotating wheels full of eyes, and a throne of sapphire — is the most elaborate visionary description in the OT. Ancient rabbis considered it so dangerous they restricted its study to mature scholars only. Echoed in Revelation 4 with the same four creatures around God\'s throne.',
      'zh-Hans':
          '以西结书第 1 章的"轮中套轮"异象——四个活物、满了眼睛的旋转轮子、蓝宝石宝座——'
              '是旧约最复杂的异象描述。古代拉比认为它危险到只允许成熟的学者研习。'
              '启示录第 4 章呼应了同样的四活物围绕神的宝座。',
      'zh-Hant':
          '以西結書第 1 章的「輪中套輪」異象——四個活物、滿了眼睛的旋轉輪子、藍寶石寶座——'
              '是舊約最複雜的異象描述。古代拉比認為它危險到只允許成熟的學者研習。'
              '啟示錄第 4 章呼應了同樣的四活物圍繞神的寶座。',
    },
    reference: 'Ezekiel 1:4',
  ),
  BibleTriviaEntry(
    tag: {'en': 'LANGUAGE', 'zh-Hans': '语言切换', 'zh-Hant': '語言切換'},
    title: {
      'en': 'Daniel: Switches between Hebrew and Aramaic at chapter borders',
      'zh-Hans': '但以理书：在章节边界处切换希伯来文/亚兰文',
      'zh-Hant': '但以理書：在章節邊界處切換希伯來文／亞蘭文',
    },
    body: {
      'en':
          'Daniel 1 + 2:1–4a is in Hebrew, then 2:4b–7:28 switches to Aramaic, then 8:1–12:13 returns to Hebrew. The Aramaic section deals with universal/Gentile-empire themes (the four-kingdom statue, the four beasts), while the Hebrew sections focus on Israel. The bilingual structure itself preaches.',
      'zh-Hans':
          '但以理书 1 章 + 2:1–4a 是希伯来文，2:4b–7:28 切换为**亚兰文**，然后 8:1–12:13 又回到希伯来文。'
              '亚兰文部分讲普世性 / 外邦帝国主题（四国之像、四兽异象），希伯来文部分聚焦以色列。'
              '**书卷的双语结构本身就在讲道**。',
      'zh-Hant':
          '但以理書 1 章 + 2:1–4a 是希伯來文，2:4b–7:28 切換為**亞蘭文**，然後 8:1–12:13 又回到希伯來文。'
              '亞蘭文部分講普世性／外邦帝國主題（四國之像、四獸異象），希伯來文部分聚焦以色列。'
              '**書卷的雙語結構本身就在講道**。',
    },
    reference: 'Daniel 2:4',
  ),
  BibleTriviaEntry(
    tag: {'en': 'NARRATIVE', 'zh-Hans': '生命比喻', 'zh-Hant': '生命比喻'},
    title: {
      'en': 'Hosea: His marriage IS the prophecy',
      'zh-Hans': '何西阿书：他的婚姻就是预言',
      'zh-Hant': '何西阿書：他的婚姻就是預言',
    },
    body: {
      'en':
          'God commanded Hosea to marry an unfaithful woman, Gomer, and stay faithful to her. The marriage itself becomes the message: just as Hosea pursues his wandering wife, God pursues unfaithful Israel. Their three children\'s names are also prophecies: Jezreel ("scattered"), Lo-Ruhamah ("not loved"), Lo-Ammi ("not my people").',
      'zh-Hans':
          '神吩咐何西阿娶不忠的妇人歌篾，并对她保持忠诚。**这桩婚姻本身就是先知信息**——'
              '何西阿如何追求出走的妻子，神就如何追求不忠的以色列。三个孩子的名字也都是预言：'
              '耶斯列（"分散"）、罗·路哈玛（"不蒙怜悯"）、罗·阿米（"非我民"）。',
      'zh-Hant':
          '神吩咐何西阿娶不忠的婦人歌篾，並對她保持忠誠。**這樁婚姻本身就是先知信息**——'
              '何西阿如何追求出走的妻子，神就如何追求不忠的以色列。三個孩子的名字也都是預言：'
              '耶斯列（「分散」）、羅・路哈瑪（「不蒙憐憫」）、羅・阿米（「非我民」）。',
    },
    reference: 'Hosea 1:2',
  ),
  BibleTriviaEntry(
    tag: {'en': 'PROPHECY', 'zh-Hans': '主题数据', 'zh-Hant': '主題數據'},
    title: {
      'en': 'Joel: Quoted by Peter at Pentecost',
      'zh-Hans': '约珥书：彼得在五旬节直接引用',
      'zh-Hant': '約珥書：彼得在五旬節直接引用',
    },
    body: {
      'en':
          'When the Spirit fell at Pentecost (Acts 2), Peter\'s first sermon explained what was happening by quoting Joel 2:28–32 — "I will pour out my Spirit on all flesh." Joel\'s small 3-chapter book hands the New Testament its template for Spirit-empowered ministry. The "day of Yahweh" he warns about is also re-applied throughout the NT.',
      'zh-Hans':
          '五旬节圣灵降下时（使徒行传 2 章），彼得的第一篇讲道直接引用约珥书 2:28–32 来解释——'
              '"我要将我的灵浇灌凡有血气的"。约珥书短短 3 章为新约提供了**圣灵充满事奉的范本**。'
              '他所警告的"雅伟的日子"也被新约反复引用。',
      'zh-Hant':
          '五旬節聖靈降下時（使徒行傳 2 章），彼得的第一篇講道直接引用約珥書 2:28–32 來解釋——'
              '「我要將我的靈澆灌凡有血氣的」。約珥書短短 3 章為新約提供了**聖靈充滿事奉的範本**。'
              '他所警告的「雅偉的日子」也被新約反覆引用。',
    },
    reference: 'Joel 2:28',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '主题数据', 'zh-Hant': '主題數據'},
    title: {
      'en': 'Amos: "I will not turn away its punishment" repeats 8 times',
      'zh-Hans': '阿摩司书：连续 8 次"必不免去他的刑罚"',
      'zh-Hant': '阿摩司書：連續 8 次「必不免去他的刑罰」',
    },
    body: {
      'en':
          'Amos opens with judgment oracles against 7 surrounding nations, each ending with "for three transgressions, and for four, I will not turn away its punishment." Just as the reader expects #8 to be the climax, Amos turns the indictment on Israel itself (2:6) — the 8th and most damning. Amos was a master of the rhetorical setup.',
      'zh-Hans':
          '阿摩司书以**对周围七国**的审判预言开篇，每一段都以"为三件、四件，我必不免去他的刑罚"作结。'
              '正当读者以为第 8 段是高潮，阿摩司**把审判的矛头转向以色列自己**（2:6）——'
              '第 8 段、也是最重的一段。阿摩司是修辞铺垫的大师。',
      'zh-Hant':
          '阿摩司書以**對周圍七國**的審判預言開篇，每一段都以「為三件、四件，我必不免去他的刑罰」作結。'
              '正當讀者以為第 8 段是高潮，阿摩司**把審判的矛頭轉向以色列自己**（2:6）——'
              '第 8 段、也是最重的一段。阿摩司是修辭鋪墊的大師。',
    },
    reference: 'Amos 2:6',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '书卷之最', 'zh-Hant': '書卷之最'},
    title: {
      'en': 'Obadiah: The shortest book in the OT — 21 verses, no chapters',
      'zh-Hans': '俄巴底亚书：旧约最短的书 —— 21 节，没有章',
      'zh-Hant': '俄巴底亞書：舊約最短的書 —— 21 節，沒有章',
    },
    body: {
      'en':
          'Obadiah is the shortest book in the Old Testament — only 21 verses, never split into chapters. Its content is a single sustained oracle of judgment against Edom (Esau\'s descendants) for the way they treated their cousin Israel. The book\'s last word is "the kingdom shall be Yahweh\'s."',
      'zh-Hans':
          '俄巴底亚书是旧约最短的书——只有 **21 节**，从未被分章。全书内容是一篇持续的预言，'
              '审判**以东**（以扫的后裔）如何对待"亲表兄"以色列。'
              '全书最后一句："国度归与雅伟。"',
      'zh-Hant':
          '俄巴底亞書是舊約最短的書——只有 **21 節**，從未被分章。全書內容是一篇持續的預言，'
              '審判**以東**（以掃的後裔）如何對待「親表兄」以色列。'
              '全書最後一句：「國度歸與雅偉。」',
    },
    reference: 'Obadiah 1:21',
  ),
  BibleTriviaEntry(
    tag: {'en': 'NARRATIVE', 'zh-Hans': '反转结构', 'zh-Hant': '反轉結構'},
    title: {
      'en': 'Jonah: The only prophet who runs FROM God',
      'zh-Hans': '约拿书：圣经中唯一一个"逃避神召"的先知',
      'zh-Hant': '約拿書：聖經中唯一一個「逃避神召」的先知',
    },
    body: {
      'en':
          'Most prophets resist their call (Moses, Jeremiah, Isaiah) but obey. Jonah is the only one who actively flees — sailing to Tarshish in the opposite direction. The pagan sailors fear God before Jonah does (1:14); the pagan Ninevites repent in 40 days. The book\'s real subject isn\'t Nineveh — it\'s the prophet\'s heart.',
      'zh-Hans':
          '多数先知（摩西、耶利米、以赛亚）都对召命有所推辞但最终顺服。**约拿是唯一主动逃跑**的——'
              '坐船往他施去，正好是反方向。异教水手在约拿之前已经敬畏神（1:14）；'
              '异教尼尼微人 40 天内就悔改。**这卷书真正的主题不是尼尼微，而是这位先知的心**。',
      'zh-Hant':
          '多數先知（摩西、耶利米、以賽亞）都對召命有所推辭但最終順服。**約拿是唯一主動逃跑**的——'
              '坐船往他施去，正好是反方向。異教水手在約拿之前已經敬畏神（1:14）；'
              '異教尼尼微人 40 天內就悔改。**這卷書真正的主題不是尼尼微，而是這位先知的心**。',
    },
    reference: 'Jonah 1:3',
  ),
  BibleTriviaEntry(
    tag: {'en': 'PROPHECY', 'zh-Hans': '弥赛亚预言', 'zh-Hant': '彌賽亞預言'},
    title: {
      'en': 'Micah: Names Bethlehem 700 years before Jesus is born there',
      'zh-Hans': '弥迦书：耶稣降生前 700 年点名"伯利恒"',
      'zh-Hant': '彌迦書：耶穌降生前 700 年點名「伯利恆」',
    },
    body: {
      'en':
          'Micah 5:2 (~700 BC): "But you, Bethlehem Ephrathah, though you are little among the clans of Judah, from you shall come forth one who is to be ruler in Israel." This is the verse the magi quoted to Herod (Matthew 2:6) when locating Jesus\'s birthplace. A precise geographic prophecy fulfilled 700 years later in a tiny village.',
      'zh-Hans':
          '弥迦书 5:2（约公元前 700 年）："伯利恒以法他啊，你在犹大诸城中为小，将来必有一位从你那里出来，'
              '在以色列中为我作掌权的。"这正是博士在希律王面前引用的那节经文（马太福音 2:6）。'
              '700 年后在一个小村子里**精确应验了一处地理预言**。',
      'zh-Hant':
          '彌迦書 5:2（約公元前 700 年）：「伯利恆以法他啊，你在猶大諸城中為小，將來必有一位從你那裡出來，'
              '在以色列中為我作掌權的。」這正是博士在希律王面前引用的那節經文（馬太福音 2:6）。'
              '700 年後在一個小村子裡**精確應驗了一處地理預言**。',
    },
    reference: 'Micah 5:2',
  ),
  BibleTriviaEntry(
    tag: {'en': 'ACROSTIC', 'zh-Hans': '半离合体', 'zh-Hant': '半離合體'},
    title: {
      'en': 'Nahum: Begins with a partial alphabet acrostic',
      'zh-Hans': '那鸿书：开篇是部分字母离合体',
      'zh-Hant': '那鴻書：開篇是部分字母離合體',
    },
    body: {
      'en':
          'Nahum 1:2–8 is a partial acrostic — the first verses\' opening letters trace through about half of the Hebrew alphabet (aleph through kaph). Scholars debate whether the original was a complete acrostic now garbled in transmission, or deliberately broken. Either way, the form lends gravitas to the opening hymn against Nineveh.',
      'zh-Hans':
          '那鸿书 1:2–8 是**部分字母离合体**——开篇若干节的首字母按希伯来字母表前半部分（aleph 到 kaph）顺序排列。'
              '学者争论原来是否是完整离合体后来在传抄中残缺，或者本来就是有意截断的。'
              '无论哪种，这个形式给开篇审判尼尼微的诗篇增添了庄严感。',
      'zh-Hant':
          '那鴻書 1:2–8 是**部分字母離合體**——開篇若干節的首字母按希伯來字母表前半部分（aleph 到 kaph）順序排列。'
              '學者爭論原來是否是完整離合體後來在傳抄中殘缺，或者本來就是有意截斷的。'
              '無論哪種，這個形式給開篇審判尼尼微的詩篇增添了莊嚴感。',
    },
    reference: 'Nahum 1:2',
  ),
  BibleTriviaEntry(
    tag: {'en': 'NT QUOTE', 'zh-Hans': '新约引用', 'zh-Hant': '新約引用'},
    title: {
      'en': 'Habakkuk: "The just shall live by faith" — quoted 3× in the NT',
      'zh-Hans': '哈巴谷书："义人必因信得生" —— 新约引用 3 次',
      'zh-Hant': '哈巴谷書：「義人必因信得生」—— 新約引用 3 次',
    },
    body: {
      'en':
          'Habakkuk 2:4 — "the righteous shall live by his faith" — is quoted three times in the NT: Romans 1:17, Galatians 3:11, Hebrews 10:38. Paul builds his entire doctrine of justification by faith on this single OT verse. Luther rediscovered it during the Reformation; it\'s arguably the most theologically influential half-verse in Scripture.',
      'zh-Hans':
          '哈巴谷书 2:4——"义人必因信得生"——在新约中被**引用 3 次**：罗马书 1:17、加拉太书 3:11、希伯来书 10:38。'
              '保罗"因信称义"的整个教义建立在这一节旧约经文上。马丁路德在宗教改革时期重新发现它。'
              '这可能是圣经中**神学影响最大的半节经文**。',
      'zh-Hant':
          '哈巴谷書 2:4——「義人必因信得生」——在新約中被**引用 3 次**：羅馬書 1:17、加拉太書 3:11、希伯來書 10:38。'
              '保羅「因信稱義」的整個教義建立在這一節舊約經文上。馬丁路德在宗教改革時期重新發現它。'
              '這可能是聖經中**神學影響最大的半節經文**。',
    },
    reference: 'Habakkuk 2:4',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '主题数据', 'zh-Hant': '主題數據'},
    title: {
      'en': 'Zephaniah: "Day of Yahweh" appears 21 times in 3 chapters',
      'zh-Hans': '西番雅书：3 章中"雅伟的日子"出现 21 次',
      'zh-Hant': '西番雅書：3 章中「雅偉的日子」出現 21 次',
    },
    body: {
      'en':
          'In just 53 verses Zephaniah uses "the day of Yahweh" or "that day" 21 times — the highest density of any prophetic book. The medieval Latin hymn Dies Irae ("Day of Wrath"), still sung at funerals today, is built directly from Zephaniah 1:14–18. A small book with outsized cultural footprint.',
      'zh-Hans':
          '西番雅书全书只有 53 节，却使用"雅伟的日子"或"那日"**21 次**——是所有先知书中频率最高的。'
              '中世纪拉丁文圣咏《震怒之日》（Dies Irae）——至今仍在葬礼上吟唱——直接取材于西番雅 1:14–18。'
              '一卷小书，文化影响远远超出体量。',
      'zh-Hant':
          '西番雅書全書只有 53 節，卻使用「雅偉的日子」或「那日」**21 次**——是所有先知書中頻率最高的。'
              '中世紀拉丁文聖詠《震怒之日》（Dies Irae）——至今仍在葬禮上吟唱——直接取材於西番雅 1:14–18。'
              '一卷小書，文化影響遠遠超出體量。',
    },
    reference: 'Zephaniah 1:14',
  ),
  BibleTriviaEntry(
    tag: {'en': 'AUTHOR', 'zh-Hans': '精确历法', 'zh-Hant': '精確曆法'},
    title: {
      'en': 'Haggai: Most precisely dated book — every oracle is timestamped',
      'zh-Hans': '哈该书：每段预言都有具体日期 —— 圣经中最精准',
      'zh-Hant': '哈該書：每段預言都有具體日期 —— 聖經中最精準',
    },
    body: {
      'en':
          'Haggai records 4 oracles delivered in just 4 months, and each one is timestamped to the exact day on the Persian calendar (1:1, 1:15, 2:1, 2:10, 2:20). Cross-referenced with extant Persian records, we can pinpoint Haggai\'s ministry to the year 520 BC. No other prophet provides this kind of historical precision.',
      'zh-Hans':
          '哈该书在短短 4 个月里记录了 4 段预言，**每一段都按波斯历精确到日**'
              '（1:1、1:15、2:1、2:10、2:20）。结合现存的波斯档案，可以把哈该的事奉定在公元前 **520 年**。'
              '没有其他先知提供如此精确的历史定位。',
      'zh-Hant':
          '哈該書在短短 4 個月裡記錄了 4 段預言，**每一段都按波斯曆精確到日**'
              '（1:1、1:15、2:1、2:10、2:20）。結合現存的波斯檔案，可以把哈該的事奉定在公元前 **520 年**。'
              '沒有其他先知提供如此精確的歷史定位。',
    },
    reference: 'Haggai 1:1',
  ),
  BibleTriviaEntry(
    tag: {'en': 'VISION', 'zh-Hans': '异象数', 'zh-Hant': '異象數'},
    title: {
      'en': 'Zechariah: 8 night visions in a single night',
      'zh-Hans': '撒迦利亚书：一夜之间 8 个异象',
      'zh-Hant': '撒迦利亞書：一夜之間 8 個異象',
    },
    body: {
      'en':
          'Zechariah 1–6 describes 8 successive visions all received in a single night — riders on horses, four horns, a measuring line, a flying scroll, a golden lampstand, and more. The collection is one of the most concentrated bursts of apocalyptic imagery in the OT, and Revelation borrows heavily from it.',
      'zh-Hans':
          '撒迦利亚书 1–6 章记载了**一夜之间相继临到**的 8 个异象——骑马的、四角、量绳、'
              '飞行书卷、金灯台等等。这是旧约最密集的启示文学异象群。**启示录**大量借用其意象。',
      'zh-Hant':
          '撒迦利亞書 1–6 章記載了**一夜之間相繼臨到**的 8 個異象——騎馬的、四角、量繩、'
              '飛行書卷、金燈臺等等。這是舊約最密集的啟示文學異象群。**啟示錄**大量借用其意象。',
    },
    reference: 'Zechariah 1:8',
  ),
  BibleTriviaEntry(
    tag: {'en': 'CANON', 'zh-Hans': '正典末句', 'zh-Hant': '正典末句'},
    title: {
      'en': 'Malachi: The last word in the OT is "curse" — then 400 years of silence',
      'zh-Hans': '玛拉基书：旧约末字是"咒诅"，随后 400 年神不再说话',
      'zh-Hant': '瑪拉基書：舊約末字是「咒詛」，隨後 400 年神不再說話',
    },
    body: {
      'en':
          'Malachi closes with "lest I come and strike the land with a curse" (חרם / cherem). After this verse, the Old Testament is silent for ~400 years until Matthew opens with the announcement of John the Baptist. The OT ends on a cliffhanger of judgment — and the NT opens with the answer: a Savior is coming.',
      'zh-Hans':
          '玛拉基书末句："恐怕我来咒诅遍地"（חרם，cherem）。此节之后，**旧约 400 年沉默**——'
              '直到马太福音以"施洗约翰"开篇。旧约以审判的悬念作结，新约以答案开始：**救主要来了**。',
      'zh-Hant':
          '瑪拉基書末句：「恐怕我來咒詛遍地」（חרם，cherem）。此節之後，**舊約 400 年沉默**——'
              '直到馬太福音以「施洗約翰」開篇。舊約以審判的懸念作結，新約以答案開始：**救主要來了**。',
    },
    reference: 'Malachi 4:6',
  ),

  // ── New Testament ────────────────────────────────────────────

  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '主题数据', 'zh-Hant': '主題數據'},
    title: {
      'en': 'Mark: "Immediately" appears 41 times — fastest-paced gospel',
      'zh-Hans': '马可福音："立刻"出现 41 次 —— 节奏最快的福音书',
      'zh-Hant': '馬可福音：「立刻」出現 41 次 —— 節奏最快的福音書',
    },
    body: {
      'en':
          'The Greek word euthus ("immediately, at once") appears 41 times in Mark — more than the other 3 gospels combined. Mark moves from scene to scene at a sprint. The earliest gospel is also the shortest and the most action-driven; Matthew and Luke later expand his framework with teaching content.',
      'zh-Hans':
          '希腊文 euthus（"立刻、立时"）在马可福音中出现 **41 次**——比其他三本福音书加起来还多。'
              '马可叙事一幕接一幕极快推进。最早的福音书也是最短的、最重动作的；'
              '马太和路加后来在他的框架上扩充教训内容。',
      'zh-Hant':
          '希臘文 euthus（「立刻、立時」）在馬可福音中出現 **41 次**——比其他三本福音書加起來還多。'
              '馬可敘事一幕接一幕極快推進。最早的福音書也是最短的、最重動作的；'
              '馬太和路加後來在他的框架上擴充教訓內容。',
    },
    reference: 'Mark 1:10',
  ),
  BibleTriviaEntry(
    tag: {'en': 'AUTHOR', 'zh-Hans': '原文水准', 'zh-Hant': '原文水準'},
    title: {
      'en': 'Luke: Most polished Greek prologue in the NT',
      'zh-Hans': '路加福音：新约中最优雅的希腊文开篇',
      'zh-Hant': '路加福音：新約中最優雅的希臘文開篇',
    },
    body: {
      'en':
          'Luke 1:1–4 is a single 36-word Greek sentence — a periodic, classical-style prologue rivaling the openings of Greek historians like Thucydides. Luke (a doctor traveling with Paul) was the most literarily-trained NT author. He wrote both Luke and Acts; together they make up about 27% of the entire NT — the largest single contribution.',
      'zh-Hans':
          '路加福音 1:1–4 是一句长达 **36 词的希腊文长句**——典雅的古典风格开篇，'
              '可与修昔底德等希腊历史学家的开篇相提并论。路加（与保罗同行的医生）是新约中文学造诣最高的作者。'
              '他写了路加福音 + 使徒行传，合起来占整本新约约 **27%**——单一作者贡献最大。',
      'zh-Hant':
          '路加福音 1:1–4 是一句長達 **36 詞的希臘文長句**——典雅的古典風格開篇，'
              '可與修昔底德等希臘歷史學家的開篇相提並論。路加（與保羅同行的醫生）是新約中文學造詣最高的作者。'
              '他寫了路加福音 + 使徒行傳，合起來佔整本新約約 **27%**——單一作者貢獻最大。',
    },
    reference: 'Luke 1:1',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '七的结构', 'zh-Hant': '七的結構'},
    title: {
      'en': 'John: 7 "I am" sayings + 7 signs — built around 7s',
      'zh-Hans': '约翰福音：7 个"我是"宣言 + 7 个神迹 —— 七的结构',
      'zh-Hant': '約翰福音：7 個「我是」宣言 + 7 個神蹟 —— 七的結構',
    },
    body: {
      'en':
          'John structures his gospel around two sevens: 7 "I AM" statements (bread, light, gate, good shepherd, resurrection, way/truth/life, true vine) and 7 signs (water-wine, healing, paralytic, feeding, walking on water, blind man, Lazarus). Seven = completion in Hebrew thought. John is saying: this is the COMPLETE picture of who Jesus is.',
      'zh-Hans':
          '约翰福音以两组"七"为结构骨架：**7 个"我是"宣言**（粮、光、门、好牧人、复活、道路真理生命、真葡萄树）'
              '和 **7 个神迹**（变水为酒、医治大臣的儿子、瘫痪、五饼二鱼、海上行走、瞎眼复明、拉撒路复活）。'
              '"七"在希伯来思想中代表完整。约翰在说：**这是耶稣身份完整的画像**。',
      'zh-Hant':
          '約翰福音以兩組「七」為結構骨架：**7 個「我是」宣言**（糧、光、門、好牧人、復活、道路真理生命、真葡萄樹）'
              '和 **7 個神蹟**（變水為酒、醫治大臣的兒子、癱瘓、五餅二魚、海上行走、瞎眼復明、拉撒路復活）。'
              '「七」在希伯來思想中代表完整。約翰在說：**這是耶穌身份完整的畫像**。',
    },
    reference: 'John 6:35',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '叙事结构', 'zh-Hant': '敘事結構'},
    title: {
      'en': 'Acts: The book ends mid-story',
      'zh-Hans': '使徒行传：故事戛然而止 —— 没有结尾',
      'zh-Hant': '使徒行傳：故事戛然而止 —— 沒有結尾',
    },
    body: {
      'en':
          'Acts ends with Paul under house arrest in Rome, "preaching the kingdom of God and teaching about the Lord Jesus with all boldness." There\'s no climax, no resolution, no martyrdom — just an open ending. Many scholars think Luke ended this way deliberately: the church\'s story keeps going, and the reader is now part of it.',
      'zh-Hans':
          '使徒行传的结尾是保罗在罗马软禁中"放胆传讲神国的道，将主耶稣基督的事教导人"。'
              '**没有高潮、没有解决、没有殉道——故事戛然而止**。许多学者认为路加是故意如此：'
              '教会的故事还在继续，**读者你现在也是其中的一员**。',
      'zh-Hant':
          '使徒行傳的結尾是保羅在羅馬軟禁中「放膽傳講神國的道，將主耶穌基督的事教導人」。'
              '**沒有高潮、沒有解決、沒有殉道——故事戛然而止**。許多學者認為路加是故意如此：'
              '教會的故事還在繼續，**讀者你現在也是其中的一員**。',
    },
    reference: 'Acts 28:31',
  ),
  BibleTriviaEntry(
    tag: {'en': 'AUTHOR', 'zh-Hans': '主题数据', 'zh-Hant': '主題數據'},
    title: {
      'en': 'Romans: The most systematic exposition of the gospel in the NT',
      'zh-Hans': '罗马书：新约中最系统的福音论述',
      'zh-Hant': '羅馬書：新約中最系統的福音論述',
    },
    body: {
      'en':
          'Unlike most Pauline letters (written to address specific church problems), Romans is a deliberate, systematic exposition of the gospel — written to a church Paul had never visited. The letter\'s 16 chapters work like a dogmatics: humanity\'s problem, God\'s solution, life in Christ, Israel\'s place, ethics. Augustine, Luther, Calvin, and Wesley all had life-changing encounters with this letter.',
      'zh-Hans':
          '不同于保罗其他多数书信（针对具体教会问题而写），罗马书是一篇**有意编排的福音系统论述**——'
              '写给保罗从未到访过的教会。16 章像一部教理学：人类的问题、神的方案、'
              '在基督里的生活、以色列的地位、伦理。**奥古斯丁、路德、加尔文、卫斯理**都曾因此书信经历改变生命的相遇。',
      'zh-Hant':
          '不同於保羅其他多數書信（針對具體教會問題而寫），羅馬書是一篇**有意編排的福音系統論述**——'
              '寫給保羅從未到訪過的教會。16 章像一部教理學：人類的問題、神的方案、'
              '在基督裡的生活、以色列的地位、倫理。**奧古斯丁、路德、加爾文、衛斯理**都曾因此書信經歷改變生命的相遇。',
    },
    reference: 'Romans 1:16',
  ),
  BibleTriviaEntry(
    tag: {'en': 'POETRY', 'zh-Hans': '爱的诗章', 'zh-Hant': '愛的詩章'},
    title: {
      'en': '1 Corinthians 13: "Love" appears 9 times in 13 verses',
      'zh-Hans': '哥林多前书 13 章：13 节经文中"爱"出现 9 次',
      'zh-Hant': '哥林多前書 13 章：13 節經文中「愛」出現 9 次',
    },
    body: {
      'en':
          'Often called the "love chapter," 1 Corinthians 13 is a self-contained poem that Paul drops into the middle of a discussion about spiritual gifts. The Greek word agape ("self-giving love") appears 9 times in 13 verses. Paul lists 15 things love is and isn\'t — a deliberate echo of Greek virtue ethics, redirected toward the cross.',
      'zh-Hans':
          '常被称为"爱的诗章"——哥林多前书第 13 章是保罗在讨论属灵恩赐中插入的一首独立诗。'
              '希腊文 agape（"舍己之爱"）在短短 13 节中出现 **9 次**。保罗列出了 **15 项**爱"是"和"不是"什么——'
              '这是有意呼应希腊伦理学的"美德论"，但把方向转向**十字架**。',
      'zh-Hant':
          '常被稱為「愛的詩章」——哥林多前書第 13 章是保羅在討論屬靈恩賜中插入的一首獨立詩。'
              '希臘文 agape（「捨己之愛」）在短短 13 節中出現 **9 次**。保羅列出了 **15 項**愛「是」和「不是」什麼——'
              '這是有意呼應希臘倫理學的「美德論」，但把方向轉向**十字架**。',
    },
    reference: '1 Corinthians 13',
  ),
  BibleTriviaEntry(
    tag: {'en': 'AUTHOR', 'zh-Hans': '自传性', 'zh-Hant': '自傳性'},
    title: {
      'en': '2 Corinthians: Paul\'s most personal letter',
      'zh-Hans': '哥林多后书：保罗最个人化的书信',
      'zh-Hant': '哥林多後書：保羅最個人化的書信',
    },
    body: {
      'en':
          '2 Corinthians is the most autobiographical of Paul\'s letters. He lists his sufferings (11:23–28), his "thorn in the flesh" (12:7), his vision of the third heaven (12:2). The tone shifts from tender to defensive — Paul is fighting for a church being seduced by "super-apostles." It\'s the most emotionally raw letter Paul wrote.',
      'zh-Hans':
          '哥林多后书是保罗书信中**最自传性**的。他列举自己受的苦（11:23–28）、'
              '"身上的一根刺"（12:7）、被提到第三层天的异象（12:2）。语气在温柔与辩护之间切换——'
              '保罗为一间正被"超级使徒"诱惑的教会奋力争战。**这是保罗笔下情感最赤裸的一封信**。',
      'zh-Hant':
          '哥林多後書是保羅書信中**最自傳性**的。他列舉自己受的苦（11:23–28）、'
              '「身上的一根刺」（12:7）、被提到第三層天的異象（12:2）。語氣在溫柔與辯護之間切換——'
              '保羅為一間正被「超級使徒」誘惑的教會奮力爭戰。**這是保羅筆下情感最赤裸的一封信**。',
    },
    reference: '2 Corinthians 11:23',
  ),
  BibleTriviaEntry(
    tag: {'en': 'AUTHOR', 'zh-Hans': '保罗笔迹', 'zh-Hant': '保羅筆跡'},
    title: {
      'en': 'Galatians: Paul writes the closing himself "in large letters"',
      'zh-Hans': '加拉太书：保罗"用大字"亲手写最后一段',
      'zh-Hant': '加拉太書：保羅「用大字」親手寫最後一段',
    },
    body: {
      'en':
          'Paul typically dictated his letters to scribes, then signed at the end. But in Galatians 6:11 he writes: "See with what large letters I am writing to you with my own hand." Many scholars connect this to his "thorn in the flesh" — possibly an eye disease that made fine writing hard. The "large letters" line is Paul\'s personal handwriting still visible across 2,000 years.',
      'zh-Hans':
          '保罗通常口述书信由文书代笔，最后亲笔签名。但加拉太书 6:11 他写道："请看我亲手写给你们的字是何等的大！"'
              '许多学者把这与他"肉体上的刺"联系起来——可能是某种眼疾使精细书写困难。'
              '**这一行"大字"是保罗 2000 年前的亲笔笔迹**，至今依然可见。',
      'zh-Hant':
          '保羅通常口述書信由文書代筆，最後親筆簽名。但加拉太書 6:11 他寫道：「請看我親手寫給你們的字是何等的大！」'
              '許多學者把這與他「肉體上的刺」聯繫起來——可能是某種眼疾使精細書寫困難。'
              '**這一行「大字」是保羅 2000 年前的親筆筆跡**，至今依然可見。',
    },
    reference: 'Galatians 6:11',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '主题数据', 'zh-Hant': '主題數據'},
    title: {
      'en': 'Ephesians: "In Christ" / "in Him" appears 27 times',
      'zh-Hans': '以弗所书："在基督里"/"在他里面"出现 27 次',
      'zh-Hant': '以弗所書：「在基督裡」／「在他裡面」出現 27 次',
    },
    body: {
      'en':
          'In just 6 short chapters Paul uses the phrase en Christo ("in Christ") or en auto ("in him") about 27 times. The whole letter is structured around what it means to be located IN Christ — every spiritual blessing, election, adoption, redemption, sealing. Ephesians is the classic text for "union with Christ."',
      'zh-Hans':
          '在短短 6 章中，保罗使用 en Christo（"在基督里"）或 en auto（"在他里面"）大约 **27 次**。'
              '整封书信围绕**身处基督之"内"**这个核心展开——一切属灵的福气、拣选、得儿子的名分、'
              '救赎、印记，都在基督里。以弗所书是讲"与基督联合"的经典文本。',
      'zh-Hant':
          '在短短 6 章中，保羅使用 en Christo（「在基督裡」）或 en auto（「在他裡面」）大約 **27 次**。'
              '整封書信圍繞**身處基督之「內」**這個核心展開——一切屬靈的福氣、揀選、得兒子的名分、'
              '救贖、印記，都在基督裡。以弗所書是講「與基督聯合」的經典文本。',
    },
    reference: 'Ephesians 1:3',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '主题数据', 'zh-Hant': '主題數據'},
    title: {
      'en': 'Philippians: Paul writes about "joy/rejoice" 16 times — from prison',
      'zh-Hans': '腓立比书：保罗在牢里写下"喜乐"16 次',
      'zh-Hant': '腓立比書：保羅在牢裡寫下「喜樂」16 次',
    },
    body: {
      'en':
          'Paul wrote Philippians from a Roman prison. In just 4 chapters he uses words for "joy" or "rejoice" 16 times. "Rejoice in the Lord always; again I will say, rejoice" (4:4). The most upbeat letter in the NT comes from a man in chains — joy independent of circumstances is Philippians\' core argument.',
      'zh-Hans':
          '保罗在罗马监狱中写下腓立比书。短短 4 章里他使用"喜乐"或"欢喜"**16 次**。'
              '"你们要靠主常常喜乐，我再说，你们要喜乐！"（4:4）**新约中最欢欣的书信，'
              '出自一个戴着锁链的人**——喜乐不依赖环境，正是腓立比书的核心论点。',
      'zh-Hant':
          '保羅在羅馬監獄中寫下腓立比書。短短 4 章裡他使用「喜樂」或「歡喜」**16 次**。'
              '「你們要靠主常常喜樂，我再說，你們要喜樂！」（4:4）**新約中最歡欣的書信，'
              '出自一個戴著鎖鏈的人**——喜樂不依賴環境，正是腓立比書的核心論點。',
    },
    reference: 'Philippians 4:4',
  ),
  BibleTriviaEntry(
    tag: {'en': 'POETRY', 'zh-Hans': '基督颂歌', 'zh-Hant': '基督頌歌'},
    title: {
      'en': 'Colossians: Christological hymn — possibly an early church song',
      'zh-Hans': '歌罗西书：基督论诗章 —— 可能是初代教会的诗歌',
      'zh-Hant': '歌羅西書：基督論詩章 —— 可能是初代教會的詩歌',
    },
    body: {
      'en':
          'Colossians 1:15–20 reads as a self-contained poem in 8 carefully balanced lines. Many scholars believe Paul is quoting an early Christian hymn already circulating in the churches. Its claims are immense: Christ is the image of God, firstborn of creation, and the agent through whom and for whom everything was created. Possibly the oldest Christian song we have.',
      'zh-Hans':
          '歌罗西书 1:15–20 读起来像一首独立的诗，8 行精心对仗。许多学者认为保罗在引用一首已在教会间流传的'
              '**早期基督教诗歌**。它的主张极宏大：基督是神的形象、是受造之先的长子、'
              '万有借他造、为他造。**可能是我们手上最古老的基督教诗歌**。',
      'zh-Hant':
          '歌羅西書 1:15–20 讀起來像一首獨立的詩，8 行精心對仗。許多學者認為保羅在引用一首已在教會間流傳的'
              '**早期基督教詩歌**。它的主張極宏大：基督是神的形象、是受造之先的長子、'
              '萬有藉他造、為他造。**可能是我們手上最古老的基督教詩歌**。',
    },
    reference: 'Colossians 1:15',
  ),
  BibleTriviaEntry(
    tag: {'en': 'AUTHOR', 'zh-Hans': '最早书信', 'zh-Hant': '最早書信'},
    title: {
      'en': '1 Thessalonians: Paul\'s earliest surviving letter',
      'zh-Hans': '帖撒罗尼迦前书：保罗现存最早的书信',
      'zh-Hant': '帖撒羅尼迦前書：保羅現存最早的書信',
    },
    body: {
      'en':
          '1 Thessalonians (~AD 50) is likely Paul\'s earliest surviving letter — and possibly the earliest book of the NT, predating even the gospels. Already at this stage Paul confidently teaches the second coming of Christ as established doctrine (4:13–18). It shows how quickly resurrection theology crystallized in the first decades after Jesus.',
      'zh-Hans':
          '帖撒罗尼迦前书（约公元 50 年）很可能是保罗现存**最早的书信**——'
              '甚至**比四福音书还早**，可能是新约最早成书的一卷。早在这个阶段保罗已经把"基督再来"作为既定的教义来教导'
              '（4:13–18）。这显示**复活神学在耶稣之后的头几十年就已经成熟**。',
      'zh-Hant':
          '帖撒羅尼迦前書（約公元 50 年）很可能是保羅現存**最早的書信**——'
              '甚至**比四福音書還早**，可能是新約最早成書的一卷。早在這個階段保羅已經把「基督再來」作為既定的教義來教導'
              '（4:13–18）。這顯示**復活神學在耶穌之後的頭幾十年就已經成熟**。',
    },
    reference: '1 Thessalonians 4:13',
  ),
  BibleTriviaEntry(
    tag: {'en': 'PROPHECY', 'zh-Hans': '末世预言', 'zh-Hant': '末世預言'},
    title: {
      'en': '2 Thessalonians: The most detailed antichrist prophecy in Paul',
      'zh-Hans': '帖撒罗尼迦后书：保罗书信中最详细的"敌基督"预言',
      'zh-Hant': '帖撒羅尼迦後書：保羅書信中最詳細的「敵基督」預言',
    },
    body: {
      'en':
          'In 2 Thessalonians 2:1–12, Paul gives his clearest description of the "man of lawlessness" — what later theology calls the antichrist. He sits in the temple, claims to be God, is held back by a "restrainer," and is finally destroyed by Christ\'s return. This 12-verse passage has been the focal point of eschatological debate for 2,000 years.',
      'zh-Hans':
          '帖撒罗尼迦后书 2:1–12 是保罗对"那大罪人 / 不法的人"——后来神学称为**敌基督**——'
              '最清晰的描述。他坐在神的殿中自称是神，被"那拦阻者"暂时止住，最终被基督再来时毁灭。'
              '这短短 12 节经文 2000 年来一直是末世论辩论的焦点。',
      'zh-Hant':
          '帖撒羅尼迦後書 2:1–12 是保羅對「那大罪人／不法的人」——後來神學稱為**敵基督**——'
              '最清晰的描述。他坐在神的殿中自稱是神，被「那攔阻者」暫時止住，最終被基督再來時毀滅。'
              '這短短 12 節經文 2000 年來一直是末世論辯論的焦點。',
    },
    reference: '2 Thessalonians 2:3',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '主题数据', 'zh-Hant': '主題數據'},
    title: {
      'en': '1 Timothy: "Faithful saying" formula appears 5 times',
      'zh-Hans': '提摩太前书："这话是可信的"出现 5 次',
      'zh-Hant': '提摩太前書：「這話是可信的」出現 5 次',
    },
    body: {
      'en':
          'The Pastoral Epistles (1 Tim, 2 Tim, Titus) introduce the formula "this is a faithful saying" (πιστὸς ὁ λόγος / pistos ho logos) 5 times — likely citing already-formed early creeds the church was reciting. Each "faithful saying" is a tightly worded summary of gospel truth. Paul is quoting the church back to itself.',
      'zh-Hans':
          '教牧书信（提前、提后、提多）中出现 5 次"这话是可信的"（πιστὸς ὁ λόγος，pistos ho logos）。'
              '这些可能是教会已经在背诵的**早期信条片段**——保罗是在**把教会的信仰宣告反过来引用给教会听**。'
              '每一句"可信之言"都是福音真理的精要总结。',
      'zh-Hant':
          '教牧書信（提前、提後、提多）中出現 5 次「這話是可信的」（πιστὸς ὁ λόγος，pistos ho logos）。'
              '這些可能是教會已經在背誦的**早期信條片段**——保羅是在**把教會的信仰宣告反過來引用給教會聽**。'
              '每一句「可信之言」都是福音真理的精要總結。',
    },
    reference: '1 Timothy 1:15',
  ),
  BibleTriviaEntry(
    tag: {'en': 'AUTHOR', 'zh-Hans': '保罗遗言', 'zh-Hant': '保羅遺言'},
    title: {
      'en': '2 Timothy: Paul\'s last letter — written before his execution',
      'zh-Hans': '提摩太后书：保罗的遗言 —— 殉道前所写',
      'zh-Hant': '提摩太後書：保羅的遺言 —— 殉道前所寫',
    },
    body: {
      'en':
          '2 Timothy is widely considered Paul\'s last letter, written from his second Roman imprisonment shortly before he was executed under Nero (~AD 66–67). "The time of my departure has come. I have fought the good fight, I have finished the race, I have kept the faith" (4:6–7). Reading these words knowing they were Paul\'s last makes them weighty.',
      'zh-Hans':
          '提摩太后书被广泛认为是保罗的**遗书**，写于他第二次罗马监禁、'
              '即将在尼禄手下被处决之前（约公元 66–67 年）。"我离世的时候到了。那美好的仗我已经打过了，'
              '当跑的路我已经跑尽了，所信的道我已经守住了"（4:6–7）。'
              '知道这是保罗的最后遗言，再读这些话别有重量。',
      'zh-Hant':
          '提摩太後書被廣泛認為是保羅的**遺書**，寫於他第二次羅馬監禁、'
              '即將在尼祿手下被處決之前（約公元 66–67 年）。「我離世的時候到了。那美好的仗我已經打過了，'
              '當跑的路我已經跑盡了，所信的道我已經守住了」（4:6–7）。'
              '知道這是保羅的最後遺言，再讀這些話別有重量。',
    },
    reference: '2 Timothy 4:6',
  ),
  BibleTriviaEntry(
    tag: {'en': 'AUTHOR', 'zh-Hans': '宣教视野', 'zh-Hant': '宣教視野'},
    title: {
      'en': 'Titus: Mentions Crete — Christianity reached the island within a generation',
      'zh-Hans': '提多书：提及克里特 —— 福音一代之内就到了那里',
      'zh-Hant': '提多書：提及克里特 —— 福音一代之內就到了那裡',
    },
    body: {
      'en':
          'Paul left Titus on Crete (1:5) to organize the churches already meeting there. The fact that there were enough believers on the island to need oversight just 30 years after the resurrection shows how rapidly Christianity spread across the Mediterranean — long before Constantine, before any state support, by ordinary travelers, traders, and merchants carrying the gospel.',
      'zh-Hans':
          '保罗把提多留在**克里特岛**（1:5）来整顿那里已经在聚会的教会。'
              '复活后短短 30 年，这个地中海岛屿就有足够多的信徒需要按立长老治理——'
              '**福音传播的速度**远比许多人想的快得多，早在君士坦丁、早在任何国家支持之前，'
              '就由普通旅人、商人把福音带到了地中海各处。',
      'zh-Hant':
          '保羅把提多留在**克里特島**（1:5）來整頓那裡已經在聚會的教會。'
              '復活後短短 30 年，這個地中海島嶼就有足夠多的信徒需要按立長老治理——'
              '**福音傳播的速度**遠比許多人想的快得多，早在君士坦丁、早在任何國家支持之前，'
              '就由普通旅人、商人把福音帶到了地中海各處。',
    },
    reference: 'Titus 1:5',
  ),
  BibleTriviaEntry(
    tag: {'en': 'NARRATIVE', 'zh-Hans': '一封私信', 'zh-Hant': '一封私信'},
    title: {
      'en': 'Philemon: A 25-verse letter that quietly undermines slavery',
      'zh-Hans': '腓利门书：25 节经文 —— 悄悄瓦解奴隶制',
      'zh-Hant': '腓利門書：25 節經文 —— 悄悄瓦解奴隸制',
    },
    body: {
      'en':
          'Philemon is a private 25-verse letter asking a slave owner to receive his runaway slave Onesimus back as "a beloved brother" (v.16). Paul never directly attacks slavery as an institution, but the logic of the gospel — "no longer as a slave, but better than a slave" — is devastating to it. The letter quietly contained the seed of abolition movements 1,800 years later.',
      'zh-Hans':
          '腓利门书是一封 **25 节的私人书信**，请求一个奴隶主接受逃跑的奴隶阿尼西母回来——但要把他视为'
              '"亲爱的弟兄"（16 节）。**保罗从未正面攻击奴隶制**，但福音的逻辑——'
              '"不再是奴仆，乃比奴仆更胜"——对这个制度是毁灭性的。这封小书信的种子'
              '在 1800 年后开花结果，长成废奴运动。',
      'zh-Hant':
          '腓利門書是一封 **25 節的私人書信**，請求一個奴隸主接受逃跑的奴隸阿尼西母回來——但要把他視為'
              '「親愛的弟兄」（16 節）。**保羅從未正面攻擊奴隸制**，但福音的邏輯——'
              '「不再是奴僕，乃比奴僕更勝」——對這個制度是毀滅性的。這封小書信的種子'
              '在 1800 年後開花結果，長成廢奴運動。',
    },
    reference: 'Philemon 16',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '主题数据', 'zh-Hant': '主題數據'},
    title: {
      'en': 'Hebrews: "Better" appears 13 times — argument by superiority',
      'zh-Hans': '希伯来书："更美"出现 13 次 —— 步步显明耶稣的超越',
      'zh-Hant': '希伯來書：「更美」出現 13 次 —— 步步顯明耶穌的超越',
    },
    body: {
      'en':
          'The author of Hebrews builds the entire argument around the Greek word kreitton ("better, superior"), which appears 13 times. Christ has a better name than angels, a better priesthood than Aaron, a better covenant than Sinai, a better sacrifice than animals, a better hope, a better resurrection. Hebrews is sustained comparative theology.',
      'zh-Hans':
          '希伯来书的作者以希腊文 kreitton（"更好的、更卓越的"）建构整个论证，'
              '该词出现 **13 次**。基督的名超过天使、祭司职任超过亚伦、'
              '所立的约超过西奈山、献的祭超过动物的祭、给的盼望更美、复活更美。'
              '**希伯来书是一篇持续比较的神学论文**。',
      'zh-Hant':
          '希伯來書的作者以希臘文 kreitton（「更好的、更卓越的」）建構整個論證，'
              '該詞出現 **13 次**。基督的名超過天使、祭司職任超過亞倫、'
              '所立的約超過西奈山、獻的祭超過動物的祭、給的盼望更美、復活更美。'
              '**希伯來書是一篇持續比較的神學論文**。',
    },
    reference: 'Hebrews 1:4',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '主题数据', 'zh-Hant': '主題數據'},
    title: {
      'en': 'James: ~50 imperatives in 108 verses — most action-driven epistle',
      'zh-Hans': '雅各书：108 节中约 50 个命令式 —— 实践导向最重的书信',
      'zh-Hant': '雅各書：108 節中約 50 個命令式 —— 實踐導向最重的書信',
    },
    body: {
      'en':
          'James packs about 50 imperative verbs ("do this, don\'t do that") into just 108 verses — far higher density than any other NT letter. His thesis: faith without works is dead. Many compared James to OT wisdom literature like Proverbs. Luther, troubled by it, called James "an epistle of straw" — but the church kept it precisely because faith and action belong together.',
      'zh-Hans':
          '雅各书在 108 节经文中**塞进约 50 个命令动词**（"要这样、不要那样"）——'
              '密度远超新约其他书信。他的论题："信心若没有行为就是死的。"许多人把雅各书与旧约**箴言**等智慧文学比较。'
              '路德困惑于此书，称之为"草木一般的书信"——但教会坚持保留它，正因**信心与行为本不可分**。',
      'zh-Hant':
          '雅各書在 108 節經文中**塞進約 50 個命令動詞**（「要這樣、不要那樣」）——'
              '密度遠超新約其他書信。他的論題：「信心若沒有行為就是死的。」許多人把雅各書與舊約**箴言**等智慧文學比較。'
              '路德困惑於此書，稱之為「草木一般的書信」——但教會堅持保留它，正因**信心與行為本不可分**。',
    },
    reference: 'James 2:17',
  ),
  BibleTriviaEntry(
    tag: {'en': 'AUTHOR', 'zh-Hans': '历史背景', 'zh-Hant': '歷史背景'},
    title: {
      'en': '1 Peter: Written from Rome during Nero\'s persecution',
      'zh-Hans': '彼得前书：尼禄逼迫期间写于罗马',
      'zh-Hant': '彼得前書：尼祿逼迫期間寫於羅馬',
    },
    body: {
      'en':
          'Peter writes "from Babylon" (5:13) — early-church code for Rome. The letter\'s heavy emphasis on suffering with grace fits the period of Nero\'s persecution (mid-60s AD), in which Peter himself was eventually crucified upside down (according to tradition). His readers in Asia Minor were facing what he was facing; he writes to encourage them as someone walking the same road.',
      'zh-Hans':
          '彼得说他从"巴比伦"写信（5:13）——这是早期教会对**罗马**的暗号。书信中对"在恩典中受苦"的强烈强调，'
              '吻合尼禄逼迫的时代背景（公元 60 年代中期）。彼得自己**最终在罗马倒钉十字架而殉道**（按教会传统）。'
              '他的读者在小亚细亚正面对着同样的处境——他是以**同路人的身份**写信鼓励他们。',
      'zh-Hant':
          '彼得說他從「巴比倫」寫信（5:13）——這是早期教會對**羅馬**的暗號。書信中對「在恩典中受苦」的強烈強調，'
              '吻合尼祿逼迫的時代背景（公元 60 年代中期）。彼得自己**最終在羅馬倒釘十字架而殉道**（按教會傳統）。'
              '他的讀者在小亞細亞正面對著同樣的處境——他是以**同路人的身份**寫信鼓勵他們。',
    },
    reference: '1 Peter 5:13',
  ),
  BibleTriviaEntry(
    tag: {'en': 'CANON', 'zh-Hans': '正典互证', 'zh-Hant': '正典互證'},
    title: {
      'en': '2 Peter: Calls Paul\'s letters "Scripture" already in the 1st century',
      'zh-Hans': '彼得后书：第一世纪就把保罗书信视为"圣经"',
      'zh-Hant': '彼得後書：第一世紀就把保羅書信視為「聖經」',
    },
    body: {
      'en':
          '2 Peter 3:15–16 mentions "our beloved brother Paul wrote you" and groups Paul\'s letters with "the OTHER Scriptures" (γραφάς / graphas). This is one of the earliest pieces of evidence we have that the 1st-century church was already viewing apostolic writings as Scripture, on par with the Old Testament. Canon-formation began far earlier than Nicaea.',
      'zh-Hans':
          '彼得后书 3:15–16 提到"我们所亲爱的兄弟保罗"写信给你们，并把保罗的书信与**"其他经书"**'
              '（γραφάς，graphas）并列。这是我们最早的证据之一，表明**第一世纪的教会已经把使徒书信视为圣经**，'
              '与旧约同等地位。**正典的成形远早于尼西亚会议**。',
      'zh-Hant':
          '彼得後書 3:15–16 提到「我們所親愛的兄弟保羅」寫信給你們，並把保羅的書信與**「其他經書」**'
              '（γραφάς，graphas）並列。這是我們最早的證據之一，表明**第一世紀的教會已經把使徒書信視為聖經**，'
              '與舊約同等地位。**正典的成形遠早於尼西亞會議**。',
    },
    reference: '2 Peter 3:16',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '主题数据', 'zh-Hant': '主題數據'},
    title: {
      'en': '1 John: "Know" appears 38 times — confidence theology',
      'zh-Hans': '约翰一书："晓得"出现 38 次 —— 确据的神学',
      'zh-Hant': '約翰一書：「曉得」出現 38 次 —— 確據的神學',
    },
    body: {
      'en':
          '1 John uses Greek words for "know" (oida, ginosko) about 38 times in just 5 chapters. The whole letter is structured as tests for assurance: "By this we know we have come to know him..." (2:3), "...that we are of the truth" (3:19), "...that he abides in us" (3:24), "...that we love the children of God" (5:2). John writes so believers may "know" they have eternal life (5:13).',
      'zh-Hans':
          '约翰一书在短短 5 章中使用希腊文"知道"（oida、ginosko）约 **38 次**。'
              '整封书信围绕**确据的检验**展开："我们若遵守他的诫命，就晓得是认识他"（2:3）、'
              '"知道我们是属真理的"（3:19）、"知道他住在我们里面"（3:24）、'
              '"知道我们爱神的儿女"（5:2）。约翰写信"是要叫你们知道自己有永生"（5:13）。',
      'zh-Hant':
          '約翰一書在短短 5 章中使用希臘文「知道」（oida、ginosko）約 **38 次**。'
              '整封書信圍繞**確據的檢驗**展開：「我們若遵守他的誡命，就曉得是認識他」（2:3）、'
              '「知道我們是屬真理的」（3:19）、「知道他住在我們裡面」（3:24）、'
              '「知道我們愛神的兒女」（5:2）。約翰寫信「是要叫你們知道自己有永生」（5:13）。',
    },
    reference: '1 John 5:13',
  ),
  BibleTriviaEntry(
    tag: {'en': 'NARRATIVE', 'zh-Hans': '一篇短信', 'zh-Hant': '一篇短信'},
    title: {
      'en': '2 John: Personal letter to "the elect lady"',
      'zh-Hans': '约翰二书：写给"蒙拣选的太太"的私信',
      'zh-Hant': '約翰二書：寫給「蒙揀選的太太」的私信',
    },
    body: {
      'en':
          '2 John (only 13 verses) is addressed to "the elect lady and her children." Scholars debate whether this is an actual woman with children or a metaphor for a local church and its members. Either way, the letter\'s warmth — "I rejoiced greatly to find some of your children walking in the truth" (v.4) — feels personal in a way the larger epistles don\'t.',
      'zh-Hans':
          '约翰二书（仅 13 节）是写给"蒙拣选的太太和她的儿女"的。学者们争论这是一位真实的妇女带着孩子，'
              '还是某间地方教会及其成员的比喻。无论哪种，书信的温柔——"我见你的儿女中有按真理而行的，'
              '就甚欢喜"（4 节）——比那些较长的书信都更**有私交感**。',
      'zh-Hant':
          '約翰二書（僅 13 節）是寫給「蒙揀選的太太和她的兒女」的。學者們爭論這是一位真實的婦女帶著孩子，'
              '還是某間地方教會及其成員的比喻。無論哪種，書信的溫柔——「我見你的兒女中有按真理而行的，'
              '就甚歡喜」（4 節）——比那些較長的書信都更**有私交感**。',
    },
    reference: '2 John 1:4',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '书卷之最', 'zh-Hant': '書卷之最'},
    title: {
      'en': '3 John: The shortest book in the Bible (219 Greek words / 14 verses)',
      'zh-Hans': '约翰三书：圣经最短的书（希腊原文 219 词 / 14 节）',
      'zh-Hant': '約翰三書：聖經最短的書（希臘原文 219 詞 / 14 節）',
    },
    body: {
      'en':
          '3 John is the shortest book in the Bible — 219 Greek words, 14 English verses. It\'s a personal letter to "the beloved Gaius" praising him for hospitality to traveling missionaries, while criticizing a man named Diotrephes for refusing the same. The letter ends with "I had much to write to you, but I would rather not write with pen and ink" — a glimpse of how letters worked in antiquity.',
      'zh-Hans':
          '约翰三书是**圣经最短的书**——希腊原文 219 词、英译 14 节。这是一封写给"亲爱的该犹"的私信，'
              '称赞他款待巡回的宣教者，同时批评一个名叫**丢特腓**的人拒绝接待。书信结尾说："我还有许多事要写给你，'
              '却不愿意用笔墨写出来"——让我们一窥古代书信往来的样貌。',
      'zh-Hant':
          '約翰三書是**聖經最短的書**——希臘原文 219 詞、英譯 14 節。這是一封寫給「親愛的該猶」的私信，'
              '稱讚他款待巡迴的宣教者，同時批評一個名叫**丟特腓**的人拒絕接待。書信結尾說：「我還有許多事要寫給你，'
              '卻不願意用筆墨寫出來」——讓我們一窺古代書信往來的樣貌。',
    },
    reference: '3 John 1:13',
  ),
  BibleTriviaEntry(
    tag: {'en': 'CANON', 'zh-Hans': '引用次经', 'zh-Hant': '引用次經'},
    title: {
      'en': 'Jude: Quotes 1 Enoch — the only NT book to cite a non-canonical work',
      'zh-Hans': '犹大书：唯一引用《以诺一书》的新约书卷',
      'zh-Hant': '猶大書：唯一引用《以諾一書》的新約書卷',
    },
    body: {
      'en':
          'Jude 14–15 directly quotes 1 Enoch ("Behold, the Lord came with his holy myriads..."), a Jewish apocalyptic book never accepted as canonical Scripture. Jude also alludes to "the Assumption of Moses" (v.9). This makes Jude the only NT writer to explicitly cite non-canonical literature as authoritative — an interesting window into 1st-century Jewish reading habits.',
      'zh-Hans':
          '犹大书 14–15 直接引用《以诺一书》（"看哪，主带着他的千万圣者降临……"）——'
              '一卷从未被列入正典的犹太启示文学。犹大书 9 节还暗指《摩西升天记》。'
              '这使**犹大书成为新约中唯一明确引用次经文献为权威**的书卷——'
              '为我们一窥第一世纪犹太人的阅读习惯打开了一扇窗。',
      'zh-Hant':
          '猶大書 14–15 直接引用《以諾一書》（「看哪，主帶著他的千萬聖者降臨……」）——'
              '一卷從未被列入正典的猶太啟示文學。猶大書 9 節還暗指《摩西升天記》。'
              '這使**猶大書成為新約中唯一明確引用次經文獻為權威**的書卷——'
              '為我們一窺第一世紀猶太人的閱讀習慣打開了一扇窗。',
    },
    reference: 'Jude 1:14',
  ),
  BibleTriviaEntry(
    tag: {'en': 'STRUCTURE', 'zh-Hans': '七的结构', 'zh-Hant': '七的結構'},
    title: {
      'en': 'Revelation: Sevens everywhere — 7 churches, seals, trumpets, bowls',
      'zh-Hans': '启示录：七的结构无处不在 —— 7 教会、7 印、7 号、7 碗',
      'zh-Hant': '啟示錄：七的結構無處不在 —— 7 教會、7 印、7 號、7 碗',
    },
    body: {
      'en':
          'Revelation has 7 churches, 7 seals, 7 trumpets, 7 thunders, 7 bowls of wrath, 7 spirits of God, 7 horns/eyes of the Lamb, 7 stars in Christ\'s hand, 7 lampstands, 7 beatitudes scattered through the book. The number 7 appears 54 times in 22 chapters. The whole apocalypse is organized around completion / divine perfection.',
      'zh-Hans':
          '启示录中"七"无处不在——7 间教会、7 印、7 号、7 雷、7 碗忿怒、7 灵、'
              '羔羊的 7 角 /7 眼、基督手中 7 星、7 灯台、全书散布 7 个"福"。'
              '"七"这个数字在 22 章中出现 **54 次**。整本启示录围绕"完整 / 神圣的完美"这个数字编排。',
      'zh-Hant':
          '啟示錄中「七」無處不在——7 間教會、7 印、7 號、7 雷、7 碗忿怒、7 靈、'
              '羔羊的 7 角／7 眼、基督手中 7 星、7 燈臺、全書散布 7 個「福」。'
              '「七」這個數字在 22 章中出現 **54 次**。整本啟示錄圍繞「完整／神聖的完美」這個數字編排。',
    },
    reference: 'Revelation 1:4',
  ),
];
