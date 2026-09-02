# NASB — permission request to The Lockman Foundation

Drafted 2026-09-02, **rewritten the same day** after two findings that
changed it materially (see "What changed" at the bottom). **Not sent.**

> ## ⚠️ SENDABLE AS WRITTEN — but read this first
>
> As of 2026-09-02:
>
> ```
> sword.yahwehword.com/assets/assets/nasb.json   200   7,588,512 bytes  ← still live
> yswords.netlify.app  /assets/assets/nasb.json   404
> yahwehword.com       /assets/assets/nasb.json   404
> ```
>
> `sword.yahwehword.com` is the SeekSparks build, deployed separately,
> and `tools/release_web.sh`'s strip never covered it.
>
> **The disclosure paragraph below now says exactly this**, so the letter
> is honest and can go today. What it commits you to is a deadline: it
> says the file "will be gone within days". Make that true.
>
> If you would rather take Sword down first, do that and then replace
> the disclosure paragraph with the shorter version at the bottom of
> this file — it reads better, but it is not worth waiting for.

## Where it goes

| | |
|---|---|
| **From** | `support@yahwehword.com` — make sure you can **receive** replies there; this is the address they will answer to |
| **Preferred route** | The Permission to Quote Request Form — `lockman.org/permission-to-quote-request-form/`. **It requires a postal mailing address**, so have one ready |
| **Email** | `Lockman@Lockman.org` |
| **Post** | The Lockman Foundation, PO Box 2279, La Habra, CA 90632-2279 |

Use the form if it accepts this much detail, and send the letter below
as the covering message. Verified against lockman.org on 2026-09-02.

---

**Subject:** Permission request — complete NASB 2020 text in free,
non-commercial Bible apps given to a church

Dear Permissions Team,

I am writing to request permission to use the New American Standard
Bible (2020) in a small family of free applications I build and
maintain. I understand that what I am asking for goes beyond the
Foundation's gratis provisions for quotation, which is why I am writing
rather than relying on them.

**Who I am.** I am one person. I write these applications myself, in my
own time, and give them to my church and to whoever else finds them
useful. They cost nothing to use. There is no advertising, no
subscription, no in-app purchase, no paywall, and no sale or sharing of
user data. There is no revenue of any kind, commercial or otherwise —
nothing is sold and nothing is asked for. This is offered as work for
God, not as a product.

**What the applications are.** Two, sharing one codebase family:

1. **Yahweh's Words** — `yahwehword.com`. A Bible reader for Android,
   iOS, Web, macOS, Windows and Linux, aimed principally at bilingual
   Chinese–English readers. It shows translations side by side; the NASB
   is the English edition our readers most often pair with the Chinese
   text.

2. **Yahweh's Sword** — `sword.yahwehword.com`. A study tool over the
   same texts, offering word-level lookup against Strong's numbers.

**What I am asking for.** Two things, and the second is the one I
expect to be hardest:

- **(a) The complete text, bundled for offline reading**, in
  both applications. The reader lets a user open any chapter with no
  network, so a quotation permission would not cover it. I am asking
  about the whole text deliberately and would rather be told no than be
  granted something narrower by a misunderstanding.

- **(b) An NASB keyed to Strong's numbers.** Application 2 already does
  this for the King James Version, where the tagged text is in the
  public domain. Doing the same for the NASB would mean attaching a
  Strong's number to each word of your text, and I understand that this
  is a **derivative work** rather than a reproduction, and a materially
  larger request than (a). I am asking about it separately for that
  reason, and a "no" to (b) would not affect my interest in (a).

**What I would do.** I would display the copyright notice and
attribution in whatever form you require — on the version-selection
screen, in each application's About page, and in the public source
repositories. I would follow whatever restrictions you set on caching,
offline storage, export and text selection, and I am willing to
implement technical limits, for example disabling bulk copy or export of
NASB text, or making the offline data non-extractable.

