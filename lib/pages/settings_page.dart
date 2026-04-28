import 'package:flutter/material.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:provider/provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:get/get.dart';
import 'package:yswords/pages/profiles_page.dart';
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/widgets/google_g_logo.dart';
import 'dart:async' show Timer;

import 'package:yswords/services/cloud_sync_service.dart';
import 'package:yswords/services/notification_service.dart';
import 'package:yswords/widgets/contact_line.dart';
import 'package:yswords/widgets/profile_avatar.dart';
import 'package:yswords/services/fetch_books.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/services/reading_plan_service.dart';

import 'package:yswords/widgets/home_icon_button.dart';
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
        actions: const [HomeIconButton()],
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
              _SectionHeader(
                  uiStrings['settingsSectionDisplay']?[settings.locale] ??
                      'Display'),
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
              _SectionHeader(
                  uiStrings['settingsSectionReading']?[settings.locale] ??
                      'Reading'),
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
              _SectionHeader(
                  uiStrings['settingsSectionApp']?[settings.locale] ??
                      'App'),
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
              _SectionHeader(
                  uiStrings['settingsSectionAccount']?[settings.locale] ??
                      'Account'),
              _AccountSection(settings: settings, s: s),
              SizedBox(height: 16 * s),
              _SectionHeader(
                  uiStrings['settingsSectionPlan']?[settings.locale] ??
                      'Reading plans'),
              _ReadingPlanSection(settings: settings, s: s),
              SizedBox(height: 16 * s),
              _SectionHeader(
                  uiStrings['settingsSectionDashboard']?[settings.locale] ??
                      'Dashboard sections'),
              _DashboardSectionsCard(settings: settings, s: s),
              SizedBox(height: 16 * s),
              _SectionHeader(
                  uiStrings['settingsSectionNotifications']
                          ?[settings.locale] ??
                      'Notifications'),
              _NotificationsCard(settings: settings, s: s),
              SizedBox(height: 16 * s),
              _SectionHeader(
                  uiStrings['settingsSectionAbout']?[settings.locale] ??
                      'About'),
              _AboutCard(settings: settings, s: s),
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
              // Resolution priority matches the Dashboard greeting:
              // signed-in Google photo first, then locally-uploaded
              // photo, then color tile + initial. Keeps the avatar
              // visually consistent across the app.
              leading: ProfileAvatar(
                photoUrl: auth.currentUser?.photoURL ?? p.photoDataUrl,
                name: p.name,
                avatarColor: p.avatarColorArgb,
                radius: 22,
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
                    final messenger = ScaffoldMessenger.of(context);
                    final result = await CloudAuthService.instance
                        .signInWithGoogleAndAdoptProfile();
                    if (!context.mounted) return;
                    if (!result.isOk) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            result.errorMessage ?? 'Sign-in failed.',
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
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
                          fontFamily: settings.fontFamily,
                          fontSize: (settings.fontSize - 6)
                              .clamp(12.0, 15.0).toDouble(),
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
              if (auth.isSignedIn) ...[
                SizedBox(height: 6 * s),
                _SyncStatusRow(settings: settings),
              ],
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
                  fontFamily: settings.fontFamily,
                  fontSize: (settings.fontSize - 7)
                      .clamp(12.0, 14.0).toDouble(),
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

/// Compact uppercase section divider that sits above a group of
/// related cards in the settings list. Round 34 added these to
/// give the long settings list visual structure (Display / Reading
/// / App / Account / Reading plans) without forcing a refactor of
/// the existing card layout.
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Scale with the user's font preference — at the default 16 pt
    // body size the header reads as 14, at 24 pt body it scales to
    // 22. Caps at 22 so very-large reader settings don't make
    // section headers tower over the cards beneath them.
    final settings = context.watch<AppSettings>();
    final size =
        (settings.fontSize - 2).clamp(11.0, 22.0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: settings.fontFamily,
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: scheme.primary,
        ),
      ),
    );
  }
}

/// Card with three switches: Today's Headlines, Today's Evidence, and
/// Today's Reading. When toggled off, the matching dashboard card AND
/// the matching quick-link tile are hidden. Lets users keep YsWords
/// focused on the parts they actually use.
class _DashboardSectionsCard extends StatelessWidget {
  final AppSettings settings;
  final double s;
  const _DashboardSectionsCard({required this.settings, required this.s});

