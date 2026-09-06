#!/usr/bin/env python3
"""Write the 2026-09-06 adjudication of `duplicates.crossCorpus` into
`assets/sermon_library/refs.json`.

Rewrites ONLY the `tier` of rows this pass adjudicated, and adds three
fields to those rows: `completeness`, `verdict` and `evidence`. Every
existing field is preserved, key order is preserved, and rows in the
`possible` and `weak` tiers are not touched at all.

`completeness` settles the vocabulary that `LibraryDuplicatePair`
parses and deliberately does not yet render:

  "complete"        the library body covers the app text's whole scope
  "library-partial" the library covers only PART of what the app text
                    carries -- NOT safe as a replacement source
  "library-fuller"  the library body is the fuller text; the app body
                    is a condensed summary or a fragment
  "unknown"         too few shared anchors to establish either way

Run from the repo root. Idempotent.
"""
import json, collections, sys, pathlib

REPO = pathlib.Path(__file__).resolve().parent.parent
REFS = REPO / 'assets/sermon_library/refs.json'

# libId|appId -> (tier, completeness, verdict, evidence)
A = {}


def same(k, comp, ev):
    A[k] = ('confirmed', comp, 'SAME', ev)


# ---- probable tier: 36 pairs, adjudicated one at a time -------------
same('3897|065', 'library-fuller', "both open at Mt 12:22-29 and both frame Satan with the Chinese art-of-war maxim 知己知彼")
same('3934|071', 'library-fuller', "same parallel chain Mt 12:46-50 -> Lk 8:19-21 -> Lk 11:27-28, and both carry the head-covering (蒙头) excursus")
same('3947|073', 'complete', "both pose the same two framing questions (does the parable hide or reveal? is salvation for everyone?) and both answer Calvinism")
same('3958|079', 'library-partial', "both give the Pharisees'/Sadducees'/Herod's leaven triad; but app 079 also carries a mustard-seed recap the library body lacks")
same('3959|080', 'complete', "same detail chain: sealed earthenware jar, waterproof, no banks, inflation; both note commentators assume the man worked the field though the text does not say so")
same('3960|082', 'library-partial', "both discuss plastic and Japanese cultured pearls and a wholesale merchant; but app 082 opens with a recap section the library places at the end of 3959 instead")
same('3973|084', 'complete', "both restore the dropped 因此/therefore in v52 and both take μαθητεύω straight to Mt 28:19, then reject making converts to swell numbers")
same('3980|101', 'library-fuller', "both count the compassion word as used five times of Jesus and both use the closed-tap image with Jn 7:37-38")
same('3981|102', 'library-fuller', "both build to five marks of faith from Peter on the water, and both use Mark's detail that Jesus meant to pass by")
same('3988|008', 'complete', "same chain Mt 5:3 -> Lk 4:16-21 -> Isa 61 -> Jubilee, debts cancelled and slaves freed")
same('4082|029', 'unknown', "both cite 王云五 and both open on rote recitation of the Lord's Prayer; app 029 is itself a fragment (app 028 is absent and the file starts mid-sentence)")
same('4083|030', 'complete', "both quote the hymn phrase 'beyond the blue' and both reach for a telescope and astronomy")
same('4142|042', 'complete', "both illustrate vague false teaching with the fortune-telling lots at the Shanghai City God Temple (城隍庙)")
same('4248|063', 'library-fuller', "both run Mt 11:30 into Mt 12:1-8 and both develop yoke -> marriage via 2 Cor 6:14, the yoke made easy by love of the one yoked with")
same('4249|062', 'library-fuller', "both go Mt 11:28 -> Jn 8:12 -> Mt 5:14, both use the collapsed-star/black-hole image for the church, and both enumerate seven things Jesus gave; the title similarity of 0.062 is misleading")
same('6004|407', 'library-fuller', "both open on John 10:10b and both grade abundance with the same transport illustration (motorcycle, then an old car, then a better one)")
same('6027|394', 'complete', "both open with the same personal anecdote: a childless wealthy couple and their unused Persian and Chinese carpets stacked to the ceiling in one room")
same('16726|105', 'library-fuller', "both invoke the physicist Oppenheimer and both close on Ps 51's clean heart")
same('20967|106', 'library-fuller', "both open by noting this woman is one of only two people Jesus commended for great faith and that both were Gentiles, then dwell on his silence")
same('22133|108', 'library-fuller', "both open with the Beatitudes as a portrait of Christ and a goal, quoting Phil 3:14's 标竿, before turning to Mt 16")
same('24578|112', 'library-fuller', "both are the SECOND message on Mt 17:14-21, both correct the 'epilepsy' rendering and both turn on the father's 我信！但我信不足")
same('24740|114', 'library-fuller', "both frame becoming a child as a revolution and both contrast it with worldly revolution as one dictator replacing another")
same('36498|325', 'complete', "28 shared non-scriptural blocks against app 325 versus 0-2 for every other candidate including app 109/110, the Matthew-series weeks the Mt83 refcode would imply; see caveat in _meta")
same('36673|118', 'library-fuller', "both note the preacher already treated marriage and divorce at Mt 5:31-32 and both then ask what the prohibition means for the church")
same('36733|120', 'library-fuller', "both switch to Mk 10:13-16 as the fuller account, both note this repeats Mt 18:1-5, and both argue from 婴孩 helplessness against original sin")
same('36787|122', 'library-fuller', "both read Mk 10:21-31 as fuller than Matthew and Luke, and both enumerate the eight dangers of wealth")
same('45684|123', 'library-fuller', "both open by recapping the same eight points about money in the same order, ending on money as transient")
same('45753|124', 'library-fuller', "both recap three weeks on Mk 10:21-31 and both read first/last through competition and class")
same('45833|125', 'library-fuller', "both survey the same named commentators in the same order -- Jeremias, Schweizer, Manson, 宋尚节, 倪柝声 -- then call it a diagnostic parable")
same('68096|126', 'library-fuller', "both treat it as the diagnostic parable's sequel and both pivot on Rom 12:1-2's renewed mind")
same('75090|127', 'library-fuller', "both cite Dale Carnegie's How to Win Friends and Influence People and a professor of experimental medicine at the University of Montreal")
same('81180|129', 'library-fuller', "both recap Lk 18:34, then Bartimaeus; the library body carries the Guy Bevington broken-ribs account and the nine days of prayer that app 129's own headings name")
same('90197|131', 'library-fuller', "both contrast institutional and inner authority at Mk 11:27-33; the library body carries the Liverpool hospital collar and the Kennedy airport stop that app 131 recounts")
same('150680|135', 'library-fuller', "both put the same two questions in the same order -- what is the wedding garment, and what does 'many called, few chosen' mean")
same('157288|763', 'complete', "both open by answering 'why does a pastor need the church?' from 2 Cor 2:12-13, Paul leaving an open door at Troas because Titus was not there")
same('163773|136', 'library-fuller', "both describe the Sadducees as an aristocratic political party, unlike the Pharisees, who accepted only the Pentateuch and so denied the resurrection")

