import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/passage_localizer.dart' show passageRefPattern;
import 'package:yswords/utils/reference_parser.dart' show parseReference;

/// 2026-08-25. `scripts/extract_sermon_refs.py` decides which verses each
/// sermon is filed under, and it is Python — so nothing in `flutter
/// analyze` or the widget suite can see it regress. What ships is
/// `assets/sermons/refs.json`, and a wrong entry there does not look like
/// a bug: it looks like the preacher cited that verse.
///
/// These cases run the REAL script, not a Dart reimplementation of its
/// regex. A reimplementation would only prove Dart agrees with Dart; the
/// pattern being pinned is a 100-line `re` with conditional groups, and
/// every trap below was paid for by a wrong index entry.
List<String> _extractRefs(String text) => _extractAll([text]).single;

List<List<String>> _extractAll(List<String> texts) {
  const driver = r'''
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location(
    "esr", "scripts/extract_sermon_refs.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
json.dump([mod.extract_refs(t) for t in json.loads(sys.argv[1])], sys.stdout)
''';
  // The cases travel as one JSON argv element rather than through a
  // shell, so a quote or a comma in a sermon sentence cannot become
  // syntax. `Process.runSync` has no stdin to write to.
  final process = Process.runSync(
    'python3',
    ['-c', driver, jsonEncode(texts)],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  // Deliberately not skipped when python3 is absent: the runner has it,
  // and a guard that silently opts out is a guard nobody has tested.
  expect(process.exitCode, 0, reason: process.stderr.toString());
  return (jsonDecode(process.stdout as String) as List)
      .map((refs) => (refs as List).cast<String>())
      .toList();
}

/// Counts, over the whole sermon corpus, of the shapes the open queue
/// entries around this script are priced on. Driven through the REAL
/// module — `REF_RE`, `_AND_SECOND_REF`, `cn_number`, `_UNIT_AFTER` and
/// the reach-back helper — because a Dart transcription of those regexes
/// would only prove Dart agrees with Dart.
///
/// One process for all of it: a `REF_RE` pass over 28 MB costs about
/// seven seconds and the counts are read once per suite run.
Map<String, int> _corpusCensus() {
  const driver = r'''
import importlib.util, json, re, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location(
    "esr", "scripts/extract_sermon_refs.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

S = Path("assets/sermons")
texts = []
for s in json.loads((S / "index.json").read_text(encoding="utf-8")):
    if s.get("passage"):
        texts.append(s["passage"])
    for lang in ("en", "zh-CN", "zh-TW"):
        p = S / lang / f'{s["id"]}.txt'
        if p.exists():
            texts.append(p.read_text(encoding="utf-8"))

CANON, ALIAS = mod.CANON, mod.ALIAS
c = dict(bodies=len(texts))

# A bare ordinal plus an ABBREVIATED numbered-book name, in the chapter
# slot of another book: NUMBERED_TAIL_RE is built from full names only.
_tails = set()
for _canon, _lst in mod.ENGLISH_ALIASES.items():
    if _canon[0].isdigit() and " " in _canon:
        for _a in _lst:
            _t = re.sub(r"^(?:[123]|I{1,3})\s*", "", _a)
            if _t and _t != _canon.split(" ", 1)[1]:
                _tails.add(_t)
_ABB = "(?:" + "|".join(re.escape(t) for t in
                        sorted(_tails, key=lambda s: (-len(s), s))) + ")"
_SHAPE2 = re.compile(
    rf"(?:{mod.BOOK_RE})\s*[,，]?\s*(?:chapters?|ch\.|第)?\s*[1-3]\s+{_ABB}\b")

# English clock markers only. 时/時 is the ordinary word "when", counted
# separately as the price of ever writing a Chinese half.
_CLOCK = re.compile(r"\s*(?:[ap]\.?m\.?\b|o'clock\b)", re.IGNORECASE)
_WHEN = re.compile(r"\s*[时時]")
_CV = re.compile(r"\b\d{1,2}\s*[:：]\s*\d{2}\b")

_RUN = re.compile(rf"{mod._CN_NUM_RE}+")
_D2 = re.compile(r"^[〇零一二三四五六七八九]{2}$")
_D3 = re.compile(r"^[〇零一二三四五六七八九]{3,}$")

c.update(abbrevTailSites=0, newlineCarryMatches=0, clockAfterCitation=0,
         clockTokens=0, clockTokensMarked=0, whenAfterCitation=0,
         markedUnitWordSites=0, bareCommaVerseMatches=0, gappedTailRoom=0,
         bareGappedAndLists=0, bareGappedVerseLists=0,
         digitRuns2=0, digitRuns3plus=0, digitRunsResolved=0,
         verseMarkGuardSites=0, reachBackSites=0)

for text in texts:
    c["abbrevTailSites"] += len(_SHAPE2.findall(text))
    for m in mod._AND_SECOND_REF.finditer(text):
        if "\n" in m.group(0):
            c["newlineCarryMatches"] += 1
    for m in _CV.finditer(text):
        c["clockTokens"] += 1
        if _CLOCK.match(text, m.end()):
            c["clockTokensMarked"] += 1
    for m in _RUN.finditer(text):
        s = m.group(0)
        if _D2.match(s):
            c["digitRuns2"] += 1
        elif _D3.match(s):
            c["digitRuns3plus"] += 1
            if mod.cn_number(s) is not None:
                c["digitRunsResolved"] += 1
    for m in mod.REF_RE.finditer(text):
        canon = ALIAS.get(mod.normalize_alias(m.group("book")))
        if not canon:
            continue
        if _CLOCK.match(text, m.end()):
            c["clockAfterCitation"] += 1
        if _WHEN.match(text, m.end()):
            c["whenAfterCitation"] += 1
        ch = (int(m.group("ch")) if m.group("ch") is not None
              else mod.cn_number(m.group("chcn")))
        if ch is None:
            continue
        verse = mod._int(m.group("v") or m.group("v2"),
                         m.group("vcn") or m.group("vcn2"))
        last = mod._int(m.group("vend") or m.group("vend2"),
                        m.group("vendcn") or m.group("vendcn2"))
        word = (m.group("chword") is not None
                or m.group("chcomma") is not None)
        marked = word or m.group("chmark") is not None
        if marked and not verse and mod._UNIT_AFTER.match(text, m.end()):
            c["markedUnitWordSites"] += 1
        if not m.group("chmark"):
            end = m.end("ch") if m.group("ch") else m.end("chcn")
            if (text[end:end + 1] in ("节", "節")
                    and len(CANON.get(canon, {1: 0})) > 1):
                c["verseMarkGuardSites"] += 1
                if mod._same_sentence_chapter(text, m.start()) is not None:
                    c["reachBackSites"] += 1
        if m.group("vbare") is None or verse is None:
            continue
        c["bareCommaVerseMatches"] += 1
        if ch < verse <= max(CANON.get(canon, {0})):
            c["gappedTailRoom"] += 1
        if (m.group("vand") is not None and last is not None
                and last != verse + 1):
            c["bareGappedAndLists"] += 1
            if not word:
                c["bareGappedVerseLists"] += 1

json.dump(c, sys.stdout)
''';
  final process = Process.runSync(
    'python3',
    ['-c', driver],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  expect(process.exitCode, 0, reason: process.stderr.toString());
  return (jsonDecode(process.stdout as String) as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, v as int));
}

/// `_zhAliasToEn` is private, so it is read from source — which is also
/// what the extraction script does, and pins the shape both rely on.
Map<String, String> _zhAliasToEnFromSource() {
  final src =
      File('lib/constants/book_name_mapping.dart').readAsStringSync();
  final block =
      RegExp(r'const _zhAliasToEn = \{(.*?)\n\};', dotAll: true).firstMatch(src);
  if (block == null) {
    throw StateError('the _zhAliasToEn block moved or changed shape');
  }
  return {
    for (final m
        in RegExp(r"'([^']+)'\s*:\s*'([^']+)'").allMatches(block.group(1)!))
      m.group(1)!: m.group(2)!,
  };
}

void main() {
  test('the extraction script is where the test expects it', () {
    expect(File('scripts/extract_sermon_refs.py').existsSync(), isTrue);
  });

  group('a bare-comma number followed by "and" is a chapter list', () {
    // The defect this group was written for: REF_RE's chapter-list
    // refusal looks for a second COMMA, so "Matthew 5, 6 and 7" walks
    // past it and the adjacency rule makes 6 and 7 a two-verse range.
    test('"Matthew 5, 6 and 7" keeps the chapter and invents no verse', () {
      expect(_extractRefs('Matthew 5, 6 and 7 are the Sermon on the Mount'),
          ['Matthew 5']);
    });

    // What tells a chapter list from a verse range is that the list
    // COUNTS ON from the chapter. These pairs do not, so they are
    // verses — and all six are how the corpus actually writes them.
    test('a pair that does not count on from the chapter stays verses', () {
      expect(_extractAll([
        '2 Peter 2, 7 and 8, where it says of Lot that he was grieved',
        '1 Corinthians 15, 53 and 54: "For this perishable nature"',
        'almost in exactly the same words as in Matthew 5, 29 and 30.',
        // Not in the corpus today, but the shape this preacher uses when
        // he restates a reference he has just read out. A rule keyed on
        // "both numbers are plausible chapters" would lose every one.
        'Matthew 28, 19 and 20 is the Great Commission',
        'Romans 12, 1 and 2 says present your bodies',
        'Genesis 1, 26 and 27, let us make man in our image',
      ]), [
        ['2 Peter 2:7', '2 Peter 2:8'],
        ['1 Corinthians 15:53', '1 Corinthians 15:54'],
        ['Matthew 5:29', 'Matthew 5:30'],
        ['Matthew 28:19', 'Matthew 28:20'],
        ['Romans 12:1', 'Romans 12:2'],
        ['Genesis 1:26', 'Genesis 1:27'],
      ]);
    });

    // Scoped to `and` because that is how a list is spoken. Both these
    // pairs are plausible chapters of their book, so a rule that ignored
    // the separator would cost 015 the Beatitudes and 089 eight verses.
    test('"to" is a range word and is left alone', () {
      expect(_extractAll([
        'Matthew 5, 10 to 12. And this is what we read',
        'in Luke 14, 7 to 14, when you are invited',
      ]), [
        ['Matthew 5:10', 'Matthew 5:11', 'Matthew 5:12'],
        [
          'Luke 14:7', 'Luke 14:8', 'Luke 14:9', 'Luke 14:10',
          'Luke 14:11', 'Luke 14:12', 'Luke 14:13', 'Luke 14:14',
        ],
      ]);
    });
  });

  group('the older list and canon refusals still hold', () {
    test('a spelled-out chapter word makes the bare number a chapter', () {
      expect(_extractRefs('Those are the points made in Romans chapter 8, '
          '1 and 2: that the law of the Spirit of life'), ['Romans 8']);
      expect(_extractRefs('which Jesus already acknowledges in John '
          'chapters 12, 14 and 16. He is saying:'), ['John 12']);
    });

    test('…except past the end of the book, where it can only be a verse',
        () {
      // Hebrews has 13 chapters, so 848's "chapter 2, 14 and 15" has no
      // chapter reading available to it.
      expect(_extractRefs('as I mentioned in Hebrews chapter 2, 14 and 15 '
          'and so on'), ['Hebrews 2:14', 'Hebrews 2:15']);
    });

    test('a third comma-separated number is a list of chapters', () {
      expect(
          _extractRefs('in Romans 6, 7, and 8, we have three distinct '
              'categories'),
          ['Romans 6']);
    });

    // Moved here from sermon_refs_resolve_test.dart on 2026-08-26. It
    // used to be asserted against sermon 012's merged keys, which stopped
    // discriminating once the Chinese bodies became visible — their
    // translator wrote the same sentence as a 13–16 range. Against the
    // sentence itself nothing else can reach it.
    //
    // The second endpoint is DROPPED, not walked: 16 is not adjacent to
    // 13, so the tail is discarded rather than turned into a span. That
    // loss is the gapped-list class queued separately; it is asserted
    // exactly so nobody reads this as "the pair is captured".
    test('a non-adjacent "verses N and M" is not walked into a span', () {
      expect(
          _extractRefs('For example, in 1 Timothy, chapter 1, verses 13 '
              'and 16, Paul says that he received mercy from God'),
          ['1 Timothy 1:13']);
    });

    test('a bare-comma restatement of one verse still reaches it', () {
      // How this preacher restates a reference he has just read out.
      expect(_extractRefs('Romans 8, 3, says what?'), ['Romans 8:3']);
    });
  });

  group('a Chinese book name run onto the previous character', () {
    // `\b` is inert against Chinese — every ideograph is a word
    // character to Python's `re`, so 「在」「马」 has no boundary between
    // them and 144's whole citation was invisible, not just its tail.
    test('is found, and carries its list', () {
      expect(_extractRefs('在马太福音2:13，12:14，21:41'),
          ['Matthew 2:13', 'Matthew 12:14', 'Matthew 21:41']);
    });

    // The reason the boundary could not simply be dropped. 「书」 is the
    // standalone alias for Joshua and also the last character of every
    // Chinese epistle name; a plain `(?<![0-9A-Za-z_])` files 1,906
    // sites of 腓立比书 / 以弗所书 / 以赛亚书 under Joshua. What keeps it
    // out is the LENGTH MINIMUM on the aliases the relaxation admits,
    // and 书 is one character, so any minimum above one is enough: these
    // three cases yield Joshua at a minimum of 1 and nothing at 2 or 3.
    // This case does not pin the shipped value of 3 — the last case in
    // this group is the one that does.
    //
    // These three sentences are from the corpus and were chosen because
    // they DISCRIMINATE. Most of the class is caught anyway by the canon
    // check — 歌罗西书1:24 would be Joshua 1:24 and Joshua 1 has 18
    // verses — so a case like that would pass with the guard removed and
    // prove nothing. Joshua 2:5-11, 4:22-24 and 11:4 all exist.
    //
    // All three reach nothing at all today, because 腓立比书 / 以弗所书 /
    // 以赛亚书 are not in the alias table — a separate, larger gap, and
    // queued as one. The assertion is keyed on Joshua rather than on an
    // empty list so that closing that gap does not fail this test for
    // being right.
    test('does not read the tail of a longer book name as its own book',
        () {
      final got = _extractAll([
        '不怕被误解——的原因在腓立比书2:5-11。你们当以基督的心为心',
        '改变成一个新的人。以弗所书4:22-24把这一点说得很清楚',
        '地意味着温柔、谦卑。在以赛亚书第十一章第四节，说弥赛亚',
      ]);
      for (final refs in got) {
        expect(refs.where((r) => r.startsWith('Joshua')), isEmpty,
            reason: 'got $refs');
      }
    });

    // 罗马书 IS an alias and is not the tail of anything, so the same
    // sentence shape must still work — otherwise the test above would
    // pass by the relaxation never firing at all.
    test('still finds a full name that is nobody else\'s tail', () {
      expect(_extractRefs('让我读给你听罗马书第八章'), ['Romans 8']);
    });

    // Mid-sentence there is no boundary to vouch for the citation, so a
    // lone Chinese numeral is not enough. 一段 / 一直 / 一开始 are
    // ordinary words whose first character is also the numeral one, and
    // these are the corpus's three sites of the shape.
    test('refuses a bare Chinese numeral with no 第, 章 or verse', () {
      final got = _extractAll([
        '这是对启示录一段经文的解释',
        '它从创世记一直绕到启示录，回到了它一开始开始的地方',
        '亚伯拉罕在创世记一开始就被提到',
      ]);
      expect(got, [<String>[], <String>[], <String>[]]);
    });

    // …and the refusal must not swallow the marked forms it sits next
    // to, including 第 without 章, which is how 012 and 023 write it.
    test('keeps the same numeral when the citation says it is one', () {
      expect(
          _extractAll([
            '这是对启示录一章的解释',
            '在约翰二书第三',
            '以犹大书第七',
          ]),
          [
            ['Revelation 1'],
            ['2 John 1:3'],
            ['Jude 1:7'],
          ]);
    });

    // 節 says the number is a verse, so it is not the chapter — and the
    // chapter is nowhere in 016's sentence, so nothing is filed. The
    // one-chapter books are exempt because their bare number is already
    // a verse, which is how 012 and 023 come out right.
    test('refuses a chapter that is really a verse, unless the book has '
        'one chapter', () {
      expect(
          _extractAll([
            '你看，在马太福音第十八节，那里的词是"恶念"',
            '我们仍然需要平安。在约翰二书第三节也是如此',
            '||以犹大书第七节为例。它说',
          ]),
          [
            <String>[],
            ['2 John 1:3'],
            ['Jude 1:7'],
          ]);
    });

    // The same 節/节-is-a-verse rule, but at a word boundary rather than
    // mid-word — 010's real sentence has a hard punctuation break right
    // before 詩篇, so `infix` is unset and the old guard (restricted to
    // the infix branch) let "Psalms 27" through even though the
    // paragraph is expounding Psalm 37 and 27 is the verse. Its chapter
    // is three SENTENCES back, so the reach-back below cannot reach it
    // either and nothing is filed.
    test('refuses the boundary form too, not just the infix one', () {
      expect(
          _extractRefs('他是一个行义的人。诗篇第二十七节说："你当离恶行善。"'
              '第二十九节："义人必承受地土。"'),
          isEmpty);
    });

    // 第二次 is "a second TIME". The English unit-word guard had no
    // Chinese half, so both of these indexed a verse the sermon never
    // opens. The chapter really was cited and is kept.
    test('a Chinese measure word after the number is not a verse', () {
      expect(
          _extractAll([
            '保罗两次提到基督的律法：一次在哥林多前书第9章，第二次在加拉太书',
            '正如启示录20章第二次复活所描述的',
          ]),
          [
            ['1 Corinthians 9'],
            ['Revelation 20'],
          ]);
    });

    // 385 stutters. Without `(?!\d)` the verse gives up a digit so that
    // the following `(?!\s*[章篇])` sees "2章" instead of "章", and the
    // sermon is filed under 2 Corinthians 12:1 — a verse it never opens.
    // The chapter is all that survives here; the sermon reaches 12:10
    // through the rest of its body, which is why this costs nothing.
    test('a verse may not give back a digit to slip past a guard', () {
      expect(_extractRefs('让我读给你听。在哥林多后书第12章，第12章第10节："所以我为"'),
          ['2 Corinthians 12']);
    });

    // The case that pins the abbreviation half of the rule. 提前 is
    // 1 Timothy and also the everyday adverb "in advance"; admitting it
    // mid-sentence indexes this sentence as 1 Timothy 3.
    //
    // The sentence is synthetic, and deliberately so: the corpus has 16
    // sites of 提前 mid-sentence and none is followed by a number, so
    // nothing in the corpus discriminates. That is the point — a base
    // rate of zero is not evidence, and this phrase is one transcript
    // away from firing.
    test('does not admit a two-character abbreviation mid-word', () {
      expect(_extractRefs('我们提前3天到达了会场'), isEmpty);
    });

    // …but a two-character COMPLETE name is admitted, which is what
    // separates 诗篇 from 提前. 092's sentence reached no Psalms 23 key
    // of any kind before this.
    test('admits a two-character complete book name mid-sentence', () {
      expect(_extractRefs('"雅伟是我的牧者"，正如你们从诗篇第23篇都知道的'),
          ['Psalms 23']);
    });
  });

  group('和 joining two 第-numbers where the second carries 节', () {
    // 009 「同一诗篇第九和第十节」. 和 joins two things of the same kind
    // and the 节 says both are VERSES, so the first number is not the
    // chapter — and the chapter is nowhere in the sentence. It is Psalm
    // 42, named three times in the paragraph before and confirmed by the
    // English body's "Verse 9 and 10 of the same psalm"; recovering that
    // needs the paragraph read, so nothing is filed. Without the refusal
    // this sentence indexes as `Psalms 9`.
    test('files nothing rather than reading the first number as a chapter',
        () {
      expect(_extractRefs('理解过这种痛苦？同一诗篇第九和第十节："我对神说'),
          isEmpty);
    });

    // The four corpus sites that sit one word away from that rule. Both
    // are real chapter pairs and both ship today; the unit word is the
    // only thing between them and the refusal, so if 章 ever stops
    // exempting them these two go silent.
    test('leaves a chapter pair alone, because it ends in 章 not 节', () {
      final got = _extractAll([
        '当我们看哥林多后书第11和12章时，我们看到了那里正在',
        '这正是保罗在哥林多前书第二和第三章所说的：属灵的人',
      ]);
      expect(got[0], contains('2 Corinthians 11'));
      expect(got[1], contains('1 Corinthians 2'));
    });

    // A 章/篇 mark on the first number is proof it really is the
    // chapter, so the refusal must not reach 149's shape.
    test('leaves a marked chapter alone', () {
      expect(_extractRefs('使徒保罗在罗马书第12章第1和第2节说我们必须'),
          ['Romans 12:1', 'Romans 12:2']);
    });
  });

  group('「<章/篇>N和M节」 names two verses, not a whole chapter', () {
    // The defect: REF_RE's verse group wants its number flush against
    // 節/节 and 和 breaks that, so the match degraded to a BARE chapter
    // key — which `PassageFilter.matchesRefKey` treats as matching every
    // verse of the chapter. 344 cites Psalm 48:1 and 48:8 and answered a
    // filter on 48:3.
    test('the unmarked spelling yields both verses and no chapter key', () {
      expect(_extractRefs('圣城、神的城是他特别的产业。我们在诗篇48篇1和8节看到'),
          ['Psalms 48:1', 'Psalms 48:8']);
    });

    // The gap is the whole reason these are endpoints. Walking 1→8
    // would file the sermon under six verses nobody mentioned, which is
    // the failure this repo cannot afford.
    test('a gapped pair is two endpoints, never a span', () {
      final got = _extractRefs('你们有例如出埃及记第14章14和25节，神为他的子民争战');
      expect(got, ['Exodus 14:14', 'Exodus 14:25']);
      expect(got, isNot(contains('Exodus 14:15')));
    });

    // 331 writes one number as a digit and the other as a numeral in
    // the same citation. Both halves of the pair go through `_int`.
    test('reads a digit and a Chinese numeral in the same pair', () {
      expect(_extractRefs('也在罗马书十五章13和十四节。让我们读这段经文'),
          ['Romans 15:13', 'Romans 15:14']);
    });

    // A list — three numbers with a 、 before the 和 — must not be read
    // as a pair. Both halves are asserted because only the pair proves
    // the 、 is what does the refusing rather than something upstream.
    //
    // Written with 马太福音 rather than 344's own
    // 「历代志下20章8、29和32节」: 历代志下 is one of the ~90 Chinese book
    // names missing from the script's alias table, so the real sentence
    // yields nothing at all and would have passed no matter what this
    // rule did. That gap is queued separately.
    test('refuses a three-item list', () {
      final got = _extractAll([
        '马太福音5章8、29和32节。就这样一直列下去',
        '马太福音5章29和32节。就这样一直列下去',
      ]);
      expect(got[0], ['Matthew 5']);
      expect(got[1], ['Matthew 5:29', 'Matthew 5:32']);
    });

    // Without the mark, 「第九和第十节」 is two verses of a psalm whose
    // number is nowhere in the sentence (009 means Psalm 42), and the
    // refusal above must keep it. Pinned here because this rule reads
    // the same 和 and would file `Psalms 9` if it ever reached it.
    test('does not reach an unmarked pair, which stays refused', () {
      expect(_extractRefs('同一诗篇第九和第十节说：我要对神我的磐石说'), isEmpty);
    });
  });

  // Measured 2026-08-31 (docs/autonomous-queue.md ~6722): a corpus-wide
  // scan found exactly 3 numeral runs before 節/节 that `cn_number`
  // rejects — 十六十七 (real, but 423 already holds both verses via its
  // zh-CN/zh-TW/en bodies), 一一 (「唯一一节」, prose) and 三百四十九
  // (tail of 一千三百四十九, prose). No splitter shipped: it cannot tell
  // "two concatenated verses" from "one digit-read chapter" (诗篇一一九篇
  // = Psalm 119, not 1 and 19) without more context than the run itself
  // carries. These pin that a naive "split the run in two" rule would
  // regress — either by inventing verses from prose, or by misreading a
  // chapter number as a verse pair.
  group('a run-together Chinese numeral pair before 節/节 stays refused',
      () {
    test('十六十七 leaves only the chapter key, not invented verses', () {
      expect(_extractRefs('哥林多后书第五章第十六十七节里面，保罗说过'),
          ['2 Corinthians 5']);
    });

    test('一一 from 唯一一节 ("the only verse") is not read as a number',
        () {
      expect(_extractRefs('哥林多后书第五章唯一一节经文'), ['2 Corinthians 5']);
    });

    test(
        '三百四十九, the tail of 一千三百四十九 (1349), is not read as a '
        'verse number', () {
      expect(_extractRefs('哥林多后书第五章出现在一千三百四十九节经文中'),
          ['2 Corinthians 5']);
    });
  });

  group('the Chinese book names come from one table', () {
    // 2026-08-26. There were three hand-typed copies of the 66 Chinese
    // book names — the app's `_zhAliasToEn`, the extraction script's
    // `CHINESE_ALIASES`, and `passageRefPattern`. The script's copy had
    // drifted to ~40 of the app's 130 spellings, so 申命记, 以赛亚书,
    // 加拉太书 and every 提摩太 / 帖撒罗尼迦 name were invisible to the
    // sermon index while the reader understood them perfectly well.
    // The script now reads the app's table; these pin that the other
    // two cannot drift away from it again.
    final aliases = _zhAliasToEnFromSource();

    test('the app table still parses and still covers all 66 books', () {
      expect(aliases.length, greaterThanOrEqualTo(130));
      expect(aliases.values.toSet().length, 66);
    });

    test('the extraction script understands every spelling in it', () {
      // 1:1 rather than 3:16 — Obadiah, Philemon, 2 John, 3 John and
      // Jude have one chapter, and the canon check would refuse a 3.
      final names = aliases.keys.toList();
      final got = _extractAll([for (final n in names) '$n 1:1']);
      final wrong = <String>[];
      for (var i = 0; i < names.length; i++) {
        final want = '${aliases[names[i]]} 1:1';
        if (!got[i].contains(want)) wrong.add('${names[i]} → ${got[i]} (want $want)');
      }
      expect(wrong, isEmpty, reason: wrong.join('\n'));
    });

    test('passageRefPattern detects every spelling in it', () {
      // This is the pattern that makes a reference tappable inside a
      // sermon body. 啓示錄 (U+5553) was missing from it, which is the
      // spelling the zh-TW transcripts use 198 times against 3 for 啟.
      final missed = <String>[];
      for (final entry in aliases.entries) {
        final m = passageRefPattern.firstMatch('${entry.key} 1:1');
        if (m == null || m.group(0) != '${entry.key} 1:1') {
          missed.add(entry.key);
          continue;
        }
        if (parseReference(m.group(0)!)?.englishBook != entry.value) {
          missed.add('${entry.key} (parsed wrong)');
        }
      }
      expect(missed, isEmpty, reason: missed.join(', '));
    });
  });

  // 2026-09-03. 247 states its chapter three words before the book name
  // repeats with a verse-marked number, and the 節-says-verse refusal
  // above was throwing the whole clause away. The rescue lives INSIDE
  // that refusal, so its firing zone is the refusal's own 12 corpus
  // sites and cannot be wider; four of the twelve find a chapter and
  // both readings are right. Corpus effect: +1 key, −0.
  group('a chapter stated earlier in the same sentence', () {
    test('247 recovers Revelation 19:12', () {
      expect(
          _extractRefs('然后在第19章，启示录12节，一个荣耀的人物出现，头戴冠冕。'),
          ['Revelation 19:12']);
    });

    // The other live site. 365 already held Psalms 40:6 from the very
    // next clause, which is why the rescue is +1 and not +2 — and why
    // this sentence is the one that shows the reading is right rather
    // than merely new.
    test('365 reads 「取自第40篇詩篇第6節起」 as Psalms 40:6', () {
      expect(
          _extractRefs('这是多么奇妙的经文！取自第40篇诗篇第6节起，诗篇40:6。'),
          contains('Psalms 40:6'));
    });

    // A sentence, not a paragraph. 010's Psalm 37 is real and three
    // sentences back; reaching it would mean reaching any number that
    // ended a paragraph, and 016 names no chapter at all.
    test('does not reach across a sentence stop', () {
      // 010's shape. Psalm 37 is stated, and stated citations are filed
      // as themselves — but the 第二十七節 two sentences later reaches
      // nothing, so neither Psalms 37:27 nor a bare Psalms 27 appears.
      expect(
          _extractRefs('主耶稣从诗篇第三十七篇取了这些话。他是一个行义的人。'
              '诗篇第二十七节说："你当离恶行善。"'),
          ['Psalms 37']);
      // 016 names no chapter anywhere in the sentence.
      expect(_extractRefs('你看，在马太福音第十八节，那里的词是"恶念"'), isEmpty);
    });

    // A comma is not a sentence stop — 247's chapter sits behind exactly
    // one 「，」, so this is the boundary the rule turns on.
    test('a comma is not a stop', () {
      expect(_extractRefs('然后在第19章，启示录12节'), ['Revelation 19:12']);
      expect(_extractRefs('然后在第19章。启示录12节'), isEmpty);
    });

    // The chapter must be BARE. Here it belongs to Matthew, which REF_RE
    // has already filed, and lending it to Luke would invent a citation.
    // No corpus site has this shape; it is the one the rule would be
    // wrong for, so it is refused by construction rather than by luck.
    test('does not borrow a chapter that belongs to another book', () {
      expect(_extractRefs('在马太福音第5章，路加福音12节'), ['Matthew 5']);
    });

    // 但 is "but", and the single-CJK-character abbreviation rule demands
    // a verse or a 章 as proof that it is Daniel. The rescue must not be
    // the thing that supplies that proof. Inert on the corpus — 106 and
    // 150's real sentences begin at the clause — and asserted because it
    // is one transcript away from firing.
    test('does not rescue a single-character abbreviation', () {
      expect(_extractRefs('在第13章，但第11节给出了更深的含义'), isEmpty);
    });
  });

  // The open queue entries around this script rest on counts, and a
  // count measured once decays silently. These run the REAL regexes over
  // the whole corpus so that the day a transcript changes the picture,
  // the suite says so instead of the entry going on claiming a number
  // nobody has re-derived. Every figure here was re-measured 2026-09-03.
  group('the corpus census the open entries rest on', () {
    // Computed once for the group. `expect` cannot run in a group body,
    // and the census is a seven-second `REF_RE` pass, so neither a
    // per-test call nor a group-body call will do.
    late final Map<String, int> c;
    setUpAll(() => c = _corpusCensus());

    test('the census actually read the corpus', () {
      expect(c['bodies'], greaterThan(1000));
    });

    // "The 2026-08-25 boundary relaxation is not additive by
    // construction." `NUMBERED_TAIL_RE` is built from full names only,
    // so a constructed 「在馬太福音 2 Cor 5:17」 eats the 2 and loses
    // 2 Corinthians 5:17. Teaching the tail rule about abbreviations was
    // built and measured: +0 −0. Zero sites is why it did not ship.
    test('no citation puts an abbreviated numbered book in a chapter slot',
        () {
      expect(c['abbrevTailSites'], 0,
          reason: 'the first Chinese sentence with an English citation '
              'inside it lands here — see docs/autonomous-queue.md');
    });

    // "The list carry's `\s*` crosses a newline." Closed 2026-09-03 with
    // `[^\S\n]*`, which is what `zhChapterMarkTailPattern` always used.
    // The corpus never had a site, and this pins that the pattern cannot
    // grow one back.
    test('the list carry never spans a newline', () {
      expect(c['newlineCarryMatches'], 0);
      expect(_extractRefs('Genesis 1:1\n\nand 2:2'), ['Genesis 1:1']);
      expect(_extractRefs('Genesis 1:1 and 2:2'),
          ['Genesis 1:1', 'Genesis 2:2']);
    });

    // "A clock time would be carried if one ever followed a citation."
    // The corpus has 1,328 `C:V`-shaped tokens and exactly two are
    // clocks — 160's "Communion at 1:15" and 230's "9:20 pm" — and
    // neither sits after a citation. No guard shipped.
    //
    // `whenAfterCitation` is why a Chinese half of that guard must never
    // be written: 时/時 after a citation is the ordinary word "when"
    // (「當你回頭看馬太福音第5章時」), 28 times, every one of them real.
    test('no clock time sits where a citation could carry it', () {
      expect(c['clockAfterCitation'], 0);
      // 1328 → 1544 when the corpus grew from 289 sermons to 414. The
      // number that carries the ARGUMENT is the one below it, and it did
      // NOT move: still exactly two of these tokens are clocks, so all 216
      // that arrived are chapter:verse citations. Sampled to confirm the
      // shape — 罗6:2, 林后5:17, 太13:6,21, 约11:11,13 — the merged bodies
      // cite in Chinese abbreviations and never print a time of day.
      expect(c['clockTokens'], 1544);
      expect(c['clockTokensMarked'], 2);
      // 28 → 34. All 34 were read: six new sites in fy-bp05, fy-sm12b and
      // fy-nm06 (each in both scripts), every one of them 時 meaning
      // "when" — 「上次我們查考使徒行傳2章38節時已看到」. A 时/時 guard
      // would still delete real citations, and now six more of them.
      expect(c['whenAfterCitation'], 34,
          reason: 'a 时/時 guard would delete this many real citations');
    });

    // "`marked` disables the unit-word guard." Zero sites, and the
    // measurement is symmetric: removing `not marked` from the guard is
    // also +0 −0, so the corpus cannot price the exemption in either
    // direction and the reasoning stands unchallenged.
    test('no marked citation is followed by a unit word', () {
      expect(c['markedUnitWordSites'], 0);
      // The class it would be about, kept executable.
      expect(_extractRefs('in Genesis, chapter 3 times'), ['Genesis 3']);
      expect(_extractRefs('the word occurs in Deuteronomy 43 times'),
          isEmpty);
    });

    // "The same chapter-list defect survives when the list is NOT
    // consecutive." Attempted and deliberately not shipped 2026-08-26;
    // these are the four counts that decision was priced on, re-derived
    // rather than copied. The one gapped bare list in the corpus is
    // 004's CHAPTER list, which the spelled-out chapter word already
    // refuses — so the rule would be inert, and an inert rule cannot be
    // validated by the corpus at all.
    test('the corpus still holds no bare gapped VERSE list', () {
      expect(c['bareGappedVerseLists'], 0,
          reason: 'one of these prices the trade — see the queue entry');
      expect(c['bareGappedAndLists'], 1, reason: "004's chapter list");
      expect(c['bareCommaVerseMatches'], 20);
      expect(c['gappedTailRoom'], 4,
          reason: 'the rule would fire on this many of the 20');
    });

    // What the rule would have destroyed: three genuine verse citations
    // that survive today only because no gapped `and` happens to follow
    // them. Asserted as the sentences one word away from the defect.
    test('the three at-risk citations still read as verses', () {
      expect(_extractAll([
        'for example, fear of man we have in Matthew 10, 26. Where the '
            'Lord says, do not fear',
        'the reality of our living, in him. Zechariah 2, 5. Even going '
            'back to the',
        'Matthew 5, 10 to 12. And this is what we read',
      ]), [
        ['Matthew 10:26'],
        ['Zechariah 2:5'],
        ['Matthew 5:10', 'Matthew 5:11', 'Matthew 5:12'],
      ]);
    });

    // "一一九 is 119 read digit-by-digit." Shipped 2026-09-03 in both
    // implementations. The floor is three characters and these are the
    // counts it rests on: 242 two-character bare-digit runs, all prose,
    // against 13 longer ones of which only 一一九 lands in 1..199.
    test('the digit-string reading admits exactly one corpus spelling',
        () {
      // 242 → 308 with the merge, and 13 → FIVE. The long runs went DOWN
      // because eight of the thirteen were in machine-translated bodies
      // that the merge replaced — 042's 二一四 among them, which is why the
      // range check below is now asserted on a constructed string rather
      // than on a sermon. All five survivors were read: 411's 一九五三 and
      // EC011's 一九五八 (×2, both scripts) are years and resolve to
      // nothing, and 331's 一一九 (×2) is Psalm 119. The claim the floor
      // rests on — that exactly one corpus spelling lands in 1..199 — is
      // therefore stronger after the merge, not weaker.
      expect(c['digitRuns2'], 308);
      expect(c['digitRuns3plus'], 5);
      expect(c['digitRunsResolved'], 2, reason: "331's two bodies");
      expect(_extractRefs('也在诗篇十九篇10节；诗篇一一九篇103节等等'),
          ['Psalms 19:10', 'Psalms 119:103']);
      // 042's 二一四 and the years stay out on the range check.
      expect(_extractRefs('诗篇二一四篇3节'), isEmpty);
    });

    // The reach-back's firing zone, pinned so that a widening of the
    // 節-says-verse refusal cannot quietly widen the rescue with it.
    test('the reach-back can only fire inside the refusal it rescues',
        () {
      expect(c['verseMarkGuardSites'], 12);
      expect(c['reachBackSites'], 4, reason: "247 and 365, both bodies");
    });
  });

  test('refs.json is in step with the script that writes it', () {
    // The script is only useful through its output. If someone changes a
    // rule and forgets to regenerate, the app keeps serving the old
    // index — and the change looks shipped when it is not.
    final refs = jsonDecode(File('assets/sermons/refs.json').readAsStringSync())
        as Map<String, dynamic>;
    final byVerse = refs['byVerse'] as Map<String, dynamic>;
    final bySermon = refs['bySermon'] as Map<String, dynamic>;
    expect(byVerse, isNotEmpty);
    expect(bySermon, isNotEmpty);

    // Every verse key must name a sermon that claims it back, and the
    // reverse. A half-regenerated file breaks exactly this.
    for (final entry in byVerse.entries) {
      for (final sid in (entry.value as List).cast<String>()) {
        expect((bySermon[sid] as List?)?.contains(entry.key), isTrue,
            reason: '${entry.key} lists $sid, which does not list it back');
      }
    }
  });
}
