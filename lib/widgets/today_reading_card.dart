import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/services/reading_plan_service.dart';
import 'package:yswords/utils/version_mapper.dart' show translateBookName;
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/reference_parser.dart';

/// "Today's Reading" surface — a tiny card meant to live just below
/// the floating header in [BibleReadingPane]. Shows the active plan's
/// chips for today and lets the user tap to jump or check off the
/// day. Renders nothing (zero height) when no plan is active so it
/// stays out of the way.
class TodayReadingCard extends StatefulWidget {
  /// Called when a chip is tapped — host pane navigates to the
  /// resolved Bible reference (passing through the same logic as
  /// cross-reference taps so behaviour stays consistent).
  final void Function(BibleReference ref)? onJump;

  const TodayReadingCard({super.key, required this.onJump});

  @override
  State<TodayReadingCard> createState() => _TodayReadingCardState();
}

class _TodayReadingCardState extends State<TodayReadingCard> {
  ReadingPlan? _plan;
  int _day = 1;
  Set<int> _done = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Reload when the user switches profiles — different profiles
    // can have different active plans + completion states.
    ProfileService.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    ProfileService.instance.removeListener(_refresh);
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
    final day = await ReadingPlanService.todayOfPlan(plan);
    final done = await ReadingPlanService.completedDays(plan.id);
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _day = day;
      _done = done;
      _loaded = true;
    });
  }

  Future<void> _toggleDone() async {
    final plan = _plan;
    if (plan == null) return;
    final isDone = _done.contains(_day);
    await ReadingPlanService.setDayCompleted(plan.id, _day, !isDone);
    final done = await ReadingPlanService.completedDays(plan.id);
    if (!mounted) return;
    setState(() => _done = done);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _plan == null) return const SizedBox.shrink();
    final plan = _plan!;
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final entry = plan.dayOf(_day);
    if (entry == null) return const SizedBox.shrink();
    final isDone = _done.contains(_day);
    final mainProvider = context.read<MainProvider>();

    final dayLabel = (uiStrings['planDayLabel']?[locale] ??
            'Day {day} of {total}')
        .replaceAll('{day}', _day.toString())
        .replaceAll('{total}', plan.days.toString());

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Material(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
        elevation: 1.5,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: _toggleDone,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.menu_book_outlined,
                        size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      uiStrings['todayReading']?[locale] ?? "Today's Reading",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _toggleDone,
                      icon: Icon(
                        isDone
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color:
                            isDone ? scheme.primary : scheme.outline,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                          minWidth: 28, minHeight: 28),
                      tooltip: isDone
                          ? (uiStrings['planMarkUndone']?[locale] ??
                              'Mark as unread')
                          : (uiStrings['planMarkDone']?[locale] ??
                              'Mark as done'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final r in entry.readings)
                      _Chip(
                        label: _localizeLabel(
                            r, mainProvider.currentVersion, locale),
                        onTap: () {
                          final ref = parseReference(r);
                          if (ref != null && widget.onJump != null) {
                            widget.onJump!(ref);
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build a localized chip label like "约 3" (zh-Hans) from the
  /// canonical "John 3" stored in the plan asset. Falls back to the
  /// canonical English when the version doesn't carry that book in
  /// its localised name table.
  String _localizeLabel(
      String canonical, String currentVersion, String locale) {
    // Parse out book + chapter; chip labels never include verse parts
    // because plan readings are whole chapters.
    final ref = parseReference(canonical);
    if (ref == null) return canonical;
    final localBook = translateBookName(ref.englishBook, currentVersion);
    return '$localBook ${ref.chapter}';
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.08),
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
              color: scheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
