# 和合本雅偉版 — what the publisher has told us about their own text

**Read this before repairing anything in `assets/cuvs-yhwh*.json` or
`assets/tagged/cuvs-yhwh/` — and, since 2026-09-08,
`assets/tagged/cuvs-yhwh-tr/`, which is derived from both (see the last
section).**

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

## The Traditional tagged layer, 2026-09-08 — derived, not tagged

`assets/tagged/cuvs-yhwh-tr/` is not a second import and is not a
conversion. `tools/derive_tagged_traditional.py` takes the Simplified
tagged layer run by run and, for each character, reads the **Traditional
character the publisher printed at that position** out of
`assets/cuvs-yhwh-tr.json`. Nothing is translated, transliterated or
looked up in a conversion table.

That is the whole reason it is allowed to exist. The one-to-many cases
that make 简→繁 a judgement call — 发→發/髮, 谷→谷/穀, 面→面/麵, 松→松/鬆
— are all already decided in the publisher's own Traditional text, so
this repo never has to make one. 19 characters stand opposite more than
one Traditional form across the Bible; not one of them is guessed at.

Three things follow, and all three are the kind of thing this page
exists to record before somebody rediscovers them:

  * **61 verses are absent from the layer.** Their two scripts are not
    the same length, so there is no position to read from. They are
    skipped and named (`--list-skipped`), never guessed. The Exegesis
    sheet falls back to plain text there, exactly as for any untagged
    verse.
  * **23,730 verses are verified against the shipped Traditional text
    character for character**, by `tools/derive_tagged_traditional.py`
    and again by `test/tagged_traditional_derived_test.dart`. The rest
    cannot be, because the tagged import writes a publisher's note as
    〔…〕 where the reading asset writes `<note: …>` — a notation
    difference, not a scripture difference.
  * **Neither reading asset is opened for writing**, and the freeze
    above is untouched. If a future pass wants to "fix" the derived
    layer, the thing to fix is the generator; the layer is output.

## The two scripts differ in their quotation marks, 2026-09-08

Recorded here because it is exactly the kind of thing that reads as
noise until it has cost something, and it has now cost 7,170 characters.

**This edition's Simplified sets `“ ” ‘ ’`; its Traditional sets
`「 」 『 』`.** Not a preference — a correspondence, one-to-one, with no
counter-example anywhere in the Bible. Walking every character-aligned
verse pair as they stood before the publisher sync:

| Simplified | Traditional | positions | other forms seen |
|---|---|---|---|
| `“` | `「` | 3,410 | none |
| `”` | `」` | 3,087 | none |
| `‘` | `『` | 630 | none |
| `’` | `』` | 599 | none |

Those four are the **only** non-Han characters that ever stand opposite
something different. Every comma, 。, ASCII `"`, digit and Latin letter
is identical in both scripts.

Two consequences worth keeping:

  * **"Punctuation is script-neutral" is false for this edition**, and
    it is a comfortable thing to believe. `mirror_publisher_sync_to_tr.py`
    believed it — it carried a `if not is_han(ch)` shortcut inherited
    from `mirror_inner_quotes_to_tr.py`, where it was true, because that
    pass only ever inserted an ASCII `"`. The publisher's current text
    roughly doubles the curly quotes, so the shortcut put 3,155 `“`,
    2,871 `”`, 574 `‘` and 570 `’` into a Traditional file that had
    **zero of all four**, leaving 3,905 verses that open 「 and close ”.
    創世記 30:6 and 出埃及記 3:5 are the two to look at.
  * **Nothing in the suite would have caught it.**
    `ascii_punctuation_test` counts the ASCII `"` and is right not to
    care about these; the mirror's own leak check compared against a
    correspondence table that had been filtered to Han pairs, so it
    listed all four at the top of "characters new to the Traditional
    file" and then reported "a real leak: 0". A guard derived from the
    same wrong premise as the code it guards is not a second opinion.

The fix was to stop asking whether a character is Han and let the
derived correspondence answer, which is what the rest of that script
already did. If a future pass needs to touch either mirror, the check to
run afterwards is simply: the Traditional edition contains no `“`, `”`,
`‘` or `’`, and the two scripts hold equal counts of their own four.
