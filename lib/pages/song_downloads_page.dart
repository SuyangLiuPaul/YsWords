import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/services/song_download_service.dart';
import 'package:yswords/services/song_download_types.dart';
import 'package:yswords/services/song_service.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Manage downloaded songs: what is stored, how much space it uses,
/// and removing it again.
///
/// On web this page states plainly that downloads are unavailable
/// rather than hiding — someone who went looking for the feature
/// deserves to know why it is not there.
class SongDownloadsPage extends StatefulWidget {
  const SongDownloadsPage({super.key});

  @override
  State<SongDownloadsPage> createState() => _SongDownloadsPageState();
}

class _SongDownloadsPageState extends State<SongDownloadsPage> {
  final _service = SongDownloadService.instance;
  Future<List<Song>>? _catalogue;

  @override
  void initState() {
    super.initState();
    _catalogue = SongService.load();
    _service.init();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    final maxW = ResponsiveBreakpoints.settingsMaxWidth(
        ResponsiveBreakpoints.classOf(MediaQuery.of(context).size.width));

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['songsDownloads']?[locale] ?? 'Downloads'),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: !SongDownloadService.isSupported
              ? _UnsupportedNotice(scheme: scheme, locale: locale)
              : FutureBuilder<List<Song>>(
                  future: _catalogue,
                  builder: (context, snap) {
                    final catalogue = snap.data ?? const <Song>[];
                    return ListenableBuilder(
                      listenable: _service,
                      builder: (context, _) {
                        final downloaded = catalogue
                            .where(_service.isDownloaded)
                            .toList();
                        // Failures were invisible: the page listed only
                        // what succeeded, so a batch where five songs
                        // 404'd showed 42 of 47 and never said why. A
                        // silent shortfall reads as a bug in the app.
                        final failed = catalogue
                            .where((s) =>
                                _service.statusOf(s).state ==
                                SongDownloadState.failed)
                            .toList();
                        return ListView(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: [
                            _SummaryCard(
                              count: downloaded.length,
                              bytes: _service.totalBytes,
                              pending: _service.pendingCount,
                              progress: _service.batchProgress,
                              batchDone: _service.batchDone,
                              batchTotal: _service.batchTotal,
                              scheme: scheme,
                              locale: locale,
                              onCancel: _service.cancelAll,
                              onDeleteAll: downloaded.isEmpty
                                  ? null
                                  : () => _confirmDeleteAll(locale),
                            ),
                            const SizedBox(height: 12),
                            if (failed.isNotEmpty) ...[
                              Row(
                                children: [
                                  Icon(Icons.error_outline_rounded,
                                      size: 18, color: scheme.error),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      uiStrings['songsDownloadsFailed']
                                              ?[locale] ??
                                          'Could not be downloaded',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.error,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _service.enqueue(failed),
                                    child: Text(
                                        uiStrings['songsRetryDownload']
                                                ?[locale] ??
                                            'Retry'),
                                  ),
                                ],
                              ),
                              for (final s in failed)
                                _FailedTile(
                                  song: s,
                                  settings: settings,
                                  scheme: scheme,
                                  error: _service.statusOf(s).error,
                                  onRetry: () => _service.enqueue([s]),
                                ),
                              const SizedBox(height: 16),
                            ],
                            if (downloaded.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: Text(
                                  uiStrings['songsNoDownloads']?[locale] ??
                                      'Nothing downloaded yet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: scheme.onSurfaceVariant),
                                ),
                              ),
                            for (final s in downloaded)
                              _DownloadedTile(
                                song: s,
                                settings: settings,
                                scheme: scheme,
                                bytes: _service.statusOf(s).bytes,
                                onDelete: () => _service.delete(s),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _confirmDeleteAll(String locale) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(uiStrings['songsDeleteAll']?[locale] ?? 'Delete all'),
        content: Text(uiStrings['songsDeleteAllBody']?[locale] ??
            'Remove every downloaded song from this device? They can be '
                'downloaded again at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(uiStrings['cancel']?[locale] ?? 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () {
              _service.deleteAll();
              Navigator.of(ctx).pop();
            },
            child: Text(uiStrings['delete']?[locale] ?? 'Delete'),
          ),
        ],
      ),
    );
  }
}

class _UnsupportedNotice extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  const _UnsupportedNotice({required this.scheme, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_for_offline_outlined,
              size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            uiStrings['songsDownloadsWebOnly']?[locale] ??
                'Downloads are available in the app, not the browser. A '
                    'web page has no storage this can manage, and the '
                    'catalogue is around 2.5 GB of audio.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int count;
  final int bytes;
  final int pending;
  final double progress;
  final int batchDone;
  final int batchTotal;
  final ColorScheme scheme;
  final String locale;
  final VoidCallback onCancel;
  final VoidCallback? onDeleteAll;

  const _SummaryCard({
    required this.count,
    required this.bytes,
    required this.pending,
    required this.progress,
    required this.batchDone,
    required this.batchTotal,
    required this.scheme,
    required this.locale,
    required this.onCancel,
    required this.onDeleteAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.download_done_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$count · ${formatDownloadBytes(bytes)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              if (onDeleteAll != null)
                TextButton(
                  onPressed: onDeleteAll,
                  child: Text(
                      uiStrings['songsDeleteAll']?[locale] ?? 'Delete all'),
                ),
            ],
          ),
          if (pending > 0) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$batchDone / $batchTotal',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
                TextButton(
                  onPressed: onCancel,
                  child: Text(uiStrings['cancel']?[locale] ?? 'Cancel'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DownloadedTile extends StatelessWidget {
  final Song song;
  final AppSettings settings;
  final ColorScheme scheme;
  final int bytes;
  final VoidCallback onDelete;

  const _DownloadedTile({
    required this.song,
    required this.settings,
    required this.scheme,
    required this.bytes,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.check_circle_rounded, color: scheme.primary),
      title: Text(
        song.title,
        style: TextStyle(
          fontFamily: settings.fontFamily,
          fontFamilyFallback: kCjkFontFallback,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        '${song.sourceLabel}'
        '${bytes > 0 ? ' · ${formatDownloadBytes(bytes)}' : ''}',
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded, size: 20),
        onPressed: onDelete,
      ),
    );
  }
}

/// A download that did not finish, with the reason and a way to try
/// again. Shown because the alternative — leaving it out of the list —
/// makes a partial batch look like a broken app.
class _FailedTile extends StatelessWidget {
  final Song song;
  final AppSettings settings;
  final ColorScheme scheme;
  final String? error;
  final VoidCallback onRetry;

  const _FailedTile({
    required this.song,
    required this.settings,
    required this.scheme,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.cloud_off_rounded, color: scheme.error),
      title: Text(
        song.title,
        style: TextStyle(
          fontFamily: settings.fontFamily,
          fontFamilyFallback: kCjkFontFallback,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        // The upstream reason, not a generic apology — "HTTP 404" tells
        // the church a file is missing from their server.
        error ?? song.sourceLabel,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.refresh_rounded, size: 20),
        tooltip: 'Retry',
        onPressed: onRetry,
      ),
    );
  }
}
