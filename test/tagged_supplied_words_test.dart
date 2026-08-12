import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/tagged_text_service.dart';

/// 295 tagged runs carried `H0` / `G0`, which is not a Strong's number.
///
/// Neither is a key in `assets/strongs/`, so the Originals sheet drew a
/// dotted underline under the word, took the tap, and answered
/// 「Lexicon entry not found for H0」. The words carrying it are the
/// divine name — 152 bare 雅伟, 28 主 — which is the word a reader is
/// most likely to tap.
///
/// What the marker means was settled against `assets/originals/`, not
/// guessed from its shape: **178 of the 295 sit in a verse whose
/// original has no divine name at all.** 歷代志上 2:3 「雅伟就使他死了」
/// renders וַיְמִיתֵהוּ, one verb with its subject in the inflection;
/// 帖撒羅尼迦前書 1:7 「信主之人」 renders τοῖς πιστεύουσιν with no
/// κύριος anywhere in the verse. The remaining 117 are the CUV printing
/// the name twice where the Hebrew prints it once, and there the single
/// Hebrew word is already tagged on the other run (歷代志上 21:26).
///
/// So `H0` means "the translation supplies this; no original word
/// stands behind it" — the opposite of a Strong's number. Numbering
/// these H3068 / G2962 would tell a reader the Hebrew carries a word it
/// does not, which is the error this repo's priority rule is about.
/// They are untagged instead: the text still prints, and the app stops
/// promising an answer it has no way to give.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the supplied-name marker is not read as a Strong\'s number', () {
    final supplied = TaggedRun.fromJson({'w': '雅伟', 's': 'H0'});
    expect(supplied.isTagged, isFalse);
    expect(supplied.strongs, '');
    // The scripture is untouched — only the promise of a lexicon entry
    // goes away.
    expect(supplied.text, '雅伟');

    expect(TaggedRun.fromJson({'w': '主', 's': 'G0'}).isTagged, isFalse);
    // A real number still tags.
    expect(TaggedRun.fromJson({'w': '雅伟', 's': 'H3068'}).strongs, 'H3068');
  });

  test('歷代志上 2:3 prints 雅伟 and offers no lexicon entry for it',
      () async {
    final runs = await TaggedTextService.forVerse(
      version: 'cuvs-yhwh',
      englishBook: '1 Chronicles',
      chapter: 2,
      verse: 3,
    );
    expect(runs, isNotNull);

    // Two 雅伟 in the verse: the first renders יְהוָה in 「在雅伟眼中」
    // and keeps its number; the second is supplied by the translator
    // for the subject of וַיְמִיתֵהוּ and must not claim one.
    final divine = runs!.where((r) => r.text.contains('雅伟')).toList();
    expect(divine.length, 2);
    expect(divine.first.strongs, 'H3068');
    expect(divine.last.isTagged, isFalse);
    expect(runs.map((r) => r.text).join(), contains('雅伟就使他死了'));
  });

  /// The drift check, and the reason this is a data test as well as a
  /// unit test: a re-import that invents a third unresolvable number
  /// would put another dead tap on screen, and no widget test would
  /// notice — the code renders exactly the runs it is handed.
  test('every other number in the tagged corpus resolves in the lexicon',
      () {
    final lexicon = <String>{
      ...(json.decode(File('assets/strongs/hebrew.json').readAsStringSync())
              as Map<String, dynamic>)
          .keys,
      ...(json.decode(File('assets/strongs/greek.json').readAsStringSync())
              as Map<String, dynamic>)
          .keys,
    };

    final unresolvable = <String, int>{};
    var supplied = 0;
    for (final f
        in Directory('assets/tagged/cuvs-yhwh').listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      final book = json.decode(f.readAsStringSync()) as Map<String, dynamic>;
      for (final runs in book.values) {
        for (final r in runs as List<dynamic>) {
          final run = r as Map<String, dynamic>;
          for (final n in <String>[
            if (run['s'] is String) run['s'] as String,
            ...((run['i'] as List?) ?? const []).cast<String>(),
          ]) {
            if (n.isEmpty || lexicon.contains(n)) continue;
            if (TaggedRun.isSuppliedMarker(n)) {
              supplied++;
            } else {
              unresolvable[n] = (unresolvable[n] ?? 0) + 1;
            }
          }
        }
      }
    }

    expect(unresolvable, isEmpty,
        reason: 'a tagged run promises a lexicon entry that does not exist');
    // Measured 2026-08-12: 253 H0 + 42 G0. Pinned so the count cannot
    // grow quietly — a rise means the importer is marking something new
    // as supplied, which needs reading before it is believed.
    expect(supplied, 295);
  });
}
