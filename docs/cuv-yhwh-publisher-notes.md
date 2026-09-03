# 和合本雅偉版 — what the publisher has told us about their own text

**Read this before repairing anything in `assets/cuvs-yhwh*.json` or
`assets/tagged/cuvs-yhwh/`.**

This file exists because its absence cost us three deletions of the same
correct data. The publisher had already explained their notation; the
explanation was in the user's inbox and nowhere in this repository, so
every audit that reasoned from the assets alone reached the wrong answer
— confidently, with measurements, twice over. A repair pass cannot
consult evidence that was never written down.

---

## The three markers on 主

Verbatim, from the publisher, relayed by the user on 2026-09-02 and
predating the deletions below:

> on the cuv-YHWH, we used 3 markup for the word 主, one for
> 主[雅偉]　主#  => 基督　　主*   =>   耶穌
>
> in your Yahweh's Word, 主* is not yet covered. eg
> https://yahwehword.com/#/john/4:4?v=cuvs-yhwh-tr

So:

| Publisher writes | Means | How this repo stores it | Count |
|---|---|---|---|
| `主[雅偉]` | Yahweh | `主[雅偉]` / `主[雅伟]` | 212 |
| `主#` | 基督 | `主[基督]` | 17 |
| `主*` | 耶穌 | `主[耶穌]` / `主[耶稣]` | 123 |

The bracket form is this repo's rendering of the publisher's notation,
not a change to it: `主#` was already imported as `主[基督]`, and `主*`
follows that precedent on the user's instruction. All three name the 主
printed immediately in front of them, which is why
`lib/utils/scripture_markup.dart` classifies them as referent glosses
rather than supplied words.

## What was done to `主*`, and when

| Date | Commit | What |
|---|---|---|
| 2025-05-17 | `b1dbb96a` | 121 occurrences deleted from BOTH reading assets. Commit title: "remove 主*". |
| 2026-08-10 | `4d019c19` | The last 2 deleted as "a character that is not in scripture" (馬太福音 9:28, 路加福音 24:34). |
| 2026-08-24 | `65eef087` | 124 deleted from the word-tap corpus, reasoning that the NT-only distribution *disproved* a divine-name convention. |
| 2026-09-02 | `862e2f62` | 123 restored as `主[耶穌]`, in both the reading assets and the corpus. |

The 2026-08-24 argument is worth keeping in view because it was careful,
measured, and wrong in a specific way: it found zero overlap with the
other two markers and an entirely-NT distribution, and read both as
evidence against a convention. Both are the signature *of* the
convention. Nothing in the assets could have corrected it — only this
page could.

## Open questions for the publisher

**All five are now drafted as `docs/和合本雅伟版-请教出版方.md`**, one
document, written so a publisher can answer it without the codebase:
使徒行傳 9:29 (below), 馬太福音 17:21 (apparatus or scripture),
H3069/H3068 across ~60 places, 利未記 4:17's second 血, and the one
convention question behind 代下 4:3 / 腓 1:29 / 約一 5:3 / 耶 33:1.
**Not sent** — it is the user's to send. Change nothing in any of the
five until an answer arrives, and record the answer here verbatim first.

**使徒行傳 9:29** — 「奉主的名放膽傳道」. The word-tap corpus carries `主*`
here; the reading assets never have, in any version back through 2025.
The two imports disagree at source rather than one having lost it, so
the marker is deliberately NOT restored at this reference: printing 耶穌
in a verse whose scripture does not contain the word is the defect
`test/tagged_rendered_duplication_test.dart` exists to catch, and it did
catch it. Ask which reading is right rather than guessing.

## The freeze, and how this sits with it

The reading assets are hash-pinned by `test/cuvs_yhwh_frozen_test.dart`
and are not ours to edit. The user lifted that freeze once, for this
restoration, because it puts back the publisher's own notation rather
than imposing ours — the opposite of the edits the freeze was written to
stop. **That is not a precedent.** The rule in that test still stands:
if the hash fails, revert the asset.

## If more publisher feedback arrives

Add it here, verbatim, with the date and who said it, before acting on
it. The verbatim text is the point — this whole episode turned on the
difference between "an asterisk appears in 115 NT verses" and "we use
主* for 耶穌", and only one of those can settle anything.
