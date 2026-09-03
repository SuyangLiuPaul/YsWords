import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/chronology.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/version_mapper.dart' show localeAwareBookName;

/// The interactive chronology chart — the "lifelines" view of the Bible
/// Timeline page.
///
/// **What this is a view of, and why it is not a second timeline page.**
/// `BibleTimelinePage`'s event list answers "what happened, in order".
/// It cannot answer "who was alive at the same time", because a list of
/// points has no duration in it. That overlap question is the whole
/// point of the reference sheet the user pointed at
/// (`docs/reference/364673272-…`, Adams' *World History Chart*): parallel
/// lifelines, coloured by descent, so contemporaneity is visible at a
/// glance. So this ships as a second VIEW on the same page rather than a
/// prettier rival to it.
///
/// **What is deliberately NOT copied from the reference.** That sheet is
/// under copyright (Bible Charts and Maps, LLC, 2012). Nothing here is
/// traced or transcribed from it: the layout is a plain left-to-right
/// lifeline chart, not its spiral, and every number comes from
/// `assets/bible_chronology.json`, which is computed from the Masoretic
/// ages in Genesis 5 and 11 and cross-checked against our own
/// `assets/family_tree.json`.
///
/// **Honesty about the dates.** The bars are laid out in Anno Mundi —
/// years since Creation — because intervals are what Genesis 5 and 11
/// actually state. The BC labels need an anchor, and the anchor is the
/// contested part; the scheme banner at the top says which one is in
/// use and opens a sheet naming the Septuagint and Samaritan
/// alternatives. It is never presented as settled.
///
/// **Layout.** A fixed name column plus a plot area that scrolls
/// horizontally in ITS OWN container when zoomed — the page never
/// scrolls sideways. At zoom 1 the whole span fits the available width,
/// which is the phone default.
class ChronologyChart extends StatefulWidget {
  final ChronologyData data;
  final String locale;

  /// Tapping a verse chip in the detail sheet. Supplied by the host page
  /// so the chart does not own navigation.
  final void Function(String raw)? onTapRef;

  const ChronologyChart({
    super.key,
    required this.data,
    required this.locale,
    this.onTapRef,
  });

  @override
  State<ChronologyChart> createState() => _ChronologyChartState();
}

class _ChronologyChartState extends State<ChronologyChart> {
  static const double _nameColumnMin = 64;
  static const double _gap = 8;

  static const double _nameFontSize = 11;
  static const double _labelFontSize = 8.5;
  static const double _foldFontSize = 9.5;
  static const double _rulerFontSize = 9;
  static const double _eraFontSize = 8.5;

  /// A folded run of lifeline rows: 8 pt of padding plus 1.8 pt per bar
  /// it stands in for, so the band's HEIGHT still reports how many rows
  /// were folded even before the label is read. The floor is a line of
  /// its own label, so a reader at large system text still gets a band
  /// that can print "{n} not in view" — the one control that unfolds it.
  double _foldHeight(int n) {
    final floor = (_scaler.scale(_foldFontSize) * 1.55).clamp(16.0, 40.0);
    return (8 + n * 1.8).clamp(floor, floor + 30);
  }

  // ── Zoom, in pixels per year ────────────────────────────────────
  //
  // **The bare multiplier was the wrong unit.** "8×" meant eight times
  // the whole span fitted to the plot, so what it delivered depended
  // entirely on how wide the plot was: on a 1280 pt desktop 8× is about
  // 2.2 pt per year, on a 390 pt phone about 0.5 — four times less. The
  // same number read fine in the desktop captures and was unusable on
  // the reader's iPhone, which is exactly what they reported.
  //
  // So zoom is now a DENSITY: pixels per year. A level shows the same
  // amount of time per centimetre of glass on every device, the plot is
  // the same number of points wide everywhere, and a bigger screen
  // simply holds more of it at once — which is what a bigger screen is
  // for. The axis is still never warped; this only changes the scale it
  // is drawn at.
  //
  // The ladder doubles, so a level is always "twice as close as the one
  // below". Level 0 is not on it: it is fit-to-width, which is the one
  // density that must stay device-dependent because the overview strip
  // and the whole-span view are defined by it.
  static const List<double> _densityLadder = [
    0.0625, 0.125, 0.25, 0.5, 1, 2, _maxDensity,
  ];

  /// **Derived, not chosen.** 4 pt per year is where more density stops
  /// buying legible labels.
  ///
  /// Measured over all 100 ticks of `assets/bible_chronology.json` by
  /// replaying this file's own label packer at five rows and counting
  /// the labels that come out COMPLETE — no ellipsis — at real font
  /// advances:
  ///
  ///     pt/yr   1    2    3    4    6    8   12   16   32
  ///     en     64   79   85   87   88   88   91   93   96
  ///     zh     74   87   88   88   91   93   94   94   96
  ///
  /// Past 4 the curve is flat: each further DOUBLING of the scroll
  /// extent buys one to three labels out of a hundred. It flattens
  /// because what is left is not a density limit at all — six events
  /// share AM 4036 (Triumphal Entry through Pentecost) and fourteen fall
  /// in the ten years around it, so they stack into label rows and the
  /// lane has five. No amount of zoom separates marks at the same x.
  ///
  /// At 4 pt/yr the plot is 16,392 pt wide on every device. On a 390 pt
  /// phone that is roughly 65× the old multiplier and about 60 years in
  /// the viewport; on a 1280 pt desktop the same level is 14× and 285
  /// years — the same picture, more of it.
  static const double _maxDensity = 4;

  /// What the DEFAULT level aims to hold: about half a millennium.
  ///
  /// Opening at whole-span was the second complaint. Whole span on a
  /// phone is 0.06 pt per year — every label the lane draws is a pinned
  /// one and the rest of the chart is texture. The default is now the
  /// closest level that holds no more than this many years, which lands
  /// on ~500 years on a phone, ~700 on a tablet and ~570 on a desktop:
  /// the same reading, not the same number. Whole span is still one tap
  /// of Zoom out away, and the overview strip above the plot shows it
  /// permanently, so nothing about the axis is hidden by opening inside
  /// it.
  static const double _defaultWindowYears = 800;

  final ScrollController _plot = ScrollController();

  /// The scrubbed year, in AM. Defaults to the Flood — a year that
  /// immediately demonstrates what the chart is for, since Methuselah's
  /// bar ends exactly on it.
  late int _cursorAm;

  /// Pixels per year, or null for fit-to-width — the whole span, no
  /// horizontal scrolling. Null until the first layout, which is where
  /// the default is picked, because the default depends on how wide the
  /// viewport turned out to be.
  double? _density;
  bool _zoomChosen = false;

  /// Last plot width laid out, so the overview strip can convert the
  /// scroll offset into an AM range without re-deriving the layout.
  double _plotWidth = 0;

  /// Which lifeline rows earned a full row on the LAST build, parallel
  /// to `data.lifelines`. Two jobs: it is the `previous` state the
  /// hysteresis in [chronologyRowsInView] needs, and it is what the
  /// scroll listener compares against so the chart rebuilds ~20 times
  /// over a full scroll rather than once per frame — the tick lane
  /// measures every label it draws, and doing that at 60 Hz for no
  /// change would be paid for by the reader.
  List<bool>? _rowsInView;

  @override
  void initState() {
    super.initState();
    _plot.addListener(_onPlotScroll);
    // Default the scrub cursor to the Flood: Methuselah's bar ends
    // exactly there, so the view opens already demonstrating what it is
    // for instead of needing to be discovered.
    var start = widget.data.spanStartAm;
    for (final m in widget.data.markers) {
      if (m.id == 'flood') {
        start = m.am;
        break;
      }
    }
    _cursorAm = start;
  }

  @override
  void dispose() {
    _plot.removeListener(_onPlotScroll);
    _plot.dispose();
    super.dispose();
  }

  /// The plan for the CURRENT scroll offset, fed the last one so the
  /// hysteresis has something to hold onto. Before the plot has been
  /// laid out — and at zoom 1, where the viewport IS the whole span —
  /// every row is in view, which is why the default view is untouched
  /// by any of this.
  List<bool> _planFor(List<bool>? previous) {
    final data = widget.data;
    if (!_plot.hasClients ||
        _plotWidth <= 0 ||
        !_plot.position.hasPixels ||
        !_plot.position.hasViewportDimension) {
      return List<bool>.filled(data.lifelines.length, true);
    }
    final px = _plot.position.pixels;
    final vp = _plot.position.viewportDimension;
    return chronologyRowsInView(
      lifelines: data.lifelines,
      spanStartAm: data.spanStartAm,
      spanEndAm: data.spanEndAm,
      viewStartFrac: px / _plotWidth,
      viewEndFrac: (px + vp) / _plotWidth,
      previous: previous,
    );
  }

