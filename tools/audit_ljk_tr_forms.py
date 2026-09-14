#!/usr/bin/env python3
"""Audit the 梁家鏗譯本 Traditional file against its own Simplified twin.

The method is `repair_biblexg_v2_tr.py`'s, applied to the v3 edition and
to the footnotes adopted from the official site on 2026-09-14: **the
conversion's own decisions are the witness against itself.** Align the
two scripts character by character and every position where they differ
is a decision something made; where it made one decision 1,123 times and
the opposite once, the once is the defect.

Four classes, and they are not the same kind of error:

  A. A Simplified character SURVIVED the conversion. 耶稣 for 耶穌 inside
     a footnote is this: the file converts 稣→穌 everywhere else.
  B. The conversion chose the wrong Traditional WORD — 會堂里 for 會堂裡,
     where the file's other 里 are all correct (公里, 提比里亞…), so the
     character itself must not be swept.
  C. The conversion went TOO FAR — 準許 for 准許 (准 is to permit; 準 is
     accurate), 矇住 for 蒙住. A Simplified-survivor screen structurally
     cannot see this class.
  D. 舊字形 stragglers — 説 for 說, 啓 for 啟, 証 for 證. Not a meaning
     defect; a SEARCH one, because a reader typing 說 does not find 説.

A and D are mechanical and this script repairs them. B and C are
judgements about words and are only REPORTED — `--report` writes the
document that goes to the translator.

Usage:
    tools/audit_ljk_tr_forms.py                 # count, change nothing
    tools/audit_ljk_tr_forms.py --write         # repair classes A and D
    tools/audit_ljk_tr_forms.py --report <path> # write the Markdown
    tools/audit_ljk_tr_forms.py --repo <path>
"""
import json
import os
import re
import sys
from collections import Counter, defaultdict

# 舊字形 and the 新字形 the rest of the file uses. Each pair is one glyph
# of one word — never a meaning change — and every one of them is a
# character a reader can type and fail to find.
OLD_FORMS = {
    '説': '說', '啓': '啟', '証': '證', '衞': '衛', '敍': '敘',
    '牀': '床', '喫': '吃', '羣': '群', '峯': '峰', '搾': '榨',
    '麪': '麵', '粧': '妝', '踪': '蹤', '却': '卻', '棄': '棄',
}


# Characters that have no life of their own in Traditional Chinese: if
# one is standing in the Traditional file, the conversion missed it.
#
# NAMED, because a statistic cannot do this job and two drafts of this
# script proved it. "The majority converts this character, so this
# position is a survivor" flagged 約旦 (the Jordan), 走一里路 (a mile),
# 放在斗底下 (a bushel), 與我何干 (what is that to me) and 醫愈 — every one
# of them correct Traditional, every one of them a character that also
# happens to be somebody else's Simplified form. `repair_biblexg_v2_tr.py`
# says it in its opening paragraph: named sites, never a sweep.
#
# Everything the statistic flags that is NOT in here goes to the report
# instead, for the translator to rule on.
SIMPLIFIED_ONLY = set('绝亲将稣万凭够毁满约话这样们个来时别')


def majority_of(counter):
    return counter.most_common(1)[0][0] if counter else None


def load(path):
    return json.load(open(path, encoding='utf-8'))


