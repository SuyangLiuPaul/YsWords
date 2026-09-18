/// The Help page — every feature, where it lives, how it differs by
/// platform, and every gesture and key, with a search box over all of it.
///
/// 2026-09-18, 「sword所有的shortcut和一些help doc是不是应该有一个page教我们
/// 怎么用 words也是」. What it replaced: a `?` dialog that listed four of
/// the reading column's ten keys and none of the projection's twenty-
/// seven, and no description of any feature anywhere inside the app. The
/// model and its rules are in `help_catalog.dart`; the words are in
/// `help_topics.dart`. The sibling app has the same page.
///
/// Opened from Quick links › Help on the home page, the top of Settings,
/// ⋯ › Help in the reader, and `?` in the text.
library;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yahwehs_words/constants/help_topics.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/about_page.dart';
import 'package:yahwehs_words/pages/bible_timeline_page.dart';
import 'package:yahwehs_words/pages/bible_trivia_page.dart';
import 'package:yahwehs_words/pages/evidence_page.dart';
import 'package:yahwehs_words/pages/family_tree_page.dart';
import 'package:yahwehs_words/pages/feedback_page.dart';
import 'package:yahwehs_words/pages/library_page.dart';
import 'package:yahwehs_words/pages/misconceptions_page.dart';
import 'package:yahwehs_words/pages/profiles_page.dart';
import 'package:yahwehs_words/pages/projection_page.dart'
    show ProjectionPage, kProjectionKeymap;
import 'package:yahwehs_words/pages/reading_stats_page.dart';
import 'package:yahwehs_words/pages/search_page.dart';
import 'package:yahwehs_words/pages/sermons_page.dart';
import 'package:yahwehs_words/pages/settings_page.dart';
import 'package:yahwehs_words/pages/songs_page.dart';
import 'package:yahwehs_words/pages/stats_page.dart';
import 'package:yahwehs_words/pages/videos_page.dart';
import 'package:yahwehs_words/utils/app_nav.dart';
import 'package:yahwehs_words/utils/app_scroll_behavior.dart'
    show kSelectableTextPhysics;
import 'package:yahwehs_words/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yahwehs_words/utils/help_catalog.dart';
import 'package:yahwehs_words/utils/keyboard_shortcuts.dart';
import 'package:yahwehs_words/utils/responsive.dart';
import 'package:yahwehs_words/widgets/home_icon_button.dart';
import 'package:yahwehs_words/widgets/language_switcher_button.dart';
import 'package:yahwehs_words/widgets/localized_back_button.dart';

/// Open the Help page, optionally at [section] or already searching
/// [query].
Future<void> openHelp(
  BuildContext context, {
  HelpSection? section,
  String? query,
}) async {
  // No route name: Help is not addressable — see its row in
  // docs/url-routing-plan.md §3.
  await pushPage(HelpPage(initialSection: section, initialQuery: query));
}

/// The device the page describes by default.
HelpPlatform currentHelpPlatform() {
  if (kIsWeb) return HelpPlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => HelpPlatform.ios,
    TargetPlatform.android => HelpPlatform.android,
    TargetPlatform.macOS => HelpPlatform.macos,
    TargetPlatform.windows => HelpPlatform.windows,
    _ => HelpPlatform.linux,
  };
}

/// Whether keys should be printed with ⌘ for [p]. The web follows the
/// keyboard of the machine the browser runs on.
bool helpUsesAppleKeys(HelpPlatform p) => switch (p) {
      HelpPlatform.macos || HelpPlatform.ios => true,
      HelpPlatform.web => defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.iOS,
      _ => false,
    };

// ── The key tables, as the page prints them ─────────────────────────

class HelpKeyRow {
  const HelpKeyRow(this.keys, this.labelKey);

  /// Every chord that does it, e.g. `[ · ⌘[`.
  final String keys;
  final String labelKey;

