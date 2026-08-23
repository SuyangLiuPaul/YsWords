#!/usr/bin/env python3
"""Find narrative speech-attribution clauses trapped INSIDE a quotation.

馬太福音 15:34 reads 耶穌說：「你們有多少餅？他們說：有七個…」 — the
disciples' answer sits inside Jesus's quotation marks, so the app attributes
one speaker's words to another. That is the one class of defect the standing
rule puts first: it reads plausibly and it is false.

**Quote depth is NOT tracked across verses**, deliberately. This edition's
quotation marks are not globally balanced (102 chapters end mid-quote), so a
running depth counter drifts and reports hundreds of false positives. The
signature used instead is local to one verse and needs no balance:

    an opening 「 … then a speech attribution 「X說：」 with NO closing 」
    between them and NO quote mark opening the reported speech.

That is exactly the defect shape, and it survives 馬太福音 17:26, where the
quotation opens in v.26 and does not close until v.27 — the opening mark and
the trapped attribution are both in v.26, so no cross-verse state is needed.

An attribution BEFORE any 「 in the verse is a different, non-false class
(the first reply is simply unquoted) and is reported separately.
"""
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

NOTE = re.compile(r'<note:[^>]*>')
# Speech verbs this edition introduces direct speech with.
SAY = re.compile(r'(說|説|说|問|问|回答|吩咐|告訴|告诉|答)：')

EDITIONS = (
    ('assets/cuvs-yhwh-tr.json', '「', '」', '『', '』'),
    ('assets/cuvs-yhwh.json', '“', '”', '‘', '’'),
)

# Verse ids where an attribution sits inside a quotation and is CORRECT: the
# trapped 說： is spoken BY the current speaker — reporting what someone else
# said, quoting scripture, or issuing an instruction — rather than being the
# narrator attributing a reply. All 39 were read individually on 2026-08-24.
EXPLAINED = {
    # The speaker relays what a third party said (「我聽見你父親…說：」).
    '001027006', '001050004', '001050016', '002019003', '005001006',
    '005001034', '005002026', '005003023', '029002017', '042024044',
    '044002029', '044009013', '044025024', '045010006',
    # A prophet relays the divine-speech formula inside his own quotation.
    '002008020', '037001013', '037002002', '037002014', '037002021',
    '038004006', '044021011', '045014011',
    # A citation formula (經上記著說 / 摩西寫著說) inside a quotation.
    '040002005', '040022043', '040023029', '042020028', '044023005',
    # An instruction to speak, inside the speaker's own words.
    '042011002', '042013032',
    # Revelation's letter formula, 「你要寫信給…的使者，說：「那…的，說：」.
    # The nested 「-inside-「 there is a separate, already-filed level-marking
    # item; it is not a misattribution.
    '066002001', '066002008', '066002012', '066002018', '066003001',
    '066003007', '066003014',
}

# Verses where the witness 7a2dc43 closes a quotation mid-verse and we do not,
# and OURS is defensible. Left deliberately; each has independent support.
WITNESS_DIFF_EXPLAINED = {
    # The witness has no speech quotation here at all — its 「」 mark the words
    # 「女人」/「男人」 themselves. Different convention, not a missing mark.
    '001002023',
    # 因為她容貌俊美 — narrator or Isaac's own thought. LEB puts it inside the
    # thought, as we do; the witness puts it outside. Disputed, not a defect.
    '001026007',
    # 因為預言中的靈意乃是為耶穌作見證 — inside the angel's speech for us, LEB
    # and 梁家鏗's independent NT; outside for the witness. Two independent
    # lines side with us, so this is an editorial split, not a defect.
    '066019010',
}


# The word-tap corpus, in canonical order — its files are named, not numbered.
TAGGED_BOOKS = (
    'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy', 'joshua',
    'judges', 'ruth', '1_samuel', '2_samuel', '1_kings', '2_kings',
    '1_chronicles', '2_chronicles', 'ezra', 'nehemiah', 'esther', 'job',
    'psalms', 'proverbs', 'ecclesiastes', 'song_of_solomon', 'isaiah',
    'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea', 'joel', 'amos',
    'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah', 'haggai',
    'zechariah', 'malachi', 'matthew', 'mark', 'luke', 'john', 'acts',
    'romans', '1_corinthians', '2_corinthians', 'galatians', 'ephesians',
    'philippians', 'colossians', '1_thessalonians', '2_thessalonians',
    '1_timothy', '2_timothy', 'titus', 'philemon', 'hebrews', 'james',
    '1_peter', '2_peter', '1_john', '2_john', '3_john', 'jude', 'revelation',
)

# Same-level nesting in the tagged corpus that is NOT a misattribution:
# Revelation's seven-letter formula, filed separately as a level-marking item
# (the witness sets the inner quotation with 『, we repeat 「).
TAGGED_EXPLAINED = {
    '066002001', '066002008', '066002012', '066002018', '066003001',
}


def strip_notes(t):
    return NOTE.sub('', t)


def find(text, o, c, oi, ci):
    """Return (inside, before) lists of (pos, context) for bare attributions."""
    inside, before = [], []
    open_seen = False
    depth = 0
    inner = 0
    for m in SAY.finditer(text):
        end = m.end()
        head = text[:m.start()]
        depth = head.count(o) - head.count(c)
        inner = head.count(oi) - head.count(ci)
        open_seen = o in head
        nxt = text[end:end + 1]
        if nxt in (o, oi):
            continue          # the reported speech is properly quoted
        if inner > 0:
            continue          # third-level speech this edition stops marking
        ctx = text[max(0, m.start() - 10):end + 12]
        if depth > 0:
            inside.append((m.start(), ctx))
        elif open_seen:
            before.append((m.start(), ctx))
    return inside, before


