import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/constants/text_patterns.dart';
import 'package:yswords/constants/ui_strings.dart';

/// Builds InlineSpan list for a single verse (number + text with annotations).
/// Shared by VerseWidget and ParagraphGroupWidget.
List<InlineSpan> buildVerseContentSpans({
  required Verse verse,
  required BuildContext context,
  required AppSettings settings,
  required String locale,
  required bool isSelected,
  bool superscriptVerseNum = false,
  VoidCallback? onTextTap,
  Color? spanBgColor,
}) {
  final isReferenceLine = verse.paragraphType == 'reference';

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
  // Verse number span — superscript in paragraph mode, normal-weight inline otherwise.
  // Superscript style: small, muted color (like printed Bibles / WeDevote 微读圣经),
  // top-aligned to sit above the baseline. Verse-by-verse style: same size as body,
  // colored with the theme's primary so it stands out as a label.
  final verseNumColor = isSelected
      ? Theme.of(context).colorScheme.onPrimaryContainer
      : (superscriptVerseNum
          ? Theme.of(context).colorScheme.onSurfaceVariant
          : Theme.of(context).colorScheme.primary);

  final verseNumStyle = TextStyle(
    fontSize:
        superscriptVerseNum ? settings.fontSize * 0.65 : settings.fontSize,
    height: superscriptVerseNum ? 1.0 : settings.lineSpacing,
    fontWeight: superscriptVerseNum ? FontWeight.w600 : FontWeight.w500,
    fontFamily: settings.fontFamily,
    fontStyle: isReferenceLine ? FontStyle.italic : FontStyle.normal,
    color: verseNumColor,
  );

  spans.add(WidgetSpan(
    alignment:
        superscriptVerseNum ? PlaceholderAlignment.top : PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
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
      child: Padding(
        // Slight right gap so number doesn't glue onto the first character.
        // Superscript needs less right-pad because it's smaller.
        padding: EdgeInsets.only(
          right: superscriptVerseNum ? 3 : 4,
          // Lift superscript a touch so it sits visually above the baseline.
          top: superscriptVerseNum ? settings.fontSize * 0.05 : 0,
        ),
        child: Text(verse.verseLabel, style: verseNumStyle),
      ),
    ),
  ));

  // Build text and badge spans
  String? lastPart;
  for (var part in parts) {
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
              final nextAnnotation =
                  RegExp(r'''^([\s.,;:""'""]*)<note:([^>]+)>''')
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
                final badgeSpans = <InlineSpan>[];
                final regex = RegExp(r'\[([^\[\]]+)\]');
                final matches = regex.allMatches(annotation);

                if (matches.isNotEmpty) {
                  int lastEnd = 0;
                  for (final match in matches) {
                    if (match.start > lastEnd) {
                      badgeSpans.add(TextSpan(
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
                    badgeSpans.add(TextSpan(
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
                    badgeSpans.add(TextSpan(
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

                  return RichText(text: TextSpan(children: badgeSpans));
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
      lastPart = part;
      continue;
    }
    if (squarePattern.hasMatch(part)) {
      final annotation = squarePattern.firstMatch(part)!.group(1)!;
      spans.add(TextSpan(
        text: annotation,
        recognizer: onTextTap != null
            ? (TapGestureRecognizer()..onTap = onTextTap)
            : null,
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
          backgroundColor: spanBgColor,
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
        recognizer: onTextTap != null
            ? (TapGestureRecognizer()..onTap = onTextTap)
            : null,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: settings.fontSize,
              height: settings.lineSpacing,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).textTheme.bodyLarge?.color,
              fontFamily: settings.fontFamily,
              fontStyle:
                  isReferenceLine ? FontStyle.italic : FontStyle.normal,
              backgroundColor: spanBgColor,
            ),
      ));
      lastPart = part;
    }
  }

  return spans;
}