  String label(String locale) =>
      uiStrings[labelKey]?[locale] ?? uiStrings[labelKey]?['en'] ?? labelKey;
}

class HelpKeyGroup {
  const HelpKeyGroup(this.titleKey, this.rows);
  final String titleKey;
  final List<HelpKeyRow> rows;
}

/// Every key the app answers, grouped by where it works — read straight
/// from the tables the handlers dispatch from.
List<HelpKeyGroup> helpKeyGroups({required bool apple}) {
  final order = <String>[];
  final chords = <String, List<String>>{};
  for (final k in kReaderShortcuts) {
    if (!k.chord.shownOn(apple: apple)) continue;
    if (!chords.containsKey(k.labelKey)) order.add(k.labelKey);
    chords.putIfAbsent(k.labelKey, () => []).add(k.chord.label(mac: apple));
  }
  return [
    HelpKeyGroup('keysReader', [
      for (final l in order) HelpKeyRow(chords[l]!.join(' · '), l),
    ]),
    HelpKeyGroup('keysProjection', [
      for (final (_, keys, labelKey) in kProjectionKeymap)
        HelpKeyRow(
          {for (final k in keys) keyCapLabel(k)}.join(' · '),
          labelKey,
        ),
    ]),
  ];
}

/// The settings section a topic's path points into, so "Take me there"
/// lands on it rather than on the top of a long page.
SettingsSection? helpSettingsSectionFor(HelpTopic t) {
  const bySegment = <String, SettingsSection>{
    'settingsSectionAccount': SettingsSection.account,
    'settingsSectionDisplay': SettingsSection.display,
    'copyFormat': SettingsSection.display,
    'readingMode': SettingsSection.reading,
    'settingsSectionDashboard': SettingsSection.dashboardLayout,
    'settingsSectionNotifications': SettingsSection.notifications,
    'settingsSectionAi': SettingsSection.ai,
    'settingsSectionAbout': SettingsSection.about,
    'offlinePackTitle': SettingsSection.about,
    'clearCache': SettingsSection.about,
    'showTourAgain': SettingsSection.about,
  };
  for (final k in t.path.reversed) {
    final s = bySegment[k];
    if (s != null) return s;
  }
  return null;
}

/// Open [d] for [topic]. Exhaustive, so a destination the help names
/// cannot compile without somewhere to go. Pushed over the Help page, so
/// Back returns to it.
void openHelpDestination(HelpDestination d, HelpTopic topic) {
  switch (d) {
    case HelpDestination.settings:
      pushPage(SettingsPage(initialSection: helpSettingsSectionFor(topic)),
          routeName: '/settings');
    case HelpDestination.profiles:
      pushPage(const ProfilesPage(), routeName: '/profiles');
    case HelpDestination.about:
      pushPage(const AboutPage(), routeName: '/about');
    case HelpDestination.search:
      pushPage(const SearchPage());
    case HelpDestination.library:
      pushPage(const LibraryPage(), routeName: '/library');
    case HelpDestination.sermons:
      pushPage(const SermonsPage(), routeName: '/sermons');
    case HelpDestination.songs:
      pushPage(const SongsPage(), routeName: '/songs');
    case HelpDestination.videos:
      pushPage(const VideosPage(), routeName: '/videos');
    case HelpDestination.projection:
      pushPage(const ProjectionPage(), routeName: '/project');
    case HelpDestination.statistics:
      pushPage(const StatsPage(), routeName: '/stats');
    case HelpDestination.readingStats:
      pushPage(const ReadingStatsPage(), routeName: '/reading-stats');
    case HelpDestination.evidence:
      pushPage(const EvidencePage(), routeName: '/evidence');
    case HelpDestination.familyTree:
      pushPage(const FamilyTreePage(), routeName: '/family-tree');
    case HelpDestination.timeline:
      pushPage(const BibleTimelinePage(), routeName: '/timeline');
    case HelpDestination.trivia:
      pushPage(const BibleTriviaPage());
    case HelpDestination.misconceptions:
      pushPage(const MisconceptionsPage(), routeName: '/misconceptions');
    case HelpDestination.feedback:
      pushPage(const FeedbackPage(), routeName: '/feedback');
  }
}