def audit(path, o, c, oi, ci):
    data = json.load(open(os.path.join(REPO, path)))
    hits, softs = [], []
    for v in data:
        text = strip_notes(v['text'])
        if o not in text:
            continue
        inside, before = find(text, o, c, oi, ci)
        for pos, ctx in inside:
            hits.append((v['id'], pos, ctx))
        for pos, ctx in before:
            softs.append((v['id'], pos, ctx))
    return hits, softs


def witness_diff():
    """Second, verb-agnostic detector: where does the witness close a
    quotation mid-verse that we leave open?

    The attribution detector above only sees a trapped voice that announces
    itself with 說：. It missed 約翰福音 2:7 (`…把缸倒滿了水。他們就倒滿了…」`),
    where the trapped voice is the NARRATOR with no speech verb at all. This
    one makes no assumption about the trapped text.
    """
    import difflib
    import subprocess
    paren = re.compile(r'（[^）]*）')
    marks = '「」『』'
    cur = {v['id']: v['text']
           for v in json.load(open(os.path.join(REPO, EDITIONS[0][0])))}
    blob = subprocess.run(['git', '-C', REPO, 'cat-file', '-p', '7a2dc43'],
                          capture_output=True, text=True).stdout
    if not blob.strip():
        print('  (witness blob 7a2dc43 unavailable — skipped)')
        return []
    wit = {v['id']: v['text'] for v in json.loads(blob)}

    def split(t):
        base, ms = [], []
        for ch in t:
            if ch in marks:
                ms.append((len(base), ch))
            else:
                base.append(ch)
        return ''.join(base), ms

    hits = []
    for vid, ours in cur.items():
        other = wit.get(vid)
        if not other or '「' not in ours:
            continue
        stripped = strip_notes(ours)
        ob, om = split(stripped)
        wb, wm = split(paren.sub('', other))
        mapping = {}
        for a, b, n in difflib.SequenceMatcher(
                None, ob, wb, autojunk=False).get_matching_blocks():
            for k in range(n):
                mapping[b + k] = a + k
        ourmarks = {i for i, _ in om}
        depth, plain, depth_at = 0, 0, {}
        for ch in stripped:
            if ch == '「':
                depth += 1
            elif ch == '」':
                depth -= 1
            elif ch not in marks:
                depth_at[plain] = depth
                plain += 1
        for wi, wch in wm:
            if wch != '」' or wi == 0 or wi >= len(wb):
                continue
            oi = mapping.get(wi)
            if oi is None or any(abs(oi - x) <= 2 for x in ourmarks):
                continue
            if depth_at.get(oi, 0) > 0:
                hits.append((vid, ob[max(0, oi - 12):oi] + '▮' + ob[oi:oi + 12]))
    return sorted(hits)


def tagged_nesting():
    """Third detector, over the corpus the other two never read.

    Both detectors above take the READING text as their subject. The word-tap
    sheet renders `assets/tagged/cuvs-yhwh/` instead, which is a separate
    transcription line: it carries quotation marks in 4,043 verses where the
    reading text carries none, so a defect can live there and be invisible to
    anything that diffs the reading text — however the diff is done.

    The signature here assumes nothing about the trapped text and needs no
    speech verb and no witness: an opening mark appearing while another is
    still open. This edition sets inner speech with ‘, never by repeating “,
    so “…“ is always either a lost closing mark or a stray opening one.
    """
    hits = []
    for num, book in enumerate(TAGGED_BOOKS, start=1):
        path = os.path.join(REPO, 'assets', 'tagged', 'cuvs-yhwh',
                            book + '.json')
        with open(path, encoding='utf-8') as fh:
            data = json.load(fh)
        for key, runs in data.items():
            text = ''.join(r.get('w', '') for r in runs)
            # Notes are 〔…〕 here, not <note:…> — their quotes are not speech.
            text = re.sub(r'〔.*?〕', '', text)
            m = re.search(r'“[^“”]*“', text)
            if not m:
                continue
            chap, verse = key.split(':')
            vid = '%03d%03d%03d' % (num, int(chap), int(verse))
            hits.append((vid, f'{book} {key}', m.group(0)[:40]))
    return sorted(hits)


def main():
    unexplained = 0
    for path, o, c, oi, ci in EDITIONS:
        hits, softs = audit(path, o, c, oi, ci)
        print(f'=== {path}')
        print(f'  {len(hits)} attribution(s) INSIDE a quotation '
              f'(wrong speaker on screen):')
        for vid, pos, ctx in hits:
            flag = '' if vid in EXPLAINED else '   <-- UNEXPLAINED'
            print(f'    {vid} @{pos}  …{ctx}…{flag}')
            if vid not in EXPLAINED:
                unexplained += 1
        print(f'  {len(softs)} unquoted reply BEFORE the verse\'s first '
              f'quotation (not false, filed separately):')
        for vid, pos, ctx in softs:
            print(f'    {vid} @{pos}  …{ctx}…')

    print('=== witness 7a2dc43 closes a quotation mid-verse and we do not')
    for vid, ctx in witness_diff():
        flag = '' if vid in WITNESS_DIFF_EXPLAINED else '   <-- UNEXPLAINED'
        print(f'    {vid}  …{ctx}…{flag}')
        if vid not in WITNESS_DIFF_EXPLAINED:
            unexplained += 1

    print('=== word-tap corpus opens “ while another “ is still open')
    for vid, where, ctx in tagged_nesting():
        flag = '' if vid in TAGGED_EXPLAINED else '   <-- UNEXPLAINED'
        print(f'    {vid}  {where}  …{ctx}…{flag}')
        if vid not in TAGGED_EXPLAINED:
            unexplained += 1
    return 1 if unexplained else 0


if __name__ == '__main__':
    sys.exit(main())
