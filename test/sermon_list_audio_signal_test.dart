import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/sermons_page.dart';
import 'package:yswords/services/sermon_audio_service.dart';
import 'package:yswords/services/sermon_service.dart';

/// The sermon list used to contain the string "audio" zero times.
///
/// The player is docked on the DETAIL page only — `sermon_detail_page.
/// dart`, `bottomNavigationBar: SermonAudioBar(sermonId: s.id)` — so a
/// reader browsing the library had no way to find out that any sermon
/// was playable without opening one at random and looking.
///
/// The shape of the gap USED to be the interesting part: every sermon had
/// audio — 289 ids in `assets/sermons/index.json`, 289 non-empty entries in
/// `assets/sermons/audio_index.json`, no id in one and not the other.
///
/// **That stopped being true on 2026-09-06 and the clause changed by
/// itself, which is what it was built to do.** 125 of Pastor Eric's
/// messages were merged in from the fuyindiantai staging library
/// (`scripts/merge_sermon_library.py`), so the corpus is 414 sermons of
/// which 289 have a recording. `sermonAudioClause` takes the partial
/// branch and the line now reads 「429 篇讲道,共 21 个主题 · 289 篇有录音」.
/// Nothing in the feature was edited to make that happen — the clause is
/// derived from two counted numbers and consults no constant, which is
/// precisely the property tested below, and this is the day it paid.
///
/// **Why the merged 125 have no audio, so that nobody adds it carelessly.**
/// Their recordings exist and the library holds their URLs, but
/// `SermonAudioService.baseUrl` is ONE host
/// (`www.christiandiscipleschurch.org`) and every `audio_index.json` entry
/// is a path under it. The library's audio lives on fuyindiantai.org, so an
/// entry for a merged sermon would resolve to
/// `christiandiscipleschurch.org/https://fuyindiantai.org/…` and 404.
/// Carrying it needs a per-part absolute URL in `SermonAudioPart`, which is
/// a `lib/` change; until then `audio_index.json` stays at 289 entries and
/// the honest sentence is the partial one.
///
/// The badge ruling is unchanged and now has a second reason behind it: a
/// play glyph on 289 of 414 rows would be a real distinction, but the
/// distinction it draws is between two source archives rather than between
/// two kinds of sermon, and the header already says both numbers.
///
/// It is therefore one clause on the existing summary line. What these
/// tests pin:
///
///   1. the clause is DERIVED — `sermonAudioClause` is given two
///      counts and never consults a constant, so 289 appears nowhere
///      in the feature and the sentence survives the corpus changing;
///   2. the universal wording is only reachable when the corpus really
///      is wholly playable, and the partial wording replaces it
///      otherwise;
///   3. nothing is claimed at all when nothing can be played;
///   4. the clause actually reaches the screen, joined to the count
///      clause — the assertion a wiring mistake fails.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // `SermonAudioService` builds a `SongPlaybackEngine` in a field
    // initialiser, which constructs an audioplayers `AudioPlayer` and
    // subscribes to its global event channel. With no plugin behind
    // it that throws MissingPluginException out of the platform
    // channel and fails the test — noise from the transport, not from
    // anything these tests assert. No-op handlers silence it. Nothing
    // here plays audio; what is under test is a sentence.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in const [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
    ]) {
      messenger.setMockMethodCallHandler(
          MethodChannel(name), (call) async => null);
    }
  });

  // ── 1. The claim is derived, not written down ──────────────────

  group('sermonAudioClause derives its wording from the counts', () {
    test('all playable → the universal claim, in every locale', () {
      expect(
        sermonAudioClause(
            configured: true, total: 289, playable: 289, locale: 'zh-Hans'),
        '每篇都有录音',
      );
      expect(
        sermonAudioClause(
            configured: true, total: 289, playable: 289, locale: 'zh-Hant'),
        '每篇都有錄音',
      );
      expect(
        sermonAudioClause(
            configured: true, total: 289, playable: 289, locale: 'en'),
        'every one has a recording',
      );
    });

    test('the universal claim does not mention a number', () {
      // The point of a separate string: beside a live "{count}
      // sermons" the number would be printed twice and read as a
      // typo. It also means no corpus size is baked into the wording.
      for (final loc in const ['zh-Hans', 'zh-Hant', 'en']) {
        final s = sermonAudioClause(
            configured: true, total: 289, playable: 289, locale: loc)!;
        expect(RegExp(r'\d').hasMatch(s), isFalse,
            reason: '$loc universal clause contains a digit: $s');
      }
    });

    test('partly playable → the count, not the universal claim', () {
      expect(
        sermonAudioClause(
            configured: true, total: 289, playable: 200, locale: 'zh-Hans'),
        '200 篇有录音',
      );
      expect(
        sermonAudioClause(
            configured: true, total: 289, playable: 200, locale: 'zh-Hant'),
        '200 篇有錄音',
      );
      expect(
        sermonAudioClause(
            configured: true, total: 289, playable: 200, locale: 'en'),
        '200 with recordings',
      );
    });

    test('one short of the corpus is still the count branch', () {
      // The boundary that matters: 288 of 289 must NOT say "every
      // one". An off-by-one here is a claim the reader cannot check
      // and would have no reason to doubt.
      expect(
        sermonAudioClause(
            configured: true, total: 289, playable: 288, locale: 'en'),
        '288 with recordings',
      );
      expect(
        sermonAudioClause(
            configured: true, total: 289, playable: 289, locale: 'en'),
        'every one has a recording',
      );
    });

    test('the number is the playable count, whatever the corpus size', () {
      // Nothing in the feature knows 289. Same shape, different
      // corpus: the wording follows the arguments.
      expect(
        sermonAudioClause(
            configured: true, total: 4, playable: 3, locale: 'en'),
        '3 with recordings',
      );
      expect(
        sermonAudioClause(
            configured: true, total: 4, playable: 4, locale: 'en'),
        'every one has a recording',
      );
    });

    test('an unknown locale falls back to English rather than blank', () {
      expect(
        sermonAudioClause(
            configured: true, total: 2, playable: 2, locale: 'fr'),
        'every one has a recording',
      );
    });
  });

  // ── 2. Silence is a valid answer ───────────────────────────────

  group('sermonAudioClause says nothing when nothing plays', () {
    test('no clause when audio hosting is not configured', () {
      // SermonAudioService's own doc comment: "A play button that
      // 404s would be worse than no play button." A sentence claiming
      // playability when nothing can play is that 404 in prose.
      expect(
        sermonAudioClause(
            configured: false, total: 289, playable: 289, locale: 'en'),
        isNull,
      );
    });

    test('no clause when nothing is playable, or before the index loads', () {
      // `playableSermonCount` / `hasAudio` both answer 0 / false
      // against a null index, so this branch is also the first frame.
      expect(
        sermonAudioClause(
            configured: true, total: 289, playable: 0, locale: 'en'),
        isNull,
      );
    });

    test('no clause for an empty corpus', () {
      expect(
        sermonAudioClause(
            configured: true, total: 0, playable: 0, locale: 'en'),
        isNull,
      );
    });
  });

  // ── 3. Which branch the real assets select ─────────────────────

  test('the shipped corpus selects the PARTIAL branch — 289 of 429', () {
    // Re-derived from the two assets, so this test tells the truth
    // about the corpus rather than repeating a number from a brief.
    final sermons =
        (json.decode(File('assets/sermons/index.json').readAsStringSync())
            as List)
            .cast<Map<String, dynamic>>();
    final audio = json.decode(
            File('assets/sermons/audio_index.json').readAsStringSync())
        as Map<String, dynamic>;

    final ids = sermons.map((s) => s['id'] as String).toSet();
    expect(ids, hasLength(sermons.length),
        reason: 'duplicate sermon ids would double-count the corpus');

    final playable = ids
        .where((id) => (audio[id] as List?)?.isNotEmpty ?? false)
        .length;

    expect(sermons.length, 429);
    expect(playable, 289,
        reason: 'the corpus grew to 414 on 2026-09-06 and the audio index '
            'did not; if either moves, read why before editing this');
    // Both sides pinned, so this cannot pass on an empty corpus and cannot
    // pass on an audio index that grew without anyone noticing.
    expect(playable, lessThan(sermons.length),
        reason: 'the corpus is no longer wholly playable; if it becomes so '
            'again the universal branch must come back and this assertion '
            'is how you find out');

    // Every audio entry belongs to a sermon that exists — the direction
    // the old equality also covered, and which must not be lost with it.
    final orphans =
        audio.keys.where((k) => !ids.contains(k)).toList()..sort();
    expect(orphans, isEmpty);

    expect(
      sermonAudioClause(
          configured: true,
          total: sermons.length,
          playable: playable,
          locale: 'en'),
      uiStrings['sermonAudioSome']!['en']!.replaceAll('{audioCount}', '289'),
    );
  });

  // ── 4. It reaches the screen ───────────────────────────────────

  /// Mount the real page with the real assets behind it.
  ///
  /// The three services cache, so warming them inside [runAsync] (the
  /// only place a widget test may do real bundle I/O) makes the page's
  /// own `_loadAll` resolve on a microtask that `pump` can flush.
  /// Without the warm-up the FutureBuilder never leaves its spinner
  /// and the page renders nothing but the AppBar — verified, and the
  /// reason this is not simply `pumpAndSettle`, which also cannot
  /// settle a `CircularProgressIndicator`.
  Future<void> mountSermonsPage(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.runAsync(() async {
      await SermonService.instance.loadByTopic();
      await SermonService.instance.loadRefs();
      await SermonAudioService.instance.load();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettings>(
        create: (_) => AppSettings(),
        child: const MaterialApp(home: SermonsPage()),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The one summary Text — found by the count clause, which is
  /// present in every state including "no matches".
  Text summaryLine(WidgetTester tester) => tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').contains('篇讲道'),
          description: 'the sermons summary line',
        ),
      );

  testWidgets('the sermons list renders the count and the audio clause',
      (tester) async {
    await mountSermonsPage(tester);

    // Default locale is zh-Hans (`AppSettings._locale`).
    final clause = uiStrings['sermonAudioSome']!['zh-Hans']!
        .replaceAll('{audioCount}', '289');
    final text = summaryLine(tester).data!;

    expect(text, contains(clause),
        reason: 'the summary line no longer tells the reader the library is '
            'listenable — this is the whole feature');
    // Joined onto the count clause, on one line, with the house
    // separator. Not floating somewhere else on the page.
    expect(text, contains(' · '));
    expect(text.indexOf('篇讲道'), lessThan(text.indexOf(clause)),
        reason: 'the audio clause must follow the count, not lead it');
    // And it is the whole sentence, derived end to end from the assets:
    // 414 sermons, 21 topics, 289 of them playable. Every one of those
    // three numbers is counted from `assets/sermons/`; none is written
    // down anywhere in the feature.
    expect(text, '429 篇讲道,共 21 个主题 · 289 篇有录音');
  });

  testWidgets('the page still shows no per-row audio badge', (tester) async {
    // The other half of the ruling, and the half a later
    // "improvement" is most likely to undo. Every sermon has audio, so
    // a play or headphone glyph on each of the 289 rows would
    // distinguish nothing — it is decoration, and decoration is what
    // trains a reader to stop reading marks. The header says it once.
    //
    // **The topic groups have to be EXPANDED first.** The first
    // version of this test did not do that, and survived its own
    // mutation: the rows live inside collapsed `ExpansionTile`s, are
    // never built, and `find.byIcon` over an unbuilt subtree finds
    // nothing no matter what you put in it. A play badge was inserted
    // on every row and the test still passed. The row-count assertion
    // below is what stops it decaying back into that.
    await mountSermonsPage(tester);
    expect(find.byType(ExpansionTile), findsWidgets);
    await tester.tap(find.byType(ExpansionTile).first);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final rows = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_SermonRow',
      description: 'built sermon rows',
    );
    expect(rows, findsWidgets,
        reason: 'no sermon row was actually built, so nothing below this '
            'line is capable of failing. Fix the test before trusting it.');

    for (final icon in const [
      Icons.play_arrow,
      Icons.play_arrow_rounded,
      Icons.play_circle,
      Icons.play_circle_outline,
      Icons.play_circle_fill,
      Icons.headphones,
      Icons.headset,
      Icons.volume_up,
      Icons.audiotrack,
      Icons.graphic_eq,
      Icons.mic,
    ]) {
      expect(find.byIcon(icon), findsNothing,
          reason: 'a playability glyph appeared in the sermon list; the '
              'claim belongs in the header once, not on 414 rows. See '
              'sermonAudioClause.');
    }
  });

  testWidgets('the audio clause is a library fact and ignores the search',
      (tester) async {
    // The count beside it is filtered and live; this clause is not. A
    // filtered audio count would fluctuate under the reader's fingers
    // while carrying no decision value — they still have to open a
    // sermon to play it.
    await mountSermonsPage(tester);
    final clause = uiStrings['sermonAudioSome']!['zh-Hans']!
        .replaceAll('{audioCount}', '289');
    final before = summaryLine(tester).data!;
    expect(before, contains(clause));

    await tester.enterText(
        find.byType(TextField), 'zzzzz-no-such-sermon-zzzzz');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final after = summaryLine(tester).data!;
    expect(after, isNot(equals(before)),
        reason: 'the count clause did not react to the search at all, so '
            'this test is no longer exercising a filtered state');
    expect(after, contains(clause),
        reason: 'the audio clause changed or vanished when the reader '
            'searched. It is a fact about the library, not about the '
            'search result — and "289 have recordings" must not silently '
            'start meaning "289 of these three".');
    // Even with nothing matching, the library is still listenable, and the
    // number in the clause is the library's, not the filter's.
    expect(after, '0 篇讲道,共 0 个主题 · 289 篇有录音');
  });
}