// ── The page ────────────────────────────────────────────────────────

class HelpPage extends StatefulWidget {
  const HelpPage({super.key, this.initialSection, this.initialQuery});

  final HelpSection? initialSection;
  final String? initialQuery;

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  late final TextEditingController _query =
      TextEditingController(text: widget.initialQuery ?? '');
  final _sectionKeys = {for (final s in HelpSection.values) s: GlobalKey()};

  /// Topics opened while browsing, and topics closed while searching —
  /// the two views start from opposite defaults.
  final _expanded = <String>{};
  final _collapsed = <String>{};
  late HelpPlatform _platform = currentHelpPlatform();

  @override
  void initState() {
    super.initState();
    final s = widget.initialSection;
    if (s != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpTo(s));
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _jumpTo(HelpSection s) {
    final ctx = _sectionKeys[s]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 250), alignment: 0);
  }

  List<HelpTopic> get _topics =>
      [for (final t in kHelpTopics) if (t.appliesTo(_platform)) t];

  String _s(String key, String fallback, String locale) =>
      uiStrings[key]?[locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scale = settings.menuScale;
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final maxW = ResponsiveBreakpoints.settingsMaxWidth(
        ResponsiveBreakpoints.classOf(width));
    final query = _query.text.trim();

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(_s('helpTitle', 'Help & shortcuts', locale)),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _toolbar(scheme, locale, scale),
              Expanded(
                child: query.isEmpty
                    ? _browse(scheme, locale, scale)
                    : _results(scheme, locale, scale, query),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Toolbar: search + platform ────────────────────────────────────

  Widget _toolbar(ColorScheme scheme, String locale, double scale) {
    final touch = helpPlatformIsTouch(currentHelpPlatform());
    final here = currentHelpPlatform();
    String name(HelpPlatform p) {
      final n = kHelpPlatformNames[p]!.of(locale);
      return p == here
          ? '$n ${_s('helpThisDevice', '(this device)', locale)}'
          : n;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _query,
            // A keyboard on the desk means the reader came here to type;
            // on a phone an unasked-for keyboard covers half the page
            // they came to read.
            autofocus: !touch,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
                fontSize: 16 * scale, fontFamilyFallback: kCjkFontFallback),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              hintText: _s('helpSearchHint',
                  'Search features — e.g. font, split, highlight', locale),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: _s('close', 'Clear', locale),
                      onPressed: () => setState(_query.clear),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _s('helpPlatformLabel', 'Describe for:', locale),
                style: TextStyle(
                    fontSize: 13 * scale, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: PopupMenuButton<HelpPlatform>(
                  tooltip: _s('helpPlatformLabel', 'Describe for:', locale),
                  initialValue: _platform,
                  onSelected: (p) => setState(() => _platform = p),
                  itemBuilder: (_) => [
                    for (final p in HelpPlatform.values)
                      PopupMenuItem(value: p, child: Text(name(p))),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          name(_platform),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14 * scale,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: scheme.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Browsing ──────────────────────────────────────────────────────

  Widget _browse(ColorScheme scheme, String locale, double scale) {
    final topics = _topics;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in HelpSection.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(kHelpSectionNames[s]!.of(locale),
                        style: TextStyle(fontSize: 13 * scale)),
                    onPressed: () => _jumpTo(s),
                  ),
                ),
            ],
          ),
        ),
        for (final s in HelpSection.values) ...[
          _sectionHeading(scheme, locale, scale, s),
          if (s == HelpSection.shortcuts)
            ..._shortcuts(scheme, locale, scale)
          else
            for (final topic in topics.where((x) => x.section == s))
              _topicCard(scheme, locale, scale, topic,
                  expanded: _expanded.contains(topic.id),
                  onToggle: () => setState(() {
                        if (!_expanded.remove(topic.id)) {
                          _expanded.add(topic.id);
                        }
                      })),
        ],
      ],
    );
  }

  Widget _sectionHeading(
          ColorScheme scheme, String locale, double scale, HelpSection s) =>
      Padding(
        key: _sectionKeys[s],
        padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4),
        child: Text(
          kHelpSectionNames[s]!.of(locale),
          style: TextStyle(
            fontSize: 18 * scale,
            fontWeight: FontWeight.w700,
            color: scheme.primary,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
      );

  // ── One topic ─────────────────────────────────────────────────────

  Widget _topicCard(ColorScheme scheme, String locale, double scale,
      HelpTopic topic,
      {required bool expanded, required VoidCallback onToggle}) {
    final firstLine = topic.body.of(locale).split('\n').first;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic.title.of(locale),
                          style: TextStyle(
                            fontSize: 16 * scale,
                            fontWeight: FontWeight.w600,
                            fontFamilyFallback: kCjkFontFallback,
                          ),
                        ),
                        if (!expanded)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              firstLine,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13 * scale,
                                color: scheme.onSurfaceVariant,
                                fontFamilyFallback: kCjkFontFallback,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _topicBody(scheme, locale, scale, topic),
            ),
        ],
      ),
    );
  }

  Widget _topicBody(
      ColorScheme scheme, String locale, double scale, HelpTopic topic) {
    final prose = TextStyle(
      fontSize: 15 * scale,
      height: 1.6,
      color: scheme.onSurface,
      fontFamilyFallback: kCjkFontFallback,
    );
    final note = topic.notes[_platform];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topic.path.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${_s('helpWhere', 'Where', locale)}  ',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                TextSpan(
                  text: [
                    for (final k in topic.path) helpPathLabel(k, locale)
                  ].join(' › '),
                  style: TextStyle(
                      color: scheme.primary, fontWeight: FontWeight.w600),
                ),
              ]),
              style: TextStyle(
                  fontSize: 13 * scale, fontFamilyFallback: kCjkFontFallback),
            ),
          ),
        ..._paragraphs(topic.body.of(locale), prose),
        if (note != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${kHelpPlatformNames[_platform]!.of(locale)}　',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: note.of(locale)),
              ]),
              style: prose,
            ),
          ),
        if (topic.open != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.arrow_forward),
              label: Text(_s('helpTakeMeThere', 'Take me there', locale)),
              onPressed: () => openHelpDestination(topic.open!, topic),
            ),
          ),
      ],
    );
  }

  List<Widget> _paragraphs(String text, TextStyle style) {
    final out = <Widget>[];
    for (final para in text.split('\n\n')) {
      final lines = para.split('\n');
      if (lines.every((l) => l.startsWith('• '))) {
        for (final l in lines) {
          out.add(Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: style),
                Expanded(
                  child: SelectableText(l.substring(2),
                      style: style, scrollPhysics: kSelectableTextPhysics),
                ),
              ],
            ),
          ));
        }
        out.add(const SizedBox(height: 6));
      } else {
        // A paragraph whose later lines are bullets: the lead-in, then
        // the list.
        final lead = lines.takeWhile((l) => !l.startsWith('• ')).join('\n');
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: SelectableText(lead,
              style: style, scrollPhysics: kSelectableTextPhysics),
        ));
        final rest = lines.skipWhile((l) => !l.startsWith('• ')).toList();
        if (rest.isNotEmpty) out.addAll(_paragraphs(rest.join('\n'), style));
      }
    }
    return out;
  }

  // ── Gestures and keys ─────────────────────────────────────────────

  List<Widget> _shortcuts(ColorScheme scheme, String locale, double scale,
      {String? filter}) {
    final apple = helpUsesAppleKeys(_platform);
    final touch = helpPlatformIsTouch(_platform);
    final f = filter == null ? null : normalizeHelpQuery(filter);
    bool keep(String keys, Iterable<String> labels) {
      if (f == null) return true;
      final hay = [keys, ...labels].map(normalizeHelpQuery).join('\n');
      return f
          .split(RegExp(r'\s+'))
          .where((x) => x.isNotEmpty)
          .every(hay.contains);
    }

    final children = <Widget>[];
    final gestures = [
      for (final (g, e) in kHelpTouchGestures)
        if (keep('', [...g.all, ...e.all])) (g.of(locale), e.of(locale)),
    ];
    // Gestures lead on a touch platform; on a desk they follow the keys,
    // because a touch-screen laptop and a phone's browser both exist.
    Widget touchGroup() =>
        _keyGroup(scheme, locale, scale, 'keysTouch', gestures, cap: false);
    if (touch && gestures.isNotEmpty) {
      children.add(touchGroup());
      if (f == null) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            _s('helpTouchKeyboardNote',
                'With a keyboard attached, the keys below work too.', locale),
            style: TextStyle(
                fontSize: 13 * scale, color: scheme.onSurfaceVariant),
          ),
        ));
      }
    }
    for (final g in helpKeyGroups(apple: apple)) {
      final rows = [
        for (final r in g.rows)
          if (keep(r.keys, uiStrings[r.labelKey]?.values ?? const []))
            (r.keys, r.label(locale)),
      ];
      if (rows.isEmpty) continue;
      children.add(_keyGroup(scheme, locale, scale, g.titleKey, rows));
    }
    if (!touch && gestures.isNotEmpty) children.add(touchGroup());
    return children;
  }

  Widget _keyGroup(ColorScheme scheme, String locale, double scale,
      String titleKey, List<(String, String)> rows,
      {bool cap = true}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kHelpKeyGroupTitles[titleKey]?.of(locale) ?? titleKey,
              style: TextStyle(
                fontSize: 15 * scale,
                fontWeight: FontWeight.w700,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
            const SizedBox(height: 6),
            for (final (keys, what) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: (cap ? 132 : 150) * scale,
                      child: cap
                          ? Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                for (final k in keys.split(' · '))
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: scheme.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: scheme.outlineVariant),
                                    ),
                                    child: Text(
                                      k,
                                      style: TextStyle(
                                        fontSize: 13 * scale,
                                        fontWeight: FontWeight.w600,
                                        fontFamilyFallback: kCjkFontFallback,
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : Text(
                              keys,
                              style: TextStyle(
                                fontSize: 14 * scale,
                                fontWeight: FontWeight.w600,
                                fontFamilyFallback: kCjkFontFallback,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        what,
                        style: TextStyle(
                          fontSize: 14 * scale,
                          fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Search results ────────────────────────────────────────────────

  Widget _results(
      ColorScheme scheme, String locale, double scale, String query) {
    final hits = searchHelp(query, _topics);
    final keys = _shortcuts(scheme, locale, scale, filter: query);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            hits.isEmpty && keys.isEmpty
                ? _s(
                    'helpNoResults',
                    'Nothing found. Try other words, or switch the platform '
                        'above.',
                    locale)
                : _s('helpResultCount', '{n} found', locale)
                    .replaceAll('{n}', '${hits.length}'),
            style: TextStyle(
                fontSize: 13 * scale, color: scheme.onSurfaceVariant),
          ),
        ),
        for (final h in hits)
          _topicCard(scheme, locale, scale, h.topic,
              // Results open expanded: the reader asked a question, and a
              // list of titles is not an answer.
              expanded: !_collapsed.contains(h.topic.id),
              onToggle: () => setState(() {
                    if (!_collapsed.remove(h.topic.id)) {
                      _collapsed.add(h.topic.id);
                    }
                  })),
        if (keys.isNotEmpty) ...[
          _sectionHeading(scheme, locale, scale, HelpSection.shortcuts),
          ...keys,
        ],
      ],
    );
  }
}
