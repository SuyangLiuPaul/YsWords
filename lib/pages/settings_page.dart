import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
import 'package:yswords/constants/ui_strings.dart';
// import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';

import 'package:yswords/widgets/localized_back_button.dart';


String getDevotionalFormattedText(
    List<Map<String, dynamic>> verses, String? book, int? chapter) {
  if (verses.isEmpty || book == null || chapter == null) return '';

  List<int> verseNums = verses.map((v) => v['verse'] as int).toList()..sort();
  List<String> textParts = verses
      .map((v) => v['text'] as String)
      .toList();

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
  SettingsPage({super.key});

  // final TextEditingController _feedbackController = TextEditingController();
  // final ValueNotifier<bool> _isSending = ValueNotifier(false);

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
              .where((v) => v.book == currentBook && v.chapter == currentChapter)
              .toList()
            ..sort((a, b) => a.verse.compareTo(b.verse));
          final verseSamples = versesInChapter
              .take(3)
              .map((v) => {'verse': v.verse, 'text': v.text})
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                      const SizedBox(height: 12),
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
                          const SizedBox(height: 8),
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
                      const SizedBox(height: 12),
                      Text(
                        '$currentBook $currentChapter',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontFamily: settings.fontFamily,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: settings.fontSize,
                                ),
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(height: 12),
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
                          final ref =
                              '${currentBook ?? ''} ${currentChapter}:${v['verse']}';
                          String formattedText;
                          switch (settings.copyFormat) {
                            case 'withRef':
                              formattedText = '[$ref] ${v['text']}';
                              break;
                            case 'plain':
                            default:
                              formattedText = '${v['verse']} ${v['text']}';
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
                                      text: '${v['verse']} ',
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
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              // --- Reading/Study Mode Toggle ---
              // Card(
              //   child: Padding(
              //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              //     child: Column(
              //       crossAxisAlignment: CrossAxisAlignment.start,
              //       children: [
              //         Text(
              //           '阅读模式排版',
              //           style: TextStyle(
              //             fontFamily: settings.fontFamily,
              //             fontSize: settings.fontSize + 2,
              //             fontWeight: FontWeight.w600,
              //           ),
              //         ),
              //         const SizedBox(height: 12),
              //         SwitchListTile(
              //           contentPadding: EdgeInsets.zero,
              //           title: Text(
              //             settings.readingModeCentered ? '阅读型（居中、段落）' : '查经型（左对齐、一节一行）',
              //             style: TextStyle(
              //               fontFamily: settings.fontFamily,
              //               fontSize: settings.fontSize,
              //             ),
              //           ),
              //           value: settings.readingModeCentered,
              //           onChanged: (val) => settings.setReadingModeCentered(val),
              //         ),
              //       ],
              //     ),
              //   ),
              // ),
              // const SizedBox(height: 16),
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
                        const SizedBox(height: 12),
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
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              // Only show these settings when running as Web App
              // if (kIsWeb && !settings.lockAllowUpdates)
              //   Card(
              //     // margin: const EdgeInsets.only(top: 24),
              //     child: SwitchListTile(
              //       title: Text(
              //         uiStrings['allowUpdates']?[settings.locale] ??
              //             'Allow Auto Updates',
              //         style: TextStyle(
              //           fontSize: settings.fontSize + 2,
              //           fontWeight: FontWeight.w600,
              //         ),
              //       ),
              //       subtitle: Text(
              //         uiStrings['allowUpdatesSubtitle']?[settings.locale] ??
              //             'Toggle whether to allow app updates from server.',
              //         style: TextStyle(
              //           fontSize: settings.fontSize,
              //           fontFamily: settings.fontFamily,
              //         ),
              //       ),
              //       value: settings.allowUpdates,
              //       onChanged: (val) {
              //         settings.setAllowUpdates(val);
              //       },
              //     ),
              //   ),
              // const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                      const SizedBox(height: 8),
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
              const SizedBox(height: 16),
              // --- 直接在 App 內輸入並發送反饋的區塊 ---
//               Card(
//                 child: Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         uiStrings['sendFeedback']?[settings.locale] ??
//                             'Send Feedback',
//                         style: TextStyle(
//                           fontFamily: settings.fontFamily,
//                           fontSize: settings.fontSize + 2,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//                       TextFormField(
//                         controller: _feedbackController,
//                         style: TextStyle(
//                           fontSize: settings.fontSize,
//                           fontFamily: settings.fontFamily,
//                         ),
//                         maxLines: null,
//                         maxLength: 500,
//                         decoration: InputDecoration(
//                           hintText: uiStrings['feedbackHint']
//                                   ?[settings.locale] ??
//                               'Please enter your feedback...',
//                           hintStyle: TextStyle(
//                             fontSize: settings.fontSize,
//                             fontFamily: settings.fontFamily,
//                           ),
//                           counterStyle: TextStyle(
//                             fontSize: settings.fontSize,
//                             fontFamily: settings.fontFamily,
//                           ),
//                           border: const OutlineInputBorder(),
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//                       SizedBox(
//                         width: double.infinity,
//                         child: ValueListenableBuilder<bool>(
//                           valueListenable: _isSending,
//                           builder: (context, isSending, child) {
//                             return ElevatedButton.icon(
//                               style: Theme.of(context).brightness ==
//                                       Brightness.light
//                                   ? ElevatedButton.styleFrom(
//                                       backgroundColor:
//                                           Theme.of(context).colorScheme.primary,
//                                       foregroundColor: Colors.white,
//                                       padding: const EdgeInsets.symmetric(
//                                           vertical: 16),
//                                       textStyle: TextStyle(
//                                         fontSize: settings.fontSize + 2,
//                                         fontWeight: FontWeight.bold,
//                                         fontFamily: settings.fontFamily,
//                                       ),
//                                     )
//                                   : null,
//                               icon: isSending
//                                   ? const SizedBox(
//                                       width: 16,
//                                       height: 16,
//                                       child: CircularProgressIndicator(
//                                         strokeWidth: 2,
//                                         valueColor:
//                                             AlwaysStoppedAnimation<Color>(
//                                                 Colors.white),
//                                       ),
//                                     )
//                                   : const Icon(Icons.send),
//                               label: Text(
//                                 isSending
//                                     ? (uiStrings['sendingFeedback']
//                                             ?[settings.locale] ??
//                                         'Sending...')
//                                     : (uiStrings['sendFeedback']
//                                             ?[settings.locale] ??
//                                         'Send Feedback'),
//                                 style: TextStyle(
//                                   fontFamily: settings.fontFamily,
//                                   fontSize: settings.fontSize,
//                                 ),
//                               ),
//                               onPressed: isSending
//                                   ? null
//                                   : () async {
//                                       final content =
//                                           _feedbackController.text.trim();
//                                       if (content.isEmpty) {
//                                         ScaffoldMessenger.of(context)
//                                             .showSnackBar(
//                                           SnackBar(
//                                             content: Text(
//                                               uiStrings['feedbackEmpty']
//                                                       ?[settings.locale] ??
//                                                   '請輸入反饋內容',
//                                               style: TextStyle(
//                                                 fontFamily: settings.fontFamily,
//                                                 fontSize: settings.fontSize,
//                                               ),
//                                             ),
//                                             duration:
//                                                 Duration(milliseconds: 1500),
//                                           ),
//                                         );
//                                         return;
//                                       }
//                                       if (content.length > 500) {
//                                         ScaffoldMessenger.of(context)
//                                             .showSnackBar(
//                                           SnackBar(
//                                             content: Text(
//                                               uiStrings['feedbackTooLong']
//                                                       ?[settings.locale] ??
//                                                   '內容過長，請刪減後再發送。',
//                                               style: TextStyle(
//                                                 fontFamily: settings.fontFamily,
//                                                 fontSize: settings.fontSize,
//                                               ),
//                                             ),
//                                             duration:
//                                                 Duration(milliseconds: 1500),
//                                           ),
//                                         );
//                                         return;
//                                       }

//                                       final emojiRegex = RegExp(
//                                         r'[\u{1F600}-\u{1F64F}]|' // Emoticons 表情符號
//                                         r'[\u{1F300}-\u{1F5FF}]|' // 各種符號
//                                         r'[\u{1F680}-\u{1F6FF}]|' // 交通工具符號
//                                         r'[\u{2600}-\u{26FF}]|' // 雜項符號
//                                         r'[\u{2700}-\u{27BF}]', // Dingbats 記號
//                                         unicode: true,
//                                       );

//                                       if (emojiRegex.hasMatch(content)) {
//                                         ScaffoldMessenger.of(context)
//                                             .showSnackBar(
//                                           SnackBar(
//                                             content: Text(
//                                               uiStrings['feedbackInvalid']
//                                                       ?[settings.locale] ??
//                                                   '❗️內容包含不支援的符號（如 emoji 表情符號），請移除後再發送。',
//                                               style: TextStyle(
//                                                 fontFamily: settings.fontFamily,
//                                                 fontSize: settings.fontSize,
//                                               ),
//                                             ),
//                                             duration:
//                                                 Duration(milliseconds: 1500),
//                                           ),
//                                         );
//                                         return;
//                                       }

//                                       _isSending.value = true;

//                                       // 當地系統時間（完整格式）
//                                       final now = DateTime.now();
//                                       final formattedTime =
//                                           DateFormat('yyyy-MM-dd HH:mm:ss')
//                                               .format(now);

//                                       final timezoneOffset = now.timeZoneOffset;
//                                       final timezoneString = timezoneOffset
//                                               .isNegative
//                                           ? '-${timezoneOffset.inHours.abs().toString().padLeft(2, '0')}:${(timezoneOffset.inMinutes.abs() % 60).toString().padLeft(2, '0')}'
//                                           : '+${timezoneOffset.inHours.toString().padLeft(2, '0')}:${(timezoneOffset.inMinutes % 60).toString().padLeft(2, '0')}';

//                                       final timezoneName = now.timeZoneName;

//                                       final deviceTimeString =
//                                           '$formattedTime GMT$timezoneString ($timezoneName)';

//                                       final formattedDate =
//                                           DateFormat('yyyy-MM-dd').format(now);

//                                       // 平台資訊
//                                       final platform = kIsWeb
//                                           ? 'Web'
//                                           : Theme.of(context).platform.name;

//                                       // 語言
//                                       final locale = settings.locale;

//                                       // Web 的 UserAgent
//                                       String userAgent = '';
//                                       if (kIsWeb) {
//                                         userAgent =
//                                             'Web Browser'; // 简单标记是Web端，无需访问html.window
//                                       }

//                                       // 組裝完整訊息
//                                       final fullMessage = '''
// $content

// ———
// Platform: $platform ${kIsWeb ? '(Web)' : ''}
// Locale: $locale
// ${userAgent.isNotEmpty ? 'UserAgent: $userAgent\n' : ''}Device Local Time (User\'s timezone): $deviceTimeString
// ''';
//                                       try {
//                                         final response = await http.post(
//                                           Uri.parse(
//                                               'https://formsubmit.co/f9d9312f748905d64423c6ce18bb285a'),
//                                           headers: {
//                                             'Content-Type':
//                                                 'application/x-www-form-urlencoded'
//                                           },
//                                           body: {
//                                             '_subject':
//                                                 'YsWords Feedback ($formattedDate)',
//                                             'message': fullMessage,
//                                             '_template': 'table',
//                                             '_honey': '',
//                                             '_captcha': 'false',
//                                           },
//                                         );
//                                         if (response.statusCode == 200) {
//                                           ScaffoldMessenger.of(context)
//                                               .showSnackBar(
//                                             SnackBar(
//                                               content: Text(
//                                                 uiStrings['feedbackSuccess']
//                                                         ?[settings.locale] ??
//                                                     '✅ Feedback sent. Thank you!',
//                                                 style: TextStyle(
//                                                   fontFamily:
//                                                       settings.fontFamily,
//                                                   fontSize: settings.fontSize,
//                                                 ),
//                                               ),
//                                               duration:
//                                                   Duration(milliseconds: 1500),
//                                             ),
//                                           );
//                                           _feedbackController.clear();
//                                         } else {
//                                           ScaffoldMessenger.of(context)
//                                               .showSnackBar(
//                                             SnackBar(
//                                               content: Text(
//                                                 uiStrings['feedbackFailure']
//                                                         ?[settings.locale] ??
//                                                     '❌ Failed to send. Please try again.',
//                                                 style: TextStyle(
//                                                   fontFamily:
//                                                       settings.fontFamily,
//                                                   fontSize: settings.fontSize,
//                                                 ),
//                                               ),
//                                               duration:
//                                                   Duration(milliseconds: 1500),
//                                             ),
//                                           );
//                                         }
//                                       } catch (_) {
//                                         ScaffoldMessenger.of(context)
//                                             .showSnackBar(
//                                           SnackBar(
//                                             content: Text(
//                                               uiStrings['feedbackFailure']
//                                                       ?[settings.locale] ??
//                                                   '❌ Failed to send. Please try again.',
//                                               style: TextStyle(
//                                                 fontFamily: settings.fontFamily,
//                                                 fontSize: settings.fontSize,
//                                               ),
//                                             ),
//                                             duration:
//                                                 Duration(milliseconds: 1500),
//                                           ),
//                                         );
//                                       } finally {
//                                         _isSending.value = false;
//                                       }
//                                     },
//                             );
//                           },
//                         ),
//                       )
//                     ],
//                   ),
//                 ),
//               ),
            
            ],
          );
        },
      ),
    );
  }
}
