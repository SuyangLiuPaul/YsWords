# LEB — you may not need to ask at all

Rewritten 2026-09-02 after reading the LEB's own published terms, which
no earlier draft of this file had done. **The conclusion changed.**

> ## The LEB's licence expressly permits giving it away
>
> From the LEB copyright and usage statement:
>
> > **"You can give away the Lexham English Bible, but you can't sell it
> > on its own.** If the LEB comprises less than 25% of the content of a
> > larger work, you can sell it as part of that work."
> >
> > "If you give away the LEB for use with a commercial product, or sell
> > a work containing more than 1,000 verses from the LEB, you must
> > annually report the number of units sold, distributed, and/or
> > downloaded."
> >
> > "You must always attribute quotations of the LEB."
>
> Yahweh's Words and Yahweh's Sword are given away, are not sold, and are
> not commercial products. **On the plain reading, bundling the complete
> LEB is already permitted** — which is a different situation from the
> NASB, whose limit is 1,000 verses full stop.
>
> So the open question is not permission. It is **attribution**, and we
> are currently getting it wrong.

## What we must fix — this is the real work

For 100 or more verses the statement requires this text, verbatim:

> Scripture quotations marked (LEB) are from the Lexham English Bible.
> Copyright 2012 Logos Bible Software. Lexham is a registered trademark
> of Logos Bible Software.

and, **in electronic use**, that "LEB" and "Lexham English Bible" link to
`http://www.lexhamenglishbible.com` and "Logos Bible Software" links to
`http://www.logos.com`.

What the app shows today (`ui_strings.dart`, `aboutLicenseLeb`):

```
© Logos Bible Software · non-commercial study only.
```

That is **not** the required statement, and it carries neither link. It
also says "non-commercial study only", which is a restriction the licence
does not actually impose in those words — we invented it. Fixing this is
a small code change and it is the thing most worth doing.

## If you still want to write

Reasonable — the plain reading above is mine, not a lawyer's, and
shipping the whole text as a bundled file is a bigger act than quoting
it. But send it as a **confirmation**, not as a permission request:
"here is what we do, here is our attribution, please tell us if this is
outside what the licence allows."

**Where to send it, and why this is muddled:**

| | |
|---|---|
| **Named in the licence** | `permissions@lexhampress.com` |
| **Does that mailbox still exist?** | **Yes** — `lexhampress.com` still has MX records (Cloudflare Email Routing) even though the website is gone |
| **The website** | `lexhampress.com` now redirects to `bakerbookhouse.com` — Baker Publishing Group **acquired Lexham Press in September 2025** |
| **Who owns the LEB** | **Logos Bible Software.** The text is "Copyright 2012 Logos Bible Software"; Logos's own announcement says it "retains the rights to Lexham Press content" |
| **Baker** | Bought the trade-book imprint. `ksmith@bakerpublishinggroup.com` is a *media* contact, not permissions |
| **Logos** | Publishes no permissions address; `cs@logos.com` is general support |

So: **write to `permissions@lexhampress.com`** (the address the licence
itself names, and it still receives mail), and if nothing comes back,
try Logos via `cs@logos.com` asking to be routed to rights — Logos is
the actual copyright holder.

---

## The letter, if you send one

**Subject:** LEB usage check — free, non-commercial Bible apps given to
a church

Dear Permissions Team,

I maintain two free applications that include the Lexham English Bible,
and I am writing to confirm that what I do is within the LEB's terms
rather than to ask for something beyond them.

I am one person. I write these applications myself, in my own time, and
give them to my church and to whoever else finds them useful. They cost
nothing to use. There is no advertising, no subscription, no in-app
purchase, no paywall, and no sale or sharing of user data, and no
revenue of any kind — nothing is sold and nothing is asked for.

1. **Yahweh's Words** — yahwehword.com. A Bible reader for Android, iOS,
   Web, macOS, Windows and Linux, aimed principally at bilingual
   Chinese–English readers, showing translations side by side.
2. **Yahweh's Sword** — sword.yahwehword.com. A study tool over the same
   texts, offering word-level lookup against Strong's numbers.

Each bundles the complete LEB so a reader can open any chapter with no
network. I read the LEB's terms as permitting this — "you can give away
the Lexham English Bible, but you can't sell it on its own" — and I want
to be sure I have read them correctly, because bundling the whole text
as a file is a larger act than quoting it.

Two specific questions:

- Is bundling the complete LEB for offline reading, in an application
  that is given away and never sold, within the licence?
- One of the two applications keys the biblical text to Strong's numbers
  for word study. It does this today for the King James Version, where
  the tagged text is public domain. Attaching Strong's numbers to the
  LEB would be a derivative work, so I would not do it without your
  agreement. Is that something you would permit?

I am correcting our attribution regardless. It will carry your required
statement in full, with "Lexham English Bible" linked to
lexhamenglishbible.com and "Logos Bible Software" linked to logos.com.

If any of this falls outside the licence, tell me and I will change it
or remove the LEB entirely.

Thank you for your time.

With respect,

[Your name]

---

## What changed, and what an earlier draft of this file got wrong

1. **The earlier draft treated this as a permission request equivalent
   to the NASB one.** It is not. The NASB's limit is 1,000 verses with
   no giveaway provision; the LEB expressly permits giving the whole
   thing away. Writing the same letter to both publishers would have
   asked Faithlife for something they have already granted in public.
2. **It asserted `permissions@faithlife.com`**, unverified, and later
   marked it unverified. The address actually named by the licence is
   `permissions@lexhampress.com`, and that domain still accepts mail
   even though the website now redirects to Baker Book House.
3. **Nobody had read the LEB's terms.** Every note in this repository,
   including the one that built the `/read/` prerender exclusion, treated
   LEB as NASB-shaped. Reading the statement took one page fetch and
   changed the whole conclusion.
4. **The bulk-file exposure reads differently here too.** A publicly
   fetchable `leb.json` is closer to "giving it away" than to selling
   it, so the LEB side of that problem is far less serious than the NASB
   side. It still fails the attribution requirement, which is a reason
   to fix attribution, not a reason to panic.
