#!/usr/bin/env python3
r"""Enumerate every compiled `num.clamp()` call site in a web bundle.

    curl -o md.js https://<deploy>--yswords-dev.netlify.app/main.dart.js
    python3 tools/scan_clamp_sites.py md.js

For BUGS #1 (`Invalid argument: 0`). dart2js compiles ONE `num.clamp()`
for the whole program, so the throw site names nothing; the question is
always which CALLER passed an inverted range. `ArgumentError.value` is
handed `lowerLimit`, so "Invalid argument: 0" means lower==0 and
upper<0 — hence the literal-0 report below.

WHY A PARSER AND NOT A GREP
---------------------------
The 2026-09-01 pass swept with `\.P\([^,()]{0,40},0,` and found 43
sites. That regex cannot match a call whose first argument contains a
paren or a comma, or runs past 40 characters, which is most of them.
Balanced-paren parsing of the same byte-identical bundle finds 66. The
22 in the difference had never been examined; all 22 turned out to be
non-invertible, but that was luck, not coverage.

Don't re-derive the bundle by guessing dart-defines — it will not
byte-match a real deploy (`APP_RELEASE_TIME` is baked in). Pull the
specific historical Netlify deploy instead.
"""
import re, sys, json, bisect

path = sys.argv[1] if len(sys.argv) > 1 else 'main.dart.js'
src = open(path, encoding='utf-8', errors='replace').read()

OPEN, CLOSE = '([{', ')]}'

def split_args(s, i):
    """s[i] == '(' . Return (args, index_after_close) with balanced nesting,
    string- and regex-literal aware. None if unbalanced."""
    assert s[i] == '('
    depth = 0; args = []; cur = []; j = i
    while j < len(s):
        c = s[j]
        if c in '"\'':
            q = c; k = j + 1
            while k < len(s):
                if s[k] == '\\': k += 2; continue
                if s[k] == q: break
                k += 1
            cur.append(s[j:k+1]); j = k + 1; continue
        if c in OPEN:
            depth += 1
            if depth == 1: j += 1; continue
            cur.append(c); j += 1; continue
        if c in CLOSE:
            depth -= 1
            if depth == 0:
                args.append(''.join(cur)); return args, j + 1
            cur.append(c); j += 1; continue
        if c == ',' and depth == 1:
            args.append(''.join(cur)); cur = []; j += 1; continue
        cur.append(c); j += 1
    return None, None

# line index for reporting
starts = [0]
for m in re.finditer('\n', src): starts.append(m.end())
def lineof(pos): return bisect.bisect_right(starts, pos)

sites = []
for m in re.finditer(r'\.P\(', src):
    i = m.end() - 1
    args, end = split_args(src, i)
    if args is None or len(args) != 3: continue
    # receiver: walk back over the identifier/property chain
    b = m.start(); k = b
    while k > 0 and (src[k-1].isalnum() or src[k-1] in '_$.'): k -= 1
    recv = src[k:b]
    sites.append({'pos': m.start(), 'line': lineof(m.start()),
                  'recv': recv, 'args': args})

print(f'total 3-arg .P( call sites: {len(sites)}')
from collections import Counter
print('receivers:', Counter(s['recv'] for s in sites).most_common(12))

# What the previous pass's regex could see.
old = set()
for m in re.finditer(r'\.P\([^,()]{0,40},0,', src):
    old.add(lineof(m.start()))
print(f'\nlines matched by the OLD regex: {len(old)}')

lit0 = [s for s in sites if s['args'][1].strip() == '0']
print(f'sites with a literal 0 LOWER bound (balanced parse): {len(lit0)}')
newly = [s for s in lit0 if s['line'] not in old]
print(f'  of those, INVISIBLE to the old regex: {len(newly)}')
for s_ in newly:
    v,l,u = [a.strip() for a in s_['args']]
    print(f"  line {s_['line']:>7}  upper= {u[:80]}")