  @override
  Widget build(BuildContext context) {
    final locale = settings.locale;
    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(8 * s, 4 * s, 8 * s, 4 * s),
        child: Column(
          children: [
            _SettingsSwitch(
              icon: Icons.newspaper_outlined,
              label: uiStrings['dailyNews']?[locale] ?? 'Daily News',
              subtitle: uiStrings['settingsShowDailyNewsHint']?[locale] ??
                  "Today's Headlines card + quick-link tile.",
              value: settings.showDailyNews,
              onChanged: (v) => settings.setShowDailyNews(v),
              settings: settings,
            ),
            _SettingsSwitch(
              icon: Icons.museum_outlined,
              label: uiStrings['bibleEvidence']?[locale] ?? 'Bible Evidence',
              subtitle:
                  uiStrings['settingsShowEvidenceHint']?[locale] ??
                      "Today's Evidence card + quick-link tile.",
              value: settings.showBibleEvidence,
              onChanged: (v) => settings.setShowBibleEvidence(v),
              settings: settings,
            ),
            _SettingsSwitch(
              icon: Icons.menu_book_outlined,
              label:
                  uiStrings['todayReading']?[locale] ?? "Today's Reading",
              subtitle: uiStrings['settingsShowPlanHint']?[locale] ??
                  'Active reading-plan card on the dashboard.',
              value: settings.showReadingPlan,
              onChanged: (v) => settings.setShowReadingPlan(v),
              settings: settings,
            ),
          ],
        ),
      ),
    );
  }
}

/// Single switch row used by [_DashboardSectionsCard] and
/// [_NotificationsCard]. Keeps font scaling consistent with the rest
/// of the settings page.
class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppSettings settings;

  const _SettingsSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.settings,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      secondary: Icon(icon, color: scheme.primary),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: settings.fontFamily,
          fontSize: settings.fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: (subtitle == null || subtitle!.isEmpty)
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontSize: (settings.fontSize - 3).clamp(11.0, 14.0),
                color: scheme.onSurfaceVariant,
              ),
            ),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// "Last synced 3 minutes ago" + "Sync now" row. Shown inside the
/// Account card whenever the user is signed in. Listens to
/// `CloudSyncService` so the timestamp updates live (e.g. after a
/// background push completes the user sees "Synced just now" without
/// reopening Settings).
class _SyncStatusRow extends StatefulWidget {
  final AppSettings settings;
  const _SyncStatusRow({required this.settings});

  @override
  State<_SyncStatusRow> createState() => _SyncStatusRowState();
}