  /// Rebuild only when the SET of rows in view changes, never per scroll
  /// frame. A scroll notification can arrive while the tree is already
  /// building (a viewport correction during layout), so a change found
  /// in that phase is deferred to the next frame instead of calling
  /// `setState` inside a build.
  void _onPlotScroll() {
    final next = _planFor(_rowsInView);
    final now = _rowsInView;
    if (now != null && listEquals(next, now)) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  bool get _isZh => widget.locale.startsWith('zh');

  /// Bring [am] into view, centred where it can be. Chips used to move
  /// only the cursor, which is why "jump to Revelation" did not look
  /// like it went anywhere once the span reached that far.
  void _scrollTo(int am, {bool animate = true}) {
    if (!_plot.hasClients || _plotWidth <= 0) return;
    final data = widget.data;
    final span = (data.spanEndAm - data.spanStartAm).abs();
    if (span == 0) return;
    final x = (am - data.spanStartAm) / span * _plotWidth;
    final target = (x - _plot.position.viewportDimension / 2)
        .clamp(0.0, _plot.position.maxScrollExtent);
    if (!animate) {
      _plot.jumpTo(target);
      return;
    }
    _plot.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  // ── Text metrics ────────────────────────────────────────────────
  //
  // **Every measurement in this file used to be against the wrong
  // font.** A bare `TextStyle(fontSize: 8.5)` handed to a `TextPainter`
  // inherits nothing: no family, no scale. The `Text` widgets beside it
  // are merged into `DefaultTextStyle`, which carries the reader's
  // chosen `settings.fontFamily` and its CJK fallback chain, and are
  // laid out through `MediaQuery.textScalerOf`. So the packer measured
  // one font and the chart drew a wider one, and every label it thought
  // fitted came out ellipsised — which is what the reader photographed.
  // Measured on their capture: "Alexander the Great Conquers Persia" was
  // given 159 pt of room for a string the packer sized at 142 and the
  // engine drew at about 155.
  //
  // So: resolve against the ambient style, and measure through the
  // scaler, everywhere. [_resolve] is what makes a measurement mean the
  // same thing as the drawing.

  TextStyle _resolve(TextStyle style) =>
      DefaultTextStyle.of(context).style.merge(style);

  TextScaler get _scaler => MediaQuery.textScalerOf(context);

  double _measure(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: _resolve(style)),
      maxLines: 1,
      textScaler: _scaler,
      textDirection: Directionality.of(context),
    )..layout();
    return tp.width;
  }

  /// One line's height at [fontSize], after the reader's text scale.
  /// Every lane pitch in this file is derived from it rather than
  /// hard-coded, because a reader at 150% text would otherwise have
  /// 12.75 pt of glyph in a 12 pt row.
  double _lineHeight(double fontSize) => _scaler.scale(fontSize) * 1.4;

  double get _rowHeight =>
      (_scaler.scale(_nameFontSize) * 2.3).clamp(26.0, 96.0);

  double get _labelRowPitch => _lineHeight(_labelFontSize).clamp(12.0, 40.0);

  /// The ruler stacks AM over BC/AD, so it needs two lines of its own
  /// font — 30 pt at 100% text, more at 130%, where two 9 pt lines are
  /// 33 and used to be clipped by the lane below.
  double get _rulerHeight =>
      (4 + _lineHeight(_rulerFontSize) * 2).clamp(30.0, 90.0);
  double get _rulerSecondLineTop => 2 + _lineHeight(_rulerFontSize);
  double get _eraStripHeight =>
      (_lineHeight(_eraFontSize) + 3).clamp(15.0, 44.0);

  /// The event lane's floor and ceiling: one label row and five.
  ///
  /// Five is where a leader line stops being believable — below that a
  /// label is too far from its own tick — so the rest of any height the
  /// folded lifeline rows give back is simply not taken, and the chart
  /// gets shorter instead. On a phone that is the whole point.
  double get _tickLaneHeight => 13 + _labelRowPitch + 7;
  double get _tickLaneMaxHeight => 13 + _labelRowPitch * 5 + 7;

  /// The name column earns its width instead of being told it.
  ///
  /// It was a flat 88 pt, which is 7 pt short of "Nahor (the elder)" in
  /// the app's own font and 10 short of 拿鹤(亚伯拉罕祖父) — so the one
  /// person on the chart who needs a disambiguating parenthetical was
  /// the one person whose name ended in an ellipsis. The column is now
  /// as wide as the widest thing it has to print, capped at a third of
  /// the chart so a long name can never eat the plot; past the cap the
  /// name wraps to a second line rather than being cut.
  double _nameColumnWidth(double content) {
    var widest = 0.0;
    for (final l in widget.data.lifelines) {
      final w = _measure(l.localizedName(widget.locale),
          const TextStyle(fontSize: _nameFontSize, fontWeight: FontWeight.w700));
      if (w > widest) widest = w;
    }
    // The captions and the fold band live in this column too, and a
    // column too narrow for "{n} not in view" would hide the one control
    // that gets a folded row back.
    for (final s in [
      _s('chronologyEras', 'Eras'),
      _s('chronologyEvents', 'Events'),
    ]) {
      final w = _measure(s, const TextStyle(fontSize: 9, fontWeight: FontWeight.w800));
      if (w > widest) widest = w;
    }
    final fold = _measure(
      _s('chronologyRowsFolded', '{n} not in view').replaceAll('{n}', '20'),
      const TextStyle(fontSize: _foldFontSize, fontWeight: FontWeight.w600),
    );
    if (fold > widest) widest = fold;
    final cap = (content * 0.34).clamp(_nameColumnMin, 168.0);
    return (widest + 4).clamp(_nameColumnMin, cap);
  }

  void _goTo(int am) {
    setState(() => _cursorAm = am);
    _scrollTo(am);
  }

  // ── The zoom ladder ─────────────────────────────────────────────

  int get _span => (widget.data.spanEndAm - widget.data.spanStartAm).abs();

  /// Fit-to-width, in pixels per year: the density at which the whole
  /// span is exactly the viewport. Every rung of the ladder at or below
  /// it is unreachable on this device, because zooming out past it would
  /// leave the plot narrower than the box it lives in.
  double _fitDensity(double viewport) =>
      _span == 0 ? 0 : viewport / _span;

  /// The rungs this device actually has, coarsest first. A phone gets
  /// all seven; a desktop's fit is already denser than the first four,
  /// so it gets three — which is right, since it starts closer to
  /// readable and has less distance to travel.
  List<double> _rungs(double viewport) {
    final fit = _fitDensity(viewport);
    return [for (final d in _densityLadder) if (d > fit * 1.02) d];
  }

  /// Where the chart opens: the coarsest rung holding no more than
  /// [_defaultWindowYears].
  double _defaultDensity(double viewport) {
    final rungs = _rungs(viewport);
    for (final d in rungs) {
      if (viewport / d <= _defaultWindowYears) return d;
    }
    return rungs.isEmpty ? _fitDensity(viewport) : rungs.last;
  }

  bool get _atFit => _density == null;

  bool _canZoomIn(double viewport) {
    final rungs = _rungs(viewport);
    if (rungs.isEmpty) return false;
    return _density == null || _density! < rungs.last - 1e-9;
  }

  bool _canZoomOut() => _density != null;

  void _zoomIn(double viewport) {
    final rungs = _rungs(viewport);
    if (rungs.isEmpty) return;
    for (final d in rungs) {
      if (_density == null || d > _density! + 1e-9) {
        _stepTo(d);
        return;
      }
    }
  }

  void _zoomOut(double viewport) {
    final rungs = _rungs(viewport);
    double? next;
    for (final d in rungs) {
      if (_density != null && d < _density! - 1e-9) next = d;
    }
    _stepTo(next);
  }

