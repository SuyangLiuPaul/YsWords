import 'package:flutter/material.dart';

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
  static const double _nameColumnWidth = 88;
  static const double _rowHeight = 26;
  static const double _rulerHeight = 30;
  static const double _gap = 8;

  final ScrollController _plot = ScrollController();

  /// The scrubbed year, in AM. Defaults to the Flood — a year that
  /// immediately demonstrates what the chart is for, since Methuselah's
  /// bar ends exactly on it.
  late int _cursorAm;

  /// 1 = whole span fits the width (no horizontal scrolling).
  double _zoom = 1;

  @override
  void initState() {
    super.initState();
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
    _plot.dispose();
    super.dispose();
  }

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = widget.data;
    final active = data.activeScheme;
    final alive = data.aliveAt(_cursorAm);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        _schemeBanner(context, active, scheme),
        const SizedBox(height: 12),
        _scrubber(context, active, scheme, alive.length),
        _zoomRow(scheme),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            // The plot never gets a width smaller than the viewport, so
            // zoom 1 always fits and never introduces a sideways scroll.
            final viewport =
                (constraints.maxWidth - _nameColumnWidth - _gap)
                    .clamp(80.0, double.infinity);
            final plotWidth = viewport * _zoom;
            return _chart(context, scheme, active, plotWidth);
          },
        ),
        const SizedBox(height: 16),
        // Below the chart, not above it: seven chips wrap to four rows
        // on a phone, and putting them before the plot pushed the thing
        // the reader came for off the first screen.
        Text(
          _s('chronologyJumpTo', 'Jump to'),
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4),
        ),
        const SizedBox(height: 6),
        _markerChips(scheme),
        const SizedBox(height: 16),
        _legend(context, scheme),
        const SizedBox(height: 12),
        _scopeNote(scheme),
      ],
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
            Text(
              _s('chronologyAliveCount', '{count} alive')
                  .replaceAll('{count}', '$aliveCount'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
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

  /// Dated events, as chips that move the scrubber. The ruler shows them
  /// as ticks; the labels live here because seven labels across a
  /// 280 pt ruler would collide on a phone.
  Widget _markerChips(ColorScheme scheme) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in widget.data.markers)
          _Chip(
            label: m.localizedTitle(widget.locale),
            selected: m.am == _cursorAm,
            scheme: scheme,
            onTap: () => setState(() => _cursorAm = m.am),
          ),
      ],
    );
  }

  Widget _zoomRow(ColorScheme scheme) {
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
        const SizedBox(width: 8),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          tooltip: _s('chronologyZoomOut', 'Zoom out'),
          onPressed: _zoom <= 1
              ? null
              : () => setState(() => _zoom = (_zoom - 1).clamp(1, 4)),
          icon: const Icon(Icons.zoom_out_rounded),
        ),
        Text(
          '${_zoom.toStringAsFixed(0)}×',
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          tooltip: _s('chronologyZoomIn', 'Zoom in'),
          onPressed: _zoom >= 4
              ? null
              : () => setState(() => _zoom = (_zoom + 1).clamp(1, 4)),
          icon: const Icon(Icons.zoom_in_rounded),
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
  ) {
    final data = widget.data;
    final rows = data.lifelines;
    final height = _rulerHeight + rows.length * _rowHeight;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed name column — stays put while the plot scrolls, so a
          // zoomed-in bar is never anonymous.
          SizedBox(
            width: _nameColumnWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: _rulerHeight),
                for (final l in rows)
                  SizedBox(
                    height: _rowHeight,
                    child: _nameCell(context, l, scheme),
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
              physics: _zoom <= 1
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              child: SizedBox(
                width: plotWidth,
                height: height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GridPainter(
                          data: data,
                          rulerHeight: _rulerHeight,
                          gridColor:
                              scheme.outlineVariant.withValues(alpha: 0.5),
                          markerColor:
                              scheme.onSurface.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: _rulerHeight,
                          child: _ruler(active, scheme, plotWidth),
                        ),
                        for (final l in rows)
                          SizedBox(
                            height: _rowHeight,
                            child: _lane(context, l, scheme, plotWidth),
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

  Widget _ruler(
    ChronologyScheme active,
    ColorScheme scheme,
    double plotWidth,
  ) {
    // One label every 500 years at zoom 1; denser as the plot widens.
    final step = _zoom >= 3 ? 200 : 500;
    final labels = <Widget>[];
    for (var am = widget.data.spanStartAm;
        am <= widget.data.spanEndAm;
        am += step) {
      // A tick whose two-line label would run past the right edge is
      // dropped rather than clipped — the scrubber above always prints
      // the exact year, so the ruler only has to give the reader a
      // sense of scale.
      if (_x(am, plotWidth) + 46 > plotWidth) break;
      final year = active.amToYear(am);
      labels.add(Positioned(
        left: _x(am, plotWidth) + 2,
        top: 2,
        child: Text(
          'AM $am',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ));
      labels.add(Positioned(
        left: _x(am, plotWidth) + 2,
        top: 14,
        child: Text(
          year < 0 ? '${-year} BC' : 'AD $year',
          style: TextStyle(
            fontSize: 9,
            color: scheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ));
    }
    return Stack(children: labels);
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 11,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              color: scheme.onSurface.withValues(alpha: on ? 0.95 : 0.4),
            ),
          ),
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
                  Text(
                    l.localizedName(widget.locale),
                    style: const TextStyle(fontSize: 12),
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
      ],
    );
  }

  Widget _scopeNote(ColorScheme scheme) {
    return Text(
      _s('chronologyScopeNote',
          'First pass: Genesis 5 and 11 only — Adam to Abraham, the span '
              'where Scripture states the ages these years are computed '
              'from.'),
      style: TextStyle(
        fontSize: 11.5,
        height: 1.6,
        fontStyle: FontStyle.italic,
        color: scheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
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

/// Vertical century gridlines behind the lanes, plus a faint tick for
/// every dated marker. Painted rather than laid out because there are
/// dozens of them and none of them is interactive.
class _GridPainter extends CustomPainter {
  final ChronologyData data;
  final double rulerHeight;
  final Color gridColor;
  final Color markerColor;

  const _GridPainter({
    required this.data,
    required this.rulerHeight,
    required this.gridColor,
    required this.markerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final span = (data.spanEndAm - data.spanStartAm).abs();
    if (span == 0) return;
    double x(int am) => (am - data.spanStartAm) / span * size.width;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (var am = data.spanStartAm; am <= data.spanEndAm; am += 500) {
      final dx = x(am);
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), grid);
    }

    final mark = Paint()
      ..color = markerColor
      ..strokeWidth = 1;
    for (final m in data.markers) {
      final dx = x(m.am);
      canvas.drawLine(
          Offset(dx, rulerHeight - 6), Offset(dx, size.height), mark);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.data != data ||
      old.gridColor != gridColor ||
      old.markerColor != markerColor;
}

/// A small selectable pill — used for the marker shortcuts.
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: scheme.onSurface.withValues(alpha: 0.9),
            ),
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