# ---- confirmed tier: completeness recorded for the 21 rows that have
# ---- a library body; one row refuted as a replacement source.
CONF = {
    '3942|074': 'complete', '3972|083': 'unknown', '3989|009': 'complete',
    '3990|010': 'complete', '4003|011': 'complete', '4004|012': 'complete',
    '4015|014': 'complete', '4023|015': 'complete', '4024|016': 'complete',
    '4032|017': 'complete', '4033|018': 'complete', '4058|023': 'complete',
    '4072|027': 'complete', '4103|034': 'unknown', '4127|039': 'complete',
    '4128|040': 'complete', '4163|047': 'complete', '6014|396': 'unknown',
    '6023|221': 'complete', '36442|013': 'complete', '36585|092': 'complete',
}
for k, c in CONF.items():
    A[k] = ('confirmed', c, 'SAME', 'pre-existing confirmed row; completeness assessed by this pass')

# The one row that must not drive a text replacement: library 6012 has
# no body at all (hasBody false, bodyFile null, bodyChars 0), so there
# is nothing to promote and nothing to check the identity against. It
# was tiered `confirmed` on `basis: exactTitle` alone.
A['6012|CP37'] = (
    'refuted', 'no-library-body', 'UNUSABLE',
    "library 6012 has no body (hasBody false, bodyFile null); tiered confirmed on exact title alone with fingerprintAvailable false. "
    "Refuted AS A PAIR OF TEXTS, not as an identity claim -- the sermons may well be the same, but nothing can verify it and there is "
    "nothing to link or substitute. Must not be treated as DIFFERENT.")


def main():
    doc = json.load(open(REFS), object_pairs_hook=collections.OrderedDict)
    rows = doc['duplicates']['crossCorpus']
    before = collections.Counter(r['tier'] for r in rows)
    touched = 0
    for r in rows:
        k = f"{r['libId']}|{r['appId']}"
        if k not in A:
            continue
        tier, comp, verdict, ev = A[k]
        r['tier'] = tier
        r['completeness'] = comp
        r['verdict'] = verdict
        r['evidence'] = ev
        r['adjudicatedOn'] = '2026-09-06'
        touched += 1
    doc['_meta']['adjudication'] = collections.OrderedDict([
        ('date', '2026-09-06'),
        ('scope', 'all 36 probable pairs, plus completeness for the 22 confirmed pairs'),
        ('method',
         'read both bodies pair by pair -- opening scripture, order of passages visited, distinctive '
         'illustrations and anecdotes, argument shape, series position -- corroborated by two measured '
         'signals: an exact preaching-date line present in 9 library bodies, and shared non-scriptural '
         'substrings (>=9 chars, verbatim CUV quotation filtered out).'),
        ('completenessVocabulary', collections.OrderedDict([
            ('complete', "the library body covers the app text's whole scope"),
            ('library-partial', 'the library covers only PART of what the app text carries; NOT safe as a replacement source'),
            ('library-fuller', 'the library body is the fuller text; the app body is a condensed summary or a fragment'),
            ('unknown', 'too few shared anchors to establish either way'),
            ('no-library-body', 'there is no library text at all'),
        ])),
        ('caveats', [
            'library 6012 / app CP37 was moved OUT of confirmed to refuted: the library record has no body, '
            'so it can neither be verified nor used. This is a statement about the texts, not a finding that '
            'the two sermons differ.',
            'library 36498 / app 325 is the one pair carrying a structural counter-indication: its Mt83 refcode '
            'sits between Mt82 and Mt84, which map to consecutive weeks (app 109, 1980-07-06 and app 110, '
            '1980-07-13), leaving no slot for it, while app 325 was preached 1982-06-06 in a camp series. '
            'Ruled SAME on the content match being unique and concentrated; a human should confirm.',
            'Not adjudicated by this pass: the 4 possible and 43 weak rows are untouched. Several weak rows '
            'score higher on shared non-scriptural prose than several confirmed rows do, so that tier is '
            'not safely assumed to be all negatives.',
        ]),
    ])
    with open(REFS, 'w', encoding='utf-8') as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
        f.write('\n')
    after = collections.Counter(r['tier'] for r in rows)
    print('rows touched:', touched)
    print('tiers before:', dict(before))
    print('tiers after :', dict(after))


if __name__ == '__main__':
    main()