**Disclosure.** Until recently the complete NASB text was also
downloadable as a single file from these websites, as a side effect of
how the web build packages its data. That was not intended and it went
unnoticed for some time. I have removed it from `yahwehword.com`, which
now serves no bulk NASB file. **The same file is still reachable on
`sword.yahwehword.com` as I write this**, because that application is
built and deployed separately; I am removing it there as well and it
will be gone within days of this letter. I would rather tell you that
than let you find it. Nothing about it is intentional and it stays gone
once removed, whatever you decide.

**If a decision will take time**, is there a provisional or limited-term
arrangement — or one conditioned on restrictions you specify — that
would let readers keep the NASB while the full request is considered? I
would gladly work within any interim conditions. To be clear, I am not
asking to carry on in the meantime on my own authority: the bulk text is
already off the websites and stays off until I hear from you.

If the answer is no, I will remove the NASB entirely and say so plainly
to the people who use these applications. The Bible reader works without
it — the King James Version is public domain and unaffected.

Thank you for your time, and for the work of the Foundation.

With respect,

[Your name]
support@yahwehword.com
yahwehword.com

---

## Notes before sending

**The one thing left to fill in is your name.** The "who I am" paragraph
is now written from what you told me — one person, given to the church
free, offered as work for God — so there is no status to choose. If you
*are* a registered non-profit, say so; it helps. If you are not, do not
imply it. What you have is already a favourable profile, and it is true.

**The disclosure paragraph is no longer optional, because the letter
now names three sites.** Earlier I offered it as a judgement call. It
isn't one any more: the file was publicly fetchable, it is trivially
discoverable, and the request describes exactly the sites it was
fetchable from. Omitting it now would read as concealment rather than
as brevity.

**But it must be true when you send it.** See the blocker at the top.

**Do not describe this as "fair use" or lean on the free-quotation
provisions.** At ~31,000 verses neither applies. Lockman's published
limit is 1,000 verses, not a complete book, not more than 50% of the
work, and not more than 1,000 verses in an electronic retrieval system —
claiming otherwise invites a boilerplate reply restating exactly that,
which is the answer you already have.

**Keep the words "complete text", "bundled" and "offline".** The
commonest way a request like this gets answered uselessly is by being
read as a quotation request.

**Expect (b) to be refused even if (a) is granted**, and that is fine —
the letter is built so the three can be answered separately. Tagging a
copyrighted translation word-by-word is a derivative work, and
publishers guard those hardest.

**Set expectations generally.** Full-Bible digital redistribution is the
case publishers guard most closely. A free, non-commercial, one-person
ministry is a genuinely favourable profile, but many publishers still
require a formal agreement and some charge.

**LEB is a separate letter to a separate publisher** — see
`docs/leb-licence-request.md`. Do not combine them.

---

## Shorter disclosure paragraph — use ONLY after Sword is fixed

Swap this in once all three URLs answer 404. Do not use it before then.

> **Disclosure.** Until recently the complete NASB text was also
> downloadable as a single file from these websites, as a side effect of
> how the web build packages its data. That was not intended and it went
> unnoticed for some time. It has now been removed from all of them, and
> the sites serve no bulk NASB file while I wait for your answer.

Check with:

```bash
for h in yahwehword.com yswords.netlify.app sword.yahwehword.com; do for a in nasb leb; do printf '%-24s %-5s %s\n' "$h" "$a" "$(curl -s -o /dev/null -w '%{http_code}' https://$h/assets/assets/$a.json)"; done; done
```

---

## What changed on 2026-09-02

1. **`sword.yahwehword.com` was found still serving the complete NASB
   and LEB** while both yswords production hosts had been fixed. The
   earlier draft's disclosure paragraph claimed the removal was
   complete. It was not. Hence the blocker at the top.
2. **The letter now names all three properties.** The earlier draft
   named Yahweh's Words and Yahweh's World and omitted Yahweh's Sword,
   which is the one that was still exposed.
3. **"NASB+" is now asked for explicitly, and as a derivative work.**
   In this codebase `+` means "keyed to Strong's numbers" (`KJV+S`,
   `雅简+`, `和简+`). It is not a Lockman product name — there is no
   NASB+ edition to license — so the request had to be phrased as what
   it actually is: attaching Strong's numbers to their text.
