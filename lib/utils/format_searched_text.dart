import 'package:flutter/material.dart';

Text formatSearchText({
  required String input,
  required String text,
  required BuildContext context,
}) {
  // Check if the input or text is empty
  if (input.isEmpty || text.isEmpty) {
    return Text(input);
  }

  // List to store formatted text spans
  List<TextSpan> textSpans = [];

  // Create a regular expression to find all matches of the search text
  RegExp regExp = RegExp(text, caseSensitive: false);

  // Find all matches in the input string
  Iterable<Match> matches = regExp.allMatches(input);

  // Initialize the current index to track the position in the input string
  int currentIndex = 0;

  // Loop through the matches
  for (Match match in matches) {
    // Add non-matching text span
    textSpans.add(TextSpan(text: input.substring(currentIndex, match.start)));

    // Add matching text span with styling
    textSpans.add(
      TextSpan(
        text: input.substring(match.start, match.end),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    // Update the current index
    currentIndex = match.end;
  }

  // Add the remaining non-matching text span
  textSpans.add(TextSpan(text: input.substring(currentIndex)));

  // Return the formatted text with spans
  return Text.rich(TextSpan(children: textSpans));
}