class _SyncStatusRowState extends State<_SyncStatusRow> {
  bool _busy = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    CloudSyncService.instance.addListener(_onSyncChange);
    // Refresh the relative-time label every 30s so "5 minutes ago"
    // doesn't go stale while the user stares at the Settings page.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    CloudSyncService.instance.removeListener(_onSyncChange);
    _ticker?.cancel();
    super.dispose();
  }

  void _onSyncChange() {
    if (mounted) setState(() {});
  }

  Future<void> _trigger() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await CloudSyncService.instance.syncNow();
    if (!mounted) return;
    setState(() => _busy = false);
    if (messenger != null) {
      final locale = widget.settings.locale;
      final scheme = Theme.of(context).colorScheme;
      messenger.hideCurrentSnackBar();
      if (ok) {
        // Success — short, no fuss, dismissible.
        messenger.showSnackBar(SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                uiStrings['syncSuccess']?[locale] ?? 'Synced.',
                style: TextStyle(
                    fontFamily: widget.settings.fontFamily,
                    color: Colors.white),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(milliseconds: 2200),
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        // Failure — error color, longer (5s), dismissible, includes
        // the actual error message from CloudSyncService so the user
        // knows WHY (timeout vs not-signed-in vs Firestore rule
        // denial vs network blip).
        final actual = CloudSyncService.instance.lastError;
        final fallback = uiStrings['syncFailed']?[locale] ??
            'Sync failed. Check your connection and try again.';
        messenger.showSnackBar(SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline,
                  color: scheme.onError, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  actual != null && actual.isNotEmpty ? actual : fallback,
                  style: TextStyle(
                    fontFamily: widget.settings.fontFamily,
                    color: scheme.onError,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: scheme.error,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: uiStrings['retry']?[locale] ?? 'Retry',
            textColor: scheme.onError,
            onPressed: _trigger,
          ),
        ));
      }
    }
  }

  String _relative(DateTime utc, String locale) {
    final now = DateTime.now().toUtc();
    final diff = now.difference(utc);
    final isZh = locale.startsWith('zh');
    if (diff.inSeconds < 30) return isZh ? '刚刚' : 'just now';
    if (diff.inMinutes < 1) {
      return isZh ? '不到一分钟前' : 'less than a minute ago';
    }
    if (diff.inMinutes < 60) {
      return isZh
          ? '${diff.inMinutes} 分钟前'
          : '${diff.inMinutes} minute${diff.inMinutes == 1 ? "" : "s"} ago';
    }
    if (diff.inHours < 24) {
      return isZh
          ? '${diff.inHours} 小时前'
          : '${diff.inHours} hour${diff.inHours == 1 ? "" : "s"} ago';
    }
    return isZh
        ? '${diff.inDays} 天前'
        : '${diff.inDays} day${diff.inDays == 1 ? "" : "s"} ago';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = widget.settings;
    final locale = settings.locale;
    final sync = CloudSyncService.instance;
    final last = sync.lastSyncedAt;
    final status = sync.status;

    String stamp;
    if (status == CloudSyncStatus.syncing || _busy) {
      stamp = uiStrings['syncingNow']?[locale] ?? 'Syncing now…';
    } else if (status == CloudSyncStatus.error) {
      // Prefer the actual error message from CloudSyncService so
      // users can see "Sync timed out after 15 seconds." or
      // "Permission denied" rather than a generic catch-all. Falls
      // back to the localized friendly string when no detail.
      final actual = sync.lastError;
      stamp = (actual != null && actual.isNotEmpty)
          ? actual
          : (uiStrings['syncFailed']?[locale] ??
              'Sync failed. Check your connection and try again.');
    } else if (last != null) {
      stamp = (uiStrings['lastSyncedAt']?[locale] ?? 'Last synced {when}')
          .replaceAll('{when}', _relative(last, locale));
    } else {
      stamp =
          uiStrings['syncNotYet']?[locale] ?? 'Not synced yet on this device.';
    }

    final isSyncing = status == CloudSyncStatus.syncing || _busy;
    final color = status == CloudSyncStatus.error
        ? scheme.error
        : scheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Status icon. While syncing we show a real
            // CircularProgressIndicator here (not just a static
            // cloud-sync icon) so the user immediately knows
            // something is happening even before the row text changes.
            SizedBox(
              width: 18,
              height: 18,
              child: isSyncing
                  ? CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: scheme.primary,
                    )
                  : Icon(
                      status == CloudSyncStatus.error
                          ? Icons.cloud_off_outlined
                          : Icons.cloud_done_outlined,
                      size: 16,
                      color: color,
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                stamp,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontSize: (settings.fontSize - 3).clamp(11.0, 14.0),
                  color: color,
                  fontWeight: isSyncing
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: isSyncing ? null : _trigger,
              icon: isSyncing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : const Icon(Icons.sync, size: 16),
              label: Text(
                isSyncing
                    ? (uiStrings['syncingNowShort']?[locale] ?? 'Syncing…')
                    : (uiStrings['syncNow']?[locale] ?? 'Sync now'),
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontSize: (settings.fontSize - 3).clamp(11.0, 14.0),
                ),
              ),
            ),
          ],
        ),
        // Full-width progress bar appears below the row whenever the
        // sync is actually in flight. Indeterminate (no known total),
        // shaped like a typical "loading" affordance so non-technical
        // users immediately understand work is happening — much more
        // visible than the previous tiny in-button spinner.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isSyncing
              ? Padding(
                  key: const ValueKey('progress'),
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor:
                          scheme.primary.withValues(alpha: 0.12),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(scheme.primary),
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('idle')),
        ),
      ],
    );
  }
}

