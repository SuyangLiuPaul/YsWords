import 'package:flutter/material.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:provider/provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:get/get.dart';
import 'package:yswords/pages/profiles_page.dart';
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/widgets/google_g_logo.dart';
import 'package:yswords/services/cloud_sync_service.dart';
import 'package:yswords/services/fetch_books.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/services/reading_plan_service.dart';

import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/utils/responsive.dart';

String getDevotionalFormattedText(
    List<Map<String, dynamic>> verses, String? book, int? chapter) {
  if (verses.isEmpty || book == null || chapter == null) return '';

  List<int> verseNums = verses.map((v) => v['verse'] as int).toList()..sort();
  List<String> textParts = verses.map((v) {
    var t = v['text'] as String;
    t = t.replaceAll(RegExp(r'<note:[^>]*>'), '')
         .replaceAll(RegExp(r'<[^>]*>'), '')
         .replaceAll(RegExp(r'\{[^}]*\}'), '');
    return t;
  }).toList();

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
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 300) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
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
                              .replaceAll(RegExp(r'\{[^}]*\}'), '')
                              .replaceAll(RegExp(r'\[[^\]]*\]'), '');

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
              // Primary Color card - always visible (dark + light)
                Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16 * s, vertical: 12 * s),
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
                          spacing: 10,
                          runSpacing: 10,
                          children: palette.map((c) {
                            final isSelected = settings.primaryColor == c;
                            // Floor the avatar at ~22 dp so the swatch
                            // never falls below a comfortable tap
                            // target even when the user shrinks the
                            // font size to its minimum.
                            final avatarRadius =
                                (settings.fontSize * 0.8).clamp(20.0, 28.0);
                            return InkWell(
                              borderRadius: BorderRadius.circular(40),
                              onTap: () => settings.setPrimaryColor(c),
                              child: Padding(
                                // Padding pushes the actual hit-test
                                // size up past 44 dp on every device
                                // class without changing the visual
                                // size of the swatch.
                                padding: const EdgeInsets.all(4),
                                child: CircleAvatar(
                                  backgroundColor: c,
                                  radius: avatarRadius,
                                  child: isSelected
                                      ? Icon(Icons.check,
                                          color:
                                              c.computeLuminance() > 0.5
                                                  ? Colors.black
                                                  : Colors.white,
                                          size: settings.fontSize * 0.6)
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16 * s),
              SizedBox(height: 16 * s),
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
                                  'System Default',
                              style: TextStyle(
                                fontSize: settings.fontSize,
                                fontFamily: settings.fontFamily,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text(
                              uiStrings['themeDay']?[settings.locale] ?? 'Light Mode',
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
                                  'Dark Mode',
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
                      LayoutBuilder(
                        builder: (context, toggleConstraints) {
                          return ToggleButtons(
                            isSelected: [!settings.paragraphMode, settings.paragraphMode],
                            onPressed: (index) =>
                                settings.setParagraphMode(index == 1),
                            borderRadius: BorderRadius.circular(8),
                            constraints: BoxConstraints(
                              minHeight: 36,
                              minWidth: (toggleConstraints.maxWidth - 8) / 2,
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
                          );
                        },
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
                    SwitchListTile(
                      title: Text(
                        uiStrings['boldVerseText']?[settings.locale] ??
                            'Bold verse text',
                        style: TextStyle(
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                          fontFamily: settings.fontFamily,
                        ),
                      ),
                      subtitle: Text(
                        uiStrings['boldVerseTextSubtitle']?[settings.locale] ??
                            'Render scripture body text in semi-bold weight.',
                        style: TextStyle(
                          fontSize: settings.fontSize,
                          fontFamily: settings.fontFamily,
                        ),
                      ),
                      value: settings.boldVerseText,
                      onChanged: (val) => settings.setBoldVerseText(val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(
                        uiStrings['showStrongsBadge']?[settings.locale] ??
                            "Show Strong's number on word chips",
                        style: TextStyle(
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                          fontFamily: settings.fontFamily,
                        ),
                      ),
                      subtitle: Text(
                        uiStrings['showStrongsBadgeSubtitle']
                                ?[settings.locale] ??
                            "Display the G#### / H#### badge under each Hebrew/Greek word in the exegesis sheet.",
                        style: TextStyle(
                          fontSize: settings.fontSize,
                          fontFamily: settings.fontFamily,
                        ),
                      ),
                      value: settings.showStrongsInOriginals,
                      onChanged: (val) =>
                          settings.setShowStrongsInOriginals(val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(
                        uiStrings['autoExpandFirstRef']?[settings.locale] ??
                            'Auto-expand first verse group',
                        style: TextStyle(
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                          fontFamily: settings.fontFamily,
                        ),
                      ),
                      subtitle: Text(
                        uiStrings['autoExpandFirstRefSubtitle']
                                ?[settings.locale] ??
                            "Automatically open the first book group of concordance refs in the exegesis sheet.",
                        style: TextStyle(
                          fontSize: settings.fontSize,
                          fontFamily: settings.fontFamily,
                        ),
                      ),
                      value: settings.autoExpandFirstRef,
                      onChanged: (val) =>
                          settings.setAutoExpandFirstRef(val),
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
                            'Interface Language',
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
              _AccountSection(settings: settings, s: s),
              SizedBox(height: 16 * s),
              _ReadingPlanSection(settings: settings, s: s),
              SizedBox(height: 16 * s),
            ],
              ),
            ),
          );
        },
      ),
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

/// Settings card for picking a reading plan, choosing the start
/// date, and resetting completion progress. Lives at the bottom of
/// the settings list because it's an opt-in feature and most users
/// will never touch it.
class _ReadingPlanSection extends StatefulWidget {
  final AppSettings settings;
  final double s;
  const _ReadingPlanSection({required this.settings, required this.s});

  @override
  State<_ReadingPlanSection> createState() => _ReadingPlanSectionState();
}

class _ReadingPlanSectionState extends State<_ReadingPlanSection> {
  List<ReadingPlan> _plans = [];
  String? _activeId;
  DateTime? _startDate;
  bool _useDate = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Refresh on profile switch so the dropdown / start-date row
    // reflect whichever account is signed in.
    ProfileService.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    ProfileService.instance.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final plans = await ReadingPlanService.all();
    final active = await ReadingPlanService.activeId();
    final start = await ReadingPlanService.startDate();
    final useDate = await ReadingPlanService.useDateMode();
    if (!mounted) return;
    setState(() {
      _plans = plans;
      _activeId = active;
      _startDate = start;
      _useDate = useDate;
      _loaded = true;
    });
  }

  Future<void> _confirmReset() async {
    final locale = widget.settings.locale;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(uiStrings['planResetProgress']?[locale] ?? 'Reset Progress'),
        content: Text(uiStrings['planResetProgressConfirm']?[locale] ??
            'Clear all completion marks for this plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(uiStrings['cancel']?[locale] ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(uiStrings['planResetProgress']?[locale] ??
                'Reset Progress'),
          ),
        ],
      ),
    );
    if (ok == true && _activeId != null) {
      await ReadingPlanService.resetProgress(_activeId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(uiStrings['planResetProgress']?[locale] ?? 'Reset'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final initial = _startDate ?? DateTime(now.year, now.month, now.day);
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (d != null) {
      await ReadingPlanService.setStartDate(d);
      if (!mounted) return;
      setState(() => _startDate = d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final s = widget.s;
    final locale = settings.locale;
    if (!_loaded) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16 * s),
          child: const SizedBox(
            height: 24,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              uiStrings['readingPlans']?[locale] ?? 'Reading Plans',
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontSize: settings.fontSize + 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8 * s),
            Text(
              uiStrings['planChooseActive']?[locale] ?? 'Choose Reading Plan',
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontSize: settings.fontSize,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 6 * s),
            DropdownButton<String?>(
              value: _activeId,
              isExpanded: true,
              hint: Text(
                uiStrings['planNoActive']?[locale] ?? 'No reading plan',
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontSize: settings.fontSize,
                ),
              ),
              onChanged: (val) async {
                await ReadingPlanService.setActiveId(val);
                if (val != null && _startDate == null) {
                  // Default start date to today the first time a plan
                  // is selected so the user immediately sees Day 1.
                  await ReadingPlanService.setStartDate(DateTime.now());
                }
                await _refresh();
              },
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    uiStrings['planNone']?[locale] ?? 'No plan',
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontSize: settings.fontSize,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final p in _plans)
                  DropdownMenuItem<String?>(
                    value: p.id,
                    child: Text(
                      p.localizedName(locale),
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontSize: settings.fontSize,
                      ),
                    ),
                  ),
              ],
            ),
            if (_activeId != null) ...[
              SizedBox(height: 8 * s),
              Text(
                _plans
                        .firstWhere(
                          (p) => p.id == _activeId,
                          orElse: () => _plans.first,
                        )
                        .localizedDescription(locale),
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontSize: settings.fontSize - 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 12 * s),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  uiStrings['planUseCalendarDate']?[locale] ??
                      'Use calendar date',
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontSize: settings.fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  uiStrings['planUseCalendarDateSub']?[locale] ??
                      'Off = day-of-year (resets every Jan 1).',
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontSize: settings.fontSize - 2,
                  ),
                ),
                value: _useDate,
                onChanged: (val) async {
                  await ReadingPlanService.setUseDateMode(val);
                  if (!mounted) return;
                  setState(() => _useDate = val);
                },
              ),
              if (_useDate)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(
                    uiStrings['planStartDate']?[locale] ?? 'Start date',
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontSize: settings.fontSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    _startDate == null
                        ? '—'
                        : '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontSize: settings.fontSize - 1,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickStartDate,
                ),
              SizedBox(height: 4 * s),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _confirmReset,
                  icon: Icon(Icons.refresh,
                      color: Theme.of(context).colorScheme.error),
                  label: Text(
                    uiStrings['planResetProgress']?[locale] ??
                        'Reset Progress',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: settings.fontSize,
                      fontFamily: settings.fontFamily,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


/// Settings card for the local "account" / profile system. Shows
/// the active profile name and a row to open the full profile
/// switcher (lib/pages/profiles_page.dart). Listens to
/// ProfileService changes so the displayed name updates as soon
/// as the user switches.
class _AccountSection extends StatefulWidget {
  final AppSettings settings;
  final double s;
  const _AccountSection({required this.settings, required this.s});

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  @override
  void initState() {
    super.initState();
    ProfileService.instance.addListener(_onChanged);
    CloudAuthService.instance.addListener(_onChanged);
    CloudSyncService.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    ProfileService.instance.removeListener(_onChanged);
    CloudAuthService.instance.removeListener(_onChanged);
    CloudSyncService.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Map sync status to a colored chip with an icon + label, so the
  /// user can see "Synced" / "Syncing..." / "Error" / "Local-only"
  /// at a glance.
  Widget _syncBadge(BuildContext context, String locale) {
    final auth = CloudAuthService.instance;
    final sync = CloudSyncService.instance;
    final scheme = Theme.of(context).colorScheme;
    if (!auth.isConfigured) {
      return _badge(
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.cloud_off_outlined,
        uiStrings['cloudNotConfigured']?[locale] ?? 'Local only',
      );
    }
    if (!auth.isSignedIn) {
      return _badge(
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.cloud_outlined,
        uiStrings['cloudNotSignedIn']?[locale] ?? 'Not signed in',
      );
    }
    switch (sync.status) {
      case CloudSyncStatus.disabled:
        return _badge(
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          Icons.cloud_outlined,
          uiStrings['cloudNotSignedIn']?[locale] ?? 'Not signed in',
        );
      case CloudSyncStatus.syncing:
        return _badge(
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.cloud_sync_outlined,
          uiStrings['cloudSyncing']?[locale] ?? 'Syncing…',
        );
      case CloudSyncStatus.synced:
        return _badge(
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          Icons.cloud_done_outlined,
          uiStrings['cloudSynced']?[locale] ?? 'Synced',
        );
      case CloudSyncStatus.error:
        return _badge(
          scheme.errorContainer,
          scheme.error,
          Icons.cloud_off_outlined,
          uiStrings['cloudError']?[locale] ?? 'Sync error',
        );
    }
  }

  Widget _badge(Color bg, Color fg, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final s = widget.s;
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final p = ProfileService.instance.current;
    final auth = CloudAuthService.instance;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    uiStrings['profileTitle']?[locale] ?? 'Profiles',
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontSize: settings.fontSize + 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _syncBadge(context, locale),
              ],
            ),
            SizedBox(height: 8 * s),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                child: Text(
                  p.name.isEmpty
                      ? "?"
                      : p.name.characters.first.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              title: Text(
                p.name,
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontSize: settings.fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                auth.isSignedIn
                    ? '${uiStrings["profileCurrent"]?[locale] ?? "Active profile"} • ${auth.currentUser?.email ?? ""}'
                    : (uiStrings["profileCurrent"]?[locale] ??
                        "Active profile"),
                style: TextStyle(
                  fontSize: settings.fontSize - 2,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.to(
                () => const ProfilesPage(),
                transition: Transition.rightToLeft,
              ),
            ),
            // Cloud-sync row — Sign in / Sign out depending on state.
            if (auth.isConfigured) ...[
              const Divider(height: 24),
              if (!auth.isSignedIn)
                OutlinedButton(
                  onPressed: () async {
                    final result = await CloudAuthService.instance
                        .signInWithGoogle();
                    if (!context.mounted) return;
                    if (!result.isOk) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result.errorMessage ?? 'Sign-in failed.',
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      return;
                    }
                    final user = result.user!;
                    final svc = ProfileService.instance;
                    final namePart =
                        user.displayName?.trim().isNotEmpty == true
                            ? user.displayName!.trim()
                            : (user.email ?? 'user').split('@').first;
                    final existing = svc.profiles.where((p) =>
                        p.name.toLowerCase() ==
                        namePart.toLowerCase());
                    if (existing.isNotEmpty) {
                      await svc.setCurrent(existing.first.id);
                    } else {
                      final p = await svc.create(namePart);
                      await svc.setCurrent(p.id);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1F1F1F),
                    side: const BorderSide(
                        color: Color(0xFFDADCE0), width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GoogleGLogo(size: 18),
                      const SizedBox(width: 12),
                      Text(
                        uiStrings['cloudSignInGoogle']?[locale] ??
                            'Sign in with Google',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (uiStrings['cloudSignedInAs']?[locale] ??
                                'Cloud-synced as {email}')
                            .replaceAll(
                                '{email}', auth.currentUser?.email ?? ''),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => CloudAuthService.instance.signOut(),
                      icon: const Icon(Icons.logout, size: 16),
                      label: Text(
                        uiStrings['cloudSignOut']?[locale] ?? 'Sign out',
                      ),
                    ),
                  ],
                ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                auth.isConfigured
                    ? (uiStrings['cloudPrivacyNotice']?[locale] ??
                        'Cloud sync uses your own Firebase project. Each user can only read their own data.')
                    : (uiStrings["welcomeLocalOnlyNotice"]?[locale] ??
                        "Profiles are stored only on this device. No password, no server."),
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