  /// Change the scale and keep the cursor where it is on screen. Without
  /// this a zoom throws the reader somewhere else on a 16,000 pt plot,
  /// which is how a zoom control stops being usable.
  void _stepTo(double? density) {
    setState(() {
      _density = density;
      _zoomChosen = true;
    });
    if (density != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollTo(_cursorAm, animate: false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = widget.data;
    final active = data.activeScheme;
    final alive = data.aliveAt(_cursorAm);

    return LayoutBuilder(
      builder: (context, outer) {
        // The ListView's own horizontal padding, taken off once here so
        // the zoom row and the plot agree about how wide the chart is.
        final content = (outer.maxWidth - 32).clamp(120.0, double.infinity);
        final nameColumn = _nameColumnWidth(content);
        final viewport =
            (content - nameColumn - _gap).clamp(80.0, double.infinity);

        // The default is picked at the FIRST layout, not in initState,
        // because it depends on the viewport it will be shown in.
        if (!_zoomChosen) {
          _zoomChosen = true;
          _density = _defaultDensity(viewport);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollTo(_cursorAm, animate: false);
          });
        }

        // A rotation or a window resize can leave the chosen rung below
        // the new fit-to-width. That IS the whole-span view, so record
        // it as one: otherwise the readout would report a window wider
        // than the axis and Zoom out would look enabled with nowhere to
        // go. Assigning here rather than in a callback is deliberate —
        // it is a normalisation of layout input, used in this same
        // build, not a state change the reader made.
        if (_density != null && _density! <= _fitDensity(viewport)) {
          _density = null;
        }

        // The plot never gets a width smaller than the viewport, so
        // fit-to-width never introduces a sideways scroll.
        final plotWidth = _density == null
            ? viewport
            : (_density! * _span).clamp(viewport, double.infinity);
        _plotWidth = plotWidth;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _schemeBanner(context, active, scheme),
            const SizedBox(height: 12),
            _scrubber(context, active, scheme, alive.length),
            _zoomRow(scheme, viewport),
            const SizedBox(height: 8),
            // Overview first, then zoom and filter, then details on
            // demand. With 4,100 years on the axis a zoom button alone
            // leaves the reader with no idea where the viewport is, so
            // the whole span stays on screen above the plot with the
            // viewport marked on it.
            _overview(context, scheme, active),
            const SizedBox(height: 10),
            _chart(context, scheme, active, plotWidth, nameColumn),
            const SizedBox(height: 16),
            // Below the chart, not above it: the chips wrap to several
            // rows on a phone, and putting them before the plot pushed
            // the thing the reader came for off the first screen.
            Text(
              _s('chronologyJumpTo', 'Jump to'),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4),
            ),
            const SizedBox(height: 6),
            _markerChips(scheme),
            const SizedBox(height: 16),
            _legend(context, scheme),
            const SizedBox(height: 12),
            _scopeNote(scheme),
          ],
        );
      },
    );
  }

  // ── Scheme banner ───────────────────────────────────────────────
  //
  // Top of the view, not a footnote. A chronology chart that does not
  // say whose chronology it is invites exactly the "reads plausibly and
  // is wrong and gets quoted" failure.
  Widget _schemeBanner(
    BuildContext context,
    ChronologyScheme active,
    ColorScheme scheme,
  ) {
    final isZh = widget.locale.startsWith('zh');
    final creation = isZh
        ? '公元前 ${active.creationBc} 年'
        : '${active.creationBc} BC';
    final line = _s('chronologySchemeBanner', 'Dated by {scheme} · '
            'Creation = {creation}')
        .replaceAll('{scheme}', active.localizedName(widget.locale))
        .replaceAll('{creation}', creation);
    return Material(
      color: scheme.tertiaryContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showSchemeSheet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              Icon(Icons.balance_rounded,
                  size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  line,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.info_outline_rounded,
                  size: 16, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  void _showSchemeSheet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      // The cap goes on the SHEET and its direct child is a Padding, so
      // the one scroll view inside is the sheet's own — see
      // `test/nested_scrollable_test.dart` for why a scroll view
      // directly under a height cap is a bug.
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _s('chronologyWhoseChronology',
                      'Whose chronology is this?'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final s in widget.data.schemes) ...[
                        Row(
                          children: [
                            Icon(
                              s.supported
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 15,
                              color: s.supported
                                  ? scheme.primary
                                  : scheme.onSurface
                                      .withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s.localizedName(widget.locale),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (!s.supported)
                              Text(
                                _s('chronologyNotPlotted', 'not plotted'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.localizedNote(widget.locale),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color:
                                scheme.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Year scrubber ───────────────────────────────────────────────

  Widget _scrubber(
    BuildContext context,
    ChronologyScheme active,
    ColorScheme scheme,
    int aliveCount,
  ) {
    final data = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                formatChronologyYear(_cursorAm, active, widget.locale),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            // Past the computed stretch there are no bars, and "0 alive"
            // would read as a claim that nobody was. Say instead that
            // the chart has nothing to draw there.
            Text(
              _cursorAm > data.computedEndAm
                  ? _s('chronologyNoLifelines', 'no lifelines here')
                  : _s('chronologyAliveCount', '{count} alive')
                      .replaceAll('{count}', '$aliveCount'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _cursorAm > data.computedEndAm
                    ? scheme.onSurface.withValues(alpha: 0.55)
                    : scheme.primary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: _cursorAm.toDouble().clamp(
                  data.spanStartAm.toDouble(),
                  data.spanEndAm.toDouble(),
                ),
            min: data.spanStartAm.toDouble(),
            max: data.spanEndAm.toDouble(),
            label: '$_cursorAm',
            onChanged: (v) => setState(() => _cursorAm = v.round()),
          ),
        ),
      ],
    );
  }

  /// Dated events, as chips that move the scrubber AND scroll the plot
  /// to them. Only the pinned ones: 100 chips is not a control. The
  /// rest are reached by tapping their tick, which is the "details on
  /// demand" end of the same interaction.
  ///
  /// The computed markers are marked with a filled glyph and the placed
  /// events with a hollow one — the same distinction the ticks make, so
  /// a reader who learned it in one place reads it in the other.
  Widget _markerChips(ColorScheme scheme) {
    final chips = [
      ...widget.data.markers,
      ...widget.data.events.where((e) => e.pin),
    ]..sort((a, b) => a.am.compareTo(b.am));
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in chips)
          _Chip(
            // Stable handle for tests and for anything that needs to
            // point at one chip: the tick lane prints some of the same
            // titles, so text alone is ambiguous.
            key: ValueKey('chronoChip_${m.id}'),
            label: m.localizedTitle(widget.locale),
            selected: m.am == _cursorAm,
            computed: m.isComputed,
            scheme: scheme,
            onTap: () => _goTo(m.am),
          ),
      ],
    );
  }

  /// A round number for a readout, not a measurement: 4,016 reads as
  /// 4,000 and 63 reads as 63.
  int _round(double years) {
    if (years >= 1000) return (years / 100).round() * 100;
    if (years >= 100) return (years / 10).round() * 10;
    return years.round().clamp(1, 1 << 30);
  }

  /// **What the control says.**
  ///
  /// Not a multiplier: the multiplier is what lied — 8× meant something
  /// different on every device, which is the whole reason this pass
  /// exists — and a computed multiplier would print "1×" for two
  /// different levels on a wide screen. Not a named bucket either ("a
  /// century", "a generation"): at a fixed density a phone and an iPad
  /// genuinely do NOT hold the same century, so the name would be wrong
  /// on one of them.
  ///
  /// Years in view is the one statement that is true on every device,
  /// and it is exactly the quantity the reader is choosing. It changes
  /// when the device rotates, because the answer really does change.
  String _zoomLabel(double viewport) {
    if (_atFit) return _s('chronologyOverview', 'Whole span');
    return _s('chronologyYearsInView', '≈ {n} years in view')
        .replaceAll('{n}', '${_round(viewport / _density!)}');
  }

  Widget _zoomRow(ColorScheme scheme, double viewport) {
    return Row(
      children: [
        Text(
          _s('chronologyZoom', 'Zoom'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          tooltip: _s('chronologyZoomOut', 'Zoom out'),
          onPressed: _canZoomOut() ? () => _zoomOut(viewport) : null,
          icon: const Icon(Icons.zoom_out_rounded),
        ),
        Expanded(
          child: Text(
            _zoomLabel(viewport),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          tooltip: _s('chronologyZoomIn', 'Zoom in'),
          onPressed: _canZoomIn(viewport) ? () => _zoomIn(viewport) : null,
          icon: const Icon(Icons.zoom_in_rounded),
        ),
      ],
    );
  }

  // ── Overview strip ──────────────────────────────────────────────
  //
  // Shneiderman's order, applied literally: overview first (this),
  // zoom and filter (the zoom row and the scrub cursor), details on
  // demand (the sheets). It is deliberately the SAME vocabulary as the
  // plot below — same era bands, same computed/placed grounds, same
  // cursor — at 1/zoom scale, plus an outlined rectangle showing which
  // slice of it the plot is currently showing. Tapping or dragging it
  // moves both the cursor and the plot.
  Widget _overview(
    BuildContext context,
    ColorScheme scheme,
    ChronologyScheme active,
  ) {
    final data = widget.data;
    final span = (data.spanEndAm - data.spanStartAm).abs();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _s('chronologyOverview', 'Whole span'),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            void handle(Offset local) {
              if (span == 0 || w <= 0) return;
              final am = (data.spanStartAm +
                      (local.dx / w).clamp(0.0, 1.0) * span)
                  .round();
              _goTo(am);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => handle(d.localPosition),
              onHorizontalDragUpdate: (d) => handle(d.localPosition),
              child: ListenableBuilder(
                listenable: _plot,
                builder: (context, _) {
                  double? viewStart;
                  double? viewEnd;
                  if (_plot.hasClients && _plotWidth > 0) {
                    final vp = _plot.position.viewportDimension;
                    viewStart = _plot.position.pixels / _plotWidth;
                    viewEnd = (_plot.position.pixels + vp) / _plotWidth;
                  }
                  return SizedBox(
                    height: 40,
                    child: CustomPaint(
                      painter: _OverviewPainter(
                        data: data,
                        cursorAm: _cursorAm,
                        viewStartFrac: viewStart,
                        viewEndFrac: viewEnd,
                        brightness: Theme.of(context).brightness,
                        scheme: scheme,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 3),
        // The two ends of the axis, printed under the ends they belong
        // to. This is the answer to the complaint that started this
        // pass, in words as well as in the drawing: the axis really
        // does run from Creation to Revelation.
        Row(
          children: [
            Expanded(
              child: Text(
                formatChronologyYear(
                    data.spanStartAm, active, widget.locale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                formatChronologyYear(data.spanEndAm, active, widget.locale),
                maxLines: 1,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── The chart itself ────────────────────────────────────────────

  Widget _chart(
    BuildContext context,
    ColorScheme scheme,
    ChronologyScheme active,
    double plotWidth,
    double nameColumn,
  ) {
    final data = widget.data;
    final rows = data.lifelines;
    final lanesTop = _rulerHeight + _eraStripHeight;
    final step = _rulerStep(plotWidth);

    // Rows earn their height from the viewport. Assigning the result
    // back is a cache for the scroll listener and for the hysteresis,
    // not layout state: `_planFor` is a pure function of the scroll
    // offset and the plan it is handed, so building twice in a row
    // yields the same answer.
    final inView = _planFor(_rowsInView);
    _rowsInView = inView;

    // Consecutive out-of-view rows fuse into ONE band, in place. Order
    // is never disturbed, so a folded run sits exactly where its rows
    // were and the reader can see how far down the column they are.
    final slots = <_Slot>[];
    for (var i = 0; i < rows.length; i++) {
      if (inView[i]) {
        slots.add(_Slot.row(rows[i]));
      } else if (slots.isNotEmpty && slots.last.folded) {
        slots.last.lines.add(rows[i]);
      } else {
        slots.add(_Slot.fold(rows[i]));
      }
    }
    double slotHeight(_Slot s) =>
        s.folded ? _foldHeight(s.lines.length) : _rowHeight;
    final rowsHeight = slots.fold<double>(0, (a, s) => a + slotHeight(s));

    // The reclaimed height goes to the layer that HAS content out
    // there. Past AM 2187 the event lane was one row tall under twenty
    // empty ones; now it is the tall layer and the lifelines are the
    // thin one, which is the true shape of the data in that stretch.
    final tickLane = (_tickLaneHeight + rows.length * _rowHeight - rowsHeight)
        .clamp(_tickLaneHeight, _tickLaneMaxHeight);
    final height = lanesTop + rowsHeight + tickLane;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed name column — stays put while the plot scrolls, so a
          // zoomed-in bar is never anonymous.
          SizedBox(
            width: nameColumn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: lanesTop,
                  child: Align(
                    alignment: AlignmentDirectional.bottomEnd,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 2, bottom: 2),
                      child: Text(
                        _s('chronologyEras', 'Eras'),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
                for (final s in slots)
                  SizedBox(
                    height: slotHeight(s),
                    child: s.folded
                        ? _foldNameCell(context, s, scheme)
                        : _nameCell(context, s.lines.first, scheme),
                  ),
                SizedBox(
                  height: tickLane,
                  child: Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 2, top: 3),
                      child: Text(
                        _s('chronologyEvents', 'Events'),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            // The ONLY horizontally scrolling thing on the page.
            child: SingleChildScrollView(
              controller: _plot,
              scrollDirection: Axis.horizontal,
              physics: _atFit
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              child: SizedBox(
                width: plotWidth,
                height: height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GroundPainter(
                          data: data,
                          rulerHeight: _rulerHeight,
                          eraStripHeight: _eraStripHeight,
                          tickLaneHeight: tickLane,
                          gridStep: step,
                          brightness: Theme.of(context).brightness,
                          scheme: scheme,
                          boundaryLabel: _s('chronologyComputedEnds',
                              'Genesis 5 & 11 ages end here'),
                          contestedLabel: _s('chronologyContestedLabel',
                              'The two scales disagree here'),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: _rulerHeight,
                          child: _ruler(active, scheme, plotWidth, step),
                        ),
                        SizedBox(
                          height: _eraStripHeight,
                          child: _eraStrip(scheme, plotWidth),
                        ),
                        for (final s in slots)
                          SizedBox(
                            height: slotHeight(s),
                            child: s.folded
                                ? _foldLane(context, s, scheme)
                                : _lane(
                                    context, s.lines.first, scheme, plotWidth),
                          ),
                        SizedBox(
                          height: tickLane,
                          child: _tickLane(
                              context, scheme, plotWidth, tickLane),
                        ),
                      ],
                    ),
                    // Scrub cursor, drawn over everything.
                    Positioned(
                      left: _x(_cursorAm, plotWidth) - 1,
                      top: 0,
                      bottom: 0,
                      width: 2,
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: scheme.primary.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _x(int am, double plotWidth) {
    final data = widget.data;
    final span = (data.spanEndAm - data.spanStartAm).abs();
    if (span == 0) return 0;
    return (am - data.spanStartAm) / span * plotWidth;
  }

  /// Ruler/grid interval, chosen from a round-number ladder so the
  /// labels never collide however wide the plot is. The old code hard-
  /// coded 500 (and 200 above zoom 3), which was legible across 2,187
  /// years and is not across 4,098: at whole span on a 402 pt phone the
  /// plot is about 290 pt wide, and 500-year labels would sit 35 pt
  /// apart with 46 pt of text in them.
  ///
  /// The ladder gained a fine end (10, 20, 25) with the density pass:
  /// at 4 pt per year a 50-year step is 200 pt, which on a phone is one
  /// ruler label in the viewport at a time. The rungs are affordable
  /// because [_ruler] only builds what the window holds.
  int _rulerStep(double plotWidth) {
    const ladder = [10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000];
    final span = (widget.data.spanEndAm - widget.data.spanStartAm).abs();
    if (span == 0 || plotWidth <= 0) return ladder.last;
    // Measured, not guessed. A hard-coded pixel budget was wrong twice:
    // the app's own font is wider than the estimate, so "AM 3000" and
    // the pinned "AM 4098" still overlapped at 402 pt after the budget
    // was raised once. `_labelWidth` asks the text engine instead.
    final need = _rulerLabelWidth() + 14;
    for (final s in ladder) {
      if (s / span * plotWidth >= need) return s;
    }
    return ladder.last;
  }

  static const TextStyle _rulerAmStyle =
      TextStyle(fontSize: _rulerFontSize, fontWeight: FontWeight.w700);
  static const TextStyle _rulerYearStyle =
      TextStyle(fontSize: _rulerFontSize);

  /// Width of the widest label the ruler will ever print — both of its
  /// two lines, at the far end of the axis where the digits are longest.
  double _rulerLabelWidth() {
    final end = widget.data.spanEndAm;
    final start = widget.data.spanStartAm;
    final active = widget.data.activeScheme;
    String yearText(int am) {
      final y = active.amToYear(am);
      return y < 0 ? '${-y} BC' : 'AD $y';
    }

    return [
      _measure('AM $end', _rulerAmStyle),
      _measure('AM $start', _rulerAmStyle),
      _measure(yearText(start), _rulerYearStyle),
      _measure(yearText(end), _rulerYearStyle),
    ].reduce((a, b) => a > b ? a : b);
  }

  /// The ruler builds only the labels the reader can SEE.
  ///
  /// At the deepest level the plot is 16,392 pt wide, and laying out
  /// every rung of the ladder across it would be several hundred `Text`
  /// widgets on a viewport that holds three. Culling to the window is
  /// what makes the fine end of the step ladder affordable — and the
  /// fine end is what the deepest level needs, since a 50-year step at
  /// 4 pt per year puts the labels 200 pt apart and a phone would see
  /// one at a time.
  Widget _ruler(
    ChronologyScheme active,
    ColorScheme scheme,
    double plotWidth,
    int step,
  ) {
    // Room for THIS label plus the pinned end label plus a gap between
    // them. Reserving one label's width was the bug: at 320 pt the last
    // ladder label fitted on its own and then sat under "AM 4098".
    final labelW = _rulerLabelWidth();
    final endReserve = labelW * 2 + 14;
    return ListenableBuilder(
      listenable: _plot,
      builder: (context, _) {
        final hasView = _plot.hasClients &&
            _plot.position.hasPixels &&
            _plot.position.hasViewportDimension;
        final viewLeft = hasView ? _plot.position.pixels : 0.0;
        final viewRight = hasView
            ? viewLeft + _plot.position.viewportDimension
            : plotWidth;
        final labels = <Widget>[];
        for (var am = widget.data.spanStartAm;
            am <= widget.data.spanEndAm;
            am += step) {
          final x = _x(am, plotWidth);
          // A tick whose label would run into the pinned label at the
          // right edge is dropped rather than allowed to collide — the
          // scrubber above always prints the exact year, so the ruler
          // only has to give the reader a sense of scale.
          if (x + endReserve > plotWidth) break;
          if (x + labelW < viewLeft || x > viewRight) continue;
          final year = active.amToYear(am);
          labels.add(Positioned(
            left: x + 2,
            top: 2,
            child: Text(
              'AM $am',
              style: _rulerAmStyle.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6)),
            ),
          ));
          labels.add(Positioned(
            left: x + 2,
            top: _rulerSecondLineTop,
            child: Text(
              year < 0 ? '${-year} BC' : 'AD $year',
              style: _rulerYearStyle.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.45)),
            ),
          ));
        }
        // The right-hand end of the axis, always printed even when the
        // ladder above stops short of it. This is the thing the reader
        // asked for: proof that scrolling right arrives at Revelation.
        final endYear = active.amToYear(widget.data.spanEndAm);
        labels.add(Positioned(
          right: 2,
          top: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'AM ${widget.data.spanEndAm}',
                style: _rulerAmStyle.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6)),
              ),
              Text(
                endYear < 0 ? '${-endYear} BC' : 'AD $endYear',
                style: _rulerYearStyle.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.45)),
              ),
            ],
          ),
        ));
        return Stack(children: labels);
      },
    );
  }

  /// Era names on their bands. Each label is clipped to its own band,
  /// so two era names can never overlap; a band too narrow for even an
  /// ellipsis prints nothing and keeps only its colour, which the
  /// legend names. Background era banding is the standard orienting
  /// device for a long chronology, and these are the eight eras
  /// `assets/bible_timeline.json` already carries — the same ones the
  /// Events list on this page groups by.
  ///
  /// **Sticky, as of the density pass.** The label used to sit at the
  /// band's START, which was fine when the default view held the whole
  /// span and every band began on screen. It is not fine now: the chart
  /// opens inside a five-hundred-year window, and the Primeval band is
  /// two thousand years wide, so its name was a thousand points off the
  /// left of the viewport and the reader got an unlabelled colour. So a
  /// label slides along with the viewport, still INSIDE its own band and
  /// never past its end — the ordinary sticky-header behaviour, applied
  /// to a horizontal axis. It never moves onto a band it does not
  /// belong to, so it cannot mislabel a stretch of the chart.
  Widget _eraStrip(ColorScheme scheme, double plotWidth) {
    final brightness = Theme.of(context).brightness;
    return ListenableBuilder(
      listenable: _plot,
      builder: (context, _) {
        final viewLeft =
            _plot.hasClients && _plot.position.hasPixels
                ? _plot.position.pixels
                : 0.0;
        final children = <Widget>[];
        for (final e in widget.data.eras) {
          final left = _x(e.startAm, plotWidth);
          final right = _x(e.endAm, plotWidth);
          final w = right - left;
          if (w < 26) continue;
          final style = TextStyle(
            fontSize: _eraFontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: _readable(brightness, Color(e.colorValue)),
          );
          final text = e.localizedName(widget.locale);
          final want = _measure(text, style);
          // Slide the label to the viewport's left edge, but never past
          // the point where it would overhang the end of its own band.
          final maxStart = right - want - 3;
          final start =
              (viewLeft + 3).clamp(left + 3, maxStart < left + 3 ? left + 3 : maxStart);
          children.add(Positioned(
            left: start,
            top: 0,
            bottom: 0,
            width: (right - 3 - start).clamp(1.0, double.infinity),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: style,
              ),
            ),
          ));
        }
        return Stack(clipBehavior: Clip.hardEdge, children: children);
      },
    );
  }

  /// The event lane: every dated thing on the chart as a tick, computed
  /// ones solid, placed ones hollow.
  ///
  /// Labels are culled twice. First by density — pinned only at
  /// fit-to-width, the computed markers join immediately above it,
  /// everything competes from a quarter of a point per year — and then
  /// greedily left to right, dropping any label that would touch the one
  /// before it. So the lane gets denser as you zoom in and never shows
  /// two labels on top of each other, which is the way this chart type
  /// usually fails.
  ///
  /// [laneHeight] is what the lifeline rows did not need. Every 12 pt of
  /// it buys one more row of labels, packed first-fit, so the extra
  /// height is spent naming ticks rather than on white space — and a
  /// label below the first row gets a leader down to its own tick, so
  /// stacking never leaves a title ambiguous about which mark it names.
  Widget _tickLane(
    BuildContext context,
    ColorScheme scheme,
    double plotWidth,
    double laneHeight,
  ) {
    final ticks = widget.data.allTicks;
    final brightness = Theme.of(context).brightness;

    // Which ticks are even candidates, by density rather than by a zoom
    // step: fit-to-width prints only the pinned events, because at
    // 0.06 pt per year the lane has room for about four labels and they
    // had better be the four a reader recognises. From a quarter of a
    // point per year the whole corpus competes.
    final d = _density ?? 0;
    final candidates = ticks.where((t) {
      if (_atFit) return t.pin;
      if (d < 0.25) return t.pin || t.isComputed;
      return true;
    }).toList();

    final styles = [
      for (final t in candidates)
        TextStyle(
          fontSize: _labelFontSize,
          fontWeight: t.isComputed ? FontWeight.w800 : FontWeight.w500,
          color: scheme.onSurface
              .withValues(alpha: t.isComputed ? 0.85 : 0.62),
        ),
    ];
    final texts = [
      for (final t in candidates) t.localizedTitle(widget.locale),
    ];
    final wants = [
      for (var i = 0; i < candidates.length; i++)
        _measure(texts[i], styles[i]),
    ];
    final lefts = [
      for (final t in candidates) _x(t.am, plotWidth) + 3,
    ];

    final pitch = _labelRowPitch;
    final labelRows = ((laneHeight - 13) / pitch).floor().clamp(1, 5);
    final plan = chronologyLabelPlan(
      lefts: lefts,
      wants: wants,
      rows: labelRows,
      plotWidth: plotWidth,
      minWidth: _scaler.scale(34),
    );

    final labels = <Widget>[];
    for (final c in plan) {
      if (c.row > 0) {
        labels.add(Positioned(
          left: lefts[c.index] - 3,
          top: 11,
          width: 0.8,
          height: 2 + c.row * pitch,
          child: ColoredBox(
            color: scheme.onSurface.withValues(alpha: 0.28),
          ),
        ));
      }
      labels.add(Positioned(
        left: lefts[c.index],
        top: 13 + c.row * pitch,
        width: c.width + 1,
        child: Text(
          texts[c.index],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: styles[c.index],
        ),
      ));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Details on demand: tap anywhere in the lane and the nearest
      // tick within 14 pt opens. Hit boxes per tick would be 100
      // stacked widgets, and the ones in the New Testament would
      // overlap each other anyway.
      onTapDown: (d) {
        ChronologyMarker? best;
        var bestDx = 14.0;
        for (final t in ticks) {
          final dx = (_x(t.am, plotWidth) - d.localPosition.dx).abs();
          if (dx <= bestDx) {
            bestDx = dx;
            best = t;
          }
        }
        if (best != null) _showEventSheet(context, best);
      },
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TickPainter(
                data: widget.data,
                brightness: brightness,
                fallback: scheme.onSurface,
              ),
            ),
          ),
          ...labels,
        ],
      ),
    );
  }

  Widget _nameCell(
    BuildContext context,
    Lifeline l,
    ColorScheme scheme,
  ) {
    final on = l.aliveAt(_cursorAm);
    return InkWell(
      onTap: () => _showPersonSheet(context, l),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Text(
            l.localizedName(widget.locale),
            // Two lines, not one. The column is sized to the widest name
            // it has to print, so this only comes into play on a narrow
            // window where that width has been capped — and a wrapped
            // "Nahor (the elder)" is a whole name where "Nahor (the el…"
            // was not one. The parenthetical is not decoration: it is
            // what separates him from Nahor son of Terah, two rows down.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: _nameFontSize,
              height: 1.05,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              color: scheme.onSurface.withValues(alpha: on ? 0.95 : 0.4),
            ),
          ),
        ),
      ),
    );
  }

  /// The AM a folded run is asking to be taken to: the middle of the
  /// stretch its bars actually occupy.
  int _foldTarget(_Slot s) {
    var lo = s.lines.first.birthAm;
    var hi = lo;
    for (final l in s.lines) {
      if (l.birthAm < lo) lo = l.birthAm;
      final e = l.endAm(widget.data.spanEndAm);
      if (e > hi) hi = e;
    }
    return ((lo + hi) / 2).round();
  }

  String _foldLabel(_Slot s) =>
      _s('chronologyRowsFolded', '{n} not in view')
          .replaceAll('{n}', '${s.lines.length}');

  /// The name column's half of a folded run. It says the count and the
  /// reason in four words, and it is a control: tapping it does the same
  /// thing a "Jump to" chip does — moves the cursor and scrolls the plot
  /// to where those bars are. That is the way back. Nothing here is a
  /// claim about the people; "not in view" is a fact about the viewport,
  /// and the row is still in its place in the column, so a folded run
  /// can never be misread the way a deleted one could.
  Widget _foldNameCell(
    BuildContext context,
    _Slot s,
    ColorScheme scheme,
  ) {
    final names =
        s.lines.map((l) => l.localizedName(widget.locale)).join(', ');
    final target = _foldTarget(s);
    return Semantics(
      // The visible label is four words in an 88 pt column; a screen
      // reader has room for the names, and losing them to a fold would
      // be the one way this really did make people vanish.
      label: '$names — ${_foldLabel(s)}',
      button: true,
      excludeSemantics: true,
      onTap: () => _goTo(target),
      child: InkWell(
        onTap: () => _goTo(target),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Text(
              _foldLabel(s),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: _foldFontSize,
                fontWeight: FontWeight.w600,
                // The alpha the chart already uses for a bar whose
                // person is not alive at the cursor. Same idea — present
                // but not what you are looking at — so the same value.
                color: scheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The plot's half of a folded run: the same bars, on the same axis,
  /// squeezed. Not a placeholder and not a new device — each folded
  /// lifeline is still drawn at its own x, in its own descent colour, at
  /// the dimmed alpha the chart already gives a bar nobody is looking
  /// at. So scrolling toward them shows them approaching the edge, and
  /// each one grows back into a full row as it arrives.
  Widget _foldLane(BuildContext context, _Slot s, ColorScheme scheme) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _goTo(_foldTarget(s)),
      child: CustomPaint(
        painter: _FoldPainter(
          data: widget.data,
          lines: s.lines,
          brightness: Theme.of(context).brightness,
          rule: scheme.onSurface.withValues(alpha: 0.10),
        ),
      ),
    );
  }

  Widget _lane(
    BuildContext context,
    Lifeline l,
    ColorScheme scheme,
    double plotWidth,
  ) {
    final line = widget.data.lineById(l.lineId);
    final base = Color(line?.colorValue ?? 0xFF555555);
    final color = _readable(Theme.of(context).brightness, base);
    final on = l.aliveAt(_cursorAm);
    final left = _x(l.birthAm, plotWidth);
    final right = _x(l.endAm(widget.data.spanEndAm), plotWidth);
    final width = (right - left).clamp(3.0, double.infinity);
    // An unknown death year is drawn faded out at the tail rather than
    // squared off, so "we don't know" never looks like "he died then".
    final openEnded = l.deathAm == null;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: 6,
          width: width,
          height: 14,
          child: Semantics(
            label: l.localizedName(widget.locale),
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showPersonSheet(context, l),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: openEnded
                      ? LinearGradient(colors: [
                          color.withValues(alpha: on ? 0.9 : 0.25),
                          color.withValues(alpha: 0.0),
                        ])
                      : null,
                  color: openEnded
                      ? null
                      : color.withValues(alpha: on ? 0.9 : 0.25),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Person detail ───────────────────────────────────────────────

  void _showPersonSheet(BuildContext context, Lifeline l) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.data.activeScheme;
    final locale = widget.locale;
    final contemporaries = widget.data.lifelines
        .where((o) =>
            o.personId != l.personId &&
            o.birthAm <= (l.deathAm ?? widget.data.spanEndAm) &&
            (o.deathAm ?? widget.data.spanEndAm) >= l.birthAm)
        .length;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      // Cap on the sheet; the scroll view is one level in, under the
      // pinned name — see `test/nested_scrollable_test.dart`.
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.localizedName(locale),
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Text(
                        '${_s('chronologyBorn', 'Born')} '
                        '${formatChronologyYear(l.birthAm, active, locale)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                      Text(
                        l.deathAm == null
                            ? _s('chronologyDeathUnknown',
                                'Death year not given in Scripture')
                            : '${_s('chronologyDied', 'Died')} '
                                '${formatChronologyYear(l.deathAm!, active, locale)}'
                                ' · ${_s('chronologyLifespan', 'lived {n} years').replaceAll('{n}', '${l.lifespan}')}',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _s('chronologyContemporaries',
                                'Overlaps {count} others on this chart')
                            .replaceAll('{count}', '$contemporaries'),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _s('chronologyDerivation',
                            'How this year is derived'),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.localizedDerivation(locale),
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: scheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                      if (l.localizedNote(locale).isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l.localizedNote(locale),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color:
                                  scheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                      if (l.refs.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final r in l.refs)
                              _RefChip(
                                raw: r,
                                locale: locale,
                                scheme: scheme,
                                onTap: (widget.onTapRef == null ||
                                        firstResolvableReference(r) == null)
                                    ? null
                                    : () {
                                        Navigator.of(ctx).pop();
                                        widget.onTapRef!(r);
                                      },
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Event detail ────────────────────────────────────────────────

  /// Details on demand for one tick. The first thing it says is where
  /// the year came from, because that is the one fact the picture
  /// cannot carry on its own and the one this chart is most at risk of
  /// being quoted for.
  void _showEventSheet(BuildContext context, ChronologyMarker m) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.data.activeScheme;
    final locale = widget.locale;
    final era = widget.data.eraById(m.era);

    String signedYear(int y) {
      if (y < 0) return _isZh ? '公元前 ${-y} 年' : '${-y} BC';
      return _isZh ? '公元 $y 年' : 'AD $y';
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _BasisGlyph(computed: m.isComputed, scheme: scheme),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m.localizedTitle(locale),
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Text(
                        formatChronologyYear(m.am, active, locale),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                      if (era != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          era.localizedName(locale),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _readable(
                                Theme.of(ctx).brightness,
                                Color(era.colorValue)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        _s('chronologyBasis', 'Where this year comes from'),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.isComputed
                            ? _s('chronologyBasisComputed', '')
                            : _s('chronologyBasisPlaced', '').replaceAll(
                                '{year}',
                                signedYear(m.year ?? active.amToYear(m.am))),
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: scheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                      // A deduped disagreement is never silent: if the
                      // event list dates the same thing differently,
                      // this says so and by how much.
                      if (m.placedYear != null &&
                          (m.placedDeltaYears ?? 0) != 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _s('chronologyAlsoPlaced', '')
                                .replaceAll(
                                    '{year}', signedYear(m.placedYear!))
                                .replaceAll('{delta}',
                                    '${m.placedDeltaYears!.abs()}'),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: scheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                      if (m.refs.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final r in m.refs)
                              _RefChip(
                                raw: r,
                                locale: locale,
                                scheme: scheme,
                                onTap: (widget.onTapRef == null ||
                                        firstResolvableReference(r) == null)
                                    ? null
                                    : () {
                                        Navigator.of(ctx).pop();
                                        widget.onTapRef!(r);
                                      },
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Legend + scope ──────────────────────────────────────────────

  Widget _legend(BuildContext context, ColorScheme scheme) {
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _s('chronologyLegend', 'Lines of descent'),
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final l in widget.data.lines)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _readable(brightness, Color(l.colorValue)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Flexible, not bare: a Wrap hands its children the
                  // full width as a maximum, and "Shem's line (Genesis
                  // 11)" at 130% system text is wider than a 402 pt
                  // phone's content column. It used to overflow the row.
                  Flexible(
                    child: Text(
                      l.localizedName(widget.locale),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.data.localizedUndrawn(widget.locale),
          style: TextStyle(
            fontSize: 11.5,
            height: 1.6,
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 14),
        // The computed/placed key. It is a SECOND statement of a
        // distinction the chart already makes in the drawing — solid
        // vs hollow tick, plain vs hatched ground, and the labelled
        // rule where one ends — never the only place it is made. A
        // legend that is the only separator between sourced data and
        // inference is how a chart like this gets quoted wrongly.
        Text(
          _s('chronologyBasis', 'Where this year comes from'),
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BasisGlyph(computed: true, scheme: scheme),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _s('chronologyComputedKey',
                    'Computed from ages Scripture states'),
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BasisGlyph(computed: false, scheme: scheme),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _s('chronologyPlacedKey',
                    'Placed event — dated by scholarship, not counted'),
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // The boundary rule on the chart carries this same sentence,
        // but it is PAINTED, which means a screen reader never sees it.
        // Repeating it as real text is the accessible copy of a mark
        // the drawing makes.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.linear_scale_rounded,
                size: 14, color: scheme.onSurface.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_s('chronologyComputedEnds', 'Genesis 5 & 11 ages end '
                    'here')} · '
                '${formatChronologyYear(widget.data.computedEndAm, widget.data.activeScheme, widget.locale)}',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.data.localizedComputedNote(widget.locale),
          style: TextStyle(
            fontSize: 11.5,
            height: 1.6,
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        if (widget.data.contested != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.8),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _s('chronologyContestedLabel',
                      'The two scales disagree here'),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.data.contested!.localizedNote(widget.locale),
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.6,
                    color: scheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _scopeNote(ColorScheme scheme) {
    final span = _s('chronologySpanNote', '').replaceAll(
        '{years}', '${widget.data.spanEndAm - widget.data.spanStartAm}');
    return Text(
      '$span '
      '${_s('chronologyScopeNote', 'The bars cover Genesis 5 and 11 only '
          '— Adam to Abraham, the span where Scripture states the ages '
          'these years are computed from.')}',
      style: TextStyle(
        fontSize: 11.5,
        height: 1.6,
        fontStyle: FontStyle.italic,
        color: scheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}

/// One vertical slot in the lifeline stack: either a single lifeline in
/// a full row, or a run of consecutive lifelines folded into one band.
class _Slot {
  final List<Lifeline> lines;
  final bool folded;

  _Slot.row(Lifeline l)
      : lines = [l],
        folded = false;
  _Slot.fold(Lifeline l)
      : lines = [l],
        folded = true;
}

/// Which lifeline rows earn a full row at the plot's current viewport.
///
/// **Why this exists.** The chart's axis runs AM 0 → 4098 but its bars
/// stop at AM 2187, because that is where Scripture stops stating the
/// begetting ages. Scrolled to the right-hand end, all twenty rows were
/// still drawn — twenty names against 700 BC, no bars, more than half
/// the chart's height spent saying nothing. That is the defect this
/// fixes. It is NOT a change to where the lifelines end: [lifelines] is
/// the same list, drawn on the same axis, and nothing is invented past
/// [spanEndAm] or hidden before it.
///
/// **Why it is not a switch at AM 2187.** A viewport that straddles the
/// boundary has real bars in it, and a binary "past the boundary" test
/// would drop them. The test here is plain overlap between each bar and
/// the viewport, so partial overlap — the normal case at high zoom —
/// keeps exactly the bars that are on screen.
///
/// **Why it takes [previous].** A single threshold flickers: a bar
/// resting on the edge of the viewport would fold and unfold with every
/// pixel of scroll jitter, and each flip moves 26 pt of layout. So the
/// row enters at [enterMargin] and only leaves at the wider
/// [exitMargin] — real hysteresis, with the side effect that every fold
/// and unfold happens for a bar that is off screen at the moment it
/// happens, so the row that changes height is never the row being read.
///
/// At zoom 1 the viewport is the whole span and this returns all true,
/// which is why the default view is byte-for-byte what it was.
@visibleForTesting
List<bool> chronologyRowsInView({
  required List<Lifeline> lifelines,
  required int spanStartAm,
  required int spanEndAm,
  required double viewStartFrac,
  required double viewEndFrac,
  List<bool>? previous,
  double enterMargin = 0.06,
  double exitMargin = 0.25,
}) {
  final span = (spanEndAm - spanStartAm).abs();
  final width = viewEndFrac - viewStartFrac;
  if (span == 0 || width <= 0 || width >= 1) {
    return List<bool>.filled(lifelines.length, true);
  }
  double lo(double m) => spanStartAm + (viewStartFrac - width * m) * span;
  double hi(double m) => spanStartAm + (viewEndFrac + width * m) * span;
  final enterLo = lo(enterMargin);
  final enterHi = hi(enterMargin);
  final exitLo = lo(exitMargin);
  final exitHi = hi(exitMargin);
  return [
    for (var i = 0; i < lifelines.length; i++)
      () {
        final b = lifelines[i].birthAm.toDouble();
        final e = lifelines[i].endAm(spanEndAm).toDouble();
        if (b <= enterHi && e >= enterLo) return true;
        final held = previous != null && i < previous.length && previous[i];
        return held && b <= exitHi && e >= exitLo;
      }(),
  ];
}

/// One event label the lane has decided to draw: which candidate it is,
/// which row it landed in, and how much horizontal room it actually got.
@visibleForTesting
class ChronologyLabelSlot {
  final int index;
  final int row;

  /// The room the label gets. Equal to its measured width unless the
  /// right-hand end of the plot cuts it short, in which case the `Text`
  /// ellipsises — see [complete].
  final double width;

  /// True when the whole title is drawn. The packer's job is to make
  /// this true for every label it chooses; a false here is a label that
  /// ran off the end of the plot, never one crowded by a neighbour.
  final bool complete;

  const ChronologyLabelSlot({
    required this.index,
    required this.row,
    required this.width,
    required this.complete,
  });
}

/// Which event labels the tick lane draws, and where.
///
/// Pass one picks the labels, greedily left to right, into the first row
/// with room — first-fit, so a long title on row 0 pushes its neighbour
/// down rather than pushing it out. With one row, which is the whole of
/// the default view, this is exactly the single-row greed the lane has
/// always used.
///
/// Pass two hands each label all the room up to the NEXT chosen label in
/// its own row. Because pass one already reserved the label's full
/// measured width, that room is never less than the title needs: a title
/// is now only ever cut by the right-hand end of the plot, never by a
/// neighbour. (It used to be reserved as `width.clamp(34, 190)`, so any
/// title wider than 190 pt under-reserved and then got trimmed by the
/// label after it — a cap in the packer masquerading as a collision.)
///
/// Pure, and separate from the widget, so the density at which the
/// corpus becomes legible can be MEASURED — see `_maxDensity`, whose
/// value is the knee of a sweep of this function over all 100 ticks.
@visibleForTesting
List<ChronologyLabelSlot> chronologyLabelPlan({
  required List<double> lefts,
  required List<double> wants,
  required int rows,
  required double plotWidth,
  double minWidth = 34,
  double gap = 6,
}) {
  final lastRight = List<double>.filled(rows, double.negativeInfinity);
  final picked = <int>[];
  final pickedRow = <int>[];
  for (var i = 0; i < lefts.length; i++) {
    final left = lefts[i];
    if (left + minWidth > plotWidth) continue;
    var row = -1;
    for (var r = 0; r < rows; r++) {
      if (left >= lastRight[r] + gap) {
        row = r;
        break;
      }
    }
    if (row < 0) continue;
    lastRight[row] = left + (wants[i] < minWidth ? minWidth : wants[i]);
    picked.add(i);
    pickedRow.add(row);
  }
  final out = <ChronologyLabelSlot>[];
  for (var k = 0; k < picked.length; k++) {
    final i = picked[k];
    var nextLeft = plotWidth;
    for (var j = k + 1; j < picked.length; j++) {
      if (pickedRow[j] == pickedRow[k]) {
        nextLeft = lefts[picked[j]] - gap;
        break;
      }
    }
    final room = (nextLeft - lefts[i]).clamp(1.0, double.infinity);
    final w = wants[i] < room ? wants[i] : room;
    out.add(ChronologyLabelSlot(
      index: i,
      row: pickedRow[k],
      width: w,
      complete: w >= wants[i] - 0.5,
    ));
  }
  return out;
}

/// The one glyph that separates a counted year from a placed one:
/// filled diamond vs hollow circle. Shape and fill, never hue — the
/// chart already spends colour on the two lines of descent and the
/// eight era bands, and a third meaning carried by hue alone would
/// vanish in greyscale and for a colour-blind reader.
class _BasisGlyph extends StatelessWidget {
  final bool computed;
  final ColorScheme scheme;
  const _BasisGlyph({required this.computed, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(
        painter: _BasisGlyphPainter(
          computed: computed,
          color: scheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _BasisGlyphPainter extends CustomPainter {
  final bool computed;
  final Color color;
  const _BasisGlyphPainter({required this.computed, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    if (computed) {
      final p = Path()
        ..moveTo(c.dx, c.dy - 5)
        ..lineTo(c.dx + 4.2, c.dy)
        ..lineTo(c.dx, c.dy + 5)
        ..lineTo(c.dx - 4.2, c.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = color);
    } else {
      canvas.drawCircle(
        c,
        4.2,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(_BasisGlyphPainter old) =>
      old.computed != computed || old.color != color;
}

/// Lighten a tuned-for-light-surfaces palette colour for the dark theme,
/// keeping the hue so the descent colour-coding still reads. Same
/// treatment `bible_timeline_page.dart` gives the era palette.
Color _readable(Brightness brightness, Color base) {
  if (brightness == Brightness.dark) {
    return Color.lerp(base, Colors.white, 0.4) ?? base;
  }
  return base;
}

/// Diagonal hatching. The chart's texture for "this is not counted
/// data" — texture rather than a tint, so it survives greyscale and
/// does not compete with the two descent colours or the eight era
/// colours already spending hue.
void _hatch(
  Canvas canvas,
  Rect rect,
  Color color, {
  double spacing = 7,
  double slope = 1,
  double stroke = 0.7,
}) {
  if (rect.width <= 0 || rect.height <= 0) return;
  canvas.save();
  canvas.clipRect(rect);
  final p = Paint()
    ..color = color
    ..strokeWidth = stroke;
  final reach = rect.width + rect.height;
  for (var i = -rect.height; i < reach; i += spacing) {
    final x0 = rect.left + i;
    // slope > 0 leans one way ("\"), slope < 0 the other ("/"), so the
    // two hatches can be laid over each other and still be told apart.
    canvas.drawLine(
      Offset(x0, slope > 0 ? rect.top : rect.bottom),
      Offset(x0 + rect.height, slope > 0 ? rect.bottom : rect.top),
      p,
    );
  }
  canvas.restore();
}

void _paintLabel(
  Canvas canvas,
  String text,
  Offset at,
  TextStyle style, {
  double rotation = 0,
  TextDirection direction = TextDirection.ltr,
}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: direction,
  )..layout();
  canvas.save();
  canvas.translate(at.dx, at.dy);
  if (rotation != 0) canvas.rotate(rotation);
  tp.paint(canvas, Offset.zero);
  canvas.restore();
}

/// Everything behind the lanes: era bands, the computed ground, the
/// fade and hatch where it stops, the contested band, and the gridlines.
///
/// The fade is deliberate reuse. `_lane` already fades a bar out at the
/// tail when Scripture gives no death year — that is this chart's
/// existing word for "we do not know". So the ground fades out at the
/// end of the computed stretch in exactly the same way, and what lies
/// beyond is hatched rather than blank: there IS something there
/// (events), it is simply not counted from stated ages.
class _GroundPainter extends CustomPainter {
  final ChronologyData data;
  final double rulerHeight;
  final double eraStripHeight;
  final double tickLaneHeight;
  final int gridStep;
  final Brightness brightness;
  final ColorScheme scheme;
  final String boundaryLabel;
  final String contestedLabel;

  const _GroundPainter({
    required this.data,
    required this.rulerHeight,
    required this.eraStripHeight,
    required this.tickLaneHeight,
    required this.gridStep,
    required this.brightness,
    required this.scheme,
    this.boundaryLabel = '',
    this.contestedLabel = '',
  });

  @override
  void paint(Canvas canvas, Size size) {
    final span = (data.spanEndAm - data.spanStartAm).abs();
    if (span == 0 || size.width <= 0) return;
    double x(int am) => (am - data.spanStartAm) / span * size.width;

    final stripTop = rulerHeight;
    final lanesTop = rulerHeight + eraStripHeight;

    // Era banding — the standard orienting device for a long
    // chronology, and eight eras this app already has rather than
    // decoration invented for the occasion.
    for (final e in data.eras) {
      final rect = Rect.fromLTRB(x(e.startAm), lanesTop, x(e.endAm),
          size.height - tickLaneHeight);
      final c = _readable(brightness, Color(e.colorValue));
      canvas.drawRect(rect, Paint()..color = c.withValues(alpha: 0.055));
      canvas.drawRect(
        Rect.fromLTRB(
            x(e.startAm), stripTop, x(e.endAm), stripTop + eraStripHeight),
        Paint()..color = c.withValues(alpha: 0.22),
      );
      canvas.drawLine(
        Offset(x(e.startAm), stripTop),
        Offset(x(e.startAm), size.height - tickLaneHeight),
        Paint()
          ..color = c.withValues(alpha: 0.45)
          ..strokeWidth = 0.8,
      );
    }

    // The computed ground, then the fade, then the hatch.
    final groundTop = lanesTop;
    final groundBottom = size.height;
    final endX = x(data.computedEndAm);
    final ground = scheme.onSurface.withValues(alpha: 0.05);
    canvas.drawRect(
      Rect.fromLTRB(x(data.spanStartAm), groundTop, endX, groundBottom),
      Paint()..color = ground,
    );
    final fadeWidth =
        ((size.width - endX) * 0.2).clamp(0.0, 70.0).toDouble();
    if (fadeWidth > 0) {
      final fadeRect =
          Rect.fromLTRB(endX, groundTop, endX + fadeWidth, groundBottom);
      canvas.drawRect(
        fadeRect,
        Paint()
          ..shader = LinearGradient(
            colors: [ground, ground.withValues(alpha: 0)],
          ).createShader(fadeRect),
      );
    }
    _hatch(
      canvas,
      Rect.fromLTRB(endX, groundTop, size.width, groundBottom),
      scheme.onSurface.withValues(alpha: 0.10),
      spacing: 8,
    );

    // The contested band: the same hatch, crossed. Two textures on top
    // of each other read as "both things are true here" — there IS a
    // computed count under it AND placed events over it, and they do
    // not agree.
    final contested = data.contested;
    if (contested != null) {
      final rect = Rect.fromLTRB(
          x(contested.startAm), groundTop, x(contested.endAm), groundBottom);
      // Heavier on the dark theme: `scheme.error` there is a pale red
      // on a near-black ground, and 0.16 alpha put the band below the
      // threshold where a reader notices it at all.
      final dark = brightness == Brightness.dark;
      _hatch(canvas, rect,
          scheme.error.withValues(alpha: dark ? 0.30 : 0.16),
          spacing: 6, slope: -1);
      final edge = Paint()
        ..color = scheme.error.withValues(alpha: dark ? 0.6 : 0.4)
        ..strokeWidth = 1;
      canvas.drawLine(
          Offset(rect.left, groundTop), Offset(rect.left, groundBottom), edge);
      if (contestedLabel.isNotEmpty && rect.width > 130) {
        _paintLabel(
          canvas,
          contestedLabel,
          Offset(rect.left + 4, groundTop + 3),
          TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: scheme.error.withValues(alpha: 0.9),
          ),
        );
      }
    }

    // Gridlines last of the fills, so they read over the bands.
    final grid = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    for (var am = data.spanStartAm; am <= data.spanEndAm; am += gridStep) {
      final dx = x(am);
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), grid);
    }

    // The boundary itself — named on the chart, not only in the legend.
    canvas.drawLine(
      Offset(endX, rulerHeight - 4),
      Offset(endX, size.height),
      Paint()
        ..color = scheme.onSurface.withValues(alpha: 0.55)
        ..strokeWidth = 1.4,
    );
    if (boundaryLabel.isNotEmpty && size.height - lanesTop > 120) {
      // Rotated, hard against the rule: a horizontal label here would
      // sit across the lifelines and collide with the era names.
      _paintLabel(
        canvas,
        boundaryLabel,
        Offset(endX - 3, lanesTop + 6),
        TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface.withValues(alpha: 0.7),
        ),
        rotation: 1.5707963,
      );
    }
  }

  @override
  bool shouldRepaint(_GroundPainter old) =>
      old.data != data ||
      old.gridStep != gridStep ||
      old.brightness != brightness ||
      old.scheme != scheme ||
      old.boundaryLabel != boundaryLabel ||
      old.contestedLabel != contestedLabel;
}

/// A folded run of lifeline rows, drawn as the same bars on the same
/// axis at a smaller pitch.
///
/// This is deliberately NOT a new mark. The bars keep their descent
/// colour and take the alpha the chart already gives a bar whose person
/// is not alive at the cursor (0.25) — present, not what you are looking
/// at. So the band is the picture the reader already knows, compressed,
/// and scrolling toward it shows the bars approaching the viewport and
/// growing back into rows one at a time. A blank strip, or a hatch,
/// would have been a second visual word for something the chart can say
/// with the word it has. (The hatch in particular is spoken for: on this
/// chart it means "not counted", and a folded row is counted — it is
/// just elsewhere.)
class _FoldPainter extends CustomPainter {
  final ChronologyData data;
  final List<Lifeline> lines;
  final Brightness brightness;
  final Color rule;

  const _FoldPainter({
    required this.data,
    required this.lines,
    required this.brightness,
    required this.rule,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final span = (data.spanEndAm - data.spanStartAm).abs();
    if (span == 0 || size.width <= 0 || lines.isEmpty) return;
    double x(int am) => (am - data.spanStartAm) / span * size.width;

    final usable = (size.height - 8).clamp(1.0, double.infinity);
    final pitch = usable / lines.length;
    final thickness = (pitch * 0.65).clamp(0.8, 3.0);
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final base =
          Color(data.lineById(l.lineId)?.colorValue ?? 0xFF555555);
      final y = 4 + pitch * (i + 0.5);
      canvas.drawLine(
        Offset(x(l.birthAm), y),
        Offset(x(l.endAm(data.spanEndAm)), y),
        Paint()
          ..color = _readable(brightness, base).withValues(alpha: 0.25)
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round,
      );
    }
    // A hairline under the band, so the fold reads as one object rather
    // than as a lifeline row that has gone thin.
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..color = rule
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_FoldPainter old) =>
      old.data != data ||
      old.brightness != brightness ||
      old.rule != rule ||
      !listEquals(old.lines, lines);
}

/// The event lane's marks. Filled diamond = counted from stated ages;
/// hollow circle = placed. Shape and fill, not hue: the tick is also
/// coloured by its era, and that colour must stay free to mean the era.
class _TickPainter extends CustomPainter {
  final ChronologyData data;
  final Brightness brightness;
  final Color fallback;

  const _TickPainter({
    required this.data,
    required this.brightness,
    required this.fallback,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final span = (data.spanEndAm - data.spanStartAm).abs();
    if (span == 0 || size.width <= 0) return;
    double x(int am) => (am - data.spanStartAm) / span * size.width;

    for (final t in data.allTicks) {
      final era = data.eraById(t.era);
      final base = era == null
          ? fallback
          : _readable(brightness, Color(era.colorValue));
      final dx = x(t.am);
      if (t.isComputed) {
        canvas.drawLine(
          Offset(dx, 0),
          Offset(dx, 11),
          Paint()
            ..color = base.withValues(alpha: 0.95)
            ..strokeWidth = 1.4,
        );
        final p = Path()
          ..moveTo(dx, 1)
          ..lineTo(dx + 3.4, 5.5)
          ..lineTo(dx, 10)
          ..lineTo(dx - 3.4, 5.5)
          ..close();
        canvas.drawPath(p, Paint()..color = base.withValues(alpha: 0.95));
      } else {
        canvas.drawLine(
          Offset(dx, 2),
          Offset(dx, 11),
          Paint()
            ..color = base.withValues(alpha: 0.5)
            ..strokeWidth = 0.8,
        );
        canvas.drawCircle(
          Offset(dx, 5.5),
          2.8,
          Paint()
            ..color = base.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.data != data ||
      old.brightness != brightness ||
      old.fallback != fallback;
}

/// The overview strip: the whole 4,100-year span at 1× with the plot's
/// current viewport outlined on it. Same vocabulary as the plot — era
/// bands, computed ground, hatch, ticks, cursor — because a second,
/// competing visual language for the same data is how a reader loses
/// track of which picture they are looking at.
class _OverviewPainter extends CustomPainter {
  final ChronologyData data;
  final int cursorAm;
  final double? viewStartFrac;
  final double? viewEndFrac;
  final Brightness brightness;
  final ColorScheme scheme;

  const _OverviewPainter({
    required this.data,
    required this.cursorAm,
    required this.viewStartFrac,
    required this.viewEndFrac,
    required this.brightness,
    required this.scheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final span = (data.spanEndAm - data.spanStartAm).abs();
    if (span == 0 || size.width <= 0) return;
    double x(int am) => (am - data.spanStartAm) / span * size.width;

    const bandBottom = 13.0;
    final ground = Rect.fromLTRB(0, bandBottom, size.width, size.height);

    for (final e in data.eras) {
      final c = _readable(brightness, Color(e.colorValue));
      canvas.drawRect(
        Rect.fromLTRB(x(e.startAm), 0, x(e.endAm), bandBottom),
        Paint()..color = c.withValues(alpha: 0.55),
      );
    }

    final endX = x(data.computedEndAm);
    canvas.drawRect(
      Rect.fromLTRB(0, bandBottom, endX, size.height),
      Paint()..color = scheme.onSurface.withValues(alpha: 0.07),
    );
    _hatch(
      canvas,
      Rect.fromLTRB(endX, bandBottom, size.width, size.height),
      scheme.onSurface.withValues(alpha: 0.13),
      spacing: 6,
    );
    final contested = data.contested;
    if (contested != null) {
      _hatch(
        canvas,
        Rect.fromLTRB(
            x(contested.startAm), bandBottom, x(contested.endAm), size.height),
        scheme.error.withValues(alpha: 0.2),
        spacing: 5,
        slope: -1,
      );
    }
    canvas.drawLine(
      Offset(endX, 0),
      Offset(endX, size.height),
      Paint()
        ..color = scheme.onSurface.withValues(alpha: 0.6)
        ..strokeWidth = 1.2,
    );

    for (final t in data.allTicks) {
      final dx = x(t.am);
      canvas.drawLine(
        Offset(dx, bandBottom + 3),
        Offset(dx, size.height - 3),
        Paint()
          ..color = scheme.onSurface
              .withValues(alpha: t.isComputed ? 0.75 : 0.32)
          ..strokeWidth = t.isComputed ? 1.4 : 0.8,
      );
    }

    canvas.drawRect(
      ground.deflate(0.25),
      Paint()
        ..color = scheme.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    // Where the plot below is currently looking.
    if (viewStartFrac != null && viewEndFrac != null) {
      final l = (viewStartFrac! * size.width).clamp(0.0, size.width);
      final r = (viewEndFrac! * size.width).clamp(0.0, size.width);
      final rect = Rect.fromLTRB(l, 0, r < l + 5 ? l + 5 : r, size.height);
      canvas.drawRect(
          rect, Paint()..color = scheme.primary.withValues(alpha: 0.10));
      canvas.drawRect(
        rect.deflate(0.75),
        Paint()
          ..color = scheme.primary.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    final cx = x(cursorAm);
    canvas.drawLine(
      Offset(cx, 0),
      Offset(cx, size.height),
      Paint()
        ..color = scheme.primary.withValues(alpha: 0.9)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_OverviewPainter old) =>
      old.data != data ||
      old.cursorAm != cursorAm ||
      old.viewStartFrac != viewStartFrac ||
      old.viewEndFrac != viewEndFrac ||
      old.brightness != brightness ||
      old.scheme != scheme;
}

/// A small selectable pill — used for the marker shortcuts. Carries the
/// same filled/hollow glyph as the tick it jumps to, so the chip says
/// which layer it belongs to without needing a colour to do it.
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool computed;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.computed,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.7)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 5, 10, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BasisGlyph(computed: computed, scheme: scheme),
              const SizedBox(width: 5),
              // Flexible, not a bare Text: the longest chip label —
              // "The Flood (Noah's 600th year)" — is wider than a
              // 402 pt phone's content column once the glyph is in
              // front of it, and must wrap rather than overflow.
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: scheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Verse citation chip in the person sheet. Non-navigable citations are
/// drawn as plain text, matching `bible_timeline_page.dart`'s rule that
/// a chip which cannot open must not look like a link.
class _RefChip extends StatelessWidget {
  final String raw;
  final String locale;
  final ColorScheme scheme;
  final VoidCallback? onTap;

  const _RefChip({
    required this.raw,
    required this.locale,
    required this.scheme,
    required this.onTap,
  });

  String _localized() {
    final p = parseReference(raw);
    if (p == null) return raw;
    final book = localeAwareBookName(p.englishBook, locale);
    final tail = p.toString().replaceFirst(p.englishBook, '');
    return '$book$tail';
  }

  @override
  Widget build(BuildContext context) {
    final navigable = onTap != null;
    final fg = navigable
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.55);
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: navigable
            ? scheme.primaryContainer.withValues(alpha: 0.25)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: navigable
              ? scheme.primary.withValues(alpha: 0.35)
              : scheme.outlineVariant.withValues(alpha: 0.6),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded, size: 11, color: fg),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              _localized(),
              style: TextStyle(
                fontSize: 11,
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (!navigable) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: body,
      ),
    );
  }
}
