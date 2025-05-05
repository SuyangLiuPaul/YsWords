import 'package:flutter/material.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:provider/provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/utils/clipboard_helper.dart';

class VerseWidget extends StatelessWidget {
  final Verse verse;
  final int index;
  const VerseWidget({super.key, required this.verse, required this.index});

  @override
  Widget build(BuildContext context) {
    return Consumer2<MainProvider, AppSettings>(
      builder: (context, mainProvider, settings, child) {
        final isSelected = mainProvider.isSelected(verse);
        final isHighlighted = mainProvider.highlightIndex == index;

        // Prepare regex and spans for verse text with annotations
        final squarePattern = RegExp(r'\[([^\]]+)\]');
        final bracePattern = RegExp(r'\{([^}]+)\}');
        final notePattern = RegExp(r'<note:([^>]+)>');
        final combinedPattern = RegExp(r'(\{[^}]+\}|\[[^\]]+\]|<note:[^>]+>)');
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
        spans.add(WidgetSpan(
          child: GestureDetector(
            onTap: () async {
              final toCopy = '${verse.verse} ${verse.text.trim()}';
              await ClipboardHelper.copyText(toCopy);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied verse ${verse.verse}')),
              );
            },
            child: Text(
              '${verse.verse} ',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: settings.fontSize,
                    height: settings.lineSpacing,
                    fontWeight: FontWeight.w500,
                    fontFamily: settings.fontFamily,
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
            final bgColor = isDark
                ? Theme.of(context).colorScheme.secondary.withOpacity(0.2)
                : Theme.of(context).colorScheme.secondary.withOpacity(0.3);
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
                    final nextAnnotation = RegExp(r'''^([\s.,;:"“”'"”]*)<note:([^>]+)>''')
                        .firstMatch(afterBrace);
                    if (nextAnnotation != null) {
                      extractedNote = nextAnnotation.group(2);
                    }
                  }
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text('Note'),
                      content: Text(extractedNote ?? annotation),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Close'),
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
                                fontSize: settings.fontSize * 0.1,
                                fontFamily: settings.fontFamily,
                                height: settings.lineSpacing,
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer
                                    : Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
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
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color,
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
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color,
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
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                : (isDark
                                    ? Colors.white
                                    : Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color),
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
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bgColor = isDark
                ? Theme.of(context).colorScheme.secondary.withOpacity(0.2)
                : Theme.of(context).colorScheme.secondary.withOpacity(0.3);
            spans.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text('Note'),
                      content: Text(note),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Close'),
                        )
                      ],
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 1.5),
                  child: Icon(
                    Icons.menu_book,
                    size: settings.fontSize * 0.75,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
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
                  ),
            ));
            lastPart = part;
          }
        }

        return Material(
          color: Colors.white.withOpacity(0.01),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            onTap: () {
              mainProvider.toggleVerse(verse: verse);
            },
            child: Column(
              crossAxisAlignment: settings.readingModeCentered
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                if (settings.readingModeCentered &&
                    verse.isParagraphStart == true)
                  const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : isHighlighted
                          ? Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.3)
                          : Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: RichText(
                    textAlign: settings.readingModeCentered
                        ? TextAlign.center
                        : TextAlign.start,
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