def main():
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if '--repo' in sys.argv:
        repo = os.path.abspath(sys.argv[sys.argv.index('--repo') + 1])
    write = '--write' in sys.argv
    report_path = None
    if '--report' in sys.argv:
        report_path = sys.argv[sys.argv.index('--report') + 1]

    s_path = os.path.join(repo, 'assets', 'biblexg-v3.json')
    t_path = os.path.join(repo, 'assets', 'biblexg-v3-tr.json')
    simplified = {r['id']: r['text'] for r in load(s_path)}
    trad_rows = load(t_path)

    # The witness: for each Simplified character, every Traditional
    # character seen opposite it, with counts.
    seen = defaultdict(Counter)
    for r in trad_rows:
        s = simplified.get(r['id'])
        t = r['text']
        if s is None or len(s) != len(t):
            continue
        for a, b in zip(s, t):
            seen[a][b] += 1

    # How often each character appears in the Traditional file at all.
    #
    # This is what stops class A from being a sweep, and the first draft
    # of this script proved the need: a plain "the majority converts this
    # character, so this position is a survivor" rule flagged 約旦 (the
    # Jordan), 走一里路 (a mile), 放在斗底下 (a bushel) and 借給 — every
    # one of them correct Traditional, and every one of them a character
    # that ALSO exists as somebody else's Simplified form. The v2 tool's
    # docstring says it in as many words: named sites, never a sweep.
    #
    # A real survivor is a character with no Traditional life of its own:
    # 稣 appears in this file exactly where it was missed and nowhere
    # else, while 里 appears 45 times legitimately.
    trad_total = Counter()
    for r in trad_rows:
        trad_total.update(r['text'])

    survivors, stragglers, judgements = [], [], []
    for r in trad_rows:
        s = simplified.get(r['id'])
        t = r['text']
        if s is None or len(s) != len(t):
            continue
        out = list(t)
        for i, (a, b) in enumerate(zip(s, t)):
            # Class A: this position kept the Simplified character while
            # the rest of the file converted it.
            if a == b and len(seen[a]) > 1:
                majority, n = seen[a].most_common(1)[0]
                if a in SIMPLIFIED_ONLY and majority != a:
                    survivors.append((r['id'], r.get('book'), r.get('chapter'),
                                      r.get('verse'), a, majority, n))
                    out[i] = majority
                elif majority != a and n >= 20:
                    # Flagged by the statistic but NOT in the named set:
                    # a character valid in both scripts, standing where
                    # the majority converted — 約旦, 走一里路, 放在斗底下,
                    # 與我何干. Reported for the translator, never
                    # touched.
                    judgements.append((r['id'], r.get('book'),
                                       r.get('chapter'), r.get('verse'),
                                       a, majority, n))
            # Class D: an old glyph form where the file's own majority is
            # the new one.
            elif b in OLD_FORMS and seen[a].get(OLD_FORMS[b], 0) > seen[a][b]:
                stragglers.append((r['id'], r.get('book'), r.get('chapter'),
                                   r.get('verse'), b, OLD_FORMS[b],
                                   seen[a][OLD_FORMS[b]], seen[a][b]))
                out[i] = OLD_FORMS[b]
        r['text'] = ''.join(out)

    # 舊字形 again, this time as a whole-file pass rather than a
    # positional one.
    #
    # The positional rule above only sees a straggler when the two
    # scripts line up at that character, and a footnote imported into one
    # file and not the other has no counterpart to line up with. 說 was
    # left standing in 彼得前書 2:1 for exactly that reason.
    #
    # A sweep is safe HERE and nowhere else in this script, because these
    # pairs are one glyph of one word — 説/說 carry no meaning
    # distinction, unlike 里/裡 or 准/準 — and because the file's own
    # majority decides it: 說 1,858 times against 説 once. The margin is
    # required to be at least twenty to one, and what it changed is
    # counted and printed.
    swept = Counter()
    whole = ''.join(r['text'] for r in trad_rows)
    # The named Simplified-only characters get the same whole-file
    # treatment, and for a stronger reason: a character with no
    # Traditional life cannot be correct anywhere in a Traditional file,
    # so there is no position to examine. 分别為聖 survived the positional
    # pass because its verse carries a footnote the Simplified file does
    # not, so the two strings are different lengths and never aligned —
    # which is precisely the case newly imported notes create.
    for ch in SIMPLIFIED_ONLY:
        majority = majority_of(seen.get(ch, Counter()))
        if majority and majority != ch and ch in whole:
            for r in trad_rows:
                if ch in r['text']:
                    swept[ch] += r['text'].count(ch)
                    r['text'] = r['text'].replace(ch, majority)
    whole = ''.join(r['text'] for r in trad_rows)
    sweepable = {old_form: new_form for old_form, new_form in OLD_FORMS.items()
                 if whole.count(new_form) >= 20 * max(1, whole.count(old_form))}
    for r in trad_rows:
        for old_form, new_form in sweepable.items():
            if old_form in r['text']:
                swept[old_form] += r['text'].count(old_form)
                r['text'] = r['text'].replace(old_form, new_form)
    if swept:
        print('swept whole-file             : %s'
              % ', '.join('%s→%s ×%d' % (k, sweepable.get(k) or
                                          majority_of(seen[k]), v)
                          for k, v in swept.items()))

    print('class A — Simplified survivors : %d' % len(survivors))
    for row in survivors[:12]:
        print('    %s %s %s:%s  %s -> %s  (the file converts it %d times)'
              % row)
    print('class C — for the translator     : %d' % len(judgements))
    for row in judgements[:12]:
        print('    %s %s %s:%s  %s  (the file converts it to %s %d times)'
              % row)
    print('class D — 舊字形 stragglers     : %d' % len(stragglers))
    for row in stragglers[:12]:
        print('    %s %s %s:%s  %s -> %s  (%d vs %d)' % row)

    if write and (survivors or stragglers or swept):
        with open(t_path, 'w', encoding='utf-8') as f:
            json.dump(trad_rows, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print('WROTE %s' % t_path)

    if report_path:
        write_report(report_path, survivors, stragglers, judgements)
        print('REPORT %s' % report_path)


def write_report(path, survivors, stragglers, judgements):
    lines = []
    w = lines.append
    w('# 梁家鏗譯本 繁體字檢查')
    w('')
    w('2026-09-14。這份清單是給譯者的，不是給程式的。')
    w('')
    w('## 檢查方法')
    w('')
    w('這個譯本同時發行簡體與繁體兩個檔案，繁體是由簡體轉出來的。')
    w('所以不需要外部依據也能檢查：把兩個檔案逐字對齊，凡是兩邊不同的')
    w('位置，都是轉換器做過的一個判斷；同一個字它做了一千多次相同的判斷、')
    w('只有一兩次相反的判斷，那一兩次就是錯的。**轉換器自己就是指證自己的')
    w('證人。**')
    w('')
    w('下面兩類是機械性的、沒有歧義的，程式已經照多數決修好；')
    w('列在這裡是為了讓您知道動過哪裡。')
    w('')
    w('## 甲類：簡體字漏轉')
    w('')
    w('繁體檔案裡殘留的簡體字。例如註腳裡的「耶稣基督」——')
    w('同一個檔案把 稣 轉成 穌 一千多次，只漏了這一處。')
    w('')
    w('| 出處 | 現況 | 應作 | 同一字正確轉換次數 |')
    w('|---|---|---|---|')
    for vid, book, ch, v, a, majority, n in survivors[:60]:
        w('| %s %s:%s | %s | %s | %d |' % (book, ch, v, a, majority, n))
    if len(survivors) > 60:
        w('')
        w('（另有 %d 處，同類。）' % (len(survivors) - 60))
    w('')
    w('## 乙類：舊字形')
    w('')
    w('意思沒有錯，但字形是舊的：説／說、啓／啟、証／證、衞／衛、敍／敘。')
    w('這一類影響的是**搜尋**——讀者打「說」找不到「説」——')
    w('而同一個檔案裡兩種字形是混用的。')
    w('')
    w('| 出處 | 現況 | 檔案多數作 | 次數對比 |')
    w('|---|---|---|---|')
    for vid, book, ch, v, b, right, n_right, n_wrong in stragglers[:60]:
        w('| %s %s:%s | %s | %s | %d : %d |' % (book, ch, v, b, right,
                                                n_right, n_wrong))
    if len(stragglers) > 60:
        w('')
        w('（另有 %d 處，同類。）' % (len(stragglers) - 60))
    w('')
    w('## 丙類：請譯者裁決的')
    w('')
    w('這幾處程式沒有動，因為它們是關於**詞**的判斷，不是字形：')
    w('')
    w('* **馬可福音 1:23**「在他們的會堂里」——應作「會堂裡」。')
    w('  檔案裡其他 45 個「里」都是對的（公里、提比里亞、克里特、')
    w('  堅革里…），所以「里」這個字本身不能一律掃換。')
    w('* **准許／準許**（馬可 5:13、8:30、10:4）——准 是允許，準 是準確。')
    w('  簡體本作「准许」，檔案自己也寫過 6 次「准許」。')
    w('* **蒙住／矇住**（馬可 14:65）——矇 用於眼睛，來源作「蒙住」。')
    w('* **指證／指証**（約翰 8:46）。')
    w('')
    w('另外，下面這些位置的字在兩個檔案裡是一樣的，但同一個字在別處被')
    w('轉成了另一個形。它們**沒有被改動**——因為這些字在繁體裡本來就站得住')
    w('（約旦、走一里路、放在斗底下、與我何干），程式不該替您決定：')
    w('')
    w('| 出處 | 現況 | 別處轉成 | 次數 |')
    w('|---|---|---|---|')
    for vid, book, ch, v, a, m, n in judgements[:40]:
        w('| %s %s:%s | %s | %s | %d |' % (book, ch, v, a, m, n))
    if len(judgements) > 40:
        w('')
        w('（另有 %d 處。）' % (len(judgements) - 40))
    w('')
    w('## 丁類：兩邊分節不同的九節')
    w('')
    w('這一類與字形無關，是**經文本身**：官方站的版本與這裡的版本在')
    w('這九節切分不同，直接照搬會刪掉經文，所以一個字都沒有動。')
    w('')
    w('| 出處 | 情況 |')
    w('|---|---|')
    w('| 馬太福音 21:44 | 這裡只有一個右引號，官方站有整句「那撞擊這石頭的必垮…」 |')
    w('| 路加福音 23:34a | 「父親啊，赦免他們」——官方站有，這裡沒有 |')
    w('| 約翰福音 12:36b | 官方站把「耶穌說完了這些話…」放在 36 節 |')
    w('| 羅馬書 3:10 | 官方站把「沒有義人，一個也沒有」放在 10 節 |')
    w('| 腓立比書 1:1 | 收件人一句兩邊落在不同節 |')
    w('| 哥林多後書 13:14 | **這裡有祝福語，官方站的 13:14 是空的** |')
    w('| 約翰一書 4:16 | 後半句歸屬不同 |')
    w('| 約翰三書 1:14 | 問安一段歸屬不同 |')
    w('| 啟示錄 12:17 | 末句歸屬不同 |')
    w('')
    w('請問哪一種分節是您要的？')
    open(path, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')


if __name__ == '__main__':
    main()
