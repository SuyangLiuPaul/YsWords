import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-08-09. Every top-level page's AppBar pairs
/// `LanguageSwitcherButton` with `HomeIconButton`. SongsPage shipped
/// without the switcher: the page was deleted in v1.3.126, the button
/// was rolled out across the app while it was gone, and restoring the
/// page from its pre-deletion snapshot brought back an AppBar that had
/// missed the change. A user spotted it, not CI.
///
/// This is a source-level check rather than a widget test on purpose:
/// the bug is "a page forgot a convention", which is a property of
/// every page at once. Pumping them individually would need each new
/// page to be remembered in a list — the same kind of omission that
/// caused the bug.
void main() {
  test('every page with a HomeIconButton also offers the language '
      'switcher', () {
    final pages = Directory('lib/pages')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('_page.dart'));
    expect(pages, isNotEmpty, reason: 'no pages found — wrong cwd?');

    final missing = <String>[];
    for (final file in pages) {
      final src = file.readAsStringSync();
      // Only pages that actually build an AppBar with the home button
      // are in scope. Detail/among-page views without one are not.
      if (!src.contains('appBar: AppBar(')) continue;
      if (!src.contains('HomeIconButton')) continue;
      if (!src.contains('LanguageSwitcherButton')) {
        missing.add(file.uri.pathSegments.last);
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'these pages have a HomeIconButton but no '
          'LanguageSwitcherButton, so users cannot switch language '
          'from them: ${missing.join(', ')}',
    );
  });
}
