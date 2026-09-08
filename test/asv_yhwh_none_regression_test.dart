// 2026-09-09: 895 verses of `asv-yhwh` shipped reading the literal
// string `None`, and this file is the guard that they do not again.
//
// 以弗所書 2:1 read, on a phone, in prod:
//
//     NoneAndNone NoneyouNone did he make alive, NonewhenNone …
//
// IT WAS NOT OURS AND IT WAS NOT THE PUBLISHER'S DATABASE. Both were
// carrying it faithfully: the corruption was in the theWord module
// itself — 19,167 `None`s glued to words, in `asv+.ont` as well as in
// `ASV(Yahweh)2026.ont`. Upstream of that, a tag pair was interpolated
// into an f-string while it was `None`, which is why the damage brackets
// each word on both sides and why the `<i>did</i>` sitting beside it in
// the same verse survived intact.
//
// The publisher rebuilt the module the same morning and nothing else in
// it moved — same 31,114 lines, same 346,817 Strong's tags, same 6,641
// `<i>`. The edition was re-imported and un-hidden.
//
// WHAT THE CORRUPTION WAS HIDING, and why the tagged numbers moved with
// it: a Strong's tag with no English word in front of it is an implied
// lemma. In the broken module every tag had a word in front — `None` was
// that word — so `implied` measured 0. It is 22 now, and 0 was never a
// fact about the ASV. See `TAGGED_EXPECTED` in `tools/import_ydh_texts.py`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/bible_versions.dart';

void main() {
  late List<Map<String, dynamic>> rows;

  setUpAll(() {
    rows = (json.decode(File('assets/asv-yhwh.json').readAsStringSync())
            as List<dynamic>)
        .cast<Map<String, dynamic>>();
  });

  test('no verse has None glued to a word', () {
    // Glued, not present: `None` IS an English word and the ASV uses it
    // twelve times. What must never come back is the wrapper form, which
    // has no space on one side — `NoneAndNone`, `Nonefor<WG1223>None`.
    final glued = RegExp(r'None\S|\SNone(?![A-Za-z])');
    final offenders = rows
        .where((r) => glued.hasMatch(r['text'] as String))
        .map((r) => '${r['book']} ${r['chapter']}:${r['verse']}')
        .toList();
    expect(offenders, isEmpty,
        reason: 'the module regressed, or an old one was re-imported — '
            'check the .ont before touching anything in this repo');
  });

  test('the twelve real Nones are still there', () {
    // The other half of the claim: a sweep that "fixed" this by deleting
    // every None would take scripture with it. 歷代志上 15:2 is the
    // one to read — 「None ought to carry the ark of God but the
    // Levites」.
    final word = RegExp(r'(?<![A-Za-z])None(?![A-Za-z])');
    final kept = rows.where((r) => word.hasMatch(r['text'] as String));
    expect(kept, hasLength(12));
    expect(
        rows.firstWhere((r) => r['id'] == '013015002')['text'] as String,
        contains('None ought to carry'));
  });

  test('the edition is offered again', () {
    expect(disabledVersions, isNot(contains('asv-yhwh')));
    expect(availableVersions.map((v) => v.value), contains('asv-yhwh'));
    expect(rows, hasLength(31086));
  });
}
