import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/sermon.dart';
import 'package:yswords/pages/sermon_detail_page.dart';
import 'package:yswords/services/sermon_service.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Topic-grouped browser for the Pastor Eric sermon corpus.
///
/// Layout mirrors the illustrations page and Bible-evidence page so
/// the UX is consistent:
///   - sticky AppBar with search field
///   - 20 collapsible topic groups (`ExpansionTile`), each showing
///     the sermon count in the header
///   - tap a sermon row → opens [SermonDetailPage] in the user's
///     preferred language (with cross-language fallback)
class SermonsPage extends StatefulWidget {
  const SermonsPage({super.key});

  @override
  State<SermonsPage> createState() => _SermonsPageState();
}

class _SermonsPageState extends State<SermonsPage> {
  Future<Map<String, List<Sermon>>>? _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = SermonService.instance.loadByTopic();
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
      body: FutureBuilder<Map<String, List<Sermon>>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load sermons: ${snap.error}',
                    style: TextStyle(color: scheme.error)),
              ),
            );
          }
          final groups = _filtered(snap.data!, _query);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: uiStrings['sermonSearchHint']?[locale] ??
                        'Search sermons by title or passage…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
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
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (final entry in groups.entries)
                      _TopicGroup(topic: entry.key, sermons: entry.value),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, List<Sermon>> _filtered(
      Map<String, List<Sermon>> groups, String query) {
    if (query.isEmpty) return groups;
    final q = query.toLowerCase();
    final out = <String, List<Sermon>>{};
    for (final e in groups.entries) {
      final hits = e.value.where((s) {
        return s.title.toLowerCase().contains(q) ||
            s.passage.toLowerCase().contains(q) ||
            s.id.toLowerCase().contains(q);
      }).toList();
      if (hits.isNotEmpty) out[e.key] = hits;
    }
    return out;
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
}

class _TopicGroup extends StatelessWidget {
  final String topic;
  final List<Sermon> sermons;

  const _TopicGroup({required this.topic, required this.sermons});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          topic,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${sermons.length} sermon${sermons.length == 1 ? '' : 's'}',
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        children: [
          for (final s in sermons) _SermonRow(sermon: s),
        ],
      ),
    );
  }
}

class _SermonRow extends StatelessWidget {
  final Sermon sermon;

  const _SermonRow({required this.sermon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      title: Text(
        sermon.title.isEmpty ? '#${sermon.id}' : sermon.title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Padding(
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
            if (sermon.passage.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  sermon.passage,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
      trailing: Icon(Icons.chevron_right,
          size: 20, color: scheme.onSurface.withValues(alpha: 0.4)),
      onTap: () => Get.to(
        () => SermonDetailPage(sermon: sermon),
        transition: Transition.rightToLeft,
      ),
    );
  }
}
