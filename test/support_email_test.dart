// The app shows readers exactly one contact address, and it is on a
// domain the project controls.
//
// Before 2026-08-31 it showed three different personal Gmail addresses —
// paulsyliu@, paul.sy.liu@ and lsy95112@ — hardcoded in eight places
// across five files. Nothing enforced agreement between them, and a
// missed copy fails silently: one screen quietly keeps pointing at an
// old inbox, and you find out when a reader writes somewhere nobody
// reads.
//
// So this scans lib/ WHOLE rather than the files that happen to use the
// constant today. A test that checked only the known call sites could
// not catch the case it exists for — a NEW screen with a fresh
// hardcoded address.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/contact.dart';

void main() {
  // Every Dart source under lib/, read once.
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => MapEntry(f.path, f.readAsStringSync()))
      .toList();

  test('the support address is on a domain we control', () {
    expect(kSupportEmail, 'support@yahwehword.com');
    expect(kSupportEmail.endsWith('@yahwehword.com'), isTrue,
        reason: 'a contact address on someone else\'s domain cannot be '
            'redirected without shipping a new build to six platforms');
  });

  test('no personal address survives anywhere in lib/', () {
    // The three that were actually there, by name. Not a generic
    // "@gmail.com" sweep: this states what was removed, so a reader of a
    // future failure knows what they are looking at.
    const banned = [
      'paulsyliu@gmail.com',
      'paul.sy.liu@gmail.com',
      'lsy95112@gmail.com',
    ];
    final offenders = <String>[];
    for (final entry in sources) {
      for (final bad in banned) {
        if (entry.value.contains(bad)) offenders.add('${entry.key}: $bad');
      }
    }
    expect(offenders, isEmpty,
        reason: 'personal inbox addresses are back in shipped code:\n'
            '${offenders.join('\n')}');
  });

  test('no OTHER address is hardcoded as a contact either', () {
    // Catches the next one before it ships. Deliberately narrow: only
    // literal addresses, and only outside comments — the doc comments in
    // contact.dart and error_reporter.dart name old addresses on purpose,
    // to explain what changed.
    final emailRe = RegExp(r"'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'");
    final allowed = <String>{"'$kSupportEmail'"};
    final offenders = <String>[];
    for (final entry in sources) {
      if (entry.key.endsWith('constants/contact.dart')) continue;
      final code = entry.value
          .split('\n')
          .where((l) {
            final t = l.trimLeft();
            return !t.startsWith('//') && !t.startsWith('///') && !t.startsWith('*');
          })
          .join('\n');
      for (final m in emailRe.allMatches(code)) {
        final lit = m.group(0)!;
        // resend.dev is the mail SENDER, configured server-side; it is
        // not a contact address and never appears in the UI.
        //
        // example.com is reserved by RFC 2606 for exactly this use. The
        // one occurrence is the hintText of the "Reply-to email" field
        // on the feedback form — an example of the format for an address
        // the READER types, not an address the app writes to. Allowing
        // the reserved domain rather than that one file keeps the rule
        // about intent instead of location.
        if (allowed.contains(lit) ||
            lit.contains('resend.dev') ||
            lit.contains('@example.com')) {
          continue;
        }
        offenders.add('${entry.key}: $lit');
      }
    }
    expect(offenders, isEmpty,
        reason: 'a literal email address is hardcoded in shipped code — '
            'use kSupportEmail so it stays redirectable:\n'
            '${offenders.join('\n')}');
  });
}
