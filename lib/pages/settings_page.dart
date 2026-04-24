import 'package:flutter/material.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:provider/provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_books.dart';
import 'package:yswords/services/fetch_verses.dart';

import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/utils/responsive.dart';

String getDevotionalFormattedText(
    List<Map<String, dynamic>> verses, String? book, int? chapter) {
  if (verses.isEmpty || book == null || chapter == null) return '';

  List<int> verseNums = verses.map((v) => v['verse'] as int).toList()..sort();
  List<String> textParts = verses.map((v) => v['text'] as String).toList();

  // Build reference string
  List<String> ranges = [];
  for (int i = 0; i < verseNums.length;) {
    int start = verseNums[i];
    int end = start;
    while (i + 1 < verseNums.length && verseNums[i + 1] == end + 1) {
      end = verseNums[++i];
    }
    ranges.add(start == end ? '$start' : '$start–$end');
    i++;
  }

  final ref = '$book $chapter:${ranges.join(',')}';
  final fullText = textParts.join('\n');
  return '$fullText\n($ref)';
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        // The settings locale is now available inside the Consumer below
        title: Consumer<AppSettings>(
          builder: (context, settings, _) =>
              Text(uiStrings['settings']?[settings.locale] ?? 'Settings'),
        ),
      ),
      body: Consumer<AppSettings>(
        builder: (context, settings, _) {
          final mainProvider = Provider.of<MainProvider>(context);
          final currentBook = mainProvider.currentBook;
          final currentChapter = mainProvider.currentChapter;

          final List<Color> palette = [
            Colors.red,
            Colors.deepOrange,
            Colors.orange,
            Colors.amber,
            Colors.yellow,
            Colors.lime,
            Colors.lightGreen,
            Colors.green,
            Colors.teal,
            Colors.cyan,
            Colors.lightBlue,
            Colors.blue,
            Colors.indigo,
            Colors.deepPurple,
            Colors.purple,
            Colors.pink,
            Colors.brown,
            Colors.grey,
            Colors.blueGrey,
          ];

          final versesInChapter = mainProvider.verses
              .where(
                  (v) => v.book == currentBook && v.chapter == currentChapter)
              .toList()
            ..sort((a, b) => a.verse.compareTo(b.verse));
          final verseSamples = versesInChapter
              .take(3)
              .map((v) => {'verse': v.verse, 'verseLabel': v.verseLabel, 'text': v.text})
              .toList();

          final dc = ResponsiveBreakpoints.classOf(
              MediaQuery.of(context).size.width);
          final maxW = ResponsiveBreakpoints.settingsMaxWidth(dc);
          final s = ResponsiveBreakpoints.spacingScale(dc);

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: ListView(
            padding: EdgeInsets.all(16 * s),
            children: [
              Card(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiStrings['fontSize']?[settings.locale] ?? 'Font Size',
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Slider(
                        value: settings.fontSize,
                        min: 12,
                        max: 40,
                        divisions: 28,
                        label: '${settings.fontSize.toInt()} pt',
                        onChanged: (val) => settings.setFontSize(val),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * s),
              Card(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiStrings['menuScale']?[settings.locale] ?? 'Menu Size',
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Slider(
                        value: settings.menuScale,
                        min: 0.7,
                        max: 1.5,
                        divisions: 8,
                        label: '${settings.menuScale.toStringAsFixed(1)}x',
                        onChanged: (val) => settings.setMenuScale(val),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * s),
              Card(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiStrings['lineSpacing']?[settings.locale] ??
                            'Line Spacing',
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Slider(
                        value: settings.lineSpacing,
                        min: 1.0,
                        max: 3.0,
                        divisions: 20,
                        label: settings.lineSpacing.toStringAsFixed(1),
                        onChanged: (val) => settings.setLineSpacing(
                            double.parse(val.toStringAsFixed(1))),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * s),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiStrings['samplePreview']?[settings.locale] ??
                            'Sample Preview',
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12 * s),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            uiStrings['copyFormat']?[settings.locale] ??
                                'Copy Format',
                            style: TextStyle(
                              fontFamily: settings.fontFamily,
                              fontSize: settings.fontSize + 2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8 * s),
                          DropdownButton<String>(
                            value: settings.copyFormat,
                            onChanged: (val) {
                              if (val != null) settings.setCopyFormat(val);
                            },
                            items: [
                              DropdownMenuItem(
                                  value: 'plain',
                                  child: Text(
                                    uiStrings['plainText']?[settings.locale] ??
                                        'Plain Text',
                                    style: TextStyle(
                                      fontSize: settings.fontSize,
                                      fontFamily: settings.fontFamily,
                                    ),
                                  )),
                              DropdownMenuItem(
                                  value: 'withRef',
                                  child: Text(
                                    uiStrings['withReference']
                                            ?[settings.locale] ??
                                        'With Reference',
                                    style: TextStyle(
                                      fontSize: settings.fontSize,
                                      fontFamily: settings.fontFamily,
                                    ),
                                  )),
                              DropdownMenuItem(
                                  value: 'devotional',
                                  child: Text(
                                    uiStrings['devotionalFormat']
                                            ?[settings.locale] ??
                                        'Devotional Format',
                                    style: TextStyle(
                                      fontSize: settings.fontSize,
                                      fontFamily: settings.fontFamily,
                                    ),
                                  )),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 12 * s),
                      Text(
                        currentBook != null && currentChapter != null
                            ? '$currentBook $currentChapter'
                            : uiStrings['noVersesAvailable']
                                    ?[settings.locale] ??
                                'No verses available',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontFamily: settings.fontFamily,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: settings.fontSize,
                                ),
                      ),
                      SizedBox(height: 8 * s),
                      SizedBox(height: 12 * s),
                      if (settings.copyFormat == 'devotional')
                        Padding(
                          padding:
                              EdgeInsets.only(bottom: settings.lineSpacing * 2),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: settings.fontSize,
                                fontFamily: settings.fontFamily,
                                height: settings.lineSpacing,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                              children: [
                                TextSpan(
                                  text: getDevotionalFormattedText(verseSamples,
                                      currentBook, currentChapter),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...verseSamples.map((v) {
                          final label = v['verseLabel'] as String;
                          final ref =
                              '${currentBook ?? ''} $currentChapter:$label';
                          String formattedText;
                          switch (settings.copyFormat) {
                            case 'withRef':
                              formattedText = '[$ref] ${v['text']}';
                              break;
                            case 'plain':
                            default:
                              formattedText = '$label ${v['text']}';
                          }
                          final cleanedText = formattedText
                              .replaceAll(RegExp(r'<[^>]*>'), '')
                              .replaceAll(RegExp(r'\{[^}]*\}'), '');

                          return Padding(
                            padding: EdgeInsets.only(
                                bottom: settings.lineSpacing * 2),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: settings.fontSize,
                                  fontFamily: settings.fontFamily,
                                  height: settings.lineSpacing,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color,
                                ),
                                children: [
                                  if (settings.copyFormat == 'plain') ...[
                                    TextSpan(
                                      text: '$label ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                    TextSpan(
                                      text: v['text']
                                          .toString()
                                          .replaceAll(RegExp(r'<[^>]*>'), '')
                                          .replaceAll(RegExp(r'\{[^}]*\}'), ''),
                                    ),
                                  ] else ...[
                                    TextSpan(text: cleanedText),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      // Removed Copy Preview button and its padding
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * s),
              Card(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiStrings['fontFamily']?[settings.locale] ??
                            'Font Family',
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12 * s),
                      DropdownButton<String>(
                        value: settings.fontFamily,
                        onChanged: (val) {
                          if (val != null) settings.setFontFamily(val);
                        },
                        items: [
                          DropdownMenuItem(
                            value: 'Roboto',
                            child: Text('Roboto',
                                style: TextStyle(
                                  fontSize: settings.fontSize,
                                  fontFamily: 'Roboto',
                                )),
                          ),
                          DropdownMenuItem(
                            value: 'Microsoft YaHei',
                            child: Text('Microsoft YaHei',
                                style: TextStyle(
                                  fontSize: settings.fontSize,
                                  fontFamily: 'Microsoft Yahei',
                                )),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * s),
              if (Theme.of(context).brightness != Brightness.dark) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          uiStrings['primaryColor']?[settings.locale] ??
                              'Primary Color',
                          style: TextStyle(
                            fontFamily: settings.fontFamily,
                            fontSize: settings.fontSize + 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 12 * s),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: palette.map((c) {
                            return GestureDetector(
                              onTap: () => settings.setPrimaryColor(c),
                              child: CircleAvatar(
                                backgroundColor: c,
                                radius: settings.fontSize * 0.8,
                                child: settings.primaryColor == c
                                    ? Icon(Icons.check,
                                        color: Colors.white,
                                        size: settings.fontSize * 0.6)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16 * s),
              ],
              Card(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiStrings['themeMode']?[settings.locale] ??
                            'Theme Mode',
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12 * s),
                      DropdownButton<ThemeMode>(
                        value: settings.themeMode,
                        onChanged: (val) {
                          if (val != null) settings.setThemeMode(val);
                        },
                        items: [
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text(
                              uiStrings['themeSystem']?[settings.locale] ??
                                  '跟隨系統',
                              style: TextStyle(
                                fontSize: settings.fontSize,
                                fontFamily: settings.fontFamily,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text(
                              uiStrings['themeDay']?[settings.locale] ?? '白天模式',
                              style: TextStyle(
                                fontSize: settings.fontSize,
                                fontFamily: settings.fontFamily,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text(
                              uiStrings['themeNight']?[settings.locale] ??
                                  '夜間模式',
                              style: TextStyle(
                                fontSize: settings.fontSize,
                                fontFamily: settings.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * s),
              Card(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiStrings['readingMode']?[settings.locale] ??
                            'Reading Mode',
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12 * s),
                      ToggleButtons(
                        isSelected: [!settings.paragraphMode, settings.paragraphMode],
                        onPressed: (index) =>
                            settings.setParagraphMode(index == 1),
                        borderRadius: BorderRadius.circular(8),
                        constraints: BoxConstraints(
                          minHeight: 36,
                          minWidth: (MediaQuery.of(context).size.width - 80) / 2,
                        ),
                        children: [
                          Text(
                            uiStrings['verseByVerse']?[settings.locale] ??
                                'Verse by Verse',
                            style: TextStyle(
                              fontSize: settings.fontSize * 0.9,
                              fontFamily: settings.fontFamily,
                            ),
                          ),
                          Text(
                            uiStrings['paragraphFlow']?[settings.locale] ??
                                'Paragraph Flow',
                            style: TextStyle(
                              fontSize: settings.fontSize * 0.9,
                              fontFamily: settings.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * s),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        uiStrings['offlineMode']?[settings.locale] ??
                            'Offline Mode',
                        style: TextStyle(
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                          fontFamily: settings.fontFamily,
                        ),
                      ),
                      subtitle: Text(
                        uiStrings['offlineModeSubtitle']?[settings.locale] ??
                            'All Bible data is bundled. No network connection required.',
                        style: TextStyle(
                          fontSize: settings.fontSize,
                          fontFamily: settings.fontFamily,
                        ),
                      ),
                      value: settings.offlineMode,
                      onChanged: (val) => settings.setOfflineMode(val),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.refresh_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: settings.fontSize + 4,
                      ),
                      title: Text(
                        uiStrings['checkForUpdates']?[settings.locale] ??
                            'Check for Updates',
                        style: TextStyle(
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                          fontFamily: settings.fontFamily,
                        ),
                      ),
                      subtitle: Text(
                        uiStrings['checkForUpdatesSubtitle']
                                ?[settings.locale] ??
                            'Refresh bundled Bible data and reload app.',
                        style: TextStyle(
                          fontSize: settings.fontSize,
                          fontFamily: settings.fontFamily,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        size: settings.fontSize + 4,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onTap: () => _onCheckForUpdates(context, settings),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16 * s),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiStrings['interfaceLanguage']?[settings.locale] ??
                            '界面语言',
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8 * s),
                      DropdownButton<String>(
                        value: settings.locale,
                        onChanged: (val) {
                          if (val != null) settings.setLocale(val);
                        },
                        items: [
                          DropdownMenuItem(
                            value: 'zh-Hans',
                            child: Text('简体中文',
                                style: TextStyle(
                                  fontSize: settings.fontSize,
                                  fontFamily: settings.fontFamily,
                                )),
                          ),
                          DropdownMenuItem(
                            value: 'zh-Hant',
                            child: Text('繁體中文',
                                style: TextStyle(
                                  fontSize: settings.fontSize,
                                  fontFamily: settings.fontFamily,
                                )),
                          ),
                          DropdownMenuItem(
                            value: 'en',
                            child: Text('English',
                                style: TextStyle(
                                  fontSize: settings.fontSize,
                                  fontFamily: settings.fontFamily,
                                )),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * s),
            ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Trigger an update check. Because Bible data is bundled with the app, an
  /// "update" is really a reload: reset the paragraph cache, re-fetch verses
  /// from the current bundle, and pop back to the reader. This gives users a
  /// concrete action tied to the Offline Mode card and surfaces the current
  /// app version so they can verify they're on the latest build.
  Future<void> _onCheckForUpdates(
      BuildContext context, AppSettings settings) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = ResponsiveBreakpoints.spacingScale(
        ResponsiveBreakpoints.classOf(MediaQuery.of(context).size.width));
    final mainProvider = context.read<MainProvider>();
    final localeTitle =
        uiStrings['updatesAvailableTitle']?[settings.locale] ??
            'You\'re up to date';
    final localeBody = uiStrings['updatesAvailableBody']?[settings.locale] ??
        'All Bible versions are bundled with the app. Data reloaded from local assets.';
    final okLabel = uiStrings['ok']?[settings.locale] ?? 'OK';
    final appVersion = _currentAppVersion;

    // Reload verses from bundle (refreshes paragraph cache too).
    try {
      // Re-import dynamically via a dedicated helper so this stateless widget
      // stays free of heavier imports.
      await _reloadVerses(mainProvider);
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Reload failed: $e'),
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.check_circle_outline,
            color: Theme.of(ctx).colorScheme.primary,
            size: settings.fontSize * 2),
        title: Text(
          localeTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: settings.fontSize + 2,
            fontWeight: FontWeight.w600,
            fontFamily: settings.fontFamily,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              localeBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: settings.fontSize,
                fontFamily: settings.fontFamily,
              ),
            ),
            SizedBox(height: 12 * s),
            Text(
              'v$appVersion',
              style: TextStyle(
                fontSize: settings.fontSize * 0.85,
                fontFamily: settings.fontFamily,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              okLabel,
              style: TextStyle(
                fontSize: settings.fontSize,
                fontFamily: settings.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bumped manually from pubspec.yaml. Kept at top-level so tests can read it.
const String _currentAppVersion = '0.1.0';

/// Re-fetch verses from the bundled assets so the reader re-reads the latest
/// shipped data. Paragraph cache is preserved — it's keyed by english book
/// name and doesn't change between reloads within the same app version.
Future<void> _reloadVerses(MainProvider mainProvider) async {
  await FetchVerses.execute(mainProvider: mainProvider);
  await FetchBooks.execute(mainProvider: mainProvider);
}
