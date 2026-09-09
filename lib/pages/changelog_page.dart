// 更新记录 — what changed, and when.
//
// From the owner on 2026-09-09: 「也要有历史的release note但是不要全部
// 的而是足够的不然太多」. The "不要全部" half is answered by
// `tools/build_changelog.py`, which bundles an 81-version window. The
// "不然太多" half is answered HERE, and the two halves needed different
// answers.
//
// **What makes a changelog for this app unreadable is not the notes,
// it is the version numbers.** The bundled window is 81 versions
// carrying 248 changes across 15 days — so a version-per-row list is
// eighty-one rows of "1.5.x" with a line or two under each, and the
// reader has to work out for themselves that six of them were one
// afternoon. Grouping by DAY collapses that to fifteen headings
// without discarding a single note. The version number stays as a
// quiet label beside its own changes, because "which version was that
// in" is the other question this page gets asked.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/app_version.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/changelog_service.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/update_service.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

class ChangelogPage extends StatefulWidget {
  const ChangelogPage({super.key});

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  late final Future<List<ChangelogDay>> _days = ChangelogService.load();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['changelogTitle']?[locale] ?? "What's new"),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: FutureBuilder<List<ChangelogDay>>(
        future: _days,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final days = snap.data!;
          if (days.isEmpty) return _empty(context, settings);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                // +1 for the footer, which is part of the honest
                // answer: this page shows a window, and says where the
                // rest is.
                itemCount: days.length + 1,
                itemBuilder: (context, i) => i == days.length
                    ? _footer(context, settings)
                    : _day(context, settings, days[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  TextStyle _style(AppSettings s, double size,
          {FontWeight? weight, Color? color, double? height}) =>
      TextStyle(
        fontFamily: s.fontFamily,
        fontFamilyFallback: kCjkFontFallback,
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color,
      );

  Widget _day(BuildContext context, AppSettings s, ChangelogDay day) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                day.date,
                style: _style(s, s.fontSize + 1,
                    weight: FontWeight.w700, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              // Changes, not versions. How often we deploy is our
              // business; what changed is theirs.
              Text(
                (uiStrings['changelogCount']?[s.locale] ?? '{n} changes')
                    .replaceAll('{n}', '${day.noteCount}'),
                style: _style(s, s.fontSize - 3,
                    color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          for (final version in day.versions) _version(context, s, version),
        ],
      ),
    );
  }

  Widget _version(BuildContext context, AppSettings s, ChangelogEntry entry) {
    final scheme = Theme.of(context).colorScheme;
    final running = entry.version == kAppVersion;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'v${entry.version}',
                style: _style(s, s.fontSize - 3,
                    weight: FontWeight.w600, color: scheme.onSurfaceVariant),
              ),
              // The reader's own build, marked. This page's second
              // question is "which version was that in", and the
              // useful half of that is "is it in mine".
              if (running) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    uiStrings['changelogYours']?[s.locale] ?? 'yours',
                    style: _style(s, s.fontSize - 3,
                        color: scheme.onPrimaryContainer),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          for (final note in entry.notes)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('·  ',
                      style: _style(s, s.fontSize,
                          color: scheme.onSurfaceVariant)),
                  // No maxLines: a note that does not fit makes the row
                  // taller. Truncating a changelog entry hides exactly
                  // the clause that says what changed — these subjects
                  // put it at the end.
                  Expanded(
                    child: Text(
                      note,
                      style: _style(s, s.fontSize,
                          height: 1.5, color: scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, AppSettings s) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uiStrings['changelogWindow']?[s.locale] ??
                'This page shows recent releases. Older ones are on GitHub.',
            style: _style(s, s.fontSize - 3,
                height: 1.5, color: scheme.onSurfaceVariant),
          ),
          if (LinkOpener.isAvailable)
            TextButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(
                uiStrings['changelogAllOnGitHub']?[s.locale] ??
                    'All releases on GitHub',
              ),
              onPressed: () => LinkOpener.openOrWarn(
                context,
                'https://github.com/${UpdateService.repo}/releases',
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, AppSettings s) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            uiStrings['changelogEmpty']?[s.locale] ??
                'No release notes are bundled with this build.',
            textAlign: TextAlign.center,
            style: _style(s, s.fontSize,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
}
