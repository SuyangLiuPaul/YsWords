import 'package:flutter/material.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:provider/provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/constants/text_patterns.dart';
import 'package:yswords/constants/ui_strings.dart';

class VerseWidget extends StatelessWidget {
  final Verse verse;
  final int index;
  final bool hasParagraphData;

  const VerseWidget({super.key, required this.verse, required this.index, this.hasParagraphData = false});

  @override
  Widget build(BuildContext context) {
    return Consumer2<MainProvider, AppSettings>(
      builder: (context, mainProvider, settings, child) {
        final locale = settings.locale;
        final isSelected = mainProvider.isSelected(verse);
        final isHighlighted = mainProvider.highlightIndex == index;
        final isReferenceLine = verse.paragraphType == 'reference';
        final inParagraphMode = settings.paragraphMode;
        final effectiveParagraphStart = inParagraphMode
            ? (hasParagraphData ? (verse.isParagraphStart == true) : true)
            : false;

        // Use shared regex patterns from text_patterns.dart
        final original = verse.text.replaceAll('\n', '');
        final raw = original.trim();
        final parts = raw
            .splitMapJoin(
              combinedPattern,
              onMatch: (m) => '||${m[0]}||',
              onNonMatch: (n) => n,
            )
            .split('||');
        final spans = <InlineSpan>[];
        final skipNoteIcons =
            bracePattern.hasMatch(original) && notePattern.hasMatch(original);
        // Verse number span
        final verseNumFontSize =
            inParagraphMode ? settings.fontSize * 0.7 : settings.fontSize;
        final verseNumWeight =
            inParagraphMode ? FontWeight.bold : FontWeight.w500;
        spans.add(WidgetSpan(
          child: GestureDetector(
            onTap: () async {
              final toCopy =
                  '${verse.verseLabel} ${sanitizeVerseText(verse.text)}';
              await ClipboardHelper.copyText(toCopy);
              if (!context.mounted) return;
              final msg =
                  (uiStrings['copiedVerse']?[locale] ?? 'Copied verse {verse}')
                      .replaceAll('{verse}', verse.verseLabel);
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(msg)));
            },
            child: Text(
              '${verse.verseLabel} ',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: verseNumFontSize,
                    height: inParagraphMode ? 1.0 : settings.lineSpacing,
                    fontWeight: verseNumWeight,
                    fontFamily: settings.fontFamily,
                    fontStyle:
                        isReferenceLine ? FontStyle.italic : FontStyle.normal,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
        ));
        // Build text and badge spans
        String? lastPart;
        for (var part in parts) {
          // Skip <note:...> if lastPart was exactly a brace and this part is *only* a note
          final isNoteOnly =
              part.trim().startsWith('<note:') && part.trim().endsWith('>');
          final wasBraceOnly = lastPart != null &&
              lastPart.trim().startsWith('{') &&
              lastPart.trim().endsWith('}');
          if (isNoteOnly && wasBraceOnly) {
            lastPart = part;
            continue;
          }
          if (bracePattern.hasMatch(part)) {
            final annotation = bracePattern.firstMatch(part)!.group(1)!;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bgColor = Theme.of(context).colorScheme.secondaryContainer;
            spans.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                onTap: () {
                  final verseText = verse.text.replaceAll('\n', '');
                  final braceFull = '{$annotation}';
                  final braceIndex = verseText.indexOf(braceFull);
                  String? extractedNote;
                  if (braceIndex != -1) {
                    final afterBrace =
                        verseText.substring(braceIndex + braceFull.length);
                    // Look for the next <note:...> tag, allowing for whitespace or punctuation in between, but no braces/brackets
                    final nextAnnotation =
                        RegExp(r'''^([\s.,;:"“”'"”]*)<note:([^>]+)>''')
                            .firstMatch(afterBrace);
                    if (nextAnnotation != null) {
                      extractedNote = nextAnnotation.group(2);
                    }
                  }
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(
                        uiStrings['note']?[locale] ?? 'Note',
                        style: TextStyle(
                          fontSize: settings.fontSize + 2,
                          fontFamily: settings.fontFamily,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: Text(extractedNote ?? annotation),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            uiStrings['ok']?[locale] ?? 'OK',
                            style: TextStyle(
                              fontSize: settings.fontSize,
                              fontFamily: settings.fontFamily,
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  margin: EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(
                      color: isDark ? Colors.teal.shade200 : Colors.teal,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Builder(
                    builder: (_) {
                      final spans = <InlineSpan>[];
                      final regex = RegExp(r'\[([^\[\]]+)\]');
                      final matches = regex.allMatches(annotation);

                      if (matches.isNotEmpty) {
                        int lastEnd = 0;
                        for (final match in matches) {
                          if (match.start > lastEnd) {
                            spans.add(TextSpan(
                              text: annotation.substring(lastEnd, match.start),
                              style: TextStyle(
                                fontSize: settings.fontSize * 0.85,
                                fontFamily: settings.fontFamily,
                                height: settings.lineSpacing,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                            ));
                          }
                          final text = match.group(1)!;
                          spans.add(TextSpan(
                            text: text,
                            style: TextStyle(
                              fontSize: settings.fontSize,
                              fontFamily: settings.fontFamily,
                              height: settings.lineSpacing,
                              decoration: TextDecoration.underline,
                              decorationStyle: TextDecorationStyle.dotted,
                              decorationColor:
                                  Theme.of(context).colorScheme.primary,
                              decorationThickness: 2.0,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ));
                          lastEnd = match.end;
                        }
                        if (lastEnd < annotation.length) {
                          spans.add(TextSpan(
                            text: annotation.substring(lastEnd),
                            style: TextStyle(
                              fontSize: settings.fontSize * 0.85,
                              fontFamily: settings.fontFamily,
                              height: settings.lineSpacing,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ));
                        }

                        return RichText(text: TextSpan(children: spans));
                      } else {
                        return Text(
                          annotation,
                          style: TextStyle(
                            fontSize: settings.fontSize * 0.85,
                            fontFamily: settings.fontFamily,
                            height: settings.lineSpacing,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ));
            // handled as a brace
            lastPart = part;
            continue;
          }
          if (squarePattern.hasMatch(part)) {
            final annotation = squarePattern.firstMatch(part)!.group(1)!;
            spans.add(TextSpan(
              text: annotation,
              style: TextStyle(
                fontSize: settings.fontSize,
                fontFamily: settings.fontFamily,
                height: settings.lineSpacing,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: Theme.of(context).colorScheme.primary,
                decorationThickness: 2.0,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ));
            lastPart = part;
            continue;
          }
          if (notePattern.hasMatch(part) &&
              !bracePattern.hasMatch(part) &&
              !(part.trim().startsWith('<note:') &&
                  part.trim().endsWith('>') &&
                  (lastPart?.trim().endsWith('}') ?? false))) {
            if (skipNoteIcons) {
              lastPart = part;
              continue;
            }
            final note = notePattern.firstMatch(part)!.group(1)!;
            spans.add(WidgetSpan(
              alignment: PlaceholderAlignment.bottom,
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(
                        uiStrings['note']?[locale] ?? 'Note',
                        style: TextStyle(
                          fontSize: settings.fontSize + 2,
                          fontFamily: settings.fontFamily,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: Text(note),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            uiStrings['ok']?[locale] ?? 'OK',
                            style: TextStyle(
                              fontSize: settings.fontSize,
                              fontFamily: settings.fontFamily,
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                },
                child: Padding(
                  padding:
                      const EdgeInsets.only(right: 4.0, left: 2.0, bottom: 5.0),
                  child: Icon(
                    Icons.menu_book,
                    size: settings.fontSize * 1.2,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ));
            lastPart = part;
            continue;
          }
          {
            spans.add(TextSpan(
              text: part,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: settings.fontSize,
                    height: settings.lineSpacing,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).textTheme.bodyLarge?.color,
                    fontFamily: settings.fontFamily,
                    fontStyle:
                        isReferenceLine ? FontStyle.italic : FontStyle.normal,
                  ),
            ));
            lastPart = part;
          }
        }

        double leftIndent;
        double topSpacer;
        double vertPadding;
        if (inParagraphMode) {
          if (isReferenceLine) {
            leftIndent = settings.fontSize * 3;
            topSpacer = 0;
          } else if (effectiveParagraphStart) {
            leftIndent = settings.fontSize * 2;
            topSpacer = settings.fontSize * 0.8;
          } else {
            leftIndent = 16;
            topSpacer = 0;
          }
          vertPadding = 2;
        } else {
          leftIndent = isReferenceLine ? 24 : 16;
          topSpacer = (verse.isParagraphStart == true) ? 10 : 0;
          vertPadding = 8;
        }

        return Material(
          color: Colors.transparent,
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            onTap: () {
              mainProvider.toggleVerse(verse: verse);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (topSpacer > 0) SizedBox(height: topSpacer),
                Container(
                  width: double.infinity,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : isHighlighted
                          ? Theme.of(context)
                              .colorScheme
                              .secondary
                              .withValues(alpha: 0.3)
                          : Colors.transparent,
                  padding:
                      EdgeInsets.fromLTRB(leftIndent, vertPadding, 16, vertPadding),
                  child: RichText(
                    textAlign: TextAlign.start,
                    text: TextSpan(
                      children: spans,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
