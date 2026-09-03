import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/constants/book_names.dart';
import 'package:yswords/constants/text_patterns.dart';
import 'package:yswords/models/strongs.dart';
import 'package:yswords/services/tagged_text_service.dart';
import 'package:yswords/widgets/implied_coverage_line.dart';

/// **How much the reader actually gains from the implied-coverage line,
/// and how much of the corpus it does not touch at all.**
///
/// `docs/autonomous-queue.md` sized the opportunity at 39,868 (verse,
/// number) pairs over 21,390 verses. That was measured on the raw
/// corpus and counts PAIRS. Neither is what a reader sees, so this file
/// re-measures under production's own conditions and asks the widget
/// itself which numbers it would print:
///
///   * a verse whose tagged runs do not cover the reader's verse falls
///     back to plain text and has no tap targets at all — 223 verses;
///   * a run whose `i` only repeats its own `s`, names `H0`/`G0`, or
///     names something the lexicon cannot answer prints nothing;
///   * one tap shows one line, so the unit of gain is a RUN, not a pair.
///
/// The answer is that the line is worth having and is also mostly
/// silent: **22,672 of 30,879 rendered verses (73.4%)** hold at least
/// one run that can print it, but **304,831 of 364,539 rendered runs
/// (83.6%) gain nothing** — tapping those is exactly what it was
/// before.
///
/// Restricted to numbers the verse's own original really contains and
/// that no run of the verse shows as `s` — the queue's question, asked
/// on production's input — the gain is **39,534 pairs over 21,230
/// verses**, against the queue's 39,868 / 21,390. The gap is the 223
/// fallen-back verses, the `i` entries that only repeat their run's own
/// `s`, and the 7 untagged runs that carry an `i` and no tap target.
/// Quote whichever figure you like, but say which one.
///
/// A ratchet like the rest of this suite: these may move when the
/// corpus is re-imported, and a move is a fact about the import, not a
/// licence to re-pin.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> readJson(String path) =>
      json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

  // The real lexicon, as `StrongsEntry`s, so `visibleNumbers` is asked
  // the same question the sheet asks it. Only presence matters here,
  // so the entries are not fully parsed.
  final lexicon = <String, StrongsEntry?>{};
  for (final file in ['hebrew', 'greek']) {
    for (final key in readJson('assets/strongs/$file.json').keys) {
      lexicon[key] = StrongsEntry(
        number: key,
        lemma: '',
        translit: '',
        pronunciation: '',
        gloss: '',
        definition: '',
      );
    }
  }

  final reading = <String, Map<String, String>>{};
  for (final row in (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync())
          as List)
      .cast<Map<String, dynamic>>()) {
    final english = bookNameToEnglish[row['book'] as String];
    if (english == null) continue;
    reading.putIfAbsent(english.toLowerCase().replaceAll(' ', '_'), () => {})[
        '${row['chapter']}:${row['verse']}'] = row['text'] as String;
  }

  final base = readJson('assets/originals_versification.json');
  final merged =
      readJson('assets/originals_versification_merged.json')['cuvs-yhwh']
          as Map<String, dynamic>;

  var taggedVerses = 0;
  var droppedMarkup = 0;
  var droppedCoverage = 0;
  var renderedVerses = 0;
  var renderedRuns = 0;
  var runsThatGain = 0;
  var runsThatGainNothing = 0;
  var versesThatGain = 0;
  var runsWithSeveralChips = 0;
  var mostChipsOnOneLine = 0;
  final unresolvable = <String>{};
  final untaggedWithImplied = <String>[];
  final newlyReachable = <String>{};
  final versesNewlyReachable = <String>{};

  for (final file in Directory('assets/tagged/cuvs-yhwh')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))) {
    final slug = file.uri.pathSegments.last.replaceAll('.json', '');
    final book = reading[slug] ?? const <String, String>{};
    final originalsFile = File('assets/originals/$slug.json');
    final originals = originalsFile.existsSync()
        ? readJson('assets/originals/$slug.json')
        : const <String, dynamic>{};
    for (final entry
        in (json.decode(file.readAsStringSync()) as Map<String, dynamic>)
            .entries) {
      taggedVerses++;
      final raw = entry.value as List;
      if (TaggedTextService.carriesImporterMarkup(raw)) {
        droppedMarkup++;
        continue;
      }
      final runs = TaggedTextService.reuniteGlossRuns(raw
          .map((r) => TaggedRun.fromJson(r as Map<String, dynamic>))
          .toList(growable: false));
      final verseText = book[entry.key];
      if (verseText == null) continue;
      if (!TaggedTextService.coversVerse(runs, sanitizeForSearch(verseText))) {
        droppedCoverage++;
        continue;
      }
      renderedVerses++;

      final present = <String>{};
      for (final originalRef
          in ((merged[slug] as Map<String, dynamic>?)?[entry.key] ??
              (base[slug] as Map<String, dynamic>?)?[entry.key] ??
              [entry.key]) as List) {
        for (final word in (originals[originalRef] as List? ?? const [])) {
          present.add(((word as Map<String, dynamic>)['s'] ?? '') as String);
        }
      }
      final shown = <String>{
        for (final r in runs)
          if (r.strongs.isNotEmpty) r.strongs,
      };

      var verseGains = false;
      for (final run in runs) {
        // A run with no printed text is skipped by `_taggedVerseLine`,
        // so it is not a tap target and cannot show anything.
        if (run.text.isEmpty) continue;
        renderedRuns++;
        for (final number in run.implied) {
          if (number != run.strongs &&
              !TaggedRun.isSuppliedMarker(number) &&
              !lexicon.containsKey(number)) {
            unresolvable.add(number);
          }
        }
        if (run.strongs.isEmpty && run.implied.isNotEmpty) {
          untaggedWithImplied.add('$slug ${entry.key} ${run.text}');
        }
        final chips = ImpliedCoverageLine.visibleNumbers(run, lexicon);
        if (chips.isEmpty) {
          runsThatGainNothing++;
          continue;
        }
        // An untagged run is not tappable, so whatever its `i` holds
        // stays out of reach — see `_taggedVerseLine`'s doc.
        if (!run.isTagged) {
          runsThatGainNothing++;
          continue;
        }
        runsThatGain++;
        verseGains = true;
        if (chips.length > 1) runsWithSeveralChips++;
        if (chips.length > mostChipsOnOneLine) {
          mostChipsOnOneLine = chips.length;
        }
        for (final number in chips) {
          if (shown.contains(number) || !present.contains(number)) continue;
          newlyReachable.add('$slug ${entry.key} $number');
          versesNewlyReachable.add('$slug ${entry.key}');
        }
      }
      if (verseGains) versesThatGain++;
    }
  }

  test('the sheet renders a tagged line on 30,879 verses', () {
    expect(taggedVerses, 31102);
    expect(droppedMarkup, 0,
        reason: 'the markup repair cleared this class; a re-import that '
            'reintroduces `<WH7931s>` would take verses off the line '
            'entirely, and that is a bigger problem than this feature');
    expect(droppedCoverage, 223,
        reason: 'pinned independently by tagged_verse_coverage_test.dart');
    expect(renderedVerses, 30879);
  });

  test('22,672 verses gain a line; 304,831 runs gain nothing', () {
    expect(renderedRuns, 364539);
    expect(runsThatGain, 59708);
    expect(runsThatGainNothing, 304831);
    expect(runsThatGain + runsThatGainNothing, renderedRuns,
        reason: 'every rendered run is in exactly one bucket');
    expect(versesThatGain, 22672);
    // 73.4% of rendered verses, 16.4% of rendered runs. Both are worth
    // stating together: the feature reaches most of the corpus and
    // almost none of the taps.
    expect(versesThatGain / renderedVerses, closeTo(0.734, 0.001));
    expect(runsThatGain / renderedRuns, closeTo(0.164, 0.001));
  });

  test('39,534 (verse, number) pairs become reachable, over 21,230 verses', () {
    // The queue's figures for the same question on the raw corpus are
    // 39,868 over 21,390. Lower here because 223 verses never render a
    // tap target and because an `i` that only repeats its run's own `s`
    // is not new reach.
    expect(newlyReachable, hasLength(39534));
    expect(versesNewlyReachable, hasLength(21230));
    // 約翰福音 3:5, the verse the whole argument was conducted over: the
    // span repair promoted 神 to G2316 θεός and 的国。 to G932 βασιλεία,
    // which left G3588 ὁ reachable nowhere. It is reachable again.
    expect(newlyReachable, contains('john 3:5 G3588'));
  });

  test('a line never has more than 12 chips, and usually has one', () {
    expect(mostChipsOnOneLine, 12);
    expect(runsWithSeveralChips, 6026);
  });

  test('no number in the shipped corpus is a dead end', () {
    expect(unresolvable, isEmpty,
        reason: 'every `i` entry resolves in assets/strongs/. The widget '
            'still filters unresolvable numbers, because this is a fact '
            'about today\'s import and not a guarantee about the next one');
  });

  test('every run with an empty `s` and a populated `i` is a supplied marker',
      () {
    // All 7 of them, and every one is an H0/G0 run — six of them the
    // divine name. `_taggedVerseLine` deliberately gives those no tap
    // target, so their `i` stays out of reach. That is the H0 decision
    // standing, not an oversight: 7 runs out of 364,539 is not a reason
    // to put a tap on a word no original word stands behind.
    expect(untaggedWithImplied, hasLength(7));
    expect(untaggedWithImplied, contains('numbers 7:89 要与雅伟'));
    expect(untaggedWithImplied, contains('1_timothy 3:16 就是神'));
    for (final where in untaggedWithImplied) {
      final parts = where.split(' ');
      final runs = (readJson('assets/tagged/cuvs-yhwh/${parts[0]}.json')[parts[1]]
              as List)
          .cast<Map<String, dynamic>>();
      final raw = runs.firstWhere((r) => r['w'] == parts[2]);
      expect(TaggedRun.isSuppliedMarker(raw['s'] as String), isTrue,
          reason: '$where has an empty `s` that is not H0/G0 — a real '
              'untagged run with implied numbers would be a new case and '
              'needs a decision, not this test passing quietly');
    }
  });
}