/// Notifications opt-in card. On web, toggling on prompts the
/// browser for permission via `Notification.requestPermission()`. On
/// non-web platforms (we don't ship them today), the row is hidden.
class _NotificationsCard extends StatefulWidget {
  final AppSettings settings;
  final double s;
  const _NotificationsCard({required this.settings, required this.s});

  @override
  State<_NotificationsCard> createState() => _NotificationsCardState();
}

class _NotificationsCardState extends State<_NotificationsCard> {
  bool _busy = false;

  Future<void> _toggle(bool v) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (v) {
        // Opting in — request browser permission first.
        if (!NotificationService.isSupported) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                uiStrings['notificationsUnsupported']
                        ?[widget.settings.locale] ??
                    "This browser doesn't support notifications.",
              ),
            ),
          );
          return;
        }
        final result = await NotificationService.requestPermission();
        if (result == NotificationPermission.granted) {
          await widget.settings.setNotificationsEnabled(true);
          if (!mounted) return;
          // Fire a confirmation notification so the user can see what
          // they look like.
          await NotificationService.show(
            title: uiStrings['appName']?[widget.settings.locale] ??
                'YsWords',
            body: uiStrings['notificationsEnabledBody']
                    ?[widget.settings.locale] ??
                'Notifications are on. You\'ll get gentle daily reminders.',
            tag: 'yswords-confirm',
          );
        } else {
          await widget.settings.setNotificationsEnabled(false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                uiStrings['notificationsDenied']
                        ?[widget.settings.locale] ??
                    'Browser denied notification permission. Allow notifications in your browser settings to enable.',
              ),
            ),
          );
        }
      } else {
        await widget.settings.setNotificationsEnabled(false);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final locale = settings.locale;
    final supported = NotificationService.isSupported;
    final perm = NotificationService.permission;
    final scheme = Theme.of(context).colorScheme;

    final hint = !supported
        ? (uiStrings['notificationsUnsupported']?[locale] ??
            "This browser doesn't support notifications.")
        : perm == NotificationPermission.denied
            ? (uiStrings['notificationsBlocked']?[locale] ??
                'Permission blocked at the browser level. Re-enable in browser settings, then toggle on here.')
            : (uiStrings['notificationsHint']?[locale] ??
                'Get gentle daily reminders for verse, reading, and news.');

    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(8 * widget.s, 4 * widget.s,
            8 * widget.s, 4 * widget.s),
        child: Column(
          children: [
            _SettingsSwitch(
              icon: Icons.notifications_active_outlined,
              label: uiStrings['notificationsToggle']?[locale] ??
                  'Enable notifications',
              subtitle: hint,
              value: settings.notificationsEnabled &&
                  perm == NotificationPermission.granted,
              onChanged: (supported &&
                      perm != NotificationPermission.denied &&
                      !_busy)
                  ? _toggle
                  : (_) {}, // ignore on unsupported / denied
              settings: settings,
            ),
            if (settings.notificationsEnabled &&
                perm == NotificationPermission.granted)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      await NotificationService.show(
                        title: uiStrings['appName']?[locale] ?? 'YsWords',
                        body: uiStrings['notificationsTestBody']
                                ?[locale] ??
                            'This is a test notification.',
                        tag: 'yswords-test',
                      );
                    },
                    icon: Icon(Icons.send_outlined,
                        size: 16, color: scheme.primary),
                    label: Text(
                      uiStrings['notificationsTest']?[locale] ??
                          'Send test notification',
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontSize:
                            (settings.fontSize - 2).clamp(12.0, 14.0),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


/// Settings → About — app name, version line, and the unified
/// ContactLine. Lives at the bottom of the Settings list.
class _AboutCard extends StatelessWidget {
  final AppSettings settings;
  final double s;
  const _AboutCard({required this.settings, required this.s});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 8 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded,
                    color: scheme.primary,
                    size: settings.fontSize + 4),
                SizedBox(width: 8 * s),
                Text(
                  uiStrings['appName']?[locale] ?? 'YsWords',
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontSize: settings.fontSize + 2,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4 * s),
            Text(
              uiStrings['appTagline']?[locale] ??
                  'A bilingual Bible study app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontSize: (settings.fontSize - 3).clamp(11.0, 14.0),
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 6 * s),
            const ContactLine(),
          ],
        ),
      ),
    );
  }
}
